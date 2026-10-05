import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_yute/core/app_controller.dart';
import 'package:own_yute/core/database.dart';
import 'package:own_yute/core/models.dart';
import 'package:own_yute/core/ui_helpers.dart';
import 'package:own_yute/main.dart';

void main() {
  testWidgets('pastel theme choice recolors the app immediately', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final app = AppController(database: database);
    await app.initialize();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appProvider.overrideWithValue(app)],
        child: const OwnYuteApp(),
      ),
    );
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pastel Blue'));
    await tester.pumpAndSettle();
    final blue = tester.widget<MaterialApp>(find.byType(MaterialApp)).theme!;
    expect(blue.colorScheme.primary, const Color(0xff4d78a8));
    expect(blue.scaffoldBackgroundColor, const Color(0xfff0f7ff));

    await tester.tap(find.text('Pastel Pink'));
    await tester.pumpAndSettle();
    final pink = tester.widget<MaterialApp>(find.byType(MaterialApp)).theme!;
    expect(pink.colorScheme.primary, const Color(0xffaa5279));
    expect(pink.scaffoldBackgroundColor, const Color(0xfffff1f7));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    app.dispose();
  });

  testWidgets('queue title can wrap on a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const longTitle =
        'A very long YouTube song title with an extended description and many words that must remain visible in the download queue';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TrackTile(
            track: Track(
              id: 'long',
              url: 'https://youtube.com/watch?v=long',
              title: longTitle,
            ),
            fullTitle: true,
            onTap: _noop,
          ),
        ),
      ),
    );
    final title = tester.widget<Text>(find.text(longTitle));
    expect(title.maxLines, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone layout opens all destinations and dark settings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final database = AppDatabase.forTesting(NativeDatabase.memory());
    await database.saveQueue(
      const QueueItem(
        status: 'failed',
        error: 'A long download error that needs to wrap on a phone screen.',
        track: Track(
          id: 'track',
          url: 'https://www.youtube.com/watch?v=track',
          title: 'A long track title that must fit on a narrow phone screen',
        ),
      ),
    );
    final app = AppController(database: database);
    await app.initialize();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appProvider.overrideWithValue(app)],
        child: const OwnYuteApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Queue').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Library').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(app.themeMode, ThemeMode.dark);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    await database.close();
  });

  testWidgets('playlist picker fits a short phone viewport', (tester) async {
    tester.view.physicalSize = const Size(320, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final app = AppController(database: database);
    final tracks = List.generate(
      30,
      (index) => Track(
        id: '$index',
        url: 'https://www.youtube.com/watch?v=$index',
        title: 'A long playlist song title $index',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showPlaylistDialog(context, app, tracks, () {}),
              child: const Text('Open playlist'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open playlist'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Select all'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    app.dispose();
  });
}

void _noop() {}
