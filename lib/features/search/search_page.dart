import 'package:flutter/material.dart';

import '../../core/app_controller.dart';
import '../../core/ui_helpers.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, required this.app, required this.onQueue});
  final AppController app;
  final VoidCallback onQueue;
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final query = TextEditingController();
  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: query,
          decoration: InputDecoration(
            labelText: 'Search YouTube',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              icon: const Icon(Icons.arrow_forward),
              onPressed: () => app.search(query.text),
            ),
          ),
          onSubmitted: app.search,
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
        if (app.history.isNotEmpty) ...[
          const SectionTitle('Recent'),
          ...app.history
              .take(5)
              .map(
                (track) => TrackTile(
                  track: track,
                  onTap: () =>
                      showTrackDialog(context, app, track, widget.onQueue),
                ),
              ),
        ],
        const SectionTitle('Songs'),
        if (app.songs.isEmpty)
          const ListTile(title: Text('Search for songs to begin.')),
        ...app.songs.map(
          (track) => TrackTile(
            track: track,
            onTap: () => showTrackDialog(context, app, track, widget.onQueue),
          ),
        ),
        const SectionTitle('Playlists'),
        if (app.playlists.isEmpty)
          const ListTile(
            title: Text('No playlists found. You can paste a playlist URL.'),
          ),
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
      ],
    );
  }
}
