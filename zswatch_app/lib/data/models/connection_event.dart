import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'connection_event.freezed.dart';

/// Type of connection event
enum ConnectionEventType {
  /// Device connected successfully
  connected,

  /// Device disconnected
  disconnected,

  /// Reconnection attempt started
  reconnectAttempt,

  /// Reconnection attempt failed
  reconnectFailed,
}

/// Extension to convert between string and enum
extension ConnectionEventTypeExtension on ConnectionEventType {
  /// Convert to string for database storage
  String toDbString() {
    switch (this) {
      case ConnectionEventType.connected:
        return 'connected';
      case ConnectionEventType.disconnected:
        return 'disconnected';
      case ConnectionEventType.reconnectAttempt:
        return 'reconnect_attempt';
      case ConnectionEventType.reconnectFailed:
        return 'reconnect_failed';
    }
  }

  /// Create from database string
  static ConnectionEventType fromDbString(String value) {
    switch (value) {
      case 'connected':
        return ConnectionEventType.connected;
      case 'disconnected':
        return ConnectionEventType.disconnected;
      case 'reconnect_attempt':
        return ConnectionEventType.reconnectAttempt;
      case 'reconnect_failed':
        return ConnectionEventType.reconnectFailed;
      default:
        debugPrint('Unknown connection event type: $value');
        return ConnectionEventType.disconnected;
    }
  }
}

/// Reason for disconnection
enum DisconnectReason {
  /// User manually disconnected
  userRequested,

  /// Connection lost (signal, distance, etc.)
  connectionLost,

  /// Device turned off or went out of range
  deviceUnavailable,

  /// Bluetooth was disabled on phone
  bluetoothDisabled,

  /// App was killed or force stopped
  appTerminated,

  /// Unknown reason
  unknown,
}

/// Extension to convert between string and enum
extension DisconnectReasonExtension on DisconnectReason {
  /// Convert to string for database storage
  String toDbString() {
    switch (this) {
      case DisconnectReason.userRequested:
        return 'user_requested';
      case DisconnectReason.connectionLost:
        return 'connection_lost';
      case DisconnectReason.deviceUnavailable:
        return 'device_unavailable';
      case DisconnectReason.bluetoothDisabled:
        return 'bluetooth_disabled';
      case DisconnectReason.appTerminated:
        return 'app_terminated';
      case DisconnectReason.unknown:
        return 'unknown';
    }
  }

  /// Create from database string
  static DisconnectReason fromDbString(String? value) {
    switch (value) {
      case 'user_requested':
        return DisconnectReason.userRequested;
      case 'connection_lost':
        return DisconnectReason.connectionLost;
      case 'device_unavailable':
        return DisconnectReason.deviceUnavailable;
      case 'bluetooth_disabled':
        return DisconnectReason.bluetoothDisabled;
      case 'app_terminated':
        return DisconnectReason.appTerminated;
      default:
        return DisconnectReason.unknown;
    }
  }

  /// Human-readable description
  String get displayName {
    switch (this) {
      case DisconnectReason.userRequested:
        return 'User disconnected';
      case DisconnectReason.connectionLost:
        return 'Connection lost';
      case DisconnectReason.deviceUnavailable:
        return 'Device unavailable';
      case DisconnectReason.bluetoothDisabled:
        return 'Bluetooth disabled';
      case DisconnectReason.appTerminated:
        return 'App terminated';
      case DisconnectReason.unknown:
        return 'Unknown';
    }
  }
}

/// A connection event record for analytics
@freezed
abstract class ConnectionEvent with _$ConnectionEvent {
  const ConnectionEvent._();

  const factory ConnectionEvent({
    /// Unique identifier
    int? id,

    /// Watch device ID
    required String watchId,

    /// Type of event
    required ConnectionEventType eventType,

    /// When the event occurred
    required DateTime timestamp,

    /// Reason for disconnection (only for disconnect events)
    DisconnectReason? reason,

    /// Additional details (e.g., error message)
    String? details,

    /// Session ID to group connect/disconnect pairs
    String? sessionId,
  }) = _ConnectionEvent;

  /// Create a connected event
  factory ConnectionEvent.connected({
    required String watchId,
    DateTime? timestamp,
    String? sessionId,
  }) {
    return ConnectionEvent(
      watchId: watchId,
      eventType: ConnectionEventType.connected,
      timestamp: timestamp ?? DateTime.now(),
      sessionId: sessionId,
    );
  }

  /// Create a disconnected event
  factory ConnectionEvent.disconnected({
    required String watchId,
    DateTime? timestamp,
    DisconnectReason reason = DisconnectReason.unknown,
    String? details,
    String? sessionId,
  }) {
    return ConnectionEvent(
      watchId: watchId,
      eventType: ConnectionEventType.disconnected,
      timestamp: timestamp ?? DateTime.now(),
      reason: reason,
      details: details,
      sessionId: sessionId,
    );
  }

  /// Create a reconnect attempt event
  factory ConnectionEvent.reconnectAttempt({
    required String watchId,
    DateTime? timestamp,
    String? sessionId,
  }) {
    return ConnectionEvent(
      watchId: watchId,
      eventType: ConnectionEventType.reconnectAttempt,
      timestamp: timestamp ?? DateTime.now(),
      sessionId: sessionId,
    );
  }

  /// Create a reconnect failed event
  factory ConnectionEvent.reconnectFailed({
    required String watchId,
    DateTime? timestamp,
    String? details,
    String? sessionId,
  }) {
    return ConnectionEvent(
      watchId: watchId,
      eventType: ConnectionEventType.reconnectFailed,
      timestamp: timestamp ?? DateTime.now(),
      details: details,
      sessionId: sessionId,
    );
  }
}
