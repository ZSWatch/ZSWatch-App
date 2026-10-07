import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/connection_state.dart';
import '../../../providers/companion_runtime_providers.dart';
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
          title: const Text('Watch connection'),
          subtitle: Text(connection.state.statusText),
          onTap: () => context.push(AppRoutes.savedWatches),
        ),
        if (snapshot?.runtimeActive == true)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'The connection runs in the background. Disconnect to stop it.',
            ),
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
