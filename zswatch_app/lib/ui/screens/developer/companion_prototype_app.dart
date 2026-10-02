import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../services/background/companion_prototype_client.dart';

/// An isolated prototype view. It does not create WatchService or any AI provider.
class CompanionPrototypeApp extends StatefulWidget {
  const CompanionPrototypeApp({super.key});
  @override
  State<CompanionPrototypeApp> createState() => _CompanionPrototypeAppState();
}

class _CompanionPrototypeAppState extends State<CompanionPrototypeApp> {
  final client = const CompanionPrototypeClient();
  final address = TextEditingController();
  StreamSubscription<CompanionPrototypeSnapshot>? subscription;
  CompanionPrototypeSnapshot? state;
  String? error;
  Map<String, Object?>? presence;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    subscription = client.watch().listen(
      show,
      onError: (Object failure) {
        if (mounted) setState(() => error = failure.toString());
      },
    );
    unawaited(
      run(() async {
        show(await client.snapshot());
      }),
    );
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
    await client.start(address.text);
    show(await client.snapshot());
  }

  @override
  void dispose() {
    unawaited(subscription?.cancel());
    address.dispose();
    super.dispose(); // Service ownership continues while this view is absent.
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: ThemeData.dark(),
    home: Scaffold(
      appBar: AppBar(title: const Text('Companion prototype')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Native Android runtime • development build'),
          const SizedBox(height: 12),
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
