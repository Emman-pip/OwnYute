import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'android_tools.dart';

/// Selects one working yt-dlp for every search, preview and download.
class YtDlpManager extends ChangeNotifier {
  static final shared = YtDlpManager();
  YtDlpManager({
    Future<String> Function()? updateLinux,
    Future<String?> Function()? installedLinux,
    Future<String> Function()? updateAndroid,
    Future<File> Function()? stampFile,
    DateTime Function()? clock,
    bool? android,
    bool? linux,
  }) : _updateLinux = updateLinux ?? _installLinuxNightly,
       _installedLinux = installedLinux ?? _linuxExecutable,
       _updateAndroid = updateAndroid ?? AndroidTools.updateNightly,
       _stampFile = stampFile ?? _defaultStampFile,
       _clock = clock ?? DateTime.now,
       _android = android ?? Platform.isAndroid,
       _linux = linux ?? Platform.isLinux;

  final Future<String> Function() _updateLinux;
  final Future<String?> Function() _installedLinux;
  final Future<String> Function() _updateAndroid;
  final Future<File> Function() _stampFile;
  final DateTime Function() _clock;
  final bool _android;
  final bool _linux;
  Future<void>? _pending;
  bool updating = false;
  String? lastError;
  String? version;
  DateTime? lastChecked;

  Future<String> executable({bool force = false}) async {
    await check(force: force);
    if (_linux) return await _installedLinux() ?? 'yt-dlp';
    return 'yt-dlp';
  }

  Future<void> check({bool force = false}) async {
    if (!_android && !_linux) return;
    if (_pending != null) return _pending!;
    final pending = _check(force: force);
    _pending = pending;
    try {
      await pending;
    } finally {
      _pending = null;
    }
  }

  Future<void> _check({required bool force}) async {
    final now = _clock();
    try {
      final stamp = await _stampFile();
      if (!force && await stamp.exists()) {
        final checked = DateTime.tryParse(await stamp.readAsString());
        if (checked != null &&
            now.difference(checked) < const Duration(days: 1)) {
          lastChecked = checked;
          return;
        }
      }
      updating = true;
      lastError = null;
      notifyListeners();
      try {
        version = _android ? await _updateAndroid() : await _updateLinux();
      } catch (failure) {
        lastError =
            'Nightly update failed: $failure. Using the available yt-dlp.';
      }
      lastChecked = now;
      await stamp.parent.create(recursive: true);
      await stamp.writeAsString(now.toIso8601String(), flush: true);
    } catch (failure) {
      lastError ??= 'Could not check yt-dlp: $failure';
    } finally {
      updating = false;
      notifyListeners();
    }
  }

  static Future<Directory> _toolDirectory() async =>
      Directory(p.join((await getApplicationSupportDirectory()).path, 'tools'));

  static Future<File> _defaultStampFile() async =>
      File(p.join((await _toolDirectory()).path, 'yt-dlp-last-check'));

  static Future<String?> _linuxExecutable() async {
    final file = File(p.join((await _toolDirectory()).path, 'yt-dlp'));
    return await file.exists() ? file.path : null;
  }

  static Future<String> _installLinuxNightly() async {
    final asset = switch (Abi.current()) {
      Abi.linuxX64 => 'yt-dlp_linux',
      Abi.linuxArm64 => 'yt-dlp_linux_aarch64',
      _ => throw const FileSystemException(
        'No nightly Linux binary is available for this architecture',
      ),
    };
    final directory = await _toolDirectory();
    await directory.create(recursive: true);
    final candidate = File(p.join(directory.path, 'yt-dlp.download'));
    final active = File(p.join(directory.path, 'yt-dlp'));
    final base = Uri.parse(
      'https://github.com/yt-dlp/yt-dlp-nightly-builds/releases/latest/download/',
    );
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final sums = utf8.decode(
        await _fetch(client, base.resolve('SHA2-256SUMS'), 1024 * 1024),
      );
      final match = RegExp(
        r'^([a-fA-F0-9]{64})\s+\*?' + asset + r'$',
        multiLine: true,
      ).firstMatch(sums);
      if (match == null) {
        throw const FormatException('Nightly checksum is missing');
      }
      final expected = match.group(1)!.toLowerCase();
      if (await active.exists() &&
          sha256.convert(await active.readAsBytes()).toString() == expected) {
        final current = await Process.run(active.path, [
          '--version',
        ]).timeout(const Duration(seconds: 15));
        if (current.exitCode == 0 &&
            (current.stdout as String).trim().isNotEmpty) {
          return (current.stdout as String).trim();
        }
      }
      final bytes = await _fetch(
        client,
        base.resolve(asset),
        100 * 1024 * 1024,
      );
      if (sha256.convert(bytes).toString().toLowerCase() != expected) {
        throw const FormatException('Nightly checksum does not match');
      }
      await candidate.writeAsBytes(bytes, flush: true);
      final chmod = await Process.run('chmod', ['700', candidate.path]);
      if (chmod.exitCode != 0) {
        throw const FileSystemException('Could not mark yt-dlp executable');
      }
      final result = await Process.run(candidate.path, [
        '--version',
      ]).timeout(const Duration(seconds: 15));
      if (result.exitCode != 0 || (result.stdout as String).trim().isEmpty) {
        throw const FileSystemException('Downloaded yt-dlp did not start');
      }
      await candidate.rename(active.path);
      return (result.stdout as String).trim();
    } finally {
      client.close(force: true);
      if (await candidate.exists()) await candidate.delete();
    }
  }

  static Future<List<int>> _fetch(HttpClient client, Uri uri, int limit) async {
    final request = await client.getUrl(uri);
    request.headers.set(HttpHeaders.userAgentHeader, 'OwnYute');
    final response = await request.close().timeout(const Duration(seconds: 30));
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'Download returned HTTP ${response.statusCode}',
        uri: uri,
      );
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response.timeout(const Duration(seconds: 30))) {
      bytes.add(chunk);
      if (bytes.length > limit) {
        throw const FormatException('Nightly download is too large');
      }
    }
    return bytes.takeBytes();
  }
}
