import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:own_yute/core/models.dart';
import 'package:own_yute/core/yt_dlp_manager.dart';
import 'package:own_yute/features/search/youtube_service.dart';

void main() {
  test('separates songs and playlists and opens pasted URLs', () async {
    final youtube = YoutubeService(
      run: (_, arguments) async {
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
                {'id': 'song-1', 'title': 'Song'},
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
                {'id': 'song-2', 'title': 'Another'},
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
    final results = await youtube.search('music');
    expect(results.songs.single.title, 'Song');
    expect(results.playlists.single.title, 'Playlist');
    expect((await youtube.openUrl('https://youtu.be/song-1')).$1?.id, 'song-1');
    expect(
      (await youtube.openUrl('https://www.youtube.com/playlist?list=list-1'))
          .$2,
      hasLength(2),
    );
  });

  test('rejects invalid and unavailable URLs', () async {
    final youtube = YoutubeService(
      run: (_, _) async => ProcessResult(0, 1, '', 'Video unavailable'),
    );
    expect(
      youtube.openUrl('https://example.com/video'),
      throwsA(isA<YoutubeFailure>()),
    );
    expect(
      youtube.openUrl('https://www.youtube.com/watch?v=missing'),
      throwsA(
        predicate((error) => error.toString().contains('Video unavailable')),
      ),
    );
  });

  test('preview reports tool launch and empty tool errors', () async {
    const track = Track(
      id: 'one',
      url: 'https://www.youtube.com/watch?v=one',
      title: 'One',
    );
    final failedLaunch = YoutubeService(
      run: (_, args) async =>
          throw ProcessException('yt-dlp', args, 'missing binary'),
    );
    await expectLater(
      failedLaunch.streamUrl(track),
      throwsA(predicate((e) => e.toString().contains('missing binary'))),
    );
    final emptyError = YoutubeService(
      run: (_, _) async => ProcessResult(0, 1, '', ''),
    );
    await expectLater(
      emptyError.streamUrl(track),
      throwsA(
        predicate((e) => e.toString().contains('Could not prepare preview')),
      ),
    );
  });

  test('search fetches a small batch first and a full window on demand', () async {
    final requested = <String>[];
    final playlistArgs = <List<String>>[];
    final youtube = YoutubeService(
      run: (_, arguments) async {
        final input = arguments.last;
        if (input.startsWith('ytsearch')) {
          requested.add(input);
          final count = int.parse(
            input.substring('ytsearch'.length, input.indexOf(':')),
          );
          return ProcessResult(
            0,
            0,
            jsonEncode({
              'entries': List.generate(
                count,
                (index) => {'id': 'song-$index', 'title': 'Song $index'},
              ),
            }),
            '',
          );
        }
        playlistArgs.add(arguments);
        return ProcessResult(0, 0, jsonEncode({'entries': []}), '');
      },
    );
    final first = await youtube.search('music');
    expect(requested.single, 'ytsearch5:music');
    expect(playlistArgs.single, contains('--playlist-end'));
    expect(playlistArgs.single, contains('5'));
    expect(first.songs, hasLength(5));
    expect(first.songsTotal, 5);

    final full = await youtube.search('music', songs: 0, playlists: 0);
    expect(requested.last, 'ytsearch50:music');
    expect(playlistArgs.last, isNot(contains('--playlist-end')));
    expect(full.songs, hasLength(50));
    expect(full.songsTotal, 50);
  });

  test('search uses the app-managed Linux nightly', () async {
    final directory = await Directory.systemTemp.createTemp(
      'own_yute_tool_choice_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final manager = YtDlpManager(
      android: false,
      linux: true,
      stampFile: () async => File('${directory.path}/checked'),
      installedLinux: () async => '${directory.path}/yt-dlp',
      updateLinux: () async => 'nightly',
    );
    final commands = <String>[];
    final youtube = YoutubeService(
      tools: manager,
      run: (executable, arguments) async {
        commands.add(executable);
        return ProcessResult(0, 0, jsonEncode({'entries': []}), '');
      },
    );
    await youtube.search('music');
    expect(commands, everyElement('${directory.path}/yt-dlp'));
    expect(commands, hasLength(2));
    manager.dispose();
  });

  test('radio mix watch URL opens its song, not an endless playlist', () async {
    final youtube = YoutubeService(
      run: (_, arguments) async {
        expect(arguments, contains('--no-playlist'));
        expect(arguments, isNot(contains('--yes-playlist')));
        return ProcessResult(
          0,
          0,
          jsonEncode({'id': 'LGEsM5l9U7U', 'title': 'Song'}),
          '',
        );
      },
    );
    final result = await youtube.openUrl(
      'https://www.youtube.com/watch?v=LGEsM5l9U7U&list=RDLGEsM5l9U7U&start_radio=1',
    );
    expect(result.$1?.id, 'LGEsM5l9U7U');
    expect(result.$2, isEmpty);
  });
}
