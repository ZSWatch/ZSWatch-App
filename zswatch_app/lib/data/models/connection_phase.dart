import 'package:freezed_annotation/freezed_annotation.dart';

import 'connection_state.dart';

part 'connection_phase.freezed.dart';

/// Connection lifecycle phase — replaces boolean flags with explicit states.
///
/// This is the single source of truth for where the connection is in its
/// lifecycle. All providers derive their state from this.
@freezed
sealed class ConnectionPhase with _$ConnectionPhase {
  const ConnectionPhase._();

  /// Not connected to any device
  const factory ConnectionPhase.disconnected() = Disconnected;

  /// Actively scanning for devices
  const factory ConnectionPhase.scanning() = Scanning;

  /// Attempting to establish BLE connection
  const factory ConnectionPhase.connecting() = Connecting;

  /// BLE connected, running post-connection setup (bonding, service discovery,
  /// MTU negotiation, NUS setup, initial sync)
  const factory ConnectionPhase.settingUp({
    /// Which sub-step of setup we're in (for UI status text)
    @Default(SetupStep.bonding) SetupStep step,
  }) = SettingUp;

  /// Fully connected, synced, and ready for communication
  const factory ConnectionPhase.connected() = Connected;

  /// Connection lost, attempting to reconnect
  const factory ConnectionPhase.reconnecting({
    required int attempt,
    @Default(false) bool isBackground,
  }) = Reconnecting;

  /// Unrecoverable error
  const factory ConnectionPhase.error({
    required ConnectionErrorType type,
    String? details,
  }) = PhaseError;

  /// Whether operations can be performed on the watch
  bool get canOperate => this is Connected;

  /// Whether we're in any "trying to connect" state
  bool get isTryingToConnect =>
      this is Connecting || this is SettingUp || this is Reconnecting;

  /// Whether disconnected (including error)
  bool get isDisconnected => this is Disconnected || this is PhaseError;

  /// Map to the existing WatchConnectionState enum for backwards compatibility
  /// with UI code that reads the Connection model.
  WatchConnectionState get watchConnectionState => switch (this) {
        Disconnected() => WatchConnectionState.disconnected,
        Scanning() => WatchConnectionState.scanning,
        Connecting() => WatchConnectionState.connecting,
        SettingUp(step: final step) => switch (step) {
            SetupStep.bonding => WatchConnectionState.bonding,
            SetupStep.discoveringServices =>
              WatchConnectionState.discoveringServices,
            SetupStep.negotiating => WatchConnectionState.negotiating,
            SetupStep.syncing => WatchConnectionState.syncing,
          },
        Connected() => WatchConnectionState.connected,
        Reconnecting() => WatchConnectionState.reconnecting,
        PhaseError() => WatchConnectionState.error,
      };
}

/// Sub-steps within the SettingUp phase, for UI status display.
enum SetupStep {
  bonding,
  discoveringServices,
  negotiating,
  syncing,
}
