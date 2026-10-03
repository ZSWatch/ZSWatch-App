import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/companion_runtime_providers.dart';
import '../../navigation/app_router.dart';

/// Android owns the explicit picker and BLE. Flutter owns this existing route.
class CompanionScanView extends ConsumerStatefulWidget {
  const CompanionScanView({super.key});

  @override
  ConsumerState<CompanionScanView> createState() => _CompanionScanViewState();
}

class _CompanionScanViewState extends ConsumerState<CompanionScanView> {
  bool busy = false;
  String? error;

  Future<void> findWatch() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref.read(companionConnectionPermissionsProvider)();
      if (!mounted) return;
      final client = ref.read(companionClientProvider);
      final selected = await client.discoverWatch();
      if (!mounted) return;
      await client.startDiscovered(selected);
      if (mounted) context.go(AppRoutes.home);
    } on PlatformException catch (failure) {
      if (mounted && failure.code != 'CANCELLED') {
        setState(() => error = 'Could not find or connect to your watch');
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not find or connect to your watch');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(companionSnapshotProvider);
    final snapshot = state.asData?.value;
    final stopped =
        snapshot != null &&
        !snapshot.runtimeActive &&
        snapshot.fields['desired_running'] == false;
    return Scaffold(
      appBar: AppBar(title: const Text('Add Watch')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.watch, size: 64),
            const SizedBox(height: 24),
            const Text(
              'Keep your ZSWatch nearby and enable Bluetooth on your phone. Choose your watch in the Android dialog to connect.',
            ),
            const SizedBox(height: 24),
            if (busy) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Choose your watch in the Android dialog…'),
            ] else if (state.hasError) ...[
              const Text('Watch connection status is unavailable'),
              TextButton(
                onPressed: () => ref.invalidate(companionSnapshotProvider),
                child: const Text('Retry connection status'),
              ),
            ] else if (snapshot == null)
              const LinearProgressIndicator()
            else if (!stopped)
              const Text('Disconnect your watch before adding another.'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: stopped && !busy ? findWatch : null,
              icon: const Icon(Icons.search),
              label: const Text('Find watch'),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
