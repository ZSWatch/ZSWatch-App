import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Manages an Android foreground service + PARTIAL_WAKE_LOCK that keeps the
/// CPU at full speed during LLM inference.
///
/// Without this, Android throttles CPU scheduling as soon as the Activity
/// leaves the foreground — even for a brief notification-shade pull — which
/// can halve prompt-eval throughput.
///
/// On iOS this is a no-op (CoreBluetooth background modes + no OS-level CPU
/// throttling for active work).
class LlmComputeService {
  static const _channel = MethodChannel('dev.zswatch.app/llm_compute');

  static LlmComputeService? _instance;
  static LlmComputeService get instance => _instance ??= LlmComputeService._();

  LlmComputeService._();

  bool _running = false;
  bool get isRunning => _running;

  /// Start the foreground service before inference.
  Future<void> start() async {
    if (!Platform.isAndroid || _running) return;
    try {
      await _channel.invokeMethod('start');
      _running = true;
      debugPrint('[LlmComputeService] Started');
    } on PlatformException catch (e) {
      debugPrint('[LlmComputeService] Failed to start: ${e.message}');
    }
  }

  /// Stop the foreground service after inference completes.
  Future<void> stop() async {
    if (!Platform.isAndroid || !_running) return;
    try {
      await _channel.invokeMethod('stop');
      _running = false;
      debugPrint('[LlmComputeService] Stopped');
    } on PlatformException catch (e) {
      debugPrint('[LlmComputeService] Failed to stop: ${e.message}');
    }
  }
}
