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

/// Saves the models chosen in settings to the native voice policy, so e.g.
/// leaving on-device processing or adding a key needs no "Apply". Chat
/// questions use the saved models also while automatic processing is off.
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
  final policy = raw is Map ? raw : null;
  final enabled = policy?['enabled'] == true;
  if (watch == null || snapshot?.fields['desired_running'] != true) {
    return;
  }
  final config = ref.watch(voiceModelConfigProvider);
  if (policy != null &&
      policy['transcription_model'] == config.transcriptionModel &&
      policy['analysis_model'] == config.analysisModel &&
      policy['correct_transcription'] == config.correctTranscription) {
    return;
  }
  if (enabled &&
      config.cloud &&
      ref.watch(openRouterKeyProvider).valueOrNull == null) {
    return;
  }
  final analyze = config.canAnalyze && policy?['analysis_enabled'] != false;
  final attempt = ref.read(_voicePolicySyncAttemptProvider);
  final signature =
      '${watch.id}|$enabled|${config.transcriptionModel}|'
      '${config.analysisModel}|${config.correctTranscription}|$analyze';
  // A failed apply is not retried until the choice changes.
  if (attempt.signature == signature) return;
  attempt.signature = signature;
  unawaited(
    _apply(ref, attempt, signature, watch.id, config, enabled, analyze),
  );
});

class _VoicePolicySyncAttempt {
  String? signature;
}

final _voicePolicySyncAttemptProvider = Provider<_VoicePolicySyncAttempt>(
  (ref) => _VoicePolicySyncAttempt(),
);

Future<void> _apply(
  Ref ref,
  _VoicePolicySyncAttempt attempt,
  String signature,
  String watchId,
  VoiceModelConfig config,
  bool enabled,
  bool analyze,
) async {
  try {
    if (enabled && !config.cloud) {
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
      // A newer choice may have been saved while this one waited.
      if (attempt.signature != signature) return;
    }
    await ref
        .read(companionClientProvider)
        .configureVoiceProcessing(
          watchId: watchId,
          enabled: enabled,
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
