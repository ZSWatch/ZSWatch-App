import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/background/companion_prototype_client.dart';
import 'companion_runtime_providers.dart';
import 'settings_providers.dart';
import 'demo_mode_provider.dart';

final companionPermissionsStatusProvider = FutureProvider.autoDispose((
  ref,
) async {
  final status = await ref.watch(companionClientProvider).permissionStatus();
  if (ref.watch(demoModeProvider)) return status;
  try {
    await ref.read(companionGpsSetupProvider).enableDefaultIfGranted(status);
  } catch (error) {
    // Keep the permission overview usable if location services are off or the
    // native owner is temporarily unavailable. A later refresh retries setup.
    debugPrint('[LocationSetup] Could not enable sharing: $error');
  }
  return status;
});

final companionGpsSetupProvider = Provider<CompanionGpsSetup>((ref) {
  return CompanionGpsSetup(
    ref.read(companionClientProvider),
    () => ref.read(sharedPreferencesProvider.future),
  );
});

/// Permission consent enables sharing once. A later off choice stays off.
class CompanionGpsSetup {
  CompanionGpsSetup(this._client, this._preferences);

  final CompanionPrototypeClient _client;
  final Future<SharedPreferences> Function() _preferences;
  Future<void>? _applying;

  Future<void> enableDefaultIfGranted(Map<String, bool> permissions) {
    if (permissions['location'] != true ||
        permissions['background_location'] != true) {
      return Future<void>.value();
    }
    return _applying ??= _enableDefault().whenComplete(() => _applying = null);
  }

  Future<void> _enableDefault() async {
    final preferences = await _preferences();
    if (preferences.getBool(SettingsKeys.watchLocationDefaultApplied) == true) {
      return;
    }
    final snapshot = await _client.snapshot();
    // An explicit switch choice may have arrived while reading the owner.
    if (preferences.getBool(SettingsKeys.watchLocationDefaultApplied) == true) {
      return;
    }
    if (snapshot.fields['gps_enabled'] != true) {
      await _client.configureGps(true);
    }
    await preferences.setBool(SettingsKeys.watchLocationDefaultApplied, true);
  }

  Future<CompanionPrototypeSnapshot> configure(bool enabled) async {
    final preferences = await _preferences();
    // Record the user's choice before sending it; an overlapping permission
    // refresh must not turn sharing back on after an explicit off action.
    await preferences.setBool(SettingsKeys.watchLocationDefaultApplied, true);
    return _client.configureGps(enabled);
  }
}
