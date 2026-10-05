import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/android_storage.dart';
import '../../core/app_controller.dart';
import '../../core/models.dart';
import '../../core/ui_helpers.dart';

/// Songs that also sit in a playlist folder, so deleting them is felt outside
/// the list the user picked. Named in delete confirmations.
List<LibraryTrack> playlistSharedSongs(Iterable<LibraryTrack> tracks) =>
    tracks.where((track) => track.playlists.isNotEmpty).toList();

String _sharedWarning(List<LibraryTrack> tracks) {
  final shared = playlistSharedSongs(tracks);
  if (shared.isEmpty) return '';
  final names = shared.map((track) => track.title).join(', ');
  return '\n\n${shared.length} ${shared.length == 1 ? 'song is' : 'songs are'} also in a playlist folder ($names) and will be removed there too.';
}

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

/// A delete of a whole storage folder, which can either forget the songs or
/// take the audio with them.
enum StorageFolderDelete { cancel, removeFromLibrary, deleteFiles }

Future<StorageFolderDelete> confirmDeleteStorageFolder(
  BuildContext context,
  AppController app,
  String folderPath,
) {
  final members = app.library
      .where((track) => AppController.folderOf(track) == folderPath)
      .toList();
  final shared = playlistSharedSongs(members);
  return showDialog<StorageFolderDelete>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete folder?'),
      content: Text(
        'Remove ${members.length} ${members.length == 1 ? 'song' : 'songs'} from the library?'
        '${shared.isEmpty ? '' : ' ${shared.length} ${shared.length == 1 ? 'song is' : 'songs are'} also in a playlist folder and will be removed there too.'}'
        '\n\n"Remove from library" keeps the audio on disk. "Delete files" removes it from this device as well.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, StorageFolderDelete.cancel),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.pop(context, StorageFolderDelete.removeFromLibrary),
          child: const Text('Remove from library'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: () =>
              Navigator.pop(context, StorageFolderDelete.deleteFiles),
          child: const Text('Delete files'),
        ),
      ],
    ),
  ).then((choice) => choice ?? StorageFolderDelete.cancel);
}

Future<void> deleteStorageFolder(
  BuildContext context,
  AppController app,
  String folderPath,
) async {
  final choice = await confirmDeleteStorageFolder(context, app, folderPath);
  if (choice == StorageFolderDelete.cancel) return;
  try {
    await app.deleteStorageFolder(
      folderPath,
      deleteFiles: choice == StorageFolderDelete.deleteFiles,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          choice == StorageFolderDelete.deleteFiles
              ? 'Folder deleted from storage and the library.'
              : 'Folder removed from the library. The audio is still on disk.',
        ),
      ),
    );
  } catch (failure) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failure.toString())));
    }
  }
}

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

Future<void> deleteLibraryTrack(
  BuildContext context,
  AppController app,
  LibraryTrack track,
) async {
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
}

/// Bulk delete for a multi-selection. The confirm names every song that also
/// lives in a playlist folder, because the delete reaches those folders too.
Future<void> deleteSelectedSongs(
  BuildContext context,
  AppController app,
  List<LibraryTrack> tracks,
) async {
  if (tracks.isEmpty) return;
  final detail =
      'Delete ${tracks.length} audio ${tracks.length == 1 ? 'file' : 'files'} from storage and remove ${tracks.length == 1 ? 'it' : 'them'} from the library and every playlist folder?${_sharedWarning(tracks)}';
  if (!await confirmDelete(
    context,
    'Delete ${tracks.length} ${tracks.length == 1 ? 'song' : 'songs'}?',
    detail,
  )) {
    return;
  }
  try {
    await app.deleteSongs(tracks);
  } catch (failure) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failure.toString())));
    }
  }
}

Future<void> refreshFolderArtwork(
  BuildContext context,
  AppController app,
  String folderPath,
) async {
  await app.lookupFolderArtwork(folderPath);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        app.artworkLookupUpdated == 0
            ? 'No new artwork found for this folder.'
            : 'Found artwork for ${app.artworkLookupUpdated} '
                  '${app.artworkLookupUpdated == 1 ? 'song' : 'songs'}.',
      ),
    ),
  );
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
  if (playlist == null) return;
  try {
    await app.assignToPlaylist(track, playlist);
    if (!context.mounted) return;
    showFeedback(context, 'Added ${track.title} to ${playlist.title}.');
  } catch (failure) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failure.toString())));
    }
  }
}

Future<void> editLibraryTrack(
  BuildContext context,
  AppController app,
  LibraryTrack track,
) async {
  try {
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
  } catch (failure) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failure.toString())));
    }
  }
}

Future<void> moveLibraryTrack(
  BuildContext context,
  AppController app,
  LibraryTrack track,
) async {
  try {
    final chosen = Platform.isAndroid
        ? await AndroidStorage.pickFolder()
        : await FilePicker.getDirectoryPath(
            dialogTitle: 'Move track to folder',
          );
    if (chosen == null || chosen.isEmpty) return;
    await app.moveTrack(track, chosen);
  } catch (failure) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failure.toString())));
    }
  }
}
