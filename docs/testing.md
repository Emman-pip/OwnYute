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
| `layout_test.dart` | Theme changes recolor immediately; long queue titles wrap on a narrow phone; phone navigation reaches every destination and dark settings; the playlist picker fits a short viewport. |
| `library_search_test.dart` | Search filters songs across every folder view; **All songs** starts collapsed; **Select** expands it and multi-select assigns all chosen songs to a playlist. |
| `model_compatibility_test.dart` | Older queue/library records (missing newer fields) remain usable. |
| `player_controller_test.dart` | Android reports playing only after a `started` event; buffering/paused/error transitions. |
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

## Known baseline failures

`flutter test` is not green on a clean checkout:

- `test/app_controller_test.dart` — `staged search loads a small first batch and pages on demand` fails (`Expected: <1> Actual: <2>`). `FakeYoutube` counts a search as "full" when `songs == 0 || playlists == 0`, so the full playlist fetch also increments the counter.
- `test/layout_test.dart` — all tests hang and time out, because they call `app.initialize()` outside `tester.runAsync` (see above).

## Conventions

- Test files are named `*_test.dart`.
- New behavior should come with a test that would fail without the change.
- Run `flutter analyze` and `flutter test` before submitting changes. Bare `flutter test` covers `test/` only; the `tool/verify_*_test.dart` wrappers must be named explicitly.
- Do not run `dart format .` across the repo — the tree is not format-clean at HEAD, so it creates a large unrelated diff. Format only the files you changed.
