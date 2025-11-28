import 'package:flutter/foundation.dart';

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
@immutable
class ConnectionEvent {
  /// Unique identifier
  final int? id;

  /// Watch device ID
  final String watchId;

  /// Type of event
  final ConnectionEventType eventType;

  /// When the event occurred
  final DateTime timestamp;

  /// Reason for disconnection (only for disconnect events)
  final DisconnectReason? reason;

  /// Additional details (e.g., error message)
  final String? details;

  /// Session ID to group connect/disconnect pairs
  final String? sessionId;

  const ConnectionEvent({
    this.id,
    required this.watchId,
    required this.eventType,
    required this.timestamp,
    this.reason,
    this.details,
    this.sessionId,
  });

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

  ConnectionEvent copyWith({
    int? id,
    String? watchId,
    ConnectionEventType? eventType,
    DateTime? timestamp,
    DisconnectReason? reason,
    String? details,
    String? sessionId,
  }) {
    return ConnectionEvent(
      id: id ?? this.id,
      watchId: watchId ?? this.watchId,
      eventType: eventType ?? this.eventType,
      timestamp: timestamp ?? this.timestamp,
      reason: reason ?? this.reason,
      details: details ?? this.details,
      sessionId: sessionId ?? this.sessionId,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ConnectionEvent &&
        other.id == id &&
        other.watchId == watchId &&
        other.eventType == eventType &&
        other.timestamp == timestamp &&
        other.reason == reason &&
        other.details == details &&
        other.sessionId == sessionId;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      watchId,
      eventType,
      timestamp,
      reason,
      details,
      sessionId,
    );
  }

  @override
  String toString() {
    return 'ConnectionEvent(id: $id, watchId: $watchId, eventType: $eventType, '
        'timestamp: $timestamp, reason: $reason, sessionId: $sessionId)';
  }
}
