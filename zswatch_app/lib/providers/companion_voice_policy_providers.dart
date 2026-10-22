import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/ai/voice_model_config.dart';
import '../services/voice_memo/transcription_engine.dart';
import 'ai_providers.dart';
import 'companion_runtime_providers.dart';
import 'demo_mode_provider.dart';
import 'openrouter_providers.dart';
import 'settings_providers.dart';
import 'voice_memo_providers.dart';

/// Applies the models chosen in settings to enabled automatic processing, so
/// e.g. leaving on-device processing or adding a key needs no "Apply".
final companionVoicePolicySyncProvider = Provider<void>((ref) {
  if (!ref.watch(nativeCompanionRuntimeProvider) ||
      ref.watch(demoModeProvider) ||
      // Before the preferences load the config shows the defaults.
      ref.watch(sharedPreferencesProvider).valueOrNull == null) {
    return;
  }
  final snapshot = ref.watch(companionSnapshotProvider).asData?.value;
  final watch = snapshot?.watch;
  final raw = snapshot?.fields['voice_processing_policy'];
  if (watch == null ||
      raw is! Map ||
      raw['enabled'] != true ||
      raw['watch_id'] != watch.id ||
      snapshot?.fields['desired_running'] != true) {
    return;
  }
  final config = ref.watch(voiceModelConfigProvider);
  final hasKey = ref.watch(openRouterKeyProvider).valueOrNull != null;
  if (raw['transcription_model'] == config.transcriptionModel &&
      raw['analysis_model'] == config.analysisModel &&
      raw['correct_transcription'] == config.correctTranscription) {
    return;
  }
  if (config.cloud && !hasKey) return;
  final analyze = config.canAnalyze && raw['analysis_enabled'] != false;
  final attempt = ref.read(_voicePolicySyncAttemptProvider);
  final signature =
      '${watch.id}|${config.transcriptionModel}|${config.analysisModel}|'
      '${config.correctTranscription}|$analyze';
  // A failed apply is not retried until the choice changes.
  if (attempt.signature == signature) return;
  attempt.signature = signature;
  unawaited(_apply(ref, watch.id, config, analyze));
});

class _VoicePolicySyncAttempt {
  String? signature;
}

final _voicePolicySyncAttemptProvider = Provider<_VoicePolicySyncAttempt>(
  (ref) => _VoicePolicySyncAttempt(),
);

Future<void> _apply(
  Ref ref,
  String watchId,
  VoiceModelConfig config,
  bool analyze,
) async {
  try {
    if (!config.cloud) {
      // Local models must be downloaded; otherwise "Apply" stays visible.
      final speech = await ref.read(
        transcriptionModelStatusProvider(
          TranscriptionEngineType.values.byName(config.transcriptionModel),
        ).future,
      );
      if (!speech.downloaded ||
          (analyze && !await ref.read(llmModelDownloadedProvider.future))) {
        return;
      }
    }
    await ref
        .read(companionClientProvider)
        .configureVoiceProcessing(
          watchId: watchId,
          enabled: true,
          transcriptionModel: config.transcriptionModel,
          analysisModel: config.analysisModel,
          correctTranscription: config.correctTranscription,
          analyze: analyze,
        );
    debugPrint('[VoicePolicySync] Applied ${config.transcriptionModel}');
  } catch (error) {
    debugPrint('[VoicePolicySync] Could not apply models: $error');
  }
}
