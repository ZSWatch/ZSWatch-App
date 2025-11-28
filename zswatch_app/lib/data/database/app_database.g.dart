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
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (healthSamplesRefs) db.healthSamples,
                    if (batteryReadingsRefs) db.batteryReadings,
                    if (connectionEventsRefs) db.connectionEvents,
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
}
