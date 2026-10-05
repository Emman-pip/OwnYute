import 'package:flutter/material.dart';

import '../../core/app_controller.dart';
import '../../core/models.dart';
import '../../core/ui_helpers.dart';
import 'folder_page.dart';
import 'library_actions.dart';
import 'library_widgets.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key, required this.app});
  final AppController app;
  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  AppController get app => widget.app;
  String query = '';
  final searchController = TextEditingController();
  final allSongsController = ExpansibleController();
  final selectedPaths = <String>{};
  bool selecting = false;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _assignSelected(BuildContext context) async {
    final selected = app.library
        .where((track) => selectedPaths.contains(track.path))
        .toList();
    if (selected.isEmpty) return;
    final playlist = await choosePlaylist(context, app);
    if (playlist == null) return;
    try {
      await app.assignManyToPlaylist(selected, playlist);
      if (!context.mounted) return;
      setState(() {
        selecting = false;
        selectedPaths.clear();
      });
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

  void _toggleSelection(LibraryTrack track) {
    setState(() {
      selecting = true;
      if (!selectedPaths.add(track.path)) selectedPaths.remove(track.path);
    });
  }

  @override
  Widget build(BuildContext context) {
    final term = query.trim().toLowerCase();
    final searching = term.isNotEmpty;
    final visible = searching
        ? app.library
              .where(
                (track) =>
                    track.title.toLowerCase().contains(term) ||
                    track.artist.toLowerCase().contains(term) ||
                    track.album.toLowerCase().contains(term) ||
                    track.playlists.any(
                      (folder) => folder.title.toLowerCase().contains(term),
                    ),
              )
              .toList()
        : app.library;
    selectedPaths.retainAll(app.library.map((track) => track.path).toSet());
    final physical = <String, List<LibraryTrack>>{};
    for (final track in app.library) {
      final folder = track.folder.isNotEmpty
          ? track.folder
          : track.path.substring(0, track.path.lastIndexOf('/'));
      (physical[folder] ??= []).add(track);
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Library', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        TextField(
          controller: searchController,
          decoration: InputDecoration(
            hintText: 'Search songs, artists, albums, or playlists',
            prefixIcon: const Icon(Icons.search),
            border: const OutlineInputBorder(),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() {
                      searchController.clear();
                      query = '';
                    }),
                  ),
          ),
          onChanged: (value) => setState(() => query = value),
        ),
        if (searching) ...[
          if (visible.isEmpty)
            const ListTile(title: Text('No songs match your search.')),
          for (final track in visible)
            LibraryTrackTile(app: app, track: track, group: visible),
        ] else ...[
          if (app.library.isEmpty)
            const ListTile(
              title: Text('Downloaded and imported music appears here.'),
            ),
          if (app.library.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 20, bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'All songs',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        selecting = !selecting;
                        if (!selecting) selectedPaths.clear();
                      });
                      if (selecting) allSongsController.expand();
                    },
                    icon: Icon(selecting ? Icons.close : Icons.checklist),
                    label: Text(selecting ? 'Cancel' : 'Select'),
                  ),
                ],
              ),
            ),
            if (selecting)
              Card(
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: ListTile(
                  title: Text('${selectedPaths.length} selected'),
                  subtitle: TextButton(
                    style: TextButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: () => setState(() {
                      final visiblePaths = app.library
                          .map((track) => track.path)
                          .toSet();
                      if (visiblePaths.every(selectedPaths.contains)) {
                        selectedPaths.removeAll(visiblePaths);
                      } else {
                        selectedPaths.addAll(visiblePaths);
                      }
                    }),
                    child: Text(
                      app.library.every(
                            (track) => selectedPaths.contains(track.path),
                          )
                          ? 'Clear all songs'
                          : 'Select all songs',
                    ),
                  ),
                  trailing: IconButton.filled(
                    tooltip: 'Add selected songs to playlist',
                    onPressed: selectedPaths.isEmpty
                        ? null
                        : () => _assignSelected(context),
                    icon: const Icon(Icons.playlist_add),
                  ),
                ),
              ),
            Card(
              child: ExpansionTile(
                controller: allSongsController,
                initiallyExpanded: false,
                leading: const Icon(Icons.library_music),
                title: Text('${app.library.length} songs'),
                children: [
                  for (final track in app.library)
                    LibraryTrackTile(
                      app: app,
                      track: track,
                      group: app.library,
                      allowSelection: true,
                      selected: selectedPaths.contains(track.path),
                      selecting: selecting,
                      onToggleSelection: () => _toggleSelection(track),
                    ),
                ],
              ),
            ),
            const SectionTitle('Playlist folders'),
            if (app.playlistFolders.isEmpty)
              const ListTile(
                title: Text('Add a song to create a playlist folder.'),
              ),
            for (final folder in app.playlistFolders)
              FolderTile(
                icon: Icons.folder_outlined,
                title: folder.title,
                subtitle:
                    '${app.library.where((track) => track.playlists.any((entry) => entry.id == folder.id)).length} songs',
                onTap: () => openPlaylistFolderPage(context, app, folder),
                trailing: IconButton(
                  tooltip: 'Delete playlist ${folder.title}',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => deletePlaylistFolder(context, app, folder),
                ),
              ),
            const SectionTitle('Storage folders'),
            for (final entry in physical.entries)
              FolderTile(
                icon: Icons.folder_open_outlined,
                title: entry.value.first.folderName.isNotEmpty
                    ? entry.value.first.folderName
                    : entry.key,
                subtitle: '${entry.value.length} songs',
                onTap: () => openStorageFolderPage(
                  context,
                  app,
                  entry.key,
                  entry.value.first.folderName.isNotEmpty
                      ? entry.value.first.folderName
                      : entry.key,
                ),
              ),
          ],
        ],
        const SectionTitle('Add music'),
        Card(
          child: ListTile(
            leading: const Icon(Icons.create_new_folder_outlined),
            title: const Text('Import folder'),
            subtitle: const Text(
              'Browse and keep a music folder in the library',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: app.importFolder,
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.audio_file_outlined),
            title: const Text('Import audio files'),
            subtitle: const Text('Copy selected audio files into the app'),
            trailing: const Icon(Icons.chevron_right),
            onTap: app.importFiles,
          ),
        ),
      ],
    );
  }
}
