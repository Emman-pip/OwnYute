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
}
