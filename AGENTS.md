# Repository Guidelines

## Project Structure & Module Organization

OwnYute is a multiplatform Linux and Android application that wraps `yt-dlp` for searching and downloading YouTube playlists and songs, with batch or individual metadata options. Keep Flutter application code in `lib/`, automated checks in `test/`, and bundled resources in `assets/`. Group related screens, services, and models by feature; keep download and metadata behavior out of presentation widgets where practical. Update `readme.md` when setup or user-facing behavior changes.

## Build, Test, and Development Commands

Run commands from the repository root:

- `flutter pub get` resolves Dart and Flutter dependencies.
- `flutter analyze` reports static analysis issues.
- `flutter test` runs the test suite.
- `flutter run -d linux` launches the Linux app; use `flutter devices` to find an Android device or emulator, then pass its device ID to `flutter run -d <device-id>`.
- `flutter build apk` creates an Android APK; `flutter build linux` builds the Linux app when the required platform tooling is installed.

## Coding Style & Naming Conventions

Use Dart’s standard formatting: two spaces for indentation and trailing commas for multiline argument lists. Format changed Dart files with `dart format`. Use `UpperCamelCase` for types, `lowerCamelCase` for members and variables, and `snake_case.dart` for filenames. Prefer small, focused widgets and services, and handle `yt-dlp` process failures and user-visible download errors explicitly.

## Testing Guidelines

Use Flutter’s `flutter_test` framework. Name test files `*_test.dart` and organize cases around observable behavior, including search results, metadata choices, and download error handling. Run `flutter test` and `flutter analyze` before submitting changes; add or update tests when behavior changes.

## Commit & Pull Request Guidelines

No commit history is available in this checkout to establish a project-specific convention. Write concise, imperative commit subjects, for example `Handle yt-dlp download failures`. Pull requests should explain the user-visible change, note platform impact and verification performed, link relevant issues, and include screenshots for UI changes.

## Security & Configuration

Do not commit credentials, personal download paths, or machine-specific configuration. Keep `yt-dlp` invocation arguments safely separated rather than assembling shell commands from user input, and document any new platform setup requirements.
