import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/connection.dart';
import '../data/models/connection_phase.dart';
import '../data/models/connection_state.dart';
import '../data/models/watch.dart';
import '../data/repositories/watch_repository.dart';
import '../services/ble/ble_connection_service.dart';
import '../services/ble/ble_scanner.dart';
import '../services/watch_service.dart';
import 'base_async_notifier.dart';
import 'demo_mode_provider.dart';
import 'watch_providers.dart';

/// Provider for the BleConnectionService singleton — single source of truth
/// for connection lifecycle.
final bleConnectionServiceProvider = Provider<BleConnectionService>((ref) {
  final service = BleConnectionService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider for the WatchService (protocol, messaging, battery).
final watchServiceProvider = Provider<WatchService>((ref) {
  final ble = ref.watch(bleConnectionServiceProvider);
  final service = WatchService(ble);
  debugPrint(
      '[watchServiceProvider] Created WatchService instance: ${service.hashCode}');
  ref.onDispose(() {
    debugPrint(
        '[watchServiceProvider] Disposing WatchService instance: ${service.hashCode}');
    service.dispose();
  });
  return service;
});

/// Provider for connection phase stream (primary state).
final connectionPhaseStreamProvider = StreamProvider<ConnectionPhase>((ref) {
  final ble = ref.watch(bleConnectionServiceProvider);
  return ble.phaseStream;
});

/// Provider for current connection phase.
final connectionPhaseProvider = Provider<ConnectionPhase>((ref) {
  final asyncValue = ref.watch(connectionPhaseStreamProvider);
  return asyncValue.valueOrNull ?? const ConnectionPhase.disconnected();
});

/// Provider for connection state stream (backwards compat Connection model).
final watchConnectionStreamProvider = StreamProvider<Connection>((ref) {
  final ble = ref.watch(bleConnectionServiceProvider);
  return ble.connectionStream;
});

/// Provider for current connection (non-stream).
///
/// In demo mode, returns a fake "connected" connection so all screens
/// are accessible without real hardware.
final watchConnectionProvider = Provider<Connection>((ref) {
  final demo = demoConnectionOrNull(ref);
  if (demo != null) return demo;

  final asyncValue = ref.watch(watchConnectionStreamProvider);
  return asyncValue.valueOrNull ??
      const Connection(
        watchId: '',
        state: WatchConnectionState.disconnected,
      );
});

/// Provider for whether watch is connected.
final isWatchConnectedProvider = Provider<bool>((ref) {
  final connection = ref.watch(watchConnectionProvider);
  return connection.state == WatchConnectionState.connected;
});

/// Provider for connection state enum.
final watchConnectionStateProvider = Provider<WatchConnectionState>((ref) {
  final connection = ref.watch(watchConnectionProvider);
  return connection.state;
});

/// Provider for watch info stream.
final watchInfoStreamProvider = StreamProvider<Watch?>((ref) {
  final service = ref.watch(watchServiceProvider);
  return service.watchInfoStream;
});

/// Provider for current watch info - merges live service data with database data.
///
/// In demo mode, returns a static placeholder watch.
final currentWatchProvider = Provider<Watch?>((ref) {
  final demo = demoWatchOrNull(ref);
  if (demo != null) return demo;

  final asyncValue = ref.watch(watchInfoStreamProvider);
  final service = ref.watch(watchServiceProvider);

  final serviceWatch = asyncValue.valueOrNull ?? service.currentWatch;
  if (serviceWatch == null) return null;

  final dbWatchAsync = ref.watch(watchByIdProvider(serviceWatch.id));
  final dbWatch = dbWatchAsync.valueOrNull;

  if (dbWatch != null && dbWatch.customName != null) {
    return serviceWatch.copyWith(customName: dbWatch.customName);
  }

  return serviceWatch;
});

/// Provider for current watch (non-null when connected).
final connectedWatchProvider = Provider<Watch?>((ref) {
  final isConnected = ref.watch(isWatchConnectedProvider);
  if (!isConnected) return null;
  return ref.watch(currentWatchProvider);
});

/// Provider for battery level stream.
final batteryLevelStreamProvider = StreamProvider<int>((ref) {
  final service = ref.watch(watchServiceProvider);
  return service.batteryStream;
});

/// Provider for current battery level.
final batteryLevelProvider = Provider<int?>((ref) {
  final asyncValue = ref.watch(batteryLevelStreamProvider);
  return asyncValue.valueOrNull;
});

/// Provider for whether the connected watch has the SMP service available.
final hasSmpServiceProvider = Provider<bool>((ref) {
  final isConnected = ref.watch(isWatchConnectedProvider);
  if (!isConnected) return false;
  final ble = ref.watch(bleConnectionServiceProvider);
  return ble.hasSmpService;
});

/// Provider that syncs watch info changes to the database.
final watchInfoPersistenceProvider = Provider<void>((ref) {
  final db = ref.watch(databaseProvider);
  final repository = WatchRepository(db);

  String? lastPersistedFw;
  String? lastPersistedHw;

  ref.listen(watchInfoStreamProvider, (previous, next) {
    final watch = next.valueOrNull;
    if (watch == null || watch.id.isEmpty) return;

    final fwChanged =
        watch.firmwareVersion != null && watch.firmwareVersion != lastPersistedFw;
    final hwChanged =
        watch.hardwareVersion != null && watch.hardwareVersion != lastPersistedHw;

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

  bool hasUpdatedLastConnected = false;
  String lastConnectedWatchId = '';

  ref.listen(watchConnectionStreamProvider, (previous, next) {
    final connection = next.valueOrNull;
    if (connection == null) return;

    if (connection.state == WatchConnectionState.disconnected ||
        connection.watchId != lastConnectedWatchId) {
      hasUpdatedLastConnected = false;
      lastConnectedWatchId = connection.watchId;
    }

    if (connection.state == WatchConnectionState.connected &&
        connection.watchId.isNotEmpty &&
        !hasUpdatedLastConnected) {
      hasUpdatedLastConnected = true;
      debugPrint(
          '[WatchInfoPersistence] Updating lastConnectedAt for ${connection.watchId}');
      unawaited(repository.updateLastConnected(connection.watchId));
    }
  });
});

/// Notifier for watch operations.
class WatchNotifier extends BaseAsyncNotifier {
  final WatchService _watchService;

  WatchNotifier(this._watchService);

  /// Connect to a scanned device.
  Future<void> connect(ScannedWatch device) =>
      run(() => _watchService.connect(device), rethrowError: true);

  /// Connect to a saved device by ID.
  Future<void> connectById(String deviceId) =>
      run(() => _watchService.connectById(deviceId), rethrowError: true);

  /// Disconnect from current device.
  Future<void> disconnect() => run(() => _watchService.disconnect());

  /// Request device info.
  Future<void> requestDeviceInfo() async {
    try {
      await _watchService.requestDeviceInfo();
    } catch (e) {
      // Non-fatal
    }
  }

  /// Sync time.
  Future<void> syncTime() async {
    try {
      await _watchService.syncTime();
    } catch (e) {
      // Non-fatal
    }
  }
}

/// Provider for watch notifier.
final watchNotifierProvider =
    StateNotifierProvider<WatchNotifier, AsyncValue<void>>((ref) {
  final watchService = ref.watch(watchServiceProvider);
  return WatchNotifier(watchService);
});
