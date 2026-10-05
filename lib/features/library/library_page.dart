import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/android_storage.dart';
import '../../core/app_controller.dart';
import '../../core/artwork_image.dart';
import '../../core/models.dart';
import '../../core/ui_helpers.dart';

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

  Future<bool> _confirmDelete(
    BuildContext context,
    String title,
    String detail,
  ) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(detail),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _deletePlaylist(BuildContext context, PlaylistRef folder) async {
    final members = app.library
        .where((track) => track.playlists.any((item) => item.id == folder.id))
        .toList();
    final shared = members.where((track) => track.playlists.length > 1).length;
    final detail =
        'Delete ${members.length} audio ${members.length == 1 ? 'file' : 'files'} from storage and remove this playlist from the app?'
        '${shared == 0 ? '' : ' $shared ${shared == 1 ? 'song also appears' : 'songs also appear'} in other playlists and will be removed there too.'}';
    if (!await _confirmDelete(context, 'Delete ${folder.title}?', detail)) {
      return;
    }
    try {
      await app.deletePlaylist(folder);
    } catch (failure) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(failure.toString())));
      }
    }
  }

  Future<PlaylistRef?> _choosePlaylist(BuildContext context) async {
    final folders = app.playlistFolders;
    final choice = await showDialog<PlaylistRef?>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Add to playlist folder'),
        children: [
          for (final folder in folders)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, folder),
              child: Text(folder.title),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(
              context,
              const PlaylistRef(id: 'new', title: 'New playlist folder'),
            ),
            child: const Text('Create new folder…'),
          ),
        ],
      ),
    );
    if (choice == null || !context.mounted) return null;
    var playlist = choice;
    if (choice.id == 'new') {
      final name = (await textDialog(
        context,
        'New playlist folder',
        'Folder name',
      ))?.trim();
      if (name == null || name.isEmpty) return null;
      playlist = PlaylistRef(
        id: 'local:${DateTime.now().microsecondsSinceEpoch}',
        title: name,
      );
    }
    return playlist;
  }

  Future<void> _assign(BuildContext context, LibraryTrack track) async {
    final playlist = await _choosePlaylist(context);
    if (playlist != null) await app.assignToPlaylist(track, playlist);
  }

  Future<void> _assignSelected(BuildContext context) async {
    final selected = app.library
        .where((track) => selectedPaths.contains(track.path))
        .toList();
    if (selected.isEmpty) return;
    final playlist = await _choosePlaylist(context);
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

  Future<void> _action(
    BuildContext context,
    LibraryTrack track,
    String action,
  ) async {
    if (action == 'delete') {
      if (!await _confirmDelete(
        context,
        'Delete ${track.title}?',
        'Delete this audio file from storage and remove it from the library and all playlist folders?',
      )) {
        return;
      }
      try {
        await app.deleteSong(track);
      } catch (failure) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(failure.toString())));
        }
      }
      return;
    }
    if (action == 'playlist') {
      await _assign(context, track);
      return;
    }
    try {
      if (action == 'edit') {
        final edited = await editTrackDialog(
          context,
          Track(
            id: track.path,
            url: track.path,
            title: track.title,
            artist: track.artist,
            album: track.album,
            artwork: track.artwork,
          ),
          pickArtwork: app.pickArtwork,
        );
        if (edited == null) return;
        await app.editLibrary(
          track,
          track.copyWith(
            title: edited.title,
            artist: edited.artist,
            album: edited.album,
            artwork: edited.artwork,
          ),
        );
      } else if (action == 'move') {
        final chosen = Platform.isAndroid
            ? await AndroidStorage.pickFolder()
            : await FilePicker.getDirectoryPath(
                dialogTitle: 'Move track to folder',
              );
        if (chosen == null || chosen.isEmpty) return;
        await app.moveTrack(track, chosen);
      }
    } catch (failure) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(failure.toString())));
      }
    }
  }

  Widget _track(
    BuildContext context,
    LibraryTrack track,
    List<LibraryTrack> group, {
    bool allowSelection = false,
  }) {
    final selected = selectedPaths.contains(track.path);
    return ListTile(
      leading: allowSelection && selecting
          ? Checkbox(value: selected, onChanged: (_) => _toggleSelection(track))
          : ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: ArtworkImage(
                source: track.artwork,
                width: 48,
                height: 48,
                fallback: const SizedBox.square(
                  dimension: 48,
                  child: Icon(Icons.audio_file),
                ),
              ),
            ),
      title: Text(track.title),
      subtitle: Text(
        track.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      selected: allowSelection && selected,
      onTap: allowSelection && selecting
          ? () => _toggleSelection(track)
          : () => app.player.playLocal(group, group.indexOf(track)),
      onLongPress: allowSelection ? () => _toggleSelection(track) : null,
      trailing: allowSelection && selecting
          ? null
          : PopupMenuButton<String>(
              onSelected: (action) => _action(context, track, action),
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'playlist',
                  child: Text('Add to playlist folder'),
                ),
                PopupMenuItem(value: 'edit', child: Text('Edit metadata')),
                PopupMenuItem(value: 'move', child: Text('Move file')),
                PopupMenuItem(value: 'delete', child: Text('Delete song')),
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final term = query.trim().toLowerCase();
    final visible = term.isEmpty
        ? app.library
        : app.library
              .where(
                (track) =>
                    track.title.toLowerCase().contains(term) ||
                    track.artist.toLowerCase().contains(term) ||
                    track.album.toLowerCase().contains(term) ||
                    track.playlists.any(
                      (folder) => folder.title.toLowerCase().contains(term),
                    ),
              )
              .toList();
    selectedPaths.retainAll(app.library.map((track) => track.path).toSet());
    final physical = <String, List<LibraryTrack>>{};
    final visibleFolders = app.playlistFolders
        .where(
          (folder) => visible.any(
            (track) => track.playlists.any((entry) => entry.id == folder.id),
          ),
        )
        .toList();
    for (final track in visible) {
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
          onChanged: (value) {
            setState(() => query = value);
            if (app.library.isNotEmpty && value.trim().isNotEmpty) {
              allSongsController.expand();
            }
          },
        ),
        if (app.library.isEmpty)
          const ListTile(
            title: Text('Downloaded and imported music appears here.'),
          ),
        if (app.library.isNotEmpty && visible.isEmpty)
          const ListTile(title: Text('No songs match your search.')),
        if (visible.isNotEmpty) ...[
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
                    final visiblePaths = visible
                        .map((track) => track.path)
                        .toSet();
                    if (visiblePaths.every(selectedPaths.contains)) {
                      selectedPaths.removeAll(visiblePaths);
                    } else {
                      selectedPaths.addAll(visiblePaths);
                    }
                  }),
                  child: Text(
                    visible.every((track) => selectedPaths.contains(track.path))
                        ? 'Clear visible songs'
                        : 'Select all visible songs',
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
              title: Text('${visible.length} songs'),
              children: [
                for (final track in visible)
                  _track(context, track, visible, allowSelection: true),
              ],
            ),
          ),
          const SectionTitle('Playlist folders'),
          if (visibleFolders.isEmpty && term.isEmpty)
            const ListTile(
              title: Text('Add a song to create a playlist folder.'),
            ),
          for (final folder in visibleFolders)
            Card(
              child: ExpansionTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(folder.title),
                trailing: IconButton(
                  tooltip: 'Delete playlist ${folder.title}',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _deletePlaylist(context, folder),
                ),
                children: [
                  for (final track in visible.where(
                    (item) =>
                        item.playlists.any((entry) => entry.id == folder.id),
                  ))
                    _track(
                      context,
                      track,
                      visible
                          .where(
                            (item) => item.playlists.any(
                              (entry) => entry.id == folder.id,
                            ),
                          )
                          .toList(),
                    ),
                ],
              ),
            ),
          const SectionTitle('Storage folders'),
          for (final folder in physical.entries)
            Card(
              child: ExpansionTile(
                leading: const Icon(Icons.folder_open_outlined),
                title: Text(
                  folder.value.first.folderName.isNotEmpty
                      ? folder.value.first.folderName
                      : folder.key,
                ),
                children: [
                  for (final track in folder.value)
                    _track(context, track, folder.value),
                ],
              ),
            ),
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
