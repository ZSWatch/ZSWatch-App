import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../data/database/companion_recording_database.dart'
    show ImportedRecording;
import '../../../data/models/companion_recording.dart';
import '../../../providers/companion_runtime_providers.dart';
import '../../../providers/settings_providers.dart';
import '../../../providers/ai_providers.dart';
import '../../../providers/openrouter_providers.dart';
import '../../../services/ai/llm_service.dart';
import '../../../services/ai/openrouter_client.dart';
import '../../../services/ai/voice_model_config.dart';
import '../../../services/voice_memo/transcription_engine.dart';
import '../../../services/voice_memo/voice_memo_file_store.dart';
import '../../../services/voice_memo/voice_note_tidy.dart';
import '../../../providers/companion_recording_import_providers.dart';
import '../../widgets/voice_memos/audio_playback_bar.dart';
import '../../widgets/voice_memos/companion_voice_action_card.dart';
import '../../widgets/companion_voice_batch_button.dart';
import '../../navigation/app_router.dart';
import 'retained_voice_memos_view.dart';

enum _RecordingFilter {
  all,
  notes,
  tasks,
  reminders,
  alerts,
  archived,
  deleted,
}

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
  final search = TextEditingController();
  Timer? searchTimer;
  String query = '';
  _RecordingFilter filter = _RecordingFilter.all;
  bool selecting = false;
  bool modifying = false;
  final selected = <String>{};
  Object? tidiedCursor;
  bool tidying = false;

  @override
  void dispose() {
    searchTimer?.cancel();
    search.dispose();
    super.dispose();
  }

  Future<void> modify(Future<void> Function() action) async {
    if (modifying) return;
    setState(() => modifying = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not save this change. Your recordings are retained.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => modifying = false);
    }
  }

  Future<String?> editText(
    String title,
    String value, {
    bool multiline = false,
  }) async {
    final controller = TextEditingController(text: value);
    try {
      return await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 480,
            child: TextField(
              controller: controller,
              autofocus: true,
              maxLength: multiline ? 16000 : 64,
              maxLines: multiline ? 10 : 1,
              decoration:
                  multiline && ref.read(voiceModelConfigProvider).canAnalyze
                  ? const InputDecoration(
                      helperText:
                          'Analyze again to update the summary and action drafts.',
                    )
                  : null,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  Navigator.pop(context, controller.text.trim());
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> purge(CompanionRecording recording) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete permanently from phone?'),
        content: const Text(
          'Permanently remove this local audio, saved notes and action history. You cannot restore them. The watch original, calendar entries and scheduled alerts remain.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete permanently'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    await modify(
      () => VoiceMemoFileStore.exclusive(
        () => ref.read(companionClientProvider).purgeRecordings([
          recording.identity,
        ]),
      ),
    );
  }

  Future<void> purgeAll(List<String> identities) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Permanently delete ${identities.length} recording${identities.length == 1 ? '' : 's'}?',
        ),
        content: const Text(
          'Permanently remove all Recently deleted audio, saved notes and action history from this phone. You cannot restore them. Watch originals, calendar entries and scheduled alerts remain.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete all permanently'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    await modify(
      () => VoiceMemoFileStore.exclusive(() async {
        for (final batch in _batches(identities)) {
          await ref.read(companionClientProvider).purgeRecordings(batch);
        }
      }),
    );
  }

  /// Native calls take at most 100 recordings each.
  static Iterable<List<String>> _batches(List<String> identities) sync* {
    for (var start = 0; start < identities.length; start += 100) {
      yield identities.sublist(
        start,
        start + 100 > identities.length ? identities.length : start + 100,
      );
    }
  }

  Future<void> remove(List<String> identities) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete ${identities.length} recording${identities.length == 1 ? '' : 's'} from phone?',
        ),
        content: const Text(
          'Move local audio and saved notes to Deleted. You can restore them there for 30 days. Watch originals, calendar entries and scheduled alerts remain.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete from phone'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    await modify(() async {
      await VoiceMemoFileStore.exclusive(() async {
        for (final batch in _batches(identities)) {
          await ref.read(companionClientProvider).removeRecordings(batch);
        }
      });
      if (mounted) {
        setState(() {
          selected.clear();
          selecting = false;
        });
      }
    });
  }

  /// Runs after each native change; failures leave the list as it is.
  void tidy(
    List<CompanionRecording> items,
    Map<String, Map<Object?, Object?>> jobs,
    Object? cursor,
  ) {
    if (tidying || cursor == tidiedCursor) return;
    tidying = true;
    tidiedCursor = cursor;
    final client = ref.read(companionClientProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (!mounted) return;
        await VoiceNoteTidy.apply(
          recordings: items,
          jobs: jobs,
          prefs: await ref.read(sharedPreferencesProvider.future),
          client: client,
        );
      } catch (error) {
        debugPrint('[CompanionVoiceMemosView] tidy skipped: $error');
      } finally {
        tidying = false;
      }
    });
  }

  Future<void> shareFile(File file) async {
    if (!mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    await Share.shareXFiles(
      [XFile(file.path)],
      sharePositionOrigin: box == null
          ? null
          : box.localToGlobal(Offset.zero) & box.size,
    );
  }

  Future<void> exportAudio(CompanionRecording recording) => modify(() async {
    final imported = await ref.read(companionPreparePlaybackProvider)(
      recording,
    );
    await ref
        .read(companionRecordingExporterProvider)
        .audio(imported, shareFile);
  });

  Future<void> recordingAction(
    String operation,
    CompanionRecording recording,
  ) async {
    final client = ref.read(companionClientProvider);
    switch (operation) {
      case 'rename':
        final value = await editText('Recording title', recording.title);
        if (value != null) {
          await modify(
            () => client.updateRecording(recording.identity, title: value),
          );
        }
      case 'archive':
        await modify(
          () => client.updateRecording(
            recording.identity,
            archived: !recording.archived,
          ),
        );
      case 'delete':
        await remove([recording.identity]);
      case 'restore':
        await modify(() => client.restoreRecording(recording.identity));
      case 'export':
        await exportAudio(recording);
      default:
        await processRecording(recording, operation: operation);
    }
  }

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
                  recording.title,
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

  Future<void> processRecording(
    CompanionRecording recording, {
    String operation = 'process',
  }) async {
    try {
      final transcriptionOnly = [
        'transcribe',
        'retranscribe',
      ].contains(operation);
      final prefs = await ref.read(sharedPreferencesProvider.future);
      final config = VoiceModelConfig.fromPrefs(prefs);
      final llmModels = transcriptionOnly || config.cloud
          ? <LlmModelInfo>[]
          : await ref.read(llmAvailableModelsProvider.future);
      var selectedStt =
          prefs.getString(SettingsKeys.transcriptionEngineType) ??
          TranscriptionEngineType.whisperTinyEn.name;
      var selectedLlm =
          prefs.getString(SettingsKeys.selectedAiModelId) ??
          LlmService.defaultModelId;
      if (!transcriptionOnly &&
          !config.cloud &&
          !llmModels.any((model) => model.id == selectedLlm)) {
        selectedLlm = LlmService.defaultModelId;
      }
      if (config.cloud) {
        selectedStt = config.transcriptionModel;
        selectedLlm = config.analysisModel;
      }
      if (!mounted) return;
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(switch (operation) {
              'transcribe' => 'Transcribe recording',
              'retranscribe' => 'Transcribe recording again',
              'reanalyze' => 'Analyze transcript again',
              _ =>
                config.cloud
                    ? 'Process recording'
                    : 'Process recording locally',
            }),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  config.cloud
                      ? 'Sends the ${operation == 'reanalyze' ? 'transcript' : 'recording'} to OpenRouter '
                            '(${openRouterModelId(config.analysisModel)}) with zero data retention.'
                      : 'Uses models already downloaded on this phone. Audio stays on the phone.',
                ),
                if (operation != 'reanalyze' && !config.cloud)
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
                if (!transcriptionOnly && !config.cloud)
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
                child: Text(transcriptionOnly ? 'Transcribe' : 'Process'),
              ),
            ],
          ),
        ),
      );
      if (accepted != true) return;
      await ref.read(companionClientProvider).processRecording({
        'identity': recording.identity,
        'operation': operation,
        'transcription_model': selectedStt,
        'analysis_model': selectedLlm,
        'correct_transcription': config.correctTranscription,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${config.cloud ? 'Processing' : 'Local processing'} queued. '
              'You can close the app.',
            ),
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
                          recording.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        Text(jobLabel(job)),
                        PopupMenuButton<String>(
                          tooltip: 'Saved revisions',
                          onSelected: (other) {
                            Navigator.pop(context);
                            unawaited(showJob(other, recording));
                          },
                          itemBuilder: (_) => [
                            for (final version
                                in (ref
                                                .read(companionSnapshotProvider)
                                                .asData
                                                ?.value
                                                .fields['voice_jobs']
                                            as List? ??
                                        [])
                                    .whereType<Map<Object?, Object?>>())
                              if (version['recording_id'] ==
                                      recording.identity &&
                                  version['job_id'] != id)
                                PopupMenuItem(
                                  value: version['job_id'] as String,
                                  child: Text(
                                    'Revision ${version['generation']} • ${jobLabel(version)}',
                                  ),
                                ),
                          ],
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('Saved revisions'),
                          ),
                        ),
                        if (job['last_error'] != null &&
                            [
                              'ready',
                              'waiting_remote',
                              'failed',
                              'blocked',
                            ].contains(job['state']))
                          Text('Reason: ${job['last_error']}'),
                        if (job['state'] == 'blocked' &&
                            job['last_error'] == 'model_missing') ...[
                          const Text(
                            'Download the selected models in Voice memo models, then retry processing.',
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              this.context.push(AppRoutes.aiModels);
                            },
                            child: const Text('Download models'),
                          ),
                        ],
                        if (text is String) ...[
                          const SizedBox(height: 16),
                          const Text('Transcript'),
                          SelectableText(text),
                          Wrap(
                            children: [
                              TextButton.icon(
                                icon: const Icon(Icons.copy),
                                label: const Text('Copy transcript'),
                                onPressed: () => Clipboard.setData(
                                  ClipboardData(text: text),
                                ),
                              ),
                              if (job['selected'] == true &&
                                  recording.state !=
                                      CompanionRecordingState.deleted)
                                TextButton.icon(
                                  icon: const Icon(Icons.edit_outlined),
                                  label: const Text('Edit transcript'),
                                  onPressed: () async {
                                    final value = await editText(
                                      'Edit transcript',
                                      text,
                                      multiline: true,
                                    );
                                    if (value == null) return;
                                    await modify(() async {
                                      final edited = await ref
                                          .read(companionClientProvider)
                                          .editVoiceTranscript(id, value);
                                      ref.invalidate(
                                        companionVoiceJobProvider(id),
                                      );
                                      if (context.mounted) {
                                        Navigator.pop(context);
                                        unawaited(showJob(edited, recording));
                                      }
                                    });
                                  },
                                ),
                              TextButton.icon(
                                icon: const Icon(Icons.ios_share),
                                label: const Text('Export text'),
                                onPressed: () => modify(
                                  () => ref
                                      .read(companionRecordingExporterProvider)
                                      .text(
                                        recording.filename,
                                        text,
                                        result?['summary'] as String? ?? '',
                                        shareFile,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (result != null &&
                            (result['summary'] as String).isNotEmpty) ...[
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
                        if (pending &&
                            recording.state != CompanionRecordingState.deleted)
                          TextButton(
                            onPressed: () async {
                              await ref
                                  .read(companionClientProvider)
                                  .voiceJob(id, cancel: true);
                              ref.invalidate(companionVoiceJobProvider(id));
                            },
                            child: const Text('Cancel job'),
                          ),
                        if (recording.hasCommittedReceipt &&
                            [
                              'failed',
                              'cancelled',
                              'blocked',
                            ].contains(job['state']))
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              processRecording(
                                recording,
                                operation:
                                    ref
                                        .read(voiceModelConfigProvider)
                                        .canAnalyze
                                    ? 'process'
                                    : 'transcribe',
                              );
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
    'transcribed' => 'Transcribed',
    'ready' =>
      job['processing'] == true
          ? job['transcript_saved'] == true
                ? 'Analyzing'
                : 'Transcribing'
          : 'Queued',
    'result_ready' ||
    'delivered' when job['undone'] == true => 'Processed • Undone',
    'result_ready' => 'Processed • Waiting for watch',
    'delivered' => 'Processed • Shown on watch',
    'cancelled' => 'Cancelled',
    'failed' => switch (job['last_error']) {
      'no_speech' => 'No speech detected',
      'analysis_empty' => 'Analysis found nothing to summarize',
      _ => 'Processing failed',
    },
    'blocked' =>
      job['last_error'] == 'model_missing'
          ? 'Selected model not downloaded'
          : 'Waiting for processing permission',
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
    final canProcess = ready || snapshot?.isIos == true;
    final paused = snapshot?.fields['recording_sync_enabled'] == false;
    final watchId = snapshot?.fields['address'];
    final matches = query.isNotEmpty
        ? ref.watch(companionRecordingSearchProvider(query))
        : null;
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
    final watchItems = (recordings.asData?.value ?? <CompanionRecording>[])
        .where((item) => item.watchId == watchId)
        .toList();
    final items = watchItems
        .where((item) {
          if (item.purged && !item.purgePending) return false;
          if (filter == _RecordingFilter.deleted) {
            return item.state == CompanionRecordingState.deleted;
          }
          if (item.state == CompanionRecordingState.deleted) return false;
          // Searching the inbox also finds finished notes.
          if (filter == _RecordingFilter.archived
              ? !item.archived
              : item.archived &&
                    (filter != _RecordingFilter.all || query.isEmpty)) {
            return false;
          }
          final types = jobs[item.identity]?['action_types'] as List? ?? [];
          return switch (filter) {
            _RecordingFilter.tasks => types.contains('task'),
            _RecordingFilter.reminders => types.contains('reminder'),
            _RecordingFilter.alerts => types.any(
              (type) => type == 'timer' || type == 'alarm',
            ),
            _RecordingFilter.notes => types.isEmpty,
            _ => true,
          };
        })
        .where(
          (item) =>
              query.isEmpty ||
              item.title.toLowerCase().contains(query) ||
              item.filename.toLowerCase().contains(query) ||
              matches?.asData?.value.contains(item.identity) == true,
        )
        .toList();
    final selectable = items
        .where((item) => item.hasCommittedReceipt)
        .map((item) => item.identity)
        .toSet();
    final selection = selected.intersection(selectable);
    final failed = watchItems.any(
      (item) => !item.purged && item.state == CompanionRecordingState.failed,
    );
    final canAnalyze = ref.watch(voiceModelConfigProvider).canAnalyze;
    if (recordings.hasValue && snapshot != null) {
      tidy(watchItems, jobs, snapshot.fields['event_cursor']);
    }
    void stopSelecting() => setState(() {
      selecting = false;
      selected.clear();
    });
    return PopScope(
      canPop: !selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) stopSelecting();
      },
      child: Scaffold(
        appBar: selecting
            ? AppBar(
                leading: IconButton(
                  tooltip: 'Cancel selection',
                  icon: const Icon(Icons.close),
                  onPressed: modifying ? null : stopSelecting,
                ),
                title: Text('${selection.length} selected'),
                actions: [
                  IconButton(
                    tooltip:
                        selectable.isNotEmpty &&
                            selection.length == selectable.length
                        ? 'Deselect all'
                        : 'Select all',
                    icon: const Icon(Icons.select_all),
                    onPressed: modifying || selectable.isEmpty
                        ? null
                        : () => setState(() {
                            if (selection.length == selectable.length) {
                              selected.clear();
                            } else {
                              selected.addAll(selectable);
                            }
                          }),
                  ),
                  IconButton(
                    tooltip: 'Transcribe or process selected',
                    icon: const Icon(Icons.auto_awesome),
                    onPressed: modifying || selection.isEmpty
                        ? null
                        : () => showBatchSheet(selection),
                  ),
                  IconButton(
                    tooltip: filter == _RecordingFilter.archived
                        ? 'Mark selected not done'
                        : 'Mark selected done',
                    icon: Icon(
                      filter == _RecordingFilter.archived
                          ? Icons.remove_done
                          : Icons.done_all,
                    ),
                    onPressed: modifying || selection.isEmpty
                        ? null
                        : () => modify(() async {
                            for (final identity in selection) {
                              await ref
                                  .read(companionClientProvider)
                                  .updateRecording(
                                    identity,
                                    archived:
                                        filter != _RecordingFilter.archived,
                                  );
                            }
                            if (mounted) stopSelecting();
                          }),
                  ),
                  IconButton(
                    tooltip: 'Delete selected',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: modifying || selection.isEmpty
                        ? null
                        : () => remove(selection.toList()),
                  ),
                ],
              )
            : AppBar(
                title: const Text('Voice Notes'),
                actions: [
                  IconButton(
                    tooltip: 'Alarms & Timers',
                    icon: const Icon(Icons.alarm_outlined),
                    onPressed: () => context.push(AppRoutes.alarmsTimers),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'More options',
                    onSelected: (choice) async {
                      switch (choice) {
                        case 'select':
                          setState(() => selecting = true);
                        case 'batch':
                          await showBatchSheet(null);
                        case 'refresh':
                          await refreshList();
                        case 'sync':
                          await modify(
                            () => ref
                                .read(companionClientProvider)
                                .setRecordingSync(paused),
                          );
                        case 'earlier':
                          await Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const RetainedVoiceMemosView(),
                            ),
                          );
                      }
                    },
                    itemBuilder: (_) => [
                      _menuItem('select', Icons.checklist, 'Select recordings'),
                      _menuItem(
                        'batch',
                        Icons.auto_awesome,
                        'Transcribe or process all',
                      ),
                      _menuItem(
                        'refresh',
                        Icons.refresh,
                        'Refresh recording list',
                        enabled: ready && !refreshing,
                      ),
                      _menuItem(
                        'sync',
                        paused ? Icons.play_arrow : Icons.pause,
                        paused ? 'Resume downloads' : 'Pause downloads',
                        enabled: !modifying,
                      ),
                      _menuItem('earlier', Icons.history, 'Earlier recordings'),
                    ],
                  ),
                ],
              ),
        body: recordings.when(
          skipLoadingOnRefresh: false,
          skipLoadingOnReload: false,
          data: (_) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              TextField(
                controller: search,
                maxLength: 128,
                decoration: const InputDecoration(
                  hintText: 'Search titles, transcripts or actions',
                  prefixIcon: Icon(Icons.search),
                  counterText: '',
                ),
                onChanged: (text) {
                  searchTimer?.cancel();
                  searchTimer = Timer(const Duration(milliseconds: 200), () {
                    if (mounted) {
                      setState(() => query = text.trim().toLowerCase());
                    }
                  });
                },
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final option in _RecordingFilter.values)
                    ChoiceChip(
                      visualDensity: VisualDensity.compact,
                      label: Text(switch (option) {
                        _RecordingFilter.all => 'Inbox',
                        _RecordingFilter.notes => 'Notes',
                        _RecordingFilter.tasks => 'Tasks',
                        _RecordingFilter.reminders => 'Reminders',
                        _RecordingFilter.alerts => 'Alarms',
                        _RecordingFilter.archived => 'Done',
                        _RecordingFilter.deleted => 'Deleted',
                      }),
                      selected: filter == option,
                      onSelected: (_) => setState(() {
                        filter = option;
                        selected.clear();
                      }),
                    ),
                ],
              ),
              if (matches?.isLoading == true) const LinearProgressIndicator(),
              if (matches?.hasError == true)
                _notice(
                  Icons.search_off,
                  'Transcript search is unavailable. Showing title matches.',
                ),
              if (!ready)
                _notice(
                  Icons.watch_off_outlined,
                  'Watch disconnected — showing saved recordings',
                )
              else if (paused)
                _notice(
                  Icons.pause_circle_outline,
                  'Downloads paused',
                  action: 'Resume',
                  onPressed: modifying
                      ? null
                      : () => modify(
                          () => ref
                              .read(companionClientProvider)
                              .setRecordingSync(true),
                        ),
                ),
              if (failed)
                _notice(
                  Icons.error_outline,
                  'Some downloads failed',
                  action: 'Retry',
                  onPressed: ready && !modifying
                      ? () => modify(
                          () => ref
                              .read(companionClientProvider)
                              .command('retryRecordings'),
                        )
                      : null,
                ),
              if (imports.hasError)
                _notice(
                  Icons.error_outline,
                  'Playback is unavailable',
                  action: 'Retry',
                  onPressed: () =>
                      ref.invalidate(companionRecordingImportsProvider),
                ),
              if (filter == _RecordingFilter.deleted)
                _notice(
                  Icons.info_outline,
                  'Deleted recordings are removed from this phone after 30 days. Watch originals remain.',
                  action: items.isEmpty || query.isNotEmpty
                      ? null
                      : 'Delete all permanently',
                  onPressed: modifying
                      ? null
                      : () => purgeAll(
                          items.map((item) => item.identity).toList(),
                        ),
                ),
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      filter == _RecordingFilter.all && query.isEmpty
                          ? 'All caught up. Finished notes move to Done.'
                          : 'No recordings here',
                    ),
                  ),
                ),
              for (final item in items)
                recordingTile(
                  item,
                  jobs[item.identity],
                  imported[item.identity],
                  ready: ready,
                  paused: paused,
                  canProcess: canProcess,
                  canAnalyze: canAnalyze,
                ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) =>
              const Center(child: Text('Recording status is unavailable')),
        ),
      ),
    );
  }

  static PopupMenuItem<String> _menuItem(
    String value,
    IconData icon,
    String label, {
    bool enabled = true,
  }) => PopupMenuItem(
    value: value,
    enabled: enabled,
    child: ListTile(
      leading: Icon(icon),
      title: Text(label),
      contentPadding: EdgeInsets.zero,
      dense: true,
    ),
  );

  Widget _notice(
    IconData icon,
    String text, {
    String? action,
    VoidCallback? onPressed,
  }) => Card(
    margin: const EdgeInsets.only(top: 8),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
          if (action != null)
            TextButton(onPressed: onPressed, child: Text(action)),
        ],
      ),
    ),
  );

  Future<void> showBatchSheet(Set<String>? identities) =>
      showModalBottomSheet<void>(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CompanionVoiceBatchButton(
                operation: 'transcribe',
                label: identities == null
                    ? 'Transcribe all untranscribed'
                    : 'Transcribe selected',
                identities: identities,
                onQueued: () => Navigator.pop(context),
              ),
              CompanionVoiceBatchButton(
                operation: 'process',
                label: identities == null
                    ? 'Process all unprocessed'
                    : 'Process selected',
                identities: identities,
                onQueued: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      );

  Widget recordingTile(
    CompanionRecording item,
    Map<Object?, Object?>? job,
    ImportedRecording? playback, {
    required bool ready,
    required bool paused,
    required bool canProcess,
    required bool canAnalyze,
  }) {
    final saved = item.hasCommittedReceipt;
    final hasTranscript =
        job != null &&
        (job['transcript_saved'] == true ||
            [
              'transcribed',
              'result_ready',
              'delivered',
            ].contains(job['state']));
    final details = [
      if (item.state != CompanionRecordingState.downloaded)
        status(item, ready, paused),
      if (job != null) jobLabel(job),
    ].join(' • ');
    final prepared = playback?.sourceSha256 == item.sha256;
    void toggle() => setState(() {
      if (!selected.remove(item.identity)) selected.add(item.identity);
    });
    return ListTile(
      key: ValueKey(item.identity),
      contentPadding: EdgeInsets.zero,
      leading: selecting && saved
          ? Checkbox(
              value: selected.contains(item.identity),
              onChanged: modifying ? null : (_) => toggle(),
            )
          : saved && item.state != CompanionRecordingState.deleted
          ? IconButton(
              tooltip: prepared ? 'Play recording' : 'Prepare playback',
              onPressed: preparing == null ? () => preparePlayback(item) : null,
              icon: preparing == item.identity
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(),
                    )
                  : const Icon(Icons.play_circle_outline),
            )
          : SizedBox.square(
              dimension: 48,
              child: Icon(switch (item.state) {
                CompanionRecordingState.failed => Icons.error_outline,
                CompanionRecordingState.deleted => Icons.delete_outline,
                _ => Icons.downloading,
              }),
            ),
      title: Text(item.title),
      subtitle: Text(
        '${DateFormat.yMMMd().add_Hm().format(item.timestampUtc.toLocal())} • '
        '${(item.durationMs / 1000).toStringAsFixed(1)} s'
        '${details.isEmpty ? '' : '\n$details'}',
      ),
      isThreeLine: details.isNotEmpty,
      onTap: selecting
          ? (saved && !modifying ? toggle : null)
          : job != null
          ? () => showJob(job['job_id'] as String, item)
          : saved && item.state != CompanionRecordingState.deleted
          ? () => preparePlayback(item)
          : null,
      onLongPress: !selecting && saved && !modifying
          ? () => setState(() {
              selecting = true;
              selected.add(item.identity);
            })
          : null,
      trailing: item.state == CompanionRecordingState.deleted
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!item.purged)
                  TextButton(
                    onPressed: modifying
                        ? null
                        : () => recordingAction('restore', item),
                    child: const Text('Restore'),
                  ),
                IconButton(
                  tooltip: item.purgePending
                      ? 'Retry permanent deletion'
                      : 'Delete permanently from phone',
                  onPressed: modifying ? null : () => purge(item),
                  icon: const Icon(Icons.delete_forever),
                ),
              ],
            )
          : saved && !selecting
          ? PopupMenuButton<String>(
              key: ValueKey('recording-menu:${item.identity}'),
              tooltip: 'Recording actions',
              onSelected: (operation) => recordingAction(operation, item),
              itemBuilder: (_) => [
                if (canAnalyze)
                  _menuItem(
                    'process',
                    Icons.auto_awesome,
                    'Process with AI',
                    enabled: canProcess,
                  ),
                _menuItem(
                  hasTranscript ? 'retranscribe' : 'transcribe',
                  Icons.subtitles_outlined,
                  'Transcribe',
                  enabled: canProcess,
                ),
                if (canAnalyze && hasTranscript)
                  _menuItem(
                    'reanalyze',
                    Icons.psychology_outlined,
                    'Analyze again',
                    enabled: canProcess,
                  ),
                const PopupMenuDivider(),
                _menuItem(
                  'archive',
                  item.archived
                      ? Icons.remove_done
                      : Icons.check_circle_outline,
                  item.archived ? 'Mark not done' : 'Mark done',
                ),
                _menuItem('export', Icons.ios_share, 'Export audio'),
                _menuItem('rename', Icons.edit_outlined, 'Rename'),
                _menuItem('delete', Icons.delete_outline, 'Delete'),
              ],
            )
          : null,
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
        CompanionRecordingState.deleted =>
          item.purgePending ? 'Deletion awaiting cleanup' : 'Recently deleted',
      };
}
