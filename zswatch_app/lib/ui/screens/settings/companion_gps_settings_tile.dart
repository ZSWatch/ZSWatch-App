import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../data/models/companion_gps_status.dart';
import '../../../providers/companion_runtime_providers.dart';
import '../../../providers/companion_permission_setup_providers.dart';
import '../../../services/background/companion_prototype_client.dart';
import 'location_permission_guidance.dart';

class CompanionGpsSettingsTile extends ConsumerStatefulWidget {
  const CompanionGpsSettingsTile({super.key});
  @override
  ConsumerState<CompanionGpsSettingsTile> createState() =>
      _CompanionGpsSettingsTileState();
}

class _CompanionGpsSettingsTileState
    extends ConsumerState<CompanionGpsSettingsTile>
    with WidgetsBindingObserver {
  bool busy = false;
  String? error;
  CompanionPrototypeSnapshot? accepted;

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
      ref.invalidate(companionSnapshotProvider);
    }
  }

  Future<void> update(bool enabled) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (enabled) {
        final confirmed = await showLocationPermissionGuidance(context);
        if (confirmed != true) return;
        await ref.read(companionGpsPermissionsProvider)();
      }
      final snapshot = await ref
          .read(companionGpsSetupProvider)
          .configure(enabled);
      if (mounted) setState(() => accepted = snapshot);
    } catch (_) {
      if (mounted) {
        setState(
          () => error = enabled
              ? defaultTargetPlatform == TargetPlatform.iOS
                    ? 'Allow location access and turn on iPhone Location Services, then try again.'
                    : 'Allow location all the time and turn on phone location services, then try again.'
              : 'Could not turn off location sharing',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final observed = ref.watch(companionSnapshotProvider).asData?.value;
    return ref
        .watch(companionGpsStatusProvider)
        .when(
          skipLoadingOnRefresh: false,
          data: (value) {
            final policy =
                observed != null &&
                    accepted != null &&
                    observed.cursor < accepted!.cursor
                ? CompanionGpsStatus.decode(accepted!.fields)
                : value;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  leading: const Icon(Icons.location_on),
                  title: const Text('Watch location'),
                  subtitle: Text(policy.description),
                  trailing: Semantics(
                    label: 'Share location with watch',
                    child: Switch(
                      key: const ValueKey('companion-gps-switch'),
                      value: policy.enabled,
                      onChanged: busy ? null : update,
                    ),
                  ),
                ),
                if (busy) const LinearProgressIndicator(),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        TextButton(
                          onPressed: () => openAppSettings(),
                          child: Text(
                            defaultTargetPlatform == TargetPlatform.iOS
                                ? 'iPhone app permissions'
                                : 'Android app permissions',
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
          loading: () => const ListTile(
            title: Text('Watch location'),
            subtitle: Text('Loading settings…'),
          ),
          error: (_, _) => const ListTile(
            title: Text('Watch location'),
            subtitle: Text('Location settings unavailable'),
          ),
        );
  }
}
