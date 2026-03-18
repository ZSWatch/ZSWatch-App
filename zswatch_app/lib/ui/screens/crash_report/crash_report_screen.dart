import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/crash_summary.dart';
import '../../../providers/watch_service_provider.dart';

class CrashReportScreen extends ConsumerWidget {
  const CrashReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(crashSummaryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Crash Report')),
      body: summary == null
          ? const Center(child: Text('No crash data available'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SummaryCard(summary: summary),
                  const SizedBox(height: AppTheme.spacingLg),
                  _ActionButtons(summary: summary),
                ],
              ),
            ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final CrashSummary summary;
  const _SummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: AppTheme.errorColor, size: 28),
                const SizedBox(width: AppTheme.spacingSm),
                Text(
                  'Crash Summary',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.errorColor,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const Divider(),
            _InfoRow(label: 'File', value: summary.file),
            _InfoRow(label: 'Line', value: summary.line.toString()),
            _InfoRow(label: 'Time', value: summary.time),
            _InfoRow(
              label: 'FW',
              value:
                  '${summary.fwVersion}${summary.fwCommitSha.isNotEmpty ? '-${summary.fwCommitSha}' : ''}',
            ),
            _InfoRow(
              label: 'Board',
              value: '${summary.board} (${summary.buildType})',
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              '$label:',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButtons extends ConsumerWidget {
  final CrashSummary summary;
  const _ActionButtons({required this.summary});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: () {
            final text = 'Crash: ${summary.file}:${summary.line}\n'
                'Time: ${summary.time}\n'
                'FW: ${summary.fwVersion}-${summary.fwCommitSha}\n'
                'Board: ${summary.board} (${summary.buildType})';
            Clipboard.setData(ClipboardData(text: text));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Crash info copied to clipboard')),
            );
          },
          icon: const Icon(Icons.copy),
          label: const Text('Copy Summary'),
        ),
        const SizedBox(height: AppTheme.spacingSm),
        OutlinedButton.icon(
          onPressed: () => _eraseCoredump(context, ref),
          icon: const Icon(Icons.delete_outline),
          label: const Text('Erase on Watch'),
          style: OutlinedButton.styleFrom(foregroundColor: AppTheme.errorColor),
        ),
      ],
    );
  }

  Future<void> _eraseCoredump(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Erase Coredump?'),
        content: const Text(
            'This will delete the coredump from the watch. Make sure you have exported it if needed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Erase'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    final watchService = ref.read(watchServiceProvider);
    await watchService.eraseCoredump();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Coredump erased')),
      );
      Navigator.of(context).pop();
    }
  }
}
