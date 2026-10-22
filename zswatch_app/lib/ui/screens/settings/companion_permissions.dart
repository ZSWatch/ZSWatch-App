import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/theme/app_theme.dart';
import '../../../providers/companion_runtime_providers.dart';

final companionPermissionsStatusProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(companionClientProvider).permissionStatus();
});

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
  final Future<void> Function(WidgetRef ref) request;
}

bool get _isIos => defaultTargetPlatform == TargetPlatform.iOS;

final notificationsPermission = CompanionPermission(
  'notifications',
  'App notifications',
  _isIos ? 'Timers, alarms and app alerts' : 'Background connection indicator',
  (ref) async {
    final result = await Permission.notification.request();
    if (!result.isGranted) await openAppSettings();
  },
);

final notificationAccessPermission = CompanionPermission(
  'notification_access',
  'Notification access',
  'Forward phone notifications',
  (ref) => ref
      .read(companionClientProvider)
      .notificationDiagnostic(requestAccess: true),
);

/// Settings lists every permission; the setup screen only some of them.
List<CompanionPermission> companionPermissions() => [
  CompanionPermission(
    'bluetooth',
    'Bluetooth connection',
    'Communicate with your watch',
    (ref) => ref.read(companionConnectionPermissionsProvider)(),
  ),
  notificationsPermission,
  if (!_isIos) notificationAccessPermission,
  CompanionPermission(
    'location',
    'Location',
    'Location for watch weather and GPS',
    (ref) async {
      final result = await Permission.locationWhenInUse.request();
      if (!result.isGranted) await openAppSettings();
    },
  ),
  CompanionPermission(
    'background_location',
    'Background location',
    'ZSWatch collects location data to send weather and GPS to your watch, even when the app is closed or not in use.',
    (ref) => ref.read(companionGpsPermissionsProvider)(),
  ),
  if (!_isIos)
    CompanionPermission(
      'battery_exemption',
      'Battery optimization',
      'Allow background operation',
      (ref) async {
        await Permission.ignoreBatteryOptimizations.request();
      },
    ),
];

/// One permission row, used by Settings and the setup screen.
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
          SnackBar(content: Text('Could not open permission settings: $error')),
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
