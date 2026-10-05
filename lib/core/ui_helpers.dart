import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'artwork_image.dart';
import 'models.dart';
import 'track_row.dart';

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key});
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Text(title, style: Theme.of(context).textTheme.titleLarge),
  );
}

/// Confirms a row command. The current message is replaced rather than queued
/// behind it, so tapping an action on several rows does not bury the screen in
/// SnackBars.
void showFeedback(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );

Future<void> showTrackDialog(
  BuildContext context,
  AppController app,
  Track track,
  VoidCallback onQueue,
) async {
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(track.title),
      content: Text(track.artist.isEmpty ? track.url : track.artist),
      actions: [
        TextButton.icon(
          onPressed: () => app.player.playTracks([track], 0),
          icon: const Icon(Icons.play_arrow),
          label: const Text('Preview'),
        ),
        TextButton.icon(
          onPressed: () {
            app.player.addToQueue(track);
            // Captured before the pop: the dialog's own context is gone by the
            // time the confirmation needs a ScaffoldMessenger.
            showFeedback(context, '${track.title} added to playback queue.');
            Navigator.pop(context);
          },
          icon: const Icon(Icons.queue_music),
          label: const Text('Queue'),
        ),
        FilledButton(
          onPressed: () async {
            await app.saveOffline(track);
            if (context.mounted) Navigator.pop(context);
            onQueue();
          },
          child: const Text('Save offline'),
        ),
      ],
    ),
  );
}

/// The track picker used for pasted and searched playlists. Rows are ordinary
/// track rows in selection mode, so a tap *and* a long press toggle, which a
/// long-press-only picker would not allow.
Future<void> showPlaylistDialog(
  BuildContext context,
  AppController app,
  List<Track> tracks,
  VoidCallback onQueue,
) async {
  final selected = <String>{};
  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => Dialog(
        child: SizedBox(
          width: 560,
          height:
              (MediaQuery.sizeOf(context).height -
                      MediaQuery.viewInsetsOf(context).bottom -
                      MediaQuery.paddingOf(context).vertical -
                      48)
                  .clamp(180.0, 620.0),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Choose tracks (${selected.length}/${tracks.length})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => setDialogState(() {
                        if (selected.length == tracks.length) {
                          selected.clear();
                        } else {
                          selected.addAll(tracks.map((t) => t.id));
                        }
                      }),
                      child: Text(
                        selected.length == tracks.length
                            ? 'Clear all'
                            : 'Select all',
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: tracks.length,
                    itemBuilder: (context, index) {
                      final track = tracks[index];
                      void toggle() => setDialogState(() {
                        if (selected.contains(track.id)) {
                          selected.remove(track.id);
                        } else {
                          selected.add(track.id);
                        }
                      });
                      return TrackTile(
                        title: track.title,
                        subtitle: track.artist,
                        artwork: track.artwork,
                        dense: true,
                        selectionMode: true,
                        selected: selected.contains(track.id),
                        onTap: toggle,
                        onLongPress: toggle,
                        actions: [
                          TrackAction(
                            tooltip: 'Preview',
                            icon: Icons.play_arrow,
                            onPressed: () =>
                                app.player.playTracks(tracks, index),
                          ),
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
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      // Plays just the chosen tracks, in playlist order, so a
                      // batch can be auditioned before anything is downloaded.
                      OutlinedButton.icon(
                        onPressed: selected.isEmpty
                            ? null
                            : () {
                                final chosen = [
                                  for (final track in tracks)
                                    if (selected.contains(track.id)) track,
                                ];
                                Navigator.pop(context);
                                app.player.playTracks(chosen, 0);
                              },
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Preview selected'),
                      ),
                      FilledButton(
                        onPressed: selected.isEmpty
                            ? null
                            : () async {
                                await app.addAll(
                                  tracks.where((t) => selected.contains(t.id)),
                                  playlist: app.pickerPlaylist,
                                );
                                if (context.mounted) Navigator.pop(context);
                                onQueue();
                              },
                        child: const Text('Add selected'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Future<String?> textDialog(
  BuildContext context,
  String title,
  String label, {
  String initial = '',
}) async {
  return showDialog<String>(
    context: context,
    builder: (context) =>
        _TextEntryDialog(title: title, label: label, initial: initial),
  );
}

class _TextEntryDialog extends StatefulWidget {
  const _TextEntryDialog({
    required this.title,
    required this.label,
    required this.initial,
  });
  final String title;
  final String label;
  final String initial;
  @override
  State<_TextEntryDialog> createState() => _TextEntryDialogState();
}

class _TextEntryDialogState extends State<_TextEntryDialog> {
  late final TextEditingController controller = TextEditingController(
    text: widget.initial,
  );
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(widget.title),
    content: TextField(
      controller: controller,
      autofocus: true,
      decoration: InputDecoration(labelText: widget.label),
      onSubmitted: (_) => Navigator.pop(context, controller.text),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, controller.text),
        child: const Text('Save'),
      ),
    ],
  );
}

Future<Track?> editTrackDialog(
  BuildContext context,
  Track track, {
  Future<String?> Function()? pickArtwork,
}) async {
  return showDialog<Track>(
    context: context,
    builder: (context) =>
        _EditTrackDialog(track: track, pickArtwork: pickArtwork),
  );
}

class _EditTrackDialog extends StatefulWidget {
  const _EditTrackDialog({required this.track, this.pickArtwork});
  final Track track;
  final Future<String?> Function()? pickArtwork;
  @override
  State<_EditTrackDialog> createState() => _EditTrackDialogState();
}

class _EditTrackDialogState extends State<_EditTrackDialog> {
  late final title = TextEditingController(text: widget.track.title);
  late final artist = TextEditingController(text: widget.track.artist);
  late final album = TextEditingController(text: widget.track.album);
  late final artwork = TextEditingController(text: widget.track.artwork);
  bool pickingArtwork = false;
  String? artworkError;

  Future<void> _pickArtwork() async {
    final picker = widget.pickArtwork;
    if (picker == null || pickingArtwork) return;
    setState(() {
      pickingArtwork = true;
      artworkError = null;
    });
    try {
      final selected = await picker();
      if (selected != null && mounted) artwork.text = selected;
    } catch (failure) {
      if (mounted) setState(() => artworkError = failure.toString());
    } finally {
      if (mounted) setState(() => pickingArtwork = false);
    }
  }

  @override
  void dispose() {
    title.dispose();
    artist.dispose();
    album.dispose();
    artwork.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('Edit track'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            TextField(
              controller: artist,
              decoration: const InputDecoration(labelText: 'Artist'),
            ),
            TextField(
              controller: album,
              decoration: const InputDecoration(labelText: 'Album'),
            ),
            TextField(
              controller: artwork,
              decoration: InputDecoration(
                labelText: 'Artwork URL or image',
                errorText: artworkError,
              ),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: artwork,
              builder: (context, value, _) => Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: ArtworkImage(
                      source: value.text,
                      width: 64,
                      height: 64,
                      fallback: ColoredBox(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        child: const SizedBox.square(
                          dimension: 64,
                          child: Icon(Icons.image_outlined),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: widget.pickArtwork == null || pickingArtwork
                          ? null
                          : _pickArtwork,
                      icon: pickingArtwork
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add_photo_alternate_outlined),
                      label: const Text('Choose image'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(
          context,
          widget.track.copyWith(
            title: title.text,
            artist: artist.text,
            album: album.text,
            artwork: artwork.text,
          ),
        ),
        child: const Text('Save'),
      ),
    ],
  );
}
