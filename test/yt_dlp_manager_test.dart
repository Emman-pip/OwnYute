import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:own_yute/core/yt_dlp_manager.dart';

void main() {
  test(
    'checks nightly once per day and manual retry bypasses the limit',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'own_yute_update_test_',
      );
      addTearDown(() => directory.delete(recursive: true));
      var now = DateTime.utc(2026, 10, 5);
      var updates = 0;
      final manager = YtDlpManager(
        android: false,
        linux: true,
        clock: () => now,
        stampFile: () async => File('${directory.path}/checked'),
        installedLinux: () async => '${directory.path}/yt-dlp',
        updateLinux: () async {
          updates++;
          return '2026.10.05';
        },
      );
      expect(await manager.executable(), '${directory.path}/yt-dlp');
      expect(await manager.executable(), '${directory.path}/yt-dlp');
      expect(updates, 1);
      await manager.check(force: true);
      expect(updates, 2);
      now = now.add(const Duration(days: 1));
      await manager.executable();
      expect(updates, 3);
      manager.dispose();
    },
  );

  test(
    'failed update retains the installed executable and reports error',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'own_yute_fallback_test_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final working = File('${directory.path}/yt-dlp');
      await working.writeAsString('working version');
      final manager = YtDlpManager(
        android: false,
        linux: true,
        stampFile: () async => File('${directory.path}/checked'),
        installedLinux: () async =>
            await working.exists() ? working.path : null,
        updateLinux: () async => throw const SocketException('offline'),
      );
      expect(await manager.executable(), working.path);
      expect(await working.readAsString(), 'working version');
      expect(manager.lastError, contains('offline'));
      expect(manager.updating, false);
      manager.dispose();
    },
  );

  test(
    'Android update failure leaves search available and manual retry works',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'own_yute_android_update_test_',
      );
      addTearDown(() => directory.delete(recursive: true));
      var attempts = 0;
      final manager = YtDlpManager(
        android: true,
        linux: false,
        stampFile: () async => File('${directory.path}/checked'),
        updateAndroid: () async {
          attempts++;
          if (attempts == 1) throw const SocketException('offline');
          return '2026.10.05.123456';
        },
      );

      expect(await manager.executable(), 'yt-dlp');
      expect(manager.lastError, contains('offline'));
      expect(await manager.executable(), 'yt-dlp');
      expect(attempts, 1);

      await manager.check(force: true);
      expect(attempts, 2);
      expect(manager.lastError, isNull);
      expect(manager.version, '2026.10.05.123456');
      manager.dispose();
    },
  );
}
