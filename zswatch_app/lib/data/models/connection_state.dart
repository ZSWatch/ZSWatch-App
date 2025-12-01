/// Connection state for BLE connection lifecycle
///
/// Represents all possible states of a BLE connection to a ZSWatch device.
enum WatchConnectionState {
  /// Not connected to any device
  disconnected,

  /// Actively scanning for devices
  scanning,

  /// Attempting to establish connection
  connecting,

  /// Performing BLE bonding/pairing
  bonding,

  /// Discovering GATT services
  discoveringServices,

  /// Negotiating connection parameters (MTU, PHY)
  negotiating,

  /// BLE connected, performing initial sync (time, media state)
  syncing,

  /// Fully connected, synced, and ready for communication
  connected,

  /// Connection lost, attempting to reconnect
  reconnecting,

  /// Disconnecting from device
  disconnecting,

  /// Connection error occurred
  error,
}

/// Extension methods for WatchConnectionState
extension WatchConnectionStateExtension on WatchConnectionState {
  /// Whether the state represents an active connection
  bool get isConnected => this == WatchConnectionState.connected;

  /// Whether the state represents a connecting process
  bool get isConnecting =>
      this == WatchConnectionState.connecting ||
      this == WatchConnectionState.bonding ||
      this == WatchConnectionState.discoveringServices ||
      this == WatchConnectionState.negotiating ||
      this == WatchConnectionState.syncing;

  /// Whether the state represents any form of connection attempt
  bool get isConnectingOrReconnecting =>
      isConnecting || this == WatchConnectionState.reconnecting;

  /// Whether the state represents a disconnected state
  bool get isDisconnected =>
      this == WatchConnectionState.disconnected ||
      this == WatchConnectionState.error;

  /// Whether the state is scanning
  bool get isScanning => this == WatchConnectionState.scanning;

  /// Whether operations can be performed (connected only)
  bool get canPerformOperations => this == WatchConnectionState.connected;

  /// Human-readable status text
  String get statusText {
    switch (this) {
      case WatchConnectionState.disconnected:
        return 'Disconnected';
      case WatchConnectionState.scanning:
        return 'Scanning...';
      case WatchConnectionState.connecting:
        return 'Connecting...';
      case WatchConnectionState.bonding:
        return 'Pairing...';
      case WatchConnectionState.discoveringServices:
        return 'Discovering services...';
      case WatchConnectionState.negotiating:
        return 'Optimizing connection...';
      case WatchConnectionState.syncing:
        return 'Syncing...';
      case WatchConnectionState.connected:
        return 'Connected';
      case WatchConnectionState.reconnecting:
        return 'Reconnecting...';
      case WatchConnectionState.disconnecting:
        return 'Disconnecting...';
      case WatchConnectionState.error:
        return 'Connection error';
    }
  }

  /// Short status text for compact displays
  String get shortStatusText {
    switch (this) {
      case WatchConnectionState.disconnected:
        return 'Offline';
      case WatchConnectionState.scanning:
        return 'Scanning';
      case WatchConnectionState.connecting:
      case WatchConnectionState.bonding:
      case WatchConnectionState.discoveringServices:
      case WatchConnectionState.negotiating:
        return 'Connecting';
      case WatchConnectionState.syncing:
        return 'Syncing';
      case WatchConnectionState.connected:
        return 'Connected';
      case WatchConnectionState.reconnecting:
        return 'Reconnecting';
      case WatchConnectionState.disconnecting:
        return 'Disconnecting';
      case WatchConnectionState.error:
        return 'Error';
    }
  }
}

/// Connection error types
enum ConnectionErrorType {
  /// Bluetooth is disabled on the device
  bluetoothDisabled,

  /// Bluetooth permissions not granted
  permissionDenied,

  /// Device not found (moved out of range or off)
  deviceNotFound,

  /// Connection attempt timed out
  timeout,

  /// Bonding/pairing failed
  bondingFailed,

  /// Service discovery failed
  serviceDiscoveryFailed,

  /// Device disconnected unexpectedly
  unexpectedDisconnect,

  /// Maximum reconnection attempts reached
  maxReconnectionsReached,

  /// Generic/unknown error
  unknown,
}

/// Extension methods for ConnectionErrorType
extension ConnectionErrorTypeExtension on ConnectionErrorType {
  /// Human-readable error message
  String get message {
    switch (this) {
      case ConnectionErrorType.bluetoothDisabled:
        return 'Bluetooth is turned off. Please enable Bluetooth to connect.';
      case ConnectionErrorType.permissionDenied:
        return 'Bluetooth permission is required to connect to your watch.';
      case ConnectionErrorType.deviceNotFound:
        return 'Watch not found. Make sure it\'s nearby and powered on.';
      case ConnectionErrorType.timeout:
        return 'Connection timed out. Please try again.';
      case ConnectionErrorType.bondingFailed:
        return 'Pairing failed. Try removing the watch from Bluetooth settings and pair again.';
      case ConnectionErrorType.serviceDiscoveryFailed:
        return 'Could not communicate with watch. Try restarting the watch.';
      case ConnectionErrorType.unexpectedDisconnect:
        return 'Lost connection to watch.';
      case ConnectionErrorType.maxReconnectionsReached:
        return 'Could not reconnect after multiple attempts.';
      case ConnectionErrorType.unknown:
        return 'An unexpected error occurred.';
    }
  }

  /// Whether the error is recoverable (can retry)
  bool get isRecoverable {
    switch (this) {
      case ConnectionErrorType.bluetoothDisabled:
      case ConnectionErrorType.permissionDenied:
        return false; // Requires user action
      case ConnectionErrorType.deviceNotFound:
      case ConnectionErrorType.timeout:
      case ConnectionErrorType.unexpectedDisconnect:
      case ConnectionErrorType.unknown:
        return true; // Can retry
      case ConnectionErrorType.bondingFailed:
      case ConnectionErrorType.maxReconnectionsReached:
        return false; // Likely needs device reset or re-pairing
      case ConnectionErrorType.serviceDiscoveryFailed:
        return true; // Can be a transient BLE issue, retry is worthwhile
    }
  }
}

