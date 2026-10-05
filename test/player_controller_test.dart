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
