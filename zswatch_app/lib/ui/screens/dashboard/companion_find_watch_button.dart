import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/companion_runtime_providers.dart';

/// Only the explicit action crosses the bridge; the native service owns timing.
class CompanionFindWatchButton extends ConsumerStatefulWidget {
  const CompanionFindWatchButton({super.key, this.builder});

  /// Builds the button in the caller's style; an outlined button otherwise.
  final Widget Function(VoidCallback? onPressed)? builder;

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
    final onPressed = ready && !busy ? () => find(snapshot!.generation) : null;
    return widget.builder?.call(onPressed) ??
        OutlinedButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.vibration, size: 18),
          label: const Text('Find watch'),
        );
  }
}
