import 'package:flutter/material.dart';

import '../../core/app_controller.dart';
import '../../core/models.dart';
import 'library_widgets.dart';

/// A dedicated page listing the tracks of one folder or playlist.
class FolderPage extends StatelessWidget {
  const FolderPage({
    super.key,
    required this.app,
    required this.title,
    required this.resolveTracks,
  });
  final AppController app;
  final String title;
  final List<LibraryTrack> Function(AppController app) resolveTracks;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: app,
      builder: (context, _) {
        final tracks = resolveTracks(app);
        return Scaffold(
          appBar: AppBar(title: Text(title)),
          body: tracks.isEmpty
              ? const Center(child: Text('No songs in this folder.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: tracks.length,
                  itemBuilder: (context, index) => LibraryTrackTile(
                    app: app,
                    track: tracks[index],
                    group: tracks,
                  ),
                ),
        );
      },
    );
  }
}

void openPlaylistFolderPage(
  BuildContext context,
  AppController app,
  PlaylistRef folder,
) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => FolderPage(
        app: app,
        title: folder.title,
        resolveTracks: (app) => app.library
            .where(
              (track) => track.playlists.any((entry) => entry.id == folder.id),
            )
            .toList(),
      ),
    ),
  );
}

void openStorageFolderPage(
  BuildContext context,
  AppController app,
  String folderPath,
  String title,
) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => FolderPage(
        app: app,
        title: title,
        resolveTracks: (app) => app.library.where((track) {
          final trackFolder = track.folder.isNotEmpty
              ? track.folder
              : track.path.substring(0, track.path.lastIndexOf('/'));
          return trackFolder == folderPath;
        }).toList(),
      ),
    ),
  );
}
