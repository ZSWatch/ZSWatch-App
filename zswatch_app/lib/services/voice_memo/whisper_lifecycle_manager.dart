import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:rxdart/rxdart.dart';

import 'whisper_native_bridge.dart';

/// User-facing GPU inference mode for iOS Metal.
///
/// Persisted in SharedPreferences so the choice survives restarts.
enum GpuInferenceMode {
  /// Automatic: GPU in foreground, CPU in background (recommended).
  auto,

  /// Always use Metal GPU — faster but will crash if inference runs while
  /// the app is backgrounded.
  alwaysGpu,

  /// Always use CPU — slower but completely safe in any lifecycle state.
  alwaysCpu,
}

/// Tracks the app's lifecycle state and automatically switches whisper and
/// fllama between Metal GPU (foreground) and CPU-only (background) on iOS.
///
/// iOS kills Metal GPU command buffers when the app is backgrounded
/// (`kIOGPUCommandBufferCallbackErrorBackgroundExecutionNotPermitted`),
/// which crashes the process. This class prevents that by proactively
/// switching whisper to CPU mode before any background transcription runs.
///
/// The user can override via [gpuMode]:
/// - [GpuInferenceMode.auto]: GPU when foregrounded, CPU when backgrounded
/// - [GpuInferenceMode.alwaysGpu]: Always GPU (risky in background)
/// - [GpuInferenceMode.alwaysCpu]: Always CPU (safe, slower)
///
/// fllama (Qwen LLM) reads [shouldUseGpu] at inference time to decide
/// `numGpuLayers`. Whisper is controlled via the native FFI bridge.
class GpuLifecycleManager with WidgetsBindingObserver {
  static GpuLifecycleManager? _instance;

  /// Singleton access. Created lazily on first call.
  static GpuLifecycleManager get instance {
    _instance ??= GpuLifecycleManager._();
    return _instance!;
  }

  GpuLifecycleManager._();

  final _isBackground = BehaviorSubject<bool>.seeded(false);
  final _gpuMode = BehaviorSubject<GpuInferenceMode>.seeded(GpuInferenceMode.auto);

  /// Whether the app is currently in a background/inactive/hidden state
  /// where Metal GPU access is not permitted by iOS.
  bool get isBackground => _isBackground.value;

  /// Stream of background state changes.
  Stream<bool> get backgroundStream => _isBackground.stream;

  /// Current user-chosen GPU mode.
  GpuInferenceMode get gpuMode => _gpuMode.value;

  /// Stream of GPU mode changes (for provider/UI binding).
  Stream<GpuInferenceMode> get gpuModeStream => _gpuMode.stream;

  /// Whether GPU should be used *right now* — combines user preference with
  /// lifecycle state. Both whisper and fllama should read this.
  bool get shouldUseGpu {
    if (!Platform.isIOS) return false; // Android: no Metal
    switch (_gpuMode.value) {
      case GpuInferenceMode.alwaysGpu:
        return true;
      case GpuInferenceMode.alwaysCpu:
        return false;
      case GpuInferenceMode.auto:
        return !_isBackground.value;
    }
  }

  /// Set the user-chosen GPU inference mode. Call from the settings UI.
  void setGpuMode(GpuInferenceMode mode) {
    if (_gpuMode.value == mode) return;
    _gpuMode.add(mode);
    debugPrint('[GpuLifecycleManager] GPU mode set to: ${mode.name}');
    _syncWhisperGpuState();
  }

  bool _initialized = false;

  /// Start observing lifecycle changes. Call once after Flutter binding is
  /// initialized (e.g. in your app's init or a Riverpod provider).
  void initialize() {
    if (_initialized) return;
    _initialized = true;
    WidgetsBinding.instance.addObserver(this);
    debugPrint('[GpuLifecycleManager] Initialized — monitoring app lifecycle for GPU safety');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasBackground = _isBackground.value;
    final nowBackground = state != AppLifecycleState.resumed;

    if (wasBackground != nowBackground) {
      _isBackground.add(nowBackground);
      debugPrint(
          '[GpuLifecycleManager] App lifecycle: $state → '
          '${nowBackground ? "BACKGROUND" : "FOREGROUND"}'
          ' (shouldUseGpu=$shouldUseGpu, mode=${_gpuMode.value.name})');
      _syncWhisperGpuState();
    }
  }

  /// Push the current GPU decision to whisper's native layer.
  void _syncWhisperGpuState() {
    if (Platform.isIOS) {
      WhisperNativeBridge.setForceCpu(forceCpu: !shouldUseGpu);
    }
  }

  void dispose() {
    if (_initialized) {
      WidgetsBinding.instance.removeObserver(this);
      _initialized = false;
    }
    _isBackground.close();
    _gpuMode.close();
  }
}
