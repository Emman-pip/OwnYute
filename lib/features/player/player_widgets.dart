import 'package:flutter/material.dart';

import '../../core/app_controller.dart';
import '../../core/artwork_image.dart';
import '../../core/marquee_text.dart';
import '../../core/models.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key, required this.app, this.onDownloads});
  final AppController app;
  final VoidCallback? onDownloads;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: app.player,
    builder: (context, _) {
      final player = app.player;
      final track = player.current;
      if (track == null) return const SizedBox.shrink();
      final scheme = Theme.of(context).colorScheme;
      final busy = player.preparing || player.buffering;
      final progress = player.duration.inMilliseconds > 0
          ? (player.position.inMilliseconds / player.duration.inMilliseconds)
                .clamp(0.0, 1.0)
          : null;
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        child: Material(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              builder: (_) => PlayerSheet(app: app, onDownloads: onDownloads),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: _Artwork(track: track, size: 44),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          Text(
                            player.error ??
                                (player.preparing
                                    ? 'Preparing audio…'
                                    : player.buffering
                                    ? 'Buffering audio…'
                                    : track.artist),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    if (app.isStreamedPreview(track))
                      IconButton(
                        tooltip: app.isInDownloadQueue(track)
                            ? 'View in Downloads'
                            : 'Save offline',
                        icon: Icon(
                          app.isInDownloadQueue(track)
                              ? Icons.download_done
                              : Icons.download_for_offline_outlined,
                        ),
                        onPressed: () async {
                          await app.saveOffline(track);
                          onDownloads?.call();
                        },
                      ),
                    IconButton(
                      tooltip: player.playing || player.preparing
                          ? 'Pause'
                          : 'Play',
                      icon: Icon(
                        player.playing || player.preparing
                            ? Icons.pause
                            : Icons.play_arrow,
                      ),
                      onPressed: player.toggle,
                    ),
                    IconButton(
                      tooltip: 'Open player',
                      icon: const Icon(Icons.keyboard_arrow_up),
                      onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        useSafeArea: true,
                        builder: (_) =>
                            PlayerSheet(app: app, onDownloads: onDownloads),
                      ),
                    ),
                  ],
                ),
                LinearProgressIndicator(
                  value: busy ? null : (progress ?? 0),
                  minHeight: 3,
                  backgroundColor: scheme.onSurface.withValues(alpha: 0.18),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class PlayerSheet extends StatefulWidget {
  const PlayerSheet({super.key, required this.app, this.onDownloads});
  final AppController app;
  final VoidCallback? onDownloads;

  @override
  State<PlayerSheet> createState() => _PlayerSheetState();
}

class _PlayerSheetState extends State<PlayerSheet> {
  double? draggedPosition;

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: 0.82,
    minChildSize: 0.45,
    maxChildSize: 0.96,
    builder: (context, scrollController) => ListenableBuilder(
      listenable: widget.app.player,
      builder: (context, _) {
        final player = widget.app.player;
        final track = player.current;
        if (track == null) return const SizedBox.shrink();
        final max = player.duration.inMilliseconds.toDouble();
        final position = player.position.inMilliseconds
            .clamp(0, max > 0 ? max.toInt() : 1 << 31)
            .toDouble();
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'NOW PLAYING',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                letterSpacing: 1.6,
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: _AnimatedArtwork(
                track: track,
                playing: player.playing,
                enabled:
                    widget.app.playerAnimationEnabled &&
                    !MediaQuery.of(context).disableAnimations,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              track.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              track.artist,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (widget.app.isStreamedPreview(track)) ...[
              const SizedBox(height: 12),
              Center(
                child: FilledButton.tonalIcon(
                  onPressed: () async {
                    await widget.app.saveOffline(track);
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    widget.onDownloads?.call();
                  },
                  icon: Icon(
                    widget.app.isInDownloadQueue(track)
                        ? Icons.download_done
                        : Icons.download_for_offline_outlined,
                  ),
                  label: Text(
                    widget.app.isInDownloadQueue(track)
                        ? 'View in Downloads'
                        : 'Save offline',
                  ),
                ),
              ),
            ],
            if (player.error != null) Text(player.error!),
            if (player.preparing || player.buffering) ...[
              const LinearProgressIndicator(),
              Text(
                player.buffering && !player.preparing
                    ? 'Buffering audio…'
                    : 'Preparing audio…',
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 16),
            Slider(
              value: max > 0
                  ? (draggedPosition ?? position).clamp(0.0, max)
                  : 0,
              max: max > 0 ? max : 1,
              onChanged: max > 0
                  ? (value) => setState(() => draggedPosition = value)
                  : null,
              onChangeEnd: max > 0
                  ? (value) {
                      setState(() => draggedPosition = null);
                      player.seek(Duration(milliseconds: value.toInt()));
                    }
                  : null,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _time(
                    Duration(
                      milliseconds: (draggedPosition ?? position).toInt(),
                    ),
                  ),
                ),
                Text(max > 0 ? _time(player.duration) : '--:--'),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Shuffle',
                  icon: Icon(
                    Icons.shuffle,
                    color: player.shuffle
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  onPressed: () => player.setShuffle(!player.shuffle),
                ),
                IconButton(
                  tooltip: 'Previous',
                  icon: const Icon(Icons.skip_previous),
                  onPressed: player.previous,
                ),
                IconButton(
                  tooltip: player.playing || player.preparing
                      ? 'Pause'
                      : 'Play',
                  icon: Icon(
                    player.playing || player.preparing
                        ? Icons.pause_circle
                        : Icons.play_circle,
                    size: 48,
                  ),
                  onPressed: player.toggle,
                ),
                IconButton(
                  tooltip: 'Next',
                  icon: const Icon(Icons.skip_next),
                  onPressed: player.next,
                ),
                IconButton(
                  tooltip: 'Repeat',
                  icon: Icon(
                    Icons.repeat,
                    color: player.repeat
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  onPressed: () => player.setRepeat(!player.repeat),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'Playback queue',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                // The queue only holds what has not played yet, so say which it
                // is rather than implying the list is the whole set.
                Text(
                  player.history.isEmpty
                      ? '${player.queue.length} tracks'
                      : '${player.queue.length} left'
                            '${player.history.length == 1 ? ' · 1 played' : ' · ${player.history.length} played'}',
                ),
              ],
            ),
            const SizedBox(height: 4),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: player.queue.length,
              onReorderItem: player.reorder,
              itemBuilder: (context, index) {
                final queued = player.queue[index];
                final playing = identical(queued, track);
                return ListTile(
                  // Indexed as well as identified: `addToQueue` does not
                  // de-duplicate, so the same Track instance can legitimately
                  // appear twice and `ObjectKey` alone would collide.
                  key: ValueKey('$index:${queued.url}'),
                  dense: true,
                  selected: playing,
                  selectedTileColor: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  // The playing track is pinned to the top and `reorder`
                  // refuses to move it, so it offers no drag handle.
                  leading: playing
                      ? const Icon(Icons.graphic_eq, size: 20)
                      : ReorderableDragStartListener(
                          index: index,
                          child: const Icon(Icons.drag_handle),
                        ),
                  title: MarqueeText(queued.title),
                  subtitle: playing
                      ? const Text('Now playing')
                      : MarqueeText(queued.artist),
                  trailing: IconButton(
                    tooltip: 'Remove from playback queue',
                    icon: const Icon(Icons.close),
                    onPressed: () => player.removeAt(index),
                  ),
                  onTap: () => player.playAt(index),
                );
              },
            ),
          ],
        );
      },
    ),
  );
}

String _time(Duration value) {
  final minutes = value.inMinutes;
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

class _Artwork extends StatelessWidget {
  const _Artwork({required this.track, required this.size});
  final Track track;
  final double size;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: SizedBox.square(
      dimension: size,
      child: ArtworkImage(
        source: track.artwork,
        fallback: ColoredBox(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(Icons.music_note, size: size * 0.45),
        ),
      ),
    ),
  );
}

class _AnimatedArtwork extends StatefulWidget {
  const _AnimatedArtwork({
    required this.track,
    required this.playing,
    required this.enabled,
  });
  final Track track;
  final bool playing;
  final bool enabled;
  @override
  State<_AnimatedArtwork> createState() => _AnimatedArtworkState();
}

class _AnimatedArtworkState extends State<_AnimatedArtwork>
    with SingleTickerProviderStateMixin {
  late final AnimationController motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_AnimatedArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.enabled && widget.playing) {
      if (!motion.isAnimating) motion.repeat(reverse: true);
    } else {
      motion.stop();
    }
  }

  @override
  void dispose() {
    motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 230,
    child: AnimatedBuilder(
      animation: motion,
      builder: (context, child) {
        final amount = widget.enabled ? motion.value : 0.0;
        return Stack(
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: 0.92 + amount * 0.16,
              child: Container(
                width: 188,
                height: 188,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.primaryContainer
                      .withValues(alpha: 0.6),
                ),
              ),
            ),
            Transform.rotate(
              angle: (amount - 0.5) * 0.08,
              child: Transform.scale(scale: 0.98 + amount * 0.04, child: child),
            ),
          ],
        );
      },
      child: _Artwork(track: widget.track, size: 164),
    ),
  );
}
