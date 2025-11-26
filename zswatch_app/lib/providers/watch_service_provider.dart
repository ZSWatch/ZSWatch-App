import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/connection.dart';
import '../data/models/connection_state.dart';
import '../data/models/watch.dart';
import '../services/watch_service.dart';
import '../services/ble/ble_scanner.dart';

const _knownWatchIdsKey = 'known_watch_ids';

/// Provider for the unified WatchService
final watchServiceProvider = Provider<WatchService>((ref) {
  final service = WatchService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider for connection state stream
final watchConnectionStreamProvider = StreamProvider<Connection>((ref) {
  final service = ref.watch(watchServiceProvider);
  return service.connectionStream;
});

/// Provider for current connection (non-stream)
final watchConnectionProvider = Provider<Connection>((ref) {
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

/// Provider for current watch info - uses stream to get reactive updates
final currentWatchProvider = Provider<Watch?>((ref) {
  // Watch the stream to get reactive updates
  final asyncValue = ref.watch(watchInfoStreamProvider);
  // Also get the synchronous value directly from the service as fallback
  final service = ref.watch(watchServiceProvider);
  
  // Prefer the stream value if available, otherwise use the service's current value
  return asyncValue.valueOrNull ?? service.currentWatch;
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

/// Provider for known watch IDs (saved in SharedPreferences)
final knownWatchIdsProvider = FutureProvider<Set<String>>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final ids = prefs.getStringList(_knownWatchIdsKey) ?? [];
  return ids.toSet();
});

/// Save a watch ID to known list
Future<void> saveKnownWatchId(String watchId) async {
  final prefs = await SharedPreferences.getInstance();
  final ids = prefs.getStringList(_knownWatchIdsKey) ?? [];
  if (!ids.contains(watchId)) {
    ids.add(watchId);
    await prefs.setStringList(_knownWatchIdsKey, ids);
  }
}

/// Remove a watch ID from known list
Future<void> removeKnownWatchId(String watchId) async {
  final prefs = await SharedPreferences.getInstance();
  final ids = prefs.getStringList(_knownWatchIdsKey) ?? [];
  ids.remove(watchId);
  await prefs.setStringList(_knownWatchIdsKey, ids);
}

