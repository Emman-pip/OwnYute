import 'package:flutter/material.dart';

import '../../core/app_controller.dart';
import '../../core/models.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key, required this.app});
  final AppController app;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: app.player,
    builder: (context, _) {
      final player = app.player;
      final track = player.current;
      if (track == null) return const SizedBox.shrink();
      final scheme = Theme.of(context).colorScheme;
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
              builder: (_) => PlayerSheet(app: app),
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
                        builder: (_) => PlayerSheet(app: app),
                      ),
                    ),
                  ],
                ),
                if (progress != null)
                  LinearProgressIndicator(value: progress, minHeight: 2),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class PlayerSheet extends StatefulWidget {
  const PlayerSheet({super.key, required this.app});
  final AppController app;

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
            .clamp(0, max.toInt())
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
            if (max > 0) ...[
              Slider(
                value: (draggedPosition ?? position).clamp(0.0, max),
                max: max,
                onChanged: (value) => setState(() => draggedPosition = value),
                onChangeEnd: (value) {
                  setState(() => draggedPosition = null);
                  player.seek(Duration(milliseconds: value.toInt()));
                },
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
                  Text(_time(player.duration)),
                ],
              ),
            ],
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
            Text('Up next', style: Theme.of(context).textTheme.titleLarge),
            ...player.queue.asMap().entries.map(
              (entry) => ListTile(
                dense: true,
                selected: entry.value == track,
                title: Text(
                  entry.value.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  entry.value.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () =>
                    player.playTracks(player.queue.toList(), entry.key),
              ),
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
      child: track.artwork.isEmpty
          ? ColoredBox(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(Icons.music_note, size: size * 0.45),
            )
          : Image.network(
              track.artwork,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => ColoredBox(
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
