import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/theme/app_theme.dart';
import '../../../providers/companion_permission_setup_providers.dart';
import '../../../providers/companion_runtime_providers.dart';
import '../../../providers/foreground_service_providers.dart';
import 'location_permission_guidance.dart';

class CompanionPermission {
  const CompanionPermission(
    this.key,
    this.title,
    this.description,
    this.request,
  );

  /// Key in the native `permissionStatus` reply.
  final String key;
  final String title;
  final String description;
  final Future<void> Function() request;
}

/// Every permission the app uses, in Settings order. Setup shows a subset.
List<CompanionPermission> companionPermissions(
  BuildContext context,
  WidgetRef ref,
  Map<String, bool> status,
) {
  final isIos = defaultTargetPlatform == TargetPlatform.iOS;
  return [
    CompanionPermission(
      'bluetooth',
      'Bluetooth connection',
      'Communicate with your watch',
      ref.read(companionConnectionPermissionsProvider),
    ),
    CompanionPermission(
      'notifications',
      'App notifications',
      isIos
          ? 'Timers, alarms and app alerts'
          : 'Background connection indicator',
      () async {
        final result = await Permission.notification.request();
        if (!result.isGranted) await openAppSettings();
      },
    ),
    if (!isIos)
      CompanionPermission(
        'notification_access',
        'Notification access',
        'Forward phone notifications to your watch',
        () => ref
            .read(companionClientProvider)
            .notificationDiagnostic(requestAccess: true),
      ),
    CompanionPermission(
      'background_location',
      'Location',
      status['background_location'] != true && status['location'] == true
          ? 'While using app only · Choose ${isIos ? 'Always' : 'Allow all the time'} for background weather and GPS'
          : locationDisclosure,
      () async {
        if (await showLocationPermissionGuidance(context) != true) return;
        await ref.read(companionGpsPermissionsProvider)();
      },
    ),
    if (!isIos)
      CompanionPermission(
        'battery_exemption',
        'Battery optimization',
        'Allow background operation',
        // Play restricts the direct exemption request.
        () => ref
            .read(foregroundServiceProvider)
            .openBatteryOptimizationSettings(),
      ),
  ];
}

/// One permission row, used by Settings and first-run setup.
class CompanionPermissionTile extends StatelessWidget {
  const CompanionPermissionTile({
    super.key,
    required this.permission,
    required this.granted,
    this.onAllow,
  });

  final CompanionPermission permission;
  final bool granted;
  final VoidCallback? onAllow;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(permission.title),
      subtitle: Text(permission.description),
      trailing: granted
          ? const Icon(Icons.check_circle, color: AppTheme.successColor)
          : FilledButton.tonal(onPressed: onAllow, child: const Text('Allow')),
    );
  }
}

/// Runs permission requests one at a time and re-reads the status after
/// each request and when the user comes back from system settings.
mixin CompanionPermissionRequests<T extends ConsumerStatefulWidget>
    on ConsumerState<T>, WidgetsBindingObserver {
  bool busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(companionPermissionsStatusProvider);
    }
  }

  Future<void> request(Future<void> Function() action) async {
    setState(() => busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Permission setup incomplete. $error'),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () => openAppSettings(),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
        ref.invalidate(companionPermissionsStatusProvider);
      }
    }
  }
}
