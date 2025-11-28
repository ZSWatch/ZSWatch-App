import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/settings_providers.dart';

/// Repository for app settings backed by SharedPreferences
///
/// This repository provides a clean interface for accessing and modifying
/// app settings. Most individual settings are managed by their own
/// StateNotifier providers, but this repository provides batch operations
/// and direct access when needed.
class SettingsRepository {
  final SharedPreferences _prefs;

  SettingsRepository(this._prefs);

  // ============ Read Operations ============

  /// Get developer mode enabled state
  bool get developerModeEnabled =>
      _prefs.getBool(SettingsKeys.developerModeEnabled) ?? false;

  /// Get notifications enabled state
  bool get notificationsEnabled =>
      _prefs.getBool(SettingsKeys.notificationsEnabled) ?? true;

  /// Get auto-reconnect enabled state
  bool get autoReconnectEnabled =>
      _prefs.getBool(SettingsKeys.autoReconnect) ?? true;

  /// Get auto time sync enabled state
  bool get autoTimeSyncEnabled =>
      _prefs.getBool(SettingsKeys.autoTimeSync) ?? true;

  /// Get keep screen on during DFU setting
  bool get keepScreenOnDuringDfu =>
      _prefs.getBool(SettingsKeys.keepScreenOnDuringDfu) ?? true;

  /// Get preferred MTU size
  int get preferredMtu => _prefs.getInt(SettingsKeys.preferredMtu) ?? 512;

  /// Get last connected watch ID
  String? get lastConnectedWatchId =>
      _prefs.getString(SettingsKeys.lastConnectedWatchId);

  /// Get notification filter packages list
  List<String> get notificationFilterPackages =>
      _prefs.getStringList(SettingsKeys.notificationFilterPackages) ?? [];

  /// Get onboarding completed state
  bool get onboardingCompleted =>
      _prefs.getBool(SettingsKeys.onboardingCompleted) ?? false;

  // ============ Write Operations ============

  /// Set developer mode enabled
  Future<bool> setDeveloperModeEnabled(bool enabled) =>
      _prefs.setBool(SettingsKeys.developerModeEnabled, enabled);

  /// Set notifications enabled
  Future<bool> setNotificationsEnabled(bool enabled) =>
      _prefs.setBool(SettingsKeys.notificationsEnabled, enabled);

  /// Set auto-reconnect enabled
  Future<bool> setAutoReconnectEnabled(bool enabled) =>
      _prefs.setBool(SettingsKeys.autoReconnect, enabled);

  /// Set auto time sync enabled
  Future<bool> setAutoTimeSyncEnabled(bool enabled) =>
      _prefs.setBool(SettingsKeys.autoTimeSync, enabled);

  /// Set keep screen on during DFU
  Future<bool> setKeepScreenOnDuringDfu(bool enabled) =>
      _prefs.setBool(SettingsKeys.keepScreenOnDuringDfu, enabled);

  /// Set preferred MTU size
  Future<bool> setPreferredMtu(int mtu) =>
      _prefs.setInt(SettingsKeys.preferredMtu, mtu);

  /// Set last connected watch ID
  Future<bool> setLastConnectedWatchId(String watchId) =>
      _prefs.setString(SettingsKeys.lastConnectedWatchId, watchId);

  /// Clear last connected watch ID
  Future<bool> clearLastConnectedWatchId() =>
      _prefs.remove(SettingsKeys.lastConnectedWatchId);

  /// Set notification filter packages
  Future<bool> setNotificationFilterPackages(List<String> packages) =>
      _prefs.setStringList(SettingsKeys.notificationFilterPackages, packages);

  /// Set onboarding completed
  Future<bool> setOnboardingCompleted(bool completed) =>
      _prefs.setBool(SettingsKeys.onboardingCompleted, completed);

  // ============ Batch Operations ============

  /// Reset all settings to defaults
  Future<void> resetToDefaults() async {
    await _prefs.setBool(SettingsKeys.developerModeEnabled, false);
    await _prefs.setBool(SettingsKeys.notificationsEnabled, true);
    await _prefs.setBool(SettingsKeys.autoReconnect, true);
    await _prefs.setBool(SettingsKeys.autoTimeSync, true);
    await _prefs.setBool(SettingsKeys.keepScreenOnDuringDfu, true);
    await _prefs.setInt(SettingsKeys.preferredMtu, 512);
    await _prefs.remove(SettingsKeys.lastConnectedWatchId);
    await _prefs.setStringList(SettingsKeys.notificationFilterPackages, []);
    // Note: onboardingCompleted is NOT reset
  }

  /// Clear all data (for logout/reset scenarios)
  Future<bool> clearAll() => _prefs.clear();

  /// Export all settings as a map (for debugging/backup)
  Map<String, dynamic> exportSettings() {
    return {
      'developerModeEnabled': developerModeEnabled,
      'notificationsEnabled': notificationsEnabled,
      'autoReconnectEnabled': autoReconnectEnabled,
      'autoTimeSyncEnabled': autoTimeSyncEnabled,
      'keepScreenOnDuringDfu': keepScreenOnDuringDfu,
      'preferredMtu': preferredMtu,
      'lastConnectedWatchId': lastConnectedWatchId,
      'notificationFilterPackages': notificationFilterPackages,
      'onboardingCompleted': onboardingCompleted,
    };
  }
}
