import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/companion_runtime_providers.dart';
import '../../providers/openrouter_providers.dart';
import '../../providers/settings_providers.dart';
import '../../services/ai/voice_model_config.dart';

/// Queues existing native receipts; the shared worker owns model execution.
class CompanionVoiceBatchButton extends ConsumerStatefulWidget {
  final String operation;
  final String label;
  final Set<String>? identities;
  const CompanionVoiceBatchButton({
    super.key,
    required this.operation,
    required this.label,
    this.identities,
  });

  @override
  ConsumerState<CompanionVoiceBatchButton> createState() => _BatchState();
}

class _BatchState extends ConsumerState<CompanionVoiceBatchButton> {
  bool busy = false;

  Future<void> queue() async {
    final snapshot = ref.read(companionSnapshotProvider).asData?.value;
    final all = ref.read(companionRecordingsProvider).asData?.value ?? [];
    final jobs = (snapshot?.fields['voice_jobs'] as List? ?? [])
        .whereType<Map<Object?, Object?>>();
    final items = all.where((recording) {
      if (!recording.hasCommittedReceipt ||
          (recording.archived && widget.identities == null) ||
          (widget.identities != null &&
              !widget.identities!.contains(recording.identity)) ||
          recording.watchId !=
              (snapshot?.isIos == true
                  ? snapshot?.fields['address']
                  : snapshot?.watch?.id)) {
        return false;
      }
      if (widget.operation == 'retranscribe') return true;
      final saved = jobs.where(
        (job) =>
            job['recording_id'] == recording.identity &&
            job['selected'] == true,
      );
      return !saved.any(
        (job) => widget.operation == 'transcribe'
            ? job['transcript_saved'] == true
            : ['result_ready', 'delivered'].contains(job['state']),
      );
    }).toList();
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No saved recordings to process')),
      );
      return;
    }
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.label),
        content: Text(
          '${items.length} saved recordings will be queued with the selected local models.'
          '${widget.operation == 'retranscribe' ? ' Existing transcriptions will be replaced.' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Queue'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    setState(() => busy = true);
    var queued = 0;
    try {
      final config = VoiceModelConfig.fromPrefs(
        await ref.read(sharedPreferencesProvider.future),
      );
      for (final recording in items) {
        await ref
            .read(companionClientProvider)
            .processRecording(
              config.processingRequest(recording.identity, widget.operation),
            );
        queued++;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$queued recordings queued. You can close the app.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$queued recordings queued; could not queue the remaining recordings.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(voiceModelConfigProvider).canAnalyze &&
        ['process', 'reanalyze'].contains(widget.operation)) {
      return const SizedBox.shrink();
    }
    final snapshot = ref.watch(companionSnapshotProvider).asData?.value;
    return ListTile(
      title: Text(widget.label),
      leading: Icon(
        widget.operation == 'process' ? Icons.auto_awesome : Icons.refresh,
      ),
      onTap:
          busy || (snapshot?.runtimeActive != true && snapshot?.isIos != true)
          ? null
          : queue,
      trailing: busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(),
            )
          : null,
    );
  }
}
