import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../providers/dev_ota_providers.dart';
import '../../../services/dev_ota/dev_ota_client.dart';
import '../../navigation/app_router.dart';

/// Settings and status for firmware served from a dev machine.
/// See `scripts/dev_ota/README.md`.
class DevOtaScreen extends ConsumerStatefulWidget {
  const DevOtaScreen({super.key});

  @override
  ConsumerState<DevOtaScreen> createState() => _DevOtaScreenState();
}

class _DevOtaScreenState extends ConsumerState<DevOtaScreen> {
  late final TextEditingController _url;
  late final TextEditingController _token;

  @override
  void initState() {
    super.initState();
    final state = ref.read(devOtaProvider);
    _url = TextEditingController(text: state.url);
    _token = TextEditingController(text: state.token);
  }

  @override
  void dispose() {
    _url.dispose();
    _token.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(devOtaProvider);
    final controller = ref.read(devOtaProvider.notifier);
    final build = state.latest;

    return Scaffold(
      appBar: AppBar(title: const Text('Dev firmware server')),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        children: [
          const Text(
            'Firmware built on your dev machine and published with '
            'scripts/dev_ota/dev_ota.py. The server URL must use HTTPS.',
          ),
          const SizedBox(height: AppTheme.spacingMd),
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Server URL'),
          ),
          const SizedBox(height: AppTheme.spacingSm),
          TextField(
            controller: _token,
            autocorrect: false,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Token'),
          ),
          const SizedBox(height: AppTheme.spacingMd),
          Row(
            children: [
              FilledButton(
                onPressed: () =>
                    unawaited(controller.configure(_url.text, _token.text)),
                child: const Text('Save'),
              ),
              const SizedBox(width: AppTheme.spacingSm),
              OutlinedButton(
                onPressed: state.configured ? controller.refresh : null,
                child: const Text('Check now'),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingLg),
          if (!state.configured)
            const Text('Not configured.')
          else ...[
            Text(
              state.reachable ? 'Connected' : 'Not reachable',
              style: TextStyle(
                color: state.reachable ? Colors.greenAccent : Colors.orange,
              ),
            ),
            if (state.error != null) ...[
              const SizedBox(height: AppTheme.spacingSm),
              Text(state.error!, style: const TextStyle(color: Colors.red)),
            ],
            if (state.phase != null) ...[
              const SizedBox(height: AppTheme.spacingSm),
              Text(state.phase!),
            ],
            const SizedBox(height: AppTheme.spacingMd),
            if (build == null)
              const Text('No build published yet.')
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingMd),
                  child: _BuildSummary(
                    info: build,
                    action: FilledButton.icon(
                      icon: const Icon(Icons.system_update),
                      label: const Text('Install'),
                      onPressed: state.installingId == null
                          ? () {
                              unawaited(controller.install(build));
                              unawaited(context.push(AppRoutes.firmware));
                            }
                          : null,
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _BuildSummary extends StatelessWidget {
  final DevOtaBuild info;
  final Widget? action;

  const _BuildSummary({required this.info, this.action});

  @override
  Widget build(BuildContext context) {
    final created = info.created?.toLocal();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          [
            if (info.branch.isNotEmpty) info.branch,
            if (info.shortCommit.isNotEmpty) info.shortCommit,
          ].join(' · '),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (info.note.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(info.note),
        ],
        const SizedBox(height: 4),
        Text(
          '${created == null ? info.id : created.toString().substring(0, 16)}'
          ' · ${(info.size / 1024).round()} KB',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (action != null) ...[const SizedBox(height: 8), action!],
      ],
    );
  }
}

/// Dialog shown when a new build appears; returns true to install.
Future<bool?> showDevOtaOffer(BuildContext context, DevOtaBuild build) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('New dev firmware'),
      content: _BuildSummary(info: build),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Install'),
        ),
      ],
    ),
  );
}
