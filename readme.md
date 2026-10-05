# OwnYute

OwnYute is a Flutter music downloader and library for Linux and Android. Search YouTube or paste a song or playlist URL, preview tracks, choose tracks, and save MP3 files to a folder you select. The queue, recent tracks, library index, and theme choice survive a restart.

## Linux setup

Install Flutter with Linux desktop support, `yt-dlp`, and `ffmpeg` (including `ffplay`). SQLite is bundled by the Dart package. On Debian or Ubuntu, for example:

```sh
sudo apt install ffmpeg yt-dlp
flutter pub get
flutter run -d linux
```

On x64 and arm64 Linux, OwnYute checks for a nightly `yt-dlp` release before the first YouTube operation and at most once every 24 hours. It downloads a verified executable into the app support directory and uses that copy for search, previews, and downloads. The system `yt-dlp` on `PATH` is used until an app copy is available. A failed check keeps using the last working copy, or the system executable if none was installed. `ffmpeg` and `ffplay` must remain on `PATH`.

## Android setup

The Android app supports Android 7 (API 24) and later on arm64 phones and x86_64 emulators. Install Flutter and the Android SDK, then connect a device or start an emulator:

```sh
flutter pub get
flutter devices
flutter run -d <device-id>
# Or build an APK:
flutter build apk
```

Android bundles `yt-dlp` and FFmpeg through [youtubedl-android](https://github.com/yausername/youtubedl-android). The app needs internet access for search, previews, artwork, and downloads. The first use of Android's folder picker grants OwnYute access to that folder through the Storage Access Framework; select a download folder from Queue or Settings and select existing music folders from Library. Access is saved across restarts. If a folder is moved, removed, or access is revoked, choose it again. Individual imported audio files are copied into the app's `Imported` folder. Playback uses an Android foreground service with a media notification; on Android 13 and later, allow notifications to show its controls. The bundled Android tool library is GPL-3.0 licensed, which matters when distributing modified APKs.

Before the first YouTube operation each day, Android checks the nightly `yt-dlp` channel. If the update fails or the device is offline, the bundled or previously updated version remains available. Settings shows update errors and has **Check now** for a manual retry. Automatic updates cannot guarantee that YouTube will always work when the site changes.

The Android updater checks that the installed tool runs before and after updating. If the nightly update fails validation, it restores the previous working tool or the bundled copy. Settings also has **Build and crash report**; tap its copy button after relaunching the app to share the app version, last tool step, and any recorded error. The report removes YouTube URLs and storage paths. Install the latest APK over an existing installation to keep app data when investigating a crash.

The current release build uses Flutter's debug signing key so it can be installed for testing. Configure your own Android signing key before publishing.

## Use

1. Search from Search, or use **Paste URL** for a YouTube song or playlist. Playlist results open a track picker with **Select all**.
2. Preview a track with the play button. The mini player remains visible while browsing. Its expanded view provides seek, previous/next, shuffle, repeat, and the playback queue. Drag the seek slider and release to jump once; the player shows buffering and pauses the time bar while loading. Android plays local and streamed tracks through its background media service.
3. Add tracks to Queue. Long song titles wrap so the full name remains visible on a phone. Each **Add selected** action creates a collapsible batch; individual additions appear in **Singles**. A song shared by batches downloads once and appears in each batch. Use a queued song's menu to assign it to an existing or new virtual playlist folder before downloading. Edit a batch with its pencil button, or use the top menu to edit all queued items, cancel downloads, or **Clear finished items**. Clearing finished items leaves saved files and Library entries intact. Choose a destination and an optional physical folder. Existing files prompt **Skip**, **Replace**, or **Keep both**.
4. Downloads run sequentially. OwnYute requests the best available source audio and source thumbnail, converts the audio to high quality variable bitrate MP3 with FFmpeg, and writes title, artist, album, and the album/single cover. User-selected artwork takes priority. Artwork retrieval and embedding are best-effort, so an unavailable or unsupported cover does not prevent the music from being saved. Failed or interrupted items remain in the queue for retry.
5. Library starts with **All songs** collapsed, followed by virtual **Playlist folders**, physical **Storage folders**, and the **Import folder** / **Import audio files** actions. Search by song, artist, album, or playlist. Use **Select** above All songs to expand the list, choose several visible tracks, and add them to one existing or new playlist folder. Downloaded playlist tracks are assigned to their source playlist folder, and the same saved file can appear in multiple playlist folders. Use a song's menu to add existing music to a playlist folder, edit metadata, choose local JPG, PNG, or WebP cover artwork (or enter an image URL), move its file, or delete it from storage and the app. The delete button on a playlist folder deletes all its member audio files and library entries, including songs shared with other playlists, after confirmation. Metadata editing briefly stops playback of that song and resumes near the previous position. A failed edit leaves the library entry and original audio in place.
6. Choose **System**, **Light**, **Dark**, **Dark Blue**, **Dark Pink**, **Pastel Blue**, or **Pastel Pink** in Settings. Animated artwork in the expanded player can be disabled there and follows the device's reduced motion setting. The layout adapts from phone navigation to a wider desktop rail.

## Development checks

```sh
flutter analyze
flutter test
flutter build linux
flutter build apk
```

Offline checks run with `flutter test tool/verify_services_test.dart`, `flutter test tool/verify_database_test.dart`, and `flutter test tool/verify_download_test.dart`. The download check requires FFmpeg and FFprobe. Flutter unit tests are in `test/`.

## Branding assets

The editable logo master is `assets/branding/ownyute_logo.svg`. Android launcher icons and the Linux window icon are generated from it. Install `rsvg-convert` (`librsvg2-bin` on Debian or Ubuntu), then regenerate every size with:

```sh
tool/generate_app_icons.sh
```

Android includes legacy, adaptive, round, and monochrome themed icons. Linux builds bundle the GTK window icon, a desktop entry, and standard hicolor assets for packaging.

For Android verification, use a connected device to search, open a song URL (including a radio mix watch URL), preview it, download it, and play the downloaded MP3. Import and play a known-good MP3 separately, then repeat playback after restarting the app. If a step fails, copy **Build and crash report** from Settings after reopening the app. Capture `adb logcat -d -v time` when ADB is available.
