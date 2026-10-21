import 'package:chrono_ai_flow/chrono_ai_flow.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/settings_providers.dart';
import '../voice_memo/transcription_engine.dart';
import 'llm_service.dart';
import 'openrouter_client.dart';

/// The models a new voice job is created with. OpenRouter is the default;
/// on-device processing is an experimental opt-in.
class VoiceModelConfig {
  const VoiceModelConfig({
    required this.transcriptionModel,
    required this.analysisModel,
    required this.correctTranscription,
    required this.onDevice,
  });

  factory VoiceModelConfig.fromPrefs(SharedPreferences? prefs) {
    final onDevice = prefs?.getBool(SettingsKeys.onDeviceProcessing) ?? false;
    if (onDevice) {
      return VoiceModelConfig(
        transcriptionModel:
            prefs?.getString(SettingsKeys.transcriptionEngineType) ??
            TranscriptionEngineType.whisperTinyEn.name,
        analysisModel:
            prefs?.getString(SettingsKeys.selectedAiModelId) ??
            LlmService.defaultModelId,
        correctTranscription:
            prefs?.getBool(SettingsKeys.aiCorrectionEnabled) ?? false,
        onDevice: true,
      );
    }
    return VoiceModelConfig(
      transcriptionModel:
          openRouterModelPrefix +
          (prefs?.getString(SettingsKeys.openRouterSttModel) ??
              OpenRouterRequest.defaultTranscriptionModel),
      analysisModel:
          openRouterModelPrefix +
          (prefs?.getString(SettingsKeys.openRouterAnalysisModel) ??
              OpenRouterRequest.defaultAnalysisModel),
      correctTranscription: false,
      onDevice: false,
    );
  }

  final String transcriptionModel;
  final String analysisModel;
  final bool correctTranscription;
  final bool onDevice;

  bool get cloud => !onDevice;

  /// iOS has no local LLM; the cloud can always analyze.
  bool get canAnalyze => cloud || LlmService.localModelsSupported;

  Map<String, Object?> processingRequest(String identity, String operation) => {
    'identity': identity,
    'operation': operation,
    'transcription_model': transcriptionModel,
    'analysis_model': analysisModel,
    'correct_transcription': correctTranscription,
  };
}
