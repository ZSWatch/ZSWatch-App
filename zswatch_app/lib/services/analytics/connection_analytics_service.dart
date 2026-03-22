import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/connection.dart';
import '../../data/models/connection_event.dart';
import '../../data/models/connection_state.dart';
import '../../data/repositories/connection_analytics_repository.dart';
import '../../providers/watch_service_provider.dart';
import '../watch_service.dart';

const _uuid = Uuid();

/// Service that tracks connection events for analytics
///
/// Records connection/disconnection events with timestamps and reasons
/// to build connection stability analytics.
class ConnectionAnalyticsService {
  final WatchService _watchService;
  final ConnectionAnalyticsRepository _repository;

  StreamSubscription<Connection>? _connectionSubscription;

  // Track current session for duration calculation
  String? _currentSessionId;
  DateTime? _sessionStartTime;
  WatchConnectionState? _lastState;
  String? _lastWatchId;

  ConnectionAnalyticsService(this._watchService, this._repository);

  /// Start tracking connection events
  void start() {
    _connectionSubscription = _watchService.connectionStream.listen(
      _onConnectionChange,
    );

    // If already connected, start a session
    if (_watchService.isConnected) {
      final connection = _watchService.currentConnection;
      _startSession(connection.watchId);
    }
  }

  /// Stop tracking connection events
  void stop() {
    _connectionSubscription?.cancel();
    _connectionSubscription = null;

    // End any active session
    if (_currentSessionId != null && _lastWatchId != null) {
      _endSession(_lastWatchId!, DisconnectReason.appTerminated);
    }
  }

  Future<void> _onConnectionChange(Connection connection) async {
    final state = connection.state;
    final watchId = connection.watchId;

    // Skip if no watch ID
    if (watchId.isEmpty) return;

    // Skip if state hasn't actually changed
    if (state == _lastState) return;

    debugPrint(
      '[ConnectionAnalytics] State change: ${_lastState?.name ?? 'null'} -> ${state.name}',
    );

    // Handle state transitions
    switch (state) {
      case WatchConnectionState.connected:
        // New connection established
        if (_lastState != WatchConnectionState.connected) {
          await _recordConnected(watchId);
          _startSession(watchId);
        }
        break;

      case WatchConnectionState.reconnecting:
        // Record reconnect attempt
        if (_lastState == WatchConnectionState.connected ||
            _lastState == WatchConnectionState.error) {
          await _recordReconnectAttempt(watchId);
        }
        break;

      case WatchConnectionState.disconnected:
      case WatchConnectionState.error:
        // Connection lost
        if (_lastState == WatchConnectionState.connected ||
            _lastState == WatchConnectionState.reconnecting) {
          final reason = _mapToDisconnectReason(connection);
          await _recordDisconnected(watchId, reason, connection.errorDetails);
          _endSession(watchId, reason);
        }
        break;

      default:
        // Connecting states - no action needed for analytics
        break;
    }

    _lastState = state;
    _lastWatchId = watchId;
  }

  DisconnectReason _mapToDisconnectReason(Connection connection) {
    if (connection.errorType != null) {
      switch (connection.errorType!) {
        case ConnectionErrorType.bluetoothDisabled:
          return DisconnectReason.bluetoothDisabled;
        case ConnectionErrorType.deviceNotFound:
          return DisconnectReason.deviceUnavailable;
        case ConnectionErrorType.timeout:
          return DisconnectReason.connectionLost;
        case ConnectionErrorType.bondingFailed:
          return DisconnectReason.unknown;
        case ConnectionErrorType.serviceDiscoveryFailed:
          return DisconnectReason.unknown;
        case ConnectionErrorType.unexpectedDisconnect:
          return DisconnectReason.unknown;
        case ConnectionErrorType.maxReconnectionsReached:
          return DisconnectReason.connectionLost;
        case ConnectionErrorType.permissionDenied:
        case ConnectionErrorType.unknown:
          return DisconnectReason.unknown;
      }
    }

    // If we're in error state without a specific error type
    if (connection.state == WatchConnectionState.error) {
      return DisconnectReason.unknown;
    }

    // Clean disconnect
    return DisconnectReason.userRequested;
  }

  void _startSession(String watchId) {
    _currentSessionId = _uuid.v4();
    _sessionStartTime = DateTime.now();
    _lastWatchId = watchId;
    debugPrint('[ConnectionAnalytics] Started session: $_currentSessionId');
  }

  void _endSession(String watchId, DisconnectReason reason) {
    if (_sessionStartTime != null) {
      final duration = DateTime.now().difference(_sessionStartTime!);
      debugPrint(
        '[ConnectionAnalytics] Ended session $_currentSessionId - duration: ${duration.inMinutes} minutes, reason: ${reason.name}',
      );
    }
    _currentSessionId = null;
    _sessionStartTime = null;
  }

  Future<void> _recordConnected(String watchId) async {
    try {
      final event = ConnectionEvent.connected(
        watchId: watchId,
        sessionId: _currentSessionId,
      );
      await _repository.recordEvent(event);
      debugPrint('[ConnectionAnalytics] Recorded: connected');
    } catch (e) {
      debugPrint('[ConnectionAnalytics] Failed to record connected: $e');
    }
  }

  Future<void> _recordDisconnected(
    String watchId,
    DisconnectReason reason,
    String? details,
  ) async {
    try {
      final event = ConnectionEvent.disconnected(
        watchId: watchId,
        reason: reason,
        details: details,
        sessionId: _currentSessionId,
      );
      await _repository.recordEvent(event);
      debugPrint(
        '[ConnectionAnalytics] Recorded: disconnected (${reason.name})',
      );
    } catch (e) {
      debugPrint('[ConnectionAnalytics] Failed to record disconnected: $e');
    }
  }

  Future<void> _recordReconnectAttempt(String watchId) async {
    try {
      final event = ConnectionEvent.reconnectAttempt(
        watchId: watchId,
        sessionId: _currentSessionId,
      );
      await _repository.recordEvent(event);
      debugPrint('[ConnectionAnalytics] Recorded: reconnect attempt');
    } catch (e) {
      debugPrint(
        '[ConnectionAnalytics] Failed to record reconnect attempt: $e',
      );
    }
  }

  /// Dispose resources
  void dispose() {
    stop();
  }
}

/// Provider for connection analytics service
final connectionAnalyticsServiceProvider = Provider<ConnectionAnalyticsService>(
  (ref) {
    final watchService = ref.watch(watchServiceProvider);
    final repository = ref.watch(connectionAnalyticsRepositoryProvider);

    final service = ConnectionAnalyticsService(watchService, repository);
    service.start();

    ref.onDispose(() {
      service.dispose();
    });

    return service;
  },
);
