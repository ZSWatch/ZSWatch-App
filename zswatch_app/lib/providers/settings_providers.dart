import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/voice_memo/transcription_engine.dart';
import '../services/voice_memo/whisper_lifecycle_manager.dart';

/// Keys for SharedPreferences
abstract final class SettingsKeys {
  static const String developerModeEnabled = 'developer_mode_enabled';
  static const String notificationsEnabled = 'notifications_enabled';
  static const String autoReconnect = 'auto_reconnect';
  static const String autoTimeSync = 'auto_time_sync';
  static const String preferredMtu = 'preferred_mtu';
  static const String lastConnectedWatchId = 'last_connected_watch_id';
  static const String notificationFilterPackages = 'notification_filter_packages';
  static const String onboardingCompleted = 'onboarding_completed';
  static const String keepScreenOnDuringDfu = 'keep_screen_on_during_dfu';
  static const String backgroundConnectionEnabled = 'background_connection_enabled';
  static const String transcriptionEngineType = 'transcription_engine_type';
  static const String localAiEnabled = 'local_ai_enabled';
  static const String autoProcessVoiceNotes = 'auto_process_voice_notes';
  static const String selectedAiModelId = 'selected_ai_model_id';
  static const String selectedProductivityCalendarId =
      'selected_productivity_calendar_id';
  static const String gpuInferenceMode = 'gpu_inference_mode';
  static const String autoCreateActions = 'auto_create_actions';
}

/// Provider for SharedPreferences instance
final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) async {
  return SharedPreferences.getInstance();
});

/// Provider for developer mode setting
final developerModeProvider =
    StateNotifierProvider<DeveloperModeNotifier, bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return DeveloperModeNotifier(prefs.valueOrNull);
});

class DeveloperModeNotifier extends StateNotifier<bool> {
  final SharedPreferences? _prefs;

  DeveloperModeNotifier(this._prefs)
      : super(_prefs?.getBool(SettingsKeys.developerModeEnabled) ?? false);

  void toggle() {
    state = !state;
    _prefs?.setBool(SettingsKeys.developerModeEnabled, state);
  }

  void setEnabled(bool enabled) {
    state = enabled;
    _prefs?.setBool(SettingsKeys.developerModeEnabled, enabled);
  }
}

/// Provider for notifications enabled setting
final notificationsEnabledProvider =
    StateNotifierProvider<NotificationsEnabledNotifier, bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return NotificationsEnabledNotifier(prefs.valueOrNull);
});

class NotificationsEnabledNotifier extends StateNotifier<bool> {
  final SharedPreferences? _prefs;

  NotificationsEnabledNotifier(this._prefs)
      : super(_prefs?.getBool(SettingsKeys.notificationsEnabled) ?? true);

  void toggle() {
    state = !state;
    _prefs?.setBool(SettingsKeys.notificationsEnabled, state);
  }

  void setEnabled(bool enabled) {
    state = enabled;
    _prefs?.setBool(SettingsKeys.notificationsEnabled, enabled);
  }
}

/// Provider for auto-reconnect setting
final autoReconnectProvider =
    StateNotifierProvider<AutoReconnectNotifier, bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return AutoReconnectNotifier(prefs.valueOrNull);
});

class AutoReconnectNotifier extends StateNotifier<bool> {
  final SharedPreferences? _prefs;

  AutoReconnectNotifier(this._prefs)
      : super(_prefs?.getBool(SettingsKeys.autoReconnect) ?? true);

  void toggle() {
    state = !state;
    _prefs?.setBool(SettingsKeys.autoReconnect, state);
  }

  void setEnabled(bool enabled) {
    state = enabled;
    _prefs?.setBool(SettingsKeys.autoReconnect, enabled);
  }
}

/// Provider for auto time sync setting
final autoTimeSyncProvider =
    StateNotifierProvider<AutoTimeSyncNotifier, bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return AutoTimeSyncNotifier(prefs.valueOrNull);
});

class AutoTimeSyncNotifier extends StateNotifier<bool> {
  final SharedPreferences? _prefs;

  AutoTimeSyncNotifier(this._prefs)
      : super(_prefs?.getBool(SettingsKeys.autoTimeSync) ?? true);

  void toggle() {
    state = !state;
    _prefs?.setBool(SettingsKeys.autoTimeSync, state);
  }

  void setEnabled(bool enabled) {
    state = enabled;
    _prefs?.setBool(SettingsKeys.autoTimeSync, enabled);
  }
}

/// Provider for preferred MTU setting
final preferredMtuProvider =
    StateNotifierProvider<PreferredMtuNotifier, int>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return PreferredMtuNotifier(prefs.valueOrNull);
});

class PreferredMtuNotifier extends StateNotifier<int> {
  final SharedPreferences? _prefs;

  PreferredMtuNotifier(this._prefs)
      : super(_prefs?.getInt(SettingsKeys.preferredMtu) ?? 512);

  void setMtu(int mtu) {
    state = mtu;
    _prefs?.setInt(SettingsKeys.preferredMtu, mtu);
  }
}

/// Provider for last connected watch ID
final lastConnectedWatchIdProvider = Provider<String?>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.valueOrNull?.getString(SettingsKeys.lastConnectedWatchId);
});

/// Provider for notification filter packages
final notificationFilterPackagesProvider =
    StateNotifierProvider<NotificationFilterNotifier, List<String>>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return NotificationFilterNotifier(prefs.valueOrNull);
});

class NotificationFilterNotifier extends StateNotifier<List<String>> {
  final SharedPreferences? _prefs;

  NotificationFilterNotifier(this._prefs)
      : super(
          _prefs?.getStringList(SettingsKeys.notificationFilterPackages) ?? [],
        );

  void addPackage(String packageName) {
    if (!state.contains(packageName)) {
      state = [...state, packageName];
      _prefs?.setStringList(SettingsKeys.notificationFilterPackages, state);
    }
  }

  void removePackage(String packageName) {
    state = state.where((p) => p != packageName).toList();
    _prefs?.setStringList(SettingsKeys.notificationFilterPackages, state);
  }

  void setPackages(List<String> packages) {
    state = packages;
    _prefs?.setStringList(SettingsKeys.notificationFilterPackages, packages);
  }

  bool isFiltered(String packageName) => state.contains(packageName);
}

/// Provider for onboarding completed flag
final onboardingCompletedProvider =
    StateNotifierProvider<OnboardingCompletedNotifier, bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return OnboardingCompletedNotifier(prefs.valueOrNull);
});

class OnboardingCompletedNotifier extends StateNotifier<bool> {
  final SharedPreferences? _prefs;

  OnboardingCompletedNotifier(this._prefs)
      : super(_prefs?.getBool(SettingsKeys.onboardingCompleted) ?? false);

  void setCompleted() {
    state = true;
    _prefs?.setBool(SettingsKeys.onboardingCompleted, true);
  }

  void reset() {
    state = false;
    _prefs?.setBool(SettingsKeys.onboardingCompleted, false);
  }
}

/// Provider for keep screen on during DFU setting
final keepScreenOnDuringDfuProvider =
    StateNotifierProvider<KeepScreenOnDuringDfuNotifier, bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return KeepScreenOnDuringDfuNotifier(prefs.valueOrNull);
});

class KeepScreenOnDuringDfuNotifier extends StateNotifier<bool> {
  final SharedPreferences? _prefs;

  KeepScreenOnDuringDfuNotifier(this._prefs)
      : super(_prefs?.getBool(SettingsKeys.keepScreenOnDuringDfu) ?? true);

  void toggle() {
    state = !state;
    _prefs?.setBool(SettingsKeys.keepScreenOnDuringDfu, state);
  }

  void setEnabled(bool enabled) {
    state = enabled;
    _prefs?.setBool(SettingsKeys.keepScreenOnDuringDfu, enabled);
  }
}

/// Provider for background connection setting (FR-089 to FR-092)
/// When enabled, the app maintains a persistent BLE connection when backgrounded
final backgroundConnectionEnabledProvider =
    StateNotifierProvider<BackgroundConnectionEnabledNotifier, bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return BackgroundConnectionEnabledNotifier(prefs.valueOrNull);
});

class BackgroundConnectionEnabledNotifier extends StateNotifier<bool> {
  final SharedPreferences? _prefs;

  BackgroundConnectionEnabledNotifier(this._prefs)
      : super(_prefs?.getBool(SettingsKeys.backgroundConnectionEnabled) ?? true);

  void toggle() {
    state = !state;
    _prefs?.setBool(SettingsKeys.backgroundConnectionEnabled, state);
  }

  void setEnabled(bool enabled) {
    state = enabled;
    _prefs?.setBool(SettingsKeys.backgroundConnectionEnabled, enabled);
  }
}

/// Settings manager for batch operations
class SettingsManager {
  final SharedPreferences _prefs;

  SettingsManager(this._prefs);

  /// Update last connected watch ID
  Future<void> setLastConnectedWatchId(String watchId) async {
    await _prefs.setString(SettingsKeys.lastConnectedWatchId, watchId);
  }

  /// Clear last connected watch ID
  Future<void> clearLastConnectedWatchId() async {
    await _prefs.remove(SettingsKeys.lastConnectedWatchId);
  }

  /// Clear all settings
  Future<void> clearAll() async {
    await _prefs.clear();
  }
}

/// Provider for settings manager
final settingsManagerProvider = Provider<SettingsManager?>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final prefsValue = prefs.valueOrNull;
  if (prefsValue == null) return null;
  return SettingsManager(prefsValue);
});

// ---------------------------------------------------------------------------
// Transcription engine type
// ---------------------------------------------------------------------------

/// Which offline Whisper engine variant to use for voice memo transcription.
/// Persisted in SharedPreferences.
final transcriptionEngineTypeProvider =
    StateNotifierProvider<TranscriptionEngineTypeNotifier, TranscriptionEngineType>(
  (ref) {
    final prefs = ref.watch(sharedPreferencesProvider);
    return TranscriptionEngineTypeNotifier(prefs.valueOrNull);
  },
);

class TranscriptionEngineTypeNotifier
    extends StateNotifier<TranscriptionEngineType> {
  final SharedPreferences? _prefs;

  TranscriptionEngineTypeNotifier(this._prefs)
      : super(_parseType(_prefs?.getString(SettingsKeys.transcriptionEngineType)));

  static TranscriptionEngineType _parseType(String? value) {
    for (final type in TranscriptionEngineType.values) {
      if (value == type.name) return type;
    }
    return TranscriptionEngineType.whisperTinyEn;
  }

  void setType(TranscriptionEngineType type) {
    state = type;
    _prefs?.setString(SettingsKeys.transcriptionEngineType, type.name);
  }
}

// ---------------------------------------------------------------------------
// Local AI settings
// ---------------------------------------------------------------------------

/// Whether local AI processing of voice notes is enabled
final localAiEnabledProvider =
    StateNotifierProvider<LocalAiEnabledNotifier, bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return LocalAiEnabledNotifier(prefs.valueOrNull);
});

class LocalAiEnabledNotifier extends StateNotifier<bool> {
  final SharedPreferences? _prefs;

  LocalAiEnabledNotifier(this._prefs)
      : super(_prefs?.getBool(SettingsKeys.localAiEnabled) ?? false);

  void toggle() {
    state = !state;
    _prefs?.setBool(SettingsKeys.localAiEnabled, state);
  }

  void setEnabled(bool enabled) {
    state = enabled;
    _prefs?.setBool(SettingsKeys.localAiEnabled, enabled);
  }
}

/// Whether voice notes should be automatically AI-processed after transcription
final autoProcessVoiceNotesProvider =
    StateNotifierProvider<AutoProcessVoiceNotesNotifier, bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return AutoProcessVoiceNotesNotifier(prefs.valueOrNull);
});

class AutoProcessVoiceNotesNotifier extends StateNotifier<bool> {
  final SharedPreferences? _prefs;

  AutoProcessVoiceNotesNotifier(this._prefs)
      : super(_prefs?.getBool(SettingsKeys.autoProcessVoiceNotes) ?? true);

  void toggle() {
    state = !state;
    _prefs?.setBool(SettingsKeys.autoProcessVoiceNotes, state);
  }

  void setEnabled(bool enabled) {
    state = enabled;
    _prefs?.setBool(SettingsKeys.autoProcessVoiceNotes, enabled);
  }
}

/// Whether extracted actions (calendar events, reminders) should be automatically
/// created after AI processing, with a watch-side undo window.
final autoCreateActionsProvider =
    StateNotifierProvider<AutoCreateActionsNotifier, bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return AutoCreateActionsNotifier(prefs.valueOrNull);
});

class AutoCreateActionsNotifier extends StateNotifier<bool> {
  final SharedPreferences? _prefs;

  AutoCreateActionsNotifier(this._prefs)
      : super(_prefs?.getBool(SettingsKeys.autoCreateActions) ?? false);

  void setEnabled(bool enabled) {
    state = enabled;
    _prefs?.setBool(SettingsKeys.autoCreateActions, enabled);
  }
}

/// Currently selected local AI model id.
final selectedAiModelIdProvider =
    StateNotifierProvider<SelectedAiModelIdNotifier, String>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SelectedAiModelIdNotifier(prefs.valueOrNull);
});

class SelectedAiModelIdNotifier extends StateNotifier<String> {
  final SharedPreferences? _prefs;

  SelectedAiModelIdNotifier(this._prefs)
      : super(
          _prefs?.getString(SettingsKeys.selectedAiModelId) ??
              'qwen25_1_5b_q4_k_m',
        );

  void setModelId(String modelId) {
    state = modelId;
    _prefs?.setString(SettingsKeys.selectedAiModelId, modelId);
  }
}

/// Currently selected Android calendar id for created reminders/events.
final selectedProductivityCalendarIdProvider =
    StateNotifierProvider<SelectedProductivityCalendarIdNotifier, int?>(
  (ref) {
    final prefs = ref.watch(sharedPreferencesProvider);
    return SelectedProductivityCalendarIdNotifier(prefs.valueOrNull);
  },
);

class SelectedProductivityCalendarIdNotifier extends StateNotifier<int?> {
  final SharedPreferences? _prefs;

  SelectedProductivityCalendarIdNotifier(this._prefs)
      : super(_prefs?.getInt(SettingsKeys.selectedProductivityCalendarId));

  void setCalendarId(int? calendarId) {
    state = calendarId;
    if (calendarId == null) {
      _prefs?.remove(SettingsKeys.selectedProductivityCalendarId);
      return;
    }
    _prefs?.setInt(SettingsKeys.selectedProductivityCalendarId, calendarId);
  }
}

// ---------------------------------------------------------------------------
// GPU inference mode (iOS Metal)
// ---------------------------------------------------------------------------

/// Controls GPU usage for whisper (transcription) and fllama (LLM) on iOS.
///
/// - [GpuInferenceMode.auto]: GPU in foreground, CPU in background (default,
///   prevents Metal crashes when iOS suspends GPU access).
/// - [GpuInferenceMode.alwaysGpu]: Force Metal GPU always (faster, but risky
///   if inference runs while backgrounded).
/// - [GpuInferenceMode.alwaysCpu]: Force CPU always (safe, slower — useful
///   for benchmarking).
final gpuInferenceModeProvider =
    StateNotifierProvider<GpuInferenceModeNotifier, GpuInferenceMode>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return GpuInferenceModeNotifier(prefs.valueOrNull);
});

class GpuInferenceModeNotifier extends StateNotifier<GpuInferenceMode> {
  final SharedPreferences? _prefs;

  GpuInferenceModeNotifier(this._prefs)
      : super(_fromString(
            _prefs?.getString(SettingsKeys.gpuInferenceMode))) {
    // Sync the initial value to the lifecycle manager.
    GpuLifecycleManager.instance.setGpuMode(state);
  }

  static GpuInferenceMode _fromString(String? value) {
    switch (value) {
      case 'alwaysGpu':
        return GpuInferenceMode.alwaysGpu;
      case 'alwaysCpu':
        return GpuInferenceMode.alwaysCpu;
      default:
        return GpuInferenceMode.auto;
    }
  }

  void setMode(GpuInferenceMode mode) {
    state = mode;
    _prefs?.setString(SettingsKeys.gpuInferenceMode, mode.name);
    GpuLifecycleManager.instance.setGpuMode(mode);
  }
}

