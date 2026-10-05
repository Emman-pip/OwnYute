# Build and Release

## Prerequisites

### Common

- Flutter 3.47.3 (stable) or newer, with Dart SDK `^3.13.3`.
- `ffmpeg`, `ffprobe`, and `ffplay` on `PATH`.
- `yt-dlp` on `PATH` for the initial Linux run before an app-managed copy is installed.

### Linux

```sh
sudo apt install ffmpeg yt-dlp librsvg2-bin
```

`librsvg2-bin` provides `rsvg-convert`, used only by the icon generation script.

### Android

- Android SDK with API 36, NDK matching Flutter's requirement.
- A connected device or emulator (arm64-v8a or x86_64).

## Dependencies

```sh
flutter pub get
```

## Build commands

| Task | Command |
| --- | --- |
| Static analysis | `flutter analyze` |
| Run tests | `flutter test` |
| Format code | `dart format .` |
| Run on Linux | `flutter run -d linux` |
| Run on Android | `flutter run -d <device-id>` |
| Build Linux release | `flutter build linux` |
| Build Android release | `flutter build apk --release` |

Build outputs:

- Linux: `build/linux/x64/release/bundle/`
- Android: `build/app/outputs/flutter-apk/app-release.apk`

## Versioning

The version lives in `pubspec.yaml` as `version: <name>+<code>`, for example `1.0.4+5`:

- `1.0.4` is `versionName` (shown to users).
- `5` is `versionCode` (must increase for every installed update).

Flutter's Gradle plugin derives both automatically; `android/app/build.gradle.kts` references `flutter.versionName` and `flutter.versionCode`.

## Android release configuration

`android/app/build.gradle.kts`:

- `applicationId = "com.example.own_yute"` (change before publishing).
- `minSdk = 24`, `targetSdk = flutter.targetSdkVersion`.
- `ndk.abiFilters` limited to `arm64-v8a` and `x86_64`.
- `packaging.jniLibs.useLegacyPackaging = true`, `keepDebugSymbols += "**/*.zip.so"`, and `excludes` for unsupported ABIs.
- Release currently signs with the **debug key** — configure a real keystore before distribution.

### R8 / ProGuard

Flutter enables R8 minification and resource shrinking for release builds. Because the bundled `youtubedl-android` AAR ships **no consumer ProGuard rules**, `android/app/proguard-rules.pro` keeps the reflection-reached tool classes:

```proguard
-keep class com.yausername.** { *; }
-keep class org.apache.commons.compress.archivers.zip.** { *; }
```

> Removing these rules reintroduces a release-only crash on the first tool operation.

## Linux release configuration

- `set(BINARY_NAME "own_yute")` and `set(APPLICATION_ID "com.example.own_yute")` in `linux/CMakeLists.txt`.
- The bundle is relocatable; icons and the desktop entry are installed under the bundle's `share/` during the build.
- For system installation, copy the bundle's `share/applications` and `share/icons` into the corresponding system directories (or package them in a `.deb`/AppImage).

## Regenerating icons

After editing `assets/branding/ownyute_logo.svg`:

```sh
tool/generate_app_icons.sh
```

This rewrites all Android densities, the adaptive foregrounds, and the Linux window icon.

## Code generation

If you change `lib/core/database.dart`:

```sh
dart run build_runner build --delete-conflicting-outputs
```

The generated `lib/core/database.g.dart` is committed, so this is only needed when the schema changes.

## Continuous checks

A healthy change should pass, in order:

```sh
flutter analyze
flutter test
tool/generate_app_icons.sh   # only when branding changes
flutter build linux
flutter build apk --release
```
