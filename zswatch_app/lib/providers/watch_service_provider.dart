import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/connection.dart';
import '../data/models/connection_phase.dart';
import '../data/models/connection_state.dart';
import '../data/models/crash_summary.dart';
import '../data/models/watch.dart';
import '../data/database/app_database.dart' show WatchEntity;

import '../services/background/companion_prototype_client.dart';

import 'base_async_notifier.dart';
import 'companion_runtime_providers.dart';
import 'demo_mode_provider.dart';
import 'watch_providers.dart';

/// Provider for connection phase stream (primary state).
final connectionPhaseStreamProvider = StreamProvider<ConnectionPhase>((ref) {
  return companionValues(ref, (s) => s.connectionPhase);
});

/// Provider for current connection phase.
final connectionPhaseProvider = Provider<ConnectionPhase>((ref) {
  if (ref.watch(demoModeProvider)) return const ConnectionPhase.connected();

  return ref.watch(companionSnapshotProvider).asData?.value.connectionPhase ??
      const ConnectionPhase.disconnected();
});

/// Provider for connection state stream (backwards compat Connection model).
final watchConnectionStreamProvider = StreamProvider<Connection>((ref) {
  return companionValues(ref, (s) => s.connection);
});

/// Provider for current connection (non-stream).
///
/// In demo mode, returns a fake "connected" connection so all screens
/// are accessible without real hardware.
final watchConnectionProvider = Provider<Connection>((ref) {
  final demo = demoConnectionOrNull(ref);
  if (demo != null) return demo;

  return ref.watch(companionSnapshotProvider).asData?.value.connection ??
      const Connection(watchId: '', state: WatchConnectionState.disconnected);
});

/// Provider for whether watch is connected.
final isWatchConnectedProvider = Provider<bool>((ref) {
  final connection = ref.watch(watchConnectionProvider);
  return connection.state == WatchConnectionState.connected;
});

/// Provider for connection state enum.
final watchConnectionStateProvider = Provider<WatchConnectionState>((ref) {
  final connection = ref.watch(watchConnectionProvider);
  return connection.state;
});

/// Provider for watch info stream.
final watchInfoStreamProvider = StreamProvider<Watch?>((ref) {
  return companionValues(ref, (s) => s.watch);
});

/// Provider for current watch info - merges live service data with database data.
///
/// In demo mode, returns a static placeholder watch.
final currentWatchProvider = Provider<Watch?>((ref) {
  final demo = demoWatchOrNull(ref);
  if (demo != null) return demo;

  final live = ref.watch(companionSnapshotProvider).asData?.value.watch;
  if (live == null) return null;
  final saved = ref.watch(allWatchesProvider).asData?.value ?? <WatchEntity>[];
  // Preserve Android MAC spelling in Drift. Do not pick an arbitrary name
  // if old rows have ambiguous aliases for one physical watch.
  final exact = saved.where((w) => w.id == live.id).toList();
  final matches = exact.isNotEmpty
      ? exact
      : saved
            .where((w) => w.id.toUpperCase() == live.id.toUpperCase())
            .toList();
  if (matches.length != 1) return live;
  final metadata = matches.single;
  return live.copyWith(
    name: metadata.name,
    customName: metadata.customName,
    isPrimary: metadata.isPrimary,
    createdAt: metadata.createdAt,
    lastConnectedAt: metadata.lastConnectedAt,
  );
});

/// Provider for current watch (non-null when connected).
final connectedWatchProvider = Provider<Watch?>((ref) {
  final isConnected = ref.watch(isWatchConnectedProvider);
  if (!isConnected) return null;
  return ref.watch(currentWatchProvider);
});

/// Provider for battery level stream.
final batteryLevelStreamProvider = StreamProvider<int>((ref) {
  return companionValues<int?>(
    ref,
    (s) => s.hasLiveStatus ? s.watch?.batteryLevel : null,
  ).where((level) => level != null).cast<int>();
});

/// Provider for current battery level.
final batteryLevelProvider = Provider<int?>((ref) {
  final snapshot = ref.watch(companionSnapshotProvider).asData?.value;
  return snapshot?.hasLiveStatus == true ? snapshot?.watch?.batteryLevel : null;
});

/// Provider for whether the connected watch has the SMP service available.
final hasSmpServiceProvider = Provider<bool>((ref) {
  final state = ref.watch(companionSnapshotProvider).asData?.value;
  return state?.protocolReady == true &&
      (state?.fields['capabilities'] as Map?)?['smp'] == true;
});

/// Provider for crash summary stream (null if no crash available).
final crashSummaryStreamProvider = StreamProvider<CrashSummary?>((ref) {
  // Reuse the app's one snapshot subscription. Only crash/identity changes
  // restart this projection; battery/status traffic must not resave history.
  ref.watch(
    companionSnapshotProvider.select((snapshot) {
      final value = snapshot.valueOrNull;
      final crash = value?.crashSummary;
      return crash == null
          ? null
          : (
              value?.fields['address'],
              crash.file,
              crash.line,
              crash.time,
              crash.fwVersion,
              crash.fwCommitSha,
              crash.board,
              crash.buildType,
            );
    }),
  );
  return Stream.value(
    ref.read(companionSnapshotProvider).valueOrNull?.crashSummary,
  );
});

/// Provider for current crash summary.
final crashSummaryProvider = Provider<CrashSummary?>((ref) {
  final asyncValue = ref.watch(crashSummaryStreamProvider);
  return asyncValue.valueOrNull;
});

/// Whether to show the crash indicator on the dashboard.
final showCrashIndicatorProvider = StateProvider<bool>((ref) {
  final summary = ref.watch(crashSummaryProvider);
  return summary != null;
});

/// Notifier for watch operations.
class WatchNotifier extends BaseAsyncNotifier {
  final CompanionPrototypeClient _client;
  WatchNotifier.native(this._client);

  Future<void> connectById(String deviceId) =>
      run(() => _client.start(deviceId), rethrowError: true);
  Future<void> disconnect() => run(() => _client.command('stop'));
  Future<void> requestDeviceInfo() async {
    try {
      await _client.command('requestDeviceInfo');
    } catch (_) {
      /* Non-fatal. */
    }
  }

  Future<void> syncTime() async {
    try {
      await _client.command('syncTime');
    } catch (_) {
      /* Non-fatal. */
    }
  }
}

final watchNotifierProvider =
    StateNotifierProvider<WatchNotifier, AsyncValue<void>>((ref) {
      return WatchNotifier.native(ref.watch(companionClientProvider));
    });
