import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../services/background/companion_prototype_client.dart';
import '../../../providers/companion_runtime_providers.dart';
import '../../../providers/watch_service_provider.dart';
import '../voice_memos/voice_memos_screen.dart';
import '../notifications/notification_settings_screen.dart';
import 'shell_screen.dart';

/// An isolated prototype view. It does not create WatchService or any AI provider.
class CompanionPrototypeApp extends ConsumerStatefulWidget {
  const CompanionPrototypeApp({super.key});
  @override
  ConsumerState<CompanionPrototypeApp> createState() =>
      _CompanionPrototypeAppState();
}

class _CompanionPrototypeAppState extends ConsumerState<CompanionPrototypeApp> {
  CompanionPrototypeClient get client => ref.read(companionClientProvider);
  final address = TextEditingController();
  ProviderSubscription<AsyncValue<CompanionPrototypeSnapshot>>? subscription;
  CompanionPrototypeSnapshot? state;
  String? error;
  Map<String, Object?>? presence;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    subscription = ref.listenManual(companionSnapshotProvider, (
      previous,
      next,
    ) {
      next.whenData(show);
      if (next.hasError && mounted) {
        setState(() {
          state = null;
          error = next.error.toString();
        });
      }
    }, fireImmediately: true);
  }

  void show(CompanionPrototypeSnapshot next) {
    if (!mounted) return;
    setState(() {
      state = next;
      error = null;
    });
    if (address.text.isEmpty && next.fields['address'] is String) {
      address.text = next.fields['address']! as String;
    }
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } catch (failure) {
      if (mounted) setState(() => error = failure.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> connect() async {
    final statuses = await [
      Permission.bluetoothConnect,
      Permission.notification,
    ].request();
    if (statuses[Permission.bluetoothConnect]?.isDenied == true) {
      throw StateError('Bluetooth connection permission is required');
    }
    await ref.read(watchNotifierProvider.notifier).connectById(address.text);
    show(await client.snapshot());
  }

  @override
  void dispose() {
    subscription?.close();
    address.dispose();
    super.dispose(); // Service ownership continues while this view is absent.
  }

  @override
  Widget build(BuildContext context) {
    // Exercise the same state providers that the ordinary app's screens use.
    final watch = ref.watch(currentWatchProvider);
    final connection = ref.watch(watchConnectionProvider);
    final battery = ref.watch(batteryLevelProvider);
    final packages = ((state?.fields['notification_packages'] as List?) ?? [])
        .cast<String>();
    final testAllowed = packages.contains('com.zswatch.app');
    return MaterialApp(
      theme: ThemeData.dark(),
      routes: {
        '/voice-notes': (context) => const VoiceMemosScreen(),
        '/notifications': (context) => const NotificationSettingsScreen(),
        '/shell': (context) => const ShellScreen(),
      },
      home: Scaffold(
        appBar: AppBar(title: const Text('Companion prototype')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Builder(
              builder: (context) => OutlinedButton(
                onPressed: () =>
                    Navigator.of(context).pushNamed('/voice-notes'),
                child: const Text('Voice notes'),
              ),
            ),
            const Text('Native Android runtime • development build'),
            Builder(
              builder: (context) => OutlinedButton(
                onPressed: () =>
                    Navigator.of(context).pushNamed('/notifications'),
                child: const Text('Notification settings'),
              ),
            ),
            const SizedBox(height: 12),
            Builder(
              builder: (context) => OutlinedButton(
                onPressed: state?.protocolReady == true
                    ? () => Navigator.of(context).pushNamed('/shell')
                    : null,
                child: const Text('Shell'),
              ),
            ),
            TextField(
              controller: address,
              decoration: const InputDecoration(
                labelText: 'Watch BLE MAC address',
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Service: ${state?.runtimeActive ?? false} • ${state?.phase ?? 'loading'}',
            ),
            Text(
              'Protocol ready: ${state?.protocolReady ?? false} • generation ${state?.generation ?? 0}',
            ),
            Text('Saved recordings: ${state?.recordings.length ?? 0}'),
            if (watch != null) ...[
              Text('Watch: ${watch.displayName}'),
              Text('Firmware: ${watch.firmwareVersion ?? 'waiting'}'),
              Text('Hardware: ${watch.hardwareVersion ?? 'waiting'}'),
              Text(
                '${state!.hasLiveStatus ? 'Battery' : 'Last battery'}: '
                '${(battery ?? watch.batteryLevel)?.toString() ?? '?'}%'
                '${connection.isCharging ? ' • charging' : ''}',
              ),
            ],
            if (state?.fields['remote_jobs'] is List)
              Text(
                'Synthetic jobs: ${jsonEncode(state!.fields['remote_jobs'])}',
              ),
            if (state?.fields['remote_jobs_error'] != null)
              Text(
                'Remote job journal unavailable: ${state!.fields['remote_jobs_error']}',
              ),
            SwitchListTile(
              title: const Text('Download recordings (experimental)'),
              value: state?.fields['recording_sync_enabled'] != false,
              onChanged: busy || state == null
                  ? null
                  : (enabled) => unawaited(
                      run(() async {
                        show(await client.setRecordingSync(enabled));
                      }),
                    ),
            ),
            SwitchListTile(
              title: const Text('Forward notifications'),
              subtitle: Text('${packages.length} selected apps'),
              value: state?.fields['notifications_enabled'] == true,
              onChanged: busy || state == null
                  ? null
                  : (enabled) => unawaited(
                      run(() async {
                        show(
                          await client.configureNotifications(
                            enabled,
                            packages,
                          ),
                        );
                      }),
                    ),
            ),
            if (presence != null)
              Text(
                'Presence supported: ${presence!['supported']} • associated: ${presence!['associated']}',
              ),
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.redAccent)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () => unawaited(
                          run(
                            () => client.notificationDiagnostic(
                              requestAccess: true,
                            ),
                          ),
                        ),
                  child: const Text('Notification access'),
                ),
                OutlinedButton(
                  onPressed:
                      busy ||
                          !testAllowed ||
                          state?.fields['notifications_enabled'] != true
                      ? null
                      : () => unawaited(
                          run(() => client.notificationDiagnostic()),
                        ),
                  child: const Text('Post test notification'),
                ),
                FilledButton(
                  onPressed:
                      busy ||
                          !testAllowed ||
                          state?.protocolReady != true ||
                          state?.fields['notifications_enabled'] != true
                      ? null
                      : () => unawaited(
                          run(
                            () => client.notificationDiagnostic(
                              delaySeconds: 15,
                              closeUi: true,
                            ),
                          ),
                        ),
                  child: const Text('Close UI and test in 15s'),
                ),
                FilledButton(
                  onPressed: busy ? null : () => unawaited(run(connect)),
                  child: const Text('Connect / recover'),
                ),
                OutlinedButton(
                  onPressed: busy || state?.runtimeActive != true
                      ? null
                      : () => unawaited(
                          run(() async {
                            final next = await client.presence(
                              address.text,
                              associate: true,
                            );
                            if (mounted) setState(() => presence = next);
                          }),
                        ),
                  child: const Text('Enable presence recovery'),
                ),
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () => unawaited(
                          run(() async {
                            show(await client.command('stop'));
                          }),
                        ),
                  child: const Text('Stop'),
                ),
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () => unawaited(
                          run(() async {
                            show(await client.snapshot());
                          }),
                        ),
                  child: const Text('Refresh'),
                ),
                OutlinedButton(
                  onPressed: busy || state?.runtimeActive != true
                      ? null
                      : () => unawaited(
                          run(() async {
                            show(await client.command('startRemoteFixture'));
                          }),
                        ),
                  child: const Text('Start synthetic remote job'),
                ),
                OutlinedButton(
                  onPressed: busy || state?.runtimeActive != true
                      ? null
                      : () => unawaited(
                          run(() async {
                            show(await client.command('startLocalFixture'));
                          }),
                        ),
                  child: const Text('Start Dart worker fixture (no model)'),
                ),
                OutlinedButton(
                  onPressed: busy || state?.protocolReady != true
                      ? null
                      : () => unawaited(
                          run(() async {
                            show(await client.command('syncTime'));
                          }),
                        ),
                  child: const Text('Sync time'),
                ),
                OutlinedButton(
                  onPressed: busy || state?.protocolReady != true
                      ? null
                      : () => unawaited(
                          run(() async {
                            show(await client.command('requestDeviceInfo'));
                          }),
                        ),
                  child: const Text('Refresh watch info'),
                ),
                OutlinedButton(
                  onPressed: busy || state?.protocolReady != true
                      ? null
                      : () => unawaited(
                          run(() async {
                            show(await client.command('retryRecordings'));
                          }),
                        ),
                  child: const Text('Fetch recordings'),
                ),
                OutlinedButton(
                  onPressed: busy || state == null
                      ? null
                      : () => unawaited(
                          run(() async {
                            show(
                              await client.command(
                                'ackEvents',
                                cursor: state!.cursor,
                              ),
                            );
                          }),
                        ),
                  child: const Text('Acknowledge displayed events'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (state != null)
              SelectableText(
                const JsonEncoder.withIndent('  ').convert(state!.fields),
              ),
          ],
        ),
      ),
    );
  }
}
