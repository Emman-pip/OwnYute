import 'dart:math' as math;

/// Sizes a batch of downloads from measured throughput, the way TCP congestion
/// control does: add a worker when the link demonstrably handled it, give one
/// back when it did not.
///
/// Deliberately free of `dart:io` and Flutter so the arithmetic is directly
/// testable. The caller owns the clock and feeds it readings.
class DownloadScheduler {
  DownloadScheduler({
    required this.maxConcurrency,
    this.pinned,
    DateTime Function()? clock,
    this.growthThreshold = 0.10,
    this.collapseRatio = 0.75,
    this.neutralWindowsBeforeShrink = 2,
  }) : _clock = clock ?? DateTime.now {
    _target = _effectiveLimit();
  }

  /// Hard ceiling. Android is lower because every yt-dlp there is a bundled
  /// Python interpreter, and phones have far less memory than a desktop.
  final int maxConcurrency;

  /// Width the user pinned in Settings. When set, readings are ignored.
  final int? pinned;

  /// Fractional gain in aggregate throughput that justifies another worker.
  final double growthThreshold;

  /// Below this share of its former speed, the link is treated as congested.
  final double collapseRatio;

  /// Consecutive unremarkable windows before giving a worker back. Without it a
  /// single slow tick makes the batch flap between widths.
  final int neutralWindowsBeforeShrink;

  final DateTime Function() _clock;
  late int _target;

  /// Latest per-track reading, kept so a worker can be compared against itself.
  final Map<String, double> _trackSpeed = {};

  double? _lastWindowThroughput;
  int _neutralWindows = 0;
  DateTime? _windowStart;

  /// True when the user pinned the width in Settings, which wins over readings.
  bool get isPinned => pinned != null;

  /// How many downloads the caller should keep in flight right now.
  int get target => _target;

  /// Set when a rate limit forced the batch back to a single worker, so the UI
  /// can explain why it slowed down.
  bool get rateLimited => _rateLimited;
  bool _rateLimited = false;

  int _effectiveLimit() {
    final pinnedWidth = pinned;
    if (pinnedWidth != null) return pinnedWidth.clamp(1, maxConcurrency);
    return math.min(maxConcurrency, 2);
  }

  /// Narrowest the automatic batch ever gets. A rate limit may force one
  /// worker; otherwise two, because flat throughput means the extra workers
  /// were not helping, not that one is better than two.
  int get _floor => _rateLimited
      ? 1
      : math.min(2, maxConcurrency);

  /// Signals the start of a measurement window. Windows are what growth and
  /// shrink are judged on, so that one slow tick cannot resize the batch.
  void beginWindow() {
    _windowStart ??= _clock();
  }

  /// Feeds one reading from a running download.
  void recordSample(String trackId, double bytesPerSecond) {
    if (bytesPerSecond <= 0 || !bytesPerSecond.isFinite) return;
    _trackSpeed[trackId] = bytesPerSecond;
  }

  /// Aggregate bytes/second across everything currently in flight.
  double get inFlightThroughput =>
      _trackSpeed.values.fold(0, (total, speed) => total + speed);

  /// Closes the current window and decides whether to widen or narrow.
  /// Returns true when the target changed.
  bool closeWindow() {
    final started = _windowStart;
    _windowStart = null;
    if (started == null) return false;
    // A window needs a real span of time, otherwise the first tick after a
    // worker launches would compare against nothing.
    final elapsed = _clock().difference(started).inMilliseconds;
    if (elapsed < 1000) return false;

    final throughput = inFlightThroughput;
    if (throughput <= 0) return false;
    final previous = _lastWindowThroughput;
    _lastWindowThroughput = throughput;

    if (isPinned) return false;

    final limit = maxConcurrency;
    if (_target >= limit) {
      // Already as wide as allowed; stop judging so it cannot ratchet down.
      _neutralWindows = 0;
      return false;
    }

    if (previous != null && throughput >= previous * (1 + growthThreshold)) {
      _neutralWindows = 0;
      return _resize(_target + 1);
    }
    if (previous != null && throughput < previous * collapseRatio) {
      _neutralWindows = 0;
      return _resize(_target - 1);
    }

    // No worker was gained and none was lost: hold steady for a while before
    // giving a slot back.
    _neutralWindows++;
    if (_neutralWindows < neutralWindowsBeforeShrink) return false;
    _neutralWindows = 0;
    return _resize(_target - 1);
  }

  /// Drops a finished track so its speed stops counting toward the window.
  void recordFinished(String trackId) {
    _trackSpeed.remove(trackId);
  }

  /// A rate limit is a hard signal, not a hint: collapse to one worker at once
  /// so the rest of the batch is not throttled along with the failed item.
  bool recordRateLimit() {
    _rateLimited = true;
    _lastWindowThroughput = null;
    _neutralWindows = 0;
    _trackSpeed.clear();
    return _resize(1);
  }

  /// Recognises the several shapes yt-dlp reports throttling in.
  static bool isRateLimit(String error) {
    final text = error.toLowerCase();
    return text.contains('429') ||
        text.contains('too many requests') ||
        text.contains('rate limit') ||
        text.contains('rate-limit');
  }

  bool _resize(int next) {
    final limit = isPinned ? _effectiveLimit() : maxConcurrency;
    final bounded = next.clamp(_floor, limit);
    if (bounded == _target) return false;
    _target = bounded;
    return true;
  }
}
