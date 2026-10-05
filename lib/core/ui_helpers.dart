import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'artwork_image.dart';
import 'models.dart';

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key});
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Text(title, style: Theme.of(context).textTheme.titleLarge),
  );
}

class TrackTile extends StatelessWidget {
  const TrackTile({
    super.key,
    required this.track,
    required this.onTap,
    this.trailing,
    this.fullTitle = false,
  });
  final Track track;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool fullTitle;
  @override
  Widget build(BuildContext context) => ListTile(
    leading: ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: ArtworkImage(
        source: track.artwork,
        width: 48,
        height: 48,
        fallback: const SizedBox.square(
          dimension: 48,
          child: Icon(Icons.music_note),
        ),
      ),
    ),
    title: Text(
      track.title,
      maxLines: fullTitle ? null : 1,
      overflow: fullTitle ? TextOverflow.visible : TextOverflow.ellipsis,
    ),
    subtitle: Text(track.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
    trailing: trailing,
    onTap: onTap,
  );
}

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
        FilledButton(
          onPressed: () async {
            await app.add(track);
            if (context.mounted) Navigator.pop(context);
            onQueue();
          },
          child: const Text('Add to queue'),
        ),
      ],
    ),
  );
}

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
                Text(
                  'Choose tracks (${selected.length}/${tracks.length})',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
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
                Expanded(
                  child: ListView.builder(
                    itemCount: tracks.length,
                    itemBuilder: (context, index) {
                      final track = tracks[index];
                      return CheckboxListTile(
                        value: selected.contains(track.id),
                        title: Text(
                          track.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          track.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        secondary: IconButton(
                          tooltip: 'Preview',
                          icon: const Icon(Icons.play_arrow),
                          onPressed: () => app.player.playTracks(tracks, index),
                        ),
                        onChanged: (value) => setDialogState(() {
                          if (value == true) {
                            selected.add(track.id);
                          } else {
                            selected.remove(track.id);
                          }
                        }),
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
