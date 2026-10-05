import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:own_yute/core/app_controller.dart';
import 'package:own_yute/core/database.dart';
import 'package:own_yute/core/models.dart';
import 'package:own_yute/features/downloads/download_service.dart';
import 'package:own_yute/features/search/youtube_service.dart';

class FakeYoutube extends YoutubeService {
  @override
  Future<SearchResults> search(String query) async =>
      SearchResults(songs: [song], playlists: []);
  @override
  Future<(Track?, List<Track>)> openUrl(String value) async {
    if (!isYoutubeUrl(value)) throw const YoutubeFailure('Invalid URL');
    if (value.contains('list=')) return (null, [song]);
    return (song, <Track>[]);
  }
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
  @override
  Future<String?> download(
    Track track,
    String destination,
    DuplicateChoice duplicate,
    void Function(double) onProgress,
  ) async {
    choice = duplicate;
    if (duplicate == DuplicateChoice.skip) return null;
    final file = File('$destination/${fileName(track)}');
    await file.parent.create(recursive: true);
    await file.writeAsString('audio');
    onProgress(1);
    return file.path;
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
    void Function(double) onProgress,
  ) async => throw const DownloadFailure('yt-dlp reported HTTP 403');
}

void main() {
  test(
    'search, pasted song and playlist, queue restoration and edits',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final app = AppController(database: database, youtube: FakeYoutube());
      await app.initialize();
      await app.search('one');
      expect(app.songs.single.title, 'One');
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
    first.player.dispose();
    restored.player.dispose();
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
}
