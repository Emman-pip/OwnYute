# Tech Stack

OwnYute is a Flutter application with thin, purpose-built native layers for Android and Linux. It deliberately avoids large third-party media SDKs and instead orchestrates a bundled `yt-dlp` binary plus FFmpeg.

## Core languages

| Language | Version / toolchain | Where |
| --- | --- | --- |
| Dart | SDK `^3.13.3`, Flutter 3.47.3 (stable) | All application code in `lib/` |
| Kotlin | 2.4.0 (JVM 17) | Android platform bridges in `android/app/src/main/kotlin` |
| C++ | C++14 | Linux GTK runner in `linux/runner` |
| Python | 3.8 (bundled on Android via youtubedl-android) | Runs `yt-dlp` inside the Android sandbox |

## Flutter / Dart dependencies

Declared in `pubspec.yaml`:

| Package | Version | Role |
| --- | --- | --- |
| `flutter` | SDK | UI framework and rendering. |
| `flutter_riverpod` | ^3.3.2 | Provides the singleton `AppController` to the widget tree. |
| `drift` | ^2.34.1 | Type-safe SQLite persistence. |
| `drift_flutter` | ^0.3.1 | Opens the SQLite database through `path_provider`. |
| `file_picker` | ^11.0.3 | Folder, audio, and cover-image pickers. |
| `path` | ^1.9.1 | Cross-platform path manipulation. |
| `path_provider` | ^2.1.6 | App support and documents directories. |
| `crypto` | ^3.0.7 | SHA-256 checksums for nightly `yt-dlp` verification and artwork deduplication. |

### Development dependencies

| Package | Version | Role |
| --- | --- | --- |
| `flutter_test` | SDK | Unit and widget tests. |
| `flutter_lints` | ^6.0.0 | Static analysis rules (`analysis_options.yaml`). |
| `drift_dev` | ^2.34.0 | Generates `database.g.dart`. |
| `build_runner` | ^2.15.1 | Runs code generation. |

## Native dependencies

### Android

| Dependency | Version | Role |
| --- | --- | --- |
| `com.android.application` (AGP) | 9.1.0 | Android build plugin. |
| `io.github.junkfood02.youtubedl-android:library` | 0.18.1 | Bundles `yt-dlp` and Python 3.8. |
| `io.github.junkfood02.youtubedl-android:ffmpeg` | 0.18.1 | Bundles the FFmpeg executable and libraries. |
| AndroidX Media / MediaSession | via Flutter engine | Foreground playback service and media notification. |
| Gradle | 9.3.1 | Build system. |

The Android app uses the Storage Access Framework (SAF) to read and write user-chosen folders, and a foreground service with type `mediaPlayback` for playback.

### Linux

| Dependency | Role |
| --- | --- |
| GTK 3 (`gtk+-3.0`) | Window and header bar via the Flutter Linux embedder. |
| `yt-dlp` on `PATH` | System copy used until an app-managed nightly copy is installed. |
| `ffmpeg` / `ffprobe` | Transcoding to MP3, cover embedding, and metadata reading. |
| `ffplay` | Local playback backend. |
| `rsvg-convert` (`librsvg2-bin`) | Build-time icon rasterization (`tool/generate_app_icons.sh`). |

## Packaging and tooling

| Tool | Purpose |
| --- | --- |
| `flutter analyze` / `dart format` | Lint and formatting gates. |
| `tool/generate_app_icons.sh` | Renders the SVG logo master into every Android and Linux icon size. |
| `tool/verify_*.dart` | Offline integration checks requiring FFmpeg/FFprobe. |
| CMake | Builds the Linux runner and installs the desktop entry and icons. |

## Why these choices

- **drift over raw SQLite or a remote database:** the app is offline-first and must survive restarts. drift gives compile-time-checked queries and migrations.
- **`yt-dlp` over the YouTube Data API:** no API keys, quota, or ToS restrictions on playback streams, and it keeps working as YouTube changes.
- **Thin native bridges over a plugin:** the app needs precise control of `yt-dlp` argv, process cancellation, SAF document handling, and crash diagnostics, which general-purpose plugins do not expose.
- **A single `ChangeNotifier`:** the UI state is small and highly interrelated; one controller avoids scattering state across providers while Riverpod keeps access testable.
