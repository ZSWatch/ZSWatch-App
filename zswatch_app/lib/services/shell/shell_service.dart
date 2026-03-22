import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mcumgr_flutter/mcumgr_flutter.dart';

/// Service for executing shell commands on the watch via SMP (group 9).
///
/// Uses the mcumgr_flutter ShellManager which communicates over BLE
/// using the SMP protocol.
class ShellService {
  String? _deviceId;
  bool _disposed = false;

  /// Set the device to communicate with.
  void setDevice(String deviceId) {
    if (_deviceId != null && _deviceId != deviceId) {
      ShellManager.kill(_deviceId!);
    }
    _deviceId = deviceId;
  }

  /// Execute a shell command and return the result.
  ///
  /// Throws if no device is set or on communication error.
  Future<ShellCommandResult> execute(String command) async {
    final deviceId = _deviceId;
    if (deviceId == null) {
      throw StateError('No device connected for shell commands');
    }

    debugPrint('[ShellService] Execute: $command');
    final result = await ShellManager.execute(deviceId, command);
    debugPrint(
      '[ShellService] Result (rc=${result.returnCode}): ${result.output.length} chars',
    );
    return result;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (_deviceId != null) {
      ShellManager.kill(_deviceId!);
      _deviceId = null;
    }
  }
}
