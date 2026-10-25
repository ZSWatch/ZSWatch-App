import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../providers/permission_providers.dart';
import '../../navigation/app_router.dart';
import '../settings/companion_permissions_summary.dart';

/// Shared first-run setup. All permission requests remain explicit user actions
/// and use the native companion, without initializing a second BLE owner.
class CompanionOnboardingScreen extends ConsumerStatefulWidget {
  const CompanionOnboardingScreen({super.key});

  @override
  ConsumerState<CompanionOnboardingScreen> createState() =>
      _CompanionOnboardingScreenState();
}

class _CompanionOnboardingScreenState
    extends ConsumerState<CompanionOnboardingScreen> {
  bool saving = false;

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
    return Scaffold(
      appBar: AppBar(title: const Text('Welcome to ZSWatch')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Set up your watch',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          const Text(
            'Bluetooth connects your watch. Choose the other permissions for '
            'the features you want. You can change them later in Settings.',
          ),
          const SizedBox(height: 16),
          const CompanionPermissionsSummary(initiallyExpanded: true),
          if (isIos)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'After pairing, allow Share System Notifications for your watch '
                'in iPhone Bluetooth settings. iOS does not support replying '
                'to notifications from the watch.',
              ),
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('Set up notifications'),
            subtitle: Text(
              isIos
                  ? 'Check notification sharing for your watch.'
                  : 'Enable forwarding to your watch. All apps are included '
                        'unless you turn an app off.',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.notifications),
          ),
          ListTile(
            leading: const Icon(Icons.mic),
            title: const Text('Set up voice notes'),
            subtitle: Text(
              'Add an OpenRouter key for cloud transcription, or choose '
              'on-device processing and download a speech model. '
              '${isIos ? '' : 'Dictated replies work without automatic voice-note processing. '}'
              'After connecting your watch, you can also enable automatic '
              'processing and analysis of ordinary voice notes.',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.aiModels),
          ),
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
