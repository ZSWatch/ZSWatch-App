import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../navigation/app_router.dart';
import 'companion_permissions.dart';

/// Preference set once the setup screen has been offered.
const permissionsSetupShownKey = 'permissionsSetupShown';

final _locationPermission = CompanionPermission(
  'background_location',
  'Location',
  'ZSWatch collects location data to send weather and GPS to your watch, even when the app is closed or not in use.',
  (ref) async {
    final whenInUse = await Permission.locationWhenInUse.request();
    if (whenInUse.isPermanentlyDenied) {
      await openAppSettings();
    } else if (whenInUse.isGranted) {
      await Permission.locationAlways.request();
    }
  },
);

/// The permissions the setup screen offers, if not granted yet.
List<CompanionPermission> companionSetupPermissions() => [
  _locationPermission,
  notificationsPermission,
  ...companionPermissions().where((p) => p.key == 'notification_access'),
];

/// Shown once after the first connection. Nothing is requested until the
/// user taps Allow.
class CompanionPermissionsSetupScreen extends ConsumerStatefulWidget {
  const CompanionPermissionsSetupScreen({super.key});

  @override
  ConsumerState<CompanionPermissionsSetupScreen> createState() => _SetupState();
}

class _SetupState extends ConsumerState<CompanionPermissionsSetupScreen>
    with WidgetsBindingObserver, CompanionPermissionRequests {
  // Rows stay after being granted, so the list doesn't jump.
  Set<String>? _shown;

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(companionPermissionsStatusProvider).valueOrNull;
    if (status != null) {
      _shown ??= {
        for (final p in companionSetupPermissions())
          if (status[p.key] != true) p.key,
      };
    }
    final rows = companionSetupPermissions().where(
      (p) => _shown?.contains(p.key) ?? false,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Set up ZSWatch')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Your watch is connected. These permissions let the app do more '
            'for it. You can change them later in Settings.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          for (final p in rows)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: CompanionPermissionTile(
                permission: p,
                granted: status?[p.key] == true,
                onAllow: busy ? null : () => request(() => p.request(ref)),
              ),
            ),
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: const Icon(Icons.mic_none),
              title: const Text('Voice memos and Chat'),
              subtitle: const Text(
                'Ask questions and create reminders with your voice. '
                'Tap to set up OpenRouter.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.aiModels),
            ),
          ),
          if (busy) const LinearProgressIndicator(),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: () => context.pop(),
            child: Text(
              rows.every((p) => status?[p.key] == true)
                  ? 'Done'
                  : 'Skip for now',
            ),
          ),
        ],
      ),
    );
  }
}
