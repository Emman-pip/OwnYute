import 'package:flutter/material.dart';

import '../../core/app_controller.dart';
import '../../core/artwork_image.dart';
import '../../core/models.dart';
import '../../core/ui_helpers.dart';
import '../library/folder_page.dart';
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

  Widget _recentCard(BuildContext context, Track track, List<Track> group) {
    return SizedBox(
      width: 120,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () =>
              widget.app.player.playTracks(group, group.indexOf(track)),
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
    final app = widget.app;
    final searching = term.isNotEmpty;
    final localMatches = _localMatches;
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
          const SectionTitle('In your library'),
          if (localMatches.isEmpty)
            const ListTile(title: Text('No downloaded songs match.')),
          for (final track in localMatches)
            LibraryTrackTile(app: app, track: track, group: localMatches),
          const SectionTitle('Songs'),
          if (app.songs.isEmpty)
            const ListTile(title: Text('No YouTube songs found.')),
          ...app.songs.map(
            (track) => TrackTile(
              track: track,
              onTap: () => showTrackDialog(context, app, track, widget.onQueue),
            ),
          ),
          const SectionTitle('Playlists'),
          ...app.playlists.map(
            (track) => TrackTile(
              track: track,
              onTap: () async {
                await app.openPlaylist(track);
                if (context.mounted && app.picker.isNotEmpty) {
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
          for (final folder in app.playlistFolders)
            FolderTile(
              icon: Icons.folder_outlined,
              title: folder.title,
              subtitle:
                  '${app.library.where((track) => track.playlists.any((entry) => entry.id == folder.id)).length} songs',
              onTap: () => openPlaylistFolderPage(context, app, folder),
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
    );
  }
}
