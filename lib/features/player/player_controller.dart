import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/models.dart';
import '../search/youtube_service.dart';

class EditPlaybackSnapshot {
  const EditPlaybackSnapshot(this.path, this.position, this.wasPlaying);
  final String path;
  final Duration position;
  final bool wasPlaying;
}

/// Reads a local file's length in seconds. Injected so tests can avoid FFmpeg.
typedef LocalDurationProbe = Future<int> Function(String path);

class PlayerController extends ChangeNotifier {
  PlayerController(
    this.youtube, {
    bool? android,
    MethodChannel? channel,
    this.onTrackStarted,
    LocalDurationProbe? probeLocalDuration,
  }) : _isAndroid = android ?? Platform.isAndroid,
       _android = channel ?? const MethodChannel('own_yute/player'),
       _probeLocalDuration = probeLocalDuration ?? _ffprobeDuration {
    if (_isAndroid) {
      _android.setMethodCallHandler(
        (call) => handlePlatformEvent(call.method, call.arguments),
      );
    }
  }
  final YoutubeService youtube;
  final ValueChanged<Track>? onTrackStarted;
  final LocalDurationProbe _probeLocalDuration;
  final bool _isAndroid;
  final MethodChannel _android;
  final List<Track> queue = [];

  /// Tracks that already finished, oldest first, so **Previous** still has
  /// somewhere to go after they leave [queue]. In memory only: the snapshot
  /// keeps the live queue and nothing depends on history surviving a restart.
  final List<Track> history = [];

  /// How many finished tracks to keep. Bounded so a long session that never
  /// restarts the app cannot grow this without limit.
  static const int historyLimit = 50;

  Track? current;
  Process? _process;
  Timer? _timer;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  bool playing = false;
  bool preparing = false;
  bool buffering = false;
  bool shuffle = false;
  bool repeat = false;
  String? error;
  String? _source;
  bool _androidServiceStarted = false;
  int? _externalPid;
  int _ticks = 0;

  Future<void> handlePlatformEvent(String event, Object? value) async {
    if (event == 'duration') {
      duration = Duration(milliseconds: (value as num).toInt());
    } else if (event == 'ended' || event == 'next') {
      await next();
      return;
    } else if (event == 'previous') {
      await previous();
      return;
    } else if (event == 'paused') {
      _timer?.cancel();
      playing = false;
      preparing = false;
      buffering = false;
    } else if (event == 'started') {
      error = null;
      preparing = false;
      playing = true;
      if (!buffering) _startTimer();
    } else if (event == 'buffering') {
      buffering = true;
      _timer?.cancel();
    } else if (event == 'ready') {
      buffering = false;
      if (playing) _startTimer();
    } else if (event == 'error') {
      error = value?.toString() ?? 'Playback failed.';
      _timer?.cancel();
      playing = false;
      preparing = false;
      buffering = false;
      _androidServiceStarted = false;
      unawaited(_saveSnapshot());
    }
    notifyListeners();
  }

  /// Keeps the current track at the head of [queue] and moves everything the
  /// user has already heard into [history].
  ///
  /// The queue is shown as "what plays from here", so a track belongs at index
  /// zero while it is playing and must not linger once it is done. Songs
  /// skipped by jumping ahead land in history too, which is what lets
  /// **Previous** return to one of them.
  void _normalizeQueue() {
    final track = current;
    if (track == null) {
      queue.clear();
      return;
    }
    final index = queue.indexOf(track);
    if (index < 0) {
      // The current track is not in the queue (a swap, or a restore that lost
      // it). Put it back at the head rather than dropping playback.
      queue.insert(0, track);
      return;
    }
    if (index == 0) return;
    _remember(queue.sublist(0, index));
    queue.removeRange(0, index);
  }

  void _remember(Iterable<Track> finished) {
    history.addAll(finished);
    if (history.length > PlayerController.historyLimit) {
      history.removeRange(0, history.length - PlayerController.historyLimit);
    }
  }

  Future<void> playTracks(List<Track> tracks, int index) async {
    queue
      ..clear()
      ..addAll(tracks);
    if (queue.isEmpty) return;
    current = queue[index.clamp(0, queue.length - 1)];
    position = Duration.zero;
    duration = Duration(seconds: current!.duration);
    _source = null;
    // Starting part way in means the songs before it are already passed.
    _normalizeQueue();
    await _start();
    unawaited(_saveSnapshot());
    unawaited(_fillLocalDuration(current!));
  }

  /// Downloaded songs inherit `duration: 0` from flat YouTube search data, so
  /// probe the file to keep the scrubber usable without a platform event.
  Future<void> _fillLocalDuration(Track track) async {
    if (track.url.startsWith('http') || track.duration > 0) return;
    final seconds = await _probeLocalDuration(track.url);
    if (seconds <= 0 || current?.url != track.url) return;
    final updated = track.copyWith(duration: seconds);
    final index = queue.indexWhere((item) => item.url == track.url);
    if (index >= 0) queue[index] = updated;
    current = updated;
    duration = Duration(seconds: seconds);
    notifyListeners();
    unawaited(_saveSnapshot());
  }

  static Future<int> _ffprobeDuration(String path) async {
    try {
      final result = await Process.run('ffprobe', [
        '-v',
        'error',
        '-show_entries',
        'format=duration',
        '-of',
        'json',
        path,
      ]);
      if (result.exitCode != 0) return 0;
      final json = jsonDecode(result.stdout as String) as Map<String, dynamic>;
      final format = json['format'] as Map<String, dynamic>?;
      return (double.tryParse(format?['duration']?.toString() ?? '') ?? 0)
          .round();
    } catch (_) {
      return 0;
    }
  }

  Future<void> playAt(int index) async {
    if (queue.isEmpty) return;
    current = queue[index.clamp(0, queue.length - 1)];
    position = Duration.zero;
    duration = Duration(seconds: current!.duration);
    _source = null;
    _normalizeQueue();
    await _start();
    unawaited(_saveSnapshot());
    unawaited(_fillLocalDuration(current!));
  }

  void addToQueue(Track track) {
    queue.add(track);
    if (current == null) {
      current = track;
      position = Duration.zero;
      duration = Duration(seconds: track.duration);
      _source = null;
    }
    notifyListeners();
    unawaited(_saveSnapshot());
  }

  void addAllToQueue(Iterable<Track> tracks) {
    final additions = tracks.toList();
    if (additions.isEmpty) return;
    queue.addAll(additions);
    if (current == null) {
      current = additions.first;
      position = Duration.zero;
      duration = Duration(seconds: current!.duration);
      _source = null;
    }
    notifyListeners();
    unawaited(_saveSnapshot());
  }

  void addLibraryToQueue(LibraryTrack track) => addToQueue(_fromLibrary(track));

  Future<void> removeAt(int index) async {
    if (index < 0 || index >= queue.length) return;
    final removingCurrent = current != null && index == queue.indexOf(current!);
    final wasActive = playing || preparing;
    if (removingCurrent) await _stopProcess();
    queue.removeAt(index);
    if (removingCurrent) {
      // The head is gone, so the next track up takes over playback.
      current = queue.isEmpty ? null : queue.first;
      position = Duration.zero;
      duration = Duration(seconds: current?.duration ?? 0);
      _source = null;
      if (wasActive && current != null) await _start();
    }
    _normalizeQueue();
    notifyListeners();
    unawaited(_saveSnapshot());
  }

  void reorder(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= queue.length) return;
    // Index zero is the playing track, and the queue is shown current-first.
    // Moving anything across it would break that reading of the list.
    if (oldIndex == 0 || newIndex == 0) return;
    final bounded = newIndex.clamp(0, queue.length - 1);
    final track = queue.removeAt(oldIndex);
    queue.insert(bounded, track);
    notifyListeners();
    unawaited(_saveSnapshot());
  }

  Future<void> playLocal(List<LibraryTrack> tracks, int index) async {
    final converted = tracks.map(_fromLibrary).toList();
    await playTracks(converted, index);
  }

  static Track _fromLibrary(LibraryTrack track) => Track(
    id: track.path,
    url: track.path,
    title: track.title,
    artist: track.artist,
    album: track.album,
    artwork: track.artwork,
    duration: track.duration,
  );

  Future<EditPlaybackSnapshot?> suspendForEdit(String path) async {
    if (current?.url != path) return null;
    final snapshot = EditPlaybackSnapshot(path, position, playing || preparing);
    await _stopProcess();
    notifyListeners();
    return snapshot;
  }

  Future<void> resumeAfterEdit(
    EditPlaybackSnapshot? snapshot,
    LibraryTrack track,
  ) async {
    if (snapshot == null || current?.url != snapshot.path) return;
    final updated = Track(
      id: track.path,
      url: track.path,
      title: track.title,
      artist: track.artist,
      album: track.album,
      artwork: track.artwork,
      duration: track.duration,
    );
    final index = queue.indexWhere((item) => item.url == snapshot.path);
    if (index >= 0) queue[index] = updated;
    current = updated;
    position = snapshot.position;
    _source = null;
    if (snapshot.wasPlaying) {
      await _start();
    } else {
      notifyListeners();
    }
  }

  Future<void> removeDeletedTrack(String path) async {
    if (current?.url == path) {
      await _stopProcess();
      current = null;
      _source = null;
      position = Duration.zero;
      duration = Duration.zero;
    }
    queue.removeWhere((item) => item.url == path);
    notifyListeners();
  }

  Future<void> _start() async {
    final track = current;
    if (track == null) return;
    onTrackStarted?.call(track);
    try {
      await _stopProcess();
      preparing = true;
      buffering = true;
      notifyListeners();
      _source ??= track.url.startsWith('http')
          ? await youtube.streamUrl(track)
          : track.url;
      if (_isAndroid) {
        error = null;
        _androidServiceStarted = true;
        notifyListeners();
        await _android.invokeMethod<void>('play', {
          'url': _source,
          'position': position.inMilliseconds,
          'title': track.title,
          'artist': track.artist,
        });
      } else {
        _process = await Process.start('ffplay', [
          '-nodisp',
          '-autoexit',
          '-loglevel',
          'quiet',
          '-ss',
          position.inSeconds.toString(),
          _source!,
        ]);
        final started = _process!;
        started.exitCode.then((_) {
          if (playing && identical(_process, started)) next();
        });
      }
      if (!_isAndroid) {
        playing = true;
        preparing = false;
        buffering = false;
        error = null;
        _startTimer();
      }
      notifyListeners();
    } catch (failure) {
      error = failure.toString();
      playing = false;
      preparing = false;
      buffering = false;
      _androidServiceStarted = false;
      notifyListeners();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _ticks = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      position += const Duration(seconds: 1);
      if (!_isAndroid && duration > Duration.zero && position >= duration) {
        next();
      }
      notifyListeners();
      _ticks++;
      if (_ticks % 5 == 0) unawaited(_saveSnapshot());
    });
  }

  Future<File> _snapshotFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, 'playback_snapshot.json'));
  }

  Future<void> _saveSnapshot() async {
    final track = current;
    try {
      final file = await _snapshotFile();
      if (track == null) {
        if (await file.exists()) await file.delete();
        return;
      }
      await file.writeAsString(
        jsonEncode({
          'queue': queue.map((item) => item.toJson()).toList(),
          'index': queue.indexOf(track),
          'positionMs': position.inMilliseconds,
          'durationMs': duration.inMilliseconds,
          'playing': playing,
          'source': _source,
          'pid': _isAndroid ? null : (_process?.pid ?? _externalPid),
          'savedAt': DateTime.now().millisecondsSinceEpoch,
        }),
      );
    } catch (_) {}
  }

  bool _pidAlive(int pid) {
    try {
      final cmdline = File('/proc/$pid/cmdline').readAsStringSync();
      return cmdline.contains('ffplay');
    } catch (_) {
      return false;
    }
  }

  /// Reattaches to playback that is still running after the app was closed,
  /// or restores the last known queue/track in a paused state.
  Future<void> restore() async {
    try {
      final file = await _snapshotFile();
      if (!await file.exists()) return;
      final data =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final restored =
          (data['queue'] as List?)
              ?.whereType<Map>()
              .map((item) => Track.fromJson(Map<String, dynamic>.from(item)))
              .toList() ??
          const <Track>[];
      if (restored.isEmpty) return;
      final index = ((data['index'] as num?)?.toInt() ?? 0).clamp(
        0,
        restored.length - 1,
      );
      queue
        ..clear()
        ..addAll(restored);
      current = restored[index];
      // The snapshot stores an index into the whole queue. Re-normalizing on
      // load is what keeps "current first" true after a restart instead of
      // resurrecting the old ordering.
      _normalizeQueue();
      position = Duration(
        milliseconds: (data['positionMs'] as num?)?.toInt() ?? 0,
      );
      duration = Duration(
        milliseconds: (data['durationMs'] as num?)?.toInt() ?? 0,
      );
      if (duration == Duration.zero && current!.duration > 0) {
        duration = Duration(seconds: current!.duration);
      }
      final savedSource = data['source'] as String?;
      final wasPlaying = data['playing'] == true;
      final savedAt = DateTime.fromMillisecondsSinceEpoch(
        (data['savedAt'] as num?)?.toInt() ?? 0,
      );
      var attached = false;
      if (_isAndroid) {
        final state = await _android.invokeMethod<dynamic>('state');
        if (state is Map) {
          _androidServiceStarted = true;
          _source = (state['source'] as String?) ?? savedSource;
          position = Duration(
            milliseconds: (state['position'] as num?)?.toInt() ?? 0,
          );
          final liveDuration = (state['duration'] as num?)?.toInt() ?? 0;
          if (liveDuration > 0) duration = Duration(milliseconds: liveDuration);
          playing = state['playing'] == true;
          preparing = false;
          buffering = false;
          attached = true;
          if (playing) _startTimer();
          // Best effort: the notification may have advanced while the UI was
          // gone, so jump to whichever queued track matches the live title.
          final liveTitle = state['title'] as String?;
          if (liveTitle != null &&
              liveTitle != current!.title &&
              savedSource != null) {
            final match = queue.indexWhere((track) => track.title == liveTitle);
            if (match >= 0) current = queue[match];
            // The notification may have advanced while the app was gone, so the
            // live track is not the one the snapshot saved.
            _normalizeQueue();
          }
        }
      } else if (Platform.isLinux) {
        final pid = (data['pid'] as num?)?.toInt();
        if (pid != null && _pidAlive(pid)) {
          _externalPid = pid;
          _source = savedSource ?? current!.url;
          if (wasPlaying) {
            position += DateTime.now().difference(savedAt);
            playing = true;
            _startTimer();
          }
          attached = true;
        }
      }
      if (attached && duration > Duration.zero && position >= duration) {
        _timer?.cancel();
        playing = false;
        await next();
        return;
      }
      if (!attached) {
        playing = false;
        preparing = false;
        buffering = false;
        _source = null;
        _androidServiceStarted = false;
      }
      notifyListeners();
      unawaited(_fillLocalDuration(current!));
    } catch (_) {}
  }

  Future<void> _stopProcess() async {
    _timer?.cancel();
    final process = _process;
    _process = null;
    process?.kill();
    final external = _externalPid;
    _externalPid = null;
    if (external != null && external != process?.pid) {
      try {
        Process.killPid(external);
      } catch (_) {}
    }
    if (_isAndroid && _androidServiceStarted) {
      await _android.invokeMethod<void>('stop');
      _androidServiceStarted = false;
    }
    playing = false;
    preparing = false;
    buffering = false;
  }

  Future<void> toggle() async {
    try {
      if (playing || preparing) {
        if (_isAndroid) {
          await _android.invokeMethod<void>('pause');
          _timer?.cancel();
          playing = false;
          preparing = false;
        } else {
          await _stopProcess();
        }
        notifyListeners();
      } else {
        if (_isAndroid && _source != null && _androidServiceStarted) {
          await _android.invokeMethod<void>('resume');
          preparing = true;
          notifyListeners();
        } else {
          await _start();
        }
      }
    } catch (failure) {
      error = 'Could not control playback: $failure';
      playing = false;
      preparing = false;
      notifyListeners();
    }
    unawaited(_saveSnapshot());
  }

  Future<void> seek(Duration to) async {
    position = to;
    if (_isAndroid) {
      try {
        buffering = true;
        _timer?.cancel();
        notifyListeners();
        await _android.invokeMethod<void>('seek', {
          'position': to.inMilliseconds,
        });
      } catch (failure) {
        error = 'Could not seek: $failure';
        buffering = false;
        if (playing) _startTimer();
      }
      notifyListeners();
    } else if (playing) {
      await _start();
    } else {
      notifyListeners();
    }
    unawaited(_saveSnapshot());
  }

  Future<void> next() async {
    if (queue.isEmpty || current == null) return;
    // The queue is current-first, so the next track is always index one.
    if (shuffle && queue.length > 1) {
      final pick = 1 + DateTime.now().millisecond % (queue.length - 1);
      current = queue[pick];
    } else if (queue.length > 1) {
      current = queue[1];
    } else if (repeat && history.isNotEmpty) {
      // Nothing left to play, so start the set over: the finished tracks come
      // back in the order they were heard, with the track that just ended at
      // the end of the set rather than dropped from it.
      final restarting = [...history, current!];
      queue
        ..clear()
        ..addAll(restarting);
      current = restarting.first;
    } else {
      await _stopProcess();
      notifyListeners();
      return;
    }
    _source = null;
    position = Duration.zero;
    duration = Duration(seconds: current!.duration);
    _normalizeQueue();
    await _start();
    unawaited(_saveSnapshot());
  }

  Future<void> previous() async {
    if (queue.isEmpty || current == null) return;
    // With the current track pinned to the top, going back means taking the
    // most recent finished track off the history and putting it in front.
    final Track? back;
    if (history.isNotEmpty) {
      back = history.removeLast();
      queue.insert(0, back);
    } else {
      // Nothing heard yet, so restart what is playing.
      back = current;
    }
    final outgoing = current!;
    current = back;
    _source = null;
    position = Duration.zero;
    duration = Duration(seconds: current!.duration);
    if (!identical(back, outgoing)) _remember([outgoing]);
    await _start();
    unawaited(_saveSnapshot());
  }

  void setShuffle(bool value) {
    shuffle = value;
    notifyListeners();
  }

  void setRepeat(bool value) {
    repeat = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _process?.kill();
    final external = _externalPid;
    _externalPid = null;
    if (external != null) {
      try {
        Process.killPid(external);
      } catch (_) {}
    }
    if (_isAndroid) _android.setMethodCallHandler(null);
    super.dispose();
  }
}
