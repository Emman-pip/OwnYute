import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_yute/core/app_controller.dart';
import 'package:own_yute/core/database.dart';
import 'package:own_yute/core/models.dart';
import 'package:own_yute/features/library/library_page.dart';

void main() {
  testWidgets('library search filters songs in every folder view', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final app = AppController(database: database);
    app.library = const [
      LibraryTrack(
        path: '/tmp/a.mp3',
        title: 'Blue Sky',
        artist: 'Aria',
        playlists: [PlaylistRef(id: 'p', title: 'Morning')],
      ),
      LibraryTrack(path: '/tmp/b.mp3', title: 'Pink Cloud', artist: 'Nova'),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LibraryPage(app: app)),
      ),
    );
    expect(find.text('Blue Sky'), findsWidgets);
    expect(find.text('Pink Cloud'), findsWidgets);
    await tester.enterText(find.byType(TextField), 'morning');
    await tester.pump();
    expect(find.text('Blue Sky'), findsWidgets);
    expect(find.text('Pink Cloud'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    app.dispose();
  });

  testWidgets('all songs stay open and multi-select adds them to a playlist', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final app = AppController(database: database);
    app.library = const [
      LibraryTrack(
        path: '/tmp/a.mp3',
        title: 'Blue Sky',
        artist: 'Aria',
        playlists: [PlaylistRef(id: 'p', title: 'Morning')],
      ),
      LibraryTrack(path: '/tmp/b.mp3', title: 'Pink Cloud', artist: 'Nova'),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LibraryPage(app: app)),
      ),
    );

    expect(find.text('Blue Sky'), findsWidgets);
    expect(find.text('Pink Cloud'), findsWidgets);
    expect(find.widgetWithText(ExpansionTile, '2 songs'), findsNothing);
    expect(find.text('Import folder'), findsNothing);

    await tester.tap(find.text('Select'));
    await tester.pump();
    expect(find.byType(Checkbox), findsNWidgets(2));
    await tester.tap(find.text('Select all visible songs'));
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
}
