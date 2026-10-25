import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/connection_state.dart';
import '../../../providers/companion_runtime_providers.dart';
import '../../../providers/ios_telemetry_providers.dart';
import '../../../providers/watch_service_provider.dart';
import '../../navigation/app_router.dart';
import 'companion_http_settings_tile.dart';
import 'companion_gps_settings_tile.dart';

/// Existing settings use the native owner's persistent connection intent.
class CompanionConnectionSettings extends ConsumerWidget {
  const CompanionConnectionSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connection = ref.watch(watchConnectionProvider);
    final snapshot = ref.watch(companionSnapshotProvider).asData?.value;
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.bluetooth),
          title: const Text('Manage watches'),
          subtitle: Text(connection.state.statusText),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(AppRoutes.savedWatches),
        ),
        if (snapshot?.runtimeActive == true)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'The connection runs in the background. Disconnect to stop it.',
            ),
          ),
        if (snapshot?.isIos == true &&
            ref.watch(iosTelemetryProjectionStateProvider).hasError)
          ListTile(
            leading: const Icon(Icons.sync_problem),
            title: const Text('Could not save watch history'),
            subtitle: const Text(
              'Observations remain on this phone. Tap to retry.',
            ),
            onTap: snapshot == null
                ? null
                : () => ref
                      .read(iosTelemetryProjectionStateProvider.notifier)
                      .observe(snapshot),
          ),
        ListTile(
          leading: const Icon(Icons.notifications),
          title: const Text('Notifications'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(AppRoutes.notifications),
        ),
        ListTile(
          leading: const Icon(Icons.mic),
          title: const Text('Voice notes'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(AppRoutes.voiceMemos),
        ),
        const CompanionHttpSettingsTile(),
        const CompanionGpsSettingsTile(),
      ],
    );
  }
}
