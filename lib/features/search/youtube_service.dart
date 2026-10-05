import 'dart:convert';
import 'dart:io';

import '../../core/models.dart';
import '../../core/android_tools.dart';
import '../../core/yt_dlp_manager.dart';

class YoutubeFailure implements Exception {
  const YoutubeFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class SearchResults {
  const SearchResults({
    required this.songs,
    required this.playlists,
    this.songsTotal = 0,
    this.playlistsTotal = 0,
  });
  final List<Track> songs;
  final List<Track> playlists;
  final int songsTotal;
  final int playlistsTotal;
}

typedef CommandRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments,
);

class YoutubeService {
  static const int fullSongWindow = 50;

  YoutubeService({CommandRunner? run, YtDlpManager? tools})
    : _run = run ?? _platformRun,
      _tools = tools ?? (run == null ? YtDlpManager.shared : null);
  final CommandRunner _run;
  final YtDlpManager? _tools;
  PlaylistRef? lastPlaylist;

  Future<ProcessResult> _runYtDlp(List<String> args) async {
    final executable = await _tools?.executable() ?? 'yt-dlp';
    return _run(executable, args);
  }

  static Future<ProcessResult> _platformRun(
    String executable,
    List<String> args,
  ) => Platform.isAndroid
      ? AndroidTools.run(executable, args)
      : Process.run(executable, args);

  Future<Map<String, dynamic>> _json(List<String> args) async {
    if (!Platform.isLinux && !Platform.isAndroid) {
      throw const YoutubeFailure(
        'YouTube tools are unavailable on this device.',
      );
    }
    ProcessResult result;
    try {
      result = await _runYtDlp([
        '--ignore-config',
        '--no-warnings',
        '--dump-single-json',
        ...args,
      ]);
    } on ProcessException catch (failure) {
      throw YoutubeFailure(
        Platform.isAndroid
            ? 'Android yt-dlp failed: ${failure.message}'
            : 'yt-dlp could not start: ${failure.message}. Check Settings or install yt-dlp.',
      );
    }
    if (result.exitCode != 0) {
      final message = (result.stderr as String).trim();
      throw YoutubeFailure(
        message.isEmpty ? 'YouTube could not load this item.' : message,
      );
    }
    try {
      return jsonDecode(result.stdout as String) as Map<String, dynamic>;
    } on FormatException {
      throw const YoutubeFailure('YouTube returned an unreadable result.');
    }
  }

  bool isYoutubeUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !{'https', 'http'}.contains(uri.scheme)) return false;
    final host = uri.host.toLowerCase();
    return host == 'youtube.com' ||
        host.endsWith('.youtube.com') ||
        host == 'youtu.be';
  }

  /// Fetches one page of results. [songs] and [playlists] are the batch
  /// sizes; pass 0 for a "full" fetch (large song window, unlimited
  /// playlists).
  Future<SearchResults> search(
    String query, {
    int songs = 5,
    int playlists = 5,
  }) async {
    final term = query.trim();
    if (term.isEmpty) {
      return const SearchResults(songs: [], playlists: []);
    }
    final results = await Future.wait([
      _json([
        '--flat-playlist',
        'ytsearch${songs == 0 ? fullSongWindow : songs}:$term',
      ]),
      _json([
        '--flat-playlist',
        if (playlists > 0) '--playlist-end',
        if (playlists > 0) '$playlists',
        Uri.https('www.youtube.com', '/results', {
          'search_query': term,
          'sp': 'EgIQAw==',
        }).toString(),
      ]).onError((_, _) => <String, dynamic>{}),
    ]);
    final allSongs = _entries(results[0])
        .where((track) => track.id.isNotEmpty)
        .toList();
    final playlistResults = _entries(results[1])
        .where((track) => track.url.contains('list='))
        .toList();
    return SearchResults(
      songs: allSongs,
      playlists: playlistResults,
      songsTotal: allSongs.length,
      playlistsTotal: playlistResults.length,
    );
  }

  Future<(Track?, List<Track>)> openUrl(String value) async {
    lastPlaylist = null;
    if (!isYoutubeUrl(value)) {
      throw const YoutubeFailure('Paste a valid YouTube song or playlist URL.');
    }
    final uri = Uri.parse(value.trim());
    final listId = uri.queryParameters['list'];
    final radioWatch =
        uri.path == '/watch' &&
        (uri.queryParameters['start_radio'] == '1' ||
            (listId?.startsWith('RD') ?? false));
    final playlist = listId != null && !radioWatch;
    if (playlist) {
      final json = await _json([
        '--flat-playlist',
        '--yes-playlist',
        value.trim(),
      ]);
      final tracks = _entries(json);
      if (tracks.isEmpty) {
        throw const YoutubeFailure('This playlist has no available tracks.');
      }
      lastPlaylist = PlaylistRef(
        id: (json['id'] ?? listId).toString(),
        title: (json['title'] ?? 'Playlist $listId').toString(),
      );
      return (null, tracks);
    }
    final json = await _json(['--no-playlist', value.trim()]);
    return (_track(json), <Track>[]);
  }

  Future<Track> details(Track track) async =>
      _track(await _json(['--no-playlist', track.url]));

  /// Finds a conservative artwork match without affecting normal search state.
  Future<Track?> findArtwork({
    required String title,
    String artist = '',
    String sourceTrackId = '',
  }) async {
    if (sourceTrackId.isNotEmpty) {
      try {
        final direct = await details(
          Track(
            id: sourceTrackId,
            url: 'https://www.youtube.com/watch?v=$sourceTrackId',
            title: title,
            artist: artist,
          ),
        );
        if (direct.artwork.isNotEmpty) return direct;
      } catch (_) {}
    }
    final query = [
      artist,
      title,
    ].where((value) => value.trim().isNotEmpty).join(' ');
    if (query.isEmpty) return null;
    final json = await _json(['--flat-playlist', 'ytsearch5:$query']);
    for (final candidate in _entries(json)) {
      if (candidate.artwork.isNotEmpty &&
          _artworkMatch(title, artist, candidate)) {
        return candidate;
      }
    }
    return null;
  }

  static bool _artworkMatch(String title, String artist, Track candidate) {
    final wantedTitle = _normalized(title);
    final foundTitle = _normalized(candidate.title);
    if (wantedTitle.isEmpty || foundTitle.isEmpty) return false;
    final titleMatches =
        wantedTitle == foundTitle ||
        (wantedTitle.length >= 8 &&
            (foundTitle.contains(wantedTitle) ||
                wantedTitle.contains(foundTitle)));
    if (!titleMatches) return false;
    final wantedArtist = _normalized(artist);
    if (wantedArtist.isEmpty) return true;
    final foundArtist = _normalized(candidate.artist);
    return foundArtist == wantedArtist ||
        foundArtist.contains(wantedArtist) ||
        wantedArtist.contains(foundArtist);
  }

  static String _normalized(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'\([^)]*(official|video|audio|lyrics?)[^)]*\)'), ' ')
      .replaceAll(
        RegExp(r'\[[^\]]*(official|video|audio|lyrics?)[^\]]*\]'),
        ' ',
      )
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();

  Future<String> streamUrl(Track track) async {
    if (!Platform.isLinux && !Platform.isAndroid) {
      throw const YoutubeFailure('Streaming is unavailable on this device.');
    }
    ProcessResult result;
    try {
      result = await _runYtDlp([
        '--ignore-config',
        '--no-warnings',
        '-g',
        '-f',
        'bestaudio',
        track.url,
      ]);
    } on ProcessException catch (failure) {
      throw YoutubeFailure('Could not prepare preview: ${failure.message}');
    }
    if (result.exitCode != 0) {
      final message = (result.stderr as String).trim();
      throw YoutubeFailure(
        message.isEmpty ? 'Could not prepare preview.' : message,
      );
    }
    final url = (result.stdout as String).trim().split('\n').first;
    if (url.isEmpty) {
      throw const YoutubeFailure('No playable audio is available.');
    }
    return url;
  }

  List<Track> _entries(Map<String, dynamic> json) {
    final raw = json['entries'];
    if (raw is! List) return [];
    return raw.whereType<Map<String, dynamic>>().map(_track).toList();
  }

  Track _track(Map<String, dynamic> json) {
    final id = (json['id'] ?? '').toString();
    final kind = (json['_type'] ?? json['ie_key'] ?? '')
        .toString()
        .toLowerCase();
    final isPlaylist =
        kind.contains('playlist') ||
        json['url']?.toString().contains('list=') == true;
    final rawUrl = (json['webpage_url'] ?? json['url'] ?? '').toString();
    final url = rawUrl.startsWith('http')
        ? rawUrl
        : isPlaylist
        ? 'https://www.youtube.com/playlist?list=$id'
        : 'https://www.youtube.com/watch?v=$id';
    return Track(
      id: id,
      url: url,
      title: (json['title'] ?? 'Untitled').toString(),
      artist: (json['artist'] ?? json['uploader'] ?? json['channel'] ?? '')
          .toString(),
      album: (json['album'] ?? '').toString(),
      artwork: (json['thumbnail'] ?? '').toString(),
      duration: (json['duration'] as num?)?.toInt() ?? 0,
    );
  }
}
