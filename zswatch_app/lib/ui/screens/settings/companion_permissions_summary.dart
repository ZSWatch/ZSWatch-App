import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/theme/app_theme.dart';
import '../../../providers/companion_runtime_providers.dart';
import 'location_permission_guidance.dart';

final companionPermissionsStatusProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(companionClientProvider).permissionStatus();
});

/// Read-only on entry; permission prompts happen only after an explicit tap.
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
    with WidgetsBindingObserver {
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

  Widget permission(
    Map<String, bool> status,
    String key,
    String title,
    String description,
    Future<void> Function() action,
  ) {
    return ListTile(
      title: Text(title),
      subtitle: Text(
        '${status[key] == true ? 'Granted' : 'Not granted'} · $description',
      ),
      trailing: Icon(
        status[key] == true ? Icons.check_circle : Icons.open_in_new,
        color: status[key] == true ? AppTheme.successColor : null,
      ),
      onTap: busy ? null : () => request(action),
    );
  }

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
              permission(
                status,
                'bluetooth',
                'Bluetooth connection',
                'Communicate with your watch',
                ref.read(companionConnectionPermissionsProvider),
              ),
              permission(
                status,
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
                permission(
                  status,
                  'notification_access',
                  'Notification access',
                  'Forward phone notifications',
                  () async {
                    await ref
                        .read(companionClientProvider)
                        .notificationDiagnostic(requestAccess: true);
                  },
                ),
              permission(
                status,
                'background_location',
                'Location',
                status['background_location'] == true
                    ? 'Weather and GPS, including while the app is closed'
                    : status['location'] == true
                    ? 'While using app only · Choose ${isIos ? 'Always' : 'Allow all the time'} for background weather and GPS'
                    : 'Weather and GPS · Requires ${isIos ? 'Always' : 'Allow all the time'} access',
                () async {
                  if (await showLocationPermissionGuidance(context) != true) {
                    return;
                  }
                  await ref.read(companionGpsPermissionsProvider)();
                },
              ),
              if (!isIos)
                permission(
                  status,
                  'battery_exemption',
                  'Battery optimization',
                  'Allow background operation',
                  () async {
                    await Permission.ignoreBatteryOptimizations.request();
                  },
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
