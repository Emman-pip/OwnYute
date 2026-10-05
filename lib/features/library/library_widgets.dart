import 'package:flutter/material.dart';

import '../../core/app_controller.dart';
import '../../core/models.dart';
import '../../core/track_row.dart';
import '../../core/ui_helpers.dart';
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
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: trailing ?? const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}

/// The commands every saved-song row offers, in one order, so the swipe strip
/// and the desktop `⋮` menu stay identical across the library, folder pages and
/// library search matches.
List<TrackAction> libraryTrackActions(
  BuildContext context,
  AppController app,
  LibraryTrack track,
) => [
  TrackAction(
    tooltip: 'Add to playback queue',
    icon: Icons.queue_music,
    onPressed: () {
      app.player.addLibraryToQueue(track);
      showFeedback(context, '${track.title} added to playback queue.');
    },
  ),
  TrackAction(
    tooltip: 'Add to playlist folder',
    icon: Icons.playlist_add,
    onPressed: () => assignTrackToPlaylist(context, app, track),
  ),
  TrackAction(
    tooltip: 'Refresh artwork',
    icon: Icons.image_search_outlined,
    onPressed: () => app.lookupArtwork(track),
  ),
  TrackAction(
    tooltip: 'Edit metadata',
    icon: Icons.edit_outlined,
    onPressed: () => editLibraryTrack(context, app, track),
  ),
  TrackAction(
    tooltip: 'Move file',
    icon: Icons.drive_file_move_outline,
    onPressed: () => moveLibraryTrack(context, app, track),
  ),
  TrackAction(
    tooltip: 'Delete song',
    icon: Icons.delete_outline,
    onPressed: () => deleteLibraryTrack(context, app, track),
  ),
];

/// A saved-song row: plays on tap, scrolls its title, and carries the library
/// commands in the swipe strip or the overflow menu.
class LibraryTrackRow extends StatelessWidget {
  const LibraryTrackRow({
    super.key,
    required this.app,
    required this.track,
    required this.group,
    this.selectionMode = false,
    this.selected = false,
    this.onSelect,
    this.onLongPress,
  });

  final AppController app;
  final LibraryTrack track;
  final List<LibraryTrack> group;
  final bool selectionMode;
  final bool selected;
  final VoidCallback? onSelect;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) => TrackTile(
    title: track.title,
    subtitle: track.artist,
    artwork: track.artwork,
    artworkIcon: Icons.audio_file,
    selectionMode: selectionMode,
    selected: selected,
    onTap: selectionMode
        ? onSelect
        : () => app.player.playLocal(group, group.indexOf(track)),
    onLongPress: selectionMode ? onSelect : onLongPress,
    actions: selectionMode
        ? const []
        : libraryTrackActions(context, app, track),
  );
}
