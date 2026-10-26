import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../providers/permission_providers.dart';
import '../../navigation/app_router.dart';
import '../../../providers/companion_permission_setup_providers.dart';
import '../settings/companion_permissions.dart';

/// Shared first-run setup. All permission requests remain explicit user actions
/// and use the native companion, without initializing a second BLE owner.
class CompanionOnboardingScreen extends ConsumerStatefulWidget {
  const CompanionOnboardingScreen({super.key});

  @override
  ConsumerState<CompanionOnboardingScreen> createState() =>
      _CompanionOnboardingScreenState();
}

class _CompanionOnboardingScreenState
    extends ConsumerState<CompanionOnboardingScreen>
    with WidgetsBindingObserver, CompanionPermissionRequests {
  /// Bluetooth is asked for when adding a watch; battery stays in Settings.
  /// Location first: it needs the most explanation.
  static const _setupKeys = [
    'background_location',
    'notifications',
    'notification_access',
  ];

  bool saving = false;

  // Rows stay after being granted, so the list doesn't jump.
  Set<String>? _shown;

  Future<void> complete() async {
    setState(() => saving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setBool(permissionOnboardingCompletedKey, true)) {
        throw StateError('Could not save setup');
      }
      ref.invalidate(permissionOnboardingCompletedProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save setup. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIos = defaultTargetPlatform == TargetPlatform.iOS;
    final status = ref.watch(companionPermissionsStatusProvider).valueOrNull;
    if (status != null) {
      _shown ??= {
        for (final key in _setupKeys)
          if (status[key] != true) key,
      };
    }
    final permissions = {
      if (status != null)
        for (final p in companionPermissions(context, ref, status)) p.key: p,
    };
    final rows = [
      for (final key in _setupKeys)
        if (_shown?.contains(key) == true && permissions[key] != null)
          permissions[key]!,
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Welcome to ZSWatch')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'These permissions let the app do more for your watch. You can '
            'change them later in Settings.',
          ),
          const SizedBox(height: 16),
          for (final p in rows)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: CompanionPermissionTile(
                permission: p,
                granted: status?[p.key] == true,
                onAllow: busy ? null : () => request(p.request),
              ),
            ),
          if (isIos)
            const Card(
              margin: EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: Icon(Icons.notifications_none),
                title: Text('Watch notifications'),
                subtitle: Text(
                  'After pairing, turn on Share System Notifications for '
                  'your watch in iPhone Bluetooth settings.',
                ),
              ),
            ),
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: const Icon(Icons.mic_none),
              title: const Text('Voice notes and Chat'),
              subtitle: const Text(
                'Transcribe voice notes and answer questions from your watch. '
                'Tap to set up.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.aiModels),
            ),
          ),
          if (busy) const LinearProgressIndicator(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton(
          onPressed: saving ? null : complete,
          child: const Text('Continue to watch setup'),
        ),
      ),
    );
  }
}
