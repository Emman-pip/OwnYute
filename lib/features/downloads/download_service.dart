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

/// One throughput reading from a running download, used to size a batch.
class TransferSample {
  const TransferSample({
    required this.bytes,
    required this.bytesPerSecond,
    required this.elapsed,
  });

  /// Bytes transferred so far, as reported by yt-dlp.
  final int bytes;
  final double bytesPerSecond;
  final Duration elapsed;
}

/// Holds the cancellation state and process handle of a single
/// [DownloadService.download] call, so that parallel downloads never share them.
class _DownloadRun {
  final Stopwatch clock = Stopwatch()..start();
  final Stopwatch sampleClock = Stopwatch()..start();
  bool cancelled = false;
  Process? process;
  String? taskId;
  int bytes = 0;

  /// Caps how often a run reports throughput, since `--newline` is chatty.
  bool shouldSample() {
    if (sampleClock.elapsedMilliseconds < 250) return false;
    sampleClock.reset();
    return true;
  }
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

  /// Live runs. Cancelling reaches every one of them, not just the newest.
  final Set<_DownloadRun> _runs = {};

  /// Stops every in-flight download. Each run owns its own flag and process, so
  /// cancelling a parallel batch kills all of them instead of the last one.
  void cancel() {
    for (final run in List<_DownloadRun>.from(_runs)) {
      run.cancelled = true;
      run.process?.kill();
      final taskId = run.taskId;
      if (taskId != null) unawaited(AndroidTools.cancel(taskId));
    }
  }

  Future<T> _withRun<T>(Future<T> Function(_DownloadRun run) body) async {
    final run = _DownloadRun();
    _runs.add(run);
    try {
      return await body(run);
    } finally {
      _runs.remove(run);
    }
  }

  /// Parses `of ~ 3.50MiB` from a `--newline` progress line into bytes.
  static final _sizePattern = RegExp(
    r'of\s+~?\s*([\d.]+)\s*(B|KiB|MiB|GiB|TiB)\b',
    caseSensitive: false,
  );

  /// Parses `at 1.23MiB/s` from a `--newline` progress line into bytes/second.
  static final _speedPattern = RegExp(
    r'at\s+([\d.]+)\s*(B|KiB|MiB|GiB|TiB)/s',
    caseSensitive: false,
  );

  static const _units = {
    'B': 1,
    'kib': 1024,
    'mib': 1024 * 1024,
    'gib': 1024 * 1024 * 1024,
    'tib': 1024 * 1024 * 1024 * 1024,
  };

  static double _parse(RegExp pattern, String line) {
    final match = pattern.firstMatch(line);
    if (match == null) return 0;
    final value = double.tryParse(match.group(1)!);
    final unit = _units[match.group(2)!.toLowerCase()];
    if (value == null || unit == null) return 0;
    return value * unit;
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
    void Function(double) onProgress, {
    void Function(TransferSample)? onSample,
  }) async {
    if (!Platform.isLinux && !Platform.isAndroid) {
      throw const DownloadFailure(
        'Downloads are unavailable on this platform.',
      );
    }
    return _withRun(
      (run) =>
          _downloadTrack(track, folder, duplicate, onProgress, onSample, run),
    );
  }

  Future<String?> _downloadTrack(
    Track track,
    String folder,
    DuplicateChoice duplicate,
    void Function(double) onProgress,
    void Function(TransferSample)? onSample,
    _DownloadRun run,
  ) async {
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
          '--write-thumbnail',
          '-f',
          'bestaudio/best',
          '-o',
          p.join(scratch.path, 'source.%(ext)s'),
          track.url,
        ],
        run,
        (line) {
          final match = RegExp(r'\[download\]\s+([\d.]+)%').firstMatch(line);
          if (match == null) return;
          final fraction = double.parse(match.group(1)!) / 100;
          onProgress(fraction * 0.75);
          if (onSample == null || !run.shouldSample()) return;
          final total = _parse(_sizePattern, line);
          if (total > 0) run.bytes = (total * fraction).round();
          if (run.bytes <= 0) return;
          // Prefer yt-dlp's own reading, but fall back to bytes over elapsed so
          // the signal survives platforms that omit the "at .../s" field.
          final speed = _parse(_speedPattern, line);
          final seconds = run.clock.elapsedMicroseconds / 1000000;
          final bytesPerSecond = speed > 0 ? speed : run.bytes / seconds;
          if (bytesPerSecond <= 0 || !bytesPerSecond.isFinite) return;
          onSample(
            TransferSample(
              bytes: run.bytes,
              bytesPerSecond: bytesPerSecond,
              elapsed: run.clock.elapsed,
            ),
          );
        },
      );
      if (run.cancelled) throw const DownloadFailure('Download cancelled.');
      final outputFiles = await scratch
          .list()
          .where((entity) => entity is File)
          .cast<File>()
          .toList();
      const imageExtensions = {
        '.avif',
        '.bmp',
        '.gif',
        '.jpeg',
        '.jpg',
        '.png',
        '.webp',
      };
      final sources = outputFiles
          .where(
            (file) =>
                p.basename(file.path).startsWith('source.') &&
                !imageExtensions.contains(p.extension(file.path).toLowerCase()),
          )
          .toList();
      if (sources.isEmpty) {
        throw const DownloadFailure('yt-dlp did not create an audio file.');
      }
      final temporaryMp3 = p.join(scratch.path, 'finished.mp3');
      File? cover;
      try {
        cover = await _artworkFile(track.artwork, scratch);
      } catch (_) {
        // Artwork is best-effort and must not prevent the audio download.
      }
      final downloadedCovers = outputFiles
          .where(
            (file) =>
                p.basename(file.path).startsWith('source.') &&
                imageExtensions.contains(p.extension(file.path).toLowerCase()),
          )
          .toList();
      if (cover == null && downloadedCovers.isNotEmpty) {
        for (final candidate in downloadedCovers) {
          if (await candidate.length() <= 10 * 1024 * 1024) {
            cover = candidate;
            break;
          }
        }
      }
      if (run.cancelled) throw const DownloadFailure('Download cancelled.');
      try {
        await _convertDownload(
          sources.first.path,
          temporaryMp3,
          track,
          cover,
          run,
        );
      } on DownloadFailure {
        if (cover == null || run.cancelled) rethrow;
        final failed = File(temporaryMp3);
        if (await failed.exists()) await failed.delete();
        await _convertDownload(sources.first.path, temporaryMp3, track, null, run);
      }
      if (run.cancelled) throw const DownloadFailure('Download cancelled.');
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
    }
  }

  Future<void> _convertDownload(
    String source,
    String output,
    Track track,
    File? cover,
    _DownloadRun run,
  ) => _run(ffmpegExecutable, [
    '-hide_banner',
    '-loglevel',
    'error',
    '-y',
    '-i',
    source,
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
    output,
  ], run);

  Future<void> editMetadata(LibraryTrack track) async {
    if (!Platform.isLinux && !Platform.isAndroid) {
      throw const DownloadFailure(
        'Metadata editing is unavailable on this platform.',
      );
    }
    // Editing owns a run too, so cancelling a batch also stops a metadata edit
    // rather than orphaning a live ffmpeg process.
    return _withRun((run) => _editMetadata(track, run));
  }

  Future<void> _editMetadata(LibraryTrack track, _DownloadRun run) async {
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
      ], run);
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
      ], run);
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

  Future<File?> _artworkFile(String source, Directory scratch) async {
    final value = source.trim();
    if (value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (uri == null || (!{'https', 'http', 'file', ''}.contains(uri.scheme))) {
      throw const DownloadFailure(
        'Artwork must be a selected image or an HTTP/HTTPS image URL.',
      );
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      final file = File(uri.scheme == 'file' ? uri.toFilePath() : value);
      if (!await file.exists()) {
        throw const DownloadFailure('The selected artwork no longer exists.');
      }
      if (await file.length() > 10 * 1024 * 1024) {
        throw const DownloadFailure('Artwork exceeds the 10 MB limit.');
      }
      return file;
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
    List<String> args,
    _DownloadRun run, [
    void Function(String)? onLine,
  ]) async {
    if (Platform.isAndroid) {
      final taskId = AndroidTools.newTaskId();
      run.taskId = taskId;
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
        if (run.cancelled) throw const DownloadFailure('Download cancelled.');
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
        run.taskId = null;
      }
    }
    late final Process process;
    try {
      process = run.process = await Process.start(executable, args);
    } on ProcessException {
      throw DownloadFailure('Install $executable and try again.');
    }
    final errors = StringBuffer();
    final stdoutDone = process.stdout
        .transform(const SystemEncoding().decoder)
        .transform(const LineSplitter())
        .listen((line) => onLine?.call(line))
        .asFuture<void>();
    final stderrDone = process.stderr
        .transform(const SystemEncoding().decoder)
        .transform(const LineSplitter())
        .listen((line) {
          errors.writeln(line);
          onLine?.call(line);
        })
        .asFuture<void>();
    final code = await process.exitCode;
    await Future.wait([stdoutDone, stderrDone]);
    run.process = null;
    if (run.cancelled) throw const DownloadFailure('Download cancelled.');
    if (code != 0) {
      throw DownloadFailure(
        errors.toString().trim().isEmpty
            ? '$executable failed.'
            : errors.toString().trim(),
      );
    }
  }
}
