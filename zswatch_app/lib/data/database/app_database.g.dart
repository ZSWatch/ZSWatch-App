// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $WatchesTable extends Watches with TableInfo<$WatchesTable, WatchEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WatchesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _customNameMeta = const VerificationMeta(
    'customName',
  );
  @override
  late final GeneratedColumn<String> customName = GeneratedColumn<String>(
    'custom_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _firmwareVersionMeta = const VerificationMeta(
    'firmwareVersion',
  );
  @override
  late final GeneratedColumn<String> firmwareVersion = GeneratedColumn<String>(
    'firmware_version',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hardwareVersionMeta = const VerificationMeta(
    'hardwareVersion',
  );
  @override
  late final GeneratedColumn<String> hardwareVersion = GeneratedColumn<String>(
    'hardware_version',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _batteryLevelMeta = const VerificationMeta(
    'batteryLevel',
  );
  @override
  late final GeneratedColumn<int> batteryLevel = GeneratedColumn<int>(
    'battery_level',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isPrimaryMeta = const VerificationMeta(
    'isPrimary',
  );
  @override
  late final GeneratedColumn<bool> isPrimary = GeneratedColumn<bool>(
    'is_primary',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_primary" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _supportsExtendedApiMeta =
      const VerificationMeta('supportsExtendedApi');
  @override
  late final GeneratedColumn<bool> supportsExtendedApi = GeneratedColumn<bool>(
    'supports_extended_api',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("supports_extended_api" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lastConnectedAtMeta = const VerificationMeta(
    'lastConnectedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastConnectedAt =
      GeneratedColumn<DateTime>(
        'last_connected_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    customName,
    firmwareVersion,
    hardwareVersion,
    batteryLevel,
    isPrimary,
    supportsExtendedApi,
    lastConnectedAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'watches';
  @override
  VerificationContext validateIntegrity(
    Insertable<WatchEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('custom_name')) {
      context.handle(
        _customNameMeta,
        customName.isAcceptableOrUnknown(data['custom_name']!, _customNameMeta),
      );
    }
    if (data.containsKey('firmware_version')) {
      context.handle(
        _firmwareVersionMeta,
        firmwareVersion.isAcceptableOrUnknown(
          data['firmware_version']!,
          _firmwareVersionMeta,
        ),
      );
    }
    if (data.containsKey('hardware_version')) {
      context.handle(
        _hardwareVersionMeta,
        hardwareVersion.isAcceptableOrUnknown(
          data['hardware_version']!,
          _hardwareVersionMeta,
        ),
      );
    }
    if (data.containsKey('battery_level')) {
      context.handle(
        _batteryLevelMeta,
        batteryLevel.isAcceptableOrUnknown(
          data['battery_level']!,
          _batteryLevelMeta,
        ),
      );
    }
    if (data.containsKey('is_primary')) {
      context.handle(
        _isPrimaryMeta,
        isPrimary.isAcceptableOrUnknown(data['is_primary']!, _isPrimaryMeta),
      );
    }
    if (data.containsKey('supports_extended_api')) {
      context.handle(
        _supportsExtendedApiMeta,
        supportsExtendedApi.isAcceptableOrUnknown(
          data['supports_extended_api']!,
          _supportsExtendedApiMeta,
        ),
      );
    }
    if (data.containsKey('last_connected_at')) {
      context.handle(
        _lastConnectedAtMeta,
        lastConnectedAt.isAcceptableOrUnknown(
          data['last_connected_at']!,
          _lastConnectedAtMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WatchEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WatchEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      customName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}custom_name'],
      ),
      firmwareVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}firmware_version'],
      ),
      hardwareVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hardware_version'],
      ),
      batteryLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}battery_level'],
      ),
      isPrimary: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_primary'],
      )!,
      supportsExtendedApi: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}supports_extended_api'],
      )!,
      lastConnectedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_connected_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $WatchesTable createAlias(String alias) {
    return $WatchesTable(attachedDatabase, alias);
  }
}

class WatchEntity extends DataClass implements Insertable<WatchEntity> {
  /// BLE device identifier (MAC address or UUID)
  final String id;

  /// Advertised device name (e.g., "ZSWatch")
  final String name;

  /// User-defined custom name for the watch (FR-099 to FR-102)
  final String? customName;

  /// Last known firmware version from `t:"ver"` message
  final String? firmwareVersion;

  /// Hardware revision if available
  final String? hardwareVersion;

  /// Last known battery percentage (0-100)
  final int? batteryLevel;

  /// Currently selected/active watch
  final bool isPrimary;

  /// Whether firmware supports Extended ZSWatch API
  final bool supportsExtendedApi;

  /// Timestamp of last successful connection
  final DateTime? lastConnectedAt;

  /// When the device was first paired
  final DateTime createdAt;
  const WatchEntity({
    required this.id,
    required this.name,
    this.customName,
    this.firmwareVersion,
    this.hardwareVersion,
    this.batteryLevel,
    required this.isPrimary,
    required this.supportsExtendedApi,
    this.lastConnectedAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || customName != null) {
      map['custom_name'] = Variable<String>(customName);
    }
    if (!nullToAbsent || firmwareVersion != null) {
      map['firmware_version'] = Variable<String>(firmwareVersion);
    }
    if (!nullToAbsent || hardwareVersion != null) {
      map['hardware_version'] = Variable<String>(hardwareVersion);
    }
    if (!nullToAbsent || batteryLevel != null) {
      map['battery_level'] = Variable<int>(batteryLevel);
    }
    map['is_primary'] = Variable<bool>(isPrimary);
    map['supports_extended_api'] = Variable<bool>(supportsExtendedApi);
    if (!nullToAbsent || lastConnectedAt != null) {
      map['last_connected_at'] = Variable<DateTime>(lastConnectedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  WatchesCompanion toCompanion(bool nullToAbsent) {
    return WatchesCompanion(
      id: Value(id),
      name: Value(name),
      customName: customName == null && nullToAbsent
          ? const Value.absent()
          : Value(customName),
      firmwareVersion: firmwareVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(firmwareVersion),
      hardwareVersion: hardwareVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(hardwareVersion),
      batteryLevel: batteryLevel == null && nullToAbsent
          ? const Value.absent()
          : Value(batteryLevel),
      isPrimary: Value(isPrimary),
      supportsExtendedApi: Value(supportsExtendedApi),
      lastConnectedAt: lastConnectedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastConnectedAt),
      createdAt: Value(createdAt),
    );
  }

  factory WatchEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WatchEntity(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      customName: serializer.fromJson<String?>(json['customName']),
      firmwareVersion: serializer.fromJson<String?>(json['firmwareVersion']),
      hardwareVersion: serializer.fromJson<String?>(json['hardwareVersion']),
      batteryLevel: serializer.fromJson<int?>(json['batteryLevel']),
      isPrimary: serializer.fromJson<bool>(json['isPrimary']),
      supportsExtendedApi: serializer.fromJson<bool>(
        json['supportsExtendedApi'],
      ),
      lastConnectedAt: serializer.fromJson<DateTime?>(json['lastConnectedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'customName': serializer.toJson<String?>(customName),
      'firmwareVersion': serializer.toJson<String?>(firmwareVersion),
      'hardwareVersion': serializer.toJson<String?>(hardwareVersion),
      'batteryLevel': serializer.toJson<int?>(batteryLevel),
      'isPrimary': serializer.toJson<bool>(isPrimary),
      'supportsExtendedApi': serializer.toJson<bool>(supportsExtendedApi),
      'lastConnectedAt': serializer.toJson<DateTime?>(lastConnectedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  WatchEntity copyWith({
    String? id,
    String? name,
    Value<String?> customName = const Value.absent(),
    Value<String?> firmwareVersion = const Value.absent(),
    Value<String?> hardwareVersion = const Value.absent(),
    Value<int?> batteryLevel = const Value.absent(),
    bool? isPrimary,
    bool? supportsExtendedApi,
    Value<DateTime?> lastConnectedAt = const Value.absent(),
    DateTime? createdAt,
  }) => WatchEntity(
    id: id ?? this.id,
    name: name ?? this.name,
    customName: customName.present ? customName.value : this.customName,
    firmwareVersion: firmwareVersion.present
        ? firmwareVersion.value
        : this.firmwareVersion,
    hardwareVersion: hardwareVersion.present
        ? hardwareVersion.value
        : this.hardwareVersion,
    batteryLevel: batteryLevel.present ? batteryLevel.value : this.batteryLevel,
    isPrimary: isPrimary ?? this.isPrimary,
    supportsExtendedApi: supportsExtendedApi ?? this.supportsExtendedApi,
    lastConnectedAt: lastConnectedAt.present
        ? lastConnectedAt.value
        : this.lastConnectedAt,
    createdAt: createdAt ?? this.createdAt,
  );
  WatchEntity copyWithCompanion(WatchesCompanion data) {
    return WatchEntity(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      customName: data.customName.present
          ? data.customName.value
          : this.customName,
      firmwareVersion: data.firmwareVersion.present
          ? data.firmwareVersion.value
          : this.firmwareVersion,
      hardwareVersion: data.hardwareVersion.present
          ? data.hardwareVersion.value
          : this.hardwareVersion,
      batteryLevel: data.batteryLevel.present
          ? data.batteryLevel.value
          : this.batteryLevel,
      isPrimary: data.isPrimary.present ? data.isPrimary.value : this.isPrimary,
      supportsExtendedApi: data.supportsExtendedApi.present
          ? data.supportsExtendedApi.value
          : this.supportsExtendedApi,
      lastConnectedAt: data.lastConnectedAt.present
          ? data.lastConnectedAt.value
          : this.lastConnectedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WatchEntity(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('customName: $customName, ')
          ..write('firmwareVersion: $firmwareVersion, ')
          ..write('hardwareVersion: $hardwareVersion, ')
          ..write('batteryLevel: $batteryLevel, ')
          ..write('isPrimary: $isPrimary, ')
          ..write('supportsExtendedApi: $supportsExtendedApi, ')
          ..write('lastConnectedAt: $lastConnectedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    customName,
    firmwareVersion,
    hardwareVersion,
    batteryLevel,
    isPrimary,
    supportsExtendedApi,
    lastConnectedAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WatchEntity &&
          other.id == this.id &&
          other.name == this.name &&
          other.customName == this.customName &&
          other.firmwareVersion == this.firmwareVersion &&
          other.hardwareVersion == this.hardwareVersion &&
          other.batteryLevel == this.batteryLevel &&
          other.isPrimary == this.isPrimary &&
          other.supportsExtendedApi == this.supportsExtendedApi &&
          other.lastConnectedAt == this.lastConnectedAt &&
          other.createdAt == this.createdAt);
}

class WatchesCompanion extends UpdateCompanion<WatchEntity> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> customName;
  final Value<String?> firmwareVersion;
  final Value<String?> hardwareVersion;
  final Value<int?> batteryLevel;
  final Value<bool> isPrimary;
  final Value<bool> supportsExtendedApi;
  final Value<DateTime?> lastConnectedAt;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const WatchesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.customName = const Value.absent(),
    this.firmwareVersion = const Value.absent(),
    this.hardwareVersion = const Value.absent(),
    this.batteryLevel = const Value.absent(),
    this.isPrimary = const Value.absent(),
    this.supportsExtendedApi = const Value.absent(),
    this.lastConnectedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WatchesCompanion.insert({
    required String id,
    required String name,
    this.customName = const Value.absent(),
    this.firmwareVersion = const Value.absent(),
    this.hardwareVersion = const Value.absent(),
    this.batteryLevel = const Value.absent(),
    this.isPrimary = const Value.absent(),
    this.supportsExtendedApi = const Value.absent(),
    this.lastConnectedAt = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<WatchEntity> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? customName,
    Expression<String>? firmwareVersion,
    Expression<String>? hardwareVersion,
    Expression<int>? batteryLevel,
    Expression<bool>? isPrimary,
    Expression<bool>? supportsExtendedApi,
    Expression<DateTime>? lastConnectedAt,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (customName != null) 'custom_name': customName,
      if (firmwareVersion != null) 'firmware_version': firmwareVersion,
      if (hardwareVersion != null) 'hardware_version': hardwareVersion,
      if (batteryLevel != null) 'battery_level': batteryLevel,
      if (isPrimary != null) 'is_primary': isPrimary,
      if (supportsExtendedApi != null)
        'supports_extended_api': supportsExtendedApi,
      if (lastConnectedAt != null) 'last_connected_at': lastConnectedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WatchesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? customName,
    Value<String?>? firmwareVersion,
    Value<String?>? hardwareVersion,
    Value<int?>? batteryLevel,
    Value<bool>? isPrimary,
    Value<bool>? supportsExtendedApi,
    Value<DateTime?>? lastConnectedAt,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return WatchesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      customName: customName ?? this.customName,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      hardwareVersion: hardwareVersion ?? this.hardwareVersion,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      isPrimary: isPrimary ?? this.isPrimary,
      supportsExtendedApi: supportsExtendedApi ?? this.supportsExtendedApi,
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (customName.present) {
      map['custom_name'] = Variable<String>(customName.value);
    }
    if (firmwareVersion.present) {
      map['firmware_version'] = Variable<String>(firmwareVersion.value);
    }
    if (hardwareVersion.present) {
      map['hardware_version'] = Variable<String>(hardwareVersion.value);
    }
    if (batteryLevel.present) {
      map['battery_level'] = Variable<int>(batteryLevel.value);
    }
    if (isPrimary.present) {
      map['is_primary'] = Variable<bool>(isPrimary.value);
    }
    if (supportsExtendedApi.present) {
      map['supports_extended_api'] = Variable<bool>(supportsExtendedApi.value);
    }
    if (lastConnectedAt.present) {
      map['last_connected_at'] = Variable<DateTime>(lastConnectedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WatchesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('customName: $customName, ')
          ..write('firmwareVersion: $firmwareVersion, ')
          ..write('hardwareVersion: $hardwareVersion, ')
          ..write('batteryLevel: $batteryLevel, ')
          ..write('isPrimary: $isPrimary, ')
          ..write('supportsExtendedApi: $supportsExtendedApi, ')
          ..write('lastConnectedAt: $lastConnectedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HealthSamplesTable extends HealthSamples
    with TableInfo<$HealthSamplesTable, HealthSampleEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HealthSamplesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
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
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES watches (id)',
    ),
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<double> value = GeneratedColumn<double>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _granularityMeta = const VerificationMeta(
    'granularity',
  );
  @override
  late final GeneratedColumn<String> granularity = GeneratedColumn<String>(
    'granularity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    watchId,
    type,
    value,
    timestamp,
    granularity,
    syncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'health_samples';
  @override
  VerificationContext validateIntegrity(
    Insertable<HealthSampleEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('watch_id')) {
      context.handle(
        _watchIdMeta,
        watchId.isAcceptableOrUnknown(data['watch_id']!, _watchIdMeta),
      );
    } else if (isInserting) {
      context.missing(_watchIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('granularity')) {
      context.handle(
        _granularityMeta,
        granularity.isAcceptableOrUnknown(
          data['granularity']!,
          _granularityMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_granularityMeta);
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_syncedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HealthSampleEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HealthSampleEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      watchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}watch_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}value'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}timestamp'],
      )!,
      granularity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}granularity'],
      )!,
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      )!,
    );
  }

  @override
  $HealthSamplesTable createAlias(String alias) {
    return $HealthSamplesTable(attachedDatabase, alias);
  }
}

class HealthSampleEntity extends DataClass
    implements Insertable<HealthSampleEntity> {
  /// Auto-incrementing row identifier
  final int id;

  /// Foreign key to source watch
  final String watchId;

  /// Type of health data (steps, heartRate, sleep)
  final String type;

  /// Measured value (steps count, BPM, minutes)
  final double value;

  /// When the measurement was taken on the watch
  final DateTime timestamp;

  /// Time granularity (realtime, hourly, daily, weekly, monthly)
  final String granularity;

  /// When the data was received by the app
  final DateTime syncedAt;
  const HealthSampleEntity({
    required this.id,
    required this.watchId,
    required this.type,
    required this.value,
    required this.timestamp,
    required this.granularity,
    required this.syncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['watch_id'] = Variable<String>(watchId);
    map['type'] = Variable<String>(type);
    map['value'] = Variable<double>(value);
    map['timestamp'] = Variable<DateTime>(timestamp);
    map['granularity'] = Variable<String>(granularity);
    map['synced_at'] = Variable<DateTime>(syncedAt);
    return map;
  }

  HealthSamplesCompanion toCompanion(bool nullToAbsent) {
    return HealthSamplesCompanion(
      id: Value(id),
      watchId: Value(watchId),
      type: Value(type),
      value: Value(value),
      timestamp: Value(timestamp),
      granularity: Value(granularity),
      syncedAt: Value(syncedAt),
    );
  }

  factory HealthSampleEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HealthSampleEntity(
      id: serializer.fromJson<int>(json['id']),
      watchId: serializer.fromJson<String>(json['watchId']),
      type: serializer.fromJson<String>(json['type']),
      value: serializer.fromJson<double>(json['value']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      granularity: serializer.fromJson<String>(json['granularity']),
      syncedAt: serializer.fromJson<DateTime>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'watchId': serializer.toJson<String>(watchId),
      'type': serializer.toJson<String>(type),
      'value': serializer.toJson<double>(value),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'granularity': serializer.toJson<String>(granularity),
      'syncedAt': serializer.toJson<DateTime>(syncedAt),
    };
  }

  HealthSampleEntity copyWith({
    int? id,
    String? watchId,
    String? type,
    double? value,
    DateTime? timestamp,
    String? granularity,
    DateTime? syncedAt,
  }) => HealthSampleEntity(
    id: id ?? this.id,
    watchId: watchId ?? this.watchId,
    type: type ?? this.type,
    value: value ?? this.value,
    timestamp: timestamp ?? this.timestamp,
    granularity: granularity ?? this.granularity,
    syncedAt: syncedAt ?? this.syncedAt,
  );
  HealthSampleEntity copyWithCompanion(HealthSamplesCompanion data) {
    return HealthSampleEntity(
      id: data.id.present ? data.id.value : this.id,
      watchId: data.watchId.present ? data.watchId.value : this.watchId,
      type: data.type.present ? data.type.value : this.type,
      value: data.value.present ? data.value.value : this.value,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      granularity: data.granularity.present
          ? data.granularity.value
          : this.granularity,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HealthSampleEntity(')
          ..write('id: $id, ')
          ..write('watchId: $watchId, ')
          ..write('type: $type, ')
          ..write('value: $value, ')
          ..write('timestamp: $timestamp, ')
          ..write('granularity: $granularity, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, watchId, type, value, timestamp, granularity, syncedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HealthSampleEntity &&
          other.id == this.id &&
          other.watchId == this.watchId &&
          other.type == this.type &&
          other.value == this.value &&
          other.timestamp == this.timestamp &&
          other.granularity == this.granularity &&
          other.syncedAt == this.syncedAt);
}

class HealthSamplesCompanion extends UpdateCompanion<HealthSampleEntity> {
  final Value<int> id;
  final Value<String> watchId;
  final Value<String> type;
  final Value<double> value;
  final Value<DateTime> timestamp;
  final Value<String> granularity;
  final Value<DateTime> syncedAt;
  const HealthSamplesCompanion({
    this.id = const Value.absent(),
    this.watchId = const Value.absent(),
    this.type = const Value.absent(),
    this.value = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.granularity = const Value.absent(),
    this.syncedAt = const Value.absent(),
  });
  HealthSamplesCompanion.insert({
    this.id = const Value.absent(),
    required String watchId,
    required String type,
    required double value,
    required DateTime timestamp,
    required String granularity,
    required DateTime syncedAt,
  }) : watchId = Value(watchId),
       type = Value(type),
       value = Value(value),
       timestamp = Value(timestamp),
       granularity = Value(granularity),
       syncedAt = Value(syncedAt);
  static Insertable<HealthSampleEntity> custom({
    Expression<int>? id,
    Expression<String>? watchId,
    Expression<String>? type,
    Expression<double>? value,
    Expression<DateTime>? timestamp,
    Expression<String>? granularity,
    Expression<DateTime>? syncedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (watchId != null) 'watch_id': watchId,
      if (type != null) 'type': type,
      if (value != null) 'value': value,
      if (timestamp != null) 'timestamp': timestamp,
      if (granularity != null) 'granularity': granularity,
      if (syncedAt != null) 'synced_at': syncedAt,
    });
  }

  HealthSamplesCompanion copyWith({
    Value<int>? id,
    Value<String>? watchId,
    Value<String>? type,
    Value<double>? value,
    Value<DateTime>? timestamp,
    Value<String>? granularity,
    Value<DateTime>? syncedAt,
  }) {
    return HealthSamplesCompanion(
      id: id ?? this.id,
      watchId: watchId ?? this.watchId,
      type: type ?? this.type,
      value: value ?? this.value,
      timestamp: timestamp ?? this.timestamp,
      granularity: granularity ?? this.granularity,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (watchId.present) {
      map['watch_id'] = Variable<String>(watchId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (value.present) {
      map['value'] = Variable<double>(value.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (granularity.present) {
      map['granularity'] = Variable<String>(granularity.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HealthSamplesCompanion(')
          ..write('id: $id, ')
          ..write('watchId: $watchId, ')
          ..write('type: $type, ')
          ..write('value: $value, ')
          ..write('timestamp: $timestamp, ')
          ..write('granularity: $granularity, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }
}

class $BatteryReadingsTable extends BatteryReadings
    with TableInfo<$BatteryReadingsTable, BatteryReadingEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BatteryReadingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
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
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES watches (id)',
    ),
  );
  static const VerificationMeta _levelMeta = const VerificationMeta('level');
  @override
  late final GeneratedColumn<int> level = GeneratedColumn<int>(
    'level',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isChargingMeta = const VerificationMeta(
    'isCharging',
  );
  @override
  late final GeneratedColumn<bool> isCharging = GeneratedColumn<bool>(
    'is_charging',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_charging" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    watchId,
    level,
    isCharging,
    timestamp,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'battery_readings';
  @override
  VerificationContext validateIntegrity(
    Insertable<BatteryReadingEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('watch_id')) {
      context.handle(
        _watchIdMeta,
        watchId.isAcceptableOrUnknown(data['watch_id']!, _watchIdMeta),
      );
    } else if (isInserting) {
      context.missing(_watchIdMeta);
    }
    if (data.containsKey('level')) {
      context.handle(
        _levelMeta,
        level.isAcceptableOrUnknown(data['level']!, _levelMeta),
      );
    } else if (isInserting) {
      context.missing(_levelMeta);
    }
    if (data.containsKey('is_charging')) {
      context.handle(
        _isChargingMeta,
        isCharging.isAcceptableOrUnknown(data['is_charging']!, _isChargingMeta),
      );
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BatteryReadingEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BatteryReadingEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      watchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}watch_id'],
      )!,
      level: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}level'],
      )!,
      isCharging: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_charging'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}timestamp'],
      )!,
    );
  }

  @override
  $BatteryReadingsTable createAlias(String alias) {
    return $BatteryReadingsTable(attachedDatabase, alias);
  }
}

class BatteryReadingEntity extends DataClass
    implements Insertable<BatteryReadingEntity> {
  /// Auto-incrementing row identifier
  final int id;

  /// Foreign key to source watch
  final String watchId;

  /// Battery percentage (0-100)
  final int level;

  /// Whether the watch is currently charging
  final bool isCharging;

  /// When the sample was taken
  final DateTime timestamp;
  const BatteryReadingEntity({
    required this.id,
    required this.watchId,
    required this.level,
    required this.isCharging,
    required this.timestamp,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['watch_id'] = Variable<String>(watchId);
    map['level'] = Variable<int>(level);
    map['is_charging'] = Variable<bool>(isCharging);
    map['timestamp'] = Variable<DateTime>(timestamp);
    return map;
  }

  BatteryReadingsCompanion toCompanion(bool nullToAbsent) {
    return BatteryReadingsCompanion(
      id: Value(id),
      watchId: Value(watchId),
      level: Value(level),
      isCharging: Value(isCharging),
      timestamp: Value(timestamp),
    );
  }

  factory BatteryReadingEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BatteryReadingEntity(
      id: serializer.fromJson<int>(json['id']),
      watchId: serializer.fromJson<String>(json['watchId']),
      level: serializer.fromJson<int>(json['level']),
      isCharging: serializer.fromJson<bool>(json['isCharging']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'watchId': serializer.toJson<String>(watchId),
      'level': serializer.toJson<int>(level),
      'isCharging': serializer.toJson<bool>(isCharging),
      'timestamp': serializer.toJson<DateTime>(timestamp),
    };
  }

  BatteryReadingEntity copyWith({
    int? id,
    String? watchId,
    int? level,
    bool? isCharging,
    DateTime? timestamp,
  }) => BatteryReadingEntity(
    id: id ?? this.id,
    watchId: watchId ?? this.watchId,
    level: level ?? this.level,
    isCharging: isCharging ?? this.isCharging,
    timestamp: timestamp ?? this.timestamp,
  );
  BatteryReadingEntity copyWithCompanion(BatteryReadingsCompanion data) {
    return BatteryReadingEntity(
      id: data.id.present ? data.id.value : this.id,
      watchId: data.watchId.present ? data.watchId.value : this.watchId,
      level: data.level.present ? data.level.value : this.level,
      isCharging: data.isCharging.present
          ? data.isCharging.value
          : this.isCharging,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BatteryReadingEntity(')
          ..write('id: $id, ')
          ..write('watchId: $watchId, ')
          ..write('level: $level, ')
          ..write('isCharging: $isCharging, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, watchId, level, isCharging, timestamp);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BatteryReadingEntity &&
          other.id == this.id &&
          other.watchId == this.watchId &&
          other.level == this.level &&
          other.isCharging == this.isCharging &&
          other.timestamp == this.timestamp);
}

class BatteryReadingsCompanion extends UpdateCompanion<BatteryReadingEntity> {
  final Value<int> id;
  final Value<String> watchId;
  final Value<int> level;
  final Value<bool> isCharging;
  final Value<DateTime> timestamp;
  const BatteryReadingsCompanion({
    this.id = const Value.absent(),
    this.watchId = const Value.absent(),
    this.level = const Value.absent(),
    this.isCharging = const Value.absent(),
    this.timestamp = const Value.absent(),
  });
  BatteryReadingsCompanion.insert({
    this.id = const Value.absent(),
    required String watchId,
    required int level,
    this.isCharging = const Value.absent(),
    required DateTime timestamp,
  }) : watchId = Value(watchId),
       level = Value(level),
       timestamp = Value(timestamp);
  static Insertable<BatteryReadingEntity> custom({
    Expression<int>? id,
    Expression<String>? watchId,
    Expression<int>? level,
    Expression<bool>? isCharging,
    Expression<DateTime>? timestamp,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (watchId != null) 'watch_id': watchId,
      if (level != null) 'level': level,
      if (isCharging != null) 'is_charging': isCharging,
      if (timestamp != null) 'timestamp': timestamp,
    });
  }

  BatteryReadingsCompanion copyWith({
    Value<int>? id,
    Value<String>? watchId,
    Value<int>? level,
    Value<bool>? isCharging,
    Value<DateTime>? timestamp,
  }) {
    return BatteryReadingsCompanion(
      id: id ?? this.id,
      watchId: watchId ?? this.watchId,
      level: level ?? this.level,
      isCharging: isCharging ?? this.isCharging,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (watchId.present) {
      map['watch_id'] = Variable<String>(watchId.value);
    }
    if (level.present) {
      map['level'] = Variable<int>(level.value);
    }
    if (isCharging.present) {
      map['is_charging'] = Variable<bool>(isCharging.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BatteryReadingsCompanion(')
          ..write('id: $id, ')
          ..write('watchId: $watchId, ')
          ..write('level: $level, ')
          ..write('isCharging: $isCharging, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }
}

class $CommLogEntriesTable extends CommLogEntries
    with TableInfo<$CommLogEntriesTable, CommLogEntryEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CommLogEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _directionMeta = const VerificationMeta(
    'direction',
  );
  @override
  late final GeneratedColumn<String> direction = GeneratedColumn<String>(
    'direction',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _protocolMeta = const VerificationMeta(
    'protocol',
  );
  @override
  late final GeneratedColumn<String> protocol = GeneratedColumn<String>(
    'protocol',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _characteristicMeta = const VerificationMeta(
    'characteristic',
  );
  @override
  late final GeneratedColumn<String> characteristic = GeneratedColumn<String>(
    'characteristic',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadSizeMeta = const VerificationMeta(
    'payloadSize',
  );
  @override
  late final GeneratedColumn<int> payloadSize = GeneratedColumn<int>(
    'payload_size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    direction,
    protocol,
    characteristic,
    payload,
    payloadSize,
    timestamp,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'comm_log_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<CommLogEntryEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('direction')) {
      context.handle(
        _directionMeta,
        direction.isAcceptableOrUnknown(data['direction']!, _directionMeta),
      );
    } else if (isInserting) {
      context.missing(_directionMeta);
    }
    if (data.containsKey('protocol')) {
      context.handle(
        _protocolMeta,
        protocol.isAcceptableOrUnknown(data['protocol']!, _protocolMeta),
      );
    } else if (isInserting) {
      context.missing(_protocolMeta);
    }
    if (data.containsKey('characteristic')) {
      context.handle(
        _characteristicMeta,
        characteristic.isAcceptableOrUnknown(
          data['characteristic']!,
          _characteristicMeta,
        ),
      );
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('payload_size')) {
      context.handle(
        _payloadSizeMeta,
        payloadSize.isAcceptableOrUnknown(
          data['payload_size']!,
          _payloadSizeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadSizeMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CommLogEntryEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CommLogEntryEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      direction: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}direction'],
      )!,
      protocol: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}protocol'],
      )!,
      characteristic: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}characteristic'],
      ),
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      payloadSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}payload_size'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}timestamp'],
      )!,
    );
  }

  @override
  $CommLogEntriesTable createAlias(String alias) {
    return $CommLogEntriesTable(attachedDatabase, alias);
  }
}

class CommLogEntryEntity extends DataClass
    implements Insertable<CommLogEntryEntity> {
  /// Auto-incrementing row identifier
  final int id;

  /// Message direction (incoming/outgoing)
  final String direction;

  /// Protocol type (gadgetbridge/extended/mcumgr/unknown)
  final String protocol;

  /// GATT characteristic UUID (if applicable)
  final String? characteristic;

  /// Message payload (truncated to 1KB max)
  final String payload;

  /// Original payload size in bytes (before truncation)
  final int payloadSize;

  /// When the message was sent/received
  final DateTime timestamp;
  const CommLogEntryEntity({
    required this.id,
    required this.direction,
    required this.protocol,
    this.characteristic,
    required this.payload,
    required this.payloadSize,
    required this.timestamp,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['direction'] = Variable<String>(direction);
    map['protocol'] = Variable<String>(protocol);
    if (!nullToAbsent || characteristic != null) {
      map['characteristic'] = Variable<String>(characteristic);
    }
    map['payload'] = Variable<String>(payload);
    map['payload_size'] = Variable<int>(payloadSize);
    map['timestamp'] = Variable<DateTime>(timestamp);
    return map;
  }

  CommLogEntriesCompanion toCompanion(bool nullToAbsent) {
    return CommLogEntriesCompanion(
      id: Value(id),
      direction: Value(direction),
      protocol: Value(protocol),
      characteristic: characteristic == null && nullToAbsent
          ? const Value.absent()
          : Value(characteristic),
      payload: Value(payload),
      payloadSize: Value(payloadSize),
      timestamp: Value(timestamp),
    );
  }

  factory CommLogEntryEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CommLogEntryEntity(
      id: serializer.fromJson<int>(json['id']),
      direction: serializer.fromJson<String>(json['direction']),
      protocol: serializer.fromJson<String>(json['protocol']),
      characteristic: serializer.fromJson<String?>(json['characteristic']),
      payload: serializer.fromJson<String>(json['payload']),
      payloadSize: serializer.fromJson<int>(json['payloadSize']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'direction': serializer.toJson<String>(direction),
      'protocol': serializer.toJson<String>(protocol),
      'characteristic': serializer.toJson<String?>(characteristic),
      'payload': serializer.toJson<String>(payload),
      'payloadSize': serializer.toJson<int>(payloadSize),
      'timestamp': serializer.toJson<DateTime>(timestamp),
    };
  }

  CommLogEntryEntity copyWith({
    int? id,
    String? direction,
    String? protocol,
    Value<String?> characteristic = const Value.absent(),
    String? payload,
    int? payloadSize,
    DateTime? timestamp,
  }) => CommLogEntryEntity(
    id: id ?? this.id,
    direction: direction ?? this.direction,
    protocol: protocol ?? this.protocol,
    characteristic: characteristic.present
        ? characteristic.value
        : this.characteristic,
    payload: payload ?? this.payload,
    payloadSize: payloadSize ?? this.payloadSize,
    timestamp: timestamp ?? this.timestamp,
  );
  CommLogEntryEntity copyWithCompanion(CommLogEntriesCompanion data) {
    return CommLogEntryEntity(
      id: data.id.present ? data.id.value : this.id,
      direction: data.direction.present ? data.direction.value : this.direction,
      protocol: data.protocol.present ? data.protocol.value : this.protocol,
      characteristic: data.characteristic.present
          ? data.characteristic.value
          : this.characteristic,
      payload: data.payload.present ? data.payload.value : this.payload,
      payloadSize: data.payloadSize.present
          ? data.payloadSize.value
          : this.payloadSize,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CommLogEntryEntity(')
          ..write('id: $id, ')
          ..write('direction: $direction, ')
          ..write('protocol: $protocol, ')
          ..write('characteristic: $characteristic, ')
          ..write('payload: $payload, ')
          ..write('payloadSize: $payloadSize, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    direction,
    protocol,
    characteristic,
    payload,
    payloadSize,
    timestamp,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CommLogEntryEntity &&
          other.id == this.id &&
          other.direction == this.direction &&
          other.protocol == this.protocol &&
          other.characteristic == this.characteristic &&
          other.payload == this.payload &&
          other.payloadSize == this.payloadSize &&
          other.timestamp == this.timestamp);
}

class CommLogEntriesCompanion extends UpdateCompanion<CommLogEntryEntity> {
  final Value<int> id;
  final Value<String> direction;
  final Value<String> protocol;
  final Value<String?> characteristic;
  final Value<String> payload;
  final Value<int> payloadSize;
  final Value<DateTime> timestamp;
  const CommLogEntriesCompanion({
    this.id = const Value.absent(),
    this.direction = const Value.absent(),
    this.protocol = const Value.absent(),
    this.characteristic = const Value.absent(),
    this.payload = const Value.absent(),
    this.payloadSize = const Value.absent(),
    this.timestamp = const Value.absent(),
  });
  CommLogEntriesCompanion.insert({
    this.id = const Value.absent(),
    required String direction,
    required String protocol,
    this.characteristic = const Value.absent(),
    required String payload,
    required int payloadSize,
    required DateTime timestamp,
  }) : direction = Value(direction),
       protocol = Value(protocol),
       payload = Value(payload),
       payloadSize = Value(payloadSize),
       timestamp = Value(timestamp);
  static Insertable<CommLogEntryEntity> custom({
    Expression<int>? id,
    Expression<String>? direction,
    Expression<String>? protocol,
    Expression<String>? characteristic,
    Expression<String>? payload,
    Expression<int>? payloadSize,
    Expression<DateTime>? timestamp,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (direction != null) 'direction': direction,
      if (protocol != null) 'protocol': protocol,
      if (characteristic != null) 'characteristic': characteristic,
      if (payload != null) 'payload': payload,
      if (payloadSize != null) 'payload_size': payloadSize,
      if (timestamp != null) 'timestamp': timestamp,
    });
  }

  CommLogEntriesCompanion copyWith({
    Value<int>? id,
    Value<String>? direction,
    Value<String>? protocol,
    Value<String?>? characteristic,
    Value<String>? payload,
    Value<int>? payloadSize,
    Value<DateTime>? timestamp,
  }) {
    return CommLogEntriesCompanion(
      id: id ?? this.id,
      direction: direction ?? this.direction,
      protocol: protocol ?? this.protocol,
      characteristic: characteristic ?? this.characteristic,
      payload: payload ?? this.payload,
      payloadSize: payloadSize ?? this.payloadSize,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (direction.present) {
      map['direction'] = Variable<String>(direction.value);
    }
    if (protocol.present) {
      map['protocol'] = Variable<String>(protocol.value);
    }
    if (characteristic.present) {
      map['characteristic'] = Variable<String>(characteristic.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (payloadSize.present) {
      map['payload_size'] = Variable<int>(payloadSize.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CommLogEntriesCompanion(')
          ..write('id: $id, ')
          ..write('direction: $direction, ')
          ..write('protocol: $protocol, ')
          ..write('characteristic: $characteristic, ')
          ..write('payload: $payload, ')
          ..write('payloadSize: $payloadSize, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }
}

class $ConnectionEventsTable extends ConnectionEvents
    with TableInfo<$ConnectionEventsTable, ConnectionEventEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConnectionEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
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
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES watches (id)',
    ),
  );
  static const VerificationMeta _eventTypeMeta = const VerificationMeta(
    'eventType',
  );
  @override
  late final GeneratedColumn<String> eventType = GeneratedColumn<String>(
    'event_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
    'reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _detailsMeta = const VerificationMeta(
    'details',
  );
  @override
  late final GeneratedColumn<String> details = GeneratedColumn<String>(
    'details',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    watchId,
    eventType,
    timestamp,
    reason,
    details,
    sessionId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'connection_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<ConnectionEventEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('watch_id')) {
      context.handle(
        _watchIdMeta,
        watchId.isAcceptableOrUnknown(data['watch_id']!, _watchIdMeta),
      );
    } else if (isInserting) {
      context.missing(_watchIdMeta);
    }
    if (data.containsKey('event_type')) {
      context.handle(
        _eventTypeMeta,
        eventType.isAcceptableOrUnknown(data['event_type']!, _eventTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_eventTypeMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('reason')) {
      context.handle(
        _reasonMeta,
        reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta),
      );
    }
    if (data.containsKey('details')) {
      context.handle(
        _detailsMeta,
        details.isAcceptableOrUnknown(data['details']!, _detailsMeta),
      );
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ConnectionEventEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConnectionEventEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      watchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}watch_id'],
      )!,
      eventType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_type'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}timestamp'],
      )!,
      reason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason'],
      ),
      details: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}details'],
      ),
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      ),
    );
  }

  @override
  $ConnectionEventsTable createAlias(String alias) {
    return $ConnectionEventsTable(attachedDatabase, alias);
  }
}

class ConnectionEventEntity extends DataClass
    implements Insertable<ConnectionEventEntity> {
  /// Auto-incrementing row identifier
  final int id;

  /// Foreign key to source watch
  final String watchId;

  /// Type of event: connected, disconnected, reconnect_attempt, reconnect_failed
  final String eventType;

  /// When the event occurred
  final DateTime timestamp;

  /// Reason for disconnection (only for disconnect events)
  /// Values: user_requested, connection_lost, device_unavailable,
  ///         bluetooth_disabled, app_terminated, unknown
  final String? reason;

  /// Additional details (e.g., error message)
  final String? details;

  /// Session ID to group connect/disconnect pairs
  /// Generated as UUID when connection is established
  final String? sessionId;
  const ConnectionEventEntity({
    required this.id,
    required this.watchId,
    required this.eventType,
    required this.timestamp,
    this.reason,
    this.details,
    this.sessionId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['watch_id'] = Variable<String>(watchId);
    map['event_type'] = Variable<String>(eventType);
    map['timestamp'] = Variable<DateTime>(timestamp);
    if (!nullToAbsent || reason != null) {
      map['reason'] = Variable<String>(reason);
    }
    if (!nullToAbsent || details != null) {
      map['details'] = Variable<String>(details);
    }
    if (!nullToAbsent || sessionId != null) {
      map['session_id'] = Variable<String>(sessionId);
    }
    return map;
  }

  ConnectionEventsCompanion toCompanion(bool nullToAbsent) {
    return ConnectionEventsCompanion(
      id: Value(id),
      watchId: Value(watchId),
      eventType: Value(eventType),
      timestamp: Value(timestamp),
      reason: reason == null && nullToAbsent
          ? const Value.absent()
          : Value(reason),
      details: details == null && nullToAbsent
          ? const Value.absent()
          : Value(details),
      sessionId: sessionId == null && nullToAbsent
          ? const Value.absent()
          : Value(sessionId),
    );
  }

  factory ConnectionEventEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConnectionEventEntity(
      id: serializer.fromJson<int>(json['id']),
      watchId: serializer.fromJson<String>(json['watchId']),
      eventType: serializer.fromJson<String>(json['eventType']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      reason: serializer.fromJson<String?>(json['reason']),
      details: serializer.fromJson<String?>(json['details']),
      sessionId: serializer.fromJson<String?>(json['sessionId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'watchId': serializer.toJson<String>(watchId),
      'eventType': serializer.toJson<String>(eventType),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'reason': serializer.toJson<String?>(reason),
      'details': serializer.toJson<String?>(details),
      'sessionId': serializer.toJson<String?>(sessionId),
    };
  }

  ConnectionEventEntity copyWith({
    int? id,
    String? watchId,
    String? eventType,
    DateTime? timestamp,
    Value<String?> reason = const Value.absent(),
    Value<String?> details = const Value.absent(),
    Value<String?> sessionId = const Value.absent(),
  }) => ConnectionEventEntity(
    id: id ?? this.id,
    watchId: watchId ?? this.watchId,
    eventType: eventType ?? this.eventType,
    timestamp: timestamp ?? this.timestamp,
    reason: reason.present ? reason.value : this.reason,
    details: details.present ? details.value : this.details,
    sessionId: sessionId.present ? sessionId.value : this.sessionId,
  );
  ConnectionEventEntity copyWithCompanion(ConnectionEventsCompanion data) {
    return ConnectionEventEntity(
      id: data.id.present ? data.id.value : this.id,
      watchId: data.watchId.present ? data.watchId.value : this.watchId,
      eventType: data.eventType.present ? data.eventType.value : this.eventType,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      reason: data.reason.present ? data.reason.value : this.reason,
      details: data.details.present ? data.details.value : this.details,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConnectionEventEntity(')
          ..write('id: $id, ')
          ..write('watchId: $watchId, ')
          ..write('eventType: $eventType, ')
          ..write('timestamp: $timestamp, ')
          ..write('reason: $reason, ')
          ..write('details: $details, ')
          ..write('sessionId: $sessionId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    watchId,
    eventType,
    timestamp,
    reason,
    details,
    sessionId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConnectionEventEntity &&
          other.id == this.id &&
          other.watchId == this.watchId &&
          other.eventType == this.eventType &&
          other.timestamp == this.timestamp &&
          other.reason == this.reason &&
          other.details == this.details &&
          other.sessionId == this.sessionId);
}

class ConnectionEventsCompanion extends UpdateCompanion<ConnectionEventEntity> {
  final Value<int> id;
  final Value<String> watchId;
  final Value<String> eventType;
  final Value<DateTime> timestamp;
  final Value<String?> reason;
  final Value<String?> details;
  final Value<String?> sessionId;
  const ConnectionEventsCompanion({
    this.id = const Value.absent(),
    this.watchId = const Value.absent(),
    this.eventType = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.reason = const Value.absent(),
    this.details = const Value.absent(),
    this.sessionId = const Value.absent(),
  });
  ConnectionEventsCompanion.insert({
    this.id = const Value.absent(),
    required String watchId,
    required String eventType,
    required DateTime timestamp,
    this.reason = const Value.absent(),
    this.details = const Value.absent(),
    this.sessionId = const Value.absent(),
  }) : watchId = Value(watchId),
       eventType = Value(eventType),
       timestamp = Value(timestamp);
  static Insertable<ConnectionEventEntity> custom({
    Expression<int>? id,
    Expression<String>? watchId,
    Expression<String>? eventType,
    Expression<DateTime>? timestamp,
    Expression<String>? reason,
    Expression<String>? details,
    Expression<String>? sessionId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (watchId != null) 'watch_id': watchId,
      if (eventType != null) 'event_type': eventType,
      if (timestamp != null) 'timestamp': timestamp,
      if (reason != null) 'reason': reason,
      if (details != null) 'details': details,
      if (sessionId != null) 'session_id': sessionId,
    });
  }

  ConnectionEventsCompanion copyWith({
    Value<int>? id,
    Value<String>? watchId,
    Value<String>? eventType,
    Value<DateTime>? timestamp,
    Value<String?>? reason,
    Value<String?>? details,
    Value<String?>? sessionId,
  }) {
    return ConnectionEventsCompanion(
      id: id ?? this.id,
      watchId: watchId ?? this.watchId,
      eventType: eventType ?? this.eventType,
      timestamp: timestamp ?? this.timestamp,
      reason: reason ?? this.reason,
      details: details ?? this.details,
      sessionId: sessionId ?? this.sessionId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (watchId.present) {
      map['watch_id'] = Variable<String>(watchId.value);
    }
    if (eventType.present) {
      map['event_type'] = Variable<String>(eventType.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (details.present) {
      map['details'] = Variable<String>(details.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConnectionEventsCompanion(')
          ..write('id: $id, ')
          ..write('watchId: $watchId, ')
          ..write('eventType: $eventType, ')
          ..write('timestamp: $timestamp, ')
          ..write('reason: $reason, ')
          ..write('details: $details, ')
          ..write('sessionId: $sessionId')
          ..write(')'))
        .toString();
  }
}

class $VoiceMemosTable extends VoiceMemos
    with TableInfo<$VoiceMemosTable, VoiceMemoEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VoiceMemosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
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
  static const VerificationMeta _localFilePathMeta = const VerificationMeta(
    'localFilePath',
  );
  @override
  late final GeneratedColumn<String> localFilePath = GeneratedColumn<String>(
    'local_file_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _transcriptionMeta = const VerificationMeta(
    'transcription',
  );
  @override
  late final GeneratedColumn<String> transcription = GeneratedColumn<String>(
    'transcription',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncedFromWatchMeta = const VerificationMeta(
    'syncedFromWatch',
  );
  @override
  late final GeneratedColumn<bool> syncedFromWatch = GeneratedColumn<bool>(
    'synced_from_watch',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("synced_from_watch" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _deletedOnWatchMeta = const VerificationMeta(
    'deletedOnWatch',
  );
  @override
  late final GeneratedColumn<bool> deletedOnWatch = GeneratedColumn<bool>(
    'deleted_on_watch',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted_on_watch" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _downloadedAtMeta = const VerificationMeta(
    'downloadedAt',
  );
  @override
  late final GeneratedColumn<DateTime> downloadedAt = GeneratedColumn<DateTime>(
    'downloaded_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _transcribedAtMeta = const VerificationMeta(
    'transcribedAt',
  );
  @override
  late final GeneratedColumn<DateTime> transcribedAt =
      GeneratedColumn<DateTime>(
        'transcribed_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _convertedFilePathMeta = const VerificationMeta(
    'convertedFilePath',
  );
  @override
  late final GeneratedColumn<String> convertedFilePath =
      GeneratedColumn<String>(
        'converted_file_path',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _summaryMeta = const VerificationMeta(
    'summary',
  );
  @override
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
    'summary',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _processingStatusMeta = const VerificationMeta(
    'processingStatus',
  );
  @override
  late final GeneratedColumn<String> processingStatus = GeneratedColumn<String>(
    'processing_status',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _aiModelMeta = const VerificationMeta(
    'aiModel',
  );
  @override
  late final GeneratedColumn<String> aiModel = GeneratedColumn<String>(
    'ai_model',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _aiProcessedAtMeta = const VerificationMeta(
    'aiProcessedAt',
  );
  @override
  late final GeneratedColumn<DateTime> aiProcessedAt =
      GeneratedColumn<DateTime>(
        'ai_processed_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _taskCreatedMeta = const VerificationMeta(
    'taskCreated',
  );
  @override
  late final GeneratedColumn<bool> taskCreated = GeneratedColumn<bool>(
    'task_created',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("task_created" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _calendarEventCreatedMeta =
      const VerificationMeta('calendarEventCreated');
  @override
  late final GeneratedColumn<bool> calendarEventCreated = GeneratedColumn<bool>(
    'calendar_event_created',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("calendar_event_created" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _actionReviewStateMeta = const VerificationMeta(
    'actionReviewState',
  );
  @override
  late final GeneratedColumn<String> actionReviewState =
      GeneratedColumn<String>(
        'action_review_state',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    filename,
    timestampUtc,
    durationMs,
    sizeBytes,
    localFilePath,
    transcription,
    syncedFromWatch,
    deletedOnWatch,
    downloadedAt,
    transcribedAt,
    convertedFilePath,
    summary,
    category,
    processingStatus,
    aiModel,
    aiProcessedAt,
    taskCreated,
    calendarEventCreated,
    actionReviewState,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'voice_memos';
  @override
  VerificationContext validateIntegrity(
    Insertable<VoiceMemoEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
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
    if (data.containsKey('local_file_path')) {
      context.handle(
        _localFilePathMeta,
        localFilePath.isAcceptableOrUnknown(
          data['local_file_path']!,
          _localFilePathMeta,
        ),
      );
    }
    if (data.containsKey('transcription')) {
      context.handle(
        _transcriptionMeta,
        transcription.isAcceptableOrUnknown(
          data['transcription']!,
          _transcriptionMeta,
        ),
      );
    }
    if (data.containsKey('synced_from_watch')) {
      context.handle(
        _syncedFromWatchMeta,
        syncedFromWatch.isAcceptableOrUnknown(
          data['synced_from_watch']!,
          _syncedFromWatchMeta,
        ),
      );
    }
    if (data.containsKey('deleted_on_watch')) {
      context.handle(
        _deletedOnWatchMeta,
        deletedOnWatch.isAcceptableOrUnknown(
          data['deleted_on_watch']!,
          _deletedOnWatchMeta,
        ),
      );
    }
    if (data.containsKey('downloaded_at')) {
      context.handle(
        _downloadedAtMeta,
        downloadedAt.isAcceptableOrUnknown(
          data['downloaded_at']!,
          _downloadedAtMeta,
        ),
      );
    }
    if (data.containsKey('transcribed_at')) {
      context.handle(
        _transcribedAtMeta,
        transcribedAt.isAcceptableOrUnknown(
          data['transcribed_at']!,
          _transcribedAtMeta,
        ),
      );
    }
    if (data.containsKey('converted_file_path')) {
      context.handle(
        _convertedFilePathMeta,
        convertedFilePath.isAcceptableOrUnknown(
          data['converted_file_path']!,
          _convertedFilePathMeta,
        ),
      );
    }
    if (data.containsKey('summary')) {
      context.handle(
        _summaryMeta,
        summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta),
      );
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('processing_status')) {
      context.handle(
        _processingStatusMeta,
        processingStatus.isAcceptableOrUnknown(
          data['processing_status']!,
          _processingStatusMeta,
        ),
      );
    }
    if (data.containsKey('ai_model')) {
      context.handle(
        _aiModelMeta,
        aiModel.isAcceptableOrUnknown(data['ai_model']!, _aiModelMeta),
      );
    }
    if (data.containsKey('ai_processed_at')) {
      context.handle(
        _aiProcessedAtMeta,
        aiProcessedAt.isAcceptableOrUnknown(
          data['ai_processed_at']!,
          _aiProcessedAtMeta,
        ),
      );
    }
    if (data.containsKey('task_created')) {
      context.handle(
        _taskCreatedMeta,
        taskCreated.isAcceptableOrUnknown(
          data['task_created']!,
          _taskCreatedMeta,
        ),
      );
    }
    if (data.containsKey('calendar_event_created')) {
      context.handle(
        _calendarEventCreatedMeta,
        calendarEventCreated.isAcceptableOrUnknown(
          data['calendar_event_created']!,
          _calendarEventCreatedMeta,
        ),
      );
    }
    if (data.containsKey('action_review_state')) {
      context.handle(
        _actionReviewStateMeta,
        actionReviewState.isAcceptableOrUnknown(
          data['action_review_state']!,
          _actionReviewStateMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VoiceMemoEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VoiceMemoEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
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
      localFilePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_file_path'],
      ),
      transcription: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transcription'],
      ),
      syncedFromWatch: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}synced_from_watch'],
      )!,
      deletedOnWatch: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted_on_watch'],
      )!,
      downloadedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}downloaded_at'],
      ),
      transcribedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}transcribed_at'],
      ),
      convertedFilePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}converted_file_path'],
      ),
      summary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary'],
      ),
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      ),
      processingStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}processing_status'],
      ),
      aiModel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ai_model'],
      ),
      aiProcessedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ai_processed_at'],
      ),
      taskCreated: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}task_created'],
      )!,
      calendarEventCreated: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}calendar_event_created'],
      )!,
      actionReviewState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action_review_state'],
      ),
    );
  }

  @override
  $VoiceMemosTable createAlias(String alias) {
    return $VoiceMemosTable(attachedDatabase, alias);
  }
}

class VoiceMemoEntity extends DataClass implements Insertable<VoiceMemoEntity> {
  /// Auto-incrementing row identifier
  final int id;

  /// Original filename on the watch (e.g., "20260304_143022")
  final String filename;

  /// Recording timestamp as Unix epoch seconds (UTC)
  final int timestampUtc;

  /// Recording duration in milliseconds
  final int durationMs;

  /// File size in bytes (Opus-encoded .zsw_opus)
  final int sizeBytes;

  /// Local file path after download (null = not yet downloaded)
  final String? localFilePath;

  /// Transcription text (null = not yet transcribed)
  final String? transcription;

  /// Whether the file has been synced (downloaded) from the watch
  final bool syncedFromWatch;

  /// Whether the file has been deleted on the watch after sync
  final bool deletedOnWatch;

  /// When the file was downloaded to the phone
  final DateTime? downloadedAt;

  /// When the transcription was completed
  final DateTime? transcribedAt;

  /// Path to converted audio file (WAV/Ogg) for playback/transcription
  final String? convertedFilePath;

  /// AI-generated summary of the voice note
  final String? summary;

  /// AI-assigned category: 'idea', 'task', 'reminder', 'meeting', 'note'
  final String? category;

  /// Current AI processing status: 'pending', 'summarizing', 'categorizing',
  /// 'extractingActions', 'ready', 'failed'
  final String? processingStatus;

  /// Which AI model was used for processing
  final String? aiModel;

  /// When AI processing completed
  final DateTime? aiProcessedAt;

  /// Whether a task has been created from this memo's suggestions
  final bool taskCreated;

  /// Whether a calendar event has been created from this memo's suggestions
  final bool calendarEventCreated;

  /// Review state for extracted actions: 'pending', 'reviewed', 'dismissed'
  final String? actionReviewState;
  const VoiceMemoEntity({
    required this.id,
    required this.filename,
    required this.timestampUtc,
    required this.durationMs,
    required this.sizeBytes,
    this.localFilePath,
    this.transcription,
    required this.syncedFromWatch,
    required this.deletedOnWatch,
    this.downloadedAt,
    this.transcribedAt,
    this.convertedFilePath,
    this.summary,
    this.category,
    this.processingStatus,
    this.aiModel,
    this.aiProcessedAt,
    required this.taskCreated,
    required this.calendarEventCreated,
    this.actionReviewState,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['filename'] = Variable<String>(filename);
    map['timestamp_utc'] = Variable<int>(timestampUtc);
    map['duration_ms'] = Variable<int>(durationMs);
    map['size_bytes'] = Variable<int>(sizeBytes);
    if (!nullToAbsent || localFilePath != null) {
      map['local_file_path'] = Variable<String>(localFilePath);
    }
    if (!nullToAbsent || transcription != null) {
      map['transcription'] = Variable<String>(transcription);
    }
    map['synced_from_watch'] = Variable<bool>(syncedFromWatch);
    map['deleted_on_watch'] = Variable<bool>(deletedOnWatch);
    if (!nullToAbsent || downloadedAt != null) {
      map['downloaded_at'] = Variable<DateTime>(downloadedAt);
    }
    if (!nullToAbsent || transcribedAt != null) {
      map['transcribed_at'] = Variable<DateTime>(transcribedAt);
    }
    if (!nullToAbsent || convertedFilePath != null) {
      map['converted_file_path'] = Variable<String>(convertedFilePath);
    }
    if (!nullToAbsent || summary != null) {
      map['summary'] = Variable<String>(summary);
    }
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    if (!nullToAbsent || processingStatus != null) {
      map['processing_status'] = Variable<String>(processingStatus);
    }
    if (!nullToAbsent || aiModel != null) {
      map['ai_model'] = Variable<String>(aiModel);
    }
    if (!nullToAbsent || aiProcessedAt != null) {
      map['ai_processed_at'] = Variable<DateTime>(aiProcessedAt);
    }
    map['task_created'] = Variable<bool>(taskCreated);
    map['calendar_event_created'] = Variable<bool>(calendarEventCreated);
    if (!nullToAbsent || actionReviewState != null) {
      map['action_review_state'] = Variable<String>(actionReviewState);
    }
    return map;
  }

  VoiceMemosCompanion toCompanion(bool nullToAbsent) {
    return VoiceMemosCompanion(
      id: Value(id),
      filename: Value(filename),
      timestampUtc: Value(timestampUtc),
      durationMs: Value(durationMs),
      sizeBytes: Value(sizeBytes),
      localFilePath: localFilePath == null && nullToAbsent
          ? const Value.absent()
          : Value(localFilePath),
      transcription: transcription == null && nullToAbsent
          ? const Value.absent()
          : Value(transcription),
      syncedFromWatch: Value(syncedFromWatch),
      deletedOnWatch: Value(deletedOnWatch),
      downloadedAt: downloadedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(downloadedAt),
      transcribedAt: transcribedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(transcribedAt),
      convertedFilePath: convertedFilePath == null && nullToAbsent
          ? const Value.absent()
          : Value(convertedFilePath),
      summary: summary == null && nullToAbsent
          ? const Value.absent()
          : Value(summary),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
      processingStatus: processingStatus == null && nullToAbsent
          ? const Value.absent()
          : Value(processingStatus),
      aiModel: aiModel == null && nullToAbsent
          ? const Value.absent()
          : Value(aiModel),
      aiProcessedAt: aiProcessedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(aiProcessedAt),
      taskCreated: Value(taskCreated),
      calendarEventCreated: Value(calendarEventCreated),
      actionReviewState: actionReviewState == null && nullToAbsent
          ? const Value.absent()
          : Value(actionReviewState),
    );
  }

  factory VoiceMemoEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VoiceMemoEntity(
      id: serializer.fromJson<int>(json['id']),
      filename: serializer.fromJson<String>(json['filename']),
      timestampUtc: serializer.fromJson<int>(json['timestampUtc']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      sizeBytes: serializer.fromJson<int>(json['sizeBytes']),
      localFilePath: serializer.fromJson<String?>(json['localFilePath']),
      transcription: serializer.fromJson<String?>(json['transcription']),
      syncedFromWatch: serializer.fromJson<bool>(json['syncedFromWatch']),
      deletedOnWatch: serializer.fromJson<bool>(json['deletedOnWatch']),
      downloadedAt: serializer.fromJson<DateTime?>(json['downloadedAt']),
      transcribedAt: serializer.fromJson<DateTime?>(json['transcribedAt']),
      convertedFilePath: serializer.fromJson<String?>(
        json['convertedFilePath'],
      ),
      summary: serializer.fromJson<String?>(json['summary']),
      category: serializer.fromJson<String?>(json['category']),
      processingStatus: serializer.fromJson<String?>(json['processingStatus']),
      aiModel: serializer.fromJson<String?>(json['aiModel']),
      aiProcessedAt: serializer.fromJson<DateTime?>(json['aiProcessedAt']),
      taskCreated: serializer.fromJson<bool>(json['taskCreated']),
      calendarEventCreated: serializer.fromJson<bool>(
        json['calendarEventCreated'],
      ),
      actionReviewState: serializer.fromJson<String?>(
        json['actionReviewState'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'filename': serializer.toJson<String>(filename),
      'timestampUtc': serializer.toJson<int>(timestampUtc),
      'durationMs': serializer.toJson<int>(durationMs),
      'sizeBytes': serializer.toJson<int>(sizeBytes),
      'localFilePath': serializer.toJson<String?>(localFilePath),
      'transcription': serializer.toJson<String?>(transcription),
      'syncedFromWatch': serializer.toJson<bool>(syncedFromWatch),
      'deletedOnWatch': serializer.toJson<bool>(deletedOnWatch),
      'downloadedAt': serializer.toJson<DateTime?>(downloadedAt),
      'transcribedAt': serializer.toJson<DateTime?>(transcribedAt),
      'convertedFilePath': serializer.toJson<String?>(convertedFilePath),
      'summary': serializer.toJson<String?>(summary),
      'category': serializer.toJson<String?>(category),
      'processingStatus': serializer.toJson<String?>(processingStatus),
      'aiModel': serializer.toJson<String?>(aiModel),
      'aiProcessedAt': serializer.toJson<DateTime?>(aiProcessedAt),
      'taskCreated': serializer.toJson<bool>(taskCreated),
      'calendarEventCreated': serializer.toJson<bool>(calendarEventCreated),
      'actionReviewState': serializer.toJson<String?>(actionReviewState),
    };
  }

  VoiceMemoEntity copyWith({
    int? id,
    String? filename,
    int? timestampUtc,
    int? durationMs,
    int? sizeBytes,
    Value<String?> localFilePath = const Value.absent(),
    Value<String?> transcription = const Value.absent(),
    bool? syncedFromWatch,
    bool? deletedOnWatch,
    Value<DateTime?> downloadedAt = const Value.absent(),
    Value<DateTime?> transcribedAt = const Value.absent(),
    Value<String?> convertedFilePath = const Value.absent(),
    Value<String?> summary = const Value.absent(),
    Value<String?> category = const Value.absent(),
    Value<String?> processingStatus = const Value.absent(),
    Value<String?> aiModel = const Value.absent(),
    Value<DateTime?> aiProcessedAt = const Value.absent(),
    bool? taskCreated,
    bool? calendarEventCreated,
    Value<String?> actionReviewState = const Value.absent(),
  }) => VoiceMemoEntity(
    id: id ?? this.id,
    filename: filename ?? this.filename,
    timestampUtc: timestampUtc ?? this.timestampUtc,
    durationMs: durationMs ?? this.durationMs,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    localFilePath: localFilePath.present
        ? localFilePath.value
        : this.localFilePath,
    transcription: transcription.present
        ? transcription.value
        : this.transcription,
    syncedFromWatch: syncedFromWatch ?? this.syncedFromWatch,
    deletedOnWatch: deletedOnWatch ?? this.deletedOnWatch,
    downloadedAt: downloadedAt.present ? downloadedAt.value : this.downloadedAt,
    transcribedAt: transcribedAt.present
        ? transcribedAt.value
        : this.transcribedAt,
    convertedFilePath: convertedFilePath.present
        ? convertedFilePath.value
        : this.convertedFilePath,
    summary: summary.present ? summary.value : this.summary,
    category: category.present ? category.value : this.category,
    processingStatus: processingStatus.present
        ? processingStatus.value
        : this.processingStatus,
    aiModel: aiModel.present ? aiModel.value : this.aiModel,
    aiProcessedAt: aiProcessedAt.present
        ? aiProcessedAt.value
        : this.aiProcessedAt,
    taskCreated: taskCreated ?? this.taskCreated,
    calendarEventCreated: calendarEventCreated ?? this.calendarEventCreated,
    actionReviewState: actionReviewState.present
        ? actionReviewState.value
        : this.actionReviewState,
  );
  VoiceMemoEntity copyWithCompanion(VoiceMemosCompanion data) {
    return VoiceMemoEntity(
      id: data.id.present ? data.id.value : this.id,
      filename: data.filename.present ? data.filename.value : this.filename,
      timestampUtc: data.timestampUtc.present
          ? data.timestampUtc.value
          : this.timestampUtc,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      localFilePath: data.localFilePath.present
          ? data.localFilePath.value
          : this.localFilePath,
      transcription: data.transcription.present
          ? data.transcription.value
          : this.transcription,
      syncedFromWatch: data.syncedFromWatch.present
          ? data.syncedFromWatch.value
          : this.syncedFromWatch,
      deletedOnWatch: data.deletedOnWatch.present
          ? data.deletedOnWatch.value
          : this.deletedOnWatch,
      downloadedAt: data.downloadedAt.present
          ? data.downloadedAt.value
          : this.downloadedAt,
      transcribedAt: data.transcribedAt.present
          ? data.transcribedAt.value
          : this.transcribedAt,
      convertedFilePath: data.convertedFilePath.present
          ? data.convertedFilePath.value
          : this.convertedFilePath,
      summary: data.summary.present ? data.summary.value : this.summary,
      category: data.category.present ? data.category.value : this.category,
      processingStatus: data.processingStatus.present
          ? data.processingStatus.value
          : this.processingStatus,
      aiModel: data.aiModel.present ? data.aiModel.value : this.aiModel,
      aiProcessedAt: data.aiProcessedAt.present
          ? data.aiProcessedAt.value
          : this.aiProcessedAt,
      taskCreated: data.taskCreated.present
          ? data.taskCreated.value
          : this.taskCreated,
      calendarEventCreated: data.calendarEventCreated.present
          ? data.calendarEventCreated.value
          : this.calendarEventCreated,
      actionReviewState: data.actionReviewState.present
          ? data.actionReviewState.value
          : this.actionReviewState,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VoiceMemoEntity(')
          ..write('id: $id, ')
          ..write('filename: $filename, ')
          ..write('timestampUtc: $timestampUtc, ')
          ..write('durationMs: $durationMs, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('localFilePath: $localFilePath, ')
          ..write('transcription: $transcription, ')
          ..write('syncedFromWatch: $syncedFromWatch, ')
          ..write('deletedOnWatch: $deletedOnWatch, ')
          ..write('downloadedAt: $downloadedAt, ')
          ..write('transcribedAt: $transcribedAt, ')
          ..write('convertedFilePath: $convertedFilePath, ')
          ..write('summary: $summary, ')
          ..write('category: $category, ')
          ..write('processingStatus: $processingStatus, ')
          ..write('aiModel: $aiModel, ')
          ..write('aiProcessedAt: $aiProcessedAt, ')
          ..write('taskCreated: $taskCreated, ')
          ..write('calendarEventCreated: $calendarEventCreated, ')
          ..write('actionReviewState: $actionReviewState')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    filename,
    timestampUtc,
    durationMs,
    sizeBytes,
    localFilePath,
    transcription,
    syncedFromWatch,
    deletedOnWatch,
    downloadedAt,
    transcribedAt,
    convertedFilePath,
    summary,
    category,
    processingStatus,
    aiModel,
    aiProcessedAt,
    taskCreated,
    calendarEventCreated,
    actionReviewState,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VoiceMemoEntity &&
          other.id == this.id &&
          other.filename == this.filename &&
          other.timestampUtc == this.timestampUtc &&
          other.durationMs == this.durationMs &&
          other.sizeBytes == this.sizeBytes &&
          other.localFilePath == this.localFilePath &&
          other.transcription == this.transcription &&
          other.syncedFromWatch == this.syncedFromWatch &&
          other.deletedOnWatch == this.deletedOnWatch &&
          other.downloadedAt == this.downloadedAt &&
          other.transcribedAt == this.transcribedAt &&
          other.convertedFilePath == this.convertedFilePath &&
          other.summary == this.summary &&
          other.category == this.category &&
          other.processingStatus == this.processingStatus &&
          other.aiModel == this.aiModel &&
          other.aiProcessedAt == this.aiProcessedAt &&
          other.taskCreated == this.taskCreated &&
          other.calendarEventCreated == this.calendarEventCreated &&
          other.actionReviewState == this.actionReviewState);
}

class VoiceMemosCompanion extends UpdateCompanion<VoiceMemoEntity> {
  final Value<int> id;
  final Value<String> filename;
  final Value<int> timestampUtc;
  final Value<int> durationMs;
  final Value<int> sizeBytes;
  final Value<String?> localFilePath;
  final Value<String?> transcription;
  final Value<bool> syncedFromWatch;
  final Value<bool> deletedOnWatch;
  final Value<DateTime?> downloadedAt;
  final Value<DateTime?> transcribedAt;
  final Value<String?> convertedFilePath;
  final Value<String?> summary;
  final Value<String?> category;
  final Value<String?> processingStatus;
  final Value<String?> aiModel;
  final Value<DateTime?> aiProcessedAt;
  final Value<bool> taskCreated;
  final Value<bool> calendarEventCreated;
  final Value<String?> actionReviewState;
  const VoiceMemosCompanion({
    this.id = const Value.absent(),
    this.filename = const Value.absent(),
    this.timestampUtc = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.localFilePath = const Value.absent(),
    this.transcription = const Value.absent(),
    this.syncedFromWatch = const Value.absent(),
    this.deletedOnWatch = const Value.absent(),
    this.downloadedAt = const Value.absent(),
    this.transcribedAt = const Value.absent(),
    this.convertedFilePath = const Value.absent(),
    this.summary = const Value.absent(),
    this.category = const Value.absent(),
    this.processingStatus = const Value.absent(),
    this.aiModel = const Value.absent(),
    this.aiProcessedAt = const Value.absent(),
    this.taskCreated = const Value.absent(),
    this.calendarEventCreated = const Value.absent(),
    this.actionReviewState = const Value.absent(),
  });
  VoiceMemosCompanion.insert({
    this.id = const Value.absent(),
    required String filename,
    required int timestampUtc,
    required int durationMs,
    required int sizeBytes,
    this.localFilePath = const Value.absent(),
    this.transcription = const Value.absent(),
    this.syncedFromWatch = const Value.absent(),
    this.deletedOnWatch = const Value.absent(),
    this.downloadedAt = const Value.absent(),
    this.transcribedAt = const Value.absent(),
    this.convertedFilePath = const Value.absent(),
    this.summary = const Value.absent(),
    this.category = const Value.absent(),
    this.processingStatus = const Value.absent(),
    this.aiModel = const Value.absent(),
    this.aiProcessedAt = const Value.absent(),
    this.taskCreated = const Value.absent(),
    this.calendarEventCreated = const Value.absent(),
    this.actionReviewState = const Value.absent(),
  }) : filename = Value(filename),
       timestampUtc = Value(timestampUtc),
       durationMs = Value(durationMs),
       sizeBytes = Value(sizeBytes);
  static Insertable<VoiceMemoEntity> custom({
    Expression<int>? id,
    Expression<String>? filename,
    Expression<int>? timestampUtc,
    Expression<int>? durationMs,
    Expression<int>? sizeBytes,
    Expression<String>? localFilePath,
    Expression<String>? transcription,
    Expression<bool>? syncedFromWatch,
    Expression<bool>? deletedOnWatch,
    Expression<DateTime>? downloadedAt,
    Expression<DateTime>? transcribedAt,
    Expression<String>? convertedFilePath,
    Expression<String>? summary,
    Expression<String>? category,
    Expression<String>? processingStatus,
    Expression<String>? aiModel,
    Expression<DateTime>? aiProcessedAt,
    Expression<bool>? taskCreated,
    Expression<bool>? calendarEventCreated,
    Expression<String>? actionReviewState,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (filename != null) 'filename': filename,
      if (timestampUtc != null) 'timestamp_utc': timestampUtc,
      if (durationMs != null) 'duration_ms': durationMs,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (localFilePath != null) 'local_file_path': localFilePath,
      if (transcription != null) 'transcription': transcription,
      if (syncedFromWatch != null) 'synced_from_watch': syncedFromWatch,
      if (deletedOnWatch != null) 'deleted_on_watch': deletedOnWatch,
      if (downloadedAt != null) 'downloaded_at': downloadedAt,
      if (transcribedAt != null) 'transcribed_at': transcribedAt,
      if (convertedFilePath != null) 'converted_file_path': convertedFilePath,
      if (summary != null) 'summary': summary,
      if (category != null) 'category': category,
      if (processingStatus != null) 'processing_status': processingStatus,
      if (aiModel != null) 'ai_model': aiModel,
      if (aiProcessedAt != null) 'ai_processed_at': aiProcessedAt,
      if (taskCreated != null) 'task_created': taskCreated,
      if (calendarEventCreated != null)
        'calendar_event_created': calendarEventCreated,
      if (actionReviewState != null) 'action_review_state': actionReviewState,
    });
  }

  VoiceMemosCompanion copyWith({
    Value<int>? id,
    Value<String>? filename,
    Value<int>? timestampUtc,
    Value<int>? durationMs,
    Value<int>? sizeBytes,
    Value<String?>? localFilePath,
    Value<String?>? transcription,
    Value<bool>? syncedFromWatch,
    Value<bool>? deletedOnWatch,
    Value<DateTime?>? downloadedAt,
    Value<DateTime?>? transcribedAt,
    Value<String?>? convertedFilePath,
    Value<String?>? summary,
    Value<String?>? category,
    Value<String?>? processingStatus,
    Value<String?>? aiModel,
    Value<DateTime?>? aiProcessedAt,
    Value<bool>? taskCreated,
    Value<bool>? calendarEventCreated,
    Value<String?>? actionReviewState,
  }) {
    return VoiceMemosCompanion(
      id: id ?? this.id,
      filename: filename ?? this.filename,
      timestampUtc: timestampUtc ?? this.timestampUtc,
      durationMs: durationMs ?? this.durationMs,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      localFilePath: localFilePath ?? this.localFilePath,
      transcription: transcription ?? this.transcription,
      syncedFromWatch: syncedFromWatch ?? this.syncedFromWatch,
      deletedOnWatch: deletedOnWatch ?? this.deletedOnWatch,
      downloadedAt: downloadedAt ?? this.downloadedAt,
      transcribedAt: transcribedAt ?? this.transcribedAt,
      convertedFilePath: convertedFilePath ?? this.convertedFilePath,
      summary: summary ?? this.summary,
      category: category ?? this.category,
      processingStatus: processingStatus ?? this.processingStatus,
      aiModel: aiModel ?? this.aiModel,
      aiProcessedAt: aiProcessedAt ?? this.aiProcessedAt,
      taskCreated: taskCreated ?? this.taskCreated,
      calendarEventCreated: calendarEventCreated ?? this.calendarEventCreated,
      actionReviewState: actionReviewState ?? this.actionReviewState,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
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
    if (localFilePath.present) {
      map['local_file_path'] = Variable<String>(localFilePath.value);
    }
    if (transcription.present) {
      map['transcription'] = Variable<String>(transcription.value);
    }
    if (syncedFromWatch.present) {
      map['synced_from_watch'] = Variable<bool>(syncedFromWatch.value);
    }
    if (deletedOnWatch.present) {
      map['deleted_on_watch'] = Variable<bool>(deletedOnWatch.value);
    }
    if (downloadedAt.present) {
      map['downloaded_at'] = Variable<DateTime>(downloadedAt.value);
    }
    if (transcribedAt.present) {
      map['transcribed_at'] = Variable<DateTime>(transcribedAt.value);
    }
    if (convertedFilePath.present) {
      map['converted_file_path'] = Variable<String>(convertedFilePath.value);
    }
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (processingStatus.present) {
      map['processing_status'] = Variable<String>(processingStatus.value);
    }
    if (aiModel.present) {
      map['ai_model'] = Variable<String>(aiModel.value);
    }
    if (aiProcessedAt.present) {
      map['ai_processed_at'] = Variable<DateTime>(aiProcessedAt.value);
    }
    if (taskCreated.present) {
      map['task_created'] = Variable<bool>(taskCreated.value);
    }
    if (calendarEventCreated.present) {
      map['calendar_event_created'] = Variable<bool>(
        calendarEventCreated.value,
      );
    }
    if (actionReviewState.present) {
      map['action_review_state'] = Variable<String>(actionReviewState.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VoiceMemosCompanion(')
          ..write('id: $id, ')
          ..write('filename: $filename, ')
          ..write('timestampUtc: $timestampUtc, ')
          ..write('durationMs: $durationMs, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('localFilePath: $localFilePath, ')
          ..write('transcription: $transcription, ')
          ..write('syncedFromWatch: $syncedFromWatch, ')
          ..write('deletedOnWatch: $deletedOnWatch, ')
          ..write('downloadedAt: $downloadedAt, ')
          ..write('transcribedAt: $transcribedAt, ')
          ..write('convertedFilePath: $convertedFilePath, ')
          ..write('summary: $summary, ')
          ..write('category: $category, ')
          ..write('processingStatus: $processingStatus, ')
          ..write('aiModel: $aiModel, ')
          ..write('aiProcessedAt: $aiProcessedAt, ')
          ..write('taskCreated: $taskCreated, ')
          ..write('calendarEventCreated: $calendarEventCreated, ')
          ..write('actionReviewState: $actionReviewState')
          ..write(')'))
        .toString();
  }
}

class $ExtractedActionsTable extends ExtractedActions
    with TableInfo<$ExtractedActionsTable, ExtractedActionEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExtractedActionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _memoIdMeta = const VerificationMeta('memoId');
  @override
  late final GeneratedColumn<int> memoId = GeneratedColumn<int>(
    'memo_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actionTypeMeta = const VerificationMeta(
    'actionType',
  );
  @override
  late final GeneratedColumn<String> actionType = GeneratedColumn<String>(
    'action_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startTimeMeta = const VerificationMeta(
    'startTime',
  );
  @override
  late final GeneratedColumn<DateTime> startTime = GeneratedColumn<DateTime>(
    'start_time',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endTimeMeta = const VerificationMeta(
    'endTime',
  );
  @override
  late final GeneratedColumn<DateTime> endTime = GeneratedColumn<DateTime>(
    'end_time',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dueDateMeta = const VerificationMeta(
    'dueDate',
  );
  @override
  late final GeneratedColumn<DateTime> dueDate = GeneratedColumn<DateTime>(
    'due_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _locationMeta = const VerificationMeta(
    'location',
  );
  @override
  late final GeneratedColumn<String> location = GeneratedColumn<String>(
    'location',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reminderMinutesMeta = const VerificationMeta(
    'reminderMinutes',
  );
  @override
  late final GeneratedColumn<int> reminderMinutes = GeneratedColumn<int>(
    'reminder_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdMeta = const VerificationMeta(
    'created',
  );
  @override
  late final GeneratedColumn<bool> created = GeneratedColumn<bool>(
    'created',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("created" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _dismissedMeta = const VerificationMeta(
    'dismissed',
  );
  @override
  late final GeneratedColumn<bool> dismissed = GeneratedColumn<bool>(
    'dismissed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dismissed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _platformTargetIdMeta = const VerificationMeta(
    'platformTargetId',
  );
  @override
  late final GeneratedColumn<String> platformTargetId = GeneratedColumn<String>(
    'platform_target_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationSecondsMeta = const VerificationMeta(
    'durationSeconds',
  );
  @override
  late final GeneratedColumn<int> durationSeconds = GeneratedColumn<int>(
    'duration_seconds',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    memoId,
    actionType,
    title,
    notes,
    startTime,
    endTime,
    dueDate,
    location,
    reminderMinutes,
    created,
    dismissed,
    platformTargetId,
    durationSeconds,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'extracted_actions';
  @override
  VerificationContext validateIntegrity(
    Insertable<ExtractedActionEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('memo_id')) {
      context.handle(
        _memoIdMeta,
        memoId.isAcceptableOrUnknown(data['memo_id']!, _memoIdMeta),
      );
    } else if (isInserting) {
      context.missing(_memoIdMeta);
    }
    if (data.containsKey('action_type')) {
      context.handle(
        _actionTypeMeta,
        actionType.isAcceptableOrUnknown(data['action_type']!, _actionTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_actionTypeMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('start_time')) {
      context.handle(
        _startTimeMeta,
        startTime.isAcceptableOrUnknown(data['start_time']!, _startTimeMeta),
      );
    }
    if (data.containsKey('end_time')) {
      context.handle(
        _endTimeMeta,
        endTime.isAcceptableOrUnknown(data['end_time']!, _endTimeMeta),
      );
    }
    if (data.containsKey('due_date')) {
      context.handle(
        _dueDateMeta,
        dueDate.isAcceptableOrUnknown(data['due_date']!, _dueDateMeta),
      );
    }
    if (data.containsKey('location')) {
      context.handle(
        _locationMeta,
        location.isAcceptableOrUnknown(data['location']!, _locationMeta),
      );
    }
    if (data.containsKey('reminder_minutes')) {
      context.handle(
        _reminderMinutesMeta,
        reminderMinutes.isAcceptableOrUnknown(
          data['reminder_minutes']!,
          _reminderMinutesMeta,
        ),
      );
    }
    if (data.containsKey('created')) {
      context.handle(
        _createdMeta,
        created.isAcceptableOrUnknown(data['created']!, _createdMeta),
      );
    }
    if (data.containsKey('dismissed')) {
      context.handle(
        _dismissedMeta,
        dismissed.isAcceptableOrUnknown(data['dismissed']!, _dismissedMeta),
      );
    }
    if (data.containsKey('platform_target_id')) {
      context.handle(
        _platformTargetIdMeta,
        platformTargetId.isAcceptableOrUnknown(
          data['platform_target_id']!,
          _platformTargetIdMeta,
        ),
      );
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
        _durationSecondsMeta,
        durationSeconds.isAcceptableOrUnknown(
          data['duration_seconds']!,
          _durationSecondsMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ExtractedActionEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExtractedActionEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      memoId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}memo_id'],
      )!,
      actionType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action_type'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      startTime: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_time'],
      ),
      endTime: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}end_time'],
      ),
      dueDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}due_date'],
      ),
      location: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location'],
      ),
      reminderMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reminder_minutes'],
      ),
      created: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}created'],
      )!,
      dismissed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dismissed'],
      )!,
      platformTargetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}platform_target_id'],
      ),
      durationSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_seconds'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      ),
    );
  }

  @override
  $ExtractedActionsTable createAlias(String alias) {
    return $ExtractedActionsTable(attachedDatabase, alias);
  }
}

class ExtractedActionEntity extends DataClass
    implements Insertable<ExtractedActionEntity> {
  /// Auto-incrementing row identifier
  final int id;

  /// Foreign key to the parent voice memo
  final int memoId;

  /// Action type: 'task', 'calendar_event', 'reminder'
  final String actionType;

  /// AI-generated title for the action
  final String title;

  /// Optional notes / body text
  final String? notes;

  /// Suggested start time (for calendar events)
  final DateTime? startTime;

  /// Suggested end time (for calendar events)
  final DateTime? endTime;

  /// Suggested due date (for tasks / reminders)
  final DateTime? dueDate;

  /// Optional location
  final String? location;

  /// Reminder offset in minutes before the event
  final int? reminderMinutes;

  /// Whether this action has been created in the OS (calendar / reminders)
  final bool created;

  /// Whether the user dismissed this suggestion
  final bool dismissed;

  /// Platform-specific ID after creation (e.g. calendar event ID)
  final String? platformTargetId;

  /// Duration in seconds (for timer actions)
  final int? durationSeconds;

  /// When this action was created in the OS
  final DateTime? createdAt;
  const ExtractedActionEntity({
    required this.id,
    required this.memoId,
    required this.actionType,
    required this.title,
    this.notes,
    this.startTime,
    this.endTime,
    this.dueDate,
    this.location,
    this.reminderMinutes,
    required this.created,
    required this.dismissed,
    this.platformTargetId,
    this.durationSeconds,
    this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['memo_id'] = Variable<int>(memoId);
    map['action_type'] = Variable<String>(actionType);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || startTime != null) {
      map['start_time'] = Variable<DateTime>(startTime);
    }
    if (!nullToAbsent || endTime != null) {
      map['end_time'] = Variable<DateTime>(endTime);
    }
    if (!nullToAbsent || dueDate != null) {
      map['due_date'] = Variable<DateTime>(dueDate);
    }
    if (!nullToAbsent || location != null) {
      map['location'] = Variable<String>(location);
    }
    if (!nullToAbsent || reminderMinutes != null) {
      map['reminder_minutes'] = Variable<int>(reminderMinutes);
    }
    map['created'] = Variable<bool>(created);
    map['dismissed'] = Variable<bool>(dismissed);
    if (!nullToAbsent || platformTargetId != null) {
      map['platform_target_id'] = Variable<String>(platformTargetId);
    }
    if (!nullToAbsent || durationSeconds != null) {
      map['duration_seconds'] = Variable<int>(durationSeconds);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    return map;
  }

  ExtractedActionsCompanion toCompanion(bool nullToAbsent) {
    return ExtractedActionsCompanion(
      id: Value(id),
      memoId: Value(memoId),
      actionType: Value(actionType),
      title: Value(title),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      startTime: startTime == null && nullToAbsent
          ? const Value.absent()
          : Value(startTime),
      endTime: endTime == null && nullToAbsent
          ? const Value.absent()
          : Value(endTime),
      dueDate: dueDate == null && nullToAbsent
          ? const Value.absent()
          : Value(dueDate),
      location: location == null && nullToAbsent
          ? const Value.absent()
          : Value(location),
      reminderMinutes: reminderMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(reminderMinutes),
      created: Value(created),
      dismissed: Value(dismissed),
      platformTargetId: platformTargetId == null && nullToAbsent
          ? const Value.absent()
          : Value(platformTargetId),
      durationSeconds: durationSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(durationSeconds),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
    );
  }

  factory ExtractedActionEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExtractedActionEntity(
      id: serializer.fromJson<int>(json['id']),
      memoId: serializer.fromJson<int>(json['memoId']),
      actionType: serializer.fromJson<String>(json['actionType']),
      title: serializer.fromJson<String>(json['title']),
      notes: serializer.fromJson<String?>(json['notes']),
      startTime: serializer.fromJson<DateTime?>(json['startTime']),
      endTime: serializer.fromJson<DateTime?>(json['endTime']),
      dueDate: serializer.fromJson<DateTime?>(json['dueDate']),
      location: serializer.fromJson<String?>(json['location']),
      reminderMinutes: serializer.fromJson<int?>(json['reminderMinutes']),
      created: serializer.fromJson<bool>(json['created']),
      dismissed: serializer.fromJson<bool>(json['dismissed']),
      platformTargetId: serializer.fromJson<String?>(json['platformTargetId']),
      durationSeconds: serializer.fromJson<int?>(json['durationSeconds']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'memoId': serializer.toJson<int>(memoId),
      'actionType': serializer.toJson<String>(actionType),
      'title': serializer.toJson<String>(title),
      'notes': serializer.toJson<String?>(notes),
      'startTime': serializer.toJson<DateTime?>(startTime),
      'endTime': serializer.toJson<DateTime?>(endTime),
      'dueDate': serializer.toJson<DateTime?>(dueDate),
      'location': serializer.toJson<String?>(location),
      'reminderMinutes': serializer.toJson<int?>(reminderMinutes),
      'created': serializer.toJson<bool>(created),
      'dismissed': serializer.toJson<bool>(dismissed),
      'platformTargetId': serializer.toJson<String?>(platformTargetId),
      'durationSeconds': serializer.toJson<int?>(durationSeconds),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
    };
  }

  ExtractedActionEntity copyWith({
    int? id,
    int? memoId,
    String? actionType,
    String? title,
    Value<String?> notes = const Value.absent(),
    Value<DateTime?> startTime = const Value.absent(),
    Value<DateTime?> endTime = const Value.absent(),
    Value<DateTime?> dueDate = const Value.absent(),
    Value<String?> location = const Value.absent(),
    Value<int?> reminderMinutes = const Value.absent(),
    bool? created,
    bool? dismissed,
    Value<String?> platformTargetId = const Value.absent(),
    Value<int?> durationSeconds = const Value.absent(),
    Value<DateTime?> createdAt = const Value.absent(),
  }) => ExtractedActionEntity(
    id: id ?? this.id,
    memoId: memoId ?? this.memoId,
    actionType: actionType ?? this.actionType,
    title: title ?? this.title,
    notes: notes.present ? notes.value : this.notes,
    startTime: startTime.present ? startTime.value : this.startTime,
    endTime: endTime.present ? endTime.value : this.endTime,
    dueDate: dueDate.present ? dueDate.value : this.dueDate,
    location: location.present ? location.value : this.location,
    reminderMinutes: reminderMinutes.present
        ? reminderMinutes.value
        : this.reminderMinutes,
    created: created ?? this.created,
    dismissed: dismissed ?? this.dismissed,
    platformTargetId: platformTargetId.present
        ? platformTargetId.value
        : this.platformTargetId,
    durationSeconds: durationSeconds.present
        ? durationSeconds.value
        : this.durationSeconds,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
  );
  ExtractedActionEntity copyWithCompanion(ExtractedActionsCompanion data) {
    return ExtractedActionEntity(
      id: data.id.present ? data.id.value : this.id,
      memoId: data.memoId.present ? data.memoId.value : this.memoId,
      actionType: data.actionType.present
          ? data.actionType.value
          : this.actionType,
      title: data.title.present ? data.title.value : this.title,
      notes: data.notes.present ? data.notes.value : this.notes,
      startTime: data.startTime.present ? data.startTime.value : this.startTime,
      endTime: data.endTime.present ? data.endTime.value : this.endTime,
      dueDate: data.dueDate.present ? data.dueDate.value : this.dueDate,
      location: data.location.present ? data.location.value : this.location,
      reminderMinutes: data.reminderMinutes.present
          ? data.reminderMinutes.value
          : this.reminderMinutes,
      created: data.created.present ? data.created.value : this.created,
      dismissed: data.dismissed.present ? data.dismissed.value : this.dismissed,
      platformTargetId: data.platformTargetId.present
          ? data.platformTargetId.value
          : this.platformTargetId,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExtractedActionEntity(')
          ..write('id: $id, ')
          ..write('memoId: $memoId, ')
          ..write('actionType: $actionType, ')
          ..write('title: $title, ')
          ..write('notes: $notes, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('dueDate: $dueDate, ')
          ..write('location: $location, ')
          ..write('reminderMinutes: $reminderMinutes, ')
          ..write('created: $created, ')
          ..write('dismissed: $dismissed, ')
          ..write('platformTargetId: $platformTargetId, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    memoId,
    actionType,
    title,
    notes,
    startTime,
    endTime,
    dueDate,
    location,
    reminderMinutes,
    created,
    dismissed,
    platformTargetId,
    durationSeconds,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExtractedActionEntity &&
          other.id == this.id &&
          other.memoId == this.memoId &&
          other.actionType == this.actionType &&
          other.title == this.title &&
          other.notes == this.notes &&
          other.startTime == this.startTime &&
          other.endTime == this.endTime &&
          other.dueDate == this.dueDate &&
          other.location == this.location &&
          other.reminderMinutes == this.reminderMinutes &&
          other.created == this.created &&
          other.dismissed == this.dismissed &&
          other.platformTargetId == this.platformTargetId &&
          other.durationSeconds == this.durationSeconds &&
          other.createdAt == this.createdAt);
}

class ExtractedActionsCompanion extends UpdateCompanion<ExtractedActionEntity> {
  final Value<int> id;
  final Value<int> memoId;
  final Value<String> actionType;
  final Value<String> title;
  final Value<String?> notes;
  final Value<DateTime?> startTime;
  final Value<DateTime?> endTime;
  final Value<DateTime?> dueDate;
  final Value<String?> location;
  final Value<int?> reminderMinutes;
  final Value<bool> created;
  final Value<bool> dismissed;
  final Value<String?> platformTargetId;
  final Value<int?> durationSeconds;
  final Value<DateTime?> createdAt;
  const ExtractedActionsCompanion({
    this.id = const Value.absent(),
    this.memoId = const Value.absent(),
    this.actionType = const Value.absent(),
    this.title = const Value.absent(),
    this.notes = const Value.absent(),
    this.startTime = const Value.absent(),
    this.endTime = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.location = const Value.absent(),
    this.reminderMinutes = const Value.absent(),
    this.created = const Value.absent(),
    this.dismissed = const Value.absent(),
    this.platformTargetId = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  ExtractedActionsCompanion.insert({
    this.id = const Value.absent(),
    required int memoId,
    required String actionType,
    required String title,
    this.notes = const Value.absent(),
    this.startTime = const Value.absent(),
    this.endTime = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.location = const Value.absent(),
    this.reminderMinutes = const Value.absent(),
    this.created = const Value.absent(),
    this.dismissed = const Value.absent(),
    this.platformTargetId = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : memoId = Value(memoId),
       actionType = Value(actionType),
       title = Value(title);
  static Insertable<ExtractedActionEntity> custom({
    Expression<int>? id,
    Expression<int>? memoId,
    Expression<String>? actionType,
    Expression<String>? title,
    Expression<String>? notes,
    Expression<DateTime>? startTime,
    Expression<DateTime>? endTime,
    Expression<DateTime>? dueDate,
    Expression<String>? location,
    Expression<int>? reminderMinutes,
    Expression<bool>? created,
    Expression<bool>? dismissed,
    Expression<String>? platformTargetId,
    Expression<int>? durationSeconds,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (memoId != null) 'memo_id': memoId,
      if (actionType != null) 'action_type': actionType,
      if (title != null) 'title': title,
      if (notes != null) 'notes': notes,
      if (startTime != null) 'start_time': startTime,
      if (endTime != null) 'end_time': endTime,
      if (dueDate != null) 'due_date': dueDate,
      if (location != null) 'location': location,
      if (reminderMinutes != null) 'reminder_minutes': reminderMinutes,
      if (created != null) 'created': created,
      if (dismissed != null) 'dismissed': dismissed,
      if (platformTargetId != null) 'platform_target_id': platformTargetId,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  ExtractedActionsCompanion copyWith({
    Value<int>? id,
    Value<int>? memoId,
    Value<String>? actionType,
    Value<String>? title,
    Value<String?>? notes,
    Value<DateTime?>? startTime,
    Value<DateTime?>? endTime,
    Value<DateTime?>? dueDate,
    Value<String?>? location,
    Value<int?>? reminderMinutes,
    Value<bool>? created,
    Value<bool>? dismissed,
    Value<String?>? platformTargetId,
    Value<int?>? durationSeconds,
    Value<DateTime?>? createdAt,
  }) {
    return ExtractedActionsCompanion(
      id: id ?? this.id,
      memoId: memoId ?? this.memoId,
      actionType: actionType ?? this.actionType,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      dueDate: dueDate ?? this.dueDate,
      location: location ?? this.location,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      created: created ?? this.created,
      dismissed: dismissed ?? this.dismissed,
      platformTargetId: platformTargetId ?? this.platformTargetId,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (memoId.present) {
      map['memo_id'] = Variable<int>(memoId.value);
    }
    if (actionType.present) {
      map['action_type'] = Variable<String>(actionType.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (startTime.present) {
      map['start_time'] = Variable<DateTime>(startTime.value);
    }
    if (endTime.present) {
      map['end_time'] = Variable<DateTime>(endTime.value);
    }
    if (dueDate.present) {
      map['due_date'] = Variable<DateTime>(dueDate.value);
    }
    if (location.present) {
      map['location'] = Variable<String>(location.value);
    }
    if (reminderMinutes.present) {
      map['reminder_minutes'] = Variable<int>(reminderMinutes.value);
    }
    if (created.present) {
      map['created'] = Variable<bool>(created.value);
    }
    if (dismissed.present) {
      map['dismissed'] = Variable<bool>(dismissed.value);
    }
    if (platformTargetId.present) {
      map['platform_target_id'] = Variable<String>(platformTargetId.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<int>(durationSeconds.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExtractedActionsCompanion(')
          ..write('id: $id, ')
          ..write('memoId: $memoId, ')
          ..write('actionType: $actionType, ')
          ..write('title: $title, ')
          ..write('notes: $notes, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('dueDate: $dueDate, ')
          ..write('location: $location, ')
          ..write('reminderMinutes: $reminderMinutes, ')
          ..write('created: $created, ')
          ..write('dismissed: $dismissed, ')
          ..write('platformTargetId: $platformTargetId, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $CrashReportsTable extends CrashReports
    with TableInfo<$CrashReportsTable, CrashReportEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CrashReportsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
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
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES watches (id)',
    ),
  );
  static const VerificationMeta _fileMeta = const VerificationMeta('file');
  @override
  late final GeneratedColumn<String> file = GeneratedColumn<String>(
    'file',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lineMeta = const VerificationMeta('line');
  @override
  late final GeneratedColumn<int> line = GeneratedColumn<int>(
    'line',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _crashTimeMeta = const VerificationMeta(
    'crashTime',
  );
  @override
  late final GeneratedColumn<String> crashTime = GeneratedColumn<String>(
    'crash_time',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fwVersionMeta = const VerificationMeta(
    'fwVersion',
  );
  @override
  late final GeneratedColumn<String> fwVersion = GeneratedColumn<String>(
    'fw_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fwCommitShaMeta = const VerificationMeta(
    'fwCommitSha',
  );
  @override
  late final GeneratedColumn<String> fwCommitSha = GeneratedColumn<String>(
    'fw_commit_sha',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _boardMeta = const VerificationMeta('board');
  @override
  late final GeneratedColumn<String> board = GeneratedColumn<String>(
    'board',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _buildTypeMeta = const VerificationMeta(
    'buildType',
  );
  @override
  late final GeneratedColumn<String> buildType = GeneratedColumn<String>(
    'build_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _receivedAtMeta = const VerificationMeta(
    'receivedAt',
  );
  @override
  late final GeneratedColumn<DateTime> receivedAt = GeneratedColumn<DateTime>(
    'received_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _analyzedMeta = const VerificationMeta(
    'analyzed',
  );
  @override
  late final GeneratedColumn<bool> analyzed = GeneratedColumn<bool>(
    'analyzed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("analyzed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _backtraceMeta = const VerificationMeta(
    'backtrace',
  );
  @override
  late final GeneratedColumn<String> backtrace = GeneratedColumn<String>(
    'backtrace',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _registersMeta = const VerificationMeta(
    'registers',
  );
  @override
  late final GeneratedColumn<String> registers = GeneratedColumn<String>(
    'registers',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rawOutputMeta = const VerificationMeta(
    'rawOutput',
  );
  @override
  late final GeneratedColumn<String> rawOutput = GeneratedColumn<String>(
    'raw_output',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _analysisErrorMeta = const VerificationMeta(
    'analysisError',
  );
  @override
  late final GeneratedColumn<String> analysisError = GeneratedColumn<String>(
    'analysis_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _elfAvailableMeta = const VerificationMeta(
    'elfAvailable',
  );
  @override
  late final GeneratedColumn<bool> elfAvailable = GeneratedColumn<bool>(
    'elf_available',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("elf_available" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    watchId,
    file,
    line,
    crashTime,
    fwVersion,
    fwCommitSha,
    board,
    buildType,
    receivedAt,
    analyzed,
    backtrace,
    registers,
    rawOutput,
    analysisError,
    elfAvailable,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'crash_reports';
  @override
  VerificationContext validateIntegrity(
    Insertable<CrashReportEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('watch_id')) {
      context.handle(
        _watchIdMeta,
        watchId.isAcceptableOrUnknown(data['watch_id']!, _watchIdMeta),
      );
    } else if (isInserting) {
      context.missing(_watchIdMeta);
    }
    if (data.containsKey('file')) {
      context.handle(
        _fileMeta,
        file.isAcceptableOrUnknown(data['file']!, _fileMeta),
      );
    } else if (isInserting) {
      context.missing(_fileMeta);
    }
    if (data.containsKey('line')) {
      context.handle(
        _lineMeta,
        line.isAcceptableOrUnknown(data['line']!, _lineMeta),
      );
    } else if (isInserting) {
      context.missing(_lineMeta);
    }
    if (data.containsKey('crash_time')) {
      context.handle(
        _crashTimeMeta,
        crashTime.isAcceptableOrUnknown(data['crash_time']!, _crashTimeMeta),
      );
    } else if (isInserting) {
      context.missing(_crashTimeMeta);
    }
    if (data.containsKey('fw_version')) {
      context.handle(
        _fwVersionMeta,
        fwVersion.isAcceptableOrUnknown(data['fw_version']!, _fwVersionMeta),
      );
    } else if (isInserting) {
      context.missing(_fwVersionMeta);
    }
    if (data.containsKey('fw_commit_sha')) {
      context.handle(
        _fwCommitShaMeta,
        fwCommitSha.isAcceptableOrUnknown(
          data['fw_commit_sha']!,
          _fwCommitShaMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fwCommitShaMeta);
    }
    if (data.containsKey('board')) {
      context.handle(
        _boardMeta,
        board.isAcceptableOrUnknown(data['board']!, _boardMeta),
      );
    } else if (isInserting) {
      context.missing(_boardMeta);
    }
    if (data.containsKey('build_type')) {
      context.handle(
        _buildTypeMeta,
        buildType.isAcceptableOrUnknown(data['build_type']!, _buildTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_buildTypeMeta);
    }
    if (data.containsKey('received_at')) {
      context.handle(
        _receivedAtMeta,
        receivedAt.isAcceptableOrUnknown(data['received_at']!, _receivedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_receivedAtMeta);
    }
    if (data.containsKey('analyzed')) {
      context.handle(
        _analyzedMeta,
        analyzed.isAcceptableOrUnknown(data['analyzed']!, _analyzedMeta),
      );
    }
    if (data.containsKey('backtrace')) {
      context.handle(
        _backtraceMeta,
        backtrace.isAcceptableOrUnknown(data['backtrace']!, _backtraceMeta),
      );
    }
    if (data.containsKey('registers')) {
      context.handle(
        _registersMeta,
        registers.isAcceptableOrUnknown(data['registers']!, _registersMeta),
      );
    }
    if (data.containsKey('raw_output')) {
      context.handle(
        _rawOutputMeta,
        rawOutput.isAcceptableOrUnknown(data['raw_output']!, _rawOutputMeta),
      );
    }
    if (data.containsKey('analysis_error')) {
      context.handle(
        _analysisErrorMeta,
        analysisError.isAcceptableOrUnknown(
          data['analysis_error']!,
          _analysisErrorMeta,
        ),
      );
    }
    if (data.containsKey('elf_available')) {
      context.handle(
        _elfAvailableMeta,
        elfAvailable.isAcceptableOrUnknown(
          data['elf_available']!,
          _elfAvailableMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CrashReportEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CrashReportEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      watchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}watch_id'],
      )!,
      file: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file'],
      )!,
      line: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}line'],
      )!,
      crashTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}crash_time'],
      )!,
      fwVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fw_version'],
      )!,
      fwCommitSha: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fw_commit_sha'],
      )!,
      board: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}board'],
      )!,
      buildType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}build_type'],
      )!,
      receivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}received_at'],
      )!,
      analyzed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}analyzed'],
      )!,
      backtrace: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}backtrace'],
      ),
      registers: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}registers'],
      ),
      rawOutput: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_output'],
      ),
      analysisError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}analysis_error'],
      ),
      elfAvailable: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}elf_available'],
      )!,
    );
  }

  @override
  $CrashReportsTable createAlias(String alias) {
    return $CrashReportsTable(attachedDatabase, alias);
  }
}

class CrashReportEntity extends DataClass
    implements Insertable<CrashReportEntity> {
  /// Auto-incrementing row identifier
  final int id;

  /// Foreign key to source watch
  final String watchId;

  /// Source file that crashed
  final String file;

  /// Line number of the crash
  final int line;

  /// Crash timestamp as reported by the watch
  final String crashTime;

  /// Firmware version at time of crash
  final String fwVersion;

  /// Firmware commit SHA at time of crash
  final String fwCommitSha;

  /// Board identifier
  final String board;

  /// Build type (debug/release)
  final String buildType;

  /// When this crash was first received by the app
  final DateTime receivedAt;

  /// Whether analysis has been performed
  final bool analyzed;

  /// Decoded backtrace from server (null if not analyzed)
  final String? backtrace;

  /// Decoded registers from server (null if not analyzed)
  final String? registers;

  /// Raw GDB output from server (null if not analyzed)
  final String? rawOutput;

  /// Error message if analysis failed
  final String? analysisError;

  /// Whether ELF was available for analysis
  final bool elfAvailable;
  const CrashReportEntity({
    required this.id,
    required this.watchId,
    required this.file,
    required this.line,
    required this.crashTime,
    required this.fwVersion,
    required this.fwCommitSha,
    required this.board,
    required this.buildType,
    required this.receivedAt,
    required this.analyzed,
    this.backtrace,
    this.registers,
    this.rawOutput,
    this.analysisError,
    required this.elfAvailable,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['watch_id'] = Variable<String>(watchId);
    map['file'] = Variable<String>(file);
    map['line'] = Variable<int>(line);
    map['crash_time'] = Variable<String>(crashTime);
    map['fw_version'] = Variable<String>(fwVersion);
    map['fw_commit_sha'] = Variable<String>(fwCommitSha);
    map['board'] = Variable<String>(board);
    map['build_type'] = Variable<String>(buildType);
    map['received_at'] = Variable<DateTime>(receivedAt);
    map['analyzed'] = Variable<bool>(analyzed);
    if (!nullToAbsent || backtrace != null) {
      map['backtrace'] = Variable<String>(backtrace);
    }
    if (!nullToAbsent || registers != null) {
      map['registers'] = Variable<String>(registers);
    }
    if (!nullToAbsent || rawOutput != null) {
      map['raw_output'] = Variable<String>(rawOutput);
    }
    if (!nullToAbsent || analysisError != null) {
      map['analysis_error'] = Variable<String>(analysisError);
    }
    map['elf_available'] = Variable<bool>(elfAvailable);
    return map;
  }

  CrashReportsCompanion toCompanion(bool nullToAbsent) {
    return CrashReportsCompanion(
      id: Value(id),
      watchId: Value(watchId),
      file: Value(file),
      line: Value(line),
      crashTime: Value(crashTime),
      fwVersion: Value(fwVersion),
      fwCommitSha: Value(fwCommitSha),
      board: Value(board),
      buildType: Value(buildType),
      receivedAt: Value(receivedAt),
      analyzed: Value(analyzed),
      backtrace: backtrace == null && nullToAbsent
          ? const Value.absent()
          : Value(backtrace),
      registers: registers == null && nullToAbsent
          ? const Value.absent()
          : Value(registers),
      rawOutput: rawOutput == null && nullToAbsent
          ? const Value.absent()
          : Value(rawOutput),
      analysisError: analysisError == null && nullToAbsent
          ? const Value.absent()
          : Value(analysisError),
      elfAvailable: Value(elfAvailable),
    );
  }

  factory CrashReportEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CrashReportEntity(
      id: serializer.fromJson<int>(json['id']),
      watchId: serializer.fromJson<String>(json['watchId']),
      file: serializer.fromJson<String>(json['file']),
      line: serializer.fromJson<int>(json['line']),
      crashTime: serializer.fromJson<String>(json['crashTime']),
      fwVersion: serializer.fromJson<String>(json['fwVersion']),
      fwCommitSha: serializer.fromJson<String>(json['fwCommitSha']),
      board: serializer.fromJson<String>(json['board']),
      buildType: serializer.fromJson<String>(json['buildType']),
      receivedAt: serializer.fromJson<DateTime>(json['receivedAt']),
      analyzed: serializer.fromJson<bool>(json['analyzed']),
      backtrace: serializer.fromJson<String?>(json['backtrace']),
      registers: serializer.fromJson<String?>(json['registers']),
      rawOutput: serializer.fromJson<String?>(json['rawOutput']),
      analysisError: serializer.fromJson<String?>(json['analysisError']),
      elfAvailable: serializer.fromJson<bool>(json['elfAvailable']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'watchId': serializer.toJson<String>(watchId),
      'file': serializer.toJson<String>(file),
      'line': serializer.toJson<int>(line),
      'crashTime': serializer.toJson<String>(crashTime),
      'fwVersion': serializer.toJson<String>(fwVersion),
      'fwCommitSha': serializer.toJson<String>(fwCommitSha),
      'board': serializer.toJson<String>(board),
      'buildType': serializer.toJson<String>(buildType),
      'receivedAt': serializer.toJson<DateTime>(receivedAt),
      'analyzed': serializer.toJson<bool>(analyzed),
      'backtrace': serializer.toJson<String?>(backtrace),
      'registers': serializer.toJson<String?>(registers),
      'rawOutput': serializer.toJson<String?>(rawOutput),
      'analysisError': serializer.toJson<String?>(analysisError),
      'elfAvailable': serializer.toJson<bool>(elfAvailable),
    };
  }

  CrashReportEntity copyWith({
    int? id,
    String? watchId,
    String? file,
    int? line,
    String? crashTime,
    String? fwVersion,
    String? fwCommitSha,
    String? board,
    String? buildType,
    DateTime? receivedAt,
    bool? analyzed,
    Value<String?> backtrace = const Value.absent(),
    Value<String?> registers = const Value.absent(),
    Value<String?> rawOutput = const Value.absent(),
    Value<String?> analysisError = const Value.absent(),
    bool? elfAvailable,
  }) => CrashReportEntity(
    id: id ?? this.id,
    watchId: watchId ?? this.watchId,
    file: file ?? this.file,
    line: line ?? this.line,
    crashTime: crashTime ?? this.crashTime,
    fwVersion: fwVersion ?? this.fwVersion,
    fwCommitSha: fwCommitSha ?? this.fwCommitSha,
    board: board ?? this.board,
    buildType: buildType ?? this.buildType,
    receivedAt: receivedAt ?? this.receivedAt,
    analyzed: analyzed ?? this.analyzed,
    backtrace: backtrace.present ? backtrace.value : this.backtrace,
    registers: registers.present ? registers.value : this.registers,
    rawOutput: rawOutput.present ? rawOutput.value : this.rawOutput,
    analysisError: analysisError.present
        ? analysisError.value
        : this.analysisError,
    elfAvailable: elfAvailable ?? this.elfAvailable,
  );
  CrashReportEntity copyWithCompanion(CrashReportsCompanion data) {
    return CrashReportEntity(
      id: data.id.present ? data.id.value : this.id,
      watchId: data.watchId.present ? data.watchId.value : this.watchId,
      file: data.file.present ? data.file.value : this.file,
      line: data.line.present ? data.line.value : this.line,
      crashTime: data.crashTime.present ? data.crashTime.value : this.crashTime,
      fwVersion: data.fwVersion.present ? data.fwVersion.value : this.fwVersion,
      fwCommitSha: data.fwCommitSha.present
          ? data.fwCommitSha.value
          : this.fwCommitSha,
      board: data.board.present ? data.board.value : this.board,
      buildType: data.buildType.present ? data.buildType.value : this.buildType,
      receivedAt: data.receivedAt.present
          ? data.receivedAt.value
          : this.receivedAt,
      analyzed: data.analyzed.present ? data.analyzed.value : this.analyzed,
      backtrace: data.backtrace.present ? data.backtrace.value : this.backtrace,
      registers: data.registers.present ? data.registers.value : this.registers,
      rawOutput: data.rawOutput.present ? data.rawOutput.value : this.rawOutput,
      analysisError: data.analysisError.present
          ? data.analysisError.value
          : this.analysisError,
      elfAvailable: data.elfAvailable.present
          ? data.elfAvailable.value
          : this.elfAvailable,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CrashReportEntity(')
          ..write('id: $id, ')
          ..write('watchId: $watchId, ')
          ..write('file: $file, ')
          ..write('line: $line, ')
          ..write('crashTime: $crashTime, ')
          ..write('fwVersion: $fwVersion, ')
          ..write('fwCommitSha: $fwCommitSha, ')
          ..write('board: $board, ')
          ..write('buildType: $buildType, ')
          ..write('receivedAt: $receivedAt, ')
          ..write('analyzed: $analyzed, ')
          ..write('backtrace: $backtrace, ')
          ..write('registers: $registers, ')
          ..write('rawOutput: $rawOutput, ')
          ..write('analysisError: $analysisError, ')
          ..write('elfAvailable: $elfAvailable')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    watchId,
    file,
    line,
    crashTime,
    fwVersion,
    fwCommitSha,
    board,
    buildType,
    receivedAt,
    analyzed,
    backtrace,
    registers,
    rawOutput,
    analysisError,
    elfAvailable,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CrashReportEntity &&
          other.id == this.id &&
          other.watchId == this.watchId &&
          other.file == this.file &&
          other.line == this.line &&
          other.crashTime == this.crashTime &&
          other.fwVersion == this.fwVersion &&
          other.fwCommitSha == this.fwCommitSha &&
          other.board == this.board &&
          other.buildType == this.buildType &&
          other.receivedAt == this.receivedAt &&
          other.analyzed == this.analyzed &&
          other.backtrace == this.backtrace &&
          other.registers == this.registers &&
          other.rawOutput == this.rawOutput &&
          other.analysisError == this.analysisError &&
          other.elfAvailable == this.elfAvailable);
}

class CrashReportsCompanion extends UpdateCompanion<CrashReportEntity> {
  final Value<int> id;
  final Value<String> watchId;
  final Value<String> file;
  final Value<int> line;
  final Value<String> crashTime;
  final Value<String> fwVersion;
  final Value<String> fwCommitSha;
  final Value<String> board;
  final Value<String> buildType;
  final Value<DateTime> receivedAt;
  final Value<bool> analyzed;
  final Value<String?> backtrace;
  final Value<String?> registers;
  final Value<String?> rawOutput;
  final Value<String?> analysisError;
  final Value<bool> elfAvailable;
  const CrashReportsCompanion({
    this.id = const Value.absent(),
    this.watchId = const Value.absent(),
    this.file = const Value.absent(),
    this.line = const Value.absent(),
    this.crashTime = const Value.absent(),
    this.fwVersion = const Value.absent(),
    this.fwCommitSha = const Value.absent(),
    this.board = const Value.absent(),
    this.buildType = const Value.absent(),
    this.receivedAt = const Value.absent(),
    this.analyzed = const Value.absent(),
    this.backtrace = const Value.absent(),
    this.registers = const Value.absent(),
    this.rawOutput = const Value.absent(),
    this.analysisError = const Value.absent(),
    this.elfAvailable = const Value.absent(),
  });
  CrashReportsCompanion.insert({
    this.id = const Value.absent(),
    required String watchId,
    required String file,
    required int line,
    required String crashTime,
    required String fwVersion,
    required String fwCommitSha,
    required String board,
    required String buildType,
    required DateTime receivedAt,
    this.analyzed = const Value.absent(),
    this.backtrace = const Value.absent(),
    this.registers = const Value.absent(),
    this.rawOutput = const Value.absent(),
    this.analysisError = const Value.absent(),
    this.elfAvailable = const Value.absent(),
  }) : watchId = Value(watchId),
       file = Value(file),
       line = Value(line),
       crashTime = Value(crashTime),
       fwVersion = Value(fwVersion),
       fwCommitSha = Value(fwCommitSha),
       board = Value(board),
       buildType = Value(buildType),
       receivedAt = Value(receivedAt);
  static Insertable<CrashReportEntity> custom({
    Expression<int>? id,
    Expression<String>? watchId,
    Expression<String>? file,
    Expression<int>? line,
    Expression<String>? crashTime,
    Expression<String>? fwVersion,
    Expression<String>? fwCommitSha,
    Expression<String>? board,
    Expression<String>? buildType,
    Expression<DateTime>? receivedAt,
    Expression<bool>? analyzed,
    Expression<String>? backtrace,
    Expression<String>? registers,
    Expression<String>? rawOutput,
    Expression<String>? analysisError,
    Expression<bool>? elfAvailable,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (watchId != null) 'watch_id': watchId,
      if (file != null) 'file': file,
      if (line != null) 'line': line,
      if (crashTime != null) 'crash_time': crashTime,
      if (fwVersion != null) 'fw_version': fwVersion,
      if (fwCommitSha != null) 'fw_commit_sha': fwCommitSha,
      if (board != null) 'board': board,
      if (buildType != null) 'build_type': buildType,
      if (receivedAt != null) 'received_at': receivedAt,
      if (analyzed != null) 'analyzed': analyzed,
      if (backtrace != null) 'backtrace': backtrace,
      if (registers != null) 'registers': registers,
      if (rawOutput != null) 'raw_output': rawOutput,
      if (analysisError != null) 'analysis_error': analysisError,
      if (elfAvailable != null) 'elf_available': elfAvailable,
    });
  }

  CrashReportsCompanion copyWith({
    Value<int>? id,
    Value<String>? watchId,
    Value<String>? file,
    Value<int>? line,
    Value<String>? crashTime,
    Value<String>? fwVersion,
    Value<String>? fwCommitSha,
    Value<String>? board,
    Value<String>? buildType,
    Value<DateTime>? receivedAt,
    Value<bool>? analyzed,
    Value<String?>? backtrace,
    Value<String?>? registers,
    Value<String?>? rawOutput,
    Value<String?>? analysisError,
    Value<bool>? elfAvailable,
  }) {
    return CrashReportsCompanion(
      id: id ?? this.id,
      watchId: watchId ?? this.watchId,
      file: file ?? this.file,
      line: line ?? this.line,
      crashTime: crashTime ?? this.crashTime,
      fwVersion: fwVersion ?? this.fwVersion,
      fwCommitSha: fwCommitSha ?? this.fwCommitSha,
      board: board ?? this.board,
      buildType: buildType ?? this.buildType,
      receivedAt: receivedAt ?? this.receivedAt,
      analyzed: analyzed ?? this.analyzed,
      backtrace: backtrace ?? this.backtrace,
      registers: registers ?? this.registers,
      rawOutput: rawOutput ?? this.rawOutput,
      analysisError: analysisError ?? this.analysisError,
      elfAvailable: elfAvailable ?? this.elfAvailable,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (watchId.present) {
      map['watch_id'] = Variable<String>(watchId.value);
    }
    if (file.present) {
      map['file'] = Variable<String>(file.value);
    }
    if (line.present) {
      map['line'] = Variable<int>(line.value);
    }
    if (crashTime.present) {
      map['crash_time'] = Variable<String>(crashTime.value);
    }
    if (fwVersion.present) {
      map['fw_version'] = Variable<String>(fwVersion.value);
    }
    if (fwCommitSha.present) {
      map['fw_commit_sha'] = Variable<String>(fwCommitSha.value);
    }
    if (board.present) {
      map['board'] = Variable<String>(board.value);
    }
    if (buildType.present) {
      map['build_type'] = Variable<String>(buildType.value);
    }
    if (receivedAt.present) {
      map['received_at'] = Variable<DateTime>(receivedAt.value);
    }
    if (analyzed.present) {
      map['analyzed'] = Variable<bool>(analyzed.value);
    }
    if (backtrace.present) {
      map['backtrace'] = Variable<String>(backtrace.value);
    }
    if (registers.present) {
      map['registers'] = Variable<String>(registers.value);
    }
    if (rawOutput.present) {
      map['raw_output'] = Variable<String>(rawOutput.value);
    }
    if (analysisError.present) {
      map['analysis_error'] = Variable<String>(analysisError.value);
    }
    if (elfAvailable.present) {
      map['elf_available'] = Variable<bool>(elfAvailable.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CrashReportsCompanion(')
          ..write('id: $id, ')
          ..write('watchId: $watchId, ')
          ..write('file: $file, ')
          ..write('line: $line, ')
          ..write('crashTime: $crashTime, ')
          ..write('fwVersion: $fwVersion, ')
          ..write('fwCommitSha: $fwCommitSha, ')
          ..write('board: $board, ')
          ..write('buildType: $buildType, ')
          ..write('receivedAt: $receivedAt, ')
          ..write('analyzed: $analyzed, ')
          ..write('backtrace: $backtrace, ')
          ..write('registers: $registers, ')
          ..write('rawOutput: $rawOutput, ')
          ..write('analysisError: $analysisError, ')
          ..write('elfAvailable: $elfAvailable')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $WatchesTable watches = $WatchesTable(this);
  late final $HealthSamplesTable healthSamples = $HealthSamplesTable(this);
  late final $BatteryReadingsTable batteryReadings = $BatteryReadingsTable(
    this,
  );
  late final $CommLogEntriesTable commLogEntries = $CommLogEntriesTable(this);
  late final $ConnectionEventsTable connectionEvents = $ConnectionEventsTable(
    this,
  );
  late final $VoiceMemosTable voiceMemos = $VoiceMemosTable(this);
  late final $ExtractedActionsTable extractedActions = $ExtractedActionsTable(
    this,
  );
  late final $CrashReportsTable crashReports = $CrashReportsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    watches,
    healthSamples,
    batteryReadings,
    commLogEntries,
    connectionEvents,
    voiceMemos,
    extractedActions,
    crashReports,
  ];
}

typedef $$WatchesTableCreateCompanionBuilder =
    WatchesCompanion Function({
      required String id,
      required String name,
      Value<String?> customName,
      Value<String?> firmwareVersion,
      Value<String?> hardwareVersion,
      Value<int?> batteryLevel,
      Value<bool> isPrimary,
      Value<bool> supportsExtendedApi,
      Value<DateTime?> lastConnectedAt,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$WatchesTableUpdateCompanionBuilder =
    WatchesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> customName,
      Value<String?> firmwareVersion,
      Value<String?> hardwareVersion,
      Value<int?> batteryLevel,
      Value<bool> isPrimary,
      Value<bool> supportsExtendedApi,
      Value<DateTime?> lastConnectedAt,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$WatchesTableReferences
    extends BaseReferences<_$AppDatabase, $WatchesTable, WatchEntity> {
  $$WatchesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$HealthSamplesTable, List<HealthSampleEntity>>
  _healthSamplesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.healthSamples,
    aliasName: $_aliasNameGenerator(db.watches.id, db.healthSamples.watchId),
  );

  $$HealthSamplesTableProcessedTableManager get healthSamplesRefs {
    final manager = $$HealthSamplesTableTableManager(
      $_db,
      $_db.healthSamples,
    ).filter((f) => f.watchId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_healthSamplesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$BatteryReadingsTable, List<BatteryReadingEntity>>
  _batteryReadingsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.batteryReadings,
    aliasName: $_aliasNameGenerator(db.watches.id, db.batteryReadings.watchId),
  );

  $$BatteryReadingsTableProcessedTableManager get batteryReadingsRefs {
    final manager = $$BatteryReadingsTableTableManager(
      $_db,
      $_db.batteryReadings,
    ).filter((f) => f.watchId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _batteryReadingsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $ConnectionEventsTable,
    List<ConnectionEventEntity>
  >
  _connectionEventsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.connectionEvents,
    aliasName: $_aliasNameGenerator(db.watches.id, db.connectionEvents.watchId),
  );

  $$ConnectionEventsTableProcessedTableManager get connectionEventsRefs {
    final manager = $$ConnectionEventsTableTableManager(
      $_db,
      $_db.connectionEvents,
    ).filter((f) => f.watchId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _connectionEventsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CrashReportsTable, List<CrashReportEntity>>
  _crashReportsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.crashReports,
    aliasName: $_aliasNameGenerator(db.watches.id, db.crashReports.watchId),
  );

  $$CrashReportsTableProcessedTableManager get crashReportsRefs {
    final manager = $$CrashReportsTableTableManager(
      $_db,
      $_db.crashReports,
    ).filter((f) => f.watchId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_crashReportsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$WatchesTableFilterComposer
    extends Composer<_$AppDatabase, $WatchesTable> {
  $$WatchesTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customName => $composableBuilder(
    column: $table.customName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get firmwareVersion => $composableBuilder(
    column: $table.firmwareVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hardwareVersion => $composableBuilder(
    column: $table.hardwareVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get batteryLevel => $composableBuilder(
    column: $table.batteryLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPrimary => $composableBuilder(
    column: $table.isPrimary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get supportsExtendedApi => $composableBuilder(
    column: $table.supportsExtendedApi,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastConnectedAt => $composableBuilder(
    column: $table.lastConnectedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> healthSamplesRefs(
    Expression<bool> Function($$HealthSamplesTableFilterComposer f) f,
  ) {
    final $$HealthSamplesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.healthSamples,
      getReferencedColumn: (t) => t.watchId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HealthSamplesTableFilterComposer(
            $db: $db,
            $table: $db.healthSamples,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> batteryReadingsRefs(
    Expression<bool> Function($$BatteryReadingsTableFilterComposer f) f,
  ) {
    final $$BatteryReadingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.batteryReadings,
      getReferencedColumn: (t) => t.watchId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BatteryReadingsTableFilterComposer(
            $db: $db,
            $table: $db.batteryReadings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> connectionEventsRefs(
    Expression<bool> Function($$ConnectionEventsTableFilterComposer f) f,
  ) {
    final $$ConnectionEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.connectionEvents,
      getReferencedColumn: (t) => t.watchId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConnectionEventsTableFilterComposer(
            $db: $db,
            $table: $db.connectionEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> crashReportsRefs(
    Expression<bool> Function($$CrashReportsTableFilterComposer f) f,
  ) {
    final $$CrashReportsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.crashReports,
      getReferencedColumn: (t) => t.watchId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CrashReportsTableFilterComposer(
            $db: $db,
            $table: $db.crashReports,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WatchesTableOrderingComposer
    extends Composer<_$AppDatabase, $WatchesTable> {
  $$WatchesTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customName => $composableBuilder(
    column: $table.customName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get firmwareVersion => $composableBuilder(
    column: $table.firmwareVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hardwareVersion => $composableBuilder(
    column: $table.hardwareVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get batteryLevel => $composableBuilder(
    column: $table.batteryLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPrimary => $composableBuilder(
    column: $table.isPrimary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get supportsExtendedApi => $composableBuilder(
    column: $table.supportsExtendedApi,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastConnectedAt => $composableBuilder(
    column: $table.lastConnectedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WatchesTableAnnotationComposer
    extends Composer<_$AppDatabase, $WatchesTable> {
  $$WatchesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get customName => $composableBuilder(
    column: $table.customName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get firmwareVersion => $composableBuilder(
    column: $table.firmwareVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get hardwareVersion => $composableBuilder(
    column: $table.hardwareVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get batteryLevel => $composableBuilder(
    column: $table.batteryLevel,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isPrimary =>
      $composableBuilder(column: $table.isPrimary, builder: (column) => column);

  GeneratedColumn<bool> get supportsExtendedApi => $composableBuilder(
    column: $table.supportsExtendedApi,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastConnectedAt => $composableBuilder(
    column: $table.lastConnectedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> healthSamplesRefs<T extends Object>(
    Expression<T> Function($$HealthSamplesTableAnnotationComposer a) f,
  ) {
    final $$HealthSamplesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.healthSamples,
      getReferencedColumn: (t) => t.watchId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HealthSamplesTableAnnotationComposer(
            $db: $db,
            $table: $db.healthSamples,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> batteryReadingsRefs<T extends Object>(
    Expression<T> Function($$BatteryReadingsTableAnnotationComposer a) f,
  ) {
    final $$BatteryReadingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.batteryReadings,
      getReferencedColumn: (t) => t.watchId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BatteryReadingsTableAnnotationComposer(
            $db: $db,
            $table: $db.batteryReadings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> connectionEventsRefs<T extends Object>(
    Expression<T> Function($$ConnectionEventsTableAnnotationComposer a) f,
  ) {
    final $$ConnectionEventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.connectionEvents,
      getReferencedColumn: (t) => t.watchId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConnectionEventsTableAnnotationComposer(
            $db: $db,
            $table: $db.connectionEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> crashReportsRefs<T extends Object>(
    Expression<T> Function($$CrashReportsTableAnnotationComposer a) f,
  ) {
    final $$CrashReportsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.crashReports,
      getReferencedColumn: (t) => t.watchId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CrashReportsTableAnnotationComposer(
            $db: $db,
            $table: $db.crashReports,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WatchesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WatchesTable,
          WatchEntity,
          $$WatchesTableFilterComposer,
          $$WatchesTableOrderingComposer,
          $$WatchesTableAnnotationComposer,
          $$WatchesTableCreateCompanionBuilder,
          $$WatchesTableUpdateCompanionBuilder,
          (WatchEntity, $$WatchesTableReferences),
          WatchEntity,
          PrefetchHooks Function({
            bool healthSamplesRefs,
            bool batteryReadingsRefs,
            bool connectionEventsRefs,
            bool crashReportsRefs,
          })
        > {
  $$WatchesTableTableManager(_$AppDatabase db, $WatchesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WatchesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WatchesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WatchesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> customName = const Value.absent(),
                Value<String?> firmwareVersion = const Value.absent(),
                Value<String?> hardwareVersion = const Value.absent(),
                Value<int?> batteryLevel = const Value.absent(),
                Value<bool> isPrimary = const Value.absent(),
                Value<bool> supportsExtendedApi = const Value.absent(),
                Value<DateTime?> lastConnectedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WatchesCompanion(
                id: id,
                name: name,
                customName: customName,
                firmwareVersion: firmwareVersion,
                hardwareVersion: hardwareVersion,
                batteryLevel: batteryLevel,
                isPrimary: isPrimary,
                supportsExtendedApi: supportsExtendedApi,
                lastConnectedAt: lastConnectedAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> customName = const Value.absent(),
                Value<String?> firmwareVersion = const Value.absent(),
                Value<String?> hardwareVersion = const Value.absent(),
                Value<int?> batteryLevel = const Value.absent(),
                Value<bool> isPrimary = const Value.absent(),
                Value<bool> supportsExtendedApi = const Value.absent(),
                Value<DateTime?> lastConnectedAt = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => WatchesCompanion.insert(
                id: id,
                name: name,
                customName: customName,
                firmwareVersion: firmwareVersion,
                hardwareVersion: hardwareVersion,
                batteryLevel: batteryLevel,
                isPrimary: isPrimary,
                supportsExtendedApi: supportsExtendedApi,
                lastConnectedAt: lastConnectedAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$WatchesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                healthSamplesRefs = false,
                batteryReadingsRefs = false,
                connectionEventsRefs = false,
                crashReportsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (healthSamplesRefs) db.healthSamples,
                    if (batteryReadingsRefs) db.batteryReadings,
                    if (connectionEventsRefs) db.connectionEvents,
                    if (crashReportsRefs) db.crashReports,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (healthSamplesRefs)
                        await $_getPrefetchedData<
                          WatchEntity,
                          $WatchesTable,
                          HealthSampleEntity
                        >(
                          currentTable: table,
                          referencedTable: $$WatchesTableReferences
                              ._healthSamplesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$WatchesTableReferences(
                                db,
                                table,
                                p0,
                              ).healthSamplesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.watchId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (batteryReadingsRefs)
                        await $_getPrefetchedData<
                          WatchEntity,
                          $WatchesTable,
                          BatteryReadingEntity
                        >(
                          currentTable: table,
                          referencedTable: $$WatchesTableReferences
                              ._batteryReadingsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$WatchesTableReferences(
                                db,
                                table,
                                p0,
                              ).batteryReadingsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.watchId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (connectionEventsRefs)
                        await $_getPrefetchedData<
                          WatchEntity,
                          $WatchesTable,
                          ConnectionEventEntity
                        >(
                          currentTable: table,
                          referencedTable: $$WatchesTableReferences
                              ._connectionEventsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$WatchesTableReferences(
                                db,
                                table,
                                p0,
                              ).connectionEventsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.watchId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (crashReportsRefs)
                        await $_getPrefetchedData<
                          WatchEntity,
                          $WatchesTable,
                          CrashReportEntity
                        >(
                          currentTable: table,
                          referencedTable: $$WatchesTableReferences
                              ._crashReportsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$WatchesTableReferences(
                                db,
                                table,
                                p0,
                              ).crashReportsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.watchId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$WatchesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WatchesTable,
      WatchEntity,
      $$WatchesTableFilterComposer,
      $$WatchesTableOrderingComposer,
      $$WatchesTableAnnotationComposer,
      $$WatchesTableCreateCompanionBuilder,
      $$WatchesTableUpdateCompanionBuilder,
      (WatchEntity, $$WatchesTableReferences),
      WatchEntity,
      PrefetchHooks Function({
        bool healthSamplesRefs,
        bool batteryReadingsRefs,
        bool connectionEventsRefs,
        bool crashReportsRefs,
      })
    >;
typedef $$HealthSamplesTableCreateCompanionBuilder =
    HealthSamplesCompanion Function({
      Value<int> id,
      required String watchId,
      required String type,
      required double value,
      required DateTime timestamp,
      required String granularity,
      required DateTime syncedAt,
    });
typedef $$HealthSamplesTableUpdateCompanionBuilder =
    HealthSamplesCompanion Function({
      Value<int> id,
      Value<String> watchId,
      Value<String> type,
      Value<double> value,
      Value<DateTime> timestamp,
      Value<String> granularity,
      Value<DateTime> syncedAt,
    });

final class $$HealthSamplesTableReferences
    extends
        BaseReferences<_$AppDatabase, $HealthSamplesTable, HealthSampleEntity> {
  $$HealthSamplesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $WatchesTable _watchIdTable(_$AppDatabase db) =>
      db.watches.createAlias(
        $_aliasNameGenerator(db.healthSamples.watchId, db.watches.id),
      );

  $$WatchesTableProcessedTableManager get watchId {
    final $_column = $_itemColumn<String>('watch_id')!;

    final manager = $$WatchesTableTableManager(
      $_db,
      $_db.watches,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_watchIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$HealthSamplesTableFilterComposer
    extends Composer<_$AppDatabase, $HealthSamplesTable> {
  $$HealthSamplesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get granularity => $composableBuilder(
    column: $table.granularity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$WatchesTableFilterComposer get watchId {
    final $$WatchesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.watchId,
      referencedTable: $db.watches,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WatchesTableFilterComposer(
            $db: $db,
            $table: $db.watches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$HealthSamplesTableOrderingComposer
    extends Composer<_$AppDatabase, $HealthSamplesTable> {
  $$HealthSamplesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get granularity => $composableBuilder(
    column: $table.granularity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$WatchesTableOrderingComposer get watchId {
    final $$WatchesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.watchId,
      referencedTable: $db.watches,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WatchesTableOrderingComposer(
            $db: $db,
            $table: $db.watches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$HealthSamplesTableAnnotationComposer
    extends Composer<_$AppDatabase, $HealthSamplesTable> {
  $$HealthSamplesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<double> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<String> get granularity => $composableBuilder(
    column: $table.granularity,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  $$WatchesTableAnnotationComposer get watchId {
    final $$WatchesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.watchId,
      referencedTable: $db.watches,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WatchesTableAnnotationComposer(
            $db: $db,
            $table: $db.watches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$HealthSamplesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HealthSamplesTable,
          HealthSampleEntity,
          $$HealthSamplesTableFilterComposer,
          $$HealthSamplesTableOrderingComposer,
          $$HealthSamplesTableAnnotationComposer,
          $$HealthSamplesTableCreateCompanionBuilder,
          $$HealthSamplesTableUpdateCompanionBuilder,
          (HealthSampleEntity, $$HealthSamplesTableReferences),
          HealthSampleEntity,
          PrefetchHooks Function({bool watchId})
        > {
  $$HealthSamplesTableTableManager(_$AppDatabase db, $HealthSamplesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HealthSamplesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HealthSamplesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HealthSamplesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> watchId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<double> value = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
                Value<String> granularity = const Value.absent(),
                Value<DateTime> syncedAt = const Value.absent(),
              }) => HealthSamplesCompanion(
                id: id,
                watchId: watchId,
                type: type,
                value: value,
                timestamp: timestamp,
                granularity: granularity,
                syncedAt: syncedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String watchId,
                required String type,
                required double value,
                required DateTime timestamp,
                required String granularity,
                required DateTime syncedAt,
              }) => HealthSamplesCompanion.insert(
                id: id,
                watchId: watchId,
                type: type,
                value: value,
                timestamp: timestamp,
                granularity: granularity,
                syncedAt: syncedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$HealthSamplesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({watchId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (watchId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.watchId,
                                referencedTable: $$HealthSamplesTableReferences
                                    ._watchIdTable(db),
                                referencedColumn: $$HealthSamplesTableReferences
                                    ._watchIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$HealthSamplesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HealthSamplesTable,
      HealthSampleEntity,
      $$HealthSamplesTableFilterComposer,
      $$HealthSamplesTableOrderingComposer,
      $$HealthSamplesTableAnnotationComposer,
      $$HealthSamplesTableCreateCompanionBuilder,
      $$HealthSamplesTableUpdateCompanionBuilder,
      (HealthSampleEntity, $$HealthSamplesTableReferences),
      HealthSampleEntity,
      PrefetchHooks Function({bool watchId})
    >;
typedef $$BatteryReadingsTableCreateCompanionBuilder =
    BatteryReadingsCompanion Function({
      Value<int> id,
      required String watchId,
      required int level,
      Value<bool> isCharging,
      required DateTime timestamp,
    });
typedef $$BatteryReadingsTableUpdateCompanionBuilder =
    BatteryReadingsCompanion Function({
      Value<int> id,
      Value<String> watchId,
      Value<int> level,
      Value<bool> isCharging,
      Value<DateTime> timestamp,
    });

final class $$BatteryReadingsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $BatteryReadingsTable,
          BatteryReadingEntity
        > {
  $$BatteryReadingsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $WatchesTable _watchIdTable(_$AppDatabase db) =>
      db.watches.createAlias(
        $_aliasNameGenerator(db.batteryReadings.watchId, db.watches.id),
      );

  $$WatchesTableProcessedTableManager get watchId {
    final $_column = $_itemColumn<String>('watch_id')!;

    final manager = $$WatchesTableTableManager(
      $_db,
      $_db.watches,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_watchIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$BatteryReadingsTableFilterComposer
    extends Composer<_$AppDatabase, $BatteryReadingsTable> {
  $$BatteryReadingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCharging => $composableBuilder(
    column: $table.isCharging,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );

  $$WatchesTableFilterComposer get watchId {
    final $$WatchesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.watchId,
      referencedTable: $db.watches,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WatchesTableFilterComposer(
            $db: $db,
            $table: $db.watches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BatteryReadingsTableOrderingComposer
    extends Composer<_$AppDatabase, $BatteryReadingsTable> {
  $$BatteryReadingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCharging => $composableBuilder(
    column: $table.isCharging,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );

  $$WatchesTableOrderingComposer get watchId {
    final $$WatchesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.watchId,
      referencedTable: $db.watches,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WatchesTableOrderingComposer(
            $db: $db,
            $table: $db.watches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BatteryReadingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BatteryReadingsTable> {
  $$BatteryReadingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get level =>
      $composableBuilder(column: $table.level, builder: (column) => column);

  GeneratedColumn<bool> get isCharging => $composableBuilder(
    column: $table.isCharging,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  $$WatchesTableAnnotationComposer get watchId {
    final $$WatchesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.watchId,
      referencedTable: $db.watches,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WatchesTableAnnotationComposer(
            $db: $db,
            $table: $db.watches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BatteryReadingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BatteryReadingsTable,
          BatteryReadingEntity,
          $$BatteryReadingsTableFilterComposer,
          $$BatteryReadingsTableOrderingComposer,
          $$BatteryReadingsTableAnnotationComposer,
          $$BatteryReadingsTableCreateCompanionBuilder,
          $$BatteryReadingsTableUpdateCompanionBuilder,
          (BatteryReadingEntity, $$BatteryReadingsTableReferences),
          BatteryReadingEntity,
          PrefetchHooks Function({bool watchId})
        > {
  $$BatteryReadingsTableTableManager(
    _$AppDatabase db,
    $BatteryReadingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BatteryReadingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BatteryReadingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BatteryReadingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> watchId = const Value.absent(),
                Value<int> level = const Value.absent(),
                Value<bool> isCharging = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
              }) => BatteryReadingsCompanion(
                id: id,
                watchId: watchId,
                level: level,
                isCharging: isCharging,
                timestamp: timestamp,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String watchId,
                required int level,
                Value<bool> isCharging = const Value.absent(),
                required DateTime timestamp,
              }) => BatteryReadingsCompanion.insert(
                id: id,
                watchId: watchId,
                level: level,
                isCharging: isCharging,
                timestamp: timestamp,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$BatteryReadingsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({watchId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (watchId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.watchId,
                                referencedTable:
                                    $$BatteryReadingsTableReferences
                                        ._watchIdTable(db),
                                referencedColumn:
                                    $$BatteryReadingsTableReferences
                                        ._watchIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$BatteryReadingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BatteryReadingsTable,
      BatteryReadingEntity,
      $$BatteryReadingsTableFilterComposer,
      $$BatteryReadingsTableOrderingComposer,
      $$BatteryReadingsTableAnnotationComposer,
      $$BatteryReadingsTableCreateCompanionBuilder,
      $$BatteryReadingsTableUpdateCompanionBuilder,
      (BatteryReadingEntity, $$BatteryReadingsTableReferences),
      BatteryReadingEntity,
      PrefetchHooks Function({bool watchId})
    >;
typedef $$CommLogEntriesTableCreateCompanionBuilder =
    CommLogEntriesCompanion Function({
      Value<int> id,
      required String direction,
      required String protocol,
      Value<String?> characteristic,
      required String payload,
      required int payloadSize,
      required DateTime timestamp,
    });
typedef $$CommLogEntriesTableUpdateCompanionBuilder =
    CommLogEntriesCompanion Function({
      Value<int> id,
      Value<String> direction,
      Value<String> protocol,
      Value<String?> characteristic,
      Value<String> payload,
      Value<int> payloadSize,
      Value<DateTime> timestamp,
    });

class $$CommLogEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $CommLogEntriesTable> {
  $$CommLogEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get protocol => $composableBuilder(
    column: $table.protocol,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get characteristic => $composableBuilder(
    column: $table.characteristic,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get payloadSize => $composableBuilder(
    column: $table.payloadSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CommLogEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CommLogEntriesTable> {
  $$CommLogEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get protocol => $composableBuilder(
    column: $table.protocol,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get characteristic => $composableBuilder(
    column: $table.characteristic,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get payloadSize => $composableBuilder(
    column: $table.payloadSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CommLogEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CommLogEntriesTable> {
  $$CommLogEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get direction =>
      $composableBuilder(column: $table.direction, builder: (column) => column);

  GeneratedColumn<String> get protocol =>
      $composableBuilder(column: $table.protocol, builder: (column) => column);

  GeneratedColumn<String> get characteristic => $composableBuilder(
    column: $table.characteristic,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<int> get payloadSize => $composableBuilder(
    column: $table.payloadSize,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);
}

class $$CommLogEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CommLogEntriesTable,
          CommLogEntryEntity,
          $$CommLogEntriesTableFilterComposer,
          $$CommLogEntriesTableOrderingComposer,
          $$CommLogEntriesTableAnnotationComposer,
          $$CommLogEntriesTableCreateCompanionBuilder,
          $$CommLogEntriesTableUpdateCompanionBuilder,
          (
            CommLogEntryEntity,
            BaseReferences<
              _$AppDatabase,
              $CommLogEntriesTable,
              CommLogEntryEntity
            >,
          ),
          CommLogEntryEntity,
          PrefetchHooks Function()
        > {
  $$CommLogEntriesTableTableManager(
    _$AppDatabase db,
    $CommLogEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CommLogEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CommLogEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CommLogEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> direction = const Value.absent(),
                Value<String> protocol = const Value.absent(),
                Value<String?> characteristic = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int> payloadSize = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
              }) => CommLogEntriesCompanion(
                id: id,
                direction: direction,
                protocol: protocol,
                characteristic: characteristic,
                payload: payload,
                payloadSize: payloadSize,
                timestamp: timestamp,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String direction,
                required String protocol,
                Value<String?> characteristic = const Value.absent(),
                required String payload,
                required int payloadSize,
                required DateTime timestamp,
              }) => CommLogEntriesCompanion.insert(
                id: id,
                direction: direction,
                protocol: protocol,
                characteristic: characteristic,
                payload: payload,
                payloadSize: payloadSize,
                timestamp: timestamp,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CommLogEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CommLogEntriesTable,
      CommLogEntryEntity,
      $$CommLogEntriesTableFilterComposer,
      $$CommLogEntriesTableOrderingComposer,
      $$CommLogEntriesTableAnnotationComposer,
      $$CommLogEntriesTableCreateCompanionBuilder,
      $$CommLogEntriesTableUpdateCompanionBuilder,
      (
        CommLogEntryEntity,
        BaseReferences<_$AppDatabase, $CommLogEntriesTable, CommLogEntryEntity>,
      ),
      CommLogEntryEntity,
      PrefetchHooks Function()
    >;
typedef $$ConnectionEventsTableCreateCompanionBuilder =
    ConnectionEventsCompanion Function({
      Value<int> id,
      required String watchId,
      required String eventType,
      required DateTime timestamp,
      Value<String?> reason,
      Value<String?> details,
      Value<String?> sessionId,
    });
typedef $$ConnectionEventsTableUpdateCompanionBuilder =
    ConnectionEventsCompanion Function({
      Value<int> id,
      Value<String> watchId,
      Value<String> eventType,
      Value<DateTime> timestamp,
      Value<String?> reason,
      Value<String?> details,
      Value<String?> sessionId,
    });

final class $$ConnectionEventsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $ConnectionEventsTable,
          ConnectionEventEntity
        > {
  $$ConnectionEventsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $WatchesTable _watchIdTable(_$AppDatabase db) =>
      db.watches.createAlias(
        $_aliasNameGenerator(db.connectionEvents.watchId, db.watches.id),
      );

  $$WatchesTableProcessedTableManager get watchId {
    final $_column = $_itemColumn<String>('watch_id')!;

    final manager = $$WatchesTableTableManager(
      $_db,
      $_db.watches,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_watchIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ConnectionEventsTableFilterComposer
    extends Composer<_$AppDatabase, $ConnectionEventsTable> {
  $$ConnectionEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eventType => $composableBuilder(
    column: $table.eventType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get details => $composableBuilder(
    column: $table.details,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  $$WatchesTableFilterComposer get watchId {
    final $$WatchesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.watchId,
      referencedTable: $db.watches,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WatchesTableFilterComposer(
            $db: $db,
            $table: $db.watches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ConnectionEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $ConnectionEventsTable> {
  $$ConnectionEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eventType => $composableBuilder(
    column: $table.eventType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get details => $composableBuilder(
    column: $table.details,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  $$WatchesTableOrderingComposer get watchId {
    final $$WatchesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.watchId,
      referencedTable: $db.watches,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WatchesTableOrderingComposer(
            $db: $db,
            $table: $db.watches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ConnectionEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ConnectionEventsTable> {
  $$ConnectionEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get eventType =>
      $composableBuilder(column: $table.eventType, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<String> get details =>
      $composableBuilder(column: $table.details, builder: (column) => column);

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  $$WatchesTableAnnotationComposer get watchId {
    final $$WatchesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.watchId,
      referencedTable: $db.watches,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WatchesTableAnnotationComposer(
            $db: $db,
            $table: $db.watches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ConnectionEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ConnectionEventsTable,
          ConnectionEventEntity,
          $$ConnectionEventsTableFilterComposer,
          $$ConnectionEventsTableOrderingComposer,
          $$ConnectionEventsTableAnnotationComposer,
          $$ConnectionEventsTableCreateCompanionBuilder,
          $$ConnectionEventsTableUpdateCompanionBuilder,
          (ConnectionEventEntity, $$ConnectionEventsTableReferences),
          ConnectionEventEntity,
          PrefetchHooks Function({bool watchId})
        > {
  $$ConnectionEventsTableTableManager(
    _$AppDatabase db,
    $ConnectionEventsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConnectionEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConnectionEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConnectionEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> watchId = const Value.absent(),
                Value<String> eventType = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
                Value<String?> reason = const Value.absent(),
                Value<String?> details = const Value.absent(),
                Value<String?> sessionId = const Value.absent(),
              }) => ConnectionEventsCompanion(
                id: id,
                watchId: watchId,
                eventType: eventType,
                timestamp: timestamp,
                reason: reason,
                details: details,
                sessionId: sessionId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String watchId,
                required String eventType,
                required DateTime timestamp,
                Value<String?> reason = const Value.absent(),
                Value<String?> details = const Value.absent(),
                Value<String?> sessionId = const Value.absent(),
              }) => ConnectionEventsCompanion.insert(
                id: id,
                watchId: watchId,
                eventType: eventType,
                timestamp: timestamp,
                reason: reason,
                details: details,
                sessionId: sessionId,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ConnectionEventsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({watchId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (watchId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.watchId,
                                referencedTable:
                                    $$ConnectionEventsTableReferences
                                        ._watchIdTable(db),
                                referencedColumn:
                                    $$ConnectionEventsTableReferences
                                        ._watchIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ConnectionEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ConnectionEventsTable,
      ConnectionEventEntity,
      $$ConnectionEventsTableFilterComposer,
      $$ConnectionEventsTableOrderingComposer,
      $$ConnectionEventsTableAnnotationComposer,
      $$ConnectionEventsTableCreateCompanionBuilder,
      $$ConnectionEventsTableUpdateCompanionBuilder,
      (ConnectionEventEntity, $$ConnectionEventsTableReferences),
      ConnectionEventEntity,
      PrefetchHooks Function({bool watchId})
    >;
typedef $$VoiceMemosTableCreateCompanionBuilder =
    VoiceMemosCompanion Function({
      Value<int> id,
      required String filename,
      required int timestampUtc,
      required int durationMs,
      required int sizeBytes,
      Value<String?> localFilePath,
      Value<String?> transcription,
      Value<bool> syncedFromWatch,
      Value<bool> deletedOnWatch,
      Value<DateTime?> downloadedAt,
      Value<DateTime?> transcribedAt,
      Value<String?> convertedFilePath,
      Value<String?> summary,
      Value<String?> category,
      Value<String?> processingStatus,
      Value<String?> aiModel,
      Value<DateTime?> aiProcessedAt,
      Value<bool> taskCreated,
      Value<bool> calendarEventCreated,
      Value<String?> actionReviewState,
    });
typedef $$VoiceMemosTableUpdateCompanionBuilder =
    VoiceMemosCompanion Function({
      Value<int> id,
      Value<String> filename,
      Value<int> timestampUtc,
      Value<int> durationMs,
      Value<int> sizeBytes,
      Value<String?> localFilePath,
      Value<String?> transcription,
      Value<bool> syncedFromWatch,
      Value<bool> deletedOnWatch,
      Value<DateTime?> downloadedAt,
      Value<DateTime?> transcribedAt,
      Value<String?> convertedFilePath,
      Value<String?> summary,
      Value<String?> category,
      Value<String?> processingStatus,
      Value<String?> aiModel,
      Value<DateTime?> aiProcessedAt,
      Value<bool> taskCreated,
      Value<bool> calendarEventCreated,
      Value<String?> actionReviewState,
    });

class $$VoiceMemosTableFilterComposer
    extends Composer<_$AppDatabase, $VoiceMemosTable> {
  $$VoiceMemosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
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

  ColumnFilters<String> get localFilePath => $composableBuilder(
    column: $table.localFilePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transcription => $composableBuilder(
    column: $table.transcription,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get syncedFromWatch => $composableBuilder(
    column: $table.syncedFromWatch,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deletedOnWatch => $composableBuilder(
    column: $table.deletedOnWatch,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get downloadedAt => $composableBuilder(
    column: $table.downloadedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get transcribedAt => $composableBuilder(
    column: $table.transcribedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get convertedFilePath => $composableBuilder(
    column: $table.convertedFilePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get processingStatus => $composableBuilder(
    column: $table.processingStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get aiModel => $composableBuilder(
    column: $table.aiModel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get aiProcessedAt => $composableBuilder(
    column: $table.aiProcessedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get taskCreated => $composableBuilder(
    column: $table.taskCreated,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get calendarEventCreated => $composableBuilder(
    column: $table.calendarEventCreated,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get actionReviewState => $composableBuilder(
    column: $table.actionReviewState,
    builder: (column) => ColumnFilters(column),
  );
}

class $$VoiceMemosTableOrderingComposer
    extends Composer<_$AppDatabase, $VoiceMemosTable> {
  $$VoiceMemosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
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

  ColumnOrderings<String> get localFilePath => $composableBuilder(
    column: $table.localFilePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transcription => $composableBuilder(
    column: $table.transcription,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get syncedFromWatch => $composableBuilder(
    column: $table.syncedFromWatch,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deletedOnWatch => $composableBuilder(
    column: $table.deletedOnWatch,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get downloadedAt => $composableBuilder(
    column: $table.downloadedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get transcribedAt => $composableBuilder(
    column: $table.transcribedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get convertedFilePath => $composableBuilder(
    column: $table.convertedFilePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get processingStatus => $composableBuilder(
    column: $table.processingStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get aiModel => $composableBuilder(
    column: $table.aiModel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get aiProcessedAt => $composableBuilder(
    column: $table.aiProcessedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get taskCreated => $composableBuilder(
    column: $table.taskCreated,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get calendarEventCreated => $composableBuilder(
    column: $table.calendarEventCreated,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actionReviewState => $composableBuilder(
    column: $table.actionReviewState,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VoiceMemosTableAnnotationComposer
    extends Composer<_$AppDatabase, $VoiceMemosTable> {
  $$VoiceMemosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

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

  GeneratedColumn<String> get localFilePath => $composableBuilder(
    column: $table.localFilePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get transcription => $composableBuilder(
    column: $table.transcription,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get syncedFromWatch => $composableBuilder(
    column: $table.syncedFromWatch,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get deletedOnWatch => $composableBuilder(
    column: $table.deletedOnWatch,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get downloadedAt => $composableBuilder(
    column: $table.downloadedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get transcribedAt => $composableBuilder(
    column: $table.transcribedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get convertedFilePath => $composableBuilder(
    column: $table.convertedFilePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get processingStatus => $composableBuilder(
    column: $table.processingStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get aiModel =>
      $composableBuilder(column: $table.aiModel, builder: (column) => column);

  GeneratedColumn<DateTime> get aiProcessedAt => $composableBuilder(
    column: $table.aiProcessedAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get taskCreated => $composableBuilder(
    column: $table.taskCreated,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get calendarEventCreated => $composableBuilder(
    column: $table.calendarEventCreated,
    builder: (column) => column,
  );

  GeneratedColumn<String> get actionReviewState => $composableBuilder(
    column: $table.actionReviewState,
    builder: (column) => column,
  );
}

class $$VoiceMemosTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VoiceMemosTable,
          VoiceMemoEntity,
          $$VoiceMemosTableFilterComposer,
          $$VoiceMemosTableOrderingComposer,
          $$VoiceMemosTableAnnotationComposer,
          $$VoiceMemosTableCreateCompanionBuilder,
          $$VoiceMemosTableUpdateCompanionBuilder,
          (
            VoiceMemoEntity,
            BaseReferences<_$AppDatabase, $VoiceMemosTable, VoiceMemoEntity>,
          ),
          VoiceMemoEntity,
          PrefetchHooks Function()
        > {
  $$VoiceMemosTableTableManager(_$AppDatabase db, $VoiceMemosTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VoiceMemosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VoiceMemosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VoiceMemosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> filename = const Value.absent(),
                Value<int> timestampUtc = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<int> sizeBytes = const Value.absent(),
                Value<String?> localFilePath = const Value.absent(),
                Value<String?> transcription = const Value.absent(),
                Value<bool> syncedFromWatch = const Value.absent(),
                Value<bool> deletedOnWatch = const Value.absent(),
                Value<DateTime?> downloadedAt = const Value.absent(),
                Value<DateTime?> transcribedAt = const Value.absent(),
                Value<String?> convertedFilePath = const Value.absent(),
                Value<String?> summary = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<String?> processingStatus = const Value.absent(),
                Value<String?> aiModel = const Value.absent(),
                Value<DateTime?> aiProcessedAt = const Value.absent(),
                Value<bool> taskCreated = const Value.absent(),
                Value<bool> calendarEventCreated = const Value.absent(),
                Value<String?> actionReviewState = const Value.absent(),
              }) => VoiceMemosCompanion(
                id: id,
                filename: filename,
                timestampUtc: timestampUtc,
                durationMs: durationMs,
                sizeBytes: sizeBytes,
                localFilePath: localFilePath,
                transcription: transcription,
                syncedFromWatch: syncedFromWatch,
                deletedOnWatch: deletedOnWatch,
                downloadedAt: downloadedAt,
                transcribedAt: transcribedAt,
                convertedFilePath: convertedFilePath,
                summary: summary,
                category: category,
                processingStatus: processingStatus,
                aiModel: aiModel,
                aiProcessedAt: aiProcessedAt,
                taskCreated: taskCreated,
                calendarEventCreated: calendarEventCreated,
                actionReviewState: actionReviewState,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String filename,
                required int timestampUtc,
                required int durationMs,
                required int sizeBytes,
                Value<String?> localFilePath = const Value.absent(),
                Value<String?> transcription = const Value.absent(),
                Value<bool> syncedFromWatch = const Value.absent(),
                Value<bool> deletedOnWatch = const Value.absent(),
                Value<DateTime?> downloadedAt = const Value.absent(),
                Value<DateTime?> transcribedAt = const Value.absent(),
                Value<String?> convertedFilePath = const Value.absent(),
                Value<String?> summary = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<String?> processingStatus = const Value.absent(),
                Value<String?> aiModel = const Value.absent(),
                Value<DateTime?> aiProcessedAt = const Value.absent(),
                Value<bool> taskCreated = const Value.absent(),
                Value<bool> calendarEventCreated = const Value.absent(),
                Value<String?> actionReviewState = const Value.absent(),
              }) => VoiceMemosCompanion.insert(
                id: id,
                filename: filename,
                timestampUtc: timestampUtc,
                durationMs: durationMs,
                sizeBytes: sizeBytes,
                localFilePath: localFilePath,
                transcription: transcription,
                syncedFromWatch: syncedFromWatch,
                deletedOnWatch: deletedOnWatch,
                downloadedAt: downloadedAt,
                transcribedAt: transcribedAt,
                convertedFilePath: convertedFilePath,
                summary: summary,
                category: category,
                processingStatus: processingStatus,
                aiModel: aiModel,
                aiProcessedAt: aiProcessedAt,
                taskCreated: taskCreated,
                calendarEventCreated: calendarEventCreated,
                actionReviewState: actionReviewState,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$VoiceMemosTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VoiceMemosTable,
      VoiceMemoEntity,
      $$VoiceMemosTableFilterComposer,
      $$VoiceMemosTableOrderingComposer,
      $$VoiceMemosTableAnnotationComposer,
      $$VoiceMemosTableCreateCompanionBuilder,
      $$VoiceMemosTableUpdateCompanionBuilder,
      (
        VoiceMemoEntity,
        BaseReferences<_$AppDatabase, $VoiceMemosTable, VoiceMemoEntity>,
      ),
      VoiceMemoEntity,
      PrefetchHooks Function()
    >;
typedef $$ExtractedActionsTableCreateCompanionBuilder =
    ExtractedActionsCompanion Function({
      Value<int> id,
      required int memoId,
      required String actionType,
      required String title,
      Value<String?> notes,
      Value<DateTime?> startTime,
      Value<DateTime?> endTime,
      Value<DateTime?> dueDate,
      Value<String?> location,
      Value<int?> reminderMinutes,
      Value<bool> created,
      Value<bool> dismissed,
      Value<String?> platformTargetId,
      Value<int?> durationSeconds,
      Value<DateTime?> createdAt,
    });
typedef $$ExtractedActionsTableUpdateCompanionBuilder =
    ExtractedActionsCompanion Function({
      Value<int> id,
      Value<int> memoId,
      Value<String> actionType,
      Value<String> title,
      Value<String?> notes,
      Value<DateTime?> startTime,
      Value<DateTime?> endTime,
      Value<DateTime?> dueDate,
      Value<String?> location,
      Value<int?> reminderMinutes,
      Value<bool> created,
      Value<bool> dismissed,
      Value<String?> platformTargetId,
      Value<int?> durationSeconds,
      Value<DateTime?> createdAt,
    });

class $$ExtractedActionsTableFilterComposer
    extends Composer<_$AppDatabase, $ExtractedActionsTable> {
  $$ExtractedActionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get memoId => $composableBuilder(
    column: $table.memoId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get actionType => $composableBuilder(
    column: $table.actionType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startTime => $composableBuilder(
    column: $table.startTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endTime => $composableBuilder(
    column: $table.endTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reminderMinutes => $composableBuilder(
    column: $table.reminderMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get created => $composableBuilder(
    column: $table.created,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dismissed => $composableBuilder(
    column: $table.dismissed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get platformTargetId => $composableBuilder(
    column: $table.platformTargetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ExtractedActionsTableOrderingComposer
    extends Composer<_$AppDatabase, $ExtractedActionsTable> {
  $$ExtractedActionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get memoId => $composableBuilder(
    column: $table.memoId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actionType => $composableBuilder(
    column: $table.actionType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startTime => $composableBuilder(
    column: $table.startTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endTime => $composableBuilder(
    column: $table.endTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reminderMinutes => $composableBuilder(
    column: $table.reminderMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get created => $composableBuilder(
    column: $table.created,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dismissed => $composableBuilder(
    column: $table.dismissed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get platformTargetId => $composableBuilder(
    column: $table.platformTargetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ExtractedActionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExtractedActionsTable> {
  $$ExtractedActionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get memoId =>
      $composableBuilder(column: $table.memoId, builder: (column) => column);

  GeneratedColumn<String> get actionType => $composableBuilder(
    column: $table.actionType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get startTime =>
      $composableBuilder(column: $table.startTime, builder: (column) => column);

  GeneratedColumn<DateTime> get endTime =>
      $composableBuilder(column: $table.endTime, builder: (column) => column);

  GeneratedColumn<DateTime> get dueDate =>
      $composableBuilder(column: $table.dueDate, builder: (column) => column);

  GeneratedColumn<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => column);

  GeneratedColumn<int> get reminderMinutes => $composableBuilder(
    column: $table.reminderMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get created =>
      $composableBuilder(column: $table.created, builder: (column) => column);

  GeneratedColumn<bool> get dismissed =>
      $composableBuilder(column: $table.dismissed, builder: (column) => column);

  GeneratedColumn<String> get platformTargetId => $composableBuilder(
    column: $table.platformTargetId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ExtractedActionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ExtractedActionsTable,
          ExtractedActionEntity,
          $$ExtractedActionsTableFilterComposer,
          $$ExtractedActionsTableOrderingComposer,
          $$ExtractedActionsTableAnnotationComposer,
          $$ExtractedActionsTableCreateCompanionBuilder,
          $$ExtractedActionsTableUpdateCompanionBuilder,
          (
            ExtractedActionEntity,
            BaseReferences<
              _$AppDatabase,
              $ExtractedActionsTable,
              ExtractedActionEntity
            >,
          ),
          ExtractedActionEntity,
          PrefetchHooks Function()
        > {
  $$ExtractedActionsTableTableManager(
    _$AppDatabase db,
    $ExtractedActionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExtractedActionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExtractedActionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExtractedActionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> memoId = const Value.absent(),
                Value<String> actionType = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime?> startTime = const Value.absent(),
                Value<DateTime?> endTime = const Value.absent(),
                Value<DateTime?> dueDate = const Value.absent(),
                Value<String?> location = const Value.absent(),
                Value<int?> reminderMinutes = const Value.absent(),
                Value<bool> created = const Value.absent(),
                Value<bool> dismissed = const Value.absent(),
                Value<String?> platformTargetId = const Value.absent(),
                Value<int?> durationSeconds = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
              }) => ExtractedActionsCompanion(
                id: id,
                memoId: memoId,
                actionType: actionType,
                title: title,
                notes: notes,
                startTime: startTime,
                endTime: endTime,
                dueDate: dueDate,
                location: location,
                reminderMinutes: reminderMinutes,
                created: created,
                dismissed: dismissed,
                platformTargetId: platformTargetId,
                durationSeconds: durationSeconds,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int memoId,
                required String actionType,
                required String title,
                Value<String?> notes = const Value.absent(),
                Value<DateTime?> startTime = const Value.absent(),
                Value<DateTime?> endTime = const Value.absent(),
                Value<DateTime?> dueDate = const Value.absent(),
                Value<String?> location = const Value.absent(),
                Value<int?> reminderMinutes = const Value.absent(),
                Value<bool> created = const Value.absent(),
                Value<bool> dismissed = const Value.absent(),
                Value<String?> platformTargetId = const Value.absent(),
                Value<int?> durationSeconds = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
              }) => ExtractedActionsCompanion.insert(
                id: id,
                memoId: memoId,
                actionType: actionType,
                title: title,
                notes: notes,
                startTime: startTime,
                endTime: endTime,
                dueDate: dueDate,
                location: location,
                reminderMinutes: reminderMinutes,
                created: created,
                dismissed: dismissed,
                platformTargetId: platformTargetId,
                durationSeconds: durationSeconds,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ExtractedActionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ExtractedActionsTable,
      ExtractedActionEntity,
      $$ExtractedActionsTableFilterComposer,
      $$ExtractedActionsTableOrderingComposer,
      $$ExtractedActionsTableAnnotationComposer,
      $$ExtractedActionsTableCreateCompanionBuilder,
      $$ExtractedActionsTableUpdateCompanionBuilder,
      (
        ExtractedActionEntity,
        BaseReferences<
          _$AppDatabase,
          $ExtractedActionsTable,
          ExtractedActionEntity
        >,
      ),
      ExtractedActionEntity,
      PrefetchHooks Function()
    >;
typedef $$CrashReportsTableCreateCompanionBuilder =
    CrashReportsCompanion Function({
      Value<int> id,
      required String watchId,
      required String file,
      required int line,
      required String crashTime,
      required String fwVersion,
      required String fwCommitSha,
      required String board,
      required String buildType,
      required DateTime receivedAt,
      Value<bool> analyzed,
      Value<String?> backtrace,
      Value<String?> registers,
      Value<String?> rawOutput,
      Value<String?> analysisError,
      Value<bool> elfAvailable,
    });
typedef $$CrashReportsTableUpdateCompanionBuilder =
    CrashReportsCompanion Function({
      Value<int> id,
      Value<String> watchId,
      Value<String> file,
      Value<int> line,
      Value<String> crashTime,
      Value<String> fwVersion,
      Value<String> fwCommitSha,
      Value<String> board,
      Value<String> buildType,
      Value<DateTime> receivedAt,
      Value<bool> analyzed,
      Value<String?> backtrace,
      Value<String?> registers,
      Value<String?> rawOutput,
      Value<String?> analysisError,
      Value<bool> elfAvailable,
    });

final class $$CrashReportsTableReferences
    extends
        BaseReferences<_$AppDatabase, $CrashReportsTable, CrashReportEntity> {
  $$CrashReportsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $WatchesTable _watchIdTable(_$AppDatabase db) =>
      db.watches.createAlias(
        $_aliasNameGenerator(db.crashReports.watchId, db.watches.id),
      );

  $$WatchesTableProcessedTableManager get watchId {
    final $_column = $_itemColumn<String>('watch_id')!;

    final manager = $$WatchesTableTableManager(
      $_db,
      $_db.watches,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_watchIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CrashReportsTableFilterComposer
    extends Composer<_$AppDatabase, $CrashReportsTable> {
  $$CrashReportsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get file => $composableBuilder(
    column: $table.file,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get line => $composableBuilder(
    column: $table.line,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get crashTime => $composableBuilder(
    column: $table.crashTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fwVersion => $composableBuilder(
    column: $table.fwVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fwCommitSha => $composableBuilder(
    column: $table.fwCommitSha,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get board => $composableBuilder(
    column: $table.board,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get buildType => $composableBuilder(
    column: $table.buildType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get receivedAt => $composableBuilder(
    column: $table.receivedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get analyzed => $composableBuilder(
    column: $table.analyzed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get backtrace => $composableBuilder(
    column: $table.backtrace,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get registers => $composableBuilder(
    column: $table.registers,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawOutput => $composableBuilder(
    column: $table.rawOutput,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get analysisError => $composableBuilder(
    column: $table.analysisError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get elfAvailable => $composableBuilder(
    column: $table.elfAvailable,
    builder: (column) => ColumnFilters(column),
  );

  $$WatchesTableFilterComposer get watchId {
    final $$WatchesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.watchId,
      referencedTable: $db.watches,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WatchesTableFilterComposer(
            $db: $db,
            $table: $db.watches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CrashReportsTableOrderingComposer
    extends Composer<_$AppDatabase, $CrashReportsTable> {
  $$CrashReportsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get file => $composableBuilder(
    column: $table.file,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get line => $composableBuilder(
    column: $table.line,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get crashTime => $composableBuilder(
    column: $table.crashTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fwVersion => $composableBuilder(
    column: $table.fwVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fwCommitSha => $composableBuilder(
    column: $table.fwCommitSha,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get board => $composableBuilder(
    column: $table.board,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get buildType => $composableBuilder(
    column: $table.buildType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get receivedAt => $composableBuilder(
    column: $table.receivedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get analyzed => $composableBuilder(
    column: $table.analyzed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get backtrace => $composableBuilder(
    column: $table.backtrace,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get registers => $composableBuilder(
    column: $table.registers,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawOutput => $composableBuilder(
    column: $table.rawOutput,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get analysisError => $composableBuilder(
    column: $table.analysisError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get elfAvailable => $composableBuilder(
    column: $table.elfAvailable,
    builder: (column) => ColumnOrderings(column),
  );

  $$WatchesTableOrderingComposer get watchId {
    final $$WatchesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.watchId,
      referencedTable: $db.watches,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WatchesTableOrderingComposer(
            $db: $db,
            $table: $db.watches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CrashReportsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CrashReportsTable> {
  $$CrashReportsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get file =>
      $composableBuilder(column: $table.file, builder: (column) => column);

  GeneratedColumn<int> get line =>
      $composableBuilder(column: $table.line, builder: (column) => column);

  GeneratedColumn<String> get crashTime =>
      $composableBuilder(column: $table.crashTime, builder: (column) => column);

  GeneratedColumn<String> get fwVersion =>
      $composableBuilder(column: $table.fwVersion, builder: (column) => column);

  GeneratedColumn<String> get fwCommitSha => $composableBuilder(
    column: $table.fwCommitSha,
    builder: (column) => column,
  );

  GeneratedColumn<String> get board =>
      $composableBuilder(column: $table.board, builder: (column) => column);

  GeneratedColumn<String> get buildType =>
      $composableBuilder(column: $table.buildType, builder: (column) => column);

  GeneratedColumn<DateTime> get receivedAt => $composableBuilder(
    column: $table.receivedAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get analyzed =>
      $composableBuilder(column: $table.analyzed, builder: (column) => column);

  GeneratedColumn<String> get backtrace =>
      $composableBuilder(column: $table.backtrace, builder: (column) => column);

  GeneratedColumn<String> get registers =>
      $composableBuilder(column: $table.registers, builder: (column) => column);

  GeneratedColumn<String> get rawOutput =>
      $composableBuilder(column: $table.rawOutput, builder: (column) => column);

  GeneratedColumn<String> get analysisError => $composableBuilder(
    column: $table.analysisError,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get elfAvailable => $composableBuilder(
    column: $table.elfAvailable,
    builder: (column) => column,
  );

  $$WatchesTableAnnotationComposer get watchId {
    final $$WatchesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.watchId,
      referencedTable: $db.watches,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WatchesTableAnnotationComposer(
            $db: $db,
            $table: $db.watches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CrashReportsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CrashReportsTable,
          CrashReportEntity,
          $$CrashReportsTableFilterComposer,
          $$CrashReportsTableOrderingComposer,
          $$CrashReportsTableAnnotationComposer,
          $$CrashReportsTableCreateCompanionBuilder,
          $$CrashReportsTableUpdateCompanionBuilder,
          (CrashReportEntity, $$CrashReportsTableReferences),
          CrashReportEntity,
          PrefetchHooks Function({bool watchId})
        > {
  $$CrashReportsTableTableManager(_$AppDatabase db, $CrashReportsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CrashReportsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CrashReportsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CrashReportsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> watchId = const Value.absent(),
                Value<String> file = const Value.absent(),
                Value<int> line = const Value.absent(),
                Value<String> crashTime = const Value.absent(),
                Value<String> fwVersion = const Value.absent(),
                Value<String> fwCommitSha = const Value.absent(),
                Value<String> board = const Value.absent(),
                Value<String> buildType = const Value.absent(),
                Value<DateTime> receivedAt = const Value.absent(),
                Value<bool> analyzed = const Value.absent(),
                Value<String?> backtrace = const Value.absent(),
                Value<String?> registers = const Value.absent(),
                Value<String?> rawOutput = const Value.absent(),
                Value<String?> analysisError = const Value.absent(),
                Value<bool> elfAvailable = const Value.absent(),
              }) => CrashReportsCompanion(
                id: id,
                watchId: watchId,
                file: file,
                line: line,
                crashTime: crashTime,
                fwVersion: fwVersion,
                fwCommitSha: fwCommitSha,
                board: board,
                buildType: buildType,
                receivedAt: receivedAt,
                analyzed: analyzed,
                backtrace: backtrace,
                registers: registers,
                rawOutput: rawOutput,
                analysisError: analysisError,
                elfAvailable: elfAvailable,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String watchId,
                required String file,
                required int line,
                required String crashTime,
                required String fwVersion,
                required String fwCommitSha,
                required String board,
                required String buildType,
                required DateTime receivedAt,
                Value<bool> analyzed = const Value.absent(),
                Value<String?> backtrace = const Value.absent(),
                Value<String?> registers = const Value.absent(),
                Value<String?> rawOutput = const Value.absent(),
                Value<String?> analysisError = const Value.absent(),
                Value<bool> elfAvailable = const Value.absent(),
              }) => CrashReportsCompanion.insert(
                id: id,
                watchId: watchId,
                file: file,
                line: line,
                crashTime: crashTime,
                fwVersion: fwVersion,
                fwCommitSha: fwCommitSha,
                board: board,
                buildType: buildType,
                receivedAt: receivedAt,
                analyzed: analyzed,
                backtrace: backtrace,
                registers: registers,
                rawOutput: rawOutput,
                analysisError: analysisError,
                elfAvailable: elfAvailable,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CrashReportsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({watchId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (watchId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.watchId,
                                referencedTable: $$CrashReportsTableReferences
                                    ._watchIdTable(db),
                                referencedColumn: $$CrashReportsTableReferences
                                    ._watchIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$CrashReportsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CrashReportsTable,
      CrashReportEntity,
      $$CrashReportsTableFilterComposer,
      $$CrashReportsTableOrderingComposer,
      $$CrashReportsTableAnnotationComposer,
      $$CrashReportsTableCreateCompanionBuilder,
      $$CrashReportsTableUpdateCompanionBuilder,
      (CrashReportEntity, $$CrashReportsTableReferences),
      CrashReportEntity,
      PrefetchHooks Function({bool watchId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$WatchesTableTableManager get watches =>
      $$WatchesTableTableManager(_db, _db.watches);
  $$HealthSamplesTableTableManager get healthSamples =>
      $$HealthSamplesTableTableManager(_db, _db.healthSamples);
  $$BatteryReadingsTableTableManager get batteryReadings =>
      $$BatteryReadingsTableTableManager(_db, _db.batteryReadings);
  $$CommLogEntriesTableTableManager get commLogEntries =>
      $$CommLogEntriesTableTableManager(_db, _db.commLogEntries);
  $$ConnectionEventsTableTableManager get connectionEvents =>
      $$ConnectionEventsTableTableManager(_db, _db.connectionEvents);
  $$VoiceMemosTableTableManager get voiceMemos =>
      $$VoiceMemosTableTableManager(_db, _db.voiceMemos);
  $$ExtractedActionsTableTableManager get extractedActions =>
      $$ExtractedActionsTableTableManager(_db, _db.extractedActions);
  $$CrashReportsTableTableManager get crashReports =>
      $$CrashReportsTableTableManager(_db, _db.crashReports);
}
