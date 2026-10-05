# Troubleshooting

This document records the significant failure modes encountered while building OwnYute, their root causes, and the fixes that are now part of the codebase.

## Release-only crash on the first search or update check

**Symptom**

```
java.lang.ExceptionInInitializerError
Caused by: java.lang.RuntimeException: class b3 is not a concrete class
  at ...ExtraFieldUtils.<clinit>
```

The app crashed on Android release builds the first time it used `yt-dlp` (search or update).

**Root cause**

Flutter enables R8 shrinking/obfuscation for release builds, and the bundled `youtubedl-android` AAR publishes **no consumer ProGuard rules**. R8 stripped `org.apache.commons.compress.archivers.zip` classes (for example `AsiExtraField`, obfuscated to `b3`) that are reached through reflection when `yt-dlp`/FFmpeg unpack their bundled packages. The reflective lookup then failed and aborted a static initializer.

**Fix**

Added `android/app/proguard-rules.pro`:

```proguard
-keep class com.yausername.** { *; }
-keep class org.apache.commons.compress.archivers.zip.** { *; }
```

Flutter auto-includes `android/app/proguard-rules.pro` when it exists, so no build-script change was needed. Verified by inspecting the regenerated `mapping.txt`/`usage.txt`: the classes are no longer stripped or renamed.

## `NetworkOnMainThreadException` during update checks

**Symptom**

```
android.os.NetworkOnMainThreadException
  at ...YoutubeDLUpdater.checkForUpdate
  at ...YoutubeDL.updateYoutubeDL
```

Triggered by the automatic pre-search update check.

**Root cause**

In `ToolBridge`, `updateNightly()` was accidentally called *inside* `main.post { ... }`, so the updater's network request ran on the UI thread.

**Fix**

Run the update on the existing single-thread worker and post only the result callback back to the main thread:

```kotlin
"updateNightly" -> ytDlpWorker.execute {
    try {
        val version = updateNightly()
        main.post { result.success(version) }
    } catch (failure: Throwable) { ... }
}
```

This also puts failures back inside the `try/catch`, so being offline becomes a non-fatal update error instead of a crash.

## Metadata edit crash: `Unsupported value: 'kotlin.Unit'`

**Symptom**

```
java.lang.IllegalArgumentException: Unsupported value: 'kotlin.Unit' of type 'class kotlin.Unit'
  at io.flutter.plugin.common.StandardMessageCodec.writeValue
  at com.example.own_yute.StorageBridge...
```

Happened whenever a song's metadata was edited on Android.

**Root cause**

`StorageBridge.replace()` and `delete()` are Kotlin functions that return `Unit`. The bridge assigned that `Unit` to the channel result and returned it to Flutter, whose codec cannot encode `kotlin.Unit`.

**Fix**

Execute the operation and return `null`:

```kotlin
"replace" -> { replace(string(call, "path"), string(call, "source")); null }
"delete"  -> { delete(string(call, "path")); null }
```

## Local cover art could not be added

**Symptom**

The metadata editor only accepted an HTTP(S) artwork URL; a local image could not be chosen, FFmpeg rejected local paths, and the UI always used `Image.network`.

**Fix**

- Added `AppController.pickArtwork`, which copies a chosen JPG/PNG/WebP into `<app support>/artwork/` (deduplicated by SHA-256).
- `DownloadService._artworkFile` now accepts a selected image, a `file://` URI, or an HTTP(S) URL.
- Added `ArtworkImage`, a widget that renders local files or network images uniformly, used in tiles, the queue, the dialog preview, and the player.

## Album/single cover not embedded on download

**Symptom**

Downloads produced audio without cover art when the source had a thumbnail.

**Fix**

The download command now passes `--write-thumbnail` to `yt-dlp`, then FFmpeg attaches the downloaded image as an MJPEG `attached_pic`. User-selected artwork takes priority. Cover retrieval and embedding are **best-effort**: on failure the conversion is retried audio-only so the music is still saved.

## Search blocked on a fresh profile

**Symptom**

On a brand-new install, the first search appears to hang.

**Cause**

Before the first YouTube operation each day, the app downloads and validates a nightly `yt-dlp`. On a slow network this takes time and the search waits behind it.

**Mitigation**

- A failed check keeps using the last working copy or the system `yt-dlp`.
- Settings shows update errors and offers **Check now** to retry manually.

## Narrow-screen layout overflow

**Symptom**

The settings updater row (`yt-dlp nightly` + **Check now**) overflowed horizontally on a 320px-wide phone.

**Fix**

The row is now responsive: below 430px the action button moves beneath the status text instead of competing for width.

## Reading a crash report

Settings → **Build and crash report** (Android) produces a scrubbed summary:

- OwnYute version, Android/SDK/ABI
- Last operation stage and time
- Last process exit reason
- The last tool error and last fatal error

URLs and storage paths are removed automatically. Capture `adb logcat -d -v time` as well when ADB is available.
