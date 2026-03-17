import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Connection state for foreground service notification
enum ForegroundConnectionState {
  /// Connected to watch
  connected,

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
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  final _disconnectRequestedController = StreamController<void>.broadcast();

  /// Stream that emits when user taps "Disconnect" on the notification
  Stream<void> get onDisconnectRequested => _disconnectRequestedController.stream;

  bool _isRunning = false;

  /// Whether the foreground service is currently running
  bool get isRunning => _isRunning;

  /// Handle method calls from native side
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onDisconnectRequested':
        debugPrint('[ForegroundService] Disconnect requested from notification');
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
      await _channel.invokeMethod('start', {
        'watchName': watchName,
        'connectionState': _stateToString(state),
      });
      _isRunning = true;
      debugPrint('[ForegroundService] Started for $watchName');
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
      await _channel.invokeMethod('stop');
      _isRunning = false;
      debugPrint('[ForegroundService] Stopped');
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
      await _channel.invokeMethod('updateNotification', {
        'watchName': watchName,
        'connectionState': _stateToString(state),
      });
    } on PlatformException catch (e) {
      debugPrint('[ForegroundService] Failed to update notification: ${e.message}');
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
      return running;
    } on PlatformException catch (e) {
      debugPrint('[ForegroundService] Failed to check status: ${e.message}');
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
      return await _channel.invokeMethod<bool>('isBatteryOptimizationDisabled') ?? false;
    } on PlatformException catch (e) {
      debugPrint('[ForegroundService] Failed to check battery optimization: ${e.message}');
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
      return await _channel.invokeMethod<bool>('requestDisableBatteryOptimization') ?? false;
    } on PlatformException catch (e) {
      debugPrint('[ForegroundService] Failed to request battery optimization: ${e.message}');
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
      return await _channel.invokeMethod<bool>('openBatteryOptimizationSettings') ?? false;
    } on PlatformException catch (e) {
      debugPrint('[ForegroundService] Failed to open battery settings: ${e.message}');
      return false;
    }
  }

  String _stateToString(ForegroundConnectionState state) {
    switch (state) {
      case ForegroundConnectionState.connected:
        return 'connected';
      case ForegroundConnectionState.reconnecting:
        return 'reconnecting';
      case ForegroundConnectionState.disconnected:
        return 'disconnected';
    }
  }

  /// Dispose resources
  void dispose() {
    _disconnectRequestedController.close();
  }
}
