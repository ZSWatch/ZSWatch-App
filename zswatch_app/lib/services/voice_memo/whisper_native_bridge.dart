import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

/// Low-level FFI bridge to the whisper_ggml_plus native `request()` function.
///
/// This bypasses the plugin's frozen Dart API so we can send custom commands
/// (e.g. `forceCpu`) that the patched C++ code handles. Only used on iOS where
/// Metal GPU is available; on Android this is a no-op.
abstract final class WhisperNativeBridge {
  /// Native function signature: `char* request(char* body)`
  static final _request = _openLib()?.lookupFunction<
      Pointer<Utf8> Function(Pointer<Utf8>),
      Pointer<Utf8> Function(Pointer<Utf8>)>('request');

  static DynamicLibrary? _openLib() {
    try {
      if (Platform.isIOS) {
        return DynamicLibrary.process();
      }
      if (Platform.isAndroid) {
        return DynamicLibrary.open('libwhisper.so');
      }
    } catch (e) {
      debugPrint('[WhisperNativeBridge] Failed to open native library: $e');
    }
    return null;
  }

  /// Tell the whisper native code to force CPU-only mode (no Metal GPU).
  ///
  /// When [forceCpu] is `true`, the cached Metal whisper context is disposed
  /// and the next transcription will create a CPU-only context. When `false`,
  /// the next transcription will recreate with Metal GPU enabled.
  ///
  /// This is a no-op on Android (GPU is already disabled at build time) and
  /// on platforms where the native library isn't available.
  static Future<void> setForceCpu({required bool forceCpu}) async {
    if (!Platform.isIOS) return;

    final requestFn = _request;
    if (requestFn == null) {
      debugPrint('[WhisperNativeBridge] Native request function not available');
      return;
    }

    try {
      // Run on an isolate to avoid blocking the UI thread — the native side
      // acquires a mutex and frees the cached whisper context.
      await Isolate.run(() {
        final lib = Platform.isIOS
            ? DynamicLibrary.process()
            : DynamicLibrary.open('libwhisper.so');

        final nativeRequest = lib.lookupFunction<
            Pointer<Utf8> Function(Pointer<Utf8>),
            Pointer<Utf8> Function(Pointer<Utf8>)>('request');

        final body = json.encode({
          '@type': 'forceCpu',
          'value': forceCpu,
        });

        final Pointer<Utf8> data = body.toNativeUtf8();
        final Pointer<Utf8> res = nativeRequest(data);

        final result = res.toDartString();
        malloc.free(data);

        return result;
      });

      debugPrint(
          '[WhisperNativeBridge] forceCpu=$forceCpu — context will be recreated on next transcription');
    } catch (e) {
      debugPrint('[WhisperNativeBridge] Failed to set forceCpu: $e');
    }
  }
}
