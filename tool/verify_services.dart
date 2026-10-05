import 'dart:convert';
import 'dart:io';

import 'package:own_yute/core/models.dart';
import 'package:own_yute/features/downloads/download_service.dart';
import 'package:own_yute/features/search/youtube_service.dart';

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Future<void> main() async {
  final youtube = YoutubeService(
    run: (executable, arguments) async {
      check(executable == 'yt-dlp', 'Expected yt-dlp invocation');
      final input = arguments.last;
      if (input.contains('/results?')) {
        return ProcessResult(
          0,
          0,
          jsonEncode({
            'entries': [
              {
                'id': 'list-1',
                '_type': 'playlist',
                'title': 'Playlist',
                'url': 'https://www.youtube.com/playlist?list=list-1',
              },
            ],
          }),
          '',
        );
      }
      if (input.startsWith('ytsearch')) {
        return ProcessResult(
          0,
          0,
          jsonEncode({
            'entries': [
              {'id': 'song-1', 'title': 'Song', 'duration': 60},
            ],
          }),
          '',
        );
      }
      if (input.contains('list=')) {
        return ProcessResult(
          0,
          0,
          jsonEncode({
            'entries': [
              {'id': 'song-1', 'title': 'Song'},
              {'id': 'song-2', 'title': 'Another Song'},
            ],
          }),
          '',
        );
      }
      return ProcessResult(
        0,
        0,
        jsonEncode({'id': 'song-1', 'title': 'Song'}),
        '',
      );
    },
  );

  check(
    youtube.isYoutubeUrl('https://www.youtube.com/watch?v=abc'),
    'YouTube URL rejected',
  );
  check(
    youtube.isYoutubeUrl('https://youtu.be/abc'),
    'Short YouTube URL rejected',
  );
  check(
    !youtube.isYoutubeUrl('https://youtube.com.evil.invalid/watch?v=abc'),
    'Invalid host accepted',
  );
  check(!youtube.isYoutubeUrl('file:///tmp/music'), 'File URL accepted');
  final results = await youtube.search('song');
  check(results.songs.single.title == 'Song', 'Song search failed');
  check(results.playlists.single.title == 'Playlist', 'Playlist search failed');
  final song = await youtube.openUrl('https://youtu.be/song-1');
  check(song.$1?.title == 'Song', 'Pasted song did not open');
  final playlist = await youtube.openUrl(
    'https://www.youtube.com/watch?v=song-1&list=list-1',
  );
  check(playlist.$2.length == 2, 'Pasted playlist did not open picker');
  try {
    await youtube.openUrl('https://example.com/not-youtube');
    throw StateError('Invalid URL accepted');
  } on YoutubeFailure {
    // Expected actionable URL error.
  }
  final track = Track(id: 'x', url: 'https://youtu.be/x', title: 'A/B: C');
  check(DownloadService().fileName(track) == 'A_B_ C.mp3', 'Unsafe filename');
  final item = QueueItem(track: track, status: 'failed', error: 'network');
  check(
    QueueItem.fromJson(item.toJson()).error == 'network',
    'Queue serialization failed',
  );
  check(
    Track.fromJson(track.toJson()).title == track.title,
    'Track serialization failed',
  );
  stdout.writeln('Service checks passed.');
}
