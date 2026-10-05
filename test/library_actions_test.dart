import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_yute/core/app_controller.dart';
import 'package:own_yute/core/database.dart';
import 'package:own_yute/core/models.dart';
import 'package:own_yute/features/downloads/download_service.dart';
import 'package:own_yute/features/library/library_actions.dart';
import 'package:own_yute/features/search/youtube_service.dart';

/// No network: the artwork path is the only thing that would reach out.
class NoArtworkYoutube extends YoutubeService {
  @override
  Future<Track?> findArtwork({
    required String title,
    String artist = '',
    String sourceTrackId = '',
  }) async => null;
}

class CoverArtworkYoutube extends YoutubeService {
  @override
  Future<Track?> findArtwork({
    required String title,
    String artist = '',
    String sourceTrackId = '',
  }) async => Track(
    id: 'matched',
    url: 'https://www.youtube.com/watch?v=matched',
    title: title,
    artist: artist,
    artwork: 'https://example.com/cover.jpg',
  );
}

/// Records the metadata writes instead of shelling out to FFmpeg.
class RecordingDownloader extends DownloadService {
  final List<LibraryTrack> edited = [];
  @override
  Future<void> editMetadata(LibraryTrack track) async => edited.add(track);
}

/// Deletes one song badly, to exercise the aggregated failure path.
class OneBadSongController extends AppController {
  OneBadSongController({required super.database, required this.badPath})
    : super(youtube: NoArtworkYoutube());

  final String badPath;

  @override
  Future<void> deleteSong(LibraryTrack track) async {
    if (track.path == badPath) {
      throw const FileSystemException('Could not delete the file');
    }
    await super.deleteSong(track);
  }
}

/// A library song backed by a real file on disk.
Future<LibraryTrack> _savedSong(
  Directory directory,
  String name, {
  List<PlaylistRef> playlists = const [],
}) async {
  final file = File('${directory.path}/$name');
  await file.writeAsString('audio');
  return LibraryTrack(
    path: file.path,
    title: name,
    artist: 'Artist',
    folder: directory.path,
    folderName: 'Music',
    playlists: playlists,
  );
}

void main() {
  test('a bulk delete removes the files and every library reference', () async {
    final directory = await Directory.systemTemp.createTemp('own_yute_bulk_');
    addTearDown(() => directory.delete(recursive: true));
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final app = AppController(database: database, youtube: NoArtworkYoutube());
    final first = await _savedSong(directory, 'first.mp3');
    final second = await _savedSong(
      directory,
      'second.mp3',
      playlists: const [PlaylistRef(id: 'shared', title: 'Shared')],
    );
    final third = await _savedSong(directory, 'third.mp3');
    app.library = [first, second, third];
    for (final song in app.library) {
      await database.saveLibrary(song);
    }
    // Queued and playing, so the cleanup paths run too.
    app.player.addToQueue(
      const Track(id: 'queued', url: '/tmp/queued.mp3', title: 'Queued'),
    );
    app.player.addLibraryToQueue(second);
    app.player.addLibraryToQueue(third);

    await app.deleteSongs([first, second]);

    expect(await File(first.path).exists(), false);
    expect(await File(second.path).exists(), false);
    // Untouched songs stay put.
    expect(await File(third.path).exists(), true);
    expect(app.library.map((song) => song.title), ['third.mp3']);
    expect((await database.loadLibrary()).map((song) => song.title), [
      'third.mp3',
    ]);
    // A song that is also in a playlist folder leaves that folder empty
    // rather than keeping a dangling reference.
    expect(app.playlistFolders, isEmpty);
    // The deleted songs left the playback queue.
    expect(app.player.queue.map((track) => track.url), [
      '/tmp/queued.mp3',
      third.path,
    ]);
    expect(app.deletingTotal, 0, reason: 'the progress line is cleared');
    app.dispose();
  });

  test('per-song failures are aggregated into one error', () async {
    final directory = await Directory.systemTemp.createTemp('own_yute_fail_');
    addTearDown(() => directory.delete(recursive: true));
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final broken = await _savedSong(directory, 'broken.mp3');
    final fine = await _savedSong(directory, 'fine.mp3');
    final app = OneBadSongController(database: database, badPath: broken.path);
    app.library = [broken, fine];

    await expectLater(
      app.deleteSongs([broken, fine]),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          allOf(contains('1 songs'), contains('broken.mp3')),
        ),
      ),
    );

    // The good song is still deleted even though its neighbour failed.
    expect(await File(fine.path).exists(), false);
    expect(app.library.map((song) => song.title), ['broken.mp3']);
    expect(app.deletingTotal, 0);
    app.dispose();
  });

  test('removing a storage folder from the library keeps the audio', () async {
    final directory = await Directory.systemTemp.createTemp('own_yute_keep_');
    addTearDown(() => directory.delete(recursive: true));
    final other = await Directory.systemTemp.createTemp('own_yute_other_');
    addTearDown(() => other.delete(recursive: true));
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    await database.saveSetting('folders', directory.path);
    final app = AppController(database: database, youtube: NoArtworkYoutube());
    await app.initialize();
    final kept = await _savedSong(directory, 'kept.mp3');
    final elsewhere = await _savedSong(other, 'elsewhere.mp3');
    app.library = [kept, elsewhere];
    await database.saveLibrary(kept);
    await database.saveLibrary(elsewhere);
    expect(app.importedFolders, contains(directory.path));

    await app.deleteStorageFolder(directory.path, deleteFiles: false);

    expect(await File(kept.path).exists(), true, reason: 'the audio stays');
    expect(app.library.map((song) => song.title), ['elsewhere.mp3']);
    expect((await database.loadLibrary()).map((song) => song.title), [
      'elsewhere.mp3',
    ]);
    // An imported folder also stops being scanned, or a refresh would bring
    // the removed songs straight back.
    expect(app.importedFolders, isNot(contains(directory.path)));
    expect(await database.setting('folders'), isNot(contains(directory.path)));
    app.dispose();
  });

  test('deleting a storage folder removes the audio and the entries', () async {
    final directory = await Directory.systemTemp.createTemp('own_yute_gone_');
    addTearDown(() => directory.delete(recursive: true));
    final other = await Directory.systemTemp.createTemp('own_yute_other2_');
    addTearDown(() => other.delete(recursive: true));
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final app = AppController(database: database, youtube: NoArtworkYoutube());
    final gone = await _savedSong(
      directory,
      'gone.mp3',
      playlists: const [PlaylistRef(id: 'mix', title: 'Mix')],
    );
    final elsewhere = await _savedSong(other, 'elsewhere.mp3');
    app.library = [gone, elsewhere];
    await database.saveLibrary(gone);
    await database.saveLibrary(elsewhere);
    app.player.addLibraryToQueue(gone);
    app.player.addLibraryToQueue(elsewhere);

    await app.deleteStorageFolder(directory.path, deleteFiles: true);

    expect(await File(gone.path).exists(), false);
    expect(app.library.map((song) => song.title), ['elsewhere.mp3']);
    expect(app.player.queue.map((track) => track.url), [elsewhere.path]);
    app.dispose();
  });

  testWidgets('the folder delete names the songs shared with a playlist', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final app = AppController(database: database, youtube: NoArtworkYoutube());
    const folder = '/music/Album';
    app.library = const [
      LibraryTrack(
        path: '/music/Album/a.mp3',
        title: 'Solo song',
        folder: folder,
      ),
      LibraryTrack(
        path: '/music/Album/b.mp3',
        title: 'Shared song',
        folder: folder,
        playlists: [PlaylistRef(id: 'mix', title: 'Mix')],
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => confirmDeleteStorageFolder(context, app, folder),
              child: const Text('Delete folder'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Delete folder'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Remove 2 songs from the library?'),
      findsOneWidget,
    );
    expect(
      find.textContaining('1 song is also in a playlist folder'),
      findsOneWidget,
    );
    expect(find.text('Remove from library'), findsOneWidget);
    expect(find.text('Delete files'), findsOneWidget);

    // Removing from the library is the non-destructive choice.
    await tester.tap(find.text('Remove from library'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(app.library, hasLength(2), reason: 'the dialog only asks');

    await tester.pumpWidget(const SizedBox());
    app.dispose();
  });

  test('a per-song artwork search embeds the cover it finds', () async {
    final directory = await Directory.systemTemp.createTemp('own_yute_art_');
    addTearDown(() => directory.delete(recursive: true));
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final downloader = RecordingDownloader();
    final app = AppController(
      database: database,
      youtube: CoverArtworkYoutube(),
      downloader: downloader,
    );
    await app.initialize();
    final song = await _savedSong(directory, 'song.mp3');
    app.library = [song];
    await database.saveLibrary(song);

    await app.lookupArtwork(song);

    expect(app.library.single.artwork, contains('cover.jpg'));
    expect(downloader.edited.single.path, song.path);
    expect(downloader.edited.single.artwork, contains('cover.jpg'));
    expect(
      (await database.loadLibrary()).single.artwork,
      contains('cover.jpg'),
    );
    app.dispose();
  });

  test('a folder artwork search covers every song in the folder', () async {
    final directory = await Directory.systemTemp.createTemp('own_yute_artdir_');
    addTearDown(() => directory.delete(recursive: true));
    final other = await Directory.systemTemp.createTemp('own_yute_artother_');
    addTearDown(() => other.delete(recursive: true));
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final downloader = RecordingDownloader();
    final app = AppController(
      database: database,
      youtube: CoverArtworkYoutube(),
      downloader: downloader,
    );
    await app.initialize();
    final inFolder = await _savedSong(directory, 'one.mp3');
    final alsoInFolder = await _savedSong(directory, 'two.mp3');
    final outside = await _savedSong(other, 'three.mp3');
    app.library = [inFolder, alsoInFolder, outside];
    for (final song in app.library) {
      await database.saveLibrary(song);
    }

    await app.lookupFolderArtwork(directory.path);

    expect(
      app.library
          .where((song) => song.artwork.contains('cover.jpg'))
          .map((song) => song.title),
      containsAll(['one.mp3', 'two.mp3']),
    );
    expect(app.library.singleWhere((s) => s.title == 'three.mp3').artwork, '');
    expect(downloader.edited, hasLength(2));
    expect(app.artworkLookupUpdated, 2);
    expect(app.artworkLookupRunning, isFalse);
    app.dispose();
  });

  testWidgets('a bulk delete confirmation names the shared songs', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final app = AppController(database: database, youtube: NoArtworkYoutube());
    const songs = [
      LibraryTrack(path: '/music/a.mp3', title: 'Solo song'),
      LibraryTrack(
        path: '/music/b.mp3',
        title: 'In a playlist',
        playlists: [PlaylistRef(id: 'mix', title: 'Mix')],
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => deleteSelectedSongs(context, app, songs),
              child: const Text('Delete selected'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Delete selected'));
    await tester.pumpAndSettle();

    expect(find.text('Delete 2 songs?'), findsOneWidget);
    expect(find.textContaining('2 audio files'), findsOneWidget);
    expect(
      find.textContaining('1 song is also in a playlist folder'),
      findsOneWidget,
    );
    expect(find.textContaining('In a playlist'), findsOneWidget);
    expect(app.library, isEmpty, reason: 'nothing is deleted before the ask');

    await tester.pumpWidget(const SizedBox());
    app.dispose();
  });

  testWidgets('adding a song to a playlist folder confirms it', (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final app = AppController(database: database, youtube: NoArtworkYoutube());
    // Folders are derived from the playlists songs already carry, so an
    // existing entry is what puts "Mix" in the picker.
    app.library = const [
      LibraryTrack(path: '/music/a.mp3', title: 'Solo song'),
      LibraryTrack(
        path: '/music/b.mp3',
        title: 'Other song',
        playlists: [PlaylistRef(id: 'mix', title: 'Mix')],
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  assignTrackToPlaylist(context, app, app.library.first),
              child: const Text('Assign'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Assign'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mix'));
    await tester.pumpAndSettle();

    // The row command gives no other sign that it worked.
    expect(find.text('Added Solo song to Mix.'), findsOneWidget);
    expect(app.library.first.playlists.single.title, 'Mix');

    await tester.pumpWidget(const SizedBox());
    app.dispose();
  });

  testWidgets('cancelling the folder picker changes nothing', (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final app = AppController(database: database, youtube: NoArtworkYoutube());
    app.library = const [
      LibraryTrack(path: '/music/a.mp3', title: 'Solo song'),
      LibraryTrack(
        path: '/music/b.mp3',
        title: 'Other song',
        playlists: [PlaylistRef(id: 'mix', title: 'Mix')],
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  assignTrackToPlaylist(context, app, app.library.first),
              child: const Text('Assign'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Assign'));
    await tester.pumpAndSettle();
    expect(find.text('Mix'), findsOneWidget, reason: 'the picker is open');
    // The picker is dismissed by tapping outside it, not a Cancel button.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(app.library.first.playlists, isEmpty);
    expect(
      find.textContaining('Added'),
      findsNothing,
      reason: 'a cancelled choice must not claim success',
    );

    await tester.pumpWidget(const SizedBox());
    app.dispose();
  });
}
