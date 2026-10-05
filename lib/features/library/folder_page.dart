import 'package:flutter/material.dart';

import '../../core/app_controller.dart';
import '../../core/models.dart';
import '../../core/track_row.dart';
import 'library_actions.dart';
import 'library_widgets.dart';

/// A dedicated page listing the tracks of one folder or playlist.
///
/// Selection lives here, not in the library, so long-pressing a row in a folder
/// never disturbs a selection the user made in the library list.
class FolderPage extends StatefulWidget {
  const FolderPage({
    super.key,
    required this.app,
    required this.title,
    required this.resolveTracks,
    this.folderActions,
  });
  final AppController app;
  final String title;
  final List<LibraryTrack> Function(AppController app) resolveTracks;

  /// Page-level commands shown behind the AppBar `⋮` (refresh artwork, delete
  /// folder). Null for playlist folders, which keep their library-page button.
  final List<TrackAction> Function(AppController app, String title)?
  folderActions;

  @override
  State<FolderPage> createState() => _FolderPageState();
}

class _FolderPageState extends State<FolderPage> {
  final selection = TrackSelection();

  AppController get app => widget.app;

  List<LibraryTrack> _selectedTracks(List<LibraryTrack> tracks) => [
    for (final track in tracks)
      if (selection.contains(track.path)) track,
  ];

  Future<void> _assignSelected(
    BuildContext context,
    List<LibraryTrack> tracks,
  ) async {
    final selected = _selectedTracks(tracks);
    if (selected.isEmpty) return;
    final playlist = await choosePlaylist(context, app);
    if (playlist == null) return;
    try {
      await app.assignManyToPlaylist(selected, playlist);
      if (!context.mounted) return;
      setState(selection.clear);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Added ${selected.length} ${selected.length == 1 ? 'song' : 'songs'} to ${playlist.title}.',
          ),
        ),
      );
    } catch (failure) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(failure.toString())));
      }
    }
  }

  Future<void> _deleteSelected(
    BuildContext context,
    List<LibraryTrack> tracks,
  ) async {
    final selected = _selectedTracks(tracks);
    if (selected.isEmpty) return;
    await deleteSelectedSongs(context, app, selected);
    if (context.mounted) setState(selection.clear);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: app,
      builder: (context, _) {
        final tracks = widget.resolveTracks(app);
        selection.sync(tracks.map((track) => track.path));
        final folderActions =
            widget.folderActions?.call(app, widget.title) ?? const [];
        return Scaffold(
          appBar: AppBar(
            title: Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: app.closeFolderPage,
            ),
            actions: [
              if (selection.active)
                IconButton(
                  tooltip: 'Cancel selection',
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(selection.clear),
                ),
              if (folderActions.isNotEmpty)
                PopupMenuButton<int>(
                  tooltip: 'Folder actions',
                  icon: const Icon(Icons.more_vert),
                  onSelected: (index) => folderActions[index].onPressed?.call(),
                  itemBuilder: (context) => [
                    for (var index = 0; index < folderActions.length; index++)
                      PopupMenuItem(
                        value: index,
                        child: Text(folderActions[index].tooltip),
                      ),
                  ],
                ),
            ],
          ),
          // The bar sits above the list, not inside it: it cannot cover a row,
          // and it stays put while a long list is scrolled.
          body: tracks.isEmpty
              ? const Center(child: Text('No songs in this folder.'))
              : Column(
                  children: [
                    if (selection.active)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: SelectionBar(
                          count: selection.count,
                          deleting: app.deletingTotal > 0,
                          progress: app.deleteProgress,
                          onAddToPlaylist: () =>
                              _assignSelected(context, tracks),
                          onDelete: () => _deleteSelected(context, tracks),
                        ),
                      ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: tracks.length,
                        itemBuilder: (context, index) {
                          final track = tracks[index];
                          return LibraryTrackRow(
                            app: app,
                            track: track,
                            group: tracks,
                            selectionMode: selection.active,
                            selected: selection.contains(track.path),
                            onSelect: () =>
                                setState(() => selection.toggle(track.path)),
                            onLongPress: () =>
                                setState(() => selection.toggle(track.path)),
                          );
                        },
                      ),
                    ),
                  ],
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
  app.openFolderOverlay(
    FolderPage(
      app: app,
      title: folder.title,
      resolveTracks: (app) => app.library
          .where(
            (track) => track.playlists.any((entry) => entry.id == folder.id),
          )
          .toList(),
    ),
  );
}

void openStorageFolderPage(
  BuildContext context,
  AppController app,
  String folderPath,
  String title,
) {
  app.openFolderOverlay(
    FolderPage(
      app: app,
      title: title,
      resolveTracks: (app) => app.library
          .where((track) => AppController.folderOf(track) == folderPath)
          .toList(),
      folderActions: (app, title) => [
        TrackAction(
          tooltip: 'Refresh artwork for folder',
          icon: Icons.image_search_outlined,
          onPressed: () => refreshFolderArtwork(context, app, folderPath),
        ),
        TrackAction(
          tooltip: 'Delete folder',
          icon: Icons.delete_outline,
          onPressed: () => deleteStorageFolder(context, app, folderPath),
        ),
      ],
    ),
  );
}
