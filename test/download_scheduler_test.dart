import 'package:flutter_test/flutter_test.dart';
import 'package:own_yute/features/downloads/download_scheduler.dart';

void main() {
  group('download scheduler', () {
    test('starts narrow and widens only when the link shows a real gain', () {
      var now = DateTime(2026);
      final scheduler = DownloadScheduler(
        maxConcurrency: 8,
        clock: () => now,
      );
      expect(scheduler.target, 2, reason: 'probes before committing to width');

      // Two tracks each at 1 MiB/s, then a third joins the window.
      scheduler.beginWindow();
      scheduler.recordSample('a', 1000);
      scheduler.recordSample('b', 1000);
      now = now.add(const Duration(seconds: 2));
      expect(scheduler.closeWindow(), isFalse, reason: 'no baseline to beat');
      expect(scheduler.target, 2);

      scheduler.beginWindow();
      scheduler.recordSample('a', 1000);
      scheduler.recordSample('b', 1000);
      scheduler.recordSample('c', 600);
      now = now.add(const Duration(seconds: 2));
      expect(scheduler.closeWindow(), isTrue);
      expect(
        scheduler.target,
        3,
        reason: '2600 over 2000 is a 30% gain, so a third worker is justified',
      );
    });

    test('a window too short to measure never resizes the batch', () {
      var now = DateTime(2026);
      final scheduler = DownloadScheduler(maxConcurrency: 8, clock: () => now);
      scheduler.beginWindow();
      scheduler.recordSample('a', 1000);
      now = now.add(const Duration(milliseconds: 400));
      expect(scheduler.closeWindow(), isFalse);
      expect(scheduler.target, 2);
    });

    test('holds its width when an extra worker bought nothing', () {
      var now = DateTime(2026);
      final scheduler = DownloadScheduler(maxConcurrency: 8, clock: () => now);
      // A first window establishes the baseline at two workers.
      scheduler.beginWindow();
      scheduler.recordSample('a', 1000);
      scheduler.recordSample('b', 1000);
      now = now.add(const Duration(seconds: 2));
      scheduler.closeWindow();

      // Adding tracks splits the same pipe, so per-track speed falls but the
      // aggregate stays flat: the extra workers bought nothing.
      for (var window = 0; window < 3; window++) {
        scheduler.beginWindow();
        for (final track in ['a', 'b', 'c']) {
          scheduler.recordSample(track, 667);
        }
        now = now.add(const Duration(seconds: 2));
        scheduler.closeWindow();
      }
      expect(
        scheduler.target,
        2,
        reason: 'flat aggregate throughput means two workers is the rest state',
      );
    });

    test('gives a worker back when the aggregate collapses', () {
      var now = DateTime(2026);
      final scheduler = DownloadScheduler(maxConcurrency: 8, clock: () => now);
      for (var width = 2; width <= 3; width++) {
        scheduler.beginWindow();
        for (var track = 0; track < width; track++) {
          scheduler.recordSample('t$track', 1000);
        }
        now = now.add(const Duration(seconds: 2));
        scheduler.closeWindow();
      }
      expect(scheduler.target, 3);

      // Same three tracks, but the total is now well under three quarters of
      // what it was: the link is saturated, so hand a slot back.
      scheduler.beginWindow();
      for (var track = 0; track < 3; track++) {
        scheduler.recordSample('t$track', 500);
      }
      now = now.add(const Duration(seconds: 2));
      expect(scheduler.closeWindow(), isTrue);
      expect(scheduler.target, 2);
    });

    test('stops widening once the platform ceiling is reached', () {
      var now = DateTime(2026);
      final scheduler = DownloadScheduler(maxConcurrency: 3, clock: () => now);
      for (var window = 0; window < 6; window++) {
        scheduler.beginWindow();
        for (var track = 0; track < scheduler.target; track++) {
          scheduler.recordSample('t$track', 1000 * (window + 1));
        }
        now = now.add(const Duration(seconds: 2));
        scheduler.closeWindow();
      }
      expect(scheduler.target, 3);
    });

    test('a rate limit collapses the batch to one at a time', () {
      final scheduler = DownloadScheduler(maxConcurrency: 8);
      scheduler.recordRateLimit();
      expect(scheduler.target, 1);
      expect(scheduler.rateLimited, isTrue);
    });

    test('recognises the shapes yt-dlp reports throttling in', () {
      expect(DownloadScheduler.isRateLimit('HTTP Error 429: Too Many Requests'),
          isTrue);
      expect(DownloadScheduler.isRateLimit('The uploader has been rate limited'),
          isTrue);
      expect(DownloadScheduler.isRateLimit('rate-limit reached'), isTrue);
      expect(DownloadScheduler.isRateLimit('HTTP Error 403: Forbidden'),
          isFalse);
    });

    test('a pinned width wins over every reading', () {
      var now = DateTime(2026);
      final scheduler = DownloadScheduler(
        maxConcurrency: 8,
        pinned: 4,
        clock: () => now,
      );
      expect(scheduler.isPinned, isTrue);
      expect(scheduler.target, 4);

      for (var window = 0; window < 4; window++) {
        scheduler.beginWindow();
        for (var track = 0; track < 8; track++) {
          scheduler.recordSample('t$track', 900 - window * 200);
        }
        now = now.add(const Duration(seconds: 2));
        scheduler.closeWindow();
      }
      expect(scheduler.target, 4, reason: 'readings cannot move a pinned batch');
    });

    test('a pinned width is still clamped to the platform ceiling', () {
      final scheduler = DownloadScheduler(maxConcurrency: 3, pinned: 8);
      expect(scheduler.target, 3);
    });

    test('a finished track stops counting toward the window', () {
      final scheduler = DownloadScheduler(maxConcurrency: 8);
      scheduler.recordSample('a', 1000);
      scheduler.recordSample('b', 1000);
      expect(scheduler.inFlightThroughput, 2000);
      scheduler.recordFinished('a');
      expect(scheduler.inFlightThroughput, 1000);
    });
  });
}
