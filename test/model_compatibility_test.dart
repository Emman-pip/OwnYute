import 'package:flutter_test/flutter_test.dart';
import 'package:own_yute/core/models.dart';

void main() {
  test('older queue and library records remain usable', () {
    final queue = QueueItem.fromJson({
      'track': const Track(id: 'one', url: 'url', title: 'One').toJson(),
      'status': 'pending',
    });
    expect(queue.inSingles, true);
    expect(queue.batches, isEmpty);
    final library = LibraryTrack.fromJson({
      'path': '/tmp/one.mp3',
      'title': 'One',
    });
    expect(library.playlists, isEmpty);
    expect(library.sourceTrackId, isEmpty);
    final assigned = queue.copyWith(
      targetPlaylists: const [PlaylistRef(id: 'custom', title: 'Custom')],
    );
    expect(
      QueueItem.fromJson(assigned.toJson()).targetPlaylists.single.title,
      'Custom',
    );
  });
}
