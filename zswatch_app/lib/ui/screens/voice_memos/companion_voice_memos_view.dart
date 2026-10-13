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
import '../../../services/ai/llm_service.dart';
import '../../../services/voice_memo/transcription_engine.dart';
import '../../../services/voice_memo/voice_memo_file_store.dart';
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
              decoration: multiline
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

  Future<void> remove(List<String> identities) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete ${identities.length} recording${identities.length == 1 ? '' : 's'} from phone?',
        ),
        content: const Text(
          'Move local audio and saved notes to Recently deleted. You can restore them there. Watch originals, calendar entries and scheduled alerts remain.',
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
      await VoiceMemoFileStore.exclusive(
        () => ref.read(companionClientProvider).removeRecordings(identities),
      );
      if (mounted) {
        setState(() {
          selected.clear();
          selecting = false;
        });
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
      final llmModels = transcriptionOnly
          ? <LlmModelInfo>[]
          : await ref.read(llmAvailableModelsProvider.future);
      var selectedStt =
          prefs.getString(SettingsKeys.transcriptionEngineType) ??
          TranscriptionEngineType.whisperTinyEn.name;
      var selectedLlm =
          prefs.getString(SettingsKeys.selectedAiModelId) ??
          LlmService.defaultModelId;
      if (!transcriptionOnly &&
          !llmModels.any((model) => model.id == selectedLlm)) {
        selectedLlm = LlmService.defaultModelId;
      }
      if (!mounted) return;
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(switch (operation) {
              'transcribe' => 'Transcribe recording',
              'retranscribe' => 'Re-transcribe recording',
              'reanalyze' => 'Re-analyze transcript',
              _ => 'Process recording locally',
            }),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Uses models already downloaded on this phone. Audio stays on the phone.',
                ),
                if (operation != 'reanalyze')
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
                if (!transcriptionOnly)
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
                          recording.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        Text(jobLabel(job)),
                        if (ref
                                .read(companionSnapshotProvider)
                                .asData
                                ?.value
                                .isIos ==
                            true)
                          PopupMenuButton<String>(
                            tooltip: 'Saved revisions',
                            onSelected: (other) {
                              Navigator.pop(context);
                              unawaited(showJob(other, recording));
                            },
                            itemBuilder: (_) => [
                              for (final version
                                  in (ref
                                                  .read(
                                                    companionSnapshotProvider,
                                                  )
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
                              if (ref
                                          .read(companionSnapshotProvider)
                                          .asData
                                          ?.value
                                          .isIos ==
                                      true &&
                                  job['selected'] == true &&
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
    'transcribed' => 'Transcribed',
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
    final canProcess = ready || snapshot?.isIos == true;
    final paused = snapshot?.fields['recording_sync_enabled'] == false;
    final watchId = snapshot?.fields['address'];
    final ios = snapshot?.isIos == true;
    final matches = ios && query.isNotEmpty
        ? ref.watch(companionRecordingSearchProvider(query))
        : null;
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
          if (ios)
            IconButton(
              tooltip: 'Earlier recordings',
              icon: const Icon(Icons.history),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const RetainedVoiceMemosView(),
                ),
              ),
            ),
          if (ios)
            IconButton(
              tooltip: selecting ? 'Cancel selection' : 'Select recordings',
              icon: Icon(selecting ? Icons.close : Icons.checklist),
              onPressed: modifying
                  ? null
                  : () => setState(() {
                      selecting = !selecting;
                      selected.clear();
                    }),
            ),
          IconButton(
            tooltip: 'Alarms & Timers',
            icon: const Icon(Icons.alarm_outlined),
            onPressed: () => context.push(AppRoutes.alarmsTimers),
          ),
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
          final watchItems = all
              .where((item) => item.watchId == watchId)
              .toList();
          final saved = watchItems
              .where((item) => item.hasCommittedReceipt)
              .length;
          final items = watchItems
              .where((item) {
                if (item.purged && !item.purgePending) return false;
                if (filter == _RecordingFilter.deleted) {
                  return item.state == CompanionRecordingState.deleted;
                }
                if (item.state == CompanionRecordingState.deleted) return false;
                if (filter == _RecordingFilter.archived
                    ? !item.archived
                    : item.archived) {
                  return false;
                }
                final types =
                    jobs[item.identity]?['action_types'] as List? ?? [];
                if (filter == _RecordingFilter.tasks &&
                    !types.contains('task')) {
                  return false;
                }
                if (filter == _RecordingFilter.reminders &&
                    !types.contains('reminder')) {
                  return false;
                }
                if (filter == _RecordingFilter.alerts &&
                    !types.any((type) => type == 'timer' || type == 'alarm')) {
                  return false;
                }
                if (filter == _RecordingFilter.notes && types.isNotEmpty) {
                  return false;
                }
                return true;
              })
              .where(
                (item) =>
                    query.isEmpty ||
                    item.title.toLowerCase().contains(query) ||
                    item.filename.toLowerCase().contains(query) ||
                    matches?.asData?.value.contains(item.identity) == true,
              )
              .toList();
          final selection = watchItems
              .where(
                (item) =>
                    selected.contains(item.identity) &&
                    item.hasCommittedReceipt,
              )
              .map((item) => item.identity)
              .toSet();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('${items.length} recordings • $saved saved on phone'),
              if (ios) ...[
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
                Wrap(
                  spacing: 8,
                  children: [
                    for (final option in _RecordingFilter.values)
                      ChoiceChip(
                        label: Text(switch (option) {
                          _RecordingFilter.all => 'All',
                          _RecordingFilter.notes => 'Notes',
                          _RecordingFilter.tasks => 'Tasks',
                          _RecordingFilter.reminders => 'Reminders',
                          _RecordingFilter.alerts => 'Timers & Alarms',
                          _RecordingFilter.archived => 'Archived',
                          _RecordingFilter.deleted => 'Recently deleted',
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
                  const Text(
                    'Transcript search is unavailable. Showing title matches.',
                  ),
                if (filter == _RecordingFilter.deleted)
                  const Text(
                    'Restore recordings or delete them permanently to free phone storage. Watch originals remain.',
                  ),
                if (selecting && selection.isNotEmpty) ...[
                  Text('${selection.length} selected'),
                  Wrap(
                    children: [
                      TextButton(
                        onPressed: modifying
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
                                if (mounted) {
                                  setState(() {
                                    selected.clear();
                                    selecting = false;
                                  });
                                }
                              }),
                        child: Text(
                          filter == _RecordingFilter.archived
                              ? 'Unarchive selected'
                              : 'Archive selected',
                        ),
                      ),
                      TextButton(
                        onPressed: modifying
                            ? null
                            : () => remove(selection.toList()),
                        child: const Text('Delete selected'),
                      ),
                    ],
                  ),
                  CompanionVoiceBatchButton(
                    operation: 'transcribe',
                    label: 'Transcribe selected',
                    identities: selection,
                  ),
                  CompanionVoiceBatchButton(
                    operation: 'process',
                    label: 'Process selected',
                    identities: selection,
                  ),
                ],
              ],
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
              if (snapshot?.isIos == true)
                const Text(
                  'Processing runs while the app is open or when iOS schedules background time.',
                ),
              const SizedBox(height: 16),
              const CompanionVoiceBatchButton(
                operation: 'transcribe',
                label: 'Transcribe all untranscribed',
              ),
              const CompanionVoiceBatchButton(
                operation: 'process',
                label: 'Process all unprocessed',
              ),
              if (items.isEmpty)
                const Text('No recordings saved for this watch'),
              for (final item in items)
                ListTile(
                  key: ValueKey(item.identity),
                  leading: selecting && item.hasCommittedReceipt
                      ? Checkbox(
                          value: selected.contains(item.identity),
                          onChanged: modifying
                              ? null
                              : (value) => setState(() {
                                  if (value == true && selected.length < 100) {
                                    selected.add(item.identity);
                                  } else {
                                    selected.remove(item.identity);
                                  }
                                }),
                        )
                      : Icon(
                          item.hasCommittedReceipt
                              ? Icons.file_download_done
                              : Icons.mic,
                        ),
                  title: Text(item.title),
                  onTap: selecting && item.hasCommittedReceipt
                      ? () => setState(() {
                          if (!selected.remove(item.identity) &&
                              selected.length < 100) {
                            selected.add(item.identity);
                          }
                        })
                      : jobs[item.identity] == null
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
                  trailing: ios && item.state == CompanionRecordingState.deleted
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
                      : item.hasCommittedReceipt
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Process recording locally',
                              onPressed: canProcess
                                  ? () => processRecording(item)
                                  : null,
                              icon: const Icon(Icons.auto_awesome),
                            ),
                            PopupMenuButton<String>(
                              key: ValueKey('recording-menu:${item.identity}'),
                              tooltip: 'Transcription actions',
                              enabled: canProcess,
                              onSelected: (operation) =>
                                  recordingAction(operation, item),
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: 'transcribe',
                                  child: Text('Transcribe only'),
                                ),
                                const PopupMenuItem(
                                  value: 'retranscribe',
                                  child: Text('Re-transcribe'),
                                ),
                                const PopupMenuItem(
                                  value: 'reanalyze',
                                  child: Text('Re-analyze transcript'),
                                ),
                                const PopupMenuItem(
                                  value: 'export',
                                  child: Text('Export audio'),
                                ),
                                if (ios) ...[
                                  const PopupMenuItem(
                                    value: 'rename',
                                    child: Text('Rename'),
                                  ),
                                  PopupMenuItem(
                                    value: 'archive',
                                    child: Text(
                                      item.archived ? 'Unarchive' : 'Archive',
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete from phone'),
                                  ),
                                ],
                              ],
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
        CompanionRecordingState.deleted =>
          item.purgePending
              ? 'Deletion awaiting cleanup'
              : 'Recently deleted',
      };
}
