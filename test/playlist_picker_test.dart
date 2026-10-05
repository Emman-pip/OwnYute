import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_yute/core/app_controller.dart';
import 'package:own_yute/core/database.dart';
import 'package:own_yute/core/models.dart';
import 'package:own_yute/core/track_row.dart';
import 'package:own_yute/core/ui_helpers.dart';

List<Track> _tracks(int count, {int titleLength = 20}) => List.generate(
  count,
  (index) => Track(
    id: 'track-$index',
    url: 'https://www.youtube.com/watch?v=track-$index',
    title: 'Song $index ${'long ' * titleLength}'.trim(),
    artist: 'Artist $index',
  ),
);

/// Hosts the picker. [reducedMotion] keeps rows static so the dialog can be
/// settled normally; without it a truncated title scrolls forever and the
/// dialog never reaches a quiet frame.
Widget _host(
  AppController app,
  List<Track> tracks, {
  bool reducedMotion = true,
}) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reducedMotion),
    child: child!,
  ),
  home: Scaffold(
    body: Builder(
      builder: (context) => TextButton(
        onPressed: () => showPlaylistDialog(context, app, tracks, () {}),
        child: const Text('Open playlist'),
      ),
    ),
  ),
);

/// Pumps a fixed window instead of `pumpAndSettle`, for a tree that includes a
/// scrolling marquee and therefore never settles.
Future<void> _pumpWindow(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  testWidgets('a tap and a long press both toggle a track', (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final app = AppController(database: database);
    await tester.pumpWidget(_host(app, _tracks(3)));
    await tester.tap(find.text('Open playlist'));
    await tester.pumpAndSettle();

    expect(find.text('Choose tracks (0/3)'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Add selected'),
          )
          .onPressed,
      isNull,
      reason: 'nothing chosen yet',
    );

    await tester.tap(find.textContaining('Song 0 '));
    await tester.pump();
    expect(find.text('Choose tracks (1/3)'), findsOneWidget);

    await tester.longPress(find.textContaining('Song 1 '));
    await tester.pump();
    expect(find.text('Choose tracks (2/3)'), findsOneWidget);
    expect(find.byType(Checkbox), findsNWidgets(3));

    // Tapping the checkbox itself goes through the same callback.
    await tester.tap(find.byType(Checkbox).at(2));
    await tester.pump();
    expect(find.text('Choose tracks (3/3)'), findsOneWidget);

    // And back off again.
    await tester.tap(find.byType(Checkbox).at(2));
    await tester.pump();
    expect(find.text('Choose tracks (2/3)'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    app.dispose();
  });

  testWidgets('select all then add the selection to the download queue', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final app = AppController(database: database);
    await tester.pumpWidget(_host(app, _tracks(3)));
    await tester.tap(find.text('Open playlist'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Select all'));
    await tester.pump();
    expect(find.text('Choose tracks (3/3)'), findsOneWidget);
    expect(find.text('Clear all'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Add selected'),
          )
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.text('Add selected'));
    await tester.pumpAndSettle();
    expect(app.queue.map((item) => item.track.id), [
      'track-0',
      'track-1',
      'track-2',
    ]);
    expect(find.text('Choose tracks (3/3)'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    app.dispose();
  });

  testWidgets('previewing plays only the chosen tracks', (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final app = AppController(database: database);
    await tester.pumpWidget(_host(app, _tracks(3)));
    await tester.tap(find.text('Open playlist'));
    await tester.pumpAndSettle();

    // Choose the first and last, skipping the middle one.
    await tester.tap(find.textContaining('Song 0 '));
    await tester.pump();
    await tester.tap(find.textContaining('Song 2 '));
    await tester.pump();
    expect(find.text('Choose tracks (2/3)'), findsOneWidget);

    // Nothing downloaded: preview is a playback action, not a queue action.
    await tester.tap(find.text('Preview selected'));
    await tester.pumpAndSettle();
    expect(app.queue, isEmpty, reason: 'preview must not queue a download');
    expect(
      app.player.current?.id,
      'track-0',
      reason: 'starts at the first pick',
    );
    expect(app.player.queue.map((track) => track.id), [
      'track-0',
      'track-2',
    ], reason: 'only the selection, in playlist order');
    expect(find.text('Choose tracks (2/3)'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    app.dispose();
  });

  testWidgets('previewing is unavailable until something is chosen', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final app = AppController(database: database);
    await tester.pumpWidget(_host(app, _tracks(3)));
    await tester.tap(find.text('Open playlist'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Preview selected'),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(find.text('Select all'));
    await tester.pump();
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Preview selected'),
          )
          .onPressed,
      isNotNull,
    );

    await tester.pumpWidget(const SizedBox());
    app.dispose();
  });

  testWidgets('a 200 character title stays inside a 320 by 360 picker', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final app = AppController(database: database);
    // Reduced motion off: these titles scroll, and scrolling rows must still
    // fit a short viewport.
    await tester.pumpWidget(
      _host(app, _tracks(30, titleLength: 40), reducedMotion: false),
    );
    await tester.tap(find.text('Open playlist'));
    await _pumpWindow(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Choose tracks (0/30)'), findsOneWidget);
    expect(find.text('Select all'), findsOneWidget);
    expect(find.byType(TrackTile), findsWidgets);

    await tester.pumpWidget(const SizedBox());
    app.dispose();
  });
}
