import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/connection.dart';
import '../data/models/connection_state.dart';
import '../data/models/watch.dart';
import '../data/models/companion_firmware_status.dart';
import '../services/background/companion_prototype_client.dart';
import 'companion_runtime_providers.dart';

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
final demoModeBusyProvider = StateProvider<bool>((ref) => false);
final demoModeControllerProvider = Provider<DemoModeController>(
  (ref) => DemoModeController(ref),
);

class DemoModeController {
  final Ref ref;
  CompanionPrototypeClient? _realClient;
  String? _resume;
  DemoModeController(this.ref);
  Future<void> set(bool enabled) async {
    if (ref.read(demoModeProvider) == enabled ||
        ref.read(demoModeBusyProvider)) {
      return;
    }
    ref.read(demoModeBusyProvider.notifier).state = true;
    try {
      if (!ref.read(nativeCompanionRuntimeProvider)) {
        ref.read(demoModeProvider.notifier).state = enabled;
        return;
      }
      if (enabled) {
        final client = ref.read(companionClientProvider);
        final before = await client.snapshot();
        if (CompanionFirmwareStatus.decode(before.fields)?.busy == true) {
          throw StateError(
            'Finish the firmware update before entering Demo Mode',
          );
        }
        await client.command(
          'stop',
        ); // Persist Stop before installing synthetic observers.
        _realClient = client;
        _resume =
            before.runtimeActive &&
                (before.fields['address'] as String? ?? '').isNotEmpty
            ? before.fields['address'] as String
            : null;
        ref.read(demoModeProvider.notifier).state = true;
      } else {
        final client = _realClient, address = _resume;
        _realClient = null;
        _resume = null;
        ref.read(demoModeProvider.notifier).state = false;
        if (client != null && address != null) await client.start(address);
      }
    } finally {
      ref.read(demoModeBusyProvider.notifier).state = false;
    }
  }
}

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
