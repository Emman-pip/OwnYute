import 'dart:io';

import 'package:drift/native.dart';
import 'package:own_yute/core/database.dart';
import 'package:own_yute/core/models.dart';

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Future<void> main() async {
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  try {
    const track = Track(
      id: 'track-1',
      url: 'https://youtu.be/track-1',
      title: 'Example',
    );
    await database.saveQueue(
      const QueueItem(track: track, status: 'downloading'),
    );
    final restored = await database.loadQueue();
    check(
      restored.single.status == 'failed',
      'Interrupted queue item was not made retryable',
    );
    await database.saveQueue(
      restored.single.copyWith(track: track.copyWith(title: 'Edited')),
    );
    check(
      (await database.loadQueue()).single.track.title == 'Edited',
      'Queue edit did not persist',
    );
    await database.saveLibrary(
      const LibraryTrack(path: '/music/Example.mp3', title: 'Example'),
    );
    check(
      (await database.loadLibrary()).single.path == '/music/Example.mp3',
      'Library row did not persist',
    );
    await database.saveHistory(track);
    check(
      (await database.loadHistory()).single.id == track.id,
      'History row did not persist',
    );
    await database.saveSetting('destination', '/music');
    check(
      await database.setting('destination') == '/music',
      'Setting did not persist',
    );
    stdout.writeln('Database checks passed.');
  } finally {
    await database.close();
  }
}
