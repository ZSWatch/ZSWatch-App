import 'package:flutter/services.dart';
import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit_config.dart';
import 'package:flutter/foundation.dart';
import '../ai/companion_voice_processor.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

const companionWorkerChannel = 'dev.zswatch.app/companion_worker_v1';

/// Service-owned Dart entry point. No UI, providers, watch connection or DB.
/// The deterministic job verifies the execution seam before enabling models.
Future<void> startCompanionDartWorker() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Inference diagnostics must not routinely log private transcript/prompt text.
  // The native owner reports bounded state/error codes for this engine.
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }
  const channel = MethodChannel(companionWorkerChannel);
  var busy = false;
  String? currentJob;
  CompanionVoiceCancellation? cancellation;
  channel.setMethodCallHandler((call) async {
    if (call.method == 'cancel') {
      final args = Map<String, Object?>.from(call.arguments as Map);
      if (args['job_id'] != currentJob || cancellation == null) return false;
      await cancellation!.cancel();
      return true;
    }
    if (call.method != 'executeFixture' && call.method != 'executeRecording') {
      throw MissingPluginException();
    }
    if (busy) throw PlatformException(code: 'BUSY');
    final request = Map<String, Object?>.from(call.arguments as Map);
    busy = true;
    currentJob = request['job_id'] as String;
    cancellation = CompanionVoiceCancellation();
    try {
      final Map<String, Object?> result;
      final runtime = <String, Object?>{};
      if (call.method == 'executeRecording') {
        result = await processCompanionVoiceRecording(
          request,
          cancellation: cancellation,
          saveTranscript: (transcript) async {
            await channel.invokeMethod<void>('checkpoint', {
              'job_id': request['job_id'],
              'transcript': transcript,
            });
          },
        );
      } else {
        result = companionLocalFixtureResult(request);
        await getTemporaryDirectory();
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          runtime['ffmpeg_version'] = await FFmpegKitConfig.getFFmpegVersion();
          runtime['available_memory_mb'] = await const MethodChannel(
            'dev.zswatch.app/productivity',
          ).invokeMethod<int>('getAvailableMemoryMB');
          runtime['path_provider'] = true;
        }
        await Future<void>.delayed(const Duration(seconds: 15));
      }
      return {
        'version': 1,
        'job_id': request['job_id'],
        'plugin_ready': true,
        'result': result,
        if (runtime.isNotEmpty) 'runtime': runtime,
      };
    } finally {
      currentJob = null;
      cancellation = null;
      busy = false;
    }
  });
  await channel.invokeMethod<void>('ready', {'version': 1});
}

/// Only a fixed metadata fixture can enter this first engine experiment.
Map<String, Object?> companionLocalFixtureResult(Map<String, Object?> request) {
  final spec = request['spec'];
  if (request['version'] != 1 ||
      request['job_id'] is! String ||
      spec is! Map ||
      spec['version'] != 1 ||
      spec['backend'] != 'local' ||
      spec['provider'] != 'dart-fixture' ||
      spec['upload_authorized'] != false ||
      spec['watch_id'] != 'fixture-watch' ||
      spec['recording_id'] != 'fixture-recording-local-001' ||
      spec['model'] != 'deterministic-v1' ||
      spec['pipeline_revision'] != 'voice-v1' ||
      spec['generation'] != 1 ||
      spec['input_sha256'] !=
          'effa60b67bee0f4d8da64cc35755a07a1e7535b2ed0ced083ce34bdd7d22ff18') {
    throw const FormatException('Unsupported local worker fixture');
  }
  return {
    'version': 1,
    'transcript': 'Påminn mig om att ladda klockan i kväll.',
    'summary': 'Ladda klockan 🔋',
    'category': 'reminder',
    'actions': [
      {
        'type': 'reminder',
        'title': 'Ladda klockan',
        'due_date': '2026-10-02T18:00:00Z',
      },
    ],
  };
}
