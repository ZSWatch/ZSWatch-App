import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/connection.dart';
import '../data/models/connection_state.dart';
import '../services/background/foreground_service.dart';
import 'settings_providers.dart';
import 'watch_service_provider.dart';

/// Provider for the ForegroundService singleton
final foregroundServiceProvider = Provider<ForegroundService>((ref) {
  return ForegroundService.instance;
});

/// Provider for battery optimization status (Android only)
final batteryOptimizationDisabledProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(foregroundServiceProvider);
  return service.isBatteryOptimizationDisabled();
});

/// Provider for foreground service running status
final foregroundServiceRunningProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(foregroundServiceProvider);
  return service.checkIsRunning();
});

/// Notifier that manages foreground service based on connection state
///
/// This notifier:
/// - Starts foreground service when connection is established (if enabled in settings)
/// - Updates notification text based on connection state (connected/reconnecting)
/// - Stops foreground service when user explicitly disconnects
/// - Handles disconnect requests from the notification
class ForegroundServiceNotifier extends StateNotifier<bool> {
  final Ref _ref;
  final ForegroundService _service;
  StreamSubscription<Connection>? _connectionSubscription;
  StreamSubscription<void>? _disconnectRequestedSubscription;
  String? _currentWatchName;
  bool _wasUserDisconnect = false;

  ForegroundServiceNotifier(this._ref, this._service) : super(false) {
    _initialize();
  }

  void _initialize() {
    // Listen to connection state changes
    final watchService = _ref.read(watchServiceProvider);
    _connectionSubscription = watchService.connectionStream.listen(_handleConnectionChange);

    // Listen to disconnect requests from notification
    _disconnectRequestedSubscription = _service.onDisconnectRequested.listen((_) {
      _handleNotificationDisconnect();
    });

    // Check if service is already running (app restart case)
    _checkServiceStatus();
  }

  Future<void> _checkServiceStatus() async {
    final isRunning = await _service.checkIsRunning();
    state = isRunning;
  }

  void _handleConnectionChange(Connection connection) {
    final backgroundEnabled = _ref.read(backgroundConnectionEnabledProvider);
    
    // Only manage foreground service on Android
    if (!Platform.isAndroid) return;

    _currentWatchName = connection.watchName ?? 'ZSWatch';

    switch (connection.state) {
      case WatchConnectionState.connected:
        // Start foreground service on successful connection (if enabled)
        if (backgroundEnabled) {
          if (state) {
            // Service already running, just update notification to connected
            _updateNotification(ForegroundConnectionState.connected);
          } else {
            _startService(ForegroundConnectionState.connected);
          }
        }
        _wasUserDisconnect = false;
        break;

      case WatchConnectionState.syncing:
        // Keep service running during sync, still connected
        if (state && backgroundEnabled) {
          _updateNotification(ForegroundConnectionState.connected);
        }
        break;

      case WatchConnectionState.reconnecting:
        // Update notification to show reconnecting state
        if (state) {
          _updateNotification(ForegroundConnectionState.reconnecting);
        }
        break;

      case WatchConnectionState.connecting:
      case WatchConnectionState.bonding:
      case WatchConnectionState.discoveringServices:
      case WatchConnectionState.negotiating:
      case WatchConnectionState.scanning:
      case WatchConnectionState.disconnecting:
        // Don't start service during initial connection or disconnecting
        // But if already running (reconnecting), keep it running
        if (state) {
          _updateNotification(ForegroundConnectionState.reconnecting);
        }
        break;

      case WatchConnectionState.disconnected:
        // Only stop service if user explicitly disconnected
        // If unexpected disconnect, keep service running for auto-reconnect
        if (_wasUserDisconnect) {
          _stopService();
        } else if (state && backgroundEnabled) {
          // Keep service running, update notification
          _updateNotification(ForegroundConnectionState.reconnecting);
        }
        break;

      case WatchConnectionState.error:
        // On error, keep service running if it was running (for retry)
        if (state) {
          _updateNotification(ForegroundConnectionState.reconnecting);
        }
        break;
    }
  }

  void _handleNotificationDisconnect() {
    debugPrint('[ForegroundServiceNotifier] Disconnect requested from notification');
    
    // Mark as user-initiated disconnect
    _wasUserDisconnect = true;
    
    // Disconnect from watch
    final watchService = _ref.read(watchServiceProvider);
    watchService.disconnect();
    
    // Stop foreground service
    _stopService();
  }

  Future<void> _startService(ForegroundConnectionState connectionState) async {
    if (state) return; // Already running

    debugPrint('[ForegroundServiceNotifier] Starting foreground service for $_currentWatchName');
    
    await _service.start(
      watchName: _currentWatchName ?? 'ZSWatch',
      state: connectionState,
    );
    state = true;
  }

  Future<void> _stopService() async {
    if (!state) return; // Not running

    debugPrint('[ForegroundServiceNotifier] Stopping foreground service');
    
    await _service.stop();
    state = false;
  }

  Future<void> _updateNotification(ForegroundConnectionState connectionState) async {
    if (!state) return; // Not running

    await _service.updateNotification(
      watchName: _currentWatchName ?? 'ZSWatch',
      state: connectionState,
    );
  }

  /// Manually start the foreground service
  Future<void> start() async {
    if (!Platform.isAndroid) return;
    
    final connection = _ref.read(watchConnectionProvider);
    _currentWatchName = connection.watchName ?? 'ZSWatch';
    
    final connectionState = connection.isConnected
        ? ForegroundConnectionState.connected
        : ForegroundConnectionState.reconnecting;
    
    await _startService(connectionState);
  }

  /// Manually stop the foreground service
  Future<void> stop() async {
    _wasUserDisconnect = true;
    await _stopService();
  }

  /// Mark that the next disconnect is user-initiated
  void markUserDisconnect() {
    _wasUserDisconnect = true;
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    _disconnectRequestedSubscription?.cancel();
    super.dispose();
  }
}

/// Provider for the foreground service notifier
final foregroundServiceNotifierProvider =
    StateNotifierProvider<ForegroundServiceNotifier, bool>((ref) {
  final service = ref.watch(foregroundServiceProvider);
  return ForegroundServiceNotifier(ref, service);
});

/// Provider to check and request battery optimization exemption
class BatteryOptimizationNotifier extends StateNotifier<AsyncValue<bool>> {
  final ForegroundService _service;

  BatteryOptimizationNotifier(this._service) : super(const AsyncValue.loading()) {
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    if (!Platform.isAndroid) {
      state = const AsyncValue.data(true); // iOS doesn't need this
      return;
    }

    try {
      final isDisabled = await _service.isBatteryOptimizationDisabled();
      state = AsyncValue.data(isDisabled);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Refresh the battery optimization status
  Future<void> refresh() async {
    await _checkStatus();
  }

  /// Request to disable battery optimization
  Future<void> requestDisable() async {
    await _service.requestDisableBatteryOptimization();
    // Delay to allow user to respond to dialog
    await Future<void>.delayed(const Duration(seconds: 1));
    await refresh();
  }

  /// Open battery optimization settings
  Future<void> openSettings() async {
    await _service.openBatteryOptimizationSettings();
  }
}

/// Provider for battery optimization notifier
final batteryOptimizationNotifierProvider =
    StateNotifierProvider<BatteryOptimizationNotifier, AsyncValue<bool>>((ref) {
  final service = ref.watch(foregroundServiceProvider);
  return BatteryOptimizationNotifier(service);
});
