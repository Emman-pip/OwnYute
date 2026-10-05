# Folder Structure

```
OwnYute/
├── AGENTS.md                     # Repository working guidelines
├── readme.md                     # Setup + user guide with screenshots
├── analysis_options.yaml         # Lint configuration
├── pubspec.yaml                  # Dependencies, assets, app version
├── pubspec.lock                  # Resolved dependency versions
│
├── assets/
│   └── branding/
│       ├── ownyute_logo.svg      # Editable logo master (source of truth)
│       ├── ownyute_logo.png      # 1024px raster master
│       └── adaptive_foreground.css # Hides the background for adaptive icons
│
├── docs/                         # This documentation set
│   ├── README.md
│   ├── tech-stack.md
│   ├── architecture.md
│   ├── folder-structure.md
│   ├── aim-and-achievements.md
│   ├── data-model.md
│   ├── platform-integration.md
│   ├── build-and-release.md
│   ├── testing.md
│   ├── troubleshooting.md
│   └── images/                   # Screenshots captured from the release build
│
├── lib/
│   ├── main.dart                 # Entry point, root widget, navigation shell
│   │
│   ├── core/
│   │   ├── app_controller.dart   # Central state + orchestration
│   │   ├── app_logo.dart         # In-app logo widgets
│   │   ├── app_themes.dart       # All light/dark/pastel color schemes
│   │   ├── artwork_image.dart    # Local-or-network artwork widget
│   │   ├── android_storage.dart  # Dart side of the SAF bridge
│   │   ├── android_tools.dart    # Dart side of the tool bridge
│   │   ├── crash_diagnostics.dart# Dart error reporting hook
│   │   ├── database.dart         # drift tables and queries
│   │   ├── database.g.dart       # Generated drift code
│   │   ├── database_factory.dart # Opens the SQLite database
│   │   ├── models.dart           # Track, PlaylistRef, QueueItem, LibraryTrack
│   │   ├── ui_helpers.dart       # Shared widgets and dialogs
│   │   └── yt_dlp_manager.dart   # Nightly yt-dlp selection/verification
│   │
│   └── features/
│       ├── search/
│       │   ├── search_page.dart  # Search + Paste URL UI
│       │   └── youtube_service.dart
│       ├── downloads/
│       │   └── download_service.dart
│       ├── queue/
│       │   └── queue_page.dart
│       ├── library/
│       │   ├── library_page.dart
│       │   └── library_service.dart
│       ├── player/
│       │   ├── player_controller.dart
│       │   └── player_widgets.dart
│       └── settings/
│           └── settings_page.dart
│
├── android/
│   ├── app/
│   │   ├── build.gradle.kts      # AGP config, youtubedl-android deps
│   │   ├── proguard-rules.pro    # Keeps reflection-reached tool classes
│   │   └── src/main/
│   │       ├── AndroidManifest.xml
│   │       ├── kotlin/com/example/own_yute/
│   │       │   ├── MainActivity.kt      # Wires up all channels
│   │       │   ├── ToolBridge.kt        # yt-dlp + FFmpeg execution
│   │       │   ├── StorageBridge.kt     # SAF folder + file access
│   │       │   ├── PlaybackService.kt   # Foreground media service
│   │       │   └── CrashDiagnostics.kt  # Fatal/last-step recording
│   │       └── res/                     # Icons, themes, splash
│   └── settings.gradle.kts
│
├── linux/
│   ├── CMakeLists.txt            # Runner build + install rules
│   ├── com.example.own_yute.desktop
│   └── runner/
│       ├── main.cc
│       ├── my_application.cc     # GTK window, title, icon
│       └── resources/ownyute_logo.png
│
├── test/                         # Flutter unit + widget tests
│   ├── app_controller_test.dart
│   ├── app_themes_test.dart
│   ├── edit_dialog_test.dart
│   ├── layout_test.dart
│   ├── library_search_test.dart
│   ├── model_compatibility_test.dart
│   ├── player_controller_test.dart
│   ├── youtube_service_test.dart
│   └── yt_dlp_manager_test.dart
│
└── tool/
    ├── generate_app_icons.sh     # Renders the logo into all icon sizes
    ├── verify_services.dart      # Offline yt-dlp/service checks
    ├── verify_database.dart      # Offline drift checks
    ├── verify_download.dart      # Offline FFmpeg download/edit check
    └── verify_*_test.dart        # Test wrappers for the above
```

## Conventions

- **Feature-centric grouping:** each screen and its service live together under `lib/features/<feature>/`.
- **`core/` holds cross-cutting code:** state, persistence, theming, platform bridges, and shared widgets.
- **Two-file pattern for platform code:** every Android `MethodChannel` has a Dart wrapper in `core/` (`android_storage.dart`, `android_tools.dart`).
- **Generated files are committed:** `lib/core/database.g.dart` is checked in so the project builds without running `build_runner` first.
- **Tests mirror behavior:** test files are named after the behavior under test (`library_search_test.dart`, `edit_dialog_test.dart`).
- **Tools are runnable and testable:** every `tool/verify_*.dart` has a matching `_test.dart` wrapper.
