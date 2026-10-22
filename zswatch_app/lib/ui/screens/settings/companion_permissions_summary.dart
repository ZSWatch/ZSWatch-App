import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import 'companion_permissions.dart';

/// Read-only on entry; permission prompts happen only after an explicit tap.
class CompanionPermissionsSummary extends ConsumerStatefulWidget {
  const CompanionPermissionsSummary({super.key});

  @override
  ConsumerState<CompanionPermissionsSummary> createState() =>
      _PermissionsState();
}

class _PermissionsState extends ConsumerState<CompanionPermissionsSummary>
    with WidgetsBindingObserver, CompanionPermissionRequests {
  Widget permission(Map<String, bool> status, CompanionPermission permission) {
    final granted = status[permission.key] == true;
    return ListTile(
      title: Text(permission.title),
      subtitle: Text(
        '${granted ? 'Granted' : 'Not granted'} · ${permission.description}',
      ),
      trailing: Icon(granted ? Icons.check_circle_outline : Icons.open_in_new),
      onTap: busy ? null : () => request(() => permission.request(ref)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isIos = defaultTargetPlatform == TargetPlatform.iOS;
    return ref
        .watch(companionPermissionsStatusProvider)
        .when(
          data: (status) => ExpansionTile(
            leading: const Icon(Icons.security),
            title: const Text('App Permissions'),
            subtitle: Text(
              isIos
                  ? 'Bluetooth, notifications and location'
                  : '${status.values.where((v) => v).length} of ${status.length} granted',
            ),
            children: [
              for (final p in companionPermissions()) permission(status, p),
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
