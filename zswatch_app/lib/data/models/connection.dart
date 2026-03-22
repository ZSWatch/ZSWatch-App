import 'package:freezed_annotation/freezed_annotation.dart';

import 'connection_state.dart';

part 'connection.freezed.dart';

/// PHY mode for BLE connection
enum PhyMode {
  /// 1 Mbps PHY (default)
  phy1M,

  /// 2 Mbps PHY (preferred for higher throughput)
  phy2M,

  /// Coded PHY (long range, not typically used for ZSWatch)
  coded,
}

/// Connection model representing an active BLE connection
///
/// This is an in-memory model that holds the current connection state
/// and metadata. It's not persisted to the database.
@freezed
abstract class Connection with _$Connection {
  const Connection._();

  const factory Connection({
    /// ID of the connected watch
    required String watchId,

    /// Name of the connected watch
    String? watchName,

    /// Current connection state
    required WatchConnectionState state,

    /// Signal strength in dBm (negative value, closer to 0 is stronger)
    int? rssi,

    /// Negotiated MTU size
    int? mtu,

    /// Current PHY mode
    PhyMode? phyMode,

    /// Whether Data Length Extension is enabled
    @Default(false) bool dleEnabled,

    /// Whether watch is currently charging
    @Default(false) bool isCharging,

    /// Number of reconnection attempts in current session
    @Default(0) int reconnectionCount,

    /// When the current connection was established
    DateTime? connectedAt,

    /// Last data exchange timestamp
    DateTime? lastActivityAt,

    /// Error information if state is error
    ConnectionErrorType? errorType,

    /// Additional error details
    String? errorDetails,
  }) = _Connection;

  /// Create initial disconnected connection state
  factory Connection.disconnected(String watchId) {
    return Connection(
      watchId: watchId,
      state: WatchConnectionState.disconnected,
    );
  }

  /// Create connection in connecting state
  factory Connection.connecting(String watchId) {
    return Connection(watchId: watchId, state: WatchConnectionState.connecting);
  }

  /// Create connection in error state
  factory Connection.error(
    String watchId,
    ConnectionErrorType errorType, {
    String? details,
  }) {
    return Connection(
      watchId: watchId,
      state: WatchConnectionState.error,
      errorType: errorType,
      errorDetails: details,
    );
  }

  /// Whether currently connected
  bool get isConnected => state.isConnected;

  /// Whether connecting or reconnecting
  bool get isConnecting => state.isConnectingOrReconnecting;

  /// Whether disconnected
  bool get isDisconnected => state.isDisconnected;

  /// Whether in error state
  bool get hasError => state == WatchConnectionState.error;

  /// Connection duration since connected
  Duration? get connectionDuration {
    if (connectedAt == null || !isConnected) return null;
    return DateTime.now().difference(connectedAt!);
  }

  /// Time since last activity
  Duration? get timeSinceLastActivity {
    if (lastActivityAt == null) return null;
    return DateTime.now().difference(lastActivityAt!);
  }

  /// Whether MTU is optimized (above minimum)
  bool get hasOptimizedMtu => mtu != null && mtu! > 23;

  /// Whether using 2M PHY
  bool get isUsing2MPhy => phyMode == PhyMode.phy2M;

  /// Signal strength description
  String get rssiDescription {
    if (rssi == null) return 'Unknown';
    if (rssi! >= -50) return 'Excellent';
    if (rssi! >= -60) return 'Good';
    if (rssi! >= -70) return 'Fair';
    return 'Weak';
  }

  /// Signal strength percentage (0-100)
  int get rssiPercentage {
    if (rssi == null) return 0;
    // Map RSSI from -100 to -30 dBm to 0-100%
    final clamped = rssi!.clamp(-100, -30);
    return ((clamped + 100) * 100 ~/ 70).clamp(0, 100);
  }
}
