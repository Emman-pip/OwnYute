import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_yute/core/app_controller.dart';
import 'package:own_yute/core/database.dart';
import 'package:own_yute/core/models.dart';
import 'package:own_yute/features/downloads/download_service.dart';
import 'package:own_yute/features/library/library_service.dart';
import 'package:own_yute/features/search/youtube_service.dart';

/// Records how many downloads were ever in flight at the same moment, and lets
/// a test dictate each one's outcome and how fast it reports progress.
class TrackingDownloader extends DownloadService {
  TrackingDownloader(this.folder);
  final Directory folder;
  int inFlight = 0;
  int peakInFlight = 0;
  int started = 0;
  final List<String> startedIds = [];
  final Map<String, String> failures = {};

  /// Emit throughput samples this often, so the scheduler has something to
  /// measure without the test having to wait real seconds.
  Duration sampleEvery = const Duration(milliseconds: 20);

  /// Per-track download time. Long enough for overlap to be observable.
  Duration duration = const Duration(milliseconds: 120);

  bool cancelled = false;
  int cancelledCount = 0;

  @override
  Future<String?> download(
    Track track,
    String destination,
    DuplicateChoice duplicate,
    void Function(double) onProgress, {
    void Function(TransferSample)? onSample,
  }) async {
    started++;
    startedIds.add(track.id);
    inFlight++;
    if (inFlight > peakInFlight) peakInFlight = inFlight;
    final ticks = duration.inMilliseconds ~/ sampleEvery.inMilliseconds;
    try {
      final failure = failures[track.id];
      for (var tick = 1; tick <= ticks; tick++) {
        if (cancelled) {
          cancelledCount++;
          throw const DownloadFailure('Download cancelled.');
        }
        await Future<void>.delayed(sampleEvery);
        final progress = tick / ticks;
        onProgress(progress * 0.75);
        // Report a throughput that comfortably clears the growth threshold, so
        // an automatic batch is allowed to widen.
        onSample?.call(
          TransferSample(
            bytes: tick * 100000,
            bytesPerSecond: 1000000,
            elapsed: sampleEvery * tick,
          ),
        );
      }
      if (failure != null) throw DownloadFailure(failure);
      final file = File('$destination/${fileName(track)}');
      await file.parent.create(recursive: true);
      await file.writeAsString('audio');
      onProgress(1);
      return file.path;
    } finally {
      inFlight--;
    }
  }
}

class StaticDurationLibraryService extends LibraryService {
  @override
  Future<int> readDuration(String path) async => 100;
}

/// Downloads the tracks these tests queue and nothing else.
class SilentYoutube extends YoutubeService {
  @override
  Future<SearchResults> search(
    String query, {
    int songs = 5,
    int playlists = 5,
  }) async => const SearchResults(songs: [], playlists: []);

  @override
  Future<Track?> findArtwork({
    required String title,
    String artist = '',
    String sourceTrackId = '',
  }) async => null;
}

List<Track> tracks(int count) => List.generate(
  count,
  (index) => Track(
    id: 'p$index',
    url: 'https://www.youtube.com/watch?v=p$index',
    title: 'Track $index',
    artist: 'Artist',
  ),
);

Future<AppController> controller(
  AppDatabase database,
  DownloadService downloader,
) async {
  final app = AppController(
    database: database,
    youtube: SilentYoutube(),
    downloader: downloader,
    libraryService: StaticDurationLibraryService(),
  );
  await app.initialize();
  return app;
}

void main() {
  test('a batch downloads more than one song at a time', () async {
    final directory = await Directory.systemTemp.createTemp('own_yute_par_');
    addTearDown(() => directory.delete(recursive: true));
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final downloader = TrackingDownloader(directory);
    final app = await controller(database, downloader);

    await app.addAll(tracks(8));
    await app.downloadQueue(
      directory.path,
      (_) async => DuplicateChoice.replace,
    );

    expect(
      downloader.peakInFlight,
      greaterThan(1),
      reason: 'a batch must overlap downloads rather than run them in series',
    );
    expect(downloader.started, 8);
    expect(app.queue.every((item) => item.status == 'done'), isTrue);
    expect(app.library, hasLength(8));
    app.dispose();
    await database.close();
  });

  test('a batch pinned to one stays strictly sequential', () async {
    final directory = await Directory.systemTemp.createTemp('own_yute_seq_');
    addTearDown(() => directory.delete(recursive: true));
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final downloader = TrackingDownloader(directory);
    final app = await controller(database, downloader);
    await app.setDownloadConcurrency(1);

    await app.addAll(tracks(5));
    await app.downloadQueue(
      directory.path,
      (_) async => DuplicateChoice.replace,
    );

    expect(downloader.peakInFlight, 1);
    expect(
      downloader.startedIds,
      tracks(5).map((track) => track.id).toList(),
      reason: 'queue order is preserved when the batch is pinned to one',
    );
    expect(app.queue.every((item) => item.status == 'done'), isTrue);
    app.dispose();
    await database.close();
  });

  test('one failed song does not stop the rest of the batch', () async {
    final directory = await Directory.systemTemp.createTemp('own_yute_mix_');
    addTearDown(() => directory.delete(recursive: true));
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final downloader = TrackingDownloader(directory)
      ..failures['p2'] = 'HTTP Error 404: Not Found';
    final app = await controller(database, downloader);

    await app.addAll(tracks(6));
    await app.downloadQueue(
      directory.path,
      (_) async => DuplicateChoice.replace,
    );

    final failed = app.queue.where((item) => item.status == 'failed');
    expect(failed, hasLength(1));
    expect(failed.single.track.id, 'p2');
    expect(failed.single.error, contains('404'));
    expect(app.queue.where((item) => item.status == 'done'), hasLength(5));
    app.dispose();
    await database.close();
  });

  test('duplicate prompts never overlap in a parallel batch', () async {
    final directory = await Directory.systemTemp.createTemp('own_yute_dup_');
    addTearDown(() => directory.delete(recursive: true));
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final downloader = TrackingDownloader(directory);
    final app = await controller(database, downloader);
    final batch = tracks(6);

    await app.addAll(batch);
    // Every song is already on disk, so the whole batch hits the prompt path.
    for (final track in batch) {
      File('${directory.path}/${track.title}.mp3').writeAsStringSync('old');
    }

    var open = 0;
    var peak = 0;
    await app.downloadQueue(directory.path, (path) async {
      open++;
      if (open > peak) peak = open;
      await Future<void>.delayed(const Duration(milliseconds: 30));
      open--;
      return DuplicateChoice.replace;
    });

    expect(
      peak,
      1,
      reason: 'stacked duplicate dialogs would make the choice unreadable',
    );
    expect(app.queue.every((item) => item.status == 'done'), isTrue);
    app.dispose();
    await database.close();
  });

  test('cancelling stops every download still running', () async {
    final directory = await Directory.systemTemp.createTemp(
      'own_yute_cancel_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final downloader = TrackingDownloader(directory)
      ..duration = const Duration(milliseconds: 400);
    final app = await controller(database, downloader);

    await app.addAll(tracks(8));
    await app.setDownloadConcurrency(4);
    final running = app.downloadQueue(
      directory.path,
      (_) async => DuplicateChoice.replace,
    );
    // Let the pool reach full width, then pull the plug.
    while (downloader.inFlight < 4) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    app.cancelDownloads();
    downloader.cancelled = true;
    await running;

    expect(downloader.inFlight, 0, reason: 'no worker is left running');
    expect(
      app.queue.any((item) => item.status == 'downloading'),
      isFalse,
      reason: 'a cancelled batch leaves nothing stuck mid-download',
    );
    app.dispose();
    await database.close();
  });

  test('a rate limited song drops the batch back to one at a time', () async {
    final directory = await Directory.systemTemp.createTemp('own_yute_429_');
    addTearDown(() => directory.delete(recursive: true));
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final downloader = TrackingDownloader(directory)
      ..failures['p0'] = 'HTTP Error 429: Too Many Requests';
    final app = await controller(database, downloader);

    await app.addAll(tracks(6));
    await app.downloadQueue(
      directory.path,
      (_) async => DuplicateChoice.replace,
    );

    expect(app.queue.first.status, 'failed');
    expect(app.error, contains('rate-limited'));
    // Everything after the throttle still completes, one at a time.
    expect(app.queue.where((item) => item.status == 'done'), hasLength(5));
    app.dispose();
    await database.close();
  });

  test('the chosen concurrency survives a restart', () async {
    final directory = await Directory.systemTemp.createTemp('own_yute_set_');
    addTearDown(() => directory.delete(recursive: true));
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final app = await controller(database, TrackingDownloader(directory));

    expect(app.downloadConcurrency, 'auto', reason: 'automatic by default');
    expect(app.pinnedDownloadConcurrency, isNull);

    await app.setDownloadConcurrency(4);
    final restored = await controller(database, TrackingDownloader(directory));
    expect(restored.downloadConcurrency, '4');
    expect(restored.pinnedDownloadConcurrency, 4);

    app.dispose();
    restored.dispose();
    await database.close();
  });

  test('a pinned concurrency is never wider than the platform allows', () async {
    final directory = await Directory.systemTemp.createTemp(
      'own_yute_clamp_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final app = await controller(database, TrackingDownloader(directory));

    await app.setDownloadConcurrency(99);
    expect(
      app.pinnedDownloadConcurrency,
      AppController.platformDownloadLimit,
    );
    app.dispose();
    await database.close();
  });

  test('a saved duplicate marked skipped never reaches the downloader', () async {
    final directory = await Directory.systemTemp.createTemp(
      'own_yute_skip_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final downloader = TrackingDownloader(directory);
    final app = await controller(database, downloader);

    final batch = tracks(4);
    await app.addAll(batch);
    for (final track in batch) {
      File('${directory.path}/${track.title}.mp3').writeAsStringSync('old');
    }

    await app.downloadQueue(directory.path, (_) async => DuplicateChoice.skip);

    expect(downloader.started, 0);
    expect(app.queue.every((item) => item.status == 'done'), isTrue);
    expect(app.library, isEmpty, reason: 'skipped files are not re-added');
    app.dispose();
    await database.close();
  });
}
