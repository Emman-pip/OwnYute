import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:own_yute/core/app_controller.dart';
import 'package:own_yute/core/database.dart';
import 'package:own_yute/core/models.dart';
import 'package:own_yute/features/downloads/download_service.dart';
import 'package:own_yute/features/library/library_service.dart';
import 'package:own_yute/features/search/youtube_service.dart';

class FakeYoutube extends YoutubeService {
  int fullSearches = 0;
  @override
  Future<SearchResults> search(
    String query, {
    int songs = 5,
    int playlists = 5,
  }) async {
    if (songs == 0 || playlists == 0) fullSearches++;
    final allSongs = List.generate(
      12,
      (index) => Track(
        id: 'song-$index',
        url: 'https://www.youtube.com/watch?v=song-$index',
        title: 'Song $index',
      ),
    );
    final allPlaylists = List.generate(
      20,
      (index) => Track(
        id: 'playlist-$index',
        url: 'https://www.youtube.com/playlist?list=playlist-$index',
        title: 'Playlist $index',
      ),
    );
    return SearchResults(
      songs: songs == 0 ? allSongs : allSongs.take(songs).toList(),
      playlists: playlists == 0
          ? allPlaylists
          : allPlaylists.take(playlists).toList(),
      songsTotal: allSongs.length,
      playlistsTotal: allPlaylists.length,
    );
  }

  @override
  Future<(Track?, List<Track>)> openUrl(String value) async {
    if (!isYoutubeUrl(value)) throw const YoutubeFailure('Invalid URL');
    if (value.contains('list=')) return (null, [song]);
    return (song, <Track>[]);
  }

  @override
  Future<Track?> findArtwork({
    required String title,
    String artist = '',
    String sourceTrackId = '',
  }) async => null;
}

class FakeArtworkYoutube extends FakeYoutube {
  @override
  Future<Track?> findArtwork({
    required String title,
    String artist = '',
    String sourceTrackId = '',
  }) async => Track(
    id: sourceTrackId.isEmpty ? 'matched' : sourceTrackId,
    url: 'https://www.youtube.com/watch?v=matched',
    title: title,
    artist: artist,
    artwork: 'https://example.com/cover.jpg',
  );
}

const song = Track(
  id: 'one',
  url: 'https://www.youtube.com/watch?v=one',
  title: 'One',
);

class FakeDownloader extends DownloadService {
  FakeDownloader(this.folder);
  final Directory folder;
  DuplicateChoice? choice;
  Track? downloadedTrack;
  @override
  Future<String?> download(
    Track track,
    String destination,
    DuplicateChoice duplicate,
    void Function(double) onProgress, {
    void Function(TransferSample)? onSample,
  }) async {
    choice = duplicate;
    downloadedTrack = track;
    if (duplicate == DuplicateChoice.skip) return null;
    final file = File('$destination/${fileName(track)}');
    await file.parent.create(recursive: true);
    await file.writeAsString('audio');
    onProgress(1);
    return file.path;
  }
}

class FakeLibraryService extends LibraryService {
  FakeLibraryService(this.durations);
  final Map<String, int> durations;
  final List<String> read = [];

  @override
  Future<int> readDuration(String path) async {
    read.add(path);
    return durations[path] ?? 0;
  }
}

class ArtworkEditDownloader extends DownloadService {
  LibraryTrack? editedTrack;

  @override
  Future<void> editMetadata(LibraryTrack track) async {
    editedTrack = track;
  }
}

class FailingEditDownloader extends DownloadService {
  @override
  Future<void> editMetadata(LibraryTrack track) async =>
      throw const DownloadFailure('Could not write edited file');
}

class FailingDownloader extends DownloadService {
  @override
  Future<String?> download(
    Track track,
    String destination,
    DuplicateChoice duplicate,
    void Function(double) onProgress, {
    void Function(TransferSample)? onSample,
  }) async => throw const DownloadFailure('yt-dlp reported HTTP 403');
}

void main() {
  test(
    'search, pasted song and playlist, queue restoration and edits',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final app = AppController(database: database, youtube: FakeYoutube());
      await app.initialize();
      await app.search('one');
      expect(app.songs, isNotEmpty);
      expect(app.playlists, isNotEmpty);
      expect((await app.openUrl(song.url))?.id, 'one');
      expect(
        await app.openUrl('https://www.youtube.com/playlist?list=abc'),
        isNull,
      );
      expect(app.picker.single.id, 'one');
      await app.addAll(app.picker);
      await app.add(song);
      expect(app.queue, hasLength(1));
      await app.editQueue(song.copyWith(title: 'Edited'));
      final restored = AppController(
        database: database,
        youtube: FakeYoutube(),
      );
      await restored.initialize();
      expect(restored.queue.single.track.title, 'Edited');
      expect(restored.history.single.id, 'one');
      app.player.dispose();
      restored.player.dispose();
      await database.close();
    },
  );

  test('staged search loads a small first batch and pages on demand', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final youtube = FakeYoutube();
    final app = AppController(database: database, youtube: youtube);
    AppController.revealDelay = Duration.zero;
    addTearDown(
      () => AppController.revealDelay = const Duration(milliseconds: 250),
    );
    await app.initialize();
    await app.search('music');
    expect(app.songs, hasLength(5));
    expect(app.playlists, hasLength(5));
    expect(app.songsExhausted, isFalse);
    expect(app.playlistsExhausted, isFalse);
    expect(youtube.fullSearches, 0);

    await app.loadMoreSongs();
    expect(youtube.fullSearches, 1);
    expect(app.songs, hasLength(12));
    expect(app.songsExhausted, isTrue);
    await app.loadMoreSongs();
    expect(app.songs, hasLength(12));
    expect(youtube.fullSearches, 1);

    await app.loadMorePlaylists();
    expect(app.playlists, hasLength(20));
    expect(app.playlistsExhausted, isTrue);
    expect(youtube.fullSearches, 2);

    await app.search('other');
    expect(app.songs, hasLength(5));
    expect(app.playlists, hasLength(5));
    expect(app.songsExhausted, isFalse);
    expect(youtube.fullSearches, 2);
    app.player.dispose();
    await database.close();
  });

  test('invalid URL reports a useful error', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final app = AppController(database: database, youtube: FakeYoutube());
    await app.initialize();
    expect(await app.openUrl('https://example.com/not-youtube'), isNull);
    expect(app.error, contains('Invalid URL'));
    app.dispose();
  });

  test('duplicate skip and completed download are recorded', () async {
    final directory = await Directory.systemTemp.createTemp('own_yute_test_');
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final downloader = FakeDownloader(directory);
    final app = AppController(
      database: database,
      youtube: FakeYoutube(),
      downloader: downloader,
    );
    await app.initialize();
    await app.add(song);
    final existing = File('${directory.path}/One.mp3');
    await existing.writeAsString('original');
    await app.downloadQueue(directory.path, (_) async => DuplicateChoice.skip);
    expect(await existing.readAsString(), 'original');
    expect(app.queue.single.status, 'done');
    expect(app.library, isEmpty);
    await app.remove(song.id);
    await app.add(song);
    await app.downloadQueue(
      directory.path,
      (_) async => DuplicateChoice.replace,
    );
    expect(app.library.single.path, existing.path);
    app.dispose();
    await directory.delete(recursive: true);
  });

  test('theme choice is restored after restart', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final first = AppController(database: database, youtube: FakeYoutube());
    await first.initialize();
    expect(first.themeMode, ThemeMode.system);
    await first.setThemeMode(ThemeMode.dark);
    await first.setThemeChoice(AppThemeChoice.pastelPink);
    await first.setPlayerAnimationEnabled(false);
    final restored = AppController(database: database, youtube: FakeYoutube());
    await restored.initialize();
    expect(restored.themeMode, ThemeMode.light);
    expect(restored.themeChoice, AppThemeChoice.pastelPink);
    expect(restored.playerAnimationEnabled, false);
    expect(restored.automaticArtworkLookup, true);
    await restored.setAutomaticArtworkLookup(false);
    final artworkSetting = AppController(
      database: database,
      youtube: FakeYoutube(),
    );
    await artworkSetting.initialize();
    expect(artworkSetting.automaticArtworkLookup, false);
    first.player.dispose();
    restored.player.dispose();
    artworkSetting.player.dispose();
    await database.close();
  });

  test('complementary dark themes use dark mode and persist', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final first = AppController(database: database, youtube: FakeYoutube());
    await first.initialize();

    await first.setThemeChoice(AppThemeChoice.darkBlue);
    expect(first.themeMode, ThemeMode.dark);
    await first.setThemeChoice(AppThemeChoice.darkPink);
    expect(first.themeMode, ThemeMode.dark);

    final restored = AppController(database: database, youtube: FakeYoutube());
    await restored.initialize();
    expect(restored.themeChoice, AppThemeChoice.darkPink);
    expect(restored.themeMode, ThemeMode.dark);

    first.player.dispose();
    restored.player.dispose();
    await database.close();
  });

  test(
    'playlist batches share a single download and clear finished rows only',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'own_yute_batches_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final app = AppController(
        database: database,
        youtube: FakeYoutube(),
        downloader: FakeDownloader(directory),
      );
      await app.initialize();
      await app.addAll([
        song,
      ], playlist: const PlaylistRef(id: 'a', title: 'First'));
      await app.addAll([
        song,
      ], playlist: const PlaylistRef(id: 'b', title: 'Second'));
      expect(app.queue, hasLength(1));
      expect(app.queue.single.batches, hasLength(2));
      await app.assignQueuedToPlaylist(
        song.id,
        const PlaylistRef(id: 'custom', title: 'My songs'),
      );
      expect(app.queue.single.targetPlaylists.single.id, 'custom');
      await app.downloadQueue(
        directory.path,
        (_) async => DuplicateChoice.replace,
      );
      expect(
        app.library.single.playlists.map((item) => item.id),
        containsAll(['a', 'b', 'custom']),
      );
      await app.clearFinished();
      expect(app.queue, isEmpty);
      expect(app.library, hasLength(1));
      expect(await File(app.library.single.path).exists(), true);
      await app.addAll([
        song,
      ], playlist: const PlaylistRef(id: 'c', title: 'Third'));
      expect(app.queue, isEmpty);
      expect(
        app.library.single.playlists.map((item) => item.id),
        containsAll(['a', 'b', 'c']),
      );
      app.dispose();
    },
  );

  test(
    'deleting a playlist removes its audio files and library entries',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'own_yute_delete_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final app = AppController(database: database, youtube: FakeYoutube());
      final file = File('${directory.path}/song.mp3');
      await file.writeAsString('audio');
      final track = LibraryTrack(
        path: file.path,
        title: 'Song',
        playlists: const [
          PlaylistRef(id: 'first', title: 'First'),
          PlaylistRef(id: 'second', title: 'Second'),
        ],
      );
      app.library = [track];
      await database.saveLibrary(track);
      await app.add(song);
      await app.assignQueuedToPlaylist(
        song.id,
        const PlaylistRef(id: 'first', title: 'First'),
      );
      await app.deletePlaylist(const PlaylistRef(id: 'first', title: 'First'));
      expect(await file.exists(), false);
      expect(app.library, isEmpty);
      expect(await database.loadLibrary(), isEmpty);
      expect(app.queue.single.targetPlaylists, isEmpty);
      app.dispose();
    },
  );

  test('failed metadata edit keeps the original library entry', () async {
    final directory = await Directory.systemTemp.createTemp('own_yute_edit_');
    addTearDown(() => directory.delete(recursive: true));
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final file = File('${directory.path}/song.mp3');
    await file.writeAsString('original');
    final original = LibraryTrack(path: file.path, title: 'Before');
    await database.saveLibrary(original);
    final app = AppController(
      database: database,
      youtube: FakeYoutube(),
      downloader: FailingEditDownloader(),
    );
    await app.initialize();
    await expectLater(
      app.editLibrary(original, original.copyWith(title: 'After')),
      throwsA(isA<DownloadFailure>()),
    );
    expect(app.library.single.title, 'Before');
    expect((await database.loadLibrary()).single.title, 'Before');
    expect(await file.readAsString(), 'original');
    app.dispose();
  });

  test('download tool failure remains visible and retryable', () async {
    final directory = await Directory.systemTemp.createTemp(
      'own_yute_failure_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final app = AppController(
      database: database,
      youtube: FakeYoutube(),
      downloader: FailingDownloader(),
    );
    await app.initialize();
    await app.add(song);
    await app.downloadQueue(
      directory.path,
      (_) async => DuplicateChoice.replace,
    );
    expect(app.queue.single.status, 'failed');
    expect(app.queue.single.error, contains('HTTP 403'));
    app.dispose();
  });

  test('download-time artwork lookup is best effort and persisted', () async {
    final directory = await Directory.systemTemp.createTemp('own_yute_art_');
    addTearDown(() => directory.delete(recursive: true));
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final downloader = FakeDownloader(directory);
    final app = AppController(
      database: database,
      youtube: FakeArtworkYoutube(),
      downloader: downloader,
    );
    await app.initialize();
    await app.add(song);
    await app.downloadQueue(
      directory.path,
      (_) async => DuplicateChoice.replace,
    );
    expect(downloader.downloadedTrack?.artwork, contains('cover.jpg'));
    expect(app.library.single.artwork, contains('cover.jpg'));
    app.dispose();
  });

  test(
    'a download records the real file duration when search gave none',
    () async {
      final directory = await Directory.systemTemp.createTemp('own_yute_dur_');
      addTearDown(() => directory.delete(recursive: true));
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final saved = File('${directory.path}/One.mp3');
      final libraryService = FakeLibraryService({saved.path: 187});
      final app = AppController(
        database: database,
        youtube: FakeYoutube(),
        downloader: FakeDownloader(directory),
        libraryService: libraryService,
      );
      await app.initialize();
      await app.add(song);
      await app.downloadQueue(
        directory.path,
        (_) async => DuplicateChoice.replace,
      );

      expect(app.library.single.duration, 187);
      expect((await database.loadLibrary()).single.duration, 187);
      expect(libraryService.read, contains(saved.path));
      app.dispose();
    },
  );

  test('refresh repairs library entries saved without a duration', () async {
    final directory = await Directory.systemTemp.createTemp('own_yute_rep_');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/song.mp3');
    await file.writeAsString('audio');
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    await database.saveLibrary(
      LibraryTrack(path: file.path, title: 'Song', sourceTrackId: 'one'),
    );
    final libraryService = FakeLibraryService({file.path: 240});
    final app = AppController(
      database: database,
      youtube: FakeYoutube(),
      libraryService: libraryService,
    );

    // initialize() probes missing durations through refreshLibrary().
    await app.initialize();

    expect(app.library.single.duration, 240);
    expect((await database.loadLibrary()).single.duration, 240);
    expect(libraryService.read, contains(file.path));
    app.dispose();
  });

  test(
    'missing library artwork updates display data and audio metadata',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'own_yute_art_edit_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/song.mp3');
      await file.writeAsString('audio');
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      await database.saveSetting('automaticArtworkLookup', 'false');
      await database.saveLibrary(
        LibraryTrack(
          path: file.path,
          title: 'One',
          artist: 'Artist',
          sourceTrackId: 'one',
        ),
      );
      final downloader = ArtworkEditDownloader();
      final app = AppController(
        database: database,
        youtube: FakeArtworkYoutube(),
        downloader: downloader,
      );
      await app.initialize();

      await app.lookupMissingArtwork();

      expect(app.library.single.artwork, contains('cover.jpg'));
      expect(downloader.editedTrack?.artwork, contains('cover.jpg'));
      expect(
        (await database.loadLibrary()).single.artwork,
        contains('cover.jpg'),
      );
      app.dispose();
    },
  );
}
