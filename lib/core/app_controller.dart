import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'database.dart';
import 'database_factory.dart';
import 'android_storage.dart';
import 'models.dart';
import 'yt_dlp_manager.dart';
import '../features/downloads/download_service.dart';
import '../features/search/youtube_service.dart';
import '../features/player/player_controller.dart';
import '../features/library/library_service.dart';

enum AppThemeChoice {
  system,
  light,
  dark,
  darkBlue,
  darkPink,
  pastelBlue,
  pastelPink,
}

class AppController extends ChangeNotifier {
  AppController({
    AppDatabase? database,
    YoutubeService? youtube,
    DownloadService? downloader,
  }) : database = database ?? openAppDatabase(),
       youtube = youtube ?? YoutubeService(),
       downloader = downloader ?? DownloadService() {
    player = PlayerController(this.youtube);
  }
  final AppDatabase database;
  final YoutubeService youtube;
  final DownloadService downloader;
  final LibraryService libraryService = LibraryService();
  final YtDlpManager tools = YtDlpManager.shared;
  late final PlayerController player;
  List<Track> songs = [];
  List<Track> playlists = [];
  List<Track> picker = [];
  PlaylistRef? pickerPlaylist;
  List<Track> history = [];
  List<QueueItem> queue = [];
  List<LibraryTrack> library = [];
  List<String> importedFolders = [];
  Map<String, String> importedFolderLabels = {};
  String? destination;
  String? destinationLabel;
  String? error;
  bool busy = false;
  bool downloading = false;
  bool cancelled = false;
  ThemeMode themeMode = ThemeMode.system;
  AppThemeChoice themeChoice = AppThemeChoice.system;
  bool playerAnimationEnabled = true;
  int _batchSequence = 0;

  void clearError() {
    error = null;
    notifyListeners();
  }

  Future<void> initialize() async {
    queue = await database.loadQueue();
    library = await database.loadLibrary();
    history = await database.loadHistory();
    destination = await database.setting('destination');
    destinationLabel = await database.setting('destinationLabel');
    final savedTheme =
        await database.setting('themeChoice') ??
        await database.setting('themeMode');
    themeChoice = AppThemeChoice.values.firstWhere(
      (choice) => choice.name == savedTheme,
      orElse: () => AppThemeChoice.system,
    );
    themeMode = switch (themeChoice) {
      AppThemeChoice.pastelBlue || AppThemeChoice.pastelPink => ThemeMode.light,
      AppThemeChoice.dark ||
      AppThemeChoice.darkBlue ||
      AppThemeChoice.darkPink => ThemeMode.dark,
      AppThemeChoice.light => ThemeMode.light,
      _ => ThemeMode.system,
    };
    playerAnimationEnabled =
        (await database.setting('playerAnimationEnabled')) != 'false';
    importedFolders =
        (await database.setting('folders'))
            ?.split('\n')
            .where((s) => s.isNotEmpty)
            .toList() ??
        [];
    for (final folder in importedFolders) {
      final savedLabel = await database.setting('folderLabel:$folder');
      if (savedLabel != null) {
        importedFolderLabels[folder] = savedLabel;
      } else if (Platform.isAndroid) {
        try {
          importedFolderLabels[folder] = await AndroidStorage.folderName(
            folder,
          );
        } catch (_) {
          importedFolderLabels[folder] = folder;
        }
      } else {
        importedFolderLabels[folder] = folder;
      }
    }
    await refreshLibrary();
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode value) async {
    themeMode = value;
    themeChoice = AppThemeChoice.values.byName(value.name);
    await database.saveSetting('themeMode', value.name);
    await database.saveSetting('themeChoice', themeChoice.name);
    notifyListeners();
  }

  Future<void> setThemeChoice(AppThemeChoice value) async {
    themeChoice = value;
    themeMode = switch (value) {
      AppThemeChoice.dark ||
      AppThemeChoice.darkBlue ||
      AppThemeChoice.darkPink => ThemeMode.dark,
      AppThemeChoice.light ||
      AppThemeChoice.pastelBlue ||
      AppThemeChoice.pastelPink => ThemeMode.light,
      _ => ThemeMode.system,
    };
    await database.saveSetting('themeChoice', value.name);
    notifyListeners();
  }

  Future<void> setPlayerAnimationEnabled(bool value) async {
    playerAnimationEnabled = value;
    await database.saveSetting('playerAnimationEnabled', value.toString());
    notifyListeners();
  }

  Future<void> refreshLibrary() async {
    for (final entry in List<LibraryTrack>.from(library)) {
      bool exists;
      try {
        exists = Platform.isAndroid && entry.path.startsWith('content://')
            ? await AndroidStorage.pathExists(entry.path)
            : await File(entry.path).exists();
      } catch (failure) {
        error = 'Could not access ${entry.title}: $failure';
        continue;
      }
      if (!exists) {
        await database.removeLibrary(entry.path);
        library = library.where((track) => track.path != entry.path).toList();
      }
    }
    for (final folder in importedFolders) {
      if (Platform.isAndroid || await Directory(folder).exists()) {
        await scanFolder(folder);
      }
    }
    notifyListeners();
  }

  Future<void> search(String query) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      final result = await youtube.search(query);
      songs = result.songs;
      playlists = result.playlists;
    } catch (failure) {
      error = failure.toString();
    }
    busy = false;
    notifyListeners();
  }

  Future<Track?> openUrl(String value) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      final result = await youtube.openUrl(value);
      picker = result.$2;
      pickerPlaylist = youtube.lastPlaylist;
      if (result.$1 != null) await database.saveHistory(result.$1!);
      history = await database.loadHistory();
      return result.$1;
    } catch (failure) {
      error = failure.toString();
      return null;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> openPlaylist(Track playlist) async {
    await openUrl(playlist.url);
    if (picker.isNotEmpty && pickerPlaylist == null) {
      pickerPlaylist = PlaylistRef(id: playlist.id, title: playlist.title);
    }
  }

  Future<void> add(Track track) async {
    final existing = queue.indexWhere((item) => item.track.id == track.id);
    if (existing >= 0) {
      if (!queue[existing].inSingles) {
        queue[existing] = queue[existing].copyWith(inSingles: true);
        await database.saveQueue(queue[existing]);
        notifyListeners();
      }
      return;
    }
    final item = QueueItem(track: track);
    queue = [...queue, item];
    await database.saveQueue(item);
    await database.saveHistory(track);
    history = await database.loadHistory();
    notifyListeners();
  }

  Future<void> addAll(Iterable<Track> tracks, {PlaylistRef? playlist}) async {
    final selected = {for (final track in tracks) track.id: track}.values
        .toList();
    if (selected.isEmpty) return;
    final batch = QueueBatchRef(
      id: '${DateTime.now().microsecondsSinceEpoch}-${_batchSequence++}',
      title: playlist?.title ?? 'Selection',
      playlist: playlist,
    );
    for (final track in selected) {
      final saved = library.where(
        (entry) =>
            entry.sourceTrackId.isNotEmpty && entry.sourceTrackId == track.id,
      );
      if (saved.isNotEmpty) {
        if (playlist != null) await assignToPlaylist(saved.first, playlist);
        continue;
      }
      final index = queue.indexWhere((item) => item.track.id == track.id);
      final item = index < 0
          ? QueueItem(track: track, inSingles: false, batches: [batch])
          : queue[index].copyWith(batches: [...queue[index].batches, batch]);
      if (index < 0) {
        queue = [...queue, item];
      } else {
        queue[index] = item;
      }
      await database.saveQueue(item);
      await database.saveHistory(track);
    }
    history = await database.loadHistory();
    notifyListeners();
  }

  Future<void> removeFromGroup(String id, {String? batchId}) async {
    final index = queue.indexWhere((item) => item.track.id == id);
    if (index < 0) return;
    final item = queue[index];
    final updated = item.copyWith(
      inSingles: batchId == null ? false : item.inSingles,
      batches: batchId == null
          ? item.batches
          : item.batches.where((batch) => batch.id != batchId).toList(),
    );
    if (!updated.inSingles && updated.batches.isEmpty) {
      await remove(id);
    } else {
      queue[index] = updated;
      await database.saveQueue(updated);
      notifyListeners();
    }
  }

  Future<void> clearFinished() async {
    if (downloading) return;
    final finished = queue.where((item) => item.status == 'done').toList();
    for (final item in finished) {
      await database.removeQueue(item.track.id);
    }
    queue = queue.where((item) => item.status != 'done').toList();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    queue = queue.where((item) => item.track.id != id).toList();
    await database.removeQueue(id);
    notifyListeners();
  }

  Future<void> editQueue(Track track) async {
    final index = queue.indexWhere((item) => item.track.id == track.id);
    if (index < 0) return;
    queue[index] = queue[index].copyWith(track: track);
    await database.saveQueue(queue[index]);
    notifyListeners();
  }

  Future<void> batchEdit({
    String? batchId,
    String? artist,
    String? album,
    String? artwork,
  }) async {
    for (var index = 0; index < queue.length; index++) {
      final item = queue[index];
      if (batchId != null &&
          !item.batches.any((batch) => batch.id == batchId)) {
        continue;
      }
      queue[index] = item.copyWith(
        track: item.track.copyWith(
          artist: artist?.isNotEmpty == true ? artist : null,
          album: album?.isNotEmpty == true ? album : null,
          artwork: artwork?.isNotEmpty == true ? artwork : null,
        ),
      );
      await database.saveQueue(queue[index]);
    }
    notifyListeners();
  }

  Future<String?> chooseDestination() async {
    try {
      final chosen = Platform.isAndroid
          ? await AndroidStorage.pickFolder()
          : await FilePicker.getDirectoryPath(
              dialogTitle: 'Choose download folder',
            );
      if (chosen != null) {
        destination = chosen;
        destinationLabel = Platform.isAndroid
            ? await AndroidStorage.folderName(chosen)
            : chosen;
        await database.saveSetting('destination', chosen);
        await database.saveSetting('destinationLabel', destinationLabel!);
        notifyListeners();
      }
      return chosen;
    } catch (failure) {
      error = 'Could not open the download folder: $failure';
      notifyListeners();
      return null;
    }
  }

  Future<String> prepareBatchFolder(String folder, String name) async {
    if (name.isEmpty) return folder;
    if (Platform.isAndroid) return AndroidStorage.ensureFolder(folder, name);
    return p.join(folder, name);
  }

  Future<void> downloadQueue(
    String folder,
    Future<DuplicateChoice> Function(String) onDuplicate,
  ) async {
    if (downloading) return;
    downloading = true;
    cancelled = false;
    error = null;
    notifyListeners();
    try {
      for (final item in List<QueueItem>.from(queue)) {
        if (cancelled) break;
        if (item.status == 'done') continue;
        final fileName = downloader.fileName(item.track);
        final path = Platform.isAndroid
            ? '${await AndroidStorage.folderName(folder)}/$fileName'
            : p.join(folder, fileName);
        var choice = DuplicateChoice.replace;
        final exists = Platform.isAndroid
            ? await AndroidStorage.exists(folder, fileName)
            : await File(path).exists();
        if (exists) choice = await onDuplicate(path);
        if (exists && choice == DuplicateChoice.skip) {
          await _updateItem(item.track.id, status: 'done', progress: 1);
          continue;
        }
        await _updateItem(
          item.track.id,
          status: 'downloading',
          error: '',
          progress: 0,
        );
        try {
          final saved = await downloader.download(item.track, folder, choice, (
            progress,
          ) {
            _updateItem(item.track.id, progress: progress);
          });
          if (saved != null) {
            final membership = queue.firstWhere(
              (entry) => entry.track.id == item.track.id,
              orElse: () => item,
            );
            final libraryTrack = LibraryTrack(
              path: saved,
              title: item.track.title,
              artist: item.track.artist,
              album: item.track.album,
              artwork: item.track.artwork,
              duration: item.track.duration,
              folder: folder,
              folderName: Platform.isAndroid
                  ? await AndroidStorage.folderName(folder)
                  : p.basename(folder),
              sourceTrackId: item.track.id,
              playlists: {
                for (final batch in membership.batches)
                  if (batch.playlist != null)
                    batch.playlist!.id: batch.playlist!,
                for (final playlist in membership.targetPlaylists)
                  playlist.id: playlist,
              }.values.toList(),
            );
            await database.saveLibrary(libraryTrack);
            library = [
              ...library.where((entry) => entry.path != saved),
              libraryTrack,
            ];
          }
          await _updateItem(item.track.id, status: 'done', progress: 1);
        } catch (failure) {
          await _updateItem(
            item.track.id,
            status: 'failed',
            error: failure.toString(),
          );
        }
      }
    } catch (failure) {
      error = 'Could not prepare download: $failure';
    } finally {
      downloading = false;
      notifyListeners();
    }
  }

  Future<void> _updateItem(
    String id, {
    String? status,
    String? error,
    double? progress,
  }) async {
    final index = queue.indexWhere((item) => item.track.id == id);
    if (index < 0) return;
    queue[index] = queue[index].copyWith(
      status: status,
      error: error,
      progress: progress,
    );
    await database.saveQueue(queue[index]);
    notifyListeners();
  }

  void cancelDownloads() {
    cancelled = true;
    downloader.cancel();
  }

  Future<void> importFolder() async {
    try {
      final folder = Platform.isAndroid
          ? await AndroidStorage.pickFolder()
          : await FilePicker.getDirectoryPath(
              dialogTitle: 'Choose music folder',
            );
      if (folder == null) return;
      if (!importedFolders.contains(folder)) {
        importedFolders = [...importedFolders, folder];
      }
      final label = Platform.isAndroid
          ? await AndroidStorage.folderName(folder)
          : folder;
      importedFolderLabels[folder] = label;
      await database.saveSetting('folders', importedFolders.join('\n'));
      await database.saveSetting('folderLabel:$folder', label);
      await scanFolder(folder);
    } catch (failure) {
      error = 'Could not import folder: $failure';
      notifyListeners();
    }
  }

  Future<void> importFiles() async {
    try {
      final selection = await FilePicker.pickFiles(
        type: FileType.audio,
        allowMultiple: true,
      );
      if (selection == null) return;
      final root = await getApplicationDocumentsDirectory();
      final folder = Directory(p.join(root.path, 'Imported'));
      await folder.create(recursive: true);
      for (final picked in selection.files) {
        if (picked.path == null) continue;
        final source = File(picked.path!);
        if (!await source.exists()) continue;
        final name = p
            .basename(picked.name)
            .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
        final extension = p.extension(name).toLowerCase();
        if (!{'.mp3', '.m4a', '.flac', '.ogg', '.wav'}.contains(extension)) {
          continue;
        }
        final stem = p.basenameWithoutExtension(name);
        var target = File(p.join(folder.path, name));
        var number = 2;
        while (await target.exists()) {
          target = File(p.join(folder.path, '$stem ($number)$extension'));
          number++;
        }
        await source.copy(target.path);
        final indexed = (await libraryService.readTrack(target))
            .copyWith(folder: folder.path, folderName: 'Imported');
        await database.saveLibrary(indexed);
        library = [...library, indexed];
      }
      notifyListeners();
    } catch (failure) {
      error = 'Could not import audio files: $failure';
      notifyListeners();
    }
  }

  Future<void> stopScanningFolder(String folder) async {
    importedFolders = importedFolders
        .where((entry) => entry != folder)
        .toList();
    await database.saveSetting('folders', importedFolders.join('\n'));
    importedFolderLabels.remove(folder);
    notifyListeners();
  }

  Future<void> scanFolder(String folder) async {
    try {
      if (Platform.isAndroid) {
        final indexed = await AndroidStorage.list(folder);
        for (final track in indexed) {
          final previous = library.where((entry) => entry.path == track.path);
          final merged = previous.isEmpty
              ? track
              : track.copyWith(
                  sourceTrackId: previous.first.sourceTrackId,
                  playlists: previous.first.playlists,
                  artwork: previous.first.artwork,
                );
          await database.saveLibrary(merged);
          library = [
            ...library.where((entry) => entry.path != track.path),
            merged,
          ];
        }
        notifyListeners();
        return;
      }
      await for (final entity in Directory(
        folder,
      ).list(recursive: true, followLinks: false)) {
        if (entity is! File ||
            !{
              '.mp3',
              '.m4a',
              '.flac',
              '.ogg',
              '.wav',
            }.contains(p.extension(entity.path).toLowerCase())) {
          continue;
        }
        if (library.any((entry) => entry.path == entity.path)) continue;
        final track = (await libraryService.readTrack(entity)).copyWith(
          folder: p.dirname(entity.path),
          folderName: p.basename(p.dirname(entity.path)),
        );
        library = [...library, track];
        await database.saveLibrary(track);
      }
      notifyListeners();
    } catch (failure) {
      error = failure.toString();
      notifyListeners();
    }
  }

  Future<void> editLibrary(LibraryTrack old, LibraryTrack edited) async {
    final resume = await player.suspendForEdit(old.path);
    var success = false;
    try {
      await downloader.editMetadata(edited);
      if (old.path != edited.path) await database.removeLibrary(old.path);
      await database.saveLibrary(edited);
      library = [...library.where((entry) => entry.path != old.path), edited];
      success = true;
      notifyListeners();
    } finally {
      await player.resumeAfterEdit(resume, success ? edited : old);
    }
  }

  List<PlaylistRef> get playlistFolders {
    final folders = <String, PlaylistRef>{};
    for (final track in library) {
      for (final playlist in track.playlists) {
        folders[playlist.id] = playlist;
      }
    }
    for (final item in queue) {
      for (final playlist in item.targetPlaylists) {
        folders[playlist.id] = playlist;
      }
    }
    return folders.values.toList()..sort((a, b) => a.title.compareTo(b.title));
  }

  Future<void> assignQueuedToPlaylist(
    String trackId,
    PlaylistRef playlist,
  ) async {
    final index = queue.indexWhere((item) => item.track.id == trackId);
    if (index < 0) return;
    final item = queue[index];
    queue[index] = item.copyWith(
      targetPlaylists: [
        ...item.targetPlaylists.where((entry) => entry.id != playlist.id),
        playlist,
      ],
    );
    await database.saveQueue(queue[index]);
    for (final saved
        in library.where((entry) => entry.sourceTrackId == trackId).toList()) {
      await assignToPlaylist(saved, playlist);
    }
    notifyListeners();
  }

  Future<void> assignToPlaylist(
    LibraryTrack track,
    PlaylistRef playlist,
  ) async {
    final updated = track.copyWith(
      playlists: [
        ...track.playlists.where((item) => item.id != playlist.id),
        playlist,
      ],
    );
    await database.saveLibrary(updated);
    library = [...library.where((item) => item.path != track.path), updated];
    notifyListeners();
  }

  Future<void> deleteSong(LibraryTrack track) async {
    final resume = await player.suspendForEdit(track.path);
    try {
      if (Platform.isAndroid && track.path.startsWith('content://')) {
        await AndroidStorage.delete(track.path);
      } else {
        final file = File(track.path);
        if (await file.exists()) await file.delete();
      }
    } catch (_) {
      await player.resumeAfterEdit(resume, track);
      rethrow;
    }
    await player.removeDeletedTrack(track.path);
    await database.removeLibrary(track.path);
    library = library.where((item) => item.path != track.path).toList();
    for (final item
        in queue
            .where(
              (item) =>
                  item.track.id == track.sourceTrackId && item.status == 'done',
            )
            .toList()) {
      await database.removeQueue(item.track.id);
      queue = queue.where((entry) => entry.track.id != item.track.id).toList();
    }
    notifyListeners();
  }

  Future<void> deletePlaylist(PlaylistRef playlist) async {
    final members = library
        .where((track) => track.playlists.any((item) => item.id == playlist.id))
        .toList();
    final failures = <String>[];
    for (final track in members) {
      try {
        await deleteSong(track);
      } catch (failure) {
        failures.add('${track.title}: $failure');
      }
    }
    if (failures.isNotEmpty) {
      throw StateError(
        'Could not delete ${failures.length} songs: ${failures.join('; ')}',
      );
    }
    for (var index = 0; index < queue.length; index++) {
      final item = queue[index];
      final updated = item.copyWith(
        targetPlaylists: item.targetPlaylists
            .where((entry) => entry.id != playlist.id)
            .toList(),
        batches: item.batches
            .map(
              (batch) => batch.playlist?.id == playlist.id
                  ? QueueBatchRef(id: batch.id, title: batch.title)
                  : batch,
            )
            .toList(),
      );
      queue[index] = updated;
      await database.saveQueue(updated);
    }
    notifyListeners();
  }

  Future<void> moveTrack(LibraryTrack track, String folder) async {
    if (Platform.isAndroid) {
      final name = track.path.startsWith('content://')
          ? await AndroidStorage.folderName(track.path)
          : p.basename(track.path);
      final moved = await AndroidStorage.move(track.path, folder, name);
      await database.removeLibrary(track.path);
      final edited = track.copyWith(
        path: moved.path,
        folder: moved.folder,
        folderName: moved.folderName,
      );
      await database.saveLibrary(edited);
      library = [...library.where((entry) => entry.path != track.path), edited];
      notifyListeners();
      return;
    }
    final source = File(track.path);
    if (!await source.exists()) {
      throw const FileSystemException('Track file is missing.');
    }
    final target = p.join(folder, p.basename(track.path));
    if (await File(target).exists()) {
      throw const FileSystemException('A file with this name already exists.');
    }
    await Directory(folder).create(recursive: true);
    File moved;
    try {
      moved = await source.rename(target);
    } on FileSystemException {
      moved = await source.copy(target);
      await source.delete();
    }
    await database.removeLibrary(track.path);
    final edited = track.copyWith(path: moved.path);
    await database.saveLibrary(edited);
    library = [...library.where((entry) => entry.path != track.path), edited];
    notifyListeners();
  }

  @override
  void dispose() {
    player.dispose();
    database.close();
    super.dispose();
  }
}
