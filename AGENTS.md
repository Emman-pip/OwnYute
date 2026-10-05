# OwnYute contributor guide

## Layout and architecture

- Flutter code lives in `lib/`, tests in `test/`, bundled files in `assets/`, and offline verification programs in `tool/`.
- `AppController` owns search, the Drift-backed **download queue**, library/settings persistence, downloads, and background artwork work.
- `PlayerController` owns the separate **playback queue**, platform playback, and `playback_snapshot.json`. Do not merge the two queue concepts.
- Keep `yt-dlp`, FFmpeg, storage, and metadata work in services/controllers rather than widgets. Android playback uses `MethodChannel('own_yute/player')`; Linux playback uses `ffplay`.
- Settings use Drift's existing key/value table. Regenerate Drift code only when the schema changes.

## Commands

Run from the repository root:

```sh
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter test tool/verify_download_test.dart  # requires FFmpeg/FFprobe
flutter run -d linux                         # Linux also requires ffplay
flutter build apk
```

## Conventions and behavior

- Follow standard Dart style: two-space indentation, trailing commas, `UpperCamelCase` types, `lowerCamelCase` members, and `snake_case.dart` files.
- Pass process arguments as lists; never interpolate user input into shell commands. Report download failures visibly and leave failed items retryable.
- Playback-queue append/remove/reorder changes must persist via the player snapshot and safely preserve or replace the current track.
- Artwork lookup is optional, enabled by default, sequential, and best-effort. Conservative matches may update display data and embed artwork with FFmpeg, but lookup or embedding failures must never block playback or downloads.
- Update `readme.md` for user-visible changes and add tests for queue state, settings persistence, metadata updates, and failure handling.
