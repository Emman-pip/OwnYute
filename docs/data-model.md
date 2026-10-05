# Data Model

All domain types live in `lib/core/models.dart` and are JSON-serialized into the drift database. The database is intentionally schema-light: five tables store JSON blobs keyed by an identifier, which keeps migrations simple and records forward-compatible.

## Domain models

### `Track`

A YouTube search result, playlist entry, or a synthetic local track.

| Field | Type | Meaning |
| --- | --- | --- |
| `id` | `String` | YouTube video/playlist id. |
| `url` | `String` | Watch or playlist URL. |
| `title` | `String` | Song title. |
| `artist` | `String` | Uploader/channel or artist. |
| `album` | `String` | Album, when known. |
| `artwork` | `String` | Cover image: local path or HTTP(S) URL. |
| `duration` | `int` | Seconds. |
| `streamUrl` | `String` | Resolved audio stream for preview. |

### `PlaylistRef`

A lightweight `{id, title}` reference to a virtual playlist folder. Tracks carry a `List<PlaylistRef>`, so one saved file can belong to many playlist folders.

### `QueueBatchRef`

`{id, title, playlist?}` describing a batch a queued song belongs to (for example, a playlist download).

### `QueueItem`

A queued download.

| Field | Type | Meaning |
| --- | --- | --- |
| `track` | `Track` | The song to download. |
| `status` | `String` | `pending`, `downloading`, `done`, or `failed`. |
| `error` | `String` | Failure message when `failed`. |
| `progress` | `double` | 0.0–1.0. |
| `inSingles` | `bool` | Whether it appears in the **Singles** group. |
| `batches` | `List<QueueBatchRef>` | Source batches. |
| `targetPlaylists` | `List<PlaylistRef>` | Playlists to assign on success. |

### `LibraryTrack`

A saved audio file in the local library.

| Field | Type | Meaning |
| --- | --- | --- |
| `path` | `String` | Filesystem path or Android `content://` URI. |
| `title`, `artist`, `album` | `String` | Tags read from the file. |
| `artwork` | `String` | Cover image source. |
| `duration` | `int` | Seconds. |
| `folder`, `folderName` | `String` | Physical storage folder. |
| `sourceTrackId` | `String` | Originating YouTube id, when applicable. |
| `playlists` | `List<PlaylistRef>` | Virtual playlist memberships. |

### `DuplicateChoice`

`skip`, `replace`, or `keepBoth` — how to handle an existing destination file.

## Database schema

`lib/core/database.dart` defines five drift tables (`schemaVersion = 2`; version 2 added `play_history_rows`):

| Table | Primary key | Payload |
| --- | --- | --- |
| `queue_rows` | `id` | `data` (JSON `QueueItem`) |
| `library_rows` | `path` | `data` (JSON `LibraryTrack`) |
| `history_rows` | `id` | `data` (JSON `Track`), `saved_at` |
| `play_history_rows` | `id` | `data` (JSON `Track`), `saved_at` |
| `settings_rows` | `key` | `value` |

### Key behaviors

- **Queue recovery:** on load, any item left in `downloading` is converted to `failed` with an *"Interrupted. Retry to continue."* message, so a crash never leaves a stuck spinner.
- **Upserts:** `saveLibrary`, `saveQueue`, and `saveSetting` use `insertOnConflictUpdate`, so repeated writes are idempotent.
- **JSON blobs:** adding a field to a model is backward compatible because `fromJson` supplies defaults for missing keys (verified by `model_compatibility_test.dart`).
- **Settings keys:** `destination`, `destinationLabel`, `themeChoice`, `themeMode`, `playerAnimationEnabled`, `folders`, and `folderLabel:<path>`.

## Persistence location

- **Linux:** `~/Documents/own_yute.sqlite` (opened via `path_provider``getApplicationDocumentsDirectory`, i.e. the XDG Documents directory).
- **Android:** the app's documents directory (app-private).
- **Artwork:** user-selected covers are copied into `<app support>/artwork/` and named by SHA-256 of their bytes, so identical images are stored once.
- **Managed `yt-dlp`:** `<app support>/tools/` with a `yt-dlp-last-check` timestamp file on Linux.

## Serialization

`models.dart` exposes `encodeJson`/`decodeJson` helpers. Every model implements `toJson`/`fromJson`, and `copyWith` returns updated immutable instances — the pattern the controller uses for all state mutations.
