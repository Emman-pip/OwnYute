import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_yute/core/marquee_text.dart';
import 'package:own_yute/core/track_row.dart';

const _long =
    'A very long song title that certainly does not fit inside a narrow row '
    'on a phone and has to travel to stay readable';

Widget _host(Widget child, {double width = 220, bool reducedMotion = false}) =>
    MaterialApp(
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(disableAnimations: reducedMotion),
          child: Center(
            child: SizedBox(width: width, child: child),
          ),
        ),
      ),
    );

/// The scroll offset of every scrolling marquee in the tree, in tree order.
List<double> _offsets(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((paint) => paint.painter)
    .whereType<MarqueeTextPainter>()
    .map((painter) => painter.offset)
    .toList();

int _scrolling(WidgetTester tester) => _offsets(tester).length;

List<TrackAction> _twoActions({
  VoidCallback? onQueued,
  VoidCallback? onDeleted,
}) => [
  TrackAction(
    tooltip: 'Add to playback queue',
    icon: Icons.queue_music,
    onPressed: onQueued ?? _noop,
  ),
  TrackAction(
    tooltip: 'Delete song',
    icon: Icons.delete_outline,
    onPressed: onDeleted ?? _noop,
  ),
];

void main() {
  testWidgets('a title that fits never starts scrolling', (tester) async {
    await tester.pumpWidget(
      // The test font draws every glyph as a fixed square, so an eleven
      // character title needs a roomy row to fit in.
      _host(const TrackTile(title: 'Short title', onTap: _noop), width: 400),
    );
    expect(_scrolling(tester), 0);
    expect(find.text('Short title'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('Short title')).overflow,
      TextOverflow.ellipsis,
    );

    await tester.pump(const Duration(seconds: 2));
    expect(_scrolling(tester), 0);
  });

  testWidgets('a truncated title travels and dwells at the end', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const TrackTile(
          title: _long,
          subtitle: 'A very long artist name that also has to travel',
          onTap: _noop,
        ),
      ),
    );
    await tester.pump();
    expect(_scrolling(tester), 2);

    await tester.pump(const Duration(milliseconds: 400));
    expect(_offsets(tester), everyElement(greaterThan(0)));

    // Travel is capped at six seconds and the dwell is 1.2, so the outward pass
    // is over by then and the text must hold still.
    await tester.pump(const Duration(seconds: 6));
    final dwelled = _offsets(tester);
    expect(dwelled, everyElement(greaterThan(0)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_offsets(tester), dwelled, reason: 'the end dwell should hold');
  });

  testWidgets('a held row pauses its marquee and resumes on release', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const TrackTile(title: _long, onTap: _noop)));
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 300));
    final moving = _offsets(tester).single;
    expect(moving, greaterThan(0), reason: 'it scrolls before the press');

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(TrackTile)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(_offsets(tester).single, moving, reason: 'a pressed row holds');

    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_offsets(tester).single, greaterThan(moving));
  });

  testWidgets('reduced motion renders a static ellipsized title', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const TrackTile(title: _long, onTap: _noop), reducedMotion: true),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(_scrolling(tester), 0);
    expect(find.text(_long), findsOneWidget);
    expect(
      tester.widget<Text>(find.text(_long)).overflow,
      TextOverflow.ellipsis,
    );
  });

  testWidgets('a muted ticker holds an offstage tab still', (tester) async {
    await tester.pumpWidget(
      _host(
        const TickerMode(
          enabled: false,
          child: TrackTile(title: _long, onTap: _noop),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final held = _offsets(tester).single;
    await tester.pump(const Duration(seconds: 3));
    expect(_offsets(tester).single, held, reason: 'TickerMode must mute it');
  });

  testWidgets('a 320dp row holds a 200 character title without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              TrackTile(title: 'x' * 200, subtitle: 'y' * 200, onTap: _noop),
              TrackTile(
                title: 'a second very long row so the marquee is not alone',
                actions: _twoActions(),
                onTap: _noop,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a pointer platform offers a menu instead of a swipe', (
    tester,
  ) async {
    var queued = 0;
    var deleted = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.linux),
        home: Scaffold(
          body: TrackTile(
            title: 'Song',
            onTap: _noop,
            actions: _twoActions(
              onQueued: () => queued++,
              onDeleted: () => deleted++,
            ),
          ),
        ),
      ),
    );
    expect(find.byTooltip('More actions'), findsOneWidget);
    expect(find.byTooltip('Delete song'), findsNothing, reason: 'no strip');

    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    expect(find.text('Add to playback queue'), findsOneWidget);
    await tester.tap(find.text('Delete song'));
    await tester.pumpAndSettle();
    expect(deleted, 1);
    expect(queued, 0);
  });

  testWidgets('the swipe strip stays hidden until the row is swiped', (
    tester,
  ) async {
    var deleted = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: Scaffold(
          body: TrackTile(
            title: 'Song',
            onTap: _noop,
            actions: _twoActions(onDeleted: () => deleted++),
          ),
        ),
      ),
    );
    // Not built, so not painted and not tappable: a closed row cannot leak the
    // actions underneath it.
    expect(find.byTooltip('Delete song'), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    expect(tester.getSize(find.byType(ListTile)).width, 800);
  });

  testWidgets('a swipe reveals the actions and springs shut again', (
    tester,
  ) async {
    var queued = 0;
    var deleted = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: Scaffold(
          body: TrackTile(
            title: 'Song',
            onTap: _noop,
            actions: _twoActions(
              onQueued: () => queued++,
              onDeleted: () => deleted++,
            ),
          ),
        ),
      ),
    );
    // No menu button: the strip is the only affordance.
    expect(find.byTooltip('More actions'), findsNothing);

    // The row slides, so the ListTile is what moves.
    final rest = tester.getTopLeft(find.byType(ListTile));
    // A drag short of the threshold springs shut.
    await tester.drag(find.byType(TrackTile), const Offset(-30, 0));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byType(ListTile)).dx, rest.dx);
    expect(find.byTooltip('Delete song'), findsNothing);

    // A drag past it stays open and the strip is tappable.
    await tester.drag(find.byType(TrackTile), const Offset(-160, 0));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byType(ListTile)).dx, lessThan(rest.dx));
    expect(find.byTooltip('Delete song'), findsOneWidget);
    await tester.tap(find.byTooltip('Add to playback queue'));
    await tester.pumpAndSettle();
    expect(queued, 1);
    expect(deleted, 0);
  });

  testWidgets('a vertical drag scrolls the list instead of revealing actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView.builder(
            itemCount: 20,
            itemBuilder: (context, index) => TrackTile(
              title: 'Song $index',
              actions: [
                TrackAction(
                  tooltip: 'Delete song $index',
                  icon: Icons.delete_outline,
                  onPressed: _noop,
                ),
              ],
              onTap: _noop,
            ),
          ),
        ),
      ),
    );
    final rest = tester.getTopLeft(find.byType(ListTile).first);
    await tester.drag(find.byType(TrackTile).first, const Offset(0, -200));
    await tester.pumpAndSettle();
    // The list scrolled and no row slid sideways to reveal its strip.
    expect(
      tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels,
      greaterThan(150),
    );
    expect(tester.getTopLeft(find.byType(ListTile).first).dx, rest.dx);
    expect(find.byTooltip('Delete song 0'), findsNothing);
  });

  testWidgets('scrolling the list shuts an open row', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: Scaffold(
          body: ListView.builder(
            itemCount: 20,
            itemBuilder: (context, index) => TrackTile(
              title: 'Song $index',
              actions: _twoActions(),
              onTap: _noop,
            ),
          ),
        ),
      ),
    );

    // Open the first row's strip and leave it open.
    final rest = tester.getTopLeft(find.byType(ListTile).first);
    await tester.drag(find.byType(TrackTile).first, const Offset(-160, 0));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.byType(ListTile).first).dx,
      lessThan(rest.dx),
    );

    // Now scroll. The row has to snap shut, or it rides along displaced with
    // its actions still tappable.
    await tester.drag(find.byType(TrackTile).first, const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.byType(ListTile).at(1)).dx,
      rest.dx,
      reason: 'a scroll must not leave a row slid aside',
    );
    expect(
      find.byTooltip('Delete song'),
      findsNothing,
      reason: 'the strip is shut, so its actions are not exposed',
    );
  });

  testWidgets('a drag past the open position resists instead of running off', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: Scaffold(
          body: TrackTile(title: 'Song', onTap: _noop, actions: _twoActions()),
        ),
      ),
    );
    final strip = 2 * TrackTile.actionWidth;
    final rest = tester.getTopLeft(find.byType(ListTile));

    // Pull three strip-widths. Rubber banding means the row travels well past
    // its open position but nowhere near as far as the finger.
    await tester.drag(find.byType(TrackTile), Offset(-strip * 3, 0));
    await tester.pump();
    final pulled = rest.dx - tester.getTopLeft(find.byType(ListTile)).dx;
    expect(pulled, greaterThan(strip), reason: 'it opens and then some');
    expect(
      pulled,
      lessThan(strip * 2),
      reason: 'the row resists rather than following the finger exactly',
    );

    // Past the threshold the strip latches open, and the rubber band relaxes
    // it back to exactly the strip width rather than leaving it over-pulled.
    await tester.pumpAndSettle();
    expect(
      rest.dx - tester.getTopLeft(find.byType(ListTile)).dx,
      closeTo(strip, 0.5),
    );
  });

  testWidgets('entering selection mode closes an open strip', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: Scaffold(
          body: TrackTile(title: 'Song', onTap: _noop, actions: _twoActions()),
        ),
      ),
    );
    final rest = tester.getTopLeft(find.byType(ListTile));
    await tester.drag(find.byType(TrackTile), const Offset(-160, 0));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byType(ListTile)).dx, lessThan(rest.dx));

    // Rebuilding into selection mode hides the strip; the offset must go with
    // it, or the row springs open again when selection ends.
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: Scaffold(
          body: TrackTile(
            title: 'Song',
            selectionMode: true,
            selected: true,
            onTap: _noop,
            actions: _twoActions(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byType(ListTile)).dx, rest.dx);
  });

  testWidgets('a pinned button shows on both platforms', (tester) async {
    for (final platform in [TargetPlatform.android, TargetPlatform.linux]) {
      var saved = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: Scaffold(
            body: TrackTile(
              title: 'Song',
              onTap: _noop,
              pinned: TrackAction(
                tooltip: 'Save offline',
                icon: Icons.download_for_offline_outlined,
                onPressed: () => saved++,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Save offline'));
      expect(saved, 1, reason: 'pinned button on $platform');
    }
  });

  testWidgets('a disabled pinned action cannot be pressed', (tester) async {
    await tester.pumpWidget(
      _host(
        const TrackTile(
          title: 'Song',
          onTap: _noop,
          pinned: TrackAction(
            tooltip: 'In the download queue',
            icon: Icons.download_done,
            onPressed: null,
          ),
        ),
      ),
    );
    final button = tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip('In the download queue'),
        matching: find.byType(IconButton),
      ),
    );
    expect(button.onPressed, isNull);
    expect(find.byIcon(Icons.download_done), findsOneWidget);
  });

  testWidgets('a selected row shows a checkbox and hides its actions', (
    tester,
  ) async {
    var toggled = 0;
    await tester.pumpWidget(
      _host(
        TrackTile(
          title: 'Song',
          selectionMode: true,
          selected: true,
          onTap: () => toggled++,
        ),
      ),
    );
    expect(find.byType(Checkbox), findsOneWidget);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
    expect(find.byType(Icon), findsNothing);

    await tester.tap(find.byType(Checkbox));
    expect(
      toggled,
      1,
      reason: 'the checkbox toggles through the same callback',
    );
  });

  testWidgets('selection clears when the list changes', (tester) async {
    final selection = TrackSelection();
    selection.sync(['a', 'b']);
    selection.start();
    selection.toggle('a');
    expect(selection.count, 1);
    expect(selection.contains('a'), isTrue);

    // The same list: the selection survives a rebuild.
    selection.sync(['a', 'b']);
    expect(selection.count, 1);

    // A different list: a stale selection must not act on a new row.
    selection.sync(['a', 'b', 'c']);
    expect(selection.count, 0);
    expect(selection.active, isFalse);
  });

  testWidgets('the selection bar reports the count and blocks empty actions', (
    tester,
  ) async {
    var added = 0;
    var deleted = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SelectionBar(
            count: 0,
            onAddToPlaylist: () => added++,
            onDelete: () => deleted++,
          ),
        ),
      ),
    );
    expect(find.text('0 selected'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.ancestor(
              of: find.byTooltip('Delete selected songs'),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed,
      isNull,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SelectionBar(
            count: 3,
            deleting: true,
            progress: 0.5,
            onAddToPlaylist: () => added++,
            onDelete: () => deleted++,
          ),
        ),
      ),
    );
    expect(find.text('3 selected'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await tester.tap(find.byTooltip('Add selected songs to playlist'));
    expect(added, 1);
    expect(deleted, 0, reason: 'delete is blocked while deleting');
  });
}

void _noop() {}
