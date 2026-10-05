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

class PlayerController extends ChangeNotifier {
  PlayerController(
    this.youtube, {
    bool? android,
    MethodChannel? channel,
    this.onTrackStarted,
  }) : _isAndroid = android ?? Platform.isAndroid,
       _android = channel ?? const MethodChannel('own_yute/player') {
    if (_isAndroid) {
      _android.setMethodCallHandler(
        (call) => handlePlatformEvent(call.method, call.arguments),
      );
    }
  }
  final YoutubeService youtube;
  final ValueChanged<Track>? onTrackStarted;
  final bool _isAndroid;
  final MethodChannel _android;
  final List<Track> queue = [];
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

  Future<void> playTracks(List<Track> tracks, int index) async {
    queue
      ..clear()
      ..addAll(tracks);
    if (queue.isEmpty) return;
    current = queue[index.clamp(0, queue.length - 1)];
    position = Duration.zero;
    duration = Duration(seconds: current!.duration);
    _source = null;
    await _start();
    unawaited(_saveSnapshot());
  }

  Future<void> playLocal(List<LibraryTrack> tracks, int index) async {
    final converted = tracks
        .map(
          (t) => Track(
            id: t.path,
            url: t.path,
            title: t.title,
            artist: t.artist,
            album: t.album,
            artwork: t.artwork,
            duration: t.duration,
          ),
        )
        .toList();
    await playTracks(converted, index);
  }

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
    if (track == null) return;
    try {
      final file = await _snapshotFile();
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
      final restored = (data['queue'] as List?)
              ?.whereType<Map>()
              .map((item) => Track.fromJson(Map<String, dynamic>.from(item)))
              .toList() ??
          const <Track>[];
      if (restored.isEmpty) return;
      final index =
          ((data['index'] as num?)?.toInt() ?? 0).clamp(0, restored.length - 1);
      queue
        ..clear()
        ..addAll(restored);
      current = restored[index];
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
            final match = queue.indexWhere(
              (track) => track.title == liveTitle,
            );
            if (match >= 0) current = queue[match];
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
    final index = queue.indexOf(current!);
    if (shuffle && queue.length > 1) {
      current =
          queue[(index + 1 + DateTime.now().millisecond % (queue.length - 1)) %
              queue.length];
    } else if (index + 1 < queue.length) {
      current = queue[index + 1];
    } else if (repeat) {
      current = queue.first;
    } else {
      await _stopProcess();
      notifyListeners();
      return;
    }
    _source = null;
    position = Duration.zero;
    duration = Duration(seconds: current!.duration);
    await _start();
    unawaited(_saveSnapshot());
  }

  Future<void> previous() async {
    if (queue.isEmpty || current == null) return;
    final index = queue.indexOf(current!);
    current = queue[index > 0 ? index - 1 : 0];
    _source = null;
    position = Duration.zero;
    duration = Duration(seconds: current!.duration);
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
