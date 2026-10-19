// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'companion_recording_database.dart';

// ignore_for_file: type=lint
class $RecordingImportsTable extends RecordingImports
    with TableInfo<$RecordingImportsTable, ImportedRecording> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecordingImportsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _identityMeta = const VerificationMeta(
    'identity',
  );
  @override
  late final GeneratedColumn<String> identity = GeneratedColumn<String>(
    'identity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _watchIdMeta = const VerificationMeta(
    'watchId',
  );
  @override
  late final GeneratedColumn<String> watchId = GeneratedColumn<String>(
    'watch_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _filenameMeta = const VerificationMeta(
    'filename',
  );
  @override
  late final GeneratedColumn<String> filename = GeneratedColumn<String>(
    'filename',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timestampUtcMeta = const VerificationMeta(
    'timestampUtc',
  );
  @override
  late final GeneratedColumn<int> timestampUtc = GeneratedColumn<int>(
    'timestamp_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeBytesMeta = const VerificationMeta(
    'sizeBytes',
  );
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
    'size_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourcePathMeta = const VerificationMeta(
    'sourcePath',
  );
  @override
  late final GeneratedColumn<String> sourcePath = GeneratedColumn<String>(
    'source_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceSha256Meta = const VerificationMeta(
    'sourceSha256',
  );
  @override
  late final GeneratedColumn<String> sourceSha256 = GeneratedColumn<String>(
    'source_sha256',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _playbackPathMeta = const VerificationMeta(
    'playbackPath',
  );
  @override
  late final GeneratedColumn<String> playbackPath = GeneratedColumn<String>(
    'playback_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _playbackSha256Meta = const VerificationMeta(
    'playbackSha256',
  );
  @override
  late final GeneratedColumn<String> playbackSha256 = GeneratedColumn<String>(
    'playback_sha256',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _converterVersionMeta = const VerificationMeta(
    'converterVersion',
  );
  @override
  late final GeneratedColumn<int> converterVersion = GeneratedColumn<int>(
    'converter_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _importedAtMeta = const VerificationMeta(
    'importedAt',
  );
  @override
  late final GeneratedColumn<DateTime> importedAt = GeneratedColumn<DateTime>(
    'imported_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    identity,
    watchId,
    filename,
    timestampUtc,
    durationMs,
    sizeBytes,
    sourcePath,
    sourceSha256,
    playbackPath,
    playbackSha256,
    converterVersion,
    importedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recording_imports';
  @override
  VerificationContext validateIntegrity(
    Insertable<ImportedRecording> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('identity')) {
      context.handle(
        _identityMeta,
        identity.isAcceptableOrUnknown(data['identity']!, _identityMeta),
      );
    } else if (isInserting) {
      context.missing(_identityMeta);
    }
    if (data.containsKey('watch_id')) {
      context.handle(
        _watchIdMeta,
        watchId.isAcceptableOrUnknown(data['watch_id']!, _watchIdMeta),
      );
    } else if (isInserting) {
      context.missing(_watchIdMeta);
    }
    if (data.containsKey('filename')) {
      context.handle(
        _filenameMeta,
        filename.isAcceptableOrUnknown(data['filename']!, _filenameMeta),
      );
    } else if (isInserting) {
      context.missing(_filenameMeta);
    }
    if (data.containsKey('timestamp_utc')) {
      context.handle(
        _timestampUtcMeta,
        timestampUtc.isAcceptableOrUnknown(
          data['timestamp_utc']!,
          _timestampUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_timestampUtcMeta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    } else if (isInserting) {
      context.missing(_durationMsMeta);
    }
    if (data.containsKey('size_bytes')) {
      context.handle(
        _sizeBytesMeta,
        sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta),
      );
    } else if (isInserting) {
      context.missing(_sizeBytesMeta);
    }
    if (data.containsKey('source_path')) {
      context.handle(
        _sourcePathMeta,
        sourcePath.isAcceptableOrUnknown(data['source_path']!, _sourcePathMeta),
      );
    } else if (isInserting) {
      context.missing(_sourcePathMeta);
    }
    if (data.containsKey('source_sha256')) {
      context.handle(
        _sourceSha256Meta,
        sourceSha256.isAcceptableOrUnknown(
          data['source_sha256']!,
          _sourceSha256Meta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceSha256Meta);
    }
    if (data.containsKey('playback_path')) {
      context.handle(
        _playbackPathMeta,
        playbackPath.isAcceptableOrUnknown(
          data['playback_path']!,
          _playbackPathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_playbackPathMeta);
    }
    if (data.containsKey('playback_sha256')) {
      context.handle(
        _playbackSha256Meta,
        playbackSha256.isAcceptableOrUnknown(
          data['playback_sha256']!,
          _playbackSha256Meta,
        ),
      );
    } else if (isInserting) {
      context.missing(_playbackSha256Meta);
    }
    if (data.containsKey('converter_version')) {
      context.handle(
        _converterVersionMeta,
        converterVersion.isAcceptableOrUnknown(
          data['converter_version']!,
          _converterVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_converterVersionMeta);
    }
    if (data.containsKey('imported_at')) {
      context.handle(
        _importedAtMeta,
        importedAt.isAcceptableOrUnknown(data['imported_at']!, _importedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_importedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {identity};
  @override
  ImportedRecording map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ImportedRecording(
      identity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}identity'],
      )!,
      watchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}watch_id'],
      )!,
      filename: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}filename'],
      )!,
      timestampUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}timestamp_utc'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      sizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size_bytes'],
      )!,
      sourcePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_path'],
      )!,
      sourceSha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_sha256'],
      )!,
      playbackPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}playback_path'],
      )!,
      playbackSha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}playback_sha256'],
      )!,
      converterVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}converter_version'],
      )!,
      importedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}imported_at'],
      )!,
    );
  }

  @override
  $RecordingImportsTable createAlias(String alias) {
    return $RecordingImportsTable(attachedDatabase, alias);
  }
}

class ImportedRecording extends DataClass
    implements Insertable<ImportedRecording> {
  final String identity;
  final String watchId;
  final String filename;
  final int timestampUtc;
  final int durationMs;
  final int sizeBytes;
  final String sourcePath;
  final String sourceSha256;
  final String playbackPath;
  final String playbackSha256;
  final int converterVersion;
  final DateTime importedAt;
  const ImportedRecording({
    required this.identity,
    required this.watchId,
    required this.filename,
    required this.timestampUtc,
    required this.durationMs,
    required this.sizeBytes,
    required this.sourcePath,
    required this.sourceSha256,
    required this.playbackPath,
    required this.playbackSha256,
    required this.converterVersion,
    required this.importedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['identity'] = Variable<String>(identity);
    map['watch_id'] = Variable<String>(watchId);
    map['filename'] = Variable<String>(filename);
    map['timestamp_utc'] = Variable<int>(timestampUtc);
    map['duration_ms'] = Variable<int>(durationMs);
    map['size_bytes'] = Variable<int>(sizeBytes);
    map['source_path'] = Variable<String>(sourcePath);
    map['source_sha256'] = Variable<String>(sourceSha256);
    map['playback_path'] = Variable<String>(playbackPath);
    map['playback_sha256'] = Variable<String>(playbackSha256);
    map['converter_version'] = Variable<int>(converterVersion);
    map['imported_at'] = Variable<DateTime>(importedAt);
    return map;
  }

  RecordingImportsCompanion toCompanion(bool nullToAbsent) {
    return RecordingImportsCompanion(
      identity: Value(identity),
      watchId: Value(watchId),
      filename: Value(filename),
      timestampUtc: Value(timestampUtc),
      durationMs: Value(durationMs),
      sizeBytes: Value(sizeBytes),
      sourcePath: Value(sourcePath),
      sourceSha256: Value(sourceSha256),
      playbackPath: Value(playbackPath),
      playbackSha256: Value(playbackSha256),
      converterVersion: Value(converterVersion),
      importedAt: Value(importedAt),
    );
  }

  factory ImportedRecording.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ImportedRecording(
      identity: serializer.fromJson<String>(json['identity']),
      watchId: serializer.fromJson<String>(json['watchId']),
      filename: serializer.fromJson<String>(json['filename']),
      timestampUtc: serializer.fromJson<int>(json['timestampUtc']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      sizeBytes: serializer.fromJson<int>(json['sizeBytes']),
      sourcePath: serializer.fromJson<String>(json['sourcePath']),
      sourceSha256: serializer.fromJson<String>(json['sourceSha256']),
      playbackPath: serializer.fromJson<String>(json['playbackPath']),
      playbackSha256: serializer.fromJson<String>(json['playbackSha256']),
      converterVersion: serializer.fromJson<int>(json['converterVersion']),
      importedAt: serializer.fromJson<DateTime>(json['importedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'identity': serializer.toJson<String>(identity),
      'watchId': serializer.toJson<String>(watchId),
      'filename': serializer.toJson<String>(filename),
      'timestampUtc': serializer.toJson<int>(timestampUtc),
      'durationMs': serializer.toJson<int>(durationMs),
      'sizeBytes': serializer.toJson<int>(sizeBytes),
      'sourcePath': serializer.toJson<String>(sourcePath),
      'sourceSha256': serializer.toJson<String>(sourceSha256),
      'playbackPath': serializer.toJson<String>(playbackPath),
      'playbackSha256': serializer.toJson<String>(playbackSha256),
      'converterVersion': serializer.toJson<int>(converterVersion),
      'importedAt': serializer.toJson<DateTime>(importedAt),
    };
  }

  ImportedRecording copyWith({
    String? identity,
    String? watchId,
    String? filename,
    int? timestampUtc,
    int? durationMs,
    int? sizeBytes,
    String? sourcePath,
    String? sourceSha256,
    String? playbackPath,
    String? playbackSha256,
    int? converterVersion,
    DateTime? importedAt,
  }) => ImportedRecording(
    identity: identity ?? this.identity,
    watchId: watchId ?? this.watchId,
    filename: filename ?? this.filename,
    timestampUtc: timestampUtc ?? this.timestampUtc,
    durationMs: durationMs ?? this.durationMs,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    sourcePath: sourcePath ?? this.sourcePath,
    sourceSha256: sourceSha256 ?? this.sourceSha256,
    playbackPath: playbackPath ?? this.playbackPath,
    playbackSha256: playbackSha256 ?? this.playbackSha256,
    converterVersion: converterVersion ?? this.converterVersion,
    importedAt: importedAt ?? this.importedAt,
  );
  ImportedRecording copyWithCompanion(RecordingImportsCompanion data) {
    return ImportedRecording(
      identity: data.identity.present ? data.identity.value : this.identity,
      watchId: data.watchId.present ? data.watchId.value : this.watchId,
      filename: data.filename.present ? data.filename.value : this.filename,
      timestampUtc: data.timestampUtc.present
          ? data.timestampUtc.value
          : this.timestampUtc,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      sourcePath: data.sourcePath.present
          ? data.sourcePath.value
          : this.sourcePath,
      sourceSha256: data.sourceSha256.present
          ? data.sourceSha256.value
          : this.sourceSha256,
      playbackPath: data.playbackPath.present
          ? data.playbackPath.value
          : this.playbackPath,
      playbackSha256: data.playbackSha256.present
          ? data.playbackSha256.value
          : this.playbackSha256,
      converterVersion: data.converterVersion.present
          ? data.converterVersion.value
          : this.converterVersion,
      importedAt: data.importedAt.present
          ? data.importedAt.value
          : this.importedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ImportedRecording(')
          ..write('identity: $identity, ')
          ..write('watchId: $watchId, ')
          ..write('filename: $filename, ')
          ..write('timestampUtc: $timestampUtc, ')
          ..write('durationMs: $durationMs, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('sourcePath: $sourcePath, ')
          ..write('sourceSha256: $sourceSha256, ')
          ..write('playbackPath: $playbackPath, ')
          ..write('playbackSha256: $playbackSha256, ')
          ..write('converterVersion: $converterVersion, ')
          ..write('importedAt: $importedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    identity,
    watchId,
    filename,
    timestampUtc,
    durationMs,
    sizeBytes,
    sourcePath,
    sourceSha256,
    playbackPath,
    playbackSha256,
    converterVersion,
    importedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ImportedRecording &&
          other.identity == this.identity &&
          other.watchId == this.watchId &&
          other.filename == this.filename &&
          other.timestampUtc == this.timestampUtc &&
          other.durationMs == this.durationMs &&
          other.sizeBytes == this.sizeBytes &&
          other.sourcePath == this.sourcePath &&
          other.sourceSha256 == this.sourceSha256 &&
          other.playbackPath == this.playbackPath &&
          other.playbackSha256 == this.playbackSha256 &&
          other.converterVersion == this.converterVersion &&
          other.importedAt == this.importedAt);
}

class RecordingImportsCompanion extends UpdateCompanion<ImportedRecording> {
  final Value<String> identity;
  final Value<String> watchId;
  final Value<String> filename;
  final Value<int> timestampUtc;
  final Value<int> durationMs;
  final Value<int> sizeBytes;
  final Value<String> sourcePath;
  final Value<String> sourceSha256;
  final Value<String> playbackPath;
  final Value<String> playbackSha256;
  final Value<int> converterVersion;
  final Value<DateTime> importedAt;
  final Value<int> rowid;
  const RecordingImportsCompanion({
    this.identity = const Value.absent(),
    this.watchId = const Value.absent(),
    this.filename = const Value.absent(),
    this.timestampUtc = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.sourcePath = const Value.absent(),
    this.sourceSha256 = const Value.absent(),
    this.playbackPath = const Value.absent(),
    this.playbackSha256 = const Value.absent(),
    this.converterVersion = const Value.absent(),
    this.importedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecordingImportsCompanion.insert({
    required String identity,
    required String watchId,
    required String filename,
    required int timestampUtc,
    required int durationMs,
    required int sizeBytes,
    required String sourcePath,
    required String sourceSha256,
    required String playbackPath,
    required String playbackSha256,
    required int converterVersion,
    required DateTime importedAt,
    this.rowid = const Value.absent(),
  }) : identity = Value(identity),
       watchId = Value(watchId),
       filename = Value(filename),
       timestampUtc = Value(timestampUtc),
       durationMs = Value(durationMs),
       sizeBytes = Value(sizeBytes),
       sourcePath = Value(sourcePath),
       sourceSha256 = Value(sourceSha256),
       playbackPath = Value(playbackPath),
       playbackSha256 = Value(playbackSha256),
       converterVersion = Value(converterVersion),
       importedAt = Value(importedAt);
  static Insertable<ImportedRecording> custom({
    Expression<String>? identity,
    Expression<String>? watchId,
    Expression<String>? filename,
    Expression<int>? timestampUtc,
    Expression<int>? durationMs,
    Expression<int>? sizeBytes,
    Expression<String>? sourcePath,
    Expression<String>? sourceSha256,
    Expression<String>? playbackPath,
    Expression<String>? playbackSha256,
    Expression<int>? converterVersion,
    Expression<DateTime>? importedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (identity != null) 'identity': identity,
      if (watchId != null) 'watch_id': watchId,
      if (filename != null) 'filename': filename,
      if (timestampUtc != null) 'timestamp_utc': timestampUtc,
      if (durationMs != null) 'duration_ms': durationMs,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (sourcePath != null) 'source_path': sourcePath,
      if (sourceSha256 != null) 'source_sha256': sourceSha256,
      if (playbackPath != null) 'playback_path': playbackPath,
      if (playbackSha256 != null) 'playback_sha256': playbackSha256,
      if (converterVersion != null) 'converter_version': converterVersion,
      if (importedAt != null) 'imported_at': importedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecordingImportsCompanion copyWith({
    Value<String>? identity,
    Value<String>? watchId,
    Value<String>? filename,
    Value<int>? timestampUtc,
    Value<int>? durationMs,
    Value<int>? sizeBytes,
    Value<String>? sourcePath,
    Value<String>? sourceSha256,
    Value<String>? playbackPath,
    Value<String>? playbackSha256,
    Value<int>? converterVersion,
    Value<DateTime>? importedAt,
    Value<int>? rowid,
  }) {
    return RecordingImportsCompanion(
      identity: identity ?? this.identity,
      watchId: watchId ?? this.watchId,
      filename: filename ?? this.filename,
      timestampUtc: timestampUtc ?? this.timestampUtc,
      durationMs: durationMs ?? this.durationMs,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      sourcePath: sourcePath ?? this.sourcePath,
      sourceSha256: sourceSha256 ?? this.sourceSha256,
      playbackPath: playbackPath ?? this.playbackPath,
      playbackSha256: playbackSha256 ?? this.playbackSha256,
      converterVersion: converterVersion ?? this.converterVersion,
      importedAt: importedAt ?? this.importedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (identity.present) {
      map['identity'] = Variable<String>(identity.value);
    }
    if (watchId.present) {
      map['watch_id'] = Variable<String>(watchId.value);
    }
    if (filename.present) {
      map['filename'] = Variable<String>(filename.value);
    }
    if (timestampUtc.present) {
      map['timestamp_utc'] = Variable<int>(timestampUtc.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (sourcePath.present) {
      map['source_path'] = Variable<String>(sourcePath.value);
    }
    if (sourceSha256.present) {
      map['source_sha256'] = Variable<String>(sourceSha256.value);
    }
    if (playbackPath.present) {
      map['playback_path'] = Variable<String>(playbackPath.value);
    }
    if (playbackSha256.present) {
      map['playback_sha256'] = Variable<String>(playbackSha256.value);
    }
    if (converterVersion.present) {
      map['converter_version'] = Variable<int>(converterVersion.value);
    }
    if (importedAt.present) {
      map['imported_at'] = Variable<DateTime>(importedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecordingImportsCompanion(')
          ..write('identity: $identity, ')
          ..write('watchId: $watchId, ')
          ..write('filename: $filename, ')
          ..write('timestampUtc: $timestampUtc, ')
          ..write('durationMs: $durationMs, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('sourcePath: $sourcePath, ')
          ..write('sourceSha256: $sourceSha256, ')
          ..write('playbackPath: $playbackPath, ')
          ..write('playbackSha256: $playbackSha256, ')
          ..write('converterVersion: $converterVersion, ')
          ..write('importedAt: $importedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$CompanionRecordingDatabase extends GeneratedDatabase {
  _$CompanionRecordingDatabase(QueryExecutor e) : super(e);
  $CompanionRecordingDatabaseManager get managers =>
      $CompanionRecordingDatabaseManager(this);
  late final $RecordingImportsTable recordingImports = $RecordingImportsTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [recordingImports];
}

typedef $$RecordingImportsTableCreateCompanionBuilder =
    RecordingImportsCompanion Function({
      required String identity,
      required String watchId,
      required String filename,
      required int timestampUtc,
      required int durationMs,
      required int sizeBytes,
      required String sourcePath,
      required String sourceSha256,
      required String playbackPath,
      required String playbackSha256,
      required int converterVersion,
      required DateTime importedAt,
      Value<int> rowid,
    });
typedef $$RecordingImportsTableUpdateCompanionBuilder =
    RecordingImportsCompanion Function({
      Value<String> identity,
      Value<String> watchId,
      Value<String> filename,
      Value<int> timestampUtc,
      Value<int> durationMs,
      Value<int> sizeBytes,
      Value<String> sourcePath,
      Value<String> sourceSha256,
      Value<String> playbackPath,
      Value<String> playbackSha256,
      Value<int> converterVersion,
      Value<DateTime> importedAt,
      Value<int> rowid,
    });

class $$RecordingImportsTableFilterComposer
    extends Composer<_$CompanionRecordingDatabase, $RecordingImportsTable> {
  $$RecordingImportsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get identity => $composableBuilder(
    column: $table.identity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get watchId => $composableBuilder(
    column: $table.watchId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filename => $composableBuilder(
    column: $table.filename,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timestampUtc => $composableBuilder(
    column: $table.timestampUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourcePath => $composableBuilder(
    column: $table.sourcePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceSha256 => $composableBuilder(
    column: $table.sourceSha256,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get playbackPath => $composableBuilder(
    column: $table.playbackPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get playbackSha256 => $composableBuilder(
    column: $table.playbackSha256,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get converterVersion => $composableBuilder(
    column: $table.converterVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RecordingImportsTableOrderingComposer
    extends Composer<_$CompanionRecordingDatabase, $RecordingImportsTable> {
  $$RecordingImportsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get identity => $composableBuilder(
    column: $table.identity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get watchId => $composableBuilder(
    column: $table.watchId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filename => $composableBuilder(
    column: $table.filename,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timestampUtc => $composableBuilder(
    column: $table.timestampUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourcePath => $composableBuilder(
    column: $table.sourcePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceSha256 => $composableBuilder(
    column: $table.sourceSha256,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get playbackPath => $composableBuilder(
    column: $table.playbackPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get playbackSha256 => $composableBuilder(
    column: $table.playbackSha256,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get converterVersion => $composableBuilder(
    column: $table.converterVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RecordingImportsTableAnnotationComposer
    extends Composer<_$CompanionRecordingDatabase, $RecordingImportsTable> {
  $$RecordingImportsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get identity =>
      $composableBuilder(column: $table.identity, builder: (column) => column);

  GeneratedColumn<String> get watchId =>
      $composableBuilder(column: $table.watchId, builder: (column) => column);

  GeneratedColumn<String> get filename =>
      $composableBuilder(column: $table.filename, builder: (column) => column);

  GeneratedColumn<int> get timestampUtc => $composableBuilder(
    column: $table.timestampUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<String> get sourcePath => $composableBuilder(
    column: $table.sourcePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceSha256 => $composableBuilder(
    column: $table.sourceSha256,
    builder: (column) => column,
  );

  GeneratedColumn<String> get playbackPath => $composableBuilder(
    column: $table.playbackPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get playbackSha256 => $composableBuilder(
    column: $table.playbackSha256,
    builder: (column) => column,
  );

  GeneratedColumn<int> get converterVersion => $composableBuilder(
    column: $table.converterVersion,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => column,
  );
}

class $$RecordingImportsTableTableManager
    extends
        RootTableManager<
          _$CompanionRecordingDatabase,
          $RecordingImportsTable,
          ImportedRecording,
          $$RecordingImportsTableFilterComposer,
          $$RecordingImportsTableOrderingComposer,
          $$RecordingImportsTableAnnotationComposer,
          $$RecordingImportsTableCreateCompanionBuilder,
          $$RecordingImportsTableUpdateCompanionBuilder,
          (
            ImportedRecording,
            BaseReferences<
              _$CompanionRecordingDatabase,
              $RecordingImportsTable,
              ImportedRecording
            >,
          ),
          ImportedRecording,
          PrefetchHooks Function()
        > {
  $$RecordingImportsTableTableManager(
    _$CompanionRecordingDatabase db,
    $RecordingImportsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecordingImportsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecordingImportsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecordingImportsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> identity = const Value.absent(),
                Value<String> watchId = const Value.absent(),
                Value<String> filename = const Value.absent(),
                Value<int> timestampUtc = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<int> sizeBytes = const Value.absent(),
                Value<String> sourcePath = const Value.absent(),
                Value<String> sourceSha256 = const Value.absent(),
                Value<String> playbackPath = const Value.absent(),
                Value<String> playbackSha256 = const Value.absent(),
                Value<int> converterVersion = const Value.absent(),
                Value<DateTime> importedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecordingImportsCompanion(
                identity: identity,
                watchId: watchId,
                filename: filename,
                timestampUtc: timestampUtc,
                durationMs: durationMs,
                sizeBytes: sizeBytes,
                sourcePath: sourcePath,
                sourceSha256: sourceSha256,
                playbackPath: playbackPath,
                playbackSha256: playbackSha256,
                converterVersion: converterVersion,
                importedAt: importedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String identity,
                required String watchId,
                required String filename,
                required int timestampUtc,
                required int durationMs,
                required int sizeBytes,
                required String sourcePath,
                required String sourceSha256,
                required String playbackPath,
                required String playbackSha256,
                required int converterVersion,
                required DateTime importedAt,
                Value<int> rowid = const Value.absent(),
              }) => RecordingImportsCompanion.insert(
                identity: identity,
                watchId: watchId,
                filename: filename,
                timestampUtc: timestampUtc,
                durationMs: durationMs,
                sizeBytes: sizeBytes,
                sourcePath: sourcePath,
                sourceSha256: sourceSha256,
                playbackPath: playbackPath,
                playbackSha256: playbackSha256,
                converterVersion: converterVersion,
                importedAt: importedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RecordingImportsTableProcessedTableManager =
    ProcessedTableManager<
      _$CompanionRecordingDatabase,
      $RecordingImportsTable,
      ImportedRecording,
      $$RecordingImportsTableFilterComposer,
      $$RecordingImportsTableOrderingComposer,
      $$RecordingImportsTableAnnotationComposer,
      $$RecordingImportsTableCreateCompanionBuilder,
      $$RecordingImportsTableUpdateCompanionBuilder,
      (
        ImportedRecording,
        BaseReferences<
          _$CompanionRecordingDatabase,
          $RecordingImportsTable,
          ImportedRecording
        >,
      ),
      ImportedRecording,
      PrefetchHooks Function()
    >;

class $CompanionRecordingDatabaseManager {
  final _$CompanionRecordingDatabase _db;
  $CompanionRecordingDatabaseManager(this._db);
  $$RecordingImportsTableTableManager get recordingImports =>
      $$RecordingImportsTableTableManager(_db, _db.recordingImports);
}
