import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/watch.dart';
import '../data/repositories/watch_repository.dart';
import '../services/ble/auto_reconnect_service.dart';
import 'base_async_notifier.dart';
import 'watch_providers.dart';
import 'watch_service_provider.dart';

// Keys for SharedPreferences
const _autoReconnectEnabledKey = 'auto_reconnect_enabled';

/// Provider for WatchRepository (for auto-reconnect).
final _watchRepositoryProvider = Provider<WatchRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return WatchRepository(db);
});

/// Provider for the AutoReconnectService.
///
/// Uses ref.read instead of ref.watch to prevent the service from being
/// recreated when connection state changes.
final autoReconnectServiceProvider = Provider<AutoReconnectService>((ref) {
  final ble = ref.read(bleConnectionServiceProvider);
  final watchRepository = ref.read(_watchRepositoryProvider);

  final service = AutoReconnectService(
    connectById: (watchId, {bool autoConnect = false}) =>
        ble.connectById(watchId, autoConnect: autoConnect),
    getLastConnectedWatch: () async {
      return watchRepository.getLastConnectedWatch();
    },
    cancelConnection: () => ble.cancelPendingConnection(),
  );

  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider for auto-reconnect state stream.
final autoReconnectStateStreamProvider = StreamProvider<AutoReconnectState>((
  ref,
) {
  final service = ref.watch(autoReconnectServiceProvider);
  return service.stateStream;
});

/// Provider for current auto-reconnect state.
final autoReconnectStateProvider = Provider<AutoReconnectState>((ref) {
  final asyncValue = ref.watch(autoReconnectStateStreamProvider);
  return asyncValue.valueOrNull ?? AutoReconnectState.idle;
});

/// Provider for whether auto-reconnect is currently in progress.
final isAutoReconnectingProvider = Provider<bool>((ref) {
  final state = ref.watch(autoReconnectStateProvider);
  return state == AutoReconnectState.waiting;
});

/// Provider for auto-reconnect target watch.
final autoReconnectTargetWatchProvider = Provider<Watch?>((ref) {
  final service = ref.watch(autoReconnectServiceProvider);
  return service.targetWatch;
});

/// Provider for whether auto-reconnect is enabled (user preference).
final autoReconnectEnabledProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_autoReconnectEnabledKey) ?? true;
});

/// Set auto-reconnect enabled preference.
Future<void> setAutoReconnectEnabled(bool enabled) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_autoReconnectEnabledKey, enabled);
}

/// Provider for last connected watch (from database).
final lastConnectedWatchProvider = FutureProvider<Watch?>((ref) async {
  final watchRepository = ref.watch(_watchRepositoryProvider);
  return watchRepository.getLastConnectedWatch();
});

/// Notifier for auto-reconnect actions.
class AutoReconnectNotifier extends BaseAsyncNotifier {
  final AutoReconnectService _service;

  AutoReconnectNotifier(this._service);

  /// Start auto-reconnect to last connected watch.
  Future<void> startAutoReconnect() => run(() => _service.startAutoReconnect());

  /// Cancel auto-reconnect (suppresses for this session).
  void cancel() {
    _service.cancel();
  }

  /// Stop auto-reconnect.
  void stop() {
    _service.stop();
  }

  /// Suppress auto-reconnect for this session.
  void suppressForSession() {
    _service.suppressForSession();
  }

  /// Set auto-reconnect enabled.
  void setEnabled(bool enabled) {
    _service.setEnabled(enabled);
  }
}

/// Provider for auto-reconnect notifier.
final autoReconnectNotifierProvider =
    StateNotifierProvider<AutoReconnectNotifier, AsyncValue<void>>((ref) {
      final service = ref.watch(autoReconnectServiceProvider);
      return AutoReconnectNotifier(service);
    });
