import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// A single-line label that scrolls sideways when it does not fit.
///
/// Long song titles are routine here, so rows keep one line and let the text
/// travel instead of wrapping or cutting a title in half. The scroll loops:
/// travel to the end, dwell, travel back, dwell. It is deliberately restrained
/// everywhere else — it holds while the row is pressed, degrades to a static
/// ellipsis when `MediaQuery.disableAnimations` is set, and needs no manual
/// wiring for hidden pages: the ticker is muted automatically while
/// `TickerMode` is off, which is what keeps the `IndexedStack` in `main.dart`
/// from animating all three tabs at once.
class MarqueeText extends StatefulWidget {
  const MarqueeText(
    this.text, {
    super.key,
    this.style,
    this.isPressed = false,
    this.speed = 26,
    this.maxTravel = const Duration(seconds: 6),
    this.dwell = const Duration(milliseconds: 1200),
  });

  final String text;
  final TextStyle? style;

  /// Holds the scroll while the surrounding row is held down. The text picks
  /// up exactly where it stopped, starting on the same frame the press begins,
  /// which is what makes a held row readable instead of a blur.
  final bool isPressed;

  /// Logical pixels per second, before [maxTravel] clamps very long titles.
  final double speed;

  /// Bounds each direction of the scroll so a pathologically long title still
  /// reads at a usable pace instead of crawling for half a minute.
  final Duration maxTravel;
  final Duration dwell;

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

/// Draws a scrolling [MarqueeText]. Exposed so tests can read the offset.
class MarqueeTextPainter extends CustomPainter {
  const MarqueeTextPainter({
    required this.text,
    required this.style,
    required this.offset,
  });

  final String text;
  final TextStyle style;
  final double offset;

  @override
  void paint(Canvas canvas, Size size) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    painter.paint(canvas, Offset(-offset, 0));
    painter.dispose();
  }

  @override
  bool shouldRepaint(covariant MarqueeTextPainter oldDelegate) =>
      oldDelegate.text != text ||
      oldDelegate.style != style ||
      oldDelegate.offset != offset;
}

class _MarqueeTextState extends State<MarqueeText>
    with SingleTickerProviderStateMixin {
  final TextPainter _measure = TextPainter(
    textDirection: TextDirection.ltr,
    maxLines: 1,
  );
  late final Ticker _ticker = createTicker(_onTick);
  final ValueNotifier<double> _offset = ValueNotifier(0);

  /// Loop position the ticker resumes from after a pause, and the position of
  /// the most recent tick.
  Duration _carried = Duration.zero;
  Duration _currentPhase = Duration.zero;

  /// Loop length and its halves, all in microseconds so the phase maths below
  /// never has to convert units.
  Duration _cycle = Duration.zero;
  int _travel = 0;
  double _distance = 0;
  bool _syncScheduled = false;

  @override
  void didUpdateWidget(covariant MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A press has to take effect on the frame it starts, not a frame later.
    if (oldWidget.isPressed != widget.isPressed) _syncTicker();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _offset.dispose();
    _measure.dispose();
    super.dispose();
  }

  /// Maps a loop position, in microseconds, to a scroll offset: out to the end,
  /// hold, back to the start, hold.
  double _offsetAt(int phase) {
    final dwell = widget.dwell.inMicroseconds;
    if (_travel <= 0) return 0;
    if (phase < _travel) return _distance * phase / _travel;
    if (phase < _travel + dwell) return _distance;
    if (phase < _travel * 2 + dwell) {
      return _distance * (1 - (phase - _travel - dwell) / _travel);
    }
    return 0;
  }

  void _onTick(Duration elapsed) {
    final cycle = _cycle.inMicroseconds;
    if (cycle <= 0) return;
    // `_carried` is the position the ticker resumed from, so a pause and
    // release continue instead of snapping back to the start.
    final phase = (_carried.inMicroseconds + elapsed.inMicroseconds) % cycle;
    _currentPhase = Duration(microseconds: phase);
    _offset.value = _offsetAt(phase);
  }

  void _scheduleSync() {
    if (_syncScheduled) return;
    _syncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncScheduled = false;
      if (mounted) _syncTicker();
    });
  }

  /// Starts or stops the ticker for the current state. Called directly when a
  /// press begins so the hold takes effect on the same frame rather than after
  /// the next layout, and from a post-frame callback when the geometry decides.
  void _syncTicker() {
    final wanted = _cycle > Duration.zero && !widget.isPressed;
    if (wanted == _ticker.isActive) return;
    if (wanted) {
      _ticker.start();
    } else {
      // Remember where the text was so the release resumes from there.
      _carried = _currentPhase;
      _ticker.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style ?? DefaultTextStyle.of(context).style;
    final animationsEnabled =
        !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    return LayoutBuilder(
      builder: (context, constraints) {
        final view = constraints.maxWidth;
        _measure.text = TextSpan(text: widget.text, style: style);
        _measure.layout();
        final width = _measure.width;
        final height = _measure.height;
        final overflows = view.isFinite && width > view + 0.5;
        if (!overflows || !animationsEnabled) {
          _cycle = Duration.zero;
          _offset.value = 0;
          _scheduleSync();
          return Text(
            widget.text,
            style: style,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
          );
        }
        final distance = width - view;
        if (distance != _distance) {
          // A different title or width restarts the loop from the beginning.
          _distance = distance;
          _carried = Duration.zero;
          _currentPhase = Duration.zero;
          _offset.value = 0;
        }
        _travel = (_distance / widget.speed * 1000000).round().clamp(
          0,
          widget.maxTravel.inMicroseconds,
        );
        _cycle = Duration(
          microseconds: _travel * 2 + widget.dwell.inMicroseconds * 2,
        );
        if (_travel == 0) {
          _cycle = Duration.zero;
          _offset.value = 0;
        }
        _scheduleSync();
        return SizedBox(
          height: height,
          child: ClipRect(
            // The painter holds a snapshot of the offset, so the viewport has
            // to rebuild on every tick for the text to actually move.
            child: ValueListenableBuilder<double>(
              valueListenable: _offset,
              builder: (context, offset, _) => CustomPaint(
                size: Size(view, height),
                painter: MarqueeTextPainter(
                  text: widget.text,
                  style: style,
                  offset: offset,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
