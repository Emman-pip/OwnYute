import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/models.dart';
import '../../core/android_storage.dart';

class LibraryService {
  Future<LibraryTrack> readTrack(File file) async {
    if (Platform.isAndroid) return AndroidStorage.metadata(file.path);
    final fallback = LibraryTrack(
      path: file.path,
      title: p.basenameWithoutExtension(file.path),
    );
    try {
      final result = await Process.run('ffprobe', [
        '-v',
        'error',
        '-show_entries',
        'format=duration:format_tags=title,artist,album',
        '-of',
        'json',
        file.path,
      ]);
      if (result.exitCode != 0) return fallback;
      final json = jsonDecode(result.stdout as String) as Map<String, dynamic>;
      final format = json['format'] as Map<String, dynamic>?;
      final tags =
          (format?['tags'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key.toLowerCase(), value.toString()),
          ) ??
          {};
      return LibraryTrack(
        path: file.path,
        title: tags['title']?.isNotEmpty == true
            ? tags['title']!
            : fallback.title,
        artist: tags['artist'] ?? '',
        album: tags['album'] ?? '',
        duration: (double.tryParse(format?['duration']?.toString() ?? '') ?? 0)
            .round(),
      );
    } on ProcessException {
      return fallback;
    } on UnsupportedError {
      return fallback;
    } on FormatException {
      return fallback;
    }
  }
}
