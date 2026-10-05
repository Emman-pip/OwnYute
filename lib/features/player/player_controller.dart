import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/models.dart';
import '../search/youtube_service.dart';

class EditPlaybackSnapshot {
  const EditPlaybackSnapshot(this.path, this.position, this.wasPlaying);
  final String path;
  final Duration position;
  final bool wasPlaying;
}

class PlayerController extends ChangeNotifier {
  PlayerController(this.youtube, {bool? android, MethodChannel? channel})
    : _isAndroid = android ?? Platform.isAndroid,
      _android = channel ?? const MethodChannel('own_yute/player') {
    if (_isAndroid) {
      _android.setMethodCallHandler(
        (call) => handlePlatformEvent(call.method, call.arguments),
      );
    }
  }
  final YoutubeService youtube;
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
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      position += const Duration(seconds: 1);
      if (!_isAndroid && duration > Duration.zero && position >= duration) {
        next();
      }
      notifyListeners();
    });
  }

  Future<void> _stopProcess() async {
    _timer?.cancel();
    final process = _process;
    _process = null;
    process?.kill();
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
  }

  Future<void> previous() async {
    if (queue.isEmpty || current == null) return;
    final index = queue.indexOf(current!);
    current = queue[index > 0 ? index - 1 : 0];
    _source = null;
    position = Duration.zero;
    duration = Duration(seconds: current!.duration);
    await _start();
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
    if (_isAndroid) _android.setMethodCallHandler(null);
    super.dispose();
  }
}
