import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/companion_http_status.dart';
import '../../../providers/companion_runtime_providers.dart';
import '../../../services/background/companion_prototype_client.dart';

/// Flutter edits durable native policy; it never executes watch HTTP or owns BLE.
class CompanionHttpSettingsTile extends ConsumerStatefulWidget {
  const CompanionHttpSettingsTile({super.key});

  @override
  ConsumerState<CompanionHttpSettingsTile> createState() =>
      _CompanionHttpSettingsTileState();
}

class _CompanionHttpSettingsTileState
    extends ConsumerState<CompanionHttpSettingsTile> {
  bool busy = false;
  String? error;
  CompanionPrototypeSnapshot? accepted;

  Future<void> update(bool enabled) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await ref
          .read(companionClientProvider)
          .configureHttp(enabled);
      if (mounted) setState(() => accepted = result);
    } catch (_) {
      if (mounted) setState(() => error = 'Could not update internet requests');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final observed = ref.watch(companionSnapshotProvider).asData?.value;
    final status = ref.watch(companionHttpStatusProvider);
    return status.when(
      skipLoadingOnRefresh: false,
      data: (value) {
        // The committed command may precede its EventChannel observation.
        final policy =
            observed != null &&
                accepted != null &&
                observed.cursor < accepted!.cursor
            ? CompanionHttpStatus.decode(accepted!.fields)
            : value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.public),
              title: const Text('Watch internet requests'),
              subtitle: const Text(
                'Allow the watch to fetch information using this phone. '
                'Replies already prepared may still arrive after turning this off.',
              ),
              value: policy.enabled,
              onChanged: busy ? null : update,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    !policy.enabled
                        ? 'Internet requests off'
                        : !policy.ready
                        ? 'Waiting for watch connection'
                        : policy.pendingCount > 0
                        ? '${policy.pendingCount} request(s) pending'
                        : 'Ready for watch requests',
                  ),
                  if (policy.lastOutcome != null)
                    Text(
                      'Last request: ${CompanionHttpStatus.outcomes[policy.lastOutcome]}',
                    ),
                  if (busy) const LinearProgressIndicator(),
                  if (error != null)
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
      loading: () => const ListTile(
        title: Text('Watch internet requests'),
        subtitle: Text('Loading settings…'),
      ),
      error: (_, _) => ListTile(
        title: const Text('Watch internet requests'),
        subtitle: const Text('Internet settings are unavailable'),
        trailing: IconButton(
          tooltip: 'Retry internet settings',
          icon: const Icon(Icons.refresh),
          onPressed: () => ref.invalidate(companionSnapshotProvider),
        ),
      ),
    );
  }
}
