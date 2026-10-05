// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $QueueRowsTable extends QueueRows
    with TableInfo<$QueueRowsTable, QueueRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QueueRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, data];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'queue_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<QueueRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  QueueRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QueueRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data'],
      )!,
    );
  }

  @override
  $QueueRowsTable createAlias(String alias) {
    return $QueueRowsTable(attachedDatabase, alias);
  }
}

class QueueRow extends DataClass implements Insertable<QueueRow> {
  final String id;
  final String data;
  const QueueRow({required this.id, required this.data});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['data'] = Variable<String>(data);
    return map;
  }

  QueueRowsCompanion toCompanion(bool nullToAbsent) {
    return QueueRowsCompanion(id: Value(id), data: Value(data));
  }

  factory QueueRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return QueueRow(
      id: serializer.fromJson<String>(json['id']),
      data: serializer.fromJson<String>(json['data']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'data': serializer.toJson<String>(data),
    };
  }

  QueueRow copyWith({String? id, String? data}) =>
      QueueRow(id: id ?? this.id, data: data ?? this.data);
  QueueRow copyWithCompanion(QueueRowsCompanion data) {
    return QueueRow(
      id: data.id.present ? data.id.value : this.id,
      data: data.data.present ? data.data.value : this.data,
    );
  }

  @override
  String toString() {
    return (StringBuffer('QueueRow(')
          ..write('id: $id, ')
          ..write('data: $data')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, data);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QueueRow && other.id == this.id && other.data == this.data);
}

class QueueRowsCompanion extends UpdateCompanion<QueueRow> {
  final Value<String> id;
  final Value<String> data;
  final Value<int> rowid;
  const QueueRowsCompanion({
    this.id = const Value.absent(),
    this.data = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  QueueRowsCompanion.insert({
    required String id,
    required String data,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       data = Value(data);
  static Insertable<QueueRow> custom({
    Expression<String>? id,
    Expression<String>? data,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (data != null) 'data': data,
      if (rowid != null) 'rowid': rowid,
    });
  }

  QueueRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? data,
    Value<int>? rowid,
  }) {
    return QueueRowsCompanion(
      id: id ?? this.id,
      data: data ?? this.data,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QueueRowsCompanion(')
          ..write('id: $id, ')
          ..write('data: $data, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LibraryRowsTable extends LibraryRows
    with TableInfo<$LibraryRowsTable, LibraryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LibraryRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [path, data];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'library_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<LibraryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {path};
  @override
  LibraryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LibraryRow(
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data'],
      )!,
    );
  }

  @override
  $LibraryRowsTable createAlias(String alias) {
    return $LibraryRowsTable(attachedDatabase, alias);
  }
}

class LibraryRow extends DataClass implements Insertable<LibraryRow> {
  final String path;
  final String data;
  const LibraryRow({required this.path, required this.data});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['path'] = Variable<String>(path);
    map['data'] = Variable<String>(data);
    return map;
  }

  LibraryRowsCompanion toCompanion(bool nullToAbsent) {
    return LibraryRowsCompanion(path: Value(path), data: Value(data));
  }

  factory LibraryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LibraryRow(
      path: serializer.fromJson<String>(json['path']),
      data: serializer.fromJson<String>(json['data']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'path': serializer.toJson<String>(path),
      'data': serializer.toJson<String>(data),
    };
  }

  LibraryRow copyWith({String? path, String? data}) =>
      LibraryRow(path: path ?? this.path, data: data ?? this.data);
  LibraryRow copyWithCompanion(LibraryRowsCompanion data) {
    return LibraryRow(
      path: data.path.present ? data.path.value : this.path,
      data: data.data.present ? data.data.value : this.data,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LibraryRow(')
          ..write('path: $path, ')
          ..write('data: $data')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(path, data);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LibraryRow &&
          other.path == this.path &&
          other.data == this.data);
}

class LibraryRowsCompanion extends UpdateCompanion<LibraryRow> {
  final Value<String> path;
  final Value<String> data;
  final Value<int> rowid;
  const LibraryRowsCompanion({
    this.path = const Value.absent(),
    this.data = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LibraryRowsCompanion.insert({
    required String path,
    required String data,
    this.rowid = const Value.absent(),
  }) : path = Value(path),
       data = Value(data);
  static Insertable<LibraryRow> custom({
    Expression<String>? path,
    Expression<String>? data,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (path != null) 'path': path,
      if (data != null) 'data': data,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LibraryRowsCompanion copyWith({
    Value<String>? path,
    Value<String>? data,
    Value<int>? rowid,
  }) {
    return LibraryRowsCompanion(
      path: path ?? this.path,
      data: data ?? this.data,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LibraryRowsCompanion(')
          ..write('path: $path, ')
          ..write('data: $data, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HistoryRowsTable extends HistoryRows
    with TableInfo<$HistoryRowsTable, HistoryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HistoryRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _savedAtMeta = const VerificationMeta(
    'savedAt',
  );
  @override
  late final GeneratedColumn<DateTime> savedAt = GeneratedColumn<DateTime>(
    'saved_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, data, savedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'history_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<HistoryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    if (data.containsKey('saved_at')) {
      context.handle(
        _savedAtMeta,
        savedAt.isAcceptableOrUnknown(data['saved_at']!, _savedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_savedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HistoryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HistoryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data'],
      )!,
      savedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}saved_at'],
      )!,
    );
  }

  @override
  $HistoryRowsTable createAlias(String alias) {
    return $HistoryRowsTable(attachedDatabase, alias);
  }
}

class HistoryRow extends DataClass implements Insertable<HistoryRow> {
  final String id;
  final String data;
  final DateTime savedAt;
  const HistoryRow({
    required this.id,
    required this.data,
    required this.savedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['data'] = Variable<String>(data);
    map['saved_at'] = Variable<DateTime>(savedAt);
    return map;
  }

  HistoryRowsCompanion toCompanion(bool nullToAbsent) {
    return HistoryRowsCompanion(
      id: Value(id),
      data: Value(data),
      savedAt: Value(savedAt),
    );
  }

  factory HistoryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HistoryRow(
      id: serializer.fromJson<String>(json['id']),
      data: serializer.fromJson<String>(json['data']),
      savedAt: serializer.fromJson<DateTime>(json['savedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'data': serializer.toJson<String>(data),
      'savedAt': serializer.toJson<DateTime>(savedAt),
    };
  }

  HistoryRow copyWith({String? id, String? data, DateTime? savedAt}) =>
      HistoryRow(
        id: id ?? this.id,
        data: data ?? this.data,
        savedAt: savedAt ?? this.savedAt,
      );
  HistoryRow copyWithCompanion(HistoryRowsCompanion data) {
    return HistoryRow(
      id: data.id.present ? data.id.value : this.id,
      data: data.data.present ? data.data.value : this.data,
      savedAt: data.savedAt.present ? data.savedAt.value : this.savedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HistoryRow(')
          ..write('id: $id, ')
          ..write('data: $data, ')
          ..write('savedAt: $savedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, data, savedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HistoryRow &&
          other.id == this.id &&
          other.data == this.data &&
          other.savedAt == this.savedAt);
}

class HistoryRowsCompanion extends UpdateCompanion<HistoryRow> {
  final Value<String> id;
  final Value<String> data;
  final Value<DateTime> savedAt;
  final Value<int> rowid;
  const HistoryRowsCompanion({
    this.id = const Value.absent(),
    this.data = const Value.absent(),
    this.savedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HistoryRowsCompanion.insert({
    required String id,
    required String data,
    required DateTime savedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       data = Value(data),
       savedAt = Value(savedAt);
  static Insertable<HistoryRow> custom({
    Expression<String>? id,
    Expression<String>? data,
    Expression<DateTime>? savedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (data != null) 'data': data,
      if (savedAt != null) 'saved_at': savedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HistoryRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? data,
    Value<DateTime>? savedAt,
    Value<int>? rowid,
  }) {
    return HistoryRowsCompanion(
      id: id ?? this.id,
      data: data ?? this.data,
      savedAt: savedAt ?? this.savedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (savedAt.present) {
      map['saved_at'] = Variable<DateTime>(savedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HistoryRowsCompanion(')
          ..write('id: $id, ')
          ..write('data: $data, ')
          ..write('savedAt: $savedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlayHistoryRowsTable extends PlayHistoryRows
    with TableInfo<$PlayHistoryRowsTable, PlayHistoryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlayHistoryRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _savedAtMeta = const VerificationMeta(
    'savedAt',
  );
  @override
  late final GeneratedColumn<DateTime> savedAt = GeneratedColumn<DateTime>(
    'saved_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, data, savedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'play_history_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlayHistoryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    if (data.containsKey('saved_at')) {
      context.handle(
        _savedAtMeta,
        savedAt.isAcceptableOrUnknown(data['saved_at']!, _savedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_savedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlayHistoryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlayHistoryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data'],
      )!,
      savedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}saved_at'],
      )!,
    );
  }

  @override
  $PlayHistoryRowsTable createAlias(String alias) {
    return $PlayHistoryRowsTable(attachedDatabase, alias);
  }
}

class PlayHistoryRow extends DataClass implements Insertable<PlayHistoryRow> {
  final String id;
  final String data;
  final DateTime savedAt;
  const PlayHistoryRow({
    required this.id,
    required this.data,
    required this.savedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['data'] = Variable<String>(data);
    map['saved_at'] = Variable<DateTime>(savedAt);
    return map;
  }

  PlayHistoryRowsCompanion toCompanion(bool nullToAbsent) {
    return PlayHistoryRowsCompanion(
      id: Value(id),
      data: Value(data),
      savedAt: Value(savedAt),
    );
  }

  factory PlayHistoryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlayHistoryRow(
      id: serializer.fromJson<String>(json['id']),
      data: serializer.fromJson<String>(json['data']),
      savedAt: serializer.fromJson<DateTime>(json['savedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'data': serializer.toJson<String>(data),
      'savedAt': serializer.toJson<DateTime>(savedAt),
    };
  }

  PlayHistoryRow copyWith({String? id, String? data, DateTime? savedAt}) =>
      PlayHistoryRow(
        id: id ?? this.id,
        data: data ?? this.data,
        savedAt: savedAt ?? this.savedAt,
      );
  PlayHistoryRow copyWithCompanion(PlayHistoryRowsCompanion data) {
    return PlayHistoryRow(
      id: data.id.present ? data.id.value : this.id,
      data: data.data.present ? data.data.value : this.data,
      savedAt: data.savedAt.present ? data.savedAt.value : this.savedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlayHistoryRow(')
          ..write('id: $id, ')
          ..write('data: $data, ')
          ..write('savedAt: $savedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, data, savedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlayHistoryRow &&
          other.id == this.id &&
          other.data == this.data &&
          other.savedAt == this.savedAt);
}

class PlayHistoryRowsCompanion extends UpdateCompanion<PlayHistoryRow> {
  final Value<String> id;
  final Value<String> data;
  final Value<DateTime> savedAt;
  final Value<int> rowid;
  const PlayHistoryRowsCompanion({
    this.id = const Value.absent(),
    this.data = const Value.absent(),
    this.savedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlayHistoryRowsCompanion.insert({
    required String id,
    required String data,
    required DateTime savedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       data = Value(data),
       savedAt = Value(savedAt);
  static Insertable<PlayHistoryRow> custom({
    Expression<String>? id,
    Expression<String>? data,
    Expression<DateTime>? savedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (data != null) 'data': data,
      if (savedAt != null) 'saved_at': savedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlayHistoryRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? data,
    Value<DateTime>? savedAt,
    Value<int>? rowid,
  }) {
    return PlayHistoryRowsCompanion(
      id: id ?? this.id,
      data: data ?? this.data,
      savedAt: savedAt ?? this.savedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (savedAt.present) {
      map['saved_at'] = Variable<DateTime>(savedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlayHistoryRowsCompanion(')
          ..write('id: $id, ')
          ..write('data: $data, ')
          ..write('savedAt: $savedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SettingsRowsTable extends SettingsRows
    with TableInfo<$SettingsRowsTable, SettingsRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingsRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SettingsRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingsRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SettingsRowsTable createAlias(String alias) {
    return $SettingsRowsTable(attachedDatabase, alias);
  }
}

class SettingsRow extends DataClass implements Insertable<SettingsRow> {
  final String key;
  final String value;
  const SettingsRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsRowsCompanion toCompanion(bool nullToAbsent) {
    return SettingsRowsCompanion(key: Value(key), value: Value(value));
  }

  factory SettingsRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingsRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SettingsRow copyWith({String? key, String? value}) =>
      SettingsRow(key: key ?? this.key, value: value ?? this.value);
  SettingsRow copyWithCompanion(SettingsRowsCompanion data) {
    return SettingsRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingsRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingsRow &&
          other.key == this.key &&
          other.value == this.value);
}

class SettingsRowsCompanion extends UpdateCompanion<SettingsRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsRowsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsRowsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SettingsRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsRowsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingsRowsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsRowsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $QueueRowsTable queueRows = $QueueRowsTable(this);
  late final $LibraryRowsTable libraryRows = $LibraryRowsTable(this);
  late final $HistoryRowsTable historyRows = $HistoryRowsTable(this);
  late final $PlayHistoryRowsTable playHistoryRows = $PlayHistoryRowsTable(
    this,
  );
  late final $SettingsRowsTable settingsRows = $SettingsRowsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    queueRows,
    libraryRows,
    historyRows,
    playHistoryRows,
    settingsRows,
  ];
}

typedef $$QueueRowsTableCreateCompanionBuilder = QueueRowsCompanion Function({
  required String id,
  required String data,
  Value<int> rowid,
});
typedef $$QueueRowsTableUpdateCompanionBuilder = QueueRowsCompanion Function({
  Value<String> id,
  Value<String> data,
  Value<int> rowid,
});

class $$QueueRowsTableFilterComposer
    extends Composer<_$AppDatabase, $QueueRowsTable> {
  $$QueueRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );
}

class $$QueueRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $QueueRowsTable> {
  $$QueueRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$QueueRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $QueueRowsTable> {
  $$QueueRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);
}

class $$QueueRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $QueueRowsTable,
          QueueRow,
          $$QueueRowsTableFilterComposer,
          $$QueueRowsTableOrderingComposer,
          $$QueueRowsTableAnnotationComposer,
          $$QueueRowsTableCreateCompanionBuilder,
          $$QueueRowsTableUpdateCompanionBuilder,
          (QueueRow, BaseReferences<_$AppDatabase, $QueueRowsTable, QueueRow>),
          QueueRow,
          PrefetchHooks Function()
        > {
  $$QueueRowsTableTableManager(_$AppDatabase db, $QueueRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QueueRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QueueRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QueueRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> data = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => QueueRowsCompanion(id: id, data: data, rowid: rowid),
          createCompanionCallback: ({
            required String id,
            required String data,
            Value<int> rowid = const Value.absent(),
          }) => QueueRowsCompanion.insert(id: id, data: data, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$QueueRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $QueueRowsTable,
      QueueRow,
      $$QueueRowsTableFilterComposer,
      $$QueueRowsTableOrderingComposer,
      $$QueueRowsTableAnnotationComposer,
      $$QueueRowsTableCreateCompanionBuilder,
      $$QueueRowsTableUpdateCompanionBuilder,
      (QueueRow, BaseReferences<_$AppDatabase, $QueueRowsTable, QueueRow>),
      QueueRow,
      PrefetchHooks Function()
    >;
typedef $$LibraryRowsTableCreateCompanionBuilder =
    LibraryRowsCompanion Function({
      required String path,
      required String data,
      Value<int> rowid,
    });
typedef $$LibraryRowsTableUpdateCompanionBuilder =
    LibraryRowsCompanion Function({
      Value<String> path,
      Value<String> data,
      Value<int> rowid,
    });

class $$LibraryRowsTableFilterComposer
    extends Composer<_$AppDatabase, $LibraryRowsTable> {
  $$LibraryRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LibraryRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $LibraryRowsTable> {
  $$LibraryRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LibraryRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LibraryRowsTable> {
  $$LibraryRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);
}

class $$LibraryRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LibraryRowsTable,
          LibraryRow,
          $$LibraryRowsTableFilterComposer,
          $$LibraryRowsTableOrderingComposer,
          $$LibraryRowsTableAnnotationComposer,
          $$LibraryRowsTableCreateCompanionBuilder,
          $$LibraryRowsTableUpdateCompanionBuilder,
          (
            LibraryRow,
            BaseReferences<_$AppDatabase, $LibraryRowsTable, LibraryRow>,
          ),
          LibraryRow,
          PrefetchHooks Function()
        > {
  $$LibraryRowsTableTableManager(_$AppDatabase db, $LibraryRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LibraryRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LibraryRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LibraryRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> path = const Value.absent(),
            Value<String> data = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => LibraryRowsCompanion(path: path, data: data, rowid: rowid),
          createCompanionCallback:
              ({
                required String path,
                required String data,
                Value<int> rowid = const Value.absent(),
              }) => LibraryRowsCompanion.insert(
                path: path,
                data: data,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LibraryRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LibraryRowsTable,
      LibraryRow,
      $$LibraryRowsTableFilterComposer,
      $$LibraryRowsTableOrderingComposer,
      $$LibraryRowsTableAnnotationComposer,
      $$LibraryRowsTableCreateCompanionBuilder,
      $$LibraryRowsTableUpdateCompanionBuilder,
      (
        LibraryRow,
        BaseReferences<_$AppDatabase, $LibraryRowsTable, LibraryRow>,
      ),
      LibraryRow,
      PrefetchHooks Function()
    >;
typedef $$HistoryRowsTableCreateCompanionBuilder =
    HistoryRowsCompanion Function({
      required String id,
      required String data,
      required DateTime savedAt,
      Value<int> rowid,
    });
typedef $$HistoryRowsTableUpdateCompanionBuilder =
    HistoryRowsCompanion Function({
      Value<String> id,
      Value<String> data,
      Value<DateTime> savedAt,
      Value<int> rowid,
    });

class $$HistoryRowsTableFilterComposer
    extends Composer<_$AppDatabase, $HistoryRowsTable> {
  $$HistoryRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get savedAt => $composableBuilder(
    column: $table.savedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HistoryRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $HistoryRowsTable> {
  $$HistoryRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get savedAt => $composableBuilder(
    column: $table.savedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HistoryRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $HistoryRowsTable> {
  $$HistoryRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<DateTime> get savedAt =>
      $composableBuilder(column: $table.savedAt, builder: (column) => column);
}

class $$HistoryRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HistoryRowsTable,
          HistoryRow,
          $$HistoryRowsTableFilterComposer,
          $$HistoryRowsTableOrderingComposer,
          $$HistoryRowsTableAnnotationComposer,
          $$HistoryRowsTableCreateCompanionBuilder,
          $$HistoryRowsTableUpdateCompanionBuilder,
          (
            HistoryRow,
            BaseReferences<_$AppDatabase, $HistoryRowsTable, HistoryRow>,
          ),
          HistoryRow,
          PrefetchHooks Function()
        > {
  $$HistoryRowsTableTableManager(_$AppDatabase db, $HistoryRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HistoryRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HistoryRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HistoryRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> data = const Value.absent(),
                Value<DateTime> savedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HistoryRowsCompanion(
                id: id,
                data: data,
                savedAt: savedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String data,
                required DateTime savedAt,
                Value<int> rowid = const Value.absent(),
              }) => HistoryRowsCompanion.insert(
                id: id,
                data: data,
                savedAt: savedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HistoryRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HistoryRowsTable,
      HistoryRow,
      $$HistoryRowsTableFilterComposer,
      $$HistoryRowsTableOrderingComposer,
      $$HistoryRowsTableAnnotationComposer,
      $$HistoryRowsTableCreateCompanionBuilder,
      $$HistoryRowsTableUpdateCompanionBuilder,
      (
        HistoryRow,
        BaseReferences<_$AppDatabase, $HistoryRowsTable, HistoryRow>,
      ),
      HistoryRow,
      PrefetchHooks Function()
    >;
typedef $$PlayHistoryRowsTableCreateCompanionBuilder =
    PlayHistoryRowsCompanion Function({
      required String id,
      required String data,
      required DateTime savedAt,
      Value<int> rowid,
    });
typedef $$PlayHistoryRowsTableUpdateCompanionBuilder =
    PlayHistoryRowsCompanion Function({
      Value<String> id,
      Value<String> data,
      Value<DateTime> savedAt,
      Value<int> rowid,
    });

class $$PlayHistoryRowsTableFilterComposer
    extends Composer<_$AppDatabase, $PlayHistoryRowsTable> {
  $$PlayHistoryRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get savedAt => $composableBuilder(
    column: $table.savedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PlayHistoryRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $PlayHistoryRowsTable> {
  $$PlayHistoryRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get savedAt => $composableBuilder(
    column: $table.savedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlayHistoryRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlayHistoryRowsTable> {
  $$PlayHistoryRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<DateTime> get savedAt =>
      $composableBuilder(column: $table.savedAt, builder: (column) => column);
}

class $$PlayHistoryRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlayHistoryRowsTable,
          PlayHistoryRow,
          $$PlayHistoryRowsTableFilterComposer,
          $$PlayHistoryRowsTableOrderingComposer,
          $$PlayHistoryRowsTableAnnotationComposer,
          $$PlayHistoryRowsTableCreateCompanionBuilder,
          $$PlayHistoryRowsTableUpdateCompanionBuilder,
          (
            PlayHistoryRow,
            BaseReferences<
              _$AppDatabase,
              $PlayHistoryRowsTable,
              PlayHistoryRow
            >,
          ),
          PlayHistoryRow,
          PrefetchHooks Function()
        > {
  $$PlayHistoryRowsTableTableManager(
    _$AppDatabase db,
    $PlayHistoryRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlayHistoryRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlayHistoryRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlayHistoryRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> data = const Value.absent(),
                Value<DateTime> savedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlayHistoryRowsCompanion(
                id: id,
                data: data,
                savedAt: savedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String data,
                required DateTime savedAt,
                Value<int> rowid = const Value.absent(),
              }) => PlayHistoryRowsCompanion.insert(
                id: id,
                data: data,
                savedAt: savedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PlayHistoryRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlayHistoryRowsTable,
      PlayHistoryRow,
      $$PlayHistoryRowsTableFilterComposer,
      $$PlayHistoryRowsTableOrderingComposer,
      $$PlayHistoryRowsTableAnnotationComposer,
      $$PlayHistoryRowsTableCreateCompanionBuilder,
      $$PlayHistoryRowsTableUpdateCompanionBuilder,
      (
        PlayHistoryRow,
        BaseReferences<_$AppDatabase, $PlayHistoryRowsTable, PlayHistoryRow>,
      ),
      PlayHistoryRow,
      PrefetchHooks Function()
    >;
typedef $$SettingsRowsTableCreateCompanionBuilder =
    SettingsRowsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$SettingsRowsTableUpdateCompanionBuilder =
    SettingsRowsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$SettingsRowsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsRowsTable> {
  $$SettingsRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsRowsTable> {
  $$SettingsRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsRowsTable> {
  $$SettingsRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsRowsTable,
          SettingsRow,
          $$SettingsRowsTableFilterComposer,
          $$SettingsRowsTableOrderingComposer,
          $$SettingsRowsTableAnnotationComposer,
          $$SettingsRowsTableCreateCompanionBuilder,
          $$SettingsRowsTableUpdateCompanionBuilder,
          (
            SettingsRow,
            BaseReferences<_$AppDatabase, $SettingsRowsTable, SettingsRow>,
          ),
          SettingsRow,
          PrefetchHooks Function()
        > {
  $$SettingsRowsTableTableManager(_$AppDatabase db, $SettingsRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SettingsRowsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => SettingsRowsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsRowsTable,
      SettingsRow,
      $$SettingsRowsTableFilterComposer,
      $$SettingsRowsTableOrderingComposer,
      $$SettingsRowsTableAnnotationComposer,
      $$SettingsRowsTableCreateCompanionBuilder,
      $$SettingsRowsTableUpdateCompanionBuilder,
      (
        SettingsRow,
        BaseReferences<_$AppDatabase, $SettingsRowsTable, SettingsRow>,
      ),
      SettingsRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$QueueRowsTableTableManager get queueRows =>
      $$QueueRowsTableTableManager(_db, _db.queueRows);
  $$LibraryRowsTableTableManager get libraryRows =>
      $$LibraryRowsTableTableManager(_db, _db.libraryRows);
  $$HistoryRowsTableTableManager get historyRows =>
      $$HistoryRowsTableTableManager(_db, _db.historyRows);
  $$PlayHistoryRowsTableTableManager get playHistoryRows =>
      $$PlayHistoryRowsTableTableManager(_db, _db.playHistoryRows);
  $$SettingsRowsTableTableManager get settingsRows =>
      $$SettingsRowsTableTableManager(_db, _db.settingsRows);
}
