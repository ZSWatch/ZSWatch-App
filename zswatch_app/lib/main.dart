import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whisper_ggml_plus_ffmpeg/whisper_ggml_plus_ffmpeg.dart';

import 'app.dart';
import 'providers/companion_runtime_providers.dart';
import 'services/background/companion_dart_worker.dart';
import 'ui/screens/developer/companion_prototype_app.dart';

@pragma('vm:entry-point')
void companionWorkerMain() {
  if (kDebugMode && const bool.fromEnvironment('COMPANION_RUNTIME_PROTOTYPE')) {
    startCompanionDartWorker();
  }
}

void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  if (useNativeCompanionRuntime) {
    runApp(const ProviderScope(child: CompanionPrototypeApp()));
    return;
  }

  // Register Whisper FFmpeg converter for Ogg/Opus → WAV transcription support
  WhisperFFmpegConverter.register();

  // Set preferred orientations (portrait only for mobile)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style for dark theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0D1117),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Set up error handling
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('Flutter error: ${details.exceptionAsString()}');
  };

  // Run the app with Riverpod provider scope
  runApp(const ProviderScope(child: ZSWatchApp()));
}
