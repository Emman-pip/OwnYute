import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/models.dart';
import '../../core/android_storage.dart';
import '../../core/android_tools.dart';
import '../../core/yt_dlp_manager.dart';

enum DuplicateChoice { skip, replace, keepBoth }

class DownloadFailure implements Exception {
  const DownloadFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class DownloadService {
  DownloadService({
    this.ytDlpExecutable = 'yt-dlp',
    this.ffmpegExecutable = 'ffmpeg',
    YtDlpManager? tools,
  }) : _tools =
           tools ?? (ytDlpExecutable == 'yt-dlp' ? YtDlpManager.shared : null);
  final String ytDlpExecutable;
  final String ffmpegExecutable;
  final YtDlpManager? _tools;
  Process? _active;
  String? _activeTaskId;
  bool _cancelled = false;
  void cancel() {
    _cancelled = true;
    _active?.kill();
    final taskId = _activeTaskId;
    if (taskId != null) unawaited(AndroidTools.cancel(taskId));
  }

  String fileName(Track track) {
    final safe = track.title
        .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_')
        .trim();
    return '${safe.isEmpty ? 'Untitled' : safe}.mp3';
  }

  Future<String?> download(
    Track track,
    String folder,
    DuplicateChoice duplicate,
    void Function(double) onProgress,
  ) async {
    if (!Platform.isLinux && !Platform.isAndroid) {
      throw const DownloadFailure(
        'Downloads are unavailable on this platform.',
      );
    }
    _cancelled = false;
    File? target;
    if (Platform.isLinux) {
      final destination = Directory(folder);
      await destination.create(recursive: true);
      target = File(p.join(folder, fileName(track)));
      if (await target.exists()) {
        if (duplicate == DuplicateChoice.skip) return null;
        if (duplicate == DuplicateChoice.keepBoth) {
          var number = 2;
          final stem = p.basenameWithoutExtension(target.path);
          while (await target!.exists()) {
            target = File(p.join(folder, '$stem ($number).mp3'));
            number++;
          }
        }
      }
    }
    final scratch = await Directory.systemTemp.createTemp('own_yute_');
    try {
      await _run(
        await _tools?.executable() ?? ytDlpExecutable,
        [
          '--ignore-config',
          '--no-playlist',
          '--newline',
          '-f',
          'bestaudio/best',
          '-o',
          p.join(scratch.path, 'source.%(ext)s'),
          track.url,
        ],
        (line) {
          final match = RegExp(r'\[download\]\s+([\d.]+)%').firstMatch(line);
          if (match != null) {
            onProgress((double.parse(match.group(1)!) / 100) * 0.75);
          }
        },
      );
      if (_cancelled) throw const DownloadFailure('Download cancelled.');
      final sources = await scratch
          .list()
          .where(
            (entity) =>
                entity is File && p.basename(entity.path).startsWith('source.'),
          )
          .toList();
      if (sources.isEmpty) {
        throw const DownloadFailure('yt-dlp did not create an audio file.');
      }
      final temporaryMp3 = p.join(scratch.path, 'finished.mp3');
      final cover = await _artworkFile(track.artwork, scratch);
      if (_cancelled) throw const DownloadFailure('Download cancelled.');
      await _run(ffmpegExecutable, [
        '-hide_banner',
        '-loglevel',
        'error',
        '-y',
        '-i',
        sources.first.path,
        if (cover != null) ...['-i', cover.path],
        if (cover != null) ...['-map', '0:a:0', '-map', '1:v:0'] else '-vn',
        '-codec:a',
        'libmp3lame',
        '-qscale:a',
        '0',
        if (cover != null) ...[
          '-codec:v',
          'mjpeg',
          '-disposition:v',
          'attached_pic',
          '-id3v2_version',
          '3',
        ],
        '-metadata',
        'title=${track.title}',
        '-metadata',
        'artist=${track.artist}',
        '-metadata',
        'album=${track.album}',
        temporaryMp3,
      ]);
      if (_cancelled) throw const DownloadFailure('Download cancelled.');
      onProgress(0.95);
      if (Platform.isAndroid) {
        final saved = await AndroidStorage.save(
          folder,
          fileName(track),
          temporaryMp3,
          duplicate.name,
        );
        onProgress(1);
        return saved?.path;
      }
      final staged = File(
        p.join(
          folder,
          '.${p.basename(target!.path)}.${DateTime.now().microsecondsSinceEpoch}.tmp',
        ),
      );
      try {
        await File(temporaryMp3).copy(staged.path);
        await staged.rename(target.path);
      } finally {
        if (await staged.exists()) await staged.delete();
      }
      onProgress(1);
      return target.path;
    } finally {
      await scratch.delete(recursive: true);
      _active = null;
    }
  }

  Future<void> editMetadata(LibraryTrack track) async {
    if (!Platform.isLinux && !Platform.isAndroid) {
      throw const DownloadFailure(
        'Metadata editing is unavailable on this platform.',
      );
    }
    final scratch = await Directory.systemTemp.createTemp('own_yute_cover_');
    final isDocument =
        Platform.isAndroid && track.path.startsWith('content://');
    final name = isDocument
        ? await AndroidStorage.folderName(track.path)
        : p.basename(track.path);
    final extension = p.extension(name).isEmpty ? '.mp3' : p.extension(name);
    String? copiedSource;
    final temporary = Platform.isAndroid
        ? p.join(scratch.path, 'edited$extension')
        : '${track.path}.own_yute.tmp$extension';
    try {
      if (isDocument) {
        copiedSource = await AndroidStorage.readToCache(track.path);
      }
      final sourcePath = copiedSource ?? track.path;
      if (!await File(sourcePath).exists()) {
        throw const DownloadFailure('This audio file no longer exists.');
      }
      final cover = await _artworkFile(track.artwork, scratch);
      await _run(ffmpegExecutable, [
        '-hide_banner',
        '-loglevel',
        'error',
        '-y',
        '-i',
        sourcePath,
        if (cover != null) ...[
          '-i',
          cover.path,
          '-map',
          '0:a:0',
          '-map',
          '1:v:0',
        ],
        '-codec:a',
        'copy',
        if (cover != null) ...[
          '-codec:v',
          'mjpeg',
          '-disposition:v',
          'attached_pic',
          '-id3v2_version',
          '3',
        ] else ...[
          '-codec:v',
          'copy',
        ],
        '-metadata',
        'title=${track.title}',
        '-metadata',
        'artist=${track.artist}',
        '-metadata',
        'album=${track.album}',
        temporary,
      ]);
      final staged = File(temporary);
      if (!await staged.exists() || await staged.length() == 0) {
        throw const DownloadFailure(
          'Metadata edit produced an empty audio file. The original was kept.',
        );
      }
      await _run(ffmpegExecutable, [
        '-hide_banner',
        '-loglevel',
        'error',
        '-i',
        temporary,
        '-map',
        '0:a:0',
        '-frames:a',
        '1',
        '-f',
        'null',
        '-',
      ]);
      if (isDocument) {
        await AndroidStorage.replace(track.path, temporary);
      } else {
        await File(temporary).rename(track.path);
      }
    } finally {
      final file = File(temporary);
      if (await file.exists()) await file.delete();
      if (copiedSource != null) {
        final copied = File(copiedSource);
        if (await copied.exists()) await copied.delete();
      }
      await scratch.delete(recursive: true);
    }
  }

  Future<File?> _artworkFile(String url, Directory scratch) async {
    if (url.trim().isEmpty) return null;
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !{'https', 'http'}.contains(uri.scheme)) {
      throw const DownloadFailure(
        'Artwork must be an HTTP or HTTPS image URL.',
      );
    }
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final response = await (await client.getUrl(uri)).close();
      if (response.statusCode != 200) {
        throw DownloadFailure(
          'Artwork download failed (${response.statusCode}).',
        );
      }
      final output = File(p.join(scratch.path, 'cover_image'));
      final sink = output.openWrite();
      var bytes = 0;
      await for (final chunk in response) {
        bytes += chunk.length;
        if (bytes > 10 * 1024 * 1024) {
          await sink.close();
          throw const DownloadFailure('Artwork exceeds the 10 MB limit.');
        }
        sink.add(chunk);
      }
      await sink.close();
      return output;
    } on SocketException {
      throw const DownloadFailure(
        'Could not load artwork. Check the URL and connection.',
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _run(
    String executable,
    List<String> args, [
    void Function(String)? onLine,
  ]) async {
    if (Platform.isAndroid) {
      final taskId = AndroidTools.newTaskId();
      _activeTaskId = taskId;
      try {
        final result = await AndroidTools.run(
          executable,
          args,
          taskId: taskId,
          onProgress: (percent, line) {
            onLine?.call('[download] $percent%');
            if (line.isNotEmpty) onLine?.call(line);
          },
        );
        if (_cancelled) throw const DownloadFailure('Download cancelled.');
        if (result.exitCode != 0) {
          final message = (result.stderr as String).trim();
          throw DownloadFailure(
            message.isEmpty ? '$executable failed.' : message,
          );
        }
        return;
      } on ProcessException catch (failure) {
        throw DownloadFailure(failure.message);
      } finally {
        _activeTaskId = null;
      }
    }
    try {
      _active = await Process.start(executable, args);
    } on ProcessException {
      throw DownloadFailure('Install $executable and try again.');
    }
    final errors = StringBuffer();
    final stdoutDone = _active!.stdout
        .transform(const SystemEncoding().decoder)
        .transform(const LineSplitter())
        .listen((line) => onLine?.call(line))
        .asFuture<void>();
    final stderrDone = _active!.stderr
        .transform(const SystemEncoding().decoder)
        .transform(const LineSplitter())
        .listen((line) {
          errors.writeln(line);
          onLine?.call(line);
        })
        .asFuture<void>();
    final code = await _active!.exitCode;
    await Future.wait([stdoutDone, stderrDone]);
    if (_cancelled) throw const DownloadFailure('Download cancelled.');
    if (code != 0) {
      throw DownloadFailure(
        errors.toString().trim().isEmpty
            ? '$executable failed.'
            : errors.toString().trim(),
      );
    }
  }
}
