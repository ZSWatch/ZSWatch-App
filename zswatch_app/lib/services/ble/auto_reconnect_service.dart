import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/watch.dart';

/// Auto-reconnect behavior state
enum AutoReconnectState {
  /// Not attempting to reconnect
  idle,

  /// Auto-connect is active (waiting for device to appear)
  waiting,

  /// Successfully connected
  connected,

  /// Reconnect was cancelled by user
  cancelled,
}

/// Configuration for auto-reconnect behavior
class AutoReconnectConfig {
  /// Delay before starting auto-reconnect on app launch
  static const Duration initialDelay = Duration(seconds: 1);
}

/// Service to manage auto-reconnect behavior (FR-071 to FR-074)
///
/// This service leverages flutter_blue_plus's built-in `autoConnect` feature:
/// - `device.connect(autoConnect: true)` - system handles reconnection automatically
/// - Works on both iOS and Android
/// - Doesn't time out - keeps trying until device is available
/// - Can be cancelled by calling disconnect()
///
/// Features:
/// - Auto-reconnect to last connected watch on app launch (FR-071)
/// - Leverages platform auto-connect (FR-072)
/// - Non-blocking reconnect that allows manual watch selection (FR-073)
/// - Navigate to connected screen on success (FR-074)
class AutoReconnectService {
  final Future<void> Function(String watchId, {bool autoConnect}) _connectById;
  final Future<Watch?> Function() _getLastConnectedWatch;
  final void Function() _cancelConnection;

  bool _isEnabled = true;
  bool _isCancelled = false;

  /// Whether auto-reconnect is suppressed for this session (until app restart)
  /// Set when user explicitly cancels or disconnects
  bool _isSuppressedForSession = false;
  Watch? _targetWatch;

  final _stateController = StreamController<AutoReconnectState>.broadcast();

  AutoReconnectState _state = AutoReconnectState.idle;

  /// Current auto-reconnect state
  AutoReconnectState get state => _state;

  /// Stream of state changes
  Stream<AutoReconnectState> get stateStream => _stateController.stream;

  /// The watch we're trying to reconnect to
  Watch? get targetWatch => _targetWatch;

  /// Whether auto-reconnect is enabled
  bool get isEnabled => _isEnabled;

  /// Whether auto-reconnect is suppressed for this session
  bool get isSuppressedForSession => _isSuppressedForSession;

  /// Whether currently waiting for auto-connect
  bool get isReconnecting => _state == AutoReconnectState.waiting;

  AutoReconnectService({
    required Future<void> Function(String watchId, {bool autoConnect})
    connectById,
    required Future<Watch?> Function() getLastConnectedWatch,
    required void Function() cancelConnection,
  }) : _connectById = connectById,
       _getLastConnectedWatch = getLastConnectedWatch,
       _cancelConnection = cancelConnection;

  /// Start auto-reconnect to last connected watch (FR-071)
  ///
  /// Uses flutter_blue_plus's `autoConnect: true` which:
  /// - Returns immediately (non-blocking)
  /// - System handles reconnection when device appears
  /// - Doesn't time out
  Future<void> startAutoReconnect() async {
    debugPrint(
      '[AutoReconnect:$hashCode] startAutoReconnect() called: _isEnabled=$_isEnabled, _isSuppressedForSession=$_isSuppressedForSession, _state=$_state',
    );

    if (!_isEnabled) {
      debugPrint('[AutoReconnect:$hashCode] Disabled, skipping');
      return;
    }

    if (_isSuppressedForSession) {
      debugPrint(
        '[AutoReconnect:$hashCode] Suppressed for this session (user cancelled/disconnected)',
      );
      return;
    }

    // Prevent multiple concurrent auto-reconnect attempts
    if (_state == AutoReconnectState.waiting) {
      debugPrint('[AutoReconnect] Already waiting for reconnect, skipping');
      return;
    }

    _isCancelled = false;

    // Get last connected watch
    _targetWatch = await _getLastConnectedWatch();
    if (_targetWatch == null) {
      debugPrint('[AutoReconnect] No last connected watch found');
      _updateState(AutoReconnectState.idle);
      return;
    }

    debugPrint(
      '[AutoReconnect] Starting auto-connect for ${_targetWatch!.displayName}',
    );

    // Wait initial delay before attempting
    await Future<void>.delayed(AutoReconnectConfig.initialDelay);

    if (_isCancelled) {
      _updateState(AutoReconnectState.cancelled);
      return;
    }

    _updateState(AutoReconnectState.waiting);

    try {
      // Use flutter_blue_plus's autoConnect feature
      // This returns immediately and the system handles reconnection
      await _connectById(_targetWatch!.id, autoConnect: true);
      debugPrint(
        '[AutoReconnect] Auto-connect initiated for ${_targetWatch!.id}',
      );
      // Note: We stay in 'waiting' state until connection actually happens
      // The watch_service will notify us when connected
    } catch (e) {
      debugPrint('[AutoReconnect] Failed to initiate auto-connect: $e');
      _updateState(AutoReconnectState.idle);
    }
  }

  /// Cancel auto-reconnect (FR-073)
  ///
  /// Call this when user manually selects a different watch or cancels reconnection.
  /// This suppresses auto-reconnect for the rest of this session.
  void cancel() {
    debugPrint(
      '[AutoReconnect:$hashCode] Cancelled by user - setting _isSuppressedForSession=true',
    );
    _isCancelled = true;
    _isSuppressedForSession = true; // Don't auto-restart until app restart
    _cancelConnection();
    _updateState(AutoReconnectState.cancelled);
  }

  /// Stop auto-reconnect without marking as cancelled
  void stop() {
    _cancelConnection();
    _updateState(AutoReconnectState.idle);
  }

  /// Suppress auto-reconnect for this session (e.g., when user manually disconnects)
  void suppressForSession() {
    debugPrint('[AutoReconnect] Suppressed for session (user disconnected)');
    _isSuppressedForSession = true;
    _cancelConnection();
    _updateState(AutoReconnectState.idle);
  }

  /// Clear session suppression (call on fresh app start if needed)
  void clearSuppression() {
    _isSuppressedForSession = false;
  }

  /// Enable or disable auto-reconnect
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    if (!enabled) {
      cancel();
    }
  }

  /// Notify that connection was successful (called externally)
  void notifyConnected() {
    _updateState(AutoReconnectState.connected);
  }

  /// Notify that disconnection occurred
  void notifyDisconnected() {
    if (_state == AutoReconnectState.connected) {
      _updateState(AutoReconnectState.idle);
    }
  }

  void _updateState(AutoReconnectState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(newState);
    }
  }

  /// Dispose resources
  void dispose() {
    _stateController.close();
  }
}
