import 'package:drift/drift.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../database/app_database.dart';
import '../models/watch.dart';
import 'base_repository.dart';

/// Repository for Watch data operations
///
/// Provides a clean interface for CRUD operations on watches,
/// abstracting the database layer from the rest of the app.
class WatchRepository extends BaseRepository<Watch, WatchEntity> {
  final AppDatabase _db;

  WatchRepository(this._db);

  // ==================== Read Operations ====================

  /// Get all saved watches
  Future<List<Watch>> getAllWatches() async {
    final entities = await _db.getAllWatches();
    return entities.map(_entityToModel).toList();
  }

  /// Watch all saved watches (stream)
  Stream<List<Watch>> watchAllWatches() {
    return _db.watchAllWatches().map(
      (entities) => entities.map(_entityToModel).toList(),
    );
  }

  /// Get watch by ID
  Future<Watch?> getWatchById(String id) async {
    final entity = await _db.getWatchById(id);
    return entity != null ? _entityToModel(entity) : null;
  }

  /// Get the primary (selected) watch
  Future<Watch?> getPrimaryWatch() async {
    final entity = await _db.getPrimaryWatch();
    return entity != null ? _entityToModel(entity) : null;
  }

  /// Get the last connected watch (most recent lastConnectedAt)
  Future<Watch?> getLastConnectedWatch() async {
    final watches = await getAllWatches();
    if (watches.isEmpty) return null;

    // Sort by lastConnectedAt descending, null values last
    watches.sort((a, b) {
      if (a.lastConnectedAt == null && b.lastConnectedAt == null) return 0;
      if (a.lastConnectedAt == null) return 1;
      if (b.lastConnectedAt == null) return -1;
      return b.lastConnectedAt!.compareTo(a.lastConnectedAt!);
    });

    return watches.firstOrNull;
  }

  /// Check if a watch exists
  Future<bool> watchExists(String id) async {
    final watch = await _db.getWatchById(id);
    return watch != null;
  }

  // ==================== Write Operations ====================

  /// Save a new watch (after pairing)
  Future<void> saveWatch(Watch watch) async {
    await _db.upsertWatch(_modelToCompanion(watch));
  }

  /// Update an existing watch
  Future<void> updateWatch(Watch watch) async {
    await _db.upsertWatch(_modelToCompanion(watch));
  }

  /// Set a watch as primary
  Future<void> setPrimaryWatch(String watchId) async {
    await _db.setWatchAsPrimary(watchId);
  }

  /// Update watch battery level
  Future<void> updateBatteryLevel(String watchId, int level) async {
    await _db.updateWatchBattery(watchId, level);
  }

  /// Update watch firmware version
  Future<void> updateFirmwareVersion(
    String watchId,
    String firmwareVersion, {
    String? hardwareVersion,
  }) async {
    final watch = await getWatchById(watchId);
    if (watch != null) {
      await updateWatch(
        watch.copyWith(
          firmwareVersion: firmwareVersion,
          hardwareVersion: hardwareVersion ?? watch.hardwareVersion,
        ),
      );
    }
  }

  /// Update watch last connected timestamp
  Future<void> updateLastConnected(String watchId) async {
    await _db.updateWatchLastConnected(watchId);
  }

  /// Update watch custom name (FR-099 to FR-102)
  Future<void> updateCustomName(String watchId, String? customName) async {
    final watch = await getWatchById(watchId);
    if (watch != null) {
      await updateWatch(watch.copyWith(customName: customName));
    }
  }

  /// Rename a watch by setting its custom name (T114)
  ///
  /// If [customName] is null or empty, clears the custom name and
  /// falls back to the default advertised name.
  Future<void> renameWatch(String watchId, String? customName) async {
    final trimmed = customName?.trim();
    final finalName = (trimmed != null && trimmed.isNotEmpty) ? trimmed : null;
    await updateCustomName(watchId, finalName);
  }

  /// Mark watch as supporting Extended API
  Future<void> setSupportsExtendedApi(String watchId, bool supports) async {
    final watch = await getWatchById(watchId);
    if (watch != null) {
      await updateWatch(watch.copyWith(supportsExtendedApi: supports));
    }
  }

  // ==================== Delete Operations ====================

  /// Delete a watch and all associated data
  Future<void> deleteWatch(String watchId) async {
    await _db.deleteWatch(watchId);
  }

  /// Forget a watch completely (T115)
  ///
  /// This removes the watch from the database AND removes the BLE bond.
  /// After calling this, the user will need to re-pair if they want to
  /// use the watch again.
  ///
  /// Note: removeBond() only works on Android. On iOS, users must
  /// manually forget the device in Bluetooth settings.
  Future<void> forgetWatch(String watchId) async {
    // First, remove the BLE bond
    try {
      final device = BluetoothDevice.fromId(watchId);
      await device.removeBond();
    } catch (e) {
      // Bond removal may fail if device is not bonded or on iOS
      // Continue with database deletion anyway
    }

    // Then delete from database
    await deleteWatch(watchId);
  }

  /// Delete all watches
  Future<void> deleteAllWatches() async {
    final watches = await getAllWatches();
    for (final watch in watches) {
      await deleteWatch(watch.id);
    }
  }

  // ==================== Utility Operations ====================

  /// Get watch count
  Future<int> getWatchCount() async {
    final watches = await getAllWatches();
    return watches.length;
  }

  /// Check if any watches are saved
  Future<bool> hasAnyWatches() async {
    final count = await getWatchCount();
    return count > 0;
  }

  /// Run data cleanup (60-day retention)
  Future<void> cleanupOldData() async {
    await _db.cleanupOldData();
  }

  // ==================== Mapping ====================

  @override
  Watch fromEntity(WatchEntity entity) => _entityToModel(entity);

  Watch _entityToModel(WatchEntity entity) {
    return Watch(
      id: entity.id,
      name: entity.name,
      customName: entity.customName,
      firmwareVersion: entity.firmwareVersion,
      hardwareVersion: entity.hardwareVersion,
      batteryLevel: entity.batteryLevel,
      isPrimary: entity.isPrimary,
      supportsExtendedApi: entity.supportsExtendedApi,
      lastConnectedAt: entity.lastConnectedAt,
      createdAt: entity.createdAt,
    );
  }

  WatchesCompanion _modelToCompanion(Watch watch) {
    return WatchesCompanion(
      id: Value(watch.id),
      name: Value(watch.name),
      customName: Value(watch.customName),
      firmwareVersion: Value(watch.firmwareVersion),
      hardwareVersion: Value(watch.hardwareVersion),
      batteryLevel: Value(watch.batteryLevel),
      isPrimary: Value(watch.isPrimary),
      supportsExtendedApi: Value(watch.supportsExtendedApi),
      lastConnectedAt: Value(watch.lastConnectedAt),
      createdAt: Value(watch.createdAt),
    );
  }
}
