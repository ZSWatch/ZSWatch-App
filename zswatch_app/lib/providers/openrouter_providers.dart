import 'dart:convert';

import 'package:chrono_ai_flow/chrono_ai_flow.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/ai/openrouter_client.dart';
import '../services/ai/voice_model_config.dart';
import 'companion_runtime_providers.dart';
import 'settings_providers.dart';

class PrefBoolNotifier extends StateNotifier<bool> {
  PrefBoolNotifier(this._prefs, this._key, bool fallback)
    : super(_prefs?.getBool(_key) ?? fallback);
  final SharedPreferences? _prefs;
  final String _key;

  void set(bool value) {
    state = value;
    _prefs?.setBool(_key, value);
  }
}

class PrefStringNotifier extends StateNotifier<String> {
  PrefStringNotifier(this._prefs, this._key, String fallback)
    : super(_prefs?.getString(_key) ?? fallback);
  final SharedPreferences? _prefs;
  final String _key;

  void set(String value) {
    state = value;
    _prefs?.setString(_key, value);
  }
}

/// Experimental: Whisper (and the local LLM on Android) instead of OpenRouter.
final onDeviceProcessingProvider =
    StateNotifierProvider<PrefBoolNotifier, bool>(
      (ref) => PrefBoolNotifier(
        ref.watch(sharedPreferencesProvider).valueOrNull,
        SettingsKeys.onDeviceProcessing,
        false,
      ),
    );

final openRouterSttModelProvider =
    StateNotifierProvider<PrefStringNotifier, String>(
      (ref) => PrefStringNotifier(
        ref.watch(sharedPreferencesProvider).valueOrNull,
        SettingsKeys.openRouterSttModel,
        OpenRouterRequest.defaultTranscriptionModel,
      ),
    );

final openRouterAnalysisModelProvider =
    StateNotifierProvider<PrefStringNotifier, String>(
      (ref) => PrefStringNotifier(
        ref.watch(sharedPreferencesProvider).valueOrNull,
        SettingsKeys.openRouterAnalysisModel,
        OpenRouterRequest.defaultAnalysisModel,
      ),
    );

/// Models new voice jobs use, following every setting above.
final voiceModelConfigProvider = Provider<VoiceModelConfig>((ref) {
  if (ref.watch(onDeviceProcessingProvider)) {
    return VoiceModelConfig(
      transcriptionModel: ref.watch(transcriptionEngineTypeProvider).name,
      analysisModel: ref.watch(selectedAiModelIdProvider),
      correctTranscription: ref.watch(aiCorrectionEnabledProvider),
      onDevice: true,
    );
  }
  return VoiceModelConfig(
    transcriptionModel:
        openRouterModelPrefix + ref.watch(openRouterSttModelProvider),
    analysisModel:
        openRouterModelPrefix + ref.watch(openRouterAnalysisModelProvider),
    correctTranscription: false,
    onDevice: false,
  );
});

/// HTTP client factory, also used when verifying a newly entered key.
final openRouterClientFactoryProvider =
    Provider<OpenRouterClient Function(String)>(
      (ref) =>
          (key) => OpenRouterClient(key),
    );

/// The key stored by the native owner; null when none is set.
final openRouterKeyProvider =
    StateNotifierProvider<OpenRouterKeyNotifier, AsyncValue<String?>>((ref) {
      // Reload when Demo Mode swaps the client.
      ref.watch(companionClientProvider);
      return OpenRouterKeyNotifier(ref);
    });

class OpenRouterKeyNotifier extends StateNotifier<AsyncValue<String?>> {
  OpenRouterKeyNotifier(this._ref) : super(const AsyncValue.loading()) {
    _load();
  }
  final Ref _ref;

  Future<void> _load() async {
    state = await AsyncValue.guard(
      () => _ref.read(companionClientProvider).cloudCredential(),
    );
  }

  /// Validates [key] with OpenRouter before storing it. Throws
  /// [OpenRouterFailure] when OpenRouter rejects it. Explicitly saving a key
  /// opts into cloud transcription and analysis; loading a stored key does not
  /// change the user's switches.
  Future<OpenRouterKeyInfo> save(String key) async {
    final trimmed = key.trim();
    final client = _ref.read(openRouterClientFactoryProvider)(trimmed);
    try {
      final info = await client.keyInfo();
      final owner = _ref.read(companionClientProvider);
      await owner.setCloudCredential(trimmed);
      state = AsyncValue.data(trimmed);
      // Read the native owner directly: onboarding can run before any watch or
      // snapshot stream has been selected.
      try {
        final snapshot = await owner.snapshot();
        await _ref.read(sharedPreferencesProvider.future);
        await owner.configureVoiceProcessing(
          watchId: snapshot.watch?.id ?? '',
          enabled: true,
          transcriptionModel:
              openRouterModelPrefix + _ref.read(openRouterSttModelProvider),
          analysisModel:
              openRouterModelPrefix +
              _ref.read(openRouterAnalysisModelProvider),
          correctTranscription: false,
          analyze: true,
        );
      } on Object {
        throw StateError(
          'The key was stored, but automatic voice processing could not be enabled. '
          'Save the key again to retry.',
        );
      }
      return info;
    } finally {
      client.close();
    }
  }

  Future<void> clear() async {
    await _ref.read(companionClientProvider).setCloudCredential(null);
    state = const AsyncValue.data(null);
  }
}

/// Usage and limit of the stored key. Null when no key is stored.
final openRouterKeyInfoProvider =
    FutureProvider.autoDispose<OpenRouterKeyInfo?>((ref) async {
      final key = ref.watch(openRouterKeyProvider).valueOrNull;
      if (key == null) return null;
      final client = OpenRouterClient(key);
      try {
        return await client.keyInfo();
      } finally {
        client.close();
      }
    });

/// Models for the pickers, cached for a day. Invalidate
/// [openRouterModelsRefreshProvider] to fetch again.
final openRouterModelsRefreshProvider = StateProvider<int>((ref) => 0);

final openRouterModelsProvider = FutureProvider<List<OpenRouterModel>>((
  ref,
) async {
  final force = ref.watch(openRouterModelsRefreshProvider) > 0;
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  final cached = prefs.getString(SettingsKeys.openRouterModelsCache);
  if (cached != null && !force) {
    try {
      final json = jsonDecode(cached) as Map<String, Object?>;
      final age = DateTime.now().millisecondsSinceEpoch - (json['at']! as int);
      if (age < const Duration(days: 1).inMilliseconds) {
        return [
          for (final m in json['models']! as List)
            OpenRouterModel.fromJson(Map<String, Object?>.from(m as Map)),
        ];
      }
    } on Object catch (e) {
      debugPrint('[OpenRouterModels] Ignoring cache: ${e.runtimeType}');
    }
  }
  final models = await OpenRouterClient.fetchModels();
  final useful = models
      .where((m) => !m.isFree && m.acceptsText && m.promptPrice >= 0)
      .toList();
  await prefs.setString(
    SettingsKeys.openRouterModelsCache,
    jsonEncode({
      'at': DateTime.now().millisecondsSinceEpoch,
      'models': [for (final m in useful) m.toJson()],
    }),
  );
  return useful;
});

/// Recommended models, best first: benchmark score on the app's prompt,
/// latency, price and Swedish quality (2026-10-21 sweep).
const recommendedAnalysisModels = [
  'google/gemini-3.1-flash-lite',
  'anthropic/claude-haiku-5.5',
  'openai/gpt-4.1-mini',
];
const recommendedTranscriptionModels = [
  'google/gemini-3.1-flash-lite',
  'google/gemini-3.5-flash-lite',
  'mistralai/voxtral-small-24b-2507',
];
