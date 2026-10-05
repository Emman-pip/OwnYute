import 'dart:io';

import 'package:flutter/services.dart';

/// Sends separated argv arrays to the packaged Android yt-dlp and FFmpeg tools.
class AndroidTools {
  static const _channel = MethodChannel('own_yute/tools');
  static final _progress = <String, void Function(double, String)>{};
  static bool _listening = false;
  static int _sequence = 0;

  static String newTaskId() =>
      'own_yute_${DateTime.now().microsecondsSinceEpoch}_${_sequence++}';

  static void _listen() {
    if (_listening) return;
    _listening = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'progress') return;
      final data = Map<String, dynamic>.from(call.arguments as Map);
      final listener = _progress[data['id'] as String];
      listener?.call(
        (data['value'] as num?)?.toDouble() ?? 0,
        data['line']?.toString() ?? '',
      );
    });
  }

  static Future<ProcessResult> run(
    String executable,
    List<String> args, {
    String? taskId,
    void Function(double, String)? onProgress,
  }) async {
    _listen();
    final id = taskId ?? newTaskId();
    if (onProgress != null) _progress[id] = onProgress;
    final method = executable == 'yt-dlp' ? 'ytDlp' : 'ffmpeg';
    try {
      final output = await _channel.invokeMapMethod<String, dynamic>(method, {
        'id': id,
        'args': args,
        'progress': onProgress != null,
      });
      if (output == null) {
        throw const FileSystemException('Android tool returned no result.');
      }
      return ProcessResult(
        0,
        (output['exitCode'] as num?)?.toInt() ?? 1,
        output['stdout']?.toString() ?? '',
        output['stderr']?.toString() ?? '',
      );
    } on PlatformException catch (failure) {
      throw ProcessException(
        executable,
        args,
        failure.message ?? 'Android tool failed.',
      );
    } finally {
      _progress.remove(id);
    }
  }

  static Future<void> cancel(String id) =>
      _channel.invokeMethod<void>('cancel', {'id': id});

  static Future<String> updateNightly() async {
    try {
      return await _channel.invokeMethod<String>('updateNightly') ?? 'nightly';
    } on PlatformException catch (failure) {
      throw ProcessException(
        'yt-dlp',
        const [],
        failure.message ?? 'Update failed.',
      );
    }
  }
}
