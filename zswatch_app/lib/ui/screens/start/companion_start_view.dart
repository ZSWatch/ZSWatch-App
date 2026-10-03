import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/connection_state.dart';
import '../../../providers/companion_runtime_providers.dart';
import '../../../providers/watch_service_provider.dart';
import '../../../providers/watch_providers.dart' as database;
import '../../../providers/companion_watch_providers.dart';
import '../../../data/database/app_database.dart';
import '../../widgets/watch_config_dialog.dart';
import 'start_page_screen.dart' show SavedWatchListTile;
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

  Future<void> changeConnection(String? id) async {
    if (changingConnection) return;
    setState(() => changingConnection = true);
    try {
      final notifier = ref.read(watchNotifierProvider.notifier);
      if (id == null) {
        await notifier.disconnect();
        if (ref.read(watchNotifierProvider).hasError) {
          throw StateError('Native Stop failed');
        }
      } else {
        await ref.read(companionConnectionPermissionsProvider)();
        await notifier.connectById(id);
      }
      // Command acceptance is not readiness. Home changes only on Ready.
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not change the watch connection'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => changingConnection = false);
    }
  }

  Future<void> configureWatch(WatchEntity watch) => WatchConfigDialog.show(
    context: context,
    watch: watch,
    allowForget: false,
    onRename: ref.read(companionRenameWatchProvider),
    onForget: (id) async =>
        throw StateError('Unpairing requires native coordination'),
  );

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(companionSnapshotProvider).asData?.value;
    final watch = ref.watch(currentWatchProvider);
    final saved = ref.watch(database.allWatchesProvider);
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
                : () => changeConnection(active ? null : watch!.id),
          ),
          const SizedBox(height: 16),
          Text('Saved watches', style: Theme.of(context).textTheme.titleMedium),
          saved.when(
            data: (watches) => Column(
              children: [
                if (watches.isEmpty) const Text('No saved watches'),
                for (final item in watches)
                  SavedWatchListTile(
                    key: ValueKey(item.id),
                    watch: item,
                    isConnecting:
                        active &&
                        snapshot?.fields['address'] == item.id.toUpperCase(),
                    enabled:
                        !busy &&
                        !active &&
                        snapshot != null &&
                        isCompanionWatchAddress(item.id),
                    onTap: () => changeConnection(item.id),
                    onConfig: () => configureWatch(item),
                  ),
              ],
            ),
            loading: () => const LinearProgressIndicator(),
            error: (error, stack) => Column(
              children: [
                const Text('Saved watches are unavailable'),
                TextButton(
                  onPressed: () => ref.invalidate(database.allWatchesProvider),
                  child: const Text('Retry saved watches'),
                ),
              ],
            ),
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
