# Testing

OwnYute uses Flutter's `flutter_test` framework for unit and widget tests, plus a set of offline integration checks that exercise real `yt-dlp`/FFmpeg tooling.

## Running the suites

```sh
# Everything
flutter test

# A single file
flutter test test/library_search_test.dart

# Offline integration checks (require FFmpeg / FFprobe)
flutter test tool/verify_services_test.dart
flutter test tool/verify_database_test.dart
flutter test tool/verify_download_test.dart
```

## Unit and widget tests (`test/`)

| File | Covers |
| --- | --- |
| `app_controller_test.dart` | Search, pasted song/playlist, queue restore and edits, invalid URLs, duplicate skip vs. replace, theme restore, complementary dark themes, playlist batches, deleting a playlist, failed metadata edit keeps the original, download failure stays retryable. |
| `app_themes_test.dart` | Dark Blue and Dark Pink palettes expose the expected accents and dark surfaces. |
| `edit_dialog_test.dart` | Saving metadata survives the dialog exit animation; local artwork can be selected and previewed. |
| `layout_test.dart` | Theme changes recolor immediately; a long queue title scrolls instead of wrapping on a narrow phone; phone navigation reaches every destination and dark settings; the playlist picker fits a short viewport. |
| `library_actions_test.dart` | Bulk delete removes files, library entries and playlist references; per-song failures aggregate into one error; removing a storage folder keeps the audio while deleting a folder does not; delete confirmations name the songs shared with a playlist; per-song and per-folder artwork search embeds the cover it finds. |
| `library_search_test.dart` | Search filters songs across every folder view; **All songs** starts collapsed; **Select** expands it, the selection bar counts and multi-select assigns the chosen songs to a playlist; a long press starts selection; a folder page's selection bar stays pinned clear of the songs while the list scrolls. |
| `playlist_picker_test.dart` | Tap and long press both toggle a track; the header count follows; **Add selected** is disabled while nothing is chosen; a 200 character title stays inside a 320x360 picker. |
| `model_compatibility_test.dart` | Older queue/library records (missing newer fields) remain usable. |
| `player_controller_test.dart` | Android reports playing only after a `started` event; buffering/paused/error transitions. |
| `track_row_test.dart` | A title that fits never scrolls while a truncated one travels, dwells and pauses under a press; reduced motion and a muted `TickerMode` both hold still; a 200 character title fits 320dp; pointer builds show a `⋮` menu, touch builds reveal a strip that stays hidden and untappable until swiped; a vertical drag scrolls the list instead; pinned, disabled, and selection rows; the selection bar and `TrackSelection`. |
| `youtube_service_test.dart` | Separates songs and playlists, opens pasted URLs, rejects invalid/unavailable URLs, radio-mix watch URLs open the song not an endless playlist, preview errors. |
| `yt_dlp_manager_test.dart` | Checks nightly once per day and manual retry bypasses the limit; a failed update retains the installed executable and reports the error; an Android update failure still leaves search available. |

## Offline integration tools (`tool/`)

Each tool is a runnable Dart entry point with a matching test wrapper.

| Tool | What it verifies |
| --- | --- |
| `verify_services.dart` | Configures the tool services end-to-end without the GUI. |
| `verify_database.dart` | Opens drift, writes and reads back queue/library/history/settings. |
| `verify_download.dart` | Generates a WAV fixture and a cover image, runs a stubbed `yt-dlp`, transcodes with FFmpeg, then checks the MP3 tags and that the **cover art was embedded as an attached picture**. |

`verify_download.dart` is the most end-to-end offline check: it uses a shell stub in place of the real `yt-dlp` (so it needs no network) and asserts on `ffprobe` output.

## Testing strategy

- **Behavior over implementation:** tests are named after observable behavior ("all songs start collapsed and multi-select expands them"), not internal methods.
- **Fakes at the service boundary:** `FakeYoutube`, `FakeDownloader`, and `FailingDownloader` in `app_controller_test.dart` let the controller be tested without network or processes.
- **In-memory database:** `AppDatabase.forTesting(NativeDatabase.memory())` gives each test an isolated database.
- **Real tooling where it matters:** the download and metadata paths are validated against actual FFmpeg output.
- **Widget-level regression coverage:** layout and dialog tests guard against overflows and lost state during animations.

## Widget tests and drift

`AppController.initialize()` awaits real drift and file-system futures. Inside `testWidgets` the binding's fake-async zone never lets those complete, so a bare `await app.initialize()` hangs until the 10-minute test timeout. Wrap it in `tester.runAsync`:

```dart
late AppController app;
await tester.runAsync(() async {
  app = AppController(database: database);
  await app.initialize();
});
await tester.pumpWidget(/* ... */);
```

When a test only needs to render a page, skip `initialize()` entirely and assign state directly (`app.library = [...]`), as `library_search_test.dart` does.

Creating several `AppDatabase.forTesting(NativeDatabase.memory())` instances in one file prints a drift *"created the database class AppDatabase multiple times"* warning. It is benign noise.

## Scrolling rows and `pumpAndSettle`

A track row whose title does not fit scrolls it with `MarqueeText`, and that
scroll repeats forever. **`pumpAndSettle()` therefore times out on any screen that
renders one** — the library, the search results, the picker, the download queue.

Two ways out, both used in this repo:

```dart
// Pump a fixed window instead of settling.
await tester.pump();
await tester.pump(const Duration(milliseconds: 600));

// Or render the rows with reduced motion, which is static.
MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: child!,
  ),
  home: /* ... */,
);
```

`track_row_test.dart` reads the scroll offset through
`find.byType(MarqueeTextPainter)` (or the `marqueeOffset` helper in
`layout_test.dart`), which is how the scrolling behaviour is asserted without
depending on private state.

## Known baseline failures

None: `flutter test` is green. It was not, until the track-row work:

- `test/layout_test.dart` hung for 10 minutes per test because it called
  `app.initialize()` outside `tester.runAsync` (see above). Fixed.
- `test/app_controller_test.dart` was documented here as failing
  `staged search loads a small first batch and pages on demand`. That note was
  stale; the test passes.

## Conventions

- Test files are named `*_test.dart`.
- New behavior should come with a test that would fail without the change.
- Run `flutter analyze` and `flutter test` before submitting changes. Bare `flutter test` covers `test/` only; the `tool/verify_*_test.dart` wrappers must be named explicitly.
- Do not run `dart format .` across the repo — the tree is not format-clean at HEAD, so it creates a large unrelated diff. Format only the files you changed.
