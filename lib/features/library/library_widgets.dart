import 'package:flutter/material.dart';

import '../../core/app_controller.dart';
import '../../core/artwork_image.dart';
import '../../core/models.dart';
import 'library_actions.dart';

/// A tappable card that opens a folder or playlist in its own page.
class FolderTile extends StatelessWidget {
  const FolderTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: trailing ?? const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}

/// A library track row that plays on tap and exposes the usual file actions.
class LibraryTrackTile extends StatelessWidget {
  const LibraryTrackTile({
    super.key,
    required this.app,
    required this.track,
    required this.group,
    this.allowSelection = false,
    this.selected = false,
    this.selecting = false,
    this.onToggleSelection,
  });
  final AppController app;
  final LibraryTrack track;
  final List<LibraryTrack> group;
  final bool allowSelection;
  final bool selected;
  final bool selecting;
  final VoidCallback? onToggleSelection;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: allowSelection && selecting
          ? Checkbox(
              value: selected,
              onChanged: (_) => onToggleSelection?.call(),
            )
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
          ? onToggleSelection
          : () => app.player.playLocal(group, group.indexOf(track)),
      onLongPress: allowSelection ? onToggleSelection : null,
      trailing: allowSelection && selecting
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Add to playback queue',
                  icon: const Icon(Icons.queue_music),
                  onPressed: () => app.player.addLibraryToQueue(track),
                ),
                PopupMenuButton<String>(
                  onSelected: (action) =>
                      libraryTrackAction(context, app, track, action),
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
              ],
            ),
    );
  }
}
