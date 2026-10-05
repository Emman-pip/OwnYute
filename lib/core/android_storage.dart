import 'package:flutter/services.dart';

import 'models.dart';

class AndroidSavedFile {
  const AndroidSavedFile({
    required this.path,
    required this.name,
    required this.folder,
    required this.folderName,
  });
  final String path;
  final String name;
  final String folder;
  final String folderName;
  factory AndroidSavedFile.fromMap(Map<dynamic, dynamic> map) =>
      AndroidSavedFile(
        path: map['path'] as String,
        name: map['name'] as String? ?? '',
        folder: map['folder'] as String? ?? '',
        folderName: map['folderName'] as String? ?? '',
      );
}

class AndroidStorage {
  static const _channel = MethodChannel('own_yute/storage');

  static Future<String?> pickFolder() =>
      _channel.invokeMethod<String>('pickFolder');
  static Future<String> folderName(String folder) async =>
      await _channel.invokeMethod<String>('folderName', {'folder': folder}) ??
      'Music folder';
  static Future<String> ensureFolder(String parent, String name) async =>
      (await _channel.invokeMethod<String>('ensureFolder', {
        'folder': parent,
        'name': name,
      }))!;
  static Future<bool> exists(String folder, String name) async =>
      await _channel.invokeMethod<bool>('exists', {
        'folder': folder,
        'name': name,
      }) ??
      false;
  static Future<bool> pathExists(String path) async =>
      await _channel.invokeMethod<bool>('pathExists', {'path': path}) ?? false;

  static Future<AndroidSavedFile?> save(
    String folder,
    String name,
    String source,
    String duplicate,
  ) async {
    final result = await _channel.invokeMapMethod<dynamic, dynamic>('save', {
      'folder': folder,
      'name': name,
      'source': source,
      'duplicate': duplicate,
    });
    return result == null ? null : AndroidSavedFile.fromMap(result);
  }

  static Future<List<LibraryTrack>> list(String folder) async {
    final result =
        await _channel.invokeListMethod<dynamic>('list', {'folder': folder}) ??
        [];
    return result.map((entry) {
      final map = Map<String, dynamic>.from(entry as Map);
      return LibraryTrack.fromJson(map);
    }).toList();
  }

  static Future<LibraryTrack> metadata(
    String path, {
    String folder = '',
    String folderName = '',
  }) async {
    final result =
        await _channel.invokeMapMethod<dynamic, dynamic>('metadata', {
          'path': path,
        }) ??
        {};
    final map = Map<String, dynamic>.from(result);
    return LibraryTrack.fromJson({
      ...map,
      'path': path,
      'folder': folder,
      'folderName': folderName,
      'title': map['title']?.toString() ?? 'Untitled',
    });
  }

  static Future<String> readToCache(String path) async =>
      (await _channel.invokeMethod<String>('readToCache', {'path': path}))!;
  static Future<void> replace(String path, String source) =>
      _channel.invokeMethod<void>('replace', {'path': path, 'source': source});
  static Future<void> delete(String path) =>
      _channel.invokeMethod<void>('delete', {'path': path});
  static Future<AndroidSavedFile> move(
    String path,
    String folder,
    String name,
  ) async {
    final result = await _channel.invokeMapMethod<dynamic, dynamic>('move', {
      'path': path,
      'folder': folder,
      'name': name,
    });
    return AndroidSavedFile.fromMap(result!);
  }
}
