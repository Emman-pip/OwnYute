import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_yute/core/models.dart';
import 'package:own_yute/core/ui_helpers.dart';

void main() {
  testWidgets('saving metadata survives dialog exit animation', (tester) async {
    Track? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await editTrackDialog(
                  context,
                  const Track(
                    id: 'file',
                    url: '/tmp/file.mp3',
                    title: 'Before',
                  ),
                );
              },
              child: const Text('Edit'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'After');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(result?.title, 'After');
    expect(tester.takeException(), isNull);
  });

  testWidgets('local artwork can be selected and previewed', (tester) async {
    Track? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await editTrackDialog(
                  context,
                  const Track(id: 'file', url: '/tmp/file.mp3', title: 'Song'),
                  pickArtwork: () async => '/tmp/cover.png',
                );
              },
              child: const Text('Edit'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose image'));
    await tester.pump();
    expect(
      tester
          .widget<TextField>(
            find.widgetWithText(TextField, 'Artwork URL or image'),
          )
          .controller
          ?.text,
      '/tmp/cover.png',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(result?.artwork, '/tmp/cover.png');
    expect(tester.takeException(), isNull);
  });
}
