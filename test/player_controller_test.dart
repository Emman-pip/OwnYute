import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:own_yute/core/models.dart';
import 'package:own_yute/features/player/player_controller.dart';
import 'package:own_yute/features/search/youtube_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Android reports playing only after a started event', () async {
    const channel = MethodChannel('own_yute/player');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async => null);
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final player = PlayerController(
      YoutubeService(run: (_, _) async => throw StateError('unused')),
      android: true,
    );
    await player.playTracks([
      const Track(id: 'local', url: '/tmp/local.mp3', title: 'Local'),
    ], 0);
    expect(player.preparing, true);
    expect(player.playing, false);
    await player.handlePlatformEvent('duration', 4000);
    expect(player.duration.inMilliseconds, 4000);
    expect(player.playing, false);
    await player.handlePlatformEvent('started', null);
    expect(player.playing, true);
    expect(player.preparing, false);
    await player.handlePlatformEvent('buffering', null);
    expect(player.buffering, true);
    expect(player.playing, true);
    await player.handlePlatformEvent('ready', null);
    expect(player.buffering, false);
    await player.handlePlatformEvent('paused', null);
    expect(player.playing, false);
    await player.handlePlatformEvent('error', 'Bad audio stream');
    expect(player.error, 'Bad audio stream');
    expect(player.playing, false);
    player.dispose();
  });

  test('playback queue appends, reorders, and removes safely', () async {
    final player = PlayerController(
      YoutubeService(run: (_, _) async => throw StateError('unused')),
      android: true,
    );
    const first = Track(id: 'one', url: '/tmp/one.mp3', title: 'One');
    const second = Track(id: 'two', url: '/tmp/two.mp3', title: 'Two');
    const third = Track(id: 'three', url: '/tmp/three.mp3', title: 'Three');

    player.addToQueue(first);
    player.addAllToQueue([second, third]);
    expect(player.current, same(first));
    expect(player.playing, isFalse);
    expect(player.queue, [first, second, third]);

    player.reorder(2, 1);
    expect(player.queue, [first, third, second]);
    expect(player.current, same(first));

    await player.removeAt(0);
    expect(player.current, same(third));
    expect(player.queue, [third, second]);
    expect(player.playing, isFalse);
    player.dispose();
  });

  test('the playing track sits at the top and finished songs leave', () async {
    final player = PlayerController(
      YoutubeService(run: (_, _) async => throw StateError('unused')),
      android: true,
    );
    const a = Track(id: 'a', url: '/tmp/a.mp3', title: 'A');
    const b = Track(id: 'b', url: '/tmp/b.mp3', title: 'B');
    const c = Track(id: 'c', url: '/tmp/c.mp3', title: 'C');

    await player.playTracks([a, b, c], 0);
    expect(player.current, same(a));
    expect(player.queue, [a, b, c]);
    expect(player.history, isEmpty);

    await player.next();
    expect(player.current, same(b));
    expect(player.queue.first, same(b), reason: 'current leads the queue');
    expect(player.queue, [b, c], reason: 'the finished song is gone');
    expect(player.history, [a]);

    await player.next();
    expect(player.current, same(c));
    expect(player.queue, [c]);
    expect(player.history, [a, b]);

    // End of the queue with repeat off: playback stops, nothing is invented.
    await player.next();
    expect(player.current, same(c));
    expect(player.queue, [c]);
    expect(player.playing, isFalse);
    player.dispose();
  });

  test('starting part way in drops the songs already passed', () async {
    final player = PlayerController(
      YoutubeService(run: (_, _) async => throw StateError('unused')),
      android: true,
    );
    const a = Track(id: 'a', url: '/tmp/a.mp3', title: 'A');
    const b = Track(id: 'b', url: '/tmp/b.mp3', title: 'B');
    const c = Track(id: 'c', url: '/tmp/c.mp3', title: 'C');

    await player.playTracks([a, b, c], 1);
    expect(player.current, same(b));
    expect(player.queue, [b, c]);
    expect(player.history, [a], reason: 'A was skipped past, not played');
    player.dispose();
  });

  test('previous returns to the last finished track', () async {
    final player = PlayerController(
      YoutubeService(run: (_, _) async => throw StateError('unused')),
      android: true,
    );
    const a = Track(id: 'a', url: '/tmp/a.mp3', title: 'A');
    const b = Track(id: 'b', url: '/tmp/b.mp3', title: 'B');

    await player.playTracks([a, b], 0);
    await player.next();
    expect(player.current, same(b));
    expect(player.history, [a]);

    await player.previous();
    expect(player.current, same(a), reason: 'back to the song that just ended');
    expect(player.queue.first, same(a));
    expect(player.history, [b], reason: 'and the roles swap over');
    player.dispose();
  });

  test('previous restarts the track when nothing has finished yet', () async {
    final player = PlayerController(
      YoutubeService(run: (_, _) async => throw StateError('unused')),
      android: true,
    );
    const a = Track(id: 'a', url: '/tmp/a.mp3', title: 'A');
    const b = Track(id: 'b', url: '/tmp/b.mp3', title: 'B');

    await player.playTracks([a, b], 0);
    await player.previous();
    expect(player.current, same(a));
    expect(player.history, isEmpty);
    expect(player.queue, [a, b], reason: 'the queue is untouched');
    player.dispose();
  });

  test('repeat starts the set over once the queue runs out', () async {
    final player = PlayerController(
      YoutubeService(run: (_, _) async => throw StateError('unused')),
      android: true,
    );
    const a = Track(id: 'a', url: '/tmp/a.mp3', title: 'A');
    const b = Track(id: 'b', url: '/tmp/b.mp3', title: 'B');

    await player.playTracks([a, b], 0);
    player.setRepeat(true);
    await player.next();
    expect(player.queue, [b]);
    await player.next();

    // Nothing was left, so the finished tracks come back in the order heard.
    expect(player.current, same(a));
    expect(player.queue, [a, b]);
    player.dispose();
  });

  test('the playing track cannot be dragged out of the top slot', () async {
    final player = PlayerController(
      YoutubeService(run: (_, _) async => throw StateError('unused')),
      android: true,
    );
    const a = Track(id: 'a', url: '/tmp/a.mp3', title: 'A');
    const b = Track(id: 'b', url: '/tmp/b.mp3', title: 'B');
    const c = Track(id: 'c', url: '/tmp/c.mp3', title: 'C');

    await player.playTracks([a, b, c], 0);
    player.reorder(0, 2);
    expect(player.queue, [a, b, c], reason: 'the head is pinned');
    expect(player.current, same(a));

    player.reorder(2, 0);
    expect(player.queue, [a, b, c], reason: 'nothing may move above it');

    // The rest of the list is still freely reorderable.
    player.reorder(2, 1);
    expect(player.queue, [a, c, b]);
    player.dispose();
  });

  test('removing the playing track promotes the next one up', () async {
    final player = PlayerController(
      YoutubeService(run: (_, _) async => throw StateError('unused')),
      android: true,
    );
    const a = Track(id: 'a', url: '/tmp/a.mp3', title: 'A');
    const b = Track(id: 'b', url: '/tmp/b.mp3', title: 'B');
    const c = Track(id: 'c', url: '/tmp/c.mp3', title: 'C');

    await player.playTracks([a, b, c], 0);
    await player.removeAt(0);
    expect(player.current, same(b));
    expect(player.queue, [b, c]);
    expect(player.playing, isFalse, reason: 'audio stops for the removal');
    player.dispose();
  });

  test('the finished history is capped', () async {
    final player = PlayerController(
      YoutubeService(run: (_, _) async => throw StateError('unused')),
      android: true,
    );
    const tracks = [
      Track(id: 't0', url: '/tmp/0.mp3', title: '0'),
      Track(id: 't1', url: '/tmp/1.mp3', title: '1'),
      Track(id: 't2', url: '/tmp/2.mp3', title: '2'),
    ];

    // Push well past the cap by cycling with repeat on.
    await player.playTracks(tracks, 0);
    player.setRepeat(true);
    for (var i = 0; i < PlayerController.historyLimit * 2; i++) {
      await player.next();
    }
    expect(
      player.history.length,
      lessThanOrEqualTo(PlayerController.historyLimit),
      reason: 'history must not grow without bound',
    );
    player.dispose();
  });

  test(
    'downloaded tracks without duration are probed for the scrubber',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const channel = MethodChannel('own_yute/player');
      messenger.setMockMethodCallHandler(channel, (_) async => null);
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final probed = <String>[];
      final player = PlayerController(
        YoutubeService(run: (_, _) async => throw StateError('unused')),
        android: true,
        probeLocalDuration: (path) async {
          probed.add(path);
          return 214;
        },
      );

      // YouTube search results carry no duration, so downloads start at 0.
      await player.playLocal([
        const LibraryTrack(path: '/music/song.mp3', title: 'Song'),
      ], 0);
      expect(player.duration, Duration.zero);

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(probed, ['/music/song.mp3']);
      expect(player.duration, const Duration(seconds: 214));
      expect(player.current?.duration, 214);
      expect(player.queue.single.duration, 214);
      player.dispose();
    },
  );

  test('remote previews are never probed for a local duration', () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const channel = MethodChannel('own_yute/player');
    messenger.setMockMethodCallHandler(channel, (_) async => null);
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    var probeCalls = 0;
    final player = PlayerController(
      YoutubeService(run: (_, _) async => throw StateError('unused')),
      android: true,
      probeLocalDuration: (_) async {
        probeCalls++;
        return 99;
      },
    );

    await player.playTracks([
      const Track(
        id: 'preview',
        url: 'https://www.youtube.com/watch?v=preview',
        title: 'Preview',
      ),
    ], 0);
    await Future<void>.delayed(Duration.zero);

    expect(probeCalls, 0);
    expect(player.duration, Duration.zero);
    player.dispose();
  });
}
