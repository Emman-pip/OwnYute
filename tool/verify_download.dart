import 'dart:convert';
import 'dart:io';

import 'package:own_yute/core/models.dart';
import 'package:own_yute/features/downloads/download_service.dart';
import 'package:own_yute/features/library/library_service.dart';

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Future<void> main() async {
  final scratch = await Directory.systemTemp.createTemp('own_yute_verify_');
  try {
    final fixture = File('${scratch.path}/fixture.wav');
    final generated = await Process.run('ffmpeg', [
      '-hide_banner',
      '-loglevel',
      'error',
      '-f',
      'lavfi',
      '-i',
      'sine=frequency=440:duration=1',
      '-y',
      fixture.path,
    ]);
    check(generated.exitCode == 0, 'Could not generate audio fixture');
    final cover = File('${scratch.path}/cover.jpg');
    final generatedCover = await Process.run('ffmpeg', [
      '-hide_banner',
      '-loglevel',
      'error',
      '-f',
      'lavfi',
      '-i',
      'color=c=0x6656d8:s=64x64',
      '-frames:v',
      '1',
      '-y',
      cover.path,
    ]);
    check(generatedCover.exitCode == 0, 'Could not generate artwork fixture');
    final stub = File('${scratch.path}/fake-yt-dlp');
    await stub.writeAsString(r'''#!/bin/sh
previous=''
for argument in "$@"; do
  if [ "$previous" = '-o' ]; then output="$argument"; fi
  previous="$argument"
done
target=$(printf '%s' "$output" | sed 's/%(ext)s/wav/')
cp "$(dirname "$0")/fixture.wav" "$target"
cp "$(dirname "$0")/cover.jpg" "$(dirname "$target")/source.jpg"
printf '[download] 100.0%%\n'
''');
    final executable = await Process.run('chmod', ['+x', stub.path]);
    check(executable.exitCode == 0, 'Could not prepare yt-dlp fixture');
    final destination = Directory('${scratch.path}/music');
    final downloader = DownloadService(ytDlpExecutable: stub.path);
    const song = Track(
      id: 'fixture',
      url: 'https://youtu.be/fixture',
      title: 'Sample',
      artist: 'Test Artist',
      album: 'Test Album',
    );
    final first = await downloader.download(
      song,
      destination.path,
      DuplicateChoice.replace,
      (_) {},
    );
    check(first != null && await File(first).exists(), 'MP3 was not created');
    final probe = await Process.run('ffprobe', [
      '-v',
      'error',
      '-show_entries',
      'format_tags=title,artist,album:stream=codec_name:stream_disposition=attached_pic',
      '-of',
      'json',
      first!,
    ]);
    check(probe.exitCode == 0, 'MP3 could not be probed');
    final details = jsonDecode(probe.stdout as String) as Map<String, dynamic>;
    final tags =
        (details['format'] as Map<String, dynamic>)['tags']
            as Map<String, dynamic>;
    check(
      tags['title'] == 'Sample' &&
          tags['artist'] == 'Test Artist' &&
          tags['album'] == 'Test Album',
      'MP3 metadata was not written',
    );
    final streams = details['streams'] as List<dynamic>;
    check(
      streams.any(
        (stream) =>
            (stream as Map<String, dynamic>)['codec_name'] == 'mjpeg' &&
            ((stream['disposition']
                    as Map<String, dynamic>?)?['attached_pic'] ==
                1),
      ),
      'Local cover artwork was not embedded',
    );
    final indexed = await LibraryService().readTrack(File(first));
    check(
      indexed.title == 'Sample' &&
          indexed.artist == 'Test Artist' &&
          indexed.duration > 0,
      'Library did not read MP3 metadata',
    );
    final skipped = await downloader.download(
      song,
      destination.path,
      DuplicateChoice.skip,
      (_) {},
    );
    check(skipped == null, 'Duplicate skip should not write a file');
    final replaced = await downloader.download(
      song,
      destination.path,
      DuplicateChoice.replace,
      (_) {},
    );
    check(
      replaced == first && await File(first).exists(),
      'Replace should update the existing file',
    );
    final second = await downloader.download(
      song,
      destination.path,
      DuplicateChoice.keepBoth,
      (_) {},
    );
    check(
      second != first && second != null && await File(second).exists(),
      'Keep both should create a second file',
    );
    await downloader.editMetadata(
      LibraryTrack(path: first, title: 'Edited', artist: 'Another Artist'),
    );
    final reprobe = await Process.run('ffprobe', [
      '-v',
      'error',
      '-show_entries',
      'format_tags=title,artist',
      '-of',
      'json',
      first,
    ]);
    final editedTags =
        ((jsonDecode(reprobe.stdout as String)
                    as Map<String, dynamic>)['format']
                as Map<String, dynamic>)['tags']
            as Map<String, dynamic>;
    check(
      editedTags['title'] == 'Edited',
      'Metadata edit did not update the MP3',
    );
    stdout.writeln('Download checks passed.');
  } finally {
    await scratch.delete(recursive: true);
  }
}
