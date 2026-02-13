import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/connection.dart';
import '../data/models/connection_state.dart';
import '../data/models/watch.dart';

/// Global flag: whether the app is running in demo mode.
///
/// In demo mode, a fake "connected" state is used so that all screens
/// are navigable without real ZSWatch hardware.  No BLE operations are
/// attempted; data-dependent widgets simply show their empty / placeholder
/// states (e.g. "--" for battery, "Unknown" for firmware).
///
/// This exists primarily so Google Play Store reviewers can explore the
/// full UI without owning a ZSWatch.
final demoModeProvider = StateProvider<bool>((ref) => false);

/// Fake connection returned when demo mode is active.
const _demoConnection = Connection(
  watchId: 'demo-device',
  watchName: 'ZSWatch (Demo)',
  state: WatchConnectionState.connected,
);

/// A minimal fake [Watch] so the dashboard can render device info.
final _demoWatch = Watch(
  id: 'demo-device',
  name: 'ZSWatch (Demo)',
  firmwareVersion: 'Demo Mode',
  hardwareVersion: 'Demo Mode',
  createdAt: DateTime(2025, 1, 1),
);

/// Returns [_demoConnection] when demo mode is on, otherwise `null`.
Connection? demoConnectionOrNull(Ref ref) {
  final demo = ref.watch(demoModeProvider);
  return demo ? _demoConnection : null;
}

/// Returns [_demoWatch] when demo mode is on, otherwise `null`.
Watch? demoWatchOrNull(Ref ref) {
  final demo = ref.watch(demoModeProvider);
  return demo ? _demoWatch : null;
}
