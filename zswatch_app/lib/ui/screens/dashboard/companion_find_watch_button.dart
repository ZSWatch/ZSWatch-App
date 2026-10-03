import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/companion_runtime_providers.dart';

/// Only the explicit action crosses the bridge; the native service owns timing.
class CompanionFindWatchButton extends ConsumerStatefulWidget {
  const CompanionFindWatchButton({super.key});

  @override
  ConsumerState<CompanionFindWatchButton> createState() => _FindWatchState();
}

class _FindWatchState extends ConsumerState<CompanionFindWatchButton> {
  bool busy = false;

  Future<void> find(int generation) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await ref.read(companionClientProvider).findWatch(generation);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not start finding watch. Wait a moment or reconnect and try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(companionSnapshotProvider).asData?.value;
    final ready =
        snapshot?.runtimeActive == true && snapshot?.protocolReady == true;
    return OutlinedButton.icon(
      onPressed: ready && !busy ? () => find(snapshot!.generation) : null,
      icon: const Icon(Icons.vibration),
      label: const Text('Find watch'),
    );
  }
}
