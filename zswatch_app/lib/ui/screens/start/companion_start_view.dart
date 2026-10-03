import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/connection_state.dart';
import '../../../providers/companion_runtime_providers.dart';
import '../../../providers/watch_service_provider.dart';
import '../../navigation/app_router.dart';

/// Reattach without restarting a deliberately stopped owner or using the
/// legacy last-watch/auto-reconnect preferences.
class CompanionStartView extends ConsumerStatefulWidget {
  const CompanionStartView({super.key});

  @override
  ConsumerState<CompanionStartView> createState() => _CompanionStartViewState();
}

class _CompanionStartViewState extends ConsumerState<CompanionStartView> {
  bool changingConnection = false;

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(companionSnapshotProvider).asData?.value;
    final watch = snapshot?.watch;
    final active = snapshot?.runtimeActive == true;
    final busy =
        changingConnection || ref.watch(watchNotifierProvider).isLoading;
    return Scaffold(
      appBar: AppBar(
        title: SvgPicture.asset('assets/images/ZSWatch_Text.svg', height: 24),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings),
            onPressed: () => context.push(AppRoutes.settings),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            watch?.displayName ?? 'Connect your watch',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          if (watch != null) Text(watch.id),
          const SizedBox(height: 16),
          if (active) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 16),
            Text(snapshot!.connection.state.statusText),
          ] else
            const Text('Watch disconnected'),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: Icon(active ? Icons.close : Icons.bluetooth),
            label: Text(active ? 'Cancel connection' : 'Connect'),
            onPressed: busy || snapshot == null || (!active && watch == null)
                ? null
                : () async {
                    setState(() => changingConnection = true);
                    try {
                      final notifier = ref.read(watchNotifierProvider.notifier);
                      if (active) {
                        await notifier.disconnect();
                        if (ref.read(watchNotifierProvider).hasError) {
                          throw StateError('Native Stop failed');
                        }
                      } else {
                        await ref.read(
                          companionConnectionPermissionsProvider,
                        )();
                        await notifier.connectById(watch!.id);
                      }
                      // An accepted Start is not Ready. The shared snapshot changes
                      // the home page only after protocol readiness.
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Could not change the watch connection',
                            ),
                          ),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => changingConnection = false);
                    }
                  },
          ),
          OutlinedButton(
            onPressed: () => context.push(AppRoutes.companionRuntime),
            child: const Text('Connection setup'),
          ),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('Notifications'),
            onTap: () => context.push(AppRoutes.notifications),
          ),
          ListTile(
            leading: const Icon(Icons.mic),
            title: const Text('Voice notes'),
            onTap: () => context.push(AppRoutes.voiceMemos),
          ),
        ],
      ),
    );
  }
}
