import 'package:drift/drift.dart';

import 'models.dart';

part 'database.g.dart';

class QueueRows extends Table {
  TextColumn get id => text()();
  TextColumn get data => text()();
  @override
  Set<Column> get primaryKey => {id};
}

class LibraryRows extends Table {
  TextColumn get path => text()();
  TextColumn get data => text()();
  @override
  Set<Column> get primaryKey => {path};
}

class HistoryRows extends Table {
  TextColumn get id => text()();
  TextColumn get data => text()();
  DateTimeColumn get savedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}

class PlayHistoryRows extends Table {
  TextColumn get id => text()();
  TextColumn get data => text()();
  DateTimeColumn get savedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}

class SettingsRows extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(
  tables: [QueueRows, LibraryRows, HistoryRows, PlayHistoryRows, SettingsRows],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);
  AppDatabase.forTesting(super.executor);
  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.createTable(playHistoryRows);
      }
    },
  );

  Future<List<QueueItem>> loadQueue() async => (await select(queueRows).get())
      .map((row) => QueueItem.fromJson(decodeJson(row.data)))
      .map(
        (item) => item.status == 'downloading'
            ? item.copyWith(
                status: 'failed',
                error: 'Interrupted. Retry to continue.',
              )
            : item,
      )
      .toList();
  Future<void> saveQueue(QueueItem item) => into(queueRows)
      .insertOnConflictUpdate(
        QueueRowsCompanion.insert(
          id: item.track.id,
          data: encodeJson(item.toJson()),
        ),
      );
  Future<void> removeQueue(String id) =>
      (delete(queueRows)..where((row) => row.id.equals(id))).go();
  Future<List<LibraryTrack>> loadLibrary() async => (await select(
    libraryRows,
  ).get()).map((row) => LibraryTrack.fromJson(decodeJson(row.data))).toList();
  Future<void> saveLibrary(LibraryTrack item) => into(libraryRows)
      .insertOnConflictUpdate(
        LibraryRowsCompanion.insert(
          path: item.path,
          data: encodeJson(item.toJson()),
        ),
      );
  Future<void> removeLibrary(String path) =>
      (delete(libraryRows)..where((row) => row.path.equals(path))).go();
  Future<void> saveHistory(Track track) =>
      into(historyRows).insertOnConflictUpdate(
        HistoryRowsCompanion.insert(
          id: track.id,
          data: encodeJson(track.toJson()),
          savedAt: DateTime.now(),
        ),
      );
  Future<List<Track>> loadHistory() async =>
      (await (select(
            historyRows,
          )..orderBy([(row) => OrderingTerm.desc(row.savedAt)])).get())
          .map((row) => Track.fromJson(decodeJson(row.data)))
          .toList();
  Future<void> savePlayHistory(Track track) =>
      into(playHistoryRows).insertOnConflictUpdate(
        PlayHistoryRowsCompanion.insert(
          id: track.id,
          data: encodeJson(track.toJson()),
          savedAt: DateTime.now(),
        ),
      );
  Future<List<Track>> loadPlayHistory() async =>
      (await (select(
            playHistoryRows,
          )..orderBy([(row) => OrderingTerm.desc(row.savedAt)])).get())
          .map((row) => Track.fromJson(decodeJson(row.data)))
          .toList();
  Future<String?> setting(String key) async => (await (select(
    settingsRows,
  )..where((row) => row.key.equals(key))).getSingleOrNull())?.value;
  Future<void> saveSetting(String key, String value) => into(settingsRows)
      .insertOnConflictUpdate(
        SettingsRowsCompanion.insert(key: key, value: value),
      );
}
