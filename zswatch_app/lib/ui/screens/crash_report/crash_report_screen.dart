import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/database/app_database.dart';
import '../../../data/models/crash_summary.dart';
import '../../../providers/coredump_providers.dart';
import '../../../providers/companion_runtime_providers.dart';
import '../../../providers/watch_service_provider.dart';
import '../../../services/coredump/coredump_service.dart';

class CrashReportScreen extends ConsumerWidget {
  const CrashReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inspection = ref.watch(nativeCoredumpInspectionProvider);
    // History remains in the existing UI repository. This provider uses
    // the native summary stream on Android and never constructs WatchService.
    ref.watch(crashReportPersistenceProvider);
    final current = inspection.isLoading == true
        ? const Center(child: CircularProgressIndicator())
        : inspection.hasError == true
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Could not inspect current crash: ${inspection.error}',
              ),
            ),
          )
        : const _CurrentCrashTab();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Crash Reports'),
          actions: [
            IconButton(
              tooltip: 'Refresh crash summary',
              icon: const Icon(Icons.refresh),
              onPressed: inspection.isLoading == true
                  ? null
                  : () => ref.invalidate(nativeCoredumpInspectionProvider),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Current'),
              Tab(text: 'History'),
            ],
          ),
        ),
        body: TabBarView(children: [current, const _HistoryTab()]),
      ),
    );
  }
}

// ==========================================================================
// Current crash tab (existing behavior)
// ==========================================================================

class _CurrentCrashTab extends ConsumerWidget {
  const _CurrentCrashTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(crashSummaryProvider);
    final downloadState =
        ref.watch(coredumpDownloadStateProvider).valueOrNull ??
        const CoredumpDownloadState();

    if (summary == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: AppTheme.successColor.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No active crash',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Crash reports appear here when a crash\nis detected on the watch.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SummaryCard(summary: summary),
          const SizedBox(height: AppTheme.spacingLg),
          _DownloadSection(state: downloadState),
          const SizedBox(height: AppTheme.spacingLg),
          _ActionButtons(summary: summary),
        ],
      ),
    );
  }
}

// ==========================================================================
// History tab
// ==========================================================================

class _HistoryTab extends ConsumerWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(crashReportHistoryProvider);
    final statsAsync = ref.watch(crashFileStatsProvider);

    return historyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (reports) {
        if (reports.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.history,
                  size: 64,
                  color: AppTheme.textSecondary.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No crash history',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Past crashes will be recorded here.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        return CustomScrollView(
          slivers: [
            // Stats section
            SliverToBoxAdapter(
              child: statsAsync.when(
                data: (stats) => stats.isEmpty
                    ? const SizedBox.shrink()
                    : _StatsCard(stats: stats, totalCrashes: reports.length),
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
            ),

            // History header with clear button
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingMd,
              ),
              sliver: SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(
                    top: AppTheme.spacingSm,
                    bottom: AppTheme.spacingSm,
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Recent Crashes (${reports.length})',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => _clearHistory(context, ref),
                        icon: const Icon(Icons.delete_sweep, size: 18),
                        label: const Text('Clear'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.errorColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _CrashHistoryTile(report: reports[index]),
                childCount: reports.length,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],
        );
      },
    );
  }

  Future<void> _clearHistory(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Crash History?'),
        content: const Text(
          'This will delete all stored crash reports from the app. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    final repo = ref.read(crashReportRepositoryProvider);
    final count = await repo.deleteAll();
    ref.invalidate(crashFileStatsProvider);

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Cleared $count crash reports')));
    }
  }
}

class _StatsCard extends StatelessWidget {
  final List<CrashFileStats> stats;
  final int totalCrashes;
  const _StatsCard({required this.stats, required this.totalCrashes});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.bar_chart, color: AppTheme.primaryColor),
                  const SizedBox(width: AppTheme.spacingSm),
                  Text(
                    'Crash Stats',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const Spacer(),
                  Text(
                    '$totalCrashes total',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              const Divider(),
              Text(
                'Top crashing files:',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 4),
              for (final stat in stats)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          stat.file,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontFamily: 'monospace'),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${stat.count}x',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: AppTheme.errorColor,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CrashHistoryTile extends StatelessWidget {
  final CrashReportEntity report;
  const _CrashHistoryTile({required this.report});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, HH:mm');
    final receivedStr = dateFormat.format(report.receivedAt);

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMd,
        vertical: 2,
      ),
      child: ExpansionTile(
        leading: const Icon(
          Icons.warning_amber_rounded,
          color: AppTheme.errorColor,
          size: 20,
        ),
        title: Text(
          '${report.file}:${report.line}',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
        ),
        subtitle: Text(
          '$receivedStr  ·  ${report.fwVersion}-${_shortSha(report.fwCommitSha)}',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppTheme.spacingMd,
          0,
          AppTheme.spacingMd,
          AppTheme.spacingMd,
        ),
        children: [
          Row(
            children: [
              Text(
                'Watch time: ${report.crashTime}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
              ),
              const Spacer(),
              Text(
                '${report.board} (${report.buildType})',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                final text = [
                  'Crash: ${report.file}:${report.line}',
                  'Time: ${report.crashTime}',
                  'FW: ${report.fwVersion}-${report.fwCommitSha}',
                  'Board: ${report.board} (${report.buildType})',
                ].join('\n');
                Clipboard.setData(ClipboardData(text: text));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')),
                );
              },
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy'),
            ),
          ),
        ],
      ),
    );
  }

  String _shortSha(String sha) => sha.length > 7 ? sha.substring(0, 7) : sha;
}

// ==========================================================================
// Shared widgets (used by Current tab)
// ==========================================================================

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
                const Icon(
                  Icons.warning_amber_rounded,
                  color: AppTheme.errorColor,
                  size: 28,
                ),
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
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DownloadSection extends ConsumerWidget {
  final CoredumpDownloadState state;
  const _DownloadSection({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isRunning) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          child: Column(
            children: [
              Text(
                state.phase == CoredumpDownloadPhase.downloading
                    ? 'Downloading coredump from watch...'
                    : 'Enabling SMP on watch...',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppTheme.spacingSm),
              // Native transfers report no progress; keep those indeterminate.
              if (state.phase == CoredumpDownloadPhase.downloading &&
                  state.downloadProgress > 0)
                LinearProgressIndicator(value: state.downloadProgress)
              else
                const LinearProgressIndicator(),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.phase == CoredumpDownloadPhase.failed) ...[
          Text(
            state.errorMessage ?? 'Download failed',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.errorColor),
          ),
          const SizedBox(height: AppTheme.spacingSm),
        ],
        if (state.phase == CoredumpDownloadPhase.completed)
          Text(
            'Coredump downloaded. Export it and attach it to a GitHub issue.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
          )
        else
          FilledButton.icon(
            onPressed: () => ref.read(coredumpServiceProvider).download(),
            icon: const Icon(Icons.download),
            label: Text(
              state.phase == CoredumpDownloadPhase.failed
                  ? 'Retry Download'
                  : 'Download Coredump',
            ),
          ),
      ],
    );
  }
}

class _ActionButtons extends ConsumerWidget {
  final CrashSummary summary;
  const _ActionButtons({required this.summary});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(coredumpServiceProvider);
    final hasCoredump = service.lastCoredumpTxt != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: () {
            final text =
                'Crash: ${summary.file}:${summary.line}\n'
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
        if (hasCoredump) ...[
          const SizedBox(height: AppTheme.spacingSm),
          OutlinedButton.icon(
            onPressed: () => _exportCoredump(context, ref),
            icon: const Icon(Icons.save_alt),
            label: const Text('Export Raw Coredump'),
          ),
        ],
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

  Future<void> _exportCoredump(BuildContext context, WidgetRef ref) async {
    final service = ref.read(coredumpServiceProvider);
    final coredumpTxt = service.lastCoredumpTxt;
    if (coredumpTxt == null) return;
    final sha = summary.fwCommitSha;
    final suffix = sha.isEmpty
        ? 'unknown'
        : sha.length > 7
        ? sha.substring(0, 7)
        : sha;

    try {
      final bytes = Uint8List.fromList(utf8.encode(coredumpTxt));
      final mobile =
          defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS;
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save coredump.txt',
        fileName: 'coredump_$suffix.txt',
        // Mobile pickers write through the document provider. Desktop pickers
        // return a path instead; macOS rejects the bytes argument.
        bytes: mobile ? bytes : null,
      );
      if (savePath == null) return;
      if (!mobile) await File(savePath).writeAsBytes(bytes);

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Coredump saved to $savePath')));
      }
    } catch (error, stack) {
      debugPrint('[CrashReportScreen] Coredump export failed: $error\n$stack');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not export coredump: $error')),
        );
      }
    }
  }

  Future<void> _eraseCoredump(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Erase Coredump?'),
        content: const Text(
          'This will delete the coredump from the watch. Make sure you have exported it if needed.',
        ),
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

    final client = ref.read(companionClientProvider);
    final snapshot = await client.snapshot();
    await client.inspectCoredump(snapshot.generation, erase: true);

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Coredump erased')));
    }
  }
}
