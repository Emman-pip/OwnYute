import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_yute/core/app_controller.dart';
import 'package:own_yute/core/database.dart';
import 'package:own_yute/core/models.dart';
import 'package:own_yute/core/track_row.dart';
import 'package:own_yute/features/library/folder_page.dart';
import 'package:own_yute/features/library/library_page.dart';

const _library = [
  LibraryTrack(
    path: '/tmp/a.mp3',
    title: 'Blue Sky',
    artist: 'Aria',
    playlists: [PlaylistRef(id: 'p', title: 'Morning')],
  ),
  LibraryTrack(path: '/tmp/b.mp3', title: 'Pink Cloud', artist: 'Nova'),
];

void main() {
  testWidgets('library search filters songs in every folder view', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final app = AppController(database: database);
    app.library = _library;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LibraryPage(app: app)),
      ),
    );
    expect(find.text('Blue Sky'), findsNothing);
    expect(find.text('Pink Cloud'), findsNothing);
    await tester.enterText(find.byType(TextField), 'morning');
    await tester.pump();
    expect(find.text('Blue Sky'), findsWidgets);
    expect(find.text('Pink Cloud'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    app.dispose();
  });

  testWidgets('all songs start collapsed and multi-select expands them', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final app = AppController(database: database);
    app.library = _library;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LibraryPage(app: app)),
      ),
    );

    expect(find.text('Blue Sky'), findsNothing);
    expect(find.text('Pink Cloud'), findsNothing);
    expect(find.widgetWithText(ExpansionTile, '2 songs'), findsOneWidget);

    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();
    expect(find.text('Blue Sky'), findsWidgets);
    expect(find.text('Pink Cloud'), findsWidgets);
    expect(find.byType(Checkbox), findsNWidgets(2));
    // The bar counts the selection and offers the two bulk commands.
    expect(find.text('0 selected'), findsOneWidget);
    expect(find.byTooltip('Add selected songs to playlist'), findsOneWidget);
    expect(find.byTooltip('Delete selected songs'), findsOneWidget);

    await tester.tap(find.text('Blue Sky'));
    await tester.pump();
    expect(find.text('1 selected'), findsOneWidget);
    await tester.tap(find.text('Pink Cloud'));
    await tester.pump();
    expect(find.text('2 selected'), findsOneWidget);

    await tester.tap(find.byTooltip('Add selected songs to playlist'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Morning').last);
    await tester.pumpAndSettle();

    expect(
      app.library.every(
        (track) => track.playlists.any((playlist) => playlist.id == 'p'),
      ),
      true,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(find.text('Import folder'), findsWidgets);

    await tester.pumpWidget(const SizedBox());
    app.dispose();
  });

  testWidgets('a long press starts selecting a library song', (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final app = AppController(database: database);
    app.library = _library;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LibraryPage(app: app)),
      ),
    );
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();
    // Leave selection mode; the list stays expanded, so a long press on a row
    // has to start the selection on its own.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('0 selected'), findsNothing);
    expect(find.byType(Checkbox), findsNothing);

    await tester.longPress(find.text('Blue Sky'));
    await tester.pumpAndSettle();

    expect(find.text('1 selected'), findsOneWidget);
    expect(find.byType(Checkbox), findsNWidgets(2));
    expect(
      find.byType(TrackTile),
      findsNWidgets(2),
      reason: 'rows keep their place while selecting',
    );
    await tester.pumpWidget(const SizedBox());
    app.dispose();
  });

  testWidgets('a folder page selection bar stays clear of the songs', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final app = AppController(database: database);
    app.library = List.generate(
      40,
      (index) => LibraryTrack(
        path: '/m/$index.mp3',
        title: 'Song $index',
        folder: '/m',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: FolderPage(
          app: app,
          title: 'Album',
          resolveTracks: (app) => app.library,
        ),
      ),
    );
    await tester.pump();

    await tester.longPress(find.text('Song 0'));
    await tester.pump();

    final bar = tester.getRect(find.text('1 selected'));
    expect(bar.overlaps(tester.getRect(find.text('Song 0'))), isFalse);

    // It is pinned above the list, so scrolling cannot take it away or push it
    // over a row.
    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);
    expect(
      tester.getRect(find.text('1 selected')).top,
      bar.top,
      reason: 'the bar does not scroll with the list',
    );

    await tester.pumpWidget(const SizedBox());
    app.dispose();
  });
}
