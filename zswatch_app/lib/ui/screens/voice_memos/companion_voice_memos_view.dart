import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/database/companion_recording_database.dart'
    show ImportedRecording;
import '../../../data/models/companion_recording.dart';
import '../../../providers/companion_runtime_providers.dart';
import '../../../providers/settings_providers.dart';
import '../../../providers/ai_providers.dart';
import '../../../services/ai/llm_service.dart';
import '../../../services/voice_memo/transcription_engine.dart';
import '../../../providers/companion_recording_import_providers.dart';
import '../../widgets/voice_memos/audio_playback_bar.dart';
import '../../widgets/voice_memos/companion_voice_action_card.dart';

/// Native receipt view used by the existing Voice Notes screen during migration.
/// It observes the core; opening this screen does not start sync or inference.
class CompanionVoiceMemosView extends ConsumerStatefulWidget {
  const CompanionVoiceMemosView({super.key});

  @override
  ConsumerState<CompanionVoiceMemosView> createState() =>
      _CompanionVoiceMemosViewState();
}

class _CompanionVoiceMemosViewState
    extends ConsumerState<CompanionVoiceMemosView> {
  bool refreshing = false;
  String? preparing;

  Future<void> preparePlayback(CompanionRecording recording) async {
    if (preparing != null) return;
    setState(() => preparing = recording.identity);
    try {
      final imported = await ref.read(companionPreparePlaybackProvider)(
        recording,
      );
      if (!mounted) return;
      setState(() => preparing = null);
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  recording.filename,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                AudioPlaybackBar(
                  key: ValueKey(imported.playbackPath),
                  filePath: imported.playbackPath,
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not prepare playback. The original recording is retained.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => preparing = null);
    }
  }

  Future<void> processRecording(CompanionRecording recording) async {
    try {
      final prefs = await ref.read(sharedPreferencesProvider.future);
      final llmModels = await ref.read(llmAvailableModelsProvider.future);
      var selectedStt =
          prefs.getString(SettingsKeys.transcriptionEngineType) ??
          TranscriptionEngineType.whisperTinyEn.name;
      var selectedLlm =
          prefs.getString(SettingsKeys.selectedAiModelId) ??
          LlmService.defaultModelId;
      if (!llmModels.any((model) => model.id == selectedLlm)) {
        selectedLlm = LlmService.defaultModelId;
      }
      if (!mounted) return;
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Process recording locally'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Uses models already downloaded on this phone. Audio stays on the phone.',
                ),
                DropdownButton<String>(
                  isExpanded: true,
                  value: selectedStt,
                  items: [
                    for (final model in TranscriptionModelCatalog.all)
                      DropdownMenuItem(
                        value: model.type.name,
                        child: Text(
                          model.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedStt = value);
                    }
                  },
                ),
                DropdownButton<String>(
                  isExpanded: true,
                  value: selectedLlm,
                  items: [
                    for (final model in llmModels)
                      DropdownMenuItem(
                        value: model.id,
                        child: Text(
                          model.displayName,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedLlm = value);
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Process'),
              ),
            ],
          ),
        ),
      );
      if (accepted != true) return;
      await ref.read(companionClientProvider).processRecording({
        'identity': recording.identity,
        'transcription_model': selectedStt,
        'analysis_model': selectedLlm,
        'correct_transcription':
            prefs.getBool(SettingsKeys.aiCorrectionEnabled) ?? false,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Local processing queued. You can close the app.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not queue processing. The original recording is retained.',
            ),
          ),
        );
      }
    }
  }

  Future<void> showJob(String id, CompanionRecording recording) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          final detail = ref.watch(companionVoiceJobProvider(id));
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: detail.when(
                  skipLoadingOnReload: true,
                  data: (job) {
                    final result = job['result'] as Map<Object?, Object?>?;
                    final text = result?['transcript'] ?? job['transcript'];
                    final pending = [
                      'ready',
                      'waiting_remote',
                      'result_ready',
                    ].contains(job['state']);
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          recording.filename,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        Text(jobLabel(job)),
                        if (job['last_error'] != null &&
                            [
                              'ready',
                              'waiting_remote',
                              'failed',
                              'blocked',
                            ].contains(job['state']))
                          Text('Reason: ${job['last_error']}'),
                        if (text is String) ...[
                          const SizedBox(height: 16),
                          const Text('Transcript'),
                          SelectableText(text),
                        ],
                        if (result != null) ...[
                          const SizedBox(height: 16),
                          const Text('Summary'),
                          SelectableText(result['summary'] as String),
                          const SizedBox(height: 16),
                          for (final (index, action)
                              in (result['actions'] as List)
                                  .cast<Map<Object?, Object?>>()
                                  .indexed)
                            CompanionVoiceActionCard(
                              key: ValueKey('$id:$index'),
                              jobId: id,
                              index: index,
                              action: action,
                              canCreate: [
                                'result_ready',
                                'delivered',
                              ].contains(job['state']),
                              state:
                                  (job['action_states']
                                          as Map<Object?, Object?>?)?['$index']
                                      as Map<Object?, Object?>?,
                              onChanged: () =>
                                  ref.invalidate(companionVoiceJobProvider(id)),
                            ),
                        ],
                        if (pending)
                          TextButton(
                            onPressed: () async {
                              await ref
                                  .read(companionClientProvider)
                                  .voiceJob(id, cancel: true);
                              ref.invalidate(companionVoiceJobProvider(id));
                            },
                            child: const Text('Cancel job'),
                          ),
                        if ([
                          'failed',
                          'cancelled',
                          'blocked',
                        ].contains(job['state']))
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              processRecording(recording);
                            },
                            child: const Text('Retry processing'),
                          ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ],
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (error, stack) =>
                      const Text('Processing status is unavailable'),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  static String jobLabel(Map<Object?, Object?> job) => switch (job['state']) {
    'ready' =>
      job['processing'] == true
          ? job['transcript_saved'] == true
                ? 'Analyzing'
                : 'Transcribing'
          : 'Queued',
    'result_ready' => 'Processed • Waiting for watch acceptance',
    'delivered' => 'Processed • Accepted by watch',
    'cancelled' => 'Cancelled',
    'failed' =>
      job['last_error'] == 'no_speech'
          ? 'No speech detected'
          : 'Processing failed',
    'blocked' => 'Waiting for processing permission',
    _ => 'Processing',
  };

  Future<void> refreshList() async {
    setState(() => refreshing = true);
    try {
      // Refresh metadata only. Native retains its download setting and owns
      // any already-enabled sync; this command never retries failed transfers.
      await ref.read(companionClientProvider).command('requestRecordingList');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not refresh the recording list')),
        );
      }
    } finally {
      if (mounted) setState(() => refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(companionSnapshotProvider).asData?.value;
    final recordings = ref.watch(companionRecordingsProvider);
    final imports = ref.watch(companionRecordingImportsProvider);
    final imported = <String, ImportedRecording>{
      for (final item in imports.asData?.value ?? <ImportedRecording>[])
        item.identity: item,
    };
    final ready = snapshot?.protocolReady == true;
    final paused = snapshot?.fields['recording_sync_enabled'] == false;
    final watchId = snapshot?.fields['address'];
    final observed = snapshot?.fields['recording_list'];
    final jobs = <String, Map<Object?, Object?>>{};
    for (final job
        in (snapshot?.fields['voice_jobs'] as List? ?? [])
            .whereType<Map<Object?, Object?>>()) {
      if (job['watch_id'] != watchId) continue;
      final identity = job['recording_id'] as String;
      final current = jobs[identity];
      final selected = job['selected'] == true;
      final currentSelected = current?['selected'] == true;
      if (current == null ||
          (selected && !currentSelected) ||
          (selected == currentSelected &&
              (job['generation'] as int) > (current['generation'] as int))) {
        jobs[identity] = job;
      }
    }
    final liveListCount =
        ready &&
            observed is Map &&
            observed['address'] == watchId &&
            observed['generation'] == snapshot?.generation &&
            observed['count'] is int
        ? observed['count'] as int
        : null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Notes'),
        actions: [
          IconButton(
            tooltip: 'Refresh recording list',
            onPressed: ready && !refreshing ? refreshList : null,
            icon: refreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: recordings.when(
        skipLoadingOnRefresh: false,
        skipLoadingOnReload: false,
        data: (all) {
          final items = all.where((item) => item.watchId == watchId).toList();
          final saved = items.where((item) => item.hasCommittedReceipt).length;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('${items.length} recordings • $saved saved on phone'),
              if (liveListCount != null)
                Text('Latest watch list: $liveListCount recordings'),
              Text(
                !ready
                    ? 'Watch disconnected — showing saved status'
                    : paused
                    ? 'Downloads paused'
                    : 'Downloads enabled',
              ),
              if (imports.hasError) ...[
                const Text('Playback imports are unavailable'),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(companionRecordingImportsProvider),
                  child: const Text('Retry playback imports'),
                ),
              ],
              const SizedBox(height: 16),
              if (items.isEmpty)
                const Text('No recordings saved for this watch'),
              for (final item in items)
                ListTile(
                  key: ValueKey(item.identity),
                  leading: Icon(
                    item.hasCommittedReceipt
                        ? Icons.file_download_done
                        : Icons.mic,
                  ),
                  title: Text(item.filename),
                  onTap: jobs[item.identity] == null
                      ? null
                      : () => showJob(
                          jobs[item.identity]!['job_id'] as String,
                          item,
                        ),
                  subtitle: Text(
                    '${DateFormat.yMMMd().add_Hm().format(item.timestampUtc.toLocal())} • '
                    '${(item.durationMs / 1000).toStringAsFixed(1)} s\n'
                    '${status(item, ready, paused)}'
                    '${jobs[item.identity] == null ? '' : ' • ${jobLabel(jobs[item.identity]!)}'}'
                    '${imported[item.identity]?.sourceSha256 == item.sha256 && item.hasCommittedReceipt ? ' • Playback prepared' : ''}',
                  ),
                  isThreeLine: true,
                  trailing: item.hasCommittedReceipt
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Process recording locally',
                              onPressed: ready
                                  ? () => processRecording(item)
                                  : null,
                              icon: const Icon(Icons.auto_awesome),
                            ),
                            IconButton(
                              tooltip:
                                  imported[item.identity]?.sourceSha256 ==
                                      item.sha256
                                  ? 'Play recording'
                                  : 'Prepare playback',
                              onPressed: preparing == null
                                  ? () => preparePlayback(item)
                                  : null,
                              icon: preparing == item.identity
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(),
                                    )
                                  : Icon(
                                      imported[item.identity]?.sourceSha256 ==
                                              item.sha256
                                          ? Icons.play_arrow
                                          : Icons.audio_file_outlined,
                                    ),
                            ),
                          ],
                        )
                      : null,
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            const Center(child: Text('Recording status is unavailable')),
      ),
    );
  }

  String status(CompanionRecording item, bool ready, bool paused) =>
      switch (item.state) {
        CompanionRecordingState.downloaded => 'Saved on phone',
        CompanionRecordingState.failed => 'Download failed',
        CompanionRecordingState.downloading =>
          ready ? 'Downloading' : 'Interrupted transfer — awaiting recovery',
        CompanionRecordingState.pending =>
          paused
              ? 'Waiting — downloads paused'
              : ready
              ? 'Queued for download'
              : 'Waiting for connection',
      };
}
