import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Dart wrapper for the native LiteRT-LM inference engine on Android.
///
/// Uses a MethodChannel + EventChannel pair to communicate with
/// [LiteRtLmBridge.kt] on the Kotlin side.
class LiteRtLmService {
  static const _methodChannel = MethodChannel('dev.zswatch.app/litert_lm');
  static const _eventChannel = EventChannel('dev.zswatch.app/litert_lm_events');

  bool _loaded = false;
  StreamSubscription<dynamic>? _eventSubscription;

  /// Whether a model is currently loaded.
  bool get isLoaded => _loaded;

  /// Load a .litertlm model file.
  ///
  /// [modelPath] must be an absolute path to the model on-device.
  /// [backend] can be 'gpu' (default), 'cpu', or 'npu'.
  /// [maxTokens] controls the max KV-cache size (default 4096).
  Future<void> loadModel(
    String modelPath, {
    String backend = 'gpu',
    int maxTokens = 4096,
  }) async {
    debugPrint('[LiteRtLmService] Loading model: $modelPath (backend=$backend)');
    await _methodChannel.invokeMethod('loadModel', {
      'modelPath': modelPath,
      'backend': backend,
      'maxTokens': maxTokens,
    });
    _loaded = true;
    debugPrint('[LiteRtLmService] Model loaded successfully');
  }

  /// Run inference with the loaded model.
  ///
  /// Returns the full generated text, token count, and elapsed time.
  /// Optionally calls [onToken] with partial results during generation.
  Future<LiteRtLmResult> generate(
    String prompt, {
    double temperature = 0.3,
    int topK = 40,
    double topP = 1.0,
    void Function(String partialText, int tokenCount)? onToken,
  }) async {
    if (!_loaded) {
      throw StateError('Model not loaded. Call loadModel() first.');
    }

    // Set up event stream for partial tokens
    final completer = Completer<void>();
    _eventSubscription?.cancel();
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is Map) {
          final type = event['type'] as String?;
          if (type == 'token') {
            onToken?.call(
              event['text'] as String? ?? '',
              event['tokenCount'] as int? ?? 0,
            );
          } else if (type == 'done') {
            if (!completer.isCompleted) completer.complete();
          }
        }
      },
      onError: (dynamic error) {
        if (!completer.isCompleted) completer.completeError(error);
      },
    );

    try {
      debugPrint('[LiteRtLmService] Calling generate MethodChannel...');
      final result = await _methodChannel.invokeMethod<Map>('generate', {
        'prompt': prompt,
        'temperature': temperature,
        'topK': topK,
        'topP': topP,
      });

      debugPrint('[LiteRtLmService] MethodChannel returned: $result');

      if (result == null) {
        throw PlatformException(
          code: 'NULL_RESULT',
          message: 'generate returned null',
        );
      }

      return LiteRtLmResult(
        text: result['text'] as String? ?? '',
        tokenCount: result['tokenCount'] as int? ?? 0,
        elapsedMs: result['elapsedMs'] as int? ?? 0,
        cancelled: result['cancelled'] as bool? ?? false,
      );
    } finally {
      _eventSubscription?.cancel();
      _eventSubscription = null;
    }
  }

  /// Cancel the current inference.
  Future<void> cancel() async {
    await _methodChannel.invokeMethod('cancel');
  }

  /// Release all native resources.
  Future<void> dispose() async {
    _eventSubscription?.cancel();
    _eventSubscription = null;
    await _methodChannel.invokeMethod('dispose');
    _loaded = false;
  }

  /// Check if a model is loaded on the native side.
  Future<bool> isModelLoaded() async {
    final loaded = await _methodChannel.invokeMethod<bool>('isLoaded');
    return loaded ?? false;
  }
}

/// Result of a single LiteRT-LM inference call.
class LiteRtLmResult {
  final String text;
  final int tokenCount;
  final int elapsedMs;
  final bool cancelled;

  const LiteRtLmResult({
    required this.text,
    required this.tokenCount,
    required this.elapsedMs,
    this.cancelled = false,
  });

  double get tokensPerSecond =>
      elapsedMs > 0 ? (tokenCount / (elapsedMs / 1000.0)) : 0.0;

  @override
  String toString() =>
      'LiteRtLmResult(tokens=$tokenCount, ${elapsedMs}ms, '
      '${tokensPerSecond.toStringAsFixed(1)} tok/s, '
      'cancelled=$cancelled)';
}
