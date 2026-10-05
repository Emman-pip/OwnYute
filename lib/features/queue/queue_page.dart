import 'package:flutter/material.dart';

import '../../core/app_controller.dart';
import '../../core/models.dart';
import '../../core/track_row.dart';
import '../../core/ui_helpers.dart';
import '../downloads/download_service.dart';

class QueuePage extends StatefulWidget {
  const QueuePage({super.key, required this.app});
  final AppController app;
  @override
  State<QueuePage> createState() => _QueuePageState();
}

class _QueuePageState extends State<QueuePage> {
  final Map<String, bool> expanded = {};

  Future<void> _assign(BuildContext context, QueueItem item) async {
    final choice = await showDialog<PlaylistRef?>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Add to playlist folder'),
        children: [
          for (final folder in widget.app.playlistFolders)
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
    if (choice == null || !context.mounted) return;
    var folder = choice;
    if (choice.id == 'new') {
      final name = (await textDialog(
        context,
        'New playlist folder',
        'Folder name',
      ))?.trim();
      if (name == null || name.isEmpty) return;
      folder = PlaylistRef(
        id: 'local:${DateTime.now().microsecondsSinceEpoch}',
        title: name,
      );
    }
    try {
      await widget.app.assignQueuedToPlaylist(item.track.id, folder);
      if (!context.mounted) return;
      showFeedback(context, '${item.track.title} added to ${folder.title}.');
    } catch (failure) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(failure.toString())));
      }
    }
  }

  Future<void> _editBatch(BuildContext context, String? batchId) async {
    final artist = await textDialog(
      context,
      'Batch edit',
      'Artist (blank keeps existing)',
    );
    if (artist == null || !context.mounted) return;
    final album = await textDialog(
      context,
      'Batch edit',
      'Album (blank keeps existing)',
    );
    if (album == null || !context.mounted) return;
    final artwork = await textDialog(
      context,
      'Batch edit',
      'Artwork URL (blank keeps existing)',
    );
    if (artwork == null) return;
    await widget.app.batchEdit(
      batchId: batchId,
      artist: artist,
      album: album,
      artwork: artwork,
    );
  }

  Future<void> _download(BuildContext context) async {
    final app = widget.app;
    final folder = app.destination ?? await app.chooseDestination();
    if (folder == null || !context.mounted) return;
    final subfolder = await textDialog(
      context,
      'Download folder',
      'Optional physical folder name',
    );
    if (subfolder == null || !context.mounted) return;
    final safe = subfolder.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    String target;
    try {
      target = await app.prepareBatchFolder(folder, safe);
    } catch (failure) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create folder: $failure')),
        );
      }
      return;
    }
    await app.downloadQueue(target, (path) async {
      if (!context.mounted) return DuplicateChoice.skip;
      return await showDialog<DuplicateChoice>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('File already exists'),
              content: Text(path),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, DuplicateChoice.skip),
                  child: const Text('Skip'),
                ),
                TextButton(
                  onPressed: () =>
                      Navigator.pop(context, DuplicateChoice.keepBoth),
                  child: const Text('Keep both'),
                ),
                FilledButton(
                  onPressed: () =>
                      Navigator.pop(context, DuplicateChoice.replace),
                  child: const Text('Replace'),
                ),
              ],
            ),
          ) ??
          DuplicateChoice.skip;
    });
  }

  List<TrackAction> _actions(
    BuildContext context,
    QueueItem item,
    String? batchId,
  ) => [
    TrackAction(
      tooltip: 'Edit metadata',
      icon: Icons.edit_outlined,
      onPressed: () async {
        final edited = await editTrackDialog(
          context,
          item.track,
          pickArtwork: widget.app.pickArtwork,
        );
        if (edited != null) await widget.app.editQueue(edited);
      },
    ),
    TrackAction(
      tooltip: 'Add to playlist folder',
      icon: Icons.playlist_add,
      onPressed: () => _assign(context, item),
    ),
    TrackAction(
      tooltip: 'Add to playback queue',
      icon: Icons.queue_music,
      onPressed: () {
        widget.app.player.addToQueue(item.track);
        showFeedback(context, '${item.track.title} added to playback queue.');
      },
    ),
    TrackAction(
      tooltip: 'Remove from group',
      icon: Icons.remove_circle_outline,
      onPressed: () =>
          widget.app.removeFromGroup(item.track.id, batchId: batchId),
    ),
  ];

  Widget _row(BuildContext context, QueueItem item, String? batchId) => Column(
    children: [
      TrackTile(
        title: item.track.title,
        subtitle: item.track.artist,
        artwork: item.track.artwork,
        onTap: () async {
          final edited = await editTrackDialog(
            context,
            item.track,
            pickArtwork: widget.app.pickArtwork,
          );
          if (edited != null) await widget.app.editQueue(edited);
        },
        actions: _actions(context, item, batchId),
      ),
      if (item.targetPlaylists.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(left: 72, right: 16, bottom: 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Playlists: ${item.targetPlaylists.map((folder) => folder.title).join(', ')}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
      if (item.status == 'downloading')
        LinearProgressIndicator(value: item.progress),
      if (item.status == 'failed')
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${item.error}\nRetry on next download',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ),
      if (item.status == 'done')
        const Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: EdgeInsets.only(right: 16),
            child: Text('Saved'),
          ),
        ),
    ],
  );

  Widget _group(
    BuildContext context,
    String id,
    String title,
    List<QueueItem> items, {
    bool editable = false,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();
    final open = expanded[id] ?? true;
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(open ? Icons.folder_open : Icons.folder_outlined),
            title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              '${items.length} ${items.length == 1 ? 'track' : 'tracks'}',
            ),
            onTap: () => setState(() => expanded[id] = !open),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (editable)
                  IconButton(
                    tooltip: 'Edit batch',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _editBatch(context, id),
                  ),
                Icon(open ? Icons.expand_less : Icons.expand_more),
              ],
            ),
          ),
          if (open)
            ...items.map((item) => _row(context, item, editable ? id : null)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final batches = <String, QueueBatchRef>{};
    for (final item in app.queue) {
      for (final batch in item.batches) {
        batches[batch.id] = batch;
      }
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Download queue',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          app.destinationLabel ?? 'Choose a folder before downloading.',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        // Wraps instead of overflowing: these three do not fit one line on a
        // 320dp phone.
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: app.chooseDestination,
              icon: const Icon(Icons.folder_open),
              label: const Text('Folder'),
            ),
            FilledButton.icon(
              onPressed: app.queue.isEmpty || app.downloading
                  ? null
                  : () => _download(context),
              icon: const Icon(Icons.download),
              label: const Text('Download'),
            ),
            PopupMenuButton<String>(
              tooltip: 'Queue actions',
              onSelected: (action) {
                if (action == 'edit') _editBatch(context, null);
                if (action == 'clear') app.clearFinished();
                if (action == 'cancel') app.cancelDownloads();
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'edit',
                  enabled: app.queue.isNotEmpty && !app.downloading,
                  child: const Text('Edit all queued'),
                ),
                PopupMenuItem(
                  value: 'clear',
                  enabled:
                      app.queue.any((item) => item.status == 'done') &&
                      !app.downloading,
                  child: const Text('Clear finished items'),
                ),
                if (app.downloading)
                  const PopupMenuItem(
                    value: 'cancel',
                    child: Text('Cancel downloads'),
                  ),
              ],
              icon: const Icon(Icons.more_vert),
            ),
          ],
        ),
        if (app.queue.isEmpty)
          const ListTile(title: Text('No tracks selected yet.')),
        for (final batch in batches.values)
          _group(
            context,
            batch.id,
            batch.title,
            app.queue
                .where(
                  (item) => item.batches.any((member) => member.id == batch.id),
                )
                .toList(),
            editable: true,
          ),
        _group(
          context,
          'singles',
          'Singles',
          app.queue.where((item) => item.inSingles).toList(),
        ),
      ],
    );
  }
}
