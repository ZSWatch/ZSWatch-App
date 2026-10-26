import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../providers/companion_permission_setup_providers.dart';
import 'companion_permissions.dart';

/// Permission prompts happen only after an explicit tap. Granted location
/// consent activates sharing once, while preserving later switch choices.
class CompanionPermissionsSummary extends ConsumerStatefulWidget {
  const CompanionPermissionsSummary({
    super.key,
    this.initiallyExpanded = false,
  });

  final bool initiallyExpanded;

  @override
  ConsumerState<CompanionPermissionsSummary> createState() =>
      _PermissionsState();
}

class _PermissionsState extends ConsumerState<CompanionPermissionsSummary>
    with WidgetsBindingObserver, CompanionPermissionRequests {
  @override
  Widget build(BuildContext context) {
    final isIos = defaultTargetPlatform == TargetPlatform.iOS;
    return ref
        .watch(companionPermissionsStatusProvider)
        .when(
          data: (status) => ExpansionTile(
            initiallyExpanded: widget.initiallyExpanded,
            leading: const Icon(Icons.security),
            title: const Text('App Permissions'),
            subtitle: Text(
              isIos
                  ? 'Bluetooth, notifications and location'
                  : '${['bluetooth', 'notifications', 'notification_access', 'background_location', 'battery_exemption'].where((key) => status[key] == true).length} of 5 granted',
            ),
            children: [
              for (final p in companionPermissions(context, ref, status))
                CompanionPermissionTile(
                  permission: p,
                  granted: status[p.key] == true,
                  onAllow: busy ? null : () => request(p.request),
                ),
              ListTile(
                title: Text(
                  isIos
                      ? 'Open iPhone app settings'
                      : 'Open Android app settings',
                ),
                trailing: const Icon(Icons.open_in_new),
                onTap: busy
                    ? null
                    : () => request(() async {
                        await openAppSettings();
                      }),
              ),
              if (busy) const LinearProgressIndicator(),
            ],
          ),
          loading: () => const ListTile(
            title: Text('App Permissions'),
            subtitle: Text('Checking permissions…'),
          ),
          error: (_, _) => ListTile(
            title: const Text('App Permissions'),
            subtitle: const Text('Could not check permissions'),
            trailing: const Icon(Icons.refresh),
            onTap: () => ref.invalidate(companionPermissionsStatusProvider),
          ),
        );
  }
}
