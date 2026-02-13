import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/connection.dart';
import '../data/models/connection_state.dart';
import '../data/models/watch.dart';
import '../data/repositories/watch_repository.dart';
import '../services/watch_service.dart';
import '../services/ble/ble_scanner.dart';
import 'demo_mode_provider.dart';
import 'watch_providers.dart';

/// Provider for the unified WatchService
final watchServiceProvider = Provider<WatchService>((ref) {
  final service = WatchService();
  debugPrint('[watchServiceProvider] Created WatchService instance: ${service.hashCode}');
  ref.onDispose(() {
    debugPrint('[watchServiceProvider] Disposing WatchService instance: ${service.hashCode}');
    service.dispose();
  });
  return service;
});

/// Provider for connection state stream
final watchConnectionStreamProvider = StreamProvider<Connection>((ref) {
  final service = ref.watch(watchServiceProvider);
  return service.connectionStream;
});

/// Provider for current connection (non-stream)
///
/// In demo mode, returns a fake "connected" connection so all screens
/// are accessible without real hardware.
final watchConnectionProvider = Provider<Connection>((ref) {
  final demo = demoConnectionOrNull(ref);
  if (demo != null) return demo;

  final asyncValue = ref.watch(watchConnectionStreamProvider);
  return asyncValue.valueOrNull ?? const Connection(
    watchId: '',
    state: WatchConnectionState.disconnected,
  );
});

/// Provider for whether watch is connected
final isWatchConnectedProvider = Provider<bool>((ref) {
  final connection = ref.watch(watchConnectionProvider);
  return connection.state == WatchConnectionState.connected;
});

/// Provider for connection state enum
final watchConnectionStateProvider = Provider<WatchConnectionState>((ref) {
  final connection = ref.watch(watchConnectionProvider);
  return connection.state;
});

/// Provider for watch info stream
final watchInfoStreamProvider = StreamProvider<Watch?>((ref) {
  final service = ref.watch(watchServiceProvider);
  return service.watchInfoStream;
});

/// Provider for current watch info - merges live service data with database data
/// 
/// The service provides live updates (battery, firmware from protocol, etc.)
/// The database provides persisted data (customName, etc.)
/// This provider merges them to provide a complete Watch with all fields.
///
/// In demo mode, returns a static placeholder watch.
final currentWatchProvider = Provider<Watch?>((ref) {
  final demo = demoWatchOrNull(ref);
  if (demo != null) return demo;

  // Watch the stream to get reactive updates from the service
  final asyncValue = ref.watch(watchInfoStreamProvider);
  // Also get the synchronous value directly from the service as fallback
  final service = ref.watch(watchServiceProvider);
  
  // Get the service's watch info (has live updates)
  final serviceWatch = asyncValue.valueOrNull ?? service.currentWatch;
  if (serviceWatch == null) return null;
  
  // Get the database watch info (has customName and other persisted data)
  final dbWatchAsync = ref.watch(watchByIdProvider(serviceWatch.id));
  final dbWatch = dbWatchAsync.valueOrNull;
  
  // Merge: use service watch as base, overlay customName from database
  if (dbWatch != null && dbWatch.customName != null) {
    return serviceWatch.copyWith(customName: dbWatch.customName);
  }
  
  return serviceWatch;
});

/// Provider for current watch (non-null when connected)
final connectedWatchProvider = Provider<Watch?>((ref) {
  final isConnected = ref.watch(isWatchConnectedProvider);
  if (!isConnected) return null;
  return ref.watch(currentWatchProvider);
});

/// Provider for battery level stream
final batteryLevelStreamProvider = StreamProvider<int>((ref) {
  final service = ref.watch(watchServiceProvider);
  return service.batteryStream;
});

/// Provider for current battery level
final batteryLevelProvider = Provider<int?>((ref) {
  final asyncValue = ref.watch(batteryLevelStreamProvider);
  return asyncValue.valueOrNull;
});

/// Provider for whether the connected watch has the SMP service available
/// (required for DFU firmware updates and filesystem uploads).
/// Re-evaluated whenever connection state changes.
final hasSmpServiceProvider = Provider<bool>((ref) {
  // Watch connection state to re-evaluate when connection changes
  final isConnected = ref.watch(isWatchConnectedProvider);
  if (!isConnected) return false;
  final service = ref.watch(watchServiceProvider);
  return service.hasSmpService;
});

/// Provider that syncs watch info changes to the database.
/// 
/// This provider listens to watch info stream and persists changes
/// (firmware version, hardware version, battery level, lastConnectedAt)
/// to the database when they change.
final watchInfoPersistenceProvider = Provider<void>((ref) {
  final db = ref.watch(databaseProvider);
  final repository = WatchRepository(db);
  
  // Track last persisted values to avoid duplicate writes
  String? lastPersistedFw;
  String? lastPersistedHw;
  
  // Listen to watch info changes and persist to database
  ref.listen(watchInfoStreamProvider, (previous, next) {
    final watch = next.valueOrNull;
    if (watch == null || watch.id.isEmpty) return;
    
    // Check if firmware or hardware version changed
    final fwChanged = watch.firmwareVersion != null && 
        watch.firmwareVersion != lastPersistedFw;
    final hwChanged = watch.hardwareVersion != null && 
        watch.hardwareVersion != lastPersistedHw;
    
    if (fwChanged || hwChanged) {
      debugPrint('[WatchInfoPersistence] Persisting firmware/hw version: '
          'fw=${watch.firmwareVersion}, hw=${watch.hardwareVersion}');
      
      if (watch.firmwareVersion != null) {
        lastPersistedFw = watch.firmwareVersion;
      }
      if (watch.hardwareVersion != null) {
        lastPersistedHw = watch.hardwareVersion;
      }
      
      unawaited(repository.updateFirmwareVersion(
        watch.id,
        watch.firmwareVersion ?? '',
        hardwareVersion: watch.hardwareVersion,
      ));
    }
  });
  
  // Listen to connection state to update lastConnectedAt when connected
  bool hasUpdatedLastConnected = false;
  String lastConnectedWatchId = '';
  
  ref.listen(watchConnectionStreamProvider, (previous, next) {
    final connection = next.valueOrNull;
    if (connection == null) return;
    
    // Reset tracking when disconnected or connecting to different device
    if (connection.state == WatchConnectionState.disconnected ||
        connection.watchId != lastConnectedWatchId) {
      hasUpdatedLastConnected = false;
      lastConnectedWatchId = connection.watchId;
    }
    
    // Update lastConnectedAt when connection becomes connected (once per connection)
    if (connection.state == WatchConnectionState.connected && 
        connection.watchId.isNotEmpty &&
        !hasUpdatedLastConnected) {
      hasUpdatedLastConnected = true;
      debugPrint('[WatchInfoPersistence] Updating lastConnectedAt for ${connection.watchId}');
      unawaited(repository.updateLastConnected(connection.watchId));
    }
  });
});

/// Notifier for watch operations
class WatchNotifier extends StateNotifier<AsyncValue<void>> {
  final WatchService _watchService;

  WatchNotifier(this._watchService)
      : super(const AsyncValue.data(null));

  /// Connect to a scanned device
  Future<void> connect(ScannedWatch device) async {
    state = const AsyncValue.loading();
    try {
      await _watchService.connect(device);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Connect to a saved device by ID
  Future<void> connectById(String deviceId) async {
    state = const AsyncValue.loading();
    try {
      await _watchService.connectById(deviceId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Disconnect from current device
  Future<void> disconnect() async {
    state = const AsyncValue.loading();
    try {
      await _watchService.disconnect();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Request device info
  Future<void> requestDeviceInfo() async {
    try {
      await _watchService.requestDeviceInfo();
    } catch (e) {
      // Non-fatal
    }
  }

  /// Sync time
  Future<void> syncTime() async {
    try {
      await _watchService.syncTime();
    } catch (e) {
      // Non-fatal
    }
  }
}

/// Provider for watch notifier
final watchNotifierProvider =
    StateNotifierProvider<WatchNotifier, AsyncValue<void>>((ref) {
  final watchService = ref.watch(watchServiceProvider);
  return WatchNotifier(watchService);
});

