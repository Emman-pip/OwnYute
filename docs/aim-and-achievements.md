# Aim and Achievements

## Aim

OwnYute exists to give people **ownership of their music on desktop and mobile** without relying on a streaming subscription or a cloud account. It brings the flexibility of `yt-dlp` into a friendly, native-feeling app: search YouTube, preview tracks, download them as high-quality MP3s with correct tags and album/single cover art, and manage the resulting files as a real music library — all running locally on Linux and Android.

The project targets four goals:

1. **Local ownership** — files live in folders the user chooses, with metadata and artwork embedded in the files themselves.
2. **Cross-platform parity** — the same core experience on Linux desktop and Android, with native integration on each (GTK window/desktop entry; SAF storage and a media foreground service).
3. **Resilience** — the app keeps working as YouTube changes by updating `yt-dlp` nightly and validating every update before adopting it.
4. **Transparency and safety** — process arguments are passed as arrays, credentials and personal paths are never committed, and errors are recorded in a shareable, scrubbed crash report.

## What has been achieved

### Functional

| Capability | Status | Notes |
| --- | --- | --- |
| YouTube search and playlist parsing | ✅ | `yt-dlp --dump-single-json`, songs and playlists separated. |
| Paste song or playlist URL | ✅ | Watch URLs, radio mixes, and playlists; a track picker with **Select all**. |
| Streaming preview | ✅ | Local and streamed previews with buffering feedback. |
| Batch and single queueing | ✅ | Collapsible batches plus a **Singles** group; shared songs de-duplicate. |
| Sequential downloads | ✅ | Progress, cancellation, and retry for failed/interrupted items. |
| MP3 transcoding | ✅ | Best available audio to VBR MP3 (`libmp3lame -qscale:a 0`). |
| Metadata (title/artist/album) | ✅ | Written on download and editable afterward. |
| Album/single cover art | ✅ | Source thumbnail fetched and embedded; user-selected cover takes priority; best-effort fallback. |
| Duplicate handling | ✅ | **Skip**, **Replace**, **Keep both**. |
| Library management | ✅ | All songs, virtual playlist folders, physical storage folders. |
| Multi-select → playlist | ✅ | Select several visible songs and assign them to a playlist atomically. |
| Playback queue controls | ✅ | Seek, previous/next, shuffle, repeat, draggable seek bar. |
| Theming | ✅ | System, Light, Dark, Dark Blue, Dark Pink, Pastel Blue, Pastel Pink. |
| Branding | ✅ | Custom logo across Android and Linux, including adaptive/themed icons. |

### Platform integration

- **Android:** bundled `yt-dlp` + FFmpeg via `youtubedl-android`, SAF folder access persisted across restarts, a foreground media service with notification controls, and a crash-diagnostics report copied from Settings.
- **Linux:** app-managed nightly `yt-dlp` with checksum verification, system fallback, a GTK window and desktop entry, and standard hicolor icons for packaging.

### Reliability engineering

- Nightly `yt-dlp` updates are **validated before and after** installation, with automatic rollback to the previous or bundled copy.
- Artwork embedding is **best-effort**, so an unavailable cover never blocks a download.
- Durable state is written to SQLite and re-read on launch (queue, library, history, settings).
- A suite of **12 test files** plus offline verification tools covers search, downloads, database, model compatibility, theming, and layout.

### Documentation and assets

- A full technical documentation set in `docs/`.
- A README with screenshots captured from the real release build.
- An editable SVG logo master with a one-command regeneration script for every platform icon size.

## Resolved engineering challenges

Highlights of non-trivial problems solved during development (details in [Troubleshooting](troubleshooting.md)):

1. **R8 stripped reflection-reached classes** in `youtubedl-android`, crashing release builds. Fixed with explicit keep rules.
2. **Network on the main thread** during update checks crashed Android; fixed by moving update work off the UI thread.
3. **`kotlin.Unit` serialization** crashed metadata edits; fixed by returning `null` from the storage bridge.
4. **Local cover art** was unsupported; added a picker, persistent artwork storage, FFmpeg embedding, and a local-or-network image widget.

## Roadmap ideas

These are natural next steps, not current features:

- Additional audio formats (FLAC/M4A) beyond MP3.
- Concurrent downloads with a configurable limit.
- Desktop media-key and MPRIS integration on Linux.
- Full-text search across the local library.
