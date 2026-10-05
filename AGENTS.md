# OwnYute — agent notes

Flutter app (Linux + Android) that wraps `yt-dlp` and FFmpeg to search, download, and organize music. Deep technical docs already live in [`docs/`](docs/README.md); this file records only what is hard to discover from the code.

## Commands

```sh
flutter analyze              # clean at HEAD; excludes android/** and linux/**
flutter test                 # runs test/ ONLY — see "Baseline failures" below
flutter run -d linux
flutter run -d <device-id>   # flutter devices first
```

- The `tool/verify_*_test.dart` wrappers are **not** picked up by bare `flutter test`; run them explicitly:
  `flutter test tool/verify_services_test.dart tool/verify_database_test.dart tool/verify_download_test.dart`.
  All three need `ffmpeg`/`ffprobe` on `PATH` and pass offline (`verify_download` stubs out `yt-dlp` with a shell script).
- `dart run build_runner build --delete-conflicting-outputs` after editing `lib/core/database.dart`. `lib/core/database.g.dart` is committed, so this is only needed on schema changes.
- `tool/generate_app_icons.sh` after editing `assets/branding/ownyute_logo.svg`; requires `rsvg-convert` (`librsvg2-bin`).
- There is **no CI**. `flutter analyze` + `flutter test` locally are the only gates, so run them yourself.
- Do **not** run `dart format .` — the tree is not format-clean at HEAD (6 files differ), so it produces a large unrelated diff. Format only the files you touched, and expect their neighbors to still differ.

## Baseline failures (present on a clean checkout — verify before blaming your change)

`flutter test` is **not** green at HEAD:

- `test/app_controller_test.dart` → `staged search loads a small first batch and pages on demand` fails with `Expected: <1> Actual: <2>` at `test/app_controller_test.dart:159`. The `FakeYoutube` counter treats `songs == 0 || playlists == 0` as a "full search", so the full *playlist* fetch in `loadMorePlaylists` also increments it.
- `test/layout_test.dart` → **every** test in the file hangs for 10 minutes and then times out. See the next section; this is not flaky.

Everything else passes.

## Widget tests + drift: `initialize()` deadlocks in fake async

`AppController.initialize()` awaits real drift/file futures. Inside `testWidgets` the `AutomatedTestWidgetsFlutterBinding` fake-async zone never lets those complete, so `await app.initialize()` hangs until the 10-minute test timeout — this is the actual cause of the `layout_test.dart` failures.

Wrap it in `tester.runAsync`:

```dart
late AppController app;
await tester.runAsync(() async {
  app = AppController(database: database);
  await app.initialize();
});
await tester.pumpWidget(/* ... */);   // pump/pumpAndSettle outside runAsync
```

Construct the controller directly and assign state fields (`app.library = [...]`) when you only need to render a page — that avoids drift entirely and is what `library_search_test.dart` does.

Also note: creating several `AppDatabase.forTesting(NativeDatabase.memory())` instances across tests prints a drift *"created the database class AppDatabase multiple times"* warning. It is benign noise, not a failure.

## Architecture

- One `AppController` (`lib/core/app_controller.dart`, the largest file in the repo) is the single `ChangeNotifier` source of truth. Riverpod is used **only** to provide that one instance (`appProvider` in `lib/main.dart`) — it is not used for granular state. Widgets rebuild via `ListenableBuilder`.
- High-frequency state lives in separate notifiers reached through the controller (`app.tools` for `YtDlpManager`, `app.player` for `PlayerController`) to avoid whole-app rebuilds.
- Services are injectable through the `AppController` constructor (`database`, `youtube`, `downloader`) — this is the seam tests use. Extend it rather than reaching for globals.
- Persistence is deliberately schema-light: five drift tables holding **JSON blobs** keyed by id/path, `schemaVersion = 2`. `fromJson` supplies defaults so adding a model field stays backward compatible (see `test/model_compatibility_test.dart`). Don't normalize the schema without a reason.
- `AppController.revealDelay` is a `@visibleForTesting` static used to make staged search reveal instant; tests that touch it must restore it in `addTearDown` (see `app_controller_test.dart`).
- Linux calls `yt-dlp`/`ffmpeg` directly with `dart:io` using **argv arrays**. Android goes through four `MethodChannel`s (`own_yute/tools`, `own_yute/storage`, `own_yute/player`, `own_yute/diagnostics`). Branch on `Platform.isAndroid` / `Platform.isLinux` as the existing code does.

## Platform gotchas that look removable but are not

- `android/app/proguard-rules.pro` keeps `com.yausername.**` and `org.apache.commons.compress.archivers.zip.**`. The bundled `youtubedl-android` AAR ships no consumer rules; deleting these reintroduces a **release-only** crash on the first `yt-dlp` call. Release builds only.
- Android `MethodChannel` handlers must return a Flutter-encodable value or `null`. Returning Kotlin `Unit` throws at serialization time (`Unsupported value: 'kotlin.Unit'`).
- Long-running native work must stay off the UI thread — `NetworkOnMainThreadException` and ANRs were real bugs here.
- Android release currently signs with the **debug key** and `applicationId = "com.example.own_yute"`. Fix both before distributing anything.
- Bump the build number in `pubspec.yaml` (`version: 1.0.4+5` → `1.0.4+6`) for every Android update; Android will not install the same `versionCode` twice.

## Conventions

- Keep download and metadata behavior in the services under `lib/features/`, not in widgets. Handle `yt-dlp` process failures and user-visible download errors explicitly — typed `DownloadFailure` / `YoutubeFailure` exceptions surface through `AppController.error`.
- Downloads run **sequentially** through one `DownloadService`. Cover art embedding is best-effort and must never block saving the audio.
- Test names describe observable behavior, not methods. New behavior should come with a test that fails without the change.
- Keep `readme.md` in sync when user-facing behavior or setup changes; technical detail goes in `docs/`.

## Commits

History is mixed: scaffolding used `feat(scope):` Conventional Commits, but all recent commits use plain imperative subjects (`Fix metadata editing and improve library management`). Match the recent style.