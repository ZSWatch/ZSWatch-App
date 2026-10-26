import 'package:chrono_ai_flow/chrono_ai_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../providers/companion_runtime_providers.dart';
import '../../../providers/openrouter_providers.dart';
import '../../../services/ai/openrouter_client.dart';

final _keysPage = Uri.parse('https://openrouter.ai/keys');
final _creditsPage = Uri.parse('https://openrouter.ai/settings/credits');

String _usd(double value) => value < 0.01 && value > 0
    ? '\$${value.toStringAsFixed(4)}'
    : '\$${value.toStringAsFixed(2)}';

/// OpenRouter key, usage and model choice for voice memo processing.
class OpenRouterSettingsSection extends ConsumerWidget {
  const OpenRouterSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = ref.watch(openRouterKeyProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacingMd,
            AppTheme.spacingMd,
            AppTheme.spacingMd,
            4,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'OpenRouter',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Each recording is transcribed and analyzed by models on '
                'OpenRouter, with your own key. Only zero-data-retention '
                'providers are used. A memo costs well under a cent.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
        const _WaitingJobsBanner(),
        const _QueuedLocalJobs(),
        key.when(
          loading: () => const ListTile(title: Text('Reading key…')),
          error: (e, _) => ListTile(
            leading: const Icon(Icons.error_outline),
            title: const Text('Could not read the stored key'),
            subtitle: Text('$e'),
          ),
          data: (value) =>
              value == null ? const _KeyEntry() : const _KeyStatus(),
        ),
        _ModelTile(
          title: 'Speech-to-text model',
          audio: true,
          model: ref.watch(openRouterSttModelProvider),
          onSelected: (id) =>
              ref.read(openRouterSttModelProvider.notifier).set(id),
        ),
        _ModelTile(
          title: 'Analysis model',
          audio: false,
          model: ref.watch(openRouterAnalysisModelProvider),
          onSelected: (id) =>
              ref.read(openRouterAnalysisModelProvider.notifier).set(id),
        ),
      ],
    );
  }
}

class _WaitingJobsBanner extends ConsumerWidget {
  const _WaitingJobsBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(companionSnapshotProvider).asData?.value;
    final jobs = [
      for (final job in snapshot?.fields['voice_jobs'] as List? ?? const [])
        if (job is Map &&
            job['state'] == 'blocked' &&
            '${job['last_error']}'.startsWith('cloud_'))
          job,
    ];
    if (jobs.isEmpty) return const SizedBox.shrink();
    final credits = jobs.any((j) => j['last_error'] == 'cloud_credits');
    final count = jobs.length == 1 ? '1 memo is' : '${jobs.length} memos are';
    return Card(
      color: AppTheme.warningColor.withValues(alpha: 0.15),
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMd,
        vertical: 8,
      ),
      child: ListTile(
        leading: const Icon(
          Icons.warning_amber_rounded,
          color: AppTheme.warningColor,
        ),
        title: Text(
          credits
              ? 'Out of OpenRouter credit. $count waiting.'
              : 'OpenRouter key missing or rejected. $count waiting.',
        ),
        subtitle: Text(
          credits
              ? 'Add credit or raise the key limit, then save the key again.'
              : 'Save a valid key; waiting memos run again automatically.',
        ),
        trailing: credits
            ? TextButton(
                onPressed: () => launchUrl(_creditsPage),
                child: const Text('Add credit'),
              )
            : null,
      ),
    );
  }
}

/// On-device jobs queued before switching to OpenRouter keep running and
/// delay new memos; this clears them in one go.
class _QueuedLocalJobs extends ConsumerStatefulWidget {
  const _QueuedLocalJobs();

  @override
  ConsumerState<_QueuedLocalJobs> createState() => _QueuedLocalJobsState();
}

class _QueuedLocalJobsState extends ConsumerState<_QueuedLocalJobs> {
  bool _cancelling = false;

  Future<void> _cancel(List<String> ids) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel on-device jobs?'),
        content: Text(
          '${ids.length} queued on-device '
          '${ids.length == 1 ? 'job stops' : 'jobs stop'}. Recordings and '
          'transcripts are kept and can be processed again later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel jobs'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _cancelling = true);
    final client = ref.read(companionClientProvider);
    var failed = 0;
    for (final id in ids) {
      try {
        await client.voiceJob(id, cancel: true);
      } catch (e) {
        failed++;
        debugPrint('[QueuedLocalJobs] cancel failed: $e');
      }
    }
    if (!mounted) return;
    setState(() => _cancelling = false);
    if (failed > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not cancel $failed of ${ids.length}.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(companionSnapshotProvider).asData?.value;
    final ids = [
      for (final job in snapshot?.fields['voice_jobs'] as List? ?? const [])
        if (job is Map &&
            ['ready', 'blocked'].contains(job['state']) &&
            job['job_id'] is String &&
            !'${job['model']}'.split('|').any(isOpenRouterModel))
          job['job_id'] as String,
    ];
    if (ids.isEmpty) return const SizedBox.shrink();
    return ListTile(
      leading: const Icon(Icons.hourglass_bottom),
      title: Text(
        '${ids.length} on-device ${ids.length == 1 ? 'job' : 'jobs'} queued',
      ),
      subtitle: const Text(
        'They run before new memos when the app is open and slow them down.',
      ),
      trailing: TextButton(
        onPressed: _cancelling ? null : () => _cancel(ids),
        child: Text(_cancelling ? 'Cancelling…' : 'Cancel all'),
      ),
    );
  }
}

class _KeyEntry extends ConsumerStatefulWidget {
  const _KeyEntry();

  @override
  ConsumerState<_KeyEntry> createState() => _KeyEntryState();
}

class _KeyEntryState extends ConsumerState<_KeyEntry> {
  final _controller = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // App Store 5.1.2(i): ask before personal data goes to a third-party AI.
    final allowed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send voice data to OpenRouter?'),
        content: const Text(
          'With a key saved, your voice memo recordings, dictated replies, '
          'their transcripts and your Chat questions are sent to OpenRouter and the AI model '
          'provider you choose, to transcribe and answer them. Remove the '
          'key at any time to stop.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Allow'),
          ),
        ],
      ),
    );
    if (allowed != true || !mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(openRouterKeyProvider.notifier).save(_controller.text);
      if (mounted) _controller.clear();
    } on OpenRouterFailure catch (e) {
      if (!mounted) return;
      setState(
        () => _error = switch (e.kind) {
          OpenRouterFailureKind.auth => 'OpenRouter rejected this key.',
          OpenRouterFailureKind.retry =>
            'Could not reach OpenRouter. Check the connection and try again.',
          _ => 'OpenRouter: ${e.message}',
        },
      );
    } on Object catch (e) {
      if (mounted) setState(() => _error = 'Could not save the key: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMd,
        vertical: 8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Create a key on openrouter.ai and paste it here. Give it a '
            'credit limit, e.g. \$5, so a bug can never spend more. '
            'Saving enables automatic transcription and analysis for new recordings. '
            'You can turn either option off below.',
          ),
          TextButton.icon(
            onPressed: () =>
                launchUrl(_keysPage, mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('openrouter.ai/keys'),
          ),
          TextField(
            controller: _controller,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: 'API key',
              hintText: 'sk-or-v1-…',
              errorText: _error,
            ),
            onSubmitted: (_) => _saving ? null : _save(),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Checking…' : 'Verify and save'),
            ),
          ),
        ],
      ),
    );
  }
}

class _KeyStatus extends ConsumerWidget {
  const _KeyStatus();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(openRouterKeyInfoProvider);
    return Column(
      children: [
        ListTile(
          leading: Icon(
            info.hasError ? Icons.error_outline : Icons.check_circle,
            color: info.hasError ? AppTheme.errorColor : AppTheme.successColor,
          ),
          title: const Text('OpenRouter key saved'),
          subtitle: info.when(
            loading: () => const Text('Checking usage…'),
            error: (e, _) => Text(
              e is OpenRouterFailure && e.kind == OpenRouterFailureKind.auth
                  ? 'OpenRouter rejects this key. Save a new one.'
                  : 'Could not check usage: ${e is OpenRouterFailure ? e.message : e}',
            ),
            data: (value) => value == null
                ? const SizedBox.shrink()
                : Text(
                    [
                      'Used this month ${_usd(value.usageMonthly)}',
                      if (value.limitRemaining != null)
                        'Left on this key ${_usd(value.limitRemaining!)} '
                            'of ${_usd(value.limit!)}'
                      else
                        'No limit on this key: consider setting one',
                    ].join('\n'),
                  ),
          ),
          trailing: IconButton(
            tooltip: 'Refresh usage',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(openRouterKeyInfoProvider),
          ),
        ),
        OverflowBar(
          alignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () =>
                  launchUrl(_creditsPage, mode: LaunchMode.externalApplication),
              child: const Text('Add credit'),
            ),
            TextButton(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Remove key?'),
                    content: const Text(
                      'New memos wait until a key is saved again. The key '
                      'stays active on OpenRouter; delete it there to revoke it.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Remove'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await ref.read(openRouterKeyProvider.notifier).clear();
                }
              },
              child: const Text('Remove key'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ModelTile extends ConsumerWidget {
  const _ModelTile({
    required this.title,
    required this.audio,
    required this.model,
    required this.onSelected,
  });

  final String title;
  final bool audio;
  final String model;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final models = ref.watch(openRouterModelsProvider).valueOrNull;
    final info = models?.where((m) => m.id == model).firstOrNull;
    return ListTile(
      title: Text(title),
      subtitle: Text(
        info == null
            ? model
            : '${info.name}\n~${_usd(audio ? info.transcriptionCostPerMemo : info.analysisCostPerMemo)} per memo'
                  '${info.zdr ? '' : ' · no zero-retention provider'}',
      ),
      isThreeLine: info != null,
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        final picked = await showModalBottomSheet<String>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (_) => _ModelPicker(audio: audio, selected: model),
        );
        if (picked != null) onSelected(picked);
      },
    );
  }
}

class _ModelPicker extends ConsumerStatefulWidget {
  const _ModelPicker({required this.audio, required this.selected});

  final bool audio;
  final String selected;

  @override
  ConsumerState<_ModelPicker> createState() => _ModelPickerState();
}

class _ModelPickerState extends ConsumerState<_ModelPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final recommended = widget.audio
        ? recommendedTranscriptionModels
        : recommendedAnalysisModels;
    final models = ref.watch(openRouterModelsProvider);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      builder: (context, scroll) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    autofocus: false,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: widget.audio
                          ? 'Search audio models'
                          : 'Search text models',
                    ),
                    onChanged: (value) =>
                        setState(() => _query = value.trim().toLowerCase()),
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh model list',
                  icon: const Icon(Icons.refresh),
                  onPressed: () => ref
                      .read(openRouterModelsRefreshProvider.notifier)
                      .state++,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Models without a zero-data-retention provider cannot be '
              'used: requests to them would fail.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
            ),
          ),
          Expanded(
            child: models.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Could not load models: $e')),
              data: (all) {
                final matching =
                    all
                        .where((m) => widget.audio ? m.acceptsAudio : true)
                        .where(
                          (m) =>
                              _query.isEmpty ||
                              m.id.toLowerCase().contains(_query) ||
                              m.name.toLowerCase().contains(_query),
                        )
                        .toList()
                      ..sort((a, b) {
                        final ra = recommended.indexOf(a.id);
                        final rb = recommended.indexOf(b.id);
                        if (ra != rb) {
                          if (ra < 0) return 1;
                          if (rb < 0) return -1;
                          return ra.compareTo(rb);
                        }
                        if (a.zdr != b.zdr) return a.zdr ? -1 : 1;
                        return a.id.compareTo(b.id);
                      });
                return ListView.builder(
                  controller: scroll,
                  itemCount: matching.length,
                  itemBuilder: (context, i) {
                    final m = matching[i];
                    final cost = widget.audio
                        ? m.transcriptionCostPerMemo
                        : m.analysisCostPerMemo;
                    return ListTile(
                      enabled: m.zdr,
                      selected: m.id == widget.selected,
                      leading: recommended.contains(m.id)
                          ? const Icon(Icons.star, color: AppTheme.warningColor)
                          : const SizedBox(width: 24),
                      title: Text(m.name),
                      subtitle: Text(
                        '${m.id}\n~${_usd(cost)} per memo'
                        '${m.zdr ? '' : ' · no zero-retention provider'}',
                      ),
                      isThreeLine: true,
                      onTap: () => Navigator.pop(context, m.id),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
