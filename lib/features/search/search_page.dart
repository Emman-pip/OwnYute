import 'package:flutter/material.dart';

import '../../core/app_controller.dart';
import '../../core/artwork_image.dart';
import '../../core/models.dart';
import '../../core/track_row.dart';
import '../../core/ui_helpers.dart';
import '../library/folder_page.dart';
import '../library/library_actions.dart';
import '../library/library_widgets.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, required this.app, required this.onQueue});
  final AppController app;
  final VoidCallback onQueue;
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final query = TextEditingController();
  String term = '';
  bool showAllPlaylistFolders = false;
  bool showAllStorageFolders = false;
  final selection = TrackSelection();

  AppController get app => widget.app;

  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  void _search(String value) {
    setState(() => term = value.trim().toLowerCase());
    widget.app.search(value);
  }

  List<LibraryTrack> get _localMatches {
    final app = widget.app;
    if (term.isEmpty) return const [];
    return app.library
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
  }

  List<LibraryTrack> _selectedMatches(List<LibraryTrack> matches) => [
    for (final track in matches)
      if (selection.contains(track.path)) track,
  ];

  Future<void> _assignSelected(
    BuildContext context,
    List<LibraryTrack> matches,
  ) async {
    final selected = _selectedMatches(matches);
    if (selected.isEmpty) return;
    final playlist = await choosePlaylist(context, app);
    if (playlist == null) return;
    try {
      await app.assignManyToPlaylist(selected, playlist);
      if (!context.mounted) return;
      setState(selection.clear);
    } catch (failure) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(failure.toString())));
      }
    }
  }

  Future<void> _deleteSelected(
    BuildContext context,
    List<LibraryTrack> matches,
  ) async {
    final selected = _selectedMatches(matches);
    if (selected.isEmpty) return;
    await deleteSelectedSongs(context, app, selected);
    if (context.mounted) setState(selection.clear);
  }

  Widget _recentCard(BuildContext context, Track track, List<Track> group) {
    return SizedBox(
      width: 120,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => app.player.playTracks(group, group.indexOf(track)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ArtworkImage(
                  source: track.artwork,
                  width: double.infinity,
                  height: double.infinity,
                  fallback: const Center(
                    child: Icon(Icons.music_note, size: 40),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
                child: Text(
                  track.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final searching = term.isNotEmpty;
    final localMatches = _localMatches;
    selection.sync(localMatches.map((track) => track.path));
    final physical = app.storageFolderGroups;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: query,
          decoration: InputDecoration(
            hintText: 'Search your library and YouTube',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: term.isEmpty
                ? IconButton(
                    tooltip: 'Search',
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: () => _search(query.text),
                  )
                : IconButton(
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() {
                      query.clear();
                      term = '';
                      widget.app.search('');
                    }),
                  ),
          ),
          onSubmitted: _search,
          onChanged: (value) {
            if (value.trim().isEmpty && term.isNotEmpty) {
              setState(() => term = '');
            }
          },
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.link),
            label: const Text('Paste URL'),
            onPressed: () async {
              final url = await textDialog(
                context,
                'Paste YouTube URL',
                'Song or playlist URL',
              );
              if (url == null || !context.mounted) return;
              final song = await app.openUrl(url);
              if (!context.mounted) return;
              if (song != null) {
                await showTrackDialog(context, app, song, widget.onQueue);
              } else if (app.picker.isNotEmpty) {
                await showPlaylistDialog(
                  context,
                  app,
                  app.picker,
                  widget.onQueue,
                );
              }
            },
          ),
        ),
        if (searching) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back'),
              onPressed: () => setState(() {
                query.clear();
                term = '';
                widget.app.search('');
              }),
            ),
          ),
          const SectionTitle('In your library'),
          if (localMatches.isEmpty)
            const ListTile(title: Text('No downloaded songs match.')),
          if (localMatches.isNotEmpty && selection.active)
            SelectionBar(
              count: selection.count,
              deleting: app.deletingTotal > 0,
              progress: app.deleteProgress,
              onAddToPlaylist: () => _assignSelected(context, localMatches),
              onDelete: () => _deleteSelected(context, localMatches),
            ),
          for (final track in localMatches)
            LibraryTrackRow(
              app: app,
              track: track,
              group: localMatches,
              selectionMode: selection.active,
              selected: selection.contains(track.path),
              onSelect: () => setState(() => selection.toggle(track.path)),
              onLongPress: () => setState(() => selection.toggle(track.path)),
            ),
          const SectionTitle('Songs'),
          if (app.songs.isEmpty && !app.songsLoading)
            const ListTile(title: Text('No YouTube songs found.')),
          ...app.songs.map(
            (track) => TrackTile(
              title: track.title,
              subtitle: track.artist,
              artwork: track.artwork,
              onTap: () => showTrackDialog(context, app, track, widget.onQueue),
              pinned: TrackAction(
                tooltip: app.isInDownloadQueue(track)
                    ? 'In the download queue'
                    : 'Save offline',
                icon: app.isInDownloadQueue(track)
                    ? Icons.download_done
                    : Icons.download_for_offline_outlined,
                onPressed: app.isInDownloadQueue(track)
                    ? null
                    : () async {
                        await app.saveOffline(track);
                        if (!context.mounted) return;
                        showFeedback(
                          context,
                          '${track.title} queued for download.',
                        );
                      },
              ),
              actions: [
                TrackAction(
                  tooltip: 'Add to playback queue',
                  icon: Icons.queue_music,
                  onPressed: () {
                    app.player.addToQueue(track);
                    showFeedback(
                      context,
                      '${track.title} added to playback queue.',
                    );
                  },
                ),
                TrackAction(
                  tooltip: 'Preview',
                  icon: Icons.play_arrow,
                  onPressed: () => app.player.playTracks([track], 0),
                ),
              ],
            ),
          ),
          if (!app.songsExhausted)
            Align(
              alignment: Alignment.centerLeft,
              child: app.songsLoading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : TextButton.icon(
                      icon: const Icon(Icons.expand_more),
                      label: const Text('More results'),
                      onPressed: app.loadMoreSongs,
                    ),
            ),
          const SectionTitle('Playlists'),
          ...app.playlists.map(
            (track) => TrackTile(
              title: track.title,
              subtitle: track.artist,
              artwork: track.artwork,
              onTap: () => _openPlaylist(track),
              pinned: TrackAction(
                tooltip: 'Choose tracks from this playlist',
                icon: Icons.playlist_add_check,
                onPressed: () => _openPlaylist(track),
              ),
            ),
          ),
          if (!app.playlistsExhausted)
            Align(
              alignment: Alignment.centerLeft,
              child: app.playlistsLoading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : TextButton.icon(
                      icon: const Icon(Icons.expand_more),
                      label: const Text('More results'),
                      onPressed: app.loadMorePlaylists,
                    ),
            ),
        ] else ...[
          if (app.recentPlays.isNotEmpty) ...[
            const SectionTitle('Recently played'),
            SizedBox(
              height: 190,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: app.recentPlays.length.clamp(0, 12),
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) => _recentCard(
                  context,
                  app.recentPlays[index],
                  app.recentPlays,
                ),
              ),
            ),
          ],
          const SectionTitle('Playlist folders'),
          if (app.playlistFolders.isEmpty)
            const ListTile(
              title: Text('Playlists you create or download appear here.'),
            ),
          for (final folder in app.playlistFolders.take(
            showAllPlaylistFolders ? app.playlistFolders.length : 4,
          ))
            FolderTile(
              icon: Icons.folder_outlined,
              title: folder.title,
              subtitle:
                  '${app.library.where((track) => track.playlists.any((entry) => entry.id == folder.id)).length} songs',
              onTap: () => openPlaylistFolderPage(context, app, folder),
            ),
          if (app.playlistFolders.length > 4)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(
                  () => showAllPlaylistFolders = !showAllPlaylistFolders,
                ),
                child: Text(
                  showAllPlaylistFolders
                      ? 'Show less'
                      : 'See all ${app.playlistFolders.length}',
                ),
              ),
            ),
          const SectionTitle('Storage folders'),
          for (final entry in physical.entries.take(
            showAllStorageFolders ? physical.length : 4,
          ))
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
          if (physical.length > 4)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(
                  () => showAllStorageFolders = !showAllStorageFolders,
                ),
                child: Text(
                  showAllStorageFolders
                      ? 'Show less'
                      : 'See all ${physical.length}',
                ),
              ),
            ),
        ],
      ],
    );
  }

  Future<void> _openPlaylist(Track playlist) async {
    await app.openPlaylist(playlist);
    if (mounted && app.picker.isNotEmpty) {
      await showPlaylistDialog(context, app, app.picker, widget.onQueue);
    }
  }
}
