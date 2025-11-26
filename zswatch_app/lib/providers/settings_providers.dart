import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

