import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/companion_notification_status.dart';
import '../../../providers/companion_runtime_providers.dart';
import '../../../services/background/companion_prototype_client.dart';

/// Configuration belongs to the native core, not Dart notification listeners.
class CompanionNotificationSettingsView extends ConsumerStatefulWidget {
  const CompanionNotificationSettingsView({super.key});

  @override
  ConsumerState<CompanionNotificationSettingsView> createState() =>
      _CompanionNotificationSettingsViewState();
}

class _CompanionNotificationSettingsViewState
    extends ConsumerState<CompanionNotificationSettingsView>
    with WidgetsBindingObserver {
  bool busy = false;
  String? error;
  CompanionPrototypeSnapshot? acceptedPolicy;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(companionNotificationStatusProvider);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> update(bool enabled, Set<String> blocked) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await ref
          .read(companionClientProvider)
          .configureNotifications(enabled, blocked.toList()..sort());
      if (mounted) setState(() => acceptedPolicy = result);
    } catch (failure) {
      if (mounted) {
        setState(() => error = 'Could not update notification settings');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> requestAccess() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref
          .read(companionClientProvider)
          .notificationDiagnostic(requestAccess: true);
    } catch (failure) {
      if (mounted) {
        setState(() => error = 'Could not open notification access settings');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(companionNotificationStatusProvider);
    final observed = ref.watch(companionSnapshotProvider).asData?.value;
    // A command response can arrive before the shared event stream catches up.
    // Use its committed policy until that cursor is observed, so rapid edits
    // cannot accidentally restore the previous blocked apps.
    final snapshot =
        observed != null &&
            acceptedPolicy != null &&
            observed.cursor < acceptedPolicy!.cursor
        ? acceptedPolicy
        : observed;
    final enabled = snapshot?.fields['notifications_enabled'] == true;
    final blocked =
        ((snapshot?.fields['notification_blocked_packages'] as List?) ?? [])
            .cast<String>()
            .toSet();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            tooltip: 'Refresh notification apps',
            icon: const Icon(Icons.refresh),
            onPressed: busy
                ? null
                : () => ref.invalidate(companionNotificationStatusProvider),
          ),
        ],
      ),
      body: status.when(
        skipLoadingOnRefresh: false,
        data: (access) => content(
          access,
          snapshot != null,
          snapshot?.protocolReady == true,
          enabled,
          blocked,
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (failure, stack) =>
            const Center(child: Text('Notification settings are unavailable')),
      ),
    );
  }

  Widget content(
    CompanionNotificationStatus access,
    bool knownPolicy,
    bool ready,
    bool enabled,
    Set<String> blocked,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          access.accessGranted
              ? 'Notification access granted'
              : 'Notification access required',
        ),
        Text(
          access.listenerConnected
              ? 'Notification listener connected'
              : 'Notification listener disconnected',
        ),
        if (!ready) const Text('Watch disconnected'),
        if (!access.accessGranted)
          FilledButton(
            onPressed: busy ? null : requestAccess,
            child: const Text('Grant notification access'),
          ),
        SwitchListTile(
          title: const Text('Forward notifications'),
          subtitle: const Text(
            'Forward notifications from all apps except unchecked ones',
          ),
          value: enabled,
          onChanged: busy || !knownPolicy || (!access.accessGranted && !enabled)
              ? null
              : (value) => update(value, blocked),
        ),
        const SizedBox(height: 16),
        Text(switch (blocked.length) {
          0 => 'All apps forwarded',
          1 => '1 app blocked',
          final count => '$count apps blocked',
        }),
        if (error != null)
          Text(error!, style: const TextStyle(color: Colors.redAccent)),
        for (final app in access.apps)
          CheckboxListTile(
            title: Text(app.appName),
            subtitle: Text(app.packageName),
            value: !blocked.contains(app.packageName),
            onChanged:
                busy ||
                    !knownPolicy ||
                    (!blocked.contains(app.packageName) &&
                        blocked.length >= 256)
                ? null
                : (value) {
                    final next = {...blocked};
                    if (value == true) {
                      next.remove(app.packageName);
                    } else {
                      next.add(app.packageName);
                    }
                    update(enabled, next);
                  },
          ),
      ],
    );
  }
}
