import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../data/models/companion_watch_selection.dart';
import '../../../providers/companion_runtime_providers.dart';
import '../../../services/background/companion_prototype_client.dart';
import '../../navigation/app_router.dart';

/// Flutter retains the Add Watch route; each native owner performs discovery.
class CompanionScanView extends ConsumerStatefulWidget {
  const CompanionScanView({super.key});

  @override
  ConsumerState<CompanionScanView> createState() => _CompanionScanViewState();
}

class _CompanionScanViewState extends ConsumerState<CompanionScanView> {
  bool busy = false;
  String? error;
  bool permissionDenied = false;
  CompanionPrototypeClient? scanningClient;
  bool get isIos => defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void dispose() {
    final client = scanningClient;
    if (client != null) unawaited(_stopScan(client));
    super.dispose();
  }

  Future<void> _stopScan(CompanionPrototypeClient client) async {
    try {
      await client.scan(start: false);
    } catch (_) {
      /* Native scan also expires. */
    }
  }

  Future<void> findWatch() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
      permissionDenied = false;
    });
    try {
      await ref.read(companionConnectionPermissionsProvider)();
      if (!mounted) return;
      final client = ref.read(companionClientProvider);
      final systemSetup =
          ref
              .read(companionSnapshotProvider)
              .asData
              ?.value
              .fields['accessory_setup_available'] ==
          true;
      if (isIos && !systemSetup) {
        scanningClient = client;
        await client.scan(start: true);
      } else {
        final selected = await client.discoverWatch();
        if (!mounted) return;
        await client.startDiscovered(selected);
        if (mounted) context.go(AppRoutes.home);
      }
    } on PlatformException catch (failure) {
      if (mounted && failure.code != 'CANCELLED') {
        setState(() {
          permissionDenied = isIos && failure.code == 'BLUETOOTH_PERMISSION';
          error = isIos || failure.code == 'BLUETOOTH_OFF'
              ? failure.message ?? 'Could not find or connect to your watch'
              : 'Could not find or connect to your watch';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not find or connect to your watch');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> choose(Map<Object?, Object?> row, int generation) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final selection = CompanionWatchSelection.decode({
        'version': 1,
        'platform': 'ios',
        'selected': true,
        'address': row['address'],
        'generation': generation,
      });
      await ref.read(companionClientProvider).startDiscovered(selection);
      if (mounted) context.go(AppRoutes.home);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not connect. Find your watch again.');
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
    final scanning = snapshot?.fields['scan_active'] == true;
    final results = snapshot?.fields['scan_results'];
    return Scaffold(
      appBar: AppBar(title: const Text('Add Watch')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.watch, size: 64),
          const SizedBox(height: 24),
          Text(
            isIos
                ? 'On ZSWatch, open Settings > Bluetooth > Pairable > Enable. Keep it nearby, tap Find watch, and complete setup on your iPhone.'
                : 'Keep your ZSWatch nearby and enable Bluetooth on your phone. Choose your watch in the Android dialog to connect.',
          ),
          const SizedBox(height: 24),
          if (busy || scanning) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              isIos
                  ? 'Finding nearby watches…'
                  : 'Choose your watch in the Android dialog…',
            ),
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
            onPressed: stopped && !busy && !scanning ? findWatch : null,
            icon: const Icon(Icons.search),
            label: const Text('Find watch'),
          ),
          if (isIos && results is List)
            for (final row in results.whereType<Map<Object?, Object?>>())
              ListTile(
                leading: const Icon(Icons.watch),
                title: Text(row['name'] as String? ?? 'ZSWatch'),
                subtitle: Text('${row['address']}'),
                onTap: stopped && !busy
                    ? () => choose(row, snapshot.generation)
                    : null,
              ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (permissionDenied)
            OutlinedButton(
              onPressed: () async {
                final opened = await openAppSettings();
                if (!opened && mounted) {
                  setState(
                    () => error =
                        'Open iPhone Settings and allow '
                        'Bluetooth access for ZSWatch.',
                  );
                }
              },
              child: const Text('Open iPhone Settings'),
            ),
        ],
      ),
    );
  }
}
