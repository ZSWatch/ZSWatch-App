import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/utils/lifecycle_logger.dart';

/// Connection state for foreground service notification
enum ForegroundConnectionState {
  /// Connected to watch
  connected,

  /// App is backgrounded and the foreground service is passively watching.
  watcher,

  /// Reconnecting to watch
  reconnecting,

  /// Disconnected from watch
  disconnected,
}

/// Service to manage Android foreground service for persistent BLE connection (FR-089 to FR-092)
///
/// This service:
/// - Keeps the app process alive when backgrounded (Android)
/// - Shows a persistent notification with connection status
/// - Allows BLE connection to remain active for notification forwarding
///
/// On iOS, background BLE is handled natively via CoreBluetooth background modes
/// configured in Info.plist (UIBackgroundModes: bluetooth-central)
class ForegroundService {
  static const _channel = MethodChannel('dev.zswatch.app/foreground_service');

  static ForegroundService? _instance;
  static ForegroundService get instance => _instance ??= ForegroundService._();

  ForegroundService._() {
    LifecycleLogger.log('ForegroundService', 'created');
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  final _disconnectRequestedController = StreamController<void>.broadcast();

  /// Stream that emits when user taps "Disconnect" on the notification
  Stream<void> get onDisconnectRequested =>
      _disconnectRequestedController.stream;

  bool _isRunning = false;

  /// Whether the foreground service is currently running
  bool get isRunning => _isRunning;

  /// Handle method calls from native side
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    LifecycleLogger.log('ForegroundService', 'methodCall ${call.method}');
    switch (call.method) {
      case 'onDisconnectRequested':
        debugPrint(
          '[ForegroundService] Disconnect requested from notification',
        );
        _disconnectRequestedController.add(null);
        break;
    }
    return null;
  }

  /// Start the foreground service (Android only)
  ///
  /// Shows a persistent notification with the watch name and connection status.
  /// On iOS, this is a no-op as background BLE is handled natively.
  Future<void> start({
    required String watchName,
    ForegroundConnectionState state = ForegroundConnectionState.connected,
  }) async {
    if (!Platform.isAndroid) {
      // iOS uses native background modes, no foreground service needed
      _isRunning = true;
      return;
    }

    try {
      LifecycleLogger.log(
        'ForegroundService',
        'start watchName=$watchName state=$state',
      );
      final started =
          await _channel.invokeMethod<bool>('start', {
            'watchName': watchName,
            'connectionState': _stateToString(state),
          }) ??
          false;
      _isRunning = started;
      debugPrint('[ForegroundService] Start result=$started for $watchName');
    } on PlatformException catch (e) {
      debugPrint('[ForegroundService] Failed to start: ${e.message}');
    }
  }

  /// Stop the foreground service (Android only)
  Future<void> stop() async {
    if (!Platform.isAndroid) {
      _isRunning = false;
      return;
    }

    try {
      LifecycleLogger.log('ForegroundService', 'stop');
      final stopped = await _channel.invokeMethod<bool>('stop') ?? false;
      if (stopped) {
        _isRunning = false;
      }
      debugPrint('[ForegroundService] Stop result=$stopped');
    } on PlatformException catch (e) {
      debugPrint('[ForegroundService] Failed to stop: ${e.message}');
    }
  }

  /// Update the notification text (Android only)
  Future<void> updateNotification({
    required String watchName,
    required ForegroundConnectionState state,
  }) async {
    if (!Platform.isAndroid || !_isRunning) return;

    try {
      LifecycleLogger.log(
        'ForegroundService',
        'updateNotification watchName=$watchName state=$state',
      );
      await _channel.invokeMethod('updateNotification', {
        'watchName': watchName,
        'connectionState': _stateToString(state),
      });
    } on PlatformException catch (e) {
      debugPrint(
        '[ForegroundService] Failed to update notification: ${e.message}',
      );
    }
  }

  /// Check if the foreground service is running (Android only)
  Future<bool> checkIsRunning() async {
    if (!Platform.isAndroid) {
      return _isRunning;
    }

    try {
      final running = await _channel.invokeMethod<bool>('isRunning') ?? false;
      _isRunning = running;
      LifecycleLogger.log('ForegroundService', 'checkIsRunning=$running');
      return running;
    } on PlatformException catch (e) {
      debugPrint('[ForegroundService] Failed to check status: ${e.message}');
      return false;
    }
  }

  /// Sync native-readable background connection preferences.
  ///
  /// These are stored in an Android-owned SharedPreferences file so boot and
  /// package-replaced receivers can make conservative recovery decisions
  /// without depending on Flutter's SharedPreferences implementation details.
  Future<void> syncBackgroundPreferences({
    String? lastWatchId,
    String? lastWatchName,
    bool? backgroundConnectionEnabled,
    bool? autoReconnectEnabled,
    bool? notificationForwardingEnabled,
    Set<String>? blockedNotificationApps,
  }) async {
    if (!Platform.isAndroid) return;

    final payload = <String, Object?>{};
    if (lastWatchId != null) payload['last_watch_id'] = lastWatchId;
    if (lastWatchName != null) payload['last_watch_name'] = lastWatchName;
    if (backgroundConnectionEnabled != null) {
      payload['background_connection_enabled'] = backgroundConnectionEnabled;
    }
    if (autoReconnectEnabled != null) {
      payload['auto_reconnect_enabled'] = autoReconnectEnabled;
    }
    if (notificationForwardingEnabled != null) {
      payload['notification_forwarding_enabled'] =
          notificationForwardingEnabled;
    }
    if (blockedNotificationApps != null) {
      payload['blocked_notification_apps'] = blockedNotificationApps.toList();
    }

    if (payload.isEmpty) return;

    try {
      await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'syncBackgroundPreferences',
        payload,
      );
      LifecycleLogger.log(
        'ForegroundService',
        'syncBackgroundPreferences $payload',
      );
      debugPrint('[ForegroundService] Synced background prefs: $payload');
    } on PlatformException catch (e) {
      debugPrint(
        '[ForegroundService] Failed to sync background prefs: ${e.message}',
      );
    }
  }

  /// Retrieve the persisted native/Dart lifecycle diagnostic ring buffer.
  Future<List<LifecycleLogEntry>> getLifecycleEvents() async {
    if (!Platform.isAndroid) return [];

    try {
      final rawEvents =
          await _channel.invokeMethod<List<dynamic>>('getLifecycleEvents') ??
          const <dynamic>[];
      final entries = <LifecycleLogEntry>[];
      for (final rawEvent in rawEvents) {
        if (rawEvent is Map<Object?, Object?>) {
          final entry = LifecycleLogEntry.fromMap(rawEvent);
          if (LifecycleLogger.shouldPersistDiagnostic(
            entry.source,
            entry.message,
          )) {
            entries.add(entry);
          }
        }
      }
      return entries.reversed.toList();
    } on PlatformException catch (e) {
      debugPrint(
        '[ForegroundService] Failed to read lifecycle events: ${e.message}',
      );
      return [];
    }
  }

  /// Clear persisted lifecycle diagnostics.
  Future<bool> clearLifecycleEvents() async {
    if (!Platform.isAndroid) return true;

    try {
      return await _channel.invokeMethod<bool>('clearLifecycleEvents') ?? false;
    } on PlatformException catch (e) {
      debugPrint(
        '[ForegroundService] Failed to clear lifecycle events: ${e.message}',
      );
      return false;
    }
  }

  /// Check if battery optimization is disabled for this app (Android only)
  ///
  /// When battery optimization is enabled (the default), Android may kill the app
  /// or restrict background activity, which can disconnect the BLE connection.
  Future<bool> isBatteryOptimizationDisabled() async {
    if (!Platform.isAndroid) {
      return true; // iOS handles this differently
    }

    try {
      final disabled =
          await _channel.invokeMethod<bool>('isBatteryOptimizationDisabled') ??
          false;
      LifecycleLogger.log(
        'ForegroundService',
        'isBatteryOptimizationDisabled=$disabled',
      );
      return disabled;
    } on PlatformException catch (e) {
      debugPrint(
        '[ForegroundService] Failed to check battery optimization: ${e.message}',
      );
      return false;
    }
  }

  /// Request to disable battery optimization for this app (Android only)
  ///
  /// This shows a system dialog asking the user to allow the app to run
  /// unrestricted in the background. Note: This is just a request, user
  /// can decline.
  ///
  /// Returns true if the request was shown, false if it failed.
  Future<bool> requestDisableBatteryOptimization() async {
    if (!Platform.isAndroid) {
      return true;
    }

    try {
      LifecycleLogger.log(
        'ForegroundService',
        'requestDisableBatteryOptimization',
      );
      return await _channel.invokeMethod<bool>(
            'requestDisableBatteryOptimization',
          ) ??
          false;
    } on PlatformException catch (e) {
      debugPrint(
        '[ForegroundService] Failed to request battery optimization: ${e.message}',
      );
      return false;
    }
  }

  /// Open the battery optimization settings page (Android only)
  ///
  /// Takes user to the system settings where they can manually disable
  /// battery optimization for this app.
  Future<bool> openBatteryOptimizationSettings() async {
    if (!Platform.isAndroid) {
      return true;
    }

    try {
      LifecycleLogger.log(
        'ForegroundService',
        'openBatteryOptimizationSettings',
      );
      return await _channel.invokeMethod<bool>(
            'openBatteryOptimizationSettings',
          ) ??
          false;
    } on PlatformException catch (e) {
      debugPrint(
        '[ForegroundService] Failed to open battery settings: ${e.message}',
      );
      return false;
    }
  }

  String _stateToString(ForegroundConnectionState state) {
    switch (state) {
      case ForegroundConnectionState.connected:
        return 'connected';
      case ForegroundConnectionState.watcher:
        return 'watcher';
      case ForegroundConnectionState.reconnecting:
        return 'reconnecting';
      case ForegroundConnectionState.disconnected:
        return 'disconnected';
    }
  }

  /// Dispose resources
  void dispose() {
    LifecycleLogger.log('ForegroundService', 'dispose');
    _disconnectRequestedController.close();
  }
}
