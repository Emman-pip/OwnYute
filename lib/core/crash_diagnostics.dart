import 'dart:io';

import 'package:flutter/services.dart';

class CrashDiagnostics {
  static const _channel = MethodChannel('own_yute/diagnostics');

  static Future<String> report() async {
    if (!Platform.isAndroid) {
      return 'Android diagnostics are unavailable on this platform.';
    }
    try {
      return await _channel.invokeMethod<String>('report') ??
          'No Android diagnostics were returned.';
    } catch (failure) {
      return 'Could not read Android diagnostics: $failure';
    }
  }

  static Future<void> recordDart(Object error, StackTrace? stack) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('recordDart', {
        'message': error.toString(),
        'stack': stack?.toString() ?? '',
      });
    } catch (_) {
      // Diagnostics should never make an existing error worse.
    }
  }
}
