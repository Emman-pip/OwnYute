import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/android_storage.dart';
import '../../core/app_controller.dart';
import '../../core/models.dart';
import '../../core/ui_helpers.dart';

Future<bool> confirmDelete(
  BuildContext context,
  String title,
  String detail,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(detail),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ??
    false;

Future<void> deletePlaylistFolder(
  BuildContext context,
  AppController app,
  PlaylistRef folder,
) async {
  final members = app.library
      .where((track) => track.playlists.any((item) => item.id == folder.id))
      .toList();
  final shared = members.where((track) => track.playlists.length > 1).length;
  final detail =
      'Delete ${members.length} audio ${members.length == 1 ? 'file' : 'files'} from storage and remove this playlist from the app?'
      '${shared == 0 ? '' : ' $shared ${shared == 1 ? 'song also appears' : 'songs also appear'} in other playlists and will be removed there too.'}';
  if (!await confirmDelete(context, 'Delete ${folder.title}?', detail)) {
    return;
  }
  try {
    await app.deletePlaylist(folder);
  } catch (failure) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failure.toString())));
    }
  }
}

Future<PlaylistRef?> choosePlaylist(
  BuildContext context,
  AppController app,
) async {
  final folders = app.playlistFolders;
  final choice = await showDialog<PlaylistRef?>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('Add to playlist folder'),
      children: [
        for (final folder in folders)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, folder),
            child: Text(folder.title),
          ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(
            context,
            const PlaylistRef(id: 'new', title: 'New playlist folder'),
          ),
          child: const Text('Create new folder…'),
        ),
      ],
    ),
  );
  if (choice == null || !context.mounted) return null;
  var playlist = choice;
  if (choice.id == 'new') {
    final name = (await textDialog(
      context,
      'New playlist folder',
      'Folder name',
    ))?.trim();
    if (name == null || name.isEmpty) return null;
    playlist = PlaylistRef(
      id: 'local:${DateTime.now().microsecondsSinceEpoch}',
      title: name,
    );
  }
  return playlist;
}

Future<void> assignTrackToPlaylist(
  BuildContext context,
  AppController app,
  LibraryTrack track,
) async {
  final playlist = await choosePlaylist(context, app);
  if (playlist != null) await app.assignToPlaylist(track, playlist);
}

Future<void> libraryTrackAction(
  BuildContext context,
  AppController app,
  LibraryTrack track,
  String action,
) async {
  if (action == 'delete') {
    if (!await confirmDelete(
      context,
      'Delete ${track.title}?',
      'Delete this audio file from storage and remove it from the library and all playlist folders?',
    )) {
      return;
    }
    try {
      await app.deleteSong(track);
    } catch (failure) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(failure.toString())));
      }
    }
    return;
  }
  if (action == 'playlist') {
    await assignTrackToPlaylist(context, app, track);
    return;
  }
  try {
    if (action == 'edit') {
      final edited = await editTrackDialog(
        context,
        Track(
          id: track.path,
          url: track.path,
          title: track.title,
          artist: track.artist,
          album: track.album,
          artwork: track.artwork,
        ),
        pickArtwork: app.pickArtwork,
      );
      if (edited == null) return;
      await app.editLibrary(
        track,
        track.copyWith(
          title: edited.title,
          artist: edited.artist,
          album: edited.album,
          artwork: edited.artwork,
        ),
      );
    } else if (action == 'move') {
      final chosen = Platform.isAndroid
          ? await AndroidStorage.pickFolder()
          : await FilePicker.getDirectoryPath(
              dialogTitle: 'Move track to folder',
            );
      if (chosen == null || chosen.isEmpty) return;
      await app.moveTrack(track, chosen);
    }
  } catch (failure) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failure.toString())));
    }
  }
}
