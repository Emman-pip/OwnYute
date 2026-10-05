# Platform Integration

OwnYute shares all business logic in Dart and pushes only platform-specific capabilities into native code. This document covers what each platform does natively and how the two sides communicate.

## Communication

Everything crosses the Flutter `MethodChannel` boundary as structured maps. There are four channels:

| Channel | Owner | Purpose |
| --- | --- | --- |
| `own_yute/tools` | `ToolBridge` | Run `yt-dlp`/FFmpeg, update nightly `yt-dlp`, cancel tasks. |
| `own_yute/storage` | `StorageBridge` | SAF folder picking and file read/write/move/delete. |
| `own_yute/player` | `MainActivity` | Playback commands and events to/from the media service. |
| `own_yute/diagnostics` | `MainActivity` | Read the crash report, record Dart errors. |

Each channel has a Dart wrapper in `lib/core/` (`android_tools.dart`, `android_storage.dart`, `crash_diagnostics.dart`).

> **Contract note:** Android bridge methods must return values Flutter can encode (maps, lists, primitives, or `null`). Returning Kotlin `Unit` throws at serialization time — see [Troubleshooting](troubleshooting.md).

## Android

### `ToolBridge` (`ToolBridge.kt`)

- Runs `yt-dlp` on a **fixed pool** (`YT_DLP_LANES`, currently 3) so a batch can download in parallel; FFmpeg runs on a cached pool. Each Dart call still supplies its own process id, so ids stay unique and cancellable. The pool is fixed rather than cached on purpose — every `yt-dlp` here is a bundled Python interpreter, and an unbounded pool would let a bug spawn them until the device runs out of memory. Keep `YT_DLP_LANES` in step with `AppController.platformDownloadLimit`, which caps Android at 3 for the same reason.
- `updateNightly()` has its **own single-thread executor**, so a nightly check never interleaves with, or queues behind, the downloads the user is waiting on.
- Calls `YoutubeDL.getInstance().init(context)` and executes `YoutubeDLRequest`s with argv arrays.
- Streams download progress back through `progress` method calls.
- `updateNightly()` downloads, validates, and installs a nightly build with layered recovery.
- `cancel` destroys the process by id via `destroyProcessById`.

### `StorageBridge` (`StorageBridge.kt`)

- Uses `ACTION_OPEN_DOCUMENT_TREE` to pick folders and persists the grant with `takePersistableUriPermission`.
- Resolves document URIs through `DocumentsContract` for listing, creating, moving, and deleting files.
- Reads metadata with `MediaMetadataRetriever`.
- `replace` writes an edited file back with a backing-up-and-restore strategy so a failed write never destroys the original.
- All heavy work runs on a worker executor; results are posted back to the main thread.

### `PlaybackService` (`PlaybackService.kt`)

- A foreground service with `foregroundServiceType="mediaPlayback"`.
- Handles play/pause/resume/seek/stop intents and emits player events (`started`, `buffering`, `paused`, `duration`, `error`, …) back to Dart.
- On Android 13+ the app requests the notification permission so media controls can be shown.

### `CrashDiagnostics` (`CrashDiagnostics.kt`)

- Installs a default uncaught-exception handler that records a scrubbed report: app version, Android/SDK/ABI, last operation stage, process exit reason, and the last fatal or tool error.
- **Scrubbing removes YouTube URLs and `/storage/...` paths** before anything is stored.
- Dart-side errors are recorded through `own_yute/diagnostics`; Settings exposes a **Build and crash report** with a copy button.

### Permissions and manifest

- `INTERNET`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MEDIA_PLAYBACK`, `POST_NOTIFICATIONS`.
- `android:icon="@mipmap/ic_launcher"` and `android:roundIcon="@mipmap/ic_launcher_round"`.

### Release signing

The current release build uses Flutter's debug signing key so it can be installed for testing; a real signing key must be configured before publishing.

## Linux

The Linux path avoids a bridge entirely — Dart calls system executables directly.

- **Processes:** `Process.run`/`Process.start` with **argv arrays** (never assembled shell strings).
- **`yt-dlp` selection:** `YtDlpManager` prefers an app-managed nightly copy in the app support directory, verifies its SHA-256 against the published `SHA2-256SUMS`, and falls back to the system `yt-dlp` on `PATH`.
- **GTK runner** (`linux/runner/my_application.cc`): sets the window title to "OwnYute", loads the bundled window icon from `data/ownyute_logo.png`, and uses a header bar under GNOME/Wayland.
- **FFmpeg/FFprobe/FFplay** must remain on `PATH`.

### Desktop packaging

`linux/CMakeLists.txt` installs:

- the binary and Flutter assets into the bundle,
- `data/ownyute_logo.svg` and `data/ownyute_logo.png` for the window icon,
- `share/applications/com.example.own_yute.desktop`,
- `share/icons/hicolor/scalable/apps/com.example.own_yute.svg` and a 512px PNG.

## Branding pipeline

`assets/branding/ownyute_logo.svg` is the single source of truth. `tool/generate_app_icons.sh` rasterizes it with `rsvg-convert` into:

- Android legacy `ic_launcher.png` and round icons for all densities,
- Android adaptive foreground layers (`ic_launcher_foreground.png`),
- the Linux window icon.

Adaptive backgrounds are vector drawables (`ic_launcher_background.xml`), and the Android 13+ monochrome icon is hand-authored (`ic_launcher_monochrome.xml`) so themed icons stay legible.
