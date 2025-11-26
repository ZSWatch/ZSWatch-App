import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/watch.dart';
import '../data/models/connection.dart';
import '../data/models/connection_state.dart';
import '../data/repositories/watch_repository.dart';
import '../services/ble/ble_connection_manager.dart';
import 'ble_providers.dart';

/// The current state of the connected watch
class WatchState {
  final Watch? watch;
  final Connection connection;
  final bool isLoading;
  final String? error;

  const WatchState({
    this.watch,
    required this.connection,
    this.isLoading = false,
    this.error,
  });

  factory WatchState.initial() => const WatchState(
        connection: Connection(
          watchId: '',
          state: WatchConnectionState.disconnected,
        ),
      );

  WatchState copyWith({
    Watch? watch,
    Connection? connection,
    bool? isLoading,
    String? error,
  }) {
    return WatchState(
      watch: watch ?? this.watch,
      connection: connection ?? this.connection,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  bool get isConnected => connection.state == WatchConnectionState.connected;
  bool get isConnecting => connection.state.isConnectingOrReconnecting;
  bool get hasWatch => watch != null;
}

/// Notifier that manages the connected watch state
class WatchStateNotifier extends StateNotifier<WatchState> {
  final BleConnectionManager _connectionManager;
  final WatchRepository? _watchRepository;
  StreamSubscription<Connection>? _connectionSubscription;

  WatchStateNotifier(this._connectionManager, this._watchRepository)
      : super(WatchState.initial()) {
    _init();
  }

  void _init() {
    // Listen to connection state changes
    _connectionSubscription = _connectionManager.connectionStream.listen(
      _handleConnectionChange,
    );
  }

  void _handleConnectionChange(Connection connection) {
    state = state.copyWith(connection: connection);

    if (connection.state == WatchConnectionState.connected) {
      // Fetch watch info when connected
      _fetchWatchInfo(connection.watchId);
    } else if (connection.state == WatchConnectionState.disconnected) {
      // Clear watch when disconnected (but keep in DB)
      state = state.copyWith(
        watch: null,
        connection: connection,
      );
    }
  }

  Future<void> _fetchWatchInfo(String watchId) async {
    state = state.copyWith(isLoading: true);

    try {
      // First check if we have this watch in the database
      Watch? watch = await _watchRepository?.getWatchById(watchId);

      // New watch - create a basic entry if not in DB
      watch ??= Watch(
        id: watchId,
        name: 'ZSWatch',
        createdAt: DateTime.now(),
      );

      // Update state with watch info
      state = state.copyWith(
        watch: watch,
        isLoading: false,
      );

      // TODO: Request device info via protocol to get firmware version, battery, etc.
      // This will be done when we wire up the protocol service

    } catch (e) {
      debugPrint('Error fetching watch info: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Update watch info (called when device info is received from watch)
  void updateWatchInfo({
    String? name,
    String? firmwareVersion,
    String? hardwareVersion,
    int? batteryLevel,
  }) {
    if (state.watch == null) return;

    final updatedWatch = state.watch!.copyWith(
      name: name,
      firmwareVersion: firmwareVersion,
      hardwareVersion: hardwareVersion,
      batteryLevel: batteryLevel,
      lastConnectedAt: DateTime.now(),
    );

    state = state.copyWith(watch: updatedWatch);

    // Persist to database
    _watchRepository?.updateWatch(updatedWatch);
  }

  /// Update battery level
  void updateBatteryLevel(int level) {
    if (state.watch == null) return;

    state = state.copyWith(
      watch: state.watch!.copyWith(batteryLevel: level),
    );

    // Persist to database
    _watchRepository?.updateBatteryLevel(state.watch!.id, level);
  }

  /// Disconnect from the current watch
  Future<void> disconnect() async {
    await _connectionManager.disconnect();
  }

  /// Save the current watch to the database
  Future<void> saveWatch() async {
    if (state.watch == null) return;
    await _watchRepository?.saveWatch(state.watch!);
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    super.dispose();
  }
}

/// Provider for WatchRepository
final watchRepositoryProvider = Provider<WatchRepository?>((ref) {
  // TODO: Initialize with actual database
  // For now, return null - we'll add database later
  return null;
});

/// Provider for the watch state notifier
final watchStateProvider =
    StateNotifierProvider<WatchStateNotifier, WatchState>((ref) {
  final connectionManager = ref.watch(bleConnectionManagerProvider);
  final watchRepository = ref.watch(watchRepositoryProvider);
  return WatchStateNotifier(connectionManager, watchRepository);
});

/// Convenience providers for specific watch state properties
final connectedWatchProvider = Provider<Watch?>((ref) {
  return ref.watch(watchStateProvider).watch;
});

final watchBatteryProvider = Provider<int?>((ref) {
  return ref.watch(watchStateProvider).watch?.batteryLevel;
});

final watchFirmwareProvider = Provider<String?>((ref) {
  return ref.watch(watchStateProvider).watch?.firmwareVersion;
});

final isWatchConnectedProvider = Provider<bool>((ref) {
  return ref.watch(watchStateProvider).isConnected;
});

