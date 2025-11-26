import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/app_database.dart';

/// Provider for the database singleton
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

/// Provider for all saved watches
final allWatchesProvider = StreamProvider<List<WatchEntity>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllWatches();
});

/// Provider for the primary watch
final primaryWatchProvider = FutureProvider<WatchEntity?>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getPrimaryWatch();
});

/// Provider for a specific watch by ID
final watchByIdProvider =
    FutureProvider.family<WatchEntity?, String>((ref, watchId) async {
  final db = ref.watch(databaseProvider);
  return db.getWatchById(watchId);
});

/// Provider for the currently connected watch info
final connectedWatchProvider = Provider<WatchEntity?>((ref) {
  // This will be updated when connection state changes
  // For now, return the primary watch
  final asyncValue = ref.watch(primaryWatchProvider);
  return asyncValue.valueOrNull;
});

/// Notifier for watch operations
class WatchNotifier extends StateNotifier<AsyncValue<void>> {
  final AppDatabase _db;

  WatchNotifier(this._db) : super(const AsyncValue.data(null));

  /// Add or update a watch
  Future<void> saveWatch({
    required String id,
    required String name,
    String? firmwareVersion,
    String? hardwareVersion,
    int? batteryLevel,
    bool isPrimary = false,
    bool supportsExtendedApi = false,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _db.upsertWatch(WatchesCompanion(
        id: Value(id),
        name: Value(name),
        firmwareVersion: Value(firmwareVersion),
        hardwareVersion: Value(hardwareVersion),
        batteryLevel: Value(batteryLevel),
        isPrimary: Value(isPrimary),
        supportsExtendedApi: Value(supportsExtendedApi),
        createdAt: Value(DateTime.now()),
      ));
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Set a watch as primary
  Future<void> setPrimaryWatch(String watchId) async {
    state = const AsyncValue.loading();
    try {
      await _db.setWatchAsPrimary(watchId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Update watch battery level
  Future<void> updateBatteryLevel(String watchId, int level) async {
    try {
      await _db.updateWatchBattery(watchId, level);
    } catch (_) {
      // Ignore battery update failures
    }
  }

  /// Update watch last connected timestamp
  Future<void> updateLastConnected(String watchId) async {
    try {
      await _db.updateWatchLastConnected(watchId);
    } catch (_) {
      // Ignore timestamp update failures
    }
  }

  /// Delete a watch and its data
  Future<void> deleteWatch(String watchId) async {
    state = const AsyncValue.loading();
    try {
      await _db.deleteWatch(watchId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Run data cleanup (60-day retention)
  Future<void> cleanupOldData() async {
    try {
      await _db.cleanupOldData();
    } catch (_) {
      // Ignore cleanup failures
    }
  }
}

/// Provider for watch operations notifier
final watchNotifierProvider =
    StateNotifierProvider<WatchNotifier, AsyncValue<void>>((ref) {
  final db = ref.watch(databaseProvider);
  return WatchNotifier(db);
});

/// Provider for watch count
final watchCountProvider = Provider<int>((ref) {
  final asyncValue = ref.watch(allWatchesProvider);
  return asyncValue.valueOrNull?.length ?? 0;
});

/// Provider for whether any watches are saved
final hasWatchesProvider = Provider<bool>((ref) {
  return ref.watch(watchCountProvider) > 0;
});

