# OwnYute — agent notes

Flutter app (Linux + Android) that wraps `yt-dlp` and FFmpeg to search, download, and organize music. Deep technical docs already live in [`docs/`](docs/README.md); this file records only what is hard to discover from the code.

## Commands

```sh
flutter analyze              # clean at HEAD; excludes android/** and linux/**
flutter test                 # runs test/ ONLY; green — see "Baseline" below
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

## Baseline: `flutter test` is green

The suite is green at HEAD. Two things this branch fixed, so they do not
surprise you again:

- `test/layout_test.dart` used to hang for 10 minutes per test because it called
  `app.initialize()` outside `tester.runAsync` (see below). It is green now.
- The `staged search loads a small first batch` note in this file was stale: the
  test passes, because `FakeYoutube.fullSearches` is asserted after both
  `loadMoreSongs` and `loadMorePlaylists`.

**A row with a truncated title never settles.** `MarqueeText` scrolls forever, so
`tester.pumpAndSettle()` times out on any screen that renders one. In tests, pump
a fixed window instead, or render rows under
`MediaQuery(disableAnimations: true)` (the picker tests do the latter).

## Widget tests + drift: `initialize()` deadlocks in fake async

`AppController.initialize()` awaits real drift/file futures. Inside `testWidgets` the `AutomatedTestWidgetsFlutterBinding` fake-async zone never lets those complete, so `await app.initialize()` hangs until the 10-minute test timeout.

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
- Services are injectable through the `AppController` constructor (`database`, `youtube`, `downloader`, `libraryService`) — this is the seam tests use. Extend it rather than reaching for globals.
- **Two distinct queues, never merge them.** `AppController.queue` is the Drift-backed *download* queue (the `QueuePage` / **Downloads** tab). `PlayerController.queue` is the *playback* queue, persisted to `playback_snapshot.json` in the app documents directory. `playTracks()` replaces the playback queue; `addToQueue()` / `addAllToQueue()` / `removeAt()` / `reorder()` mutate it without disturbing playback of the current track.
- Playback-queue edits must keep the snapshot current (`_saveSnapshot()`) and must leave a safe current track: removing the playing track stops audio and selects a successor; queueing onto an idle player adopts the first item as a paused `current` so the mini player appears without starting audio.
- **The playback queue is current-first and self-pruning.** `current` is always
  `queue[0]`, and `_normalizeQueue()` enforces that by moving everything already
  heard into `history` (capped, in memory only, not persisted). It runs after
  `playTracks`, `playAt`, `next`, `previous`, `removeAt`, and **`restore`** —
  that last one matters, because the snapshot stores an index into the whole
  queue and would otherwise resurrect the old ordering on the next launch.
  `previous()` therefore pulls the newest track off `history` back to the front
  rather than walking backwards, `repeat` re-seeds the queue from `history` when
  it empties, and `reorder()` refuses any move touching index 0 (the row shows no
  drag handle for the same reason).
- Persistence is deliberately schema-light: five drift tables holding **JSON blobs** keyed by id/path, `schemaVersion = 2`. `fromJson` supplies defaults so adding a model field stays backward compatible (see `test/model_compatibility_test.dart`). Don't normalize the schema without a reason. Settings (theme, player animation, automatic artwork lookup) use the existing key/value table — only regenerate drift code on a real schema change.
- `AppController.revealDelay` is a `@visibleForTesting` static used to make staged search reveal instant; tests that touch it must restore it in `addTearDown` (see `app_controller_test.dart`).
- Linux calls `yt-dlp`/`ffmpeg` directly with `dart:io` using **argv arrays**. Android goes through four `MethodChannel`s (`own_yute/tools`, `own_yute/storage`, `own_yute/player`, `own_yute/diagnostics`). Branch on `Platform.isAndroid` / `Platform.isLinux` as the existing code does.

## Rows: one shape, and the rules that go with it

- `lib/core/track_row.dart` owns **the** row (`TrackTile`, plus `TrackAction`,
  `TrackSelection`, `SelectionBar`) and `lib/core/marquee_text.dart` owns the
  scrolling label. `ui_helpers.dart` keeps only dialogs. Do not add a second row
  widget; extend `TrackTile` and pass `actions:`.
- A row is `[artwork or checkbox][title / subtitle][pinned][overflow]`. At most
  one `pinned` action, and only where the plan calls for it (search results).
  Everything else goes in `actions:`, which touch builds reveal by swiping and
  pointer builds expose through a `⋮` menu.
- The strip is **not** drawn under a transparent row. The row slides left and
  crops its trailing edge, the strip crops its leading edge, and the two regions
  never overlap, so the actions are invisible and untappable until the user
  actually swipes. Don't "simplify" that into a `Positioned.fill` behind a
  `Transform`.
- **An open row must never outlive the scroll that follows it.** A row listens
  to the enclosing `ScrollPosition.isScrollingNotifier` (a
  `NotificationListener<ScrollNotification>` inside a row gets nothing — those
  notifications are dispatched from the `Scrollable` and bubble *up*, past the
  rows) and settles shut, and it also resets on `onHorizontalDragCancel`, which
  is what a vertical drag taking the pointer produces. Over-pulling is damped by
  `_rubberBand` against a separate `_raw`, so resistance never compounds.
- Row commands confirm themselves through `showFeedback(context, message)` in
  `ui_helpers.dart`, which replaces the current SnackBar rather than queueing
  behind it. Use it for every add-to-queue and add-to-playlist action.
- Long-press is the parent list's selection hook (`onLongPress`), selection state
  lives per list in a `TrackSelection`, and `TrackSelection.sync(ids)` drops a
  selection whenever the visible list changes.
- `MarqueeText` holds while pressed, mutes itself when `TickerMode` is off (the
  `IndexedStack` in `main.dart` keeps all three tabs alive), and falls back to a
  static ellipsis under reduced motion.

## Two traps that look like bugs but are data gaps

- **`yt-dlp --flat-playlist` returns no duration**, so search results carry `Track.duration == 0`. Downloads therefore recorded a library entry with no length, and the player's scrubber had no value to show. Duration is now read back from the saved file: `LibraryService.readDuration()`, `_resolveSavedDuration()` at download time, `_repairMissingDuration()` during `refreshLibrary()`, and `PlayerController._fillLocalDuration()` via the injectable `probeLocalDuration` (ffprobe by default, never used for remote URLs). When changing how a track is constructed, check whether its duration is real.
- **Artwork lookup is optional, on by default, sequential, and best-effort.** `YoutubeService.findArtwork()` matches conservatively on normalized title/artist; `AppController.lookupMissingArtwork()` runs it in the background and embeds matches via `editLibrary()`. `lookupArtwork(track)` and `lookupFolderArtwork(folderPath)` are the on-demand versions behind the row and folder menus. Failures increment counters and are swallowed so they can never block playback or downloads. `_artworkBusy` keeps a library-wide scan and a folder scan from interleaving.

## Platform gotchas that look removable but are not

- `android/app/proguard-rules.pro` keeps `com.yausername.**` and `org.apache.commons.compress.archivers.zip.**`. The bundled `youtubedl-android` AAR ships no consumer rules; deleting these reintroduces a **release-only** crash on the first `yt-dlp` call. Release builds only.
- Android `MethodChannel` handlers must return a Flutter-encodable value or `null`. Returning Kotlin `Unit` throws at serialization time (`Unsupported value: 'kotlin.Unit'`).
- Long-running native work must stay off the UI thread — `NetworkOnMainThreadException` and ANRs were real bugs here.
- Android release currently signs with the **debug key** and `applicationId = "com.example.own_yute"`. Fix both before distributing anything.
- Bump the build number in `pubspec.yaml` (`version: 1.0.4+5` → `1.0.4+6`) for every Android update; Android will not install the same `versionCode` twice.

- **Deletes go through one path.** `deleteSong` is the single file delete (it also
  cleans up playback and the download queue). `deleteSongs(list)` is the bulk
  form and `deleteStorageFolder(path, deleteFiles:)` is the folder form; both
  reuse `deleteSong` and both collect per-song failures into **one** aggregated
  `StateError` rather than stopping at the first problem. `deletePlaylist` is the
  same contract. Deleting a file that also lives in a playlist folder removes it
  from that folder too, so every delete confirmation names the shared songs.

## Conventions

- Keep download and metadata behavior in the services under `lib/features/`, not in widgets. Handle `yt-dlp` process failures and user-visible download errors explicitly — typed `DownloadFailure` / `YoutubeFailure` exceptions surface through `AppController.error`.
- Downloads run **sequentially** through one `DownloadService`. Cover art embedding is best-effort and must never block saving the audio.
- Test names describe observable behavior, not methods. New behavior should come with a test that fails without the change.
- Keep `readme.md` in sync when user-facing behavior or setup changes; technical detail goes in `docs/`.

## Commits

History is mixed: scaffolding used `feat(scope):` Conventional Commits, but all recent commits use plain imperative subjects (`Fix metadata editing and improve library management`). Match the recent style.
