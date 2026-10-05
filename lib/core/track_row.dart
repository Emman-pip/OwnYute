import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'artwork_image.dart';
import 'marquee_text.dart';

/// One entry of a [TrackTile]'s action strip.
@immutable
class TrackAction {
  const TrackAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;

  /// `null` renders the action as disabled, used for the "already saved"
  /// download button on search results.
  final VoidCallback? onPressed;
}

/// The one row shape used by every track list in the app.
///
/// Layout is `[artwork or checkbox][title / subtitle][pinned][overflow]`:
/// - Titles and artists scroll with [MarqueeText] instead of wrapping.
/// - [pinned] is at most one always-visible button (download, "add to
///   playlist"). Search results only.
/// - [actions] are the row's commands. Touch builds reveal them by swiping the
///   row left; pointer builds show a `⋮` menu, so nothing depends on a gesture.
/// - [onLongPress] belongs to the parent, which is how every list enters its own
///   selection mode.
class TrackTile extends StatefulWidget {
  const TrackTile({
    super.key,
    required this.title,
    this.subtitle = '',
    this.artwork = '',
    this.onTap,
    this.onLongPress,
    this.pinned,
    this.actions = const [],
    this.selectionMode = false,
    this.selected = false,
    this.dense = false,
    this.artworkIcon = Icons.music_note,
  });

  final String title;
  final String subtitle;
  final String artwork;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final TrackAction? pinned;
  final List<TrackAction> actions;
  final bool selectionMode;
  final bool selected;
  final bool dense;
  final IconData artworkIcon;

  /// Width of one revealed action.
  static const double actionWidth = 68;

  /// Fraction of the strip a drag must pass before it stays open.
  static const double snapFraction = 0.4;

  /// Desktop and web point instead of touch, so they get the `⋮` menu.
  static bool usesPointerInput(TargetPlatform platform) =>
      platform == TargetPlatform.linux ||
      platform == TargetPlatform.macOS ||
      platform == TargetPlatform.windows ||
      platform == TargetPlatform.fuchsia;

  double get stripWidth => actions.length * actionWidth;

  @override
  State<TrackTile> createState() => _TrackTileState();
}

class _TrackTileState extends State<TrackTile>
    with SingleTickerProviderStateMixin {
  /// Settles the revealed strip open or shut. [_drag] is the single source of
  /// truth: a drag writes it directly, and this controller eases it to
  /// [_snapTo] when the finger lifts.
  late final AnimationController _snap =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 220),
      )..addListener(() {
        _drag = lerpDouble(
          _snapFrom,
          _snapTo,
          Curves.easeOutCubic.transform(_snap.value),
        )!;
      });

  /// Where the finger actually is, without the rubber band applied. [_drag] is
  /// what paints, so resistance past the open position never compounds.
  double _raw = 0;
  double _drag = 0;
  double _snapFrom = 0;
  double _snapTo = 0;
  bool _pressed = false;
  ScrollPosition? _scroll;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A scroll notification is dispatched from the Scrollable's own context and
    // bubbles up, so a listener inside a row never sees one. The enclosing
    // scroll position is the only handle a row has on the list it lives in.
    final next = Scrollable.maybeOf(context)?.position;
    if (identical(next, _scroll)) return;
    _scroll?.isScrollingNotifier.removeListener(_onScroll);
    _scroll = next;
    _scroll?.isScrollingNotifier.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(TrackTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Entering selection mode, or losing the actions, hides the strip. The
    // offset has to go with it or the row springs open again on the way out.
    if (!_stripVisible && (_raw != 0 || oldWidget.actions.isNotEmpty)) {
      _settle(0);
    }
  }

  bool get _stripVisible => !widget.selectionMode && widget.actions.isNotEmpty;

  /// An open row must not ride along while the list moves under it, so any
  /// scroll shuts it. Without this the strip is stranded on a row that has
  /// scrolled somewhere else, with its actions still tappable.
  void _onScroll() {
    // The notifier fires on both edges of a scroll; only the row sitting open
    // cares, and by the time scrolling stops it has already been shut.
    if (_drag == 0) return;
    _settle(0);
  }

  @override
  void dispose() {
    _scroll?.isScrollingNotifier.removeListener(_onScroll);
    _snap.dispose();
    super.dispose();
  }

  void _settle(double target) {
    _raw = target;
    _snapFrom = _drag;
    _snapTo = target;
    _snap.forward(from: 0);
  }

  /// Past the fully open position the row still moves, but with a third of the
  /// travel, so the end of the strip feels elastic rather than like a wall.
  double _rubberBand(double raw) {
    final limit = widget.stripWidth;
    if (raw >= 0) return 0;
    if (raw >= -limit) return raw;
    return -limit + (raw + limit) / 3;
  }

  void _dragUpdate(DragUpdateDetails details) {
    _snap.stop();
    setState(() {
      _raw = (_raw + details.delta.dx).clamp(-widget.stripWidth * 1.4, 0.0);
      _drag = _rubberBand(_raw);
    });
  }

  void _dragEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond.dx;
    final past = _raw < -widget.stripWidth * TrackTile.snapFraction;
    final closing = velocity > 600 || (!past && velocity > -600);
    _settle(closing ? 0 : -widget.stripWidth);
  }

  /// A drag that loses the arena (the list claims the pointer for a scroll)
  /// reports a cancel rather than an end, so the row resets itself here. The
  /// scroll listener covers the settled case; this covers the in-flight one.
  void _dragCancel() => _settle(0);

  Widget _leading() {
    if (widget.selectionMode) {
      return Checkbox(
        value: widget.selected,
        onChanged: (_) => widget.onTap?.call(),
      );
    }
    final size = widget.dense ? 40.0 : 48.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: ArtworkImage(
        source: widget.artwork,
        width: size,
        height: size,
        fallback: SizedBox.square(
          dimension: size,
          child: Icon(widget.artworkIcon),
        ),
      ),
    );
  }

  List<Widget> _trailing(bool touch) {
    final buttons = <Widget>[];
    final pinned = widget.pinned;
    if (pinned != null) {
      buttons.add(
        IconButton(
          tooltip: pinned.tooltip,
          icon: Icon(pinned.icon),
          onPressed: pinned.onPressed,
        ),
      );
    }
    if (widget.actions.isNotEmpty && !touch) {
      buttons.add(
        PopupMenuButton<int>(
          tooltip: 'More actions',
          icon: const Icon(Icons.more_vert),
          onSelected: (index) => widget.actions[index].onPressed?.call(),
          itemBuilder: (context) => [
            for (var index = 0; index < widget.actions.length; index++)
              PopupMenuItem(
                value: index,
                child: Text(widget.actions[index].tooltip),
              ),
          ],
        ),
      );
    }
    return buttons;
  }

  Widget _row(BuildContext context) {
    final touch = !TrackTile.usesPointerInput(Theme.of(context).platform);
    final trailing = _trailing(touch);
    // Pointer up can land after the row is gone: a long press rebuilds the
    // list into selection mode, which disposes the row that was held.
    void release() {
      if (!mounted || !_pressed) return;
      setState(() => _pressed = false);
    }

    return Listener(
      onPointerDown: (_) {
        if (_pressed) return;
        setState(() => _pressed = true);
      },
      onPointerUp: (_) => release(),
      onPointerCancel: (_) => release(),
      child: GestureDetector(
        // Horizontal only, so a vertical drag still scrolls the list.
        onHorizontalDragUpdate: widget.actions.isEmpty ? null : _dragUpdate,
        onHorizontalDragEnd: widget.actions.isEmpty ? null : _dragEnd,
        onHorizontalDragCancel: widget.actions.isEmpty ? null : _dragCancel,
        child: ListTile(
          dense: widget.dense,
          selected: widget.selected,
          selectedTileColor: Theme.of(context).colorScheme.primaryContainer
              .withValues(alpha: 0.4),
          leading: _leading(),
          title: MarqueeText(widget.title, isPressed: _pressed),
          // No explicit style: the ListTile subtitle slot already carries the
          // theme's subtitle typography.
          subtitle: widget.subtitle.isEmpty
              ? null
              : MarqueeText(widget.subtitle, isPressed: _pressed),
          trailing: trailing.isEmpty
              ? null
              : Row(mainAxisSize: MainAxisSize.min, children: trailing),
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
        ),
      ),
    );
  }

  Widget _strip(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final action in widget.actions)
        SizedBox(
          width: TrackTile.actionWidth,
          child: InkWell(
            onTap: action.onPressed,
            child: Tooltip(
              message: action.tooltip,
              child: Icon(
                action.icon,
                color: action.onPressed == null
                    ? Theme.of(context).disabledColor
                    : null,
              ),
            ),
          ),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _snap,
      builder: (context, child) {
        final revealed = _stripVisible ? -_drag : 0.0;
        return Stack(
          children: [
            // The strip sits underneath, aligned to the right edge and cut
            // back on its left, so only the swiped sliver of it is ever shown.
            if (revealed > 0)
              Positioned.fill(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: ClipRect(
                    clipper: _EdgeCropClipper(
                      (widget.stripWidth - revealed).clamp(
                        0,
                        widget.stripWidth,
                      ),
                      _CropEdge.left,
                    ),
                    child: ColoredBox(
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                      child: _strip(context),
                    ),
                  ),
                ),
              ),
            // The row is above the strip and covers the same ground, so the
            // actions are only ever visible in the swiped sliver. It crops its
            // trailing edge by the same amount instead of laying out narrower,
            // which keeps the row's text from re-measuring mid-drag.
            if (revealed > 0)
              Transform.translate(
                offset: Offset(-revealed, 0),
                child: ClipRect(
                  clipper: _EdgeCropClipper(revealed, _CropEdge.right),
                  child: child,
                ),
              )
            else
              child!,
          ],
        );
      },
      child: _row(context),
    );
  }
}

enum _CropEdge { left, right }

/// Crops [amount] pixels off one edge, so a sliver of a wide widget can be
/// shown without changing the layout of the widget itself.
class _EdgeCropClipper extends CustomClipper<Rect> {
  const _EdgeCropClipper(this.amount, this.edge);
  final double amount;
  final _CropEdge edge;

  @override
  Rect getClip(Size size) => switch (edge) {
    _CropEdge.left => Rect.fromLTRB(
      amount.clamp(0, size.width),
      0,
      size.width,
      size.height,
    ),
    _CropEdge.right => Rect.fromLTRB(
      0,
      0,
      (size.width - amount).clamp(0, size.width),
      size.height,
    ),
  };

  @override
  bool shouldReclip(_EdgeCropClipper oldClipper) =>
      oldClipper.amount != amount || oldClipper.edge != edge;
}

/// Selection state for one row list.
///
/// Selection is per list and is dropped whenever the list itself changes, so a
/// stale selection can never act on a track that arrived after it was made.
class TrackSelection {
  final Set<String> _selected = <String>{};
  bool active = false;
  String? _signature;

  int get count => _selected.length;
  bool get isEmpty => _selected.isEmpty;
  List<String> get ids => _selected.toList();
  bool contains(String id) => _selected.contains(id);

  void sync(Iterable<String> ids) {
    final signature = ids.join('');
    if (signature == _signature) return;
    _signature = signature;
    clear();
  }

  void start() {
    active = true;
  }

  void toggle(String id) {
    active = true;
    if (!_selected.remove(id)) _selected.add(id);
  }

  void clear() {
    _selected.clear();
    active = false;
  }
}

/// The bar that replaces normal row actions while a list is selecting.
class SelectionBar extends StatelessWidget {
  const SelectionBar({
    super.key,
    required this.count,
    this.onAddToPlaylist,
    this.onDelete,
    this.deleting = false,
    this.progress,
  });

  final int count;
  final VoidCallback? onAddToPlaylist;
  final VoidCallback? onDelete;
  final bool deleting;
  final double? progress;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(
      color: Theme.of(context).colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Text(
              '$count selected',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(width: 12),
            if (deleting) ...[
              SizedBox(
                width: 80,
                child: LinearProgressIndicator(value: progress),
              ),
              const SizedBox(width: 12),
            ],
            const Spacer(),
            IconButton(
              tooltip: 'Add selected songs to playlist',
              icon: const Icon(Icons.playlist_add),
              onPressed: count == 0 ? null : onAddToPlaylist,
            ),
            IconButton(
              tooltip: 'Delete selected songs',
              icon: const Icon(Icons.delete_outline),
              onPressed: count == 0 || deleting ? null : onDelete,
            ),
          ],
        ),
      ),
    ),
  );
}
