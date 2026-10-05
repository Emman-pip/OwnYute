import 'dart:convert';

class Track {
  const Track({
    required this.id,
    required this.url,
    required this.title,
    this.artist = '',
    this.album = '',
    this.artwork = '',
    this.duration = 0,
    this.streamUrl = '',
  });

  final String id;
  final String url;
  final String title;
  final String artist;
  final String album;
  final String artwork;
  final int duration;
  final String streamUrl;

  Track copyWith({
    String? title,
    String? artist,
    String? album,
    String? artwork,
    int? duration,
    String? streamUrl,
  }) => Track(
    id: id,
    url: url,
    title: title ?? this.title,
    artist: artist ?? this.artist,
    album: album ?? this.album,
    artwork: artwork ?? this.artwork,
    duration: duration ?? this.duration,
    streamUrl: streamUrl ?? this.streamUrl,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'url': url,
    'title': title,
    'artist': artist,
    'album': album,
    'artwork': artwork,
    'duration': duration,
    'streamUrl': streamUrl,
  };
  factory Track.fromJson(Map<String, dynamic> json) => Track(
    id: json['id'] as String,
    url: json['url'] as String,
    title: json['title'] as String,
    artist: json['artist'] as String? ?? '',
    album: json['album'] as String? ?? '',
    artwork: json['artwork'] as String? ?? '',
    duration: json['duration'] as int? ?? 0,
    streamUrl: json['streamUrl'] as String? ?? '',
  );
}

class PlaylistRef {
  const PlaylistRef({required this.id, required this.title});
  final String id;
  final String title;

  Map<String, dynamic> toJson() => {'id': id, 'title': title};
  factory PlaylistRef.fromJson(Map<String, dynamic> json) =>
      PlaylistRef(id: json['id'] as String, title: json['title'] as String);
}

class QueueBatchRef {
  const QueueBatchRef({required this.id, required this.title, this.playlist});
  final String id;
  final String title;
  final PlaylistRef? playlist;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    if (playlist != null) 'playlist': playlist!.toJson(),
  };
  factory QueueBatchRef.fromJson(Map<String, dynamic> json) => QueueBatchRef(
    id: json['id'] as String,
    title: json['title'] as String,
    playlist: json['playlist'] is Map
        ? PlaylistRef.fromJson(
            Map<String, dynamic>.from(json['playlist'] as Map),
          )
        : null,
  );
}

class QueueItem {
  const QueueItem({
    required this.track,
    this.status = 'pending',
    this.error = '',
    this.progress = 0,
    this.inSingles = true,
    this.batches = const [],
    this.targetPlaylists = const [],
  });
  final Track track;
  final String status;
  final String error;
  final double progress;
  final bool inSingles;
  final List<QueueBatchRef> batches;
  final List<PlaylistRef> targetPlaylists;
  QueueItem copyWith({
    Track? track,
    String? status,
    String? error,
    double? progress,
    bool? inSingles,
    List<QueueBatchRef>? batches,
    List<PlaylistRef>? targetPlaylists,
  }) => QueueItem(
    track: track ?? this.track,
    status: status ?? this.status,
    error: error ?? this.error,
    progress: progress ?? this.progress,
    inSingles: inSingles ?? this.inSingles,
    batches: batches ?? this.batches,
    targetPlaylists: targetPlaylists ?? this.targetPlaylists,
  );
  Map<String, dynamic> toJson() => {
    'track': track.toJson(),
    'status': status,
    'error': error,
    'inSingles': inSingles,
    'batches': batches.map((batch) => batch.toJson()).toList(),
    'targetPlaylists': targetPlaylists.map((item) => item.toJson()).toList(),
  };
  factory QueueItem.fromJson(Map<String, dynamic> json) => QueueItem(
    track: Track.fromJson(json['track'] as Map<String, dynamic>),
    status: json['status'] as String? ?? 'pending',
    error: json['error'] as String? ?? '',
    inSingles: json['inSingles'] as bool? ?? true,
    batches:
        (json['batches'] as List?)
            ?.whereType<Map>()
            .map(
              (value) =>
                  QueueBatchRef.fromJson(Map<String, dynamic>.from(value)),
            )
            .toList() ??
        const [],
    targetPlaylists:
        (json['targetPlaylists'] as List?)
            ?.whereType<Map>()
            .map(
              (value) => PlaylistRef.fromJson(Map<String, dynamic>.from(value)),
            )
            .toList() ??
        const [],
  );
}

class LibraryTrack {
  const LibraryTrack({
    required this.path,
    required this.title,
    this.artist = '',
    this.album = '',
    this.artwork = '',
    this.duration = 0,
    this.folder = '',
    this.folderName = '',
    this.sourceTrackId = '',
    this.playlists = const [],
  });
  final String path;
  final String title;
  final String artist;
  final String album;
  final String artwork;
  final int duration;
  final String folder;
  final String folderName;
  final String sourceTrackId;
  final List<PlaylistRef> playlists;
  LibraryTrack copyWith({
    String? path,
    String? title,
    String? artist,
    String? album,
    String? artwork,
    int? duration,
    String? folder,
    String? folderName,
    String? sourceTrackId,
    List<PlaylistRef>? playlists,
  }) => LibraryTrack(
    path: path ?? this.path,
    title: title ?? this.title,
    artist: artist ?? this.artist,
    album: album ?? this.album,
    artwork: artwork ?? this.artwork,
    duration: duration ?? this.duration,
    folder: folder ?? this.folder,
    folderName: folderName ?? this.folderName,
    sourceTrackId: sourceTrackId ?? this.sourceTrackId,
    playlists: playlists ?? this.playlists,
  );
  Map<String, dynamic> toJson() => {
    'path': path,
    'title': title,
    'artist': artist,
    'album': album,
    'artwork': artwork,
    'duration': duration,
    'folder': folder,
    'folderName': folderName,
    'sourceTrackId': sourceTrackId,
    'playlists': playlists.map((playlist) => playlist.toJson()).toList(),
  };
  factory LibraryTrack.fromJson(Map<String, dynamic> json) => LibraryTrack(
    path: json['path'] as String,
    title: json['title'] as String,
    artist: json['artist'] as String? ?? '',
    album: json['album'] as String? ?? '',
    artwork: json['artwork'] as String? ?? '',
    duration: json['duration'] as int? ?? 0,
    folder: json['folder'] as String? ?? '',
    folderName: json['folderName'] as String? ?? '',
    sourceTrackId: json['sourceTrackId'] as String? ?? '',
    playlists:
        (json['playlists'] as List?)
            ?.whereType<Map>()
            .map(
              (value) => PlaylistRef.fromJson(Map<String, dynamic>.from(value)),
            )
            .toList() ??
        const [],
  );
}

String encodeJson(Object value) => jsonEncode(value);
Map<String, dynamic> decodeJson(String value) =>
    jsonDecode(value) as Map<String, dynamic>;
