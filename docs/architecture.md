# Architecture

OwnYute follows a layered architecture: a thin Flutter UI, a central application controller that owns all state, feature services that perform work, and platform bridges that expose native capabilities.

```
┌──────────────────────────────────────────────────────────────┐
│ Presentation (lib/features/*)                                │
│  SearchPage  QueuePage  LibraryPage  SettingsPage  Player UI │
└───────────────────────────┬──────────────────────────────────┘
                            │ reads state, calls methods
┌───────────────────────────▼──────────────────────────────────┐
│ AppController (lib/core/app_controller.dart)                 │
│  • owns library / queue / history / settings state           │
│  • coordinates services and persists through the database    │
│  • extends ChangeNotifier, provided via Riverpod             │
└───────┬───────────┬───────────┬───────────┬──────────────────┘
        │           │           │           │
        ▼           ▼           ▼           ▼
  YoutubeService DownloadService YtDlpManager PlayerController
  LibraryService               (nightly mgr)
        │           │           │           │
        └───────────┴─────┬─────┴───────────┘
                          ▼
              Platform bridges / process runners
        ┌─────────────────────┬───────────────────────┐
        │ Android (Kotlin)    │ Linux (dart:io)        │
        │ ToolBridge          │ Process.run/start      │
        │ StorageBridge       │ System yt-dlp/ffmpeg   │
        │ PlaybackService     │ GTK window             │
        │ CrashDiagnostics    │                        │
        └─────────────────────┴───────────────────────┘
```

## State management

- **`AppController`** is a `ChangeNotifier` created once in `main.dart` through a Riverpod `Provider`. It is the single source of truth for songs, playlists, the download queue, history, library entries, settings, and transient errors.
- Widgets listen with `ListenableBuilder` (and `ConsumerWidget` for the root), so any mutation calls `notifyListeners()` and the affected subtree rebuilds.
- `YtDlpManager` and `PlayerController` are separate `ChangeNotifier`s surfaced through the controller (`app.tools`, `app.player`) so their high-frequency updates do not rebuild the whole app.

## Layers

### 1. Presentation

`lib/features/search`, `queue`, `library`, `settings`, and `player` contain pages and widgets. They hold only ephemeral UI state (search text, dialog controllers, selection sets) and delegate all durable actions to `AppController`. Shared widgets such as `TrackTile` and dialogs live in `lib/core/ui_helpers.dart`.

### 2. Application controller

`AppController` (`lib/core/app_controller.dart`, ~820 lines) is the core of the app. Responsibilities:

- Load and persist settings, queue, library, and history on startup.
- Drive search, playlist parsing, preview resolution, and metadata edits.
- Own the sequential download loop, including duplicate handling and batch bookkeeping.
- Manage playlist folders, physical folder scans, and file moves/deletes.
- Expose helpers for the artwork picker and theme selection.

### 3. Feature services

| Service | Responsibility |
| --- | --- |
| `YoutubeService` | Builds `yt-dlp` argv, parses search/URL JSON, resolves stream URLs. |
| `DownloadService` | Downloads, transcodes to MP3, embeds cover art, verifies output, edits metadata. |
| `LibraryService` | Reads local audio tags with `ffprobe` (Linux) or `MediaMetadataRetriever` (Android). |
| `YtDlpManager` | Fetches, verifies, installs, and falls back between nightly `yt-dlp` builds. |
| `PlayerController` | Controls local/streamed playback, queue navigation, shuffle/repeat. |

### 4. Platform bridges

- **Android:** Kotlin classes registered as Flutter `MethodChannel`s. `ToolBridge` runs `yt-dlp`/FFmpeg off the UI thread, `StorageBridge` handles SAF folders and file I/O, `PlaybackService` is a foreground service, and `CrashDiagnostics` records the last operation for support reports.
- **Linux:** the app calls `yt-dlp`/`ffmpeg` directly with `dart:io` `Process`, using argv arrays (never shell strings). The GTK runner sets the window title and icon.

## Data flow examples

### Search

1. `SearchPage` calls `app.search(query)`.
2. `AppController` sets `busy`, calls `YoutubeService.search`.
3. `YoutubeService` asks `YtDlpManager` for an executable, runs `yt-dlp` with `--dump-single-json`, parses entries into `Track`/`PlaylistRef`.
4. The controller stores `songs`/`playlists`, clears `busy`, and notifies listeners.

### Download

1. `QueuePage` calls `app.downloadQueue(folder, duplicateResolver)`.
2. For each item, `DownloadService.download` runs `yt-dlp --write-thumbnail`, then FFmpeg to transcode and attach the cover.
3. Artwork is best-effort: a missing or unembeddable cover triggers an audio-only retry rather than failing the item.
4. Results are saved to the destination and recorded in the library and database.

## Concurrency

- The download queue runs **sequentially** through one `DownloadService` instance; `cancel()` kills the active process and notifies Android through the bridge.
- On Android, `yt-dlp` is serialized on a single-thread executor so process IDs stay unique and cancellable; FFmpeg runs on a cached pool.
- Long native work is always dispatched off the UI thread. This was a specific bug class addressed during development (see [Troubleshooting](troubleshooting.md)).

## Error handling

- `AppController.error` is surfaced as a `MaterialBanner`/`SnackBar` and can be dismissed.
- Service failures throw typed exceptions (`DownloadFailure`, `YoutubeFailure`) with user-facing messages.
- On Android, uncaught exceptions and Dart errors are recorded by `CrashDiagnostics` and can be copied from Settings as a scrubbed report.
