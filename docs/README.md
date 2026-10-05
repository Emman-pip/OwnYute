# OwnYute Documentation

Technical documentation for **OwnYute**, a cross-platform (Linux + Android) Flutter application that searches, downloads, and organizes music from YouTube by wrapping `yt-dlp` and FFmpeg.

> Screenshots throughout these documents are captured from the real release build of the application.

## Contents

| Document | Description |
| --- | --- |
| [Tech Stack](tech-stack.md) | Languages, frameworks, packages, and native dependencies. |
| [Architecture](architecture.md) | Layers, state management, data flow, and concurrency model. |
| [Folder Structure](folder-structure.md) | Where every part of the project lives and why. |
| [Aim and Achievements](aim-and-achievements.md) | The goal of the project and what it has accomplished. |
| [Data Model](data-model.md) | Domain models and the drift database schema. |
| [Platform Integration](platform-integration.md) | Android Kotlin bridges, Linux GTK runner, and bundling. |
| [Build and Release](build-and-release.md) | Build commands, versioning, signing, and packaging. |
| [Testing](testing.md) | Unit, widget, and offline verification suites. |
| [Troubleshooting](troubleshooting.md) | Known failure modes and how they were resolved. |

## Project at a glance

- **Name:** OwnYute
- **Version:** 1.0.4 (5)
- **Platforms:** Android 7+ (API 24+, arm64-v8a and x86_64) and Linux desktop (x64 and arm64)
- **Language:** Dart (Flutter) with Kotlin for Android platform code
- **Media engine:** `yt-dlp` + FFmpeg
- **Local data:** drift (SQLite), stored in the app Documents directory
- **State management:** a single `ChangeNotifier` (`AppController`) with Riverpod providing it to the widget tree

## Quick links

- [Project README](../readme.md) — setup and user guide with screenshots
- [Branding assets](../assets/branding) — editable logo master and generation script
