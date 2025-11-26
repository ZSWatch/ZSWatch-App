import 'package:equatable/equatable.dart';

import 'connection_state.dart';

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
class Connection extends Equatable {
  /// ID of the connected watch
  final String watchId;

  /// Name of the connected watch
  final String? watchName;

  /// Current connection state
  final WatchConnectionState state;

  /// Signal strength in dBm (negative value, closer to 0 is stronger)
  final int? rssi;

  /// Negotiated MTU size
  final int? mtu;

  /// Current PHY mode
  final PhyMode? phyMode;

  /// Whether Data Length Extension is enabled
  final bool dleEnabled;

  /// Whether watch is currently charging
  final bool isCharging;

  /// Number of reconnection attempts in current session
  final int reconnectionCount;

  /// When the current connection was established
  final DateTime? connectedAt;

  /// Last data exchange timestamp
  final DateTime? lastActivityAt;

  /// Error information if state is error
  final ConnectionErrorType? errorType;

  /// Additional error details
  final String? errorDetails;

  const Connection({
    required this.watchId,
    this.watchName,
    required this.state,
    this.rssi,
    this.mtu,
    this.phyMode,
    this.dleEnabled = false,
    this.isCharging = false,
    this.reconnectionCount = 0,
    this.connectedAt,
    this.lastActivityAt,
    this.errorType,
    this.errorDetails,
  });

  /// Create initial disconnected connection state
  factory Connection.disconnected(String watchId) {
    return Connection(
      watchId: watchId,
      state: WatchConnectionState.disconnected,
    );
  }

  /// Create connection in connecting state
  factory Connection.connecting(String watchId) {
    return Connection(
      watchId: watchId,
      state: WatchConnectionState.connecting,
    );
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

  /// Copy with modified fields
  Connection copyWith({
    String? watchId,
    String? watchName,
    WatchConnectionState? state,
    int? rssi,
    int? mtu,
    PhyMode? phyMode,
    bool? dleEnabled,
    bool? isCharging,
    int? reconnectionCount,
    DateTime? connectedAt,
    DateTime? lastActivityAt,
    ConnectionErrorType? errorType,
    String? errorDetails,
  }) {
    return Connection(
      watchId: watchId ?? this.watchId,
      watchName: watchName ?? this.watchName,
      state: state ?? this.state,
      rssi: rssi ?? this.rssi,
      mtu: mtu ?? this.mtu,
      phyMode: phyMode ?? this.phyMode,
      dleEnabled: dleEnabled ?? this.dleEnabled,
      isCharging: isCharging ?? this.isCharging,
      reconnectionCount: reconnectionCount ?? this.reconnectionCount,
      connectedAt: connectedAt ?? this.connectedAt,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      errorType: errorType ?? this.errorType,
      errorDetails: errorDetails ?? this.errorDetails,
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

  @override
  List<Object?> get props => [
        watchId,
        watchName,
        state,
        rssi,
        mtu,
        phyMode,
        dleEnabled,
        isCharging,
        reconnectionCount,
        connectedAt,
        lastActivityAt,
        errorType,
        errorDetails,
      ];

  @override
  String toString() {
    return 'Connection(watchId: $watchId, state: ${state.name}, rssi: $rssi, mtu: $mtu)';
  }
}

