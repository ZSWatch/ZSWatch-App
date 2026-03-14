import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/extracted_action.dart';
import '../../../data/models/voice_memo.dart';
import '../../../providers/ai_providers.dart';
import '../../../providers/settings_providers.dart';
import '../../../services/ai/extracted_action_creation_service.dart';
import '../../widgets/ai_debug_widgets.dart';
import '../../../providers/voice_memo_providers.dart';
import '../../../providers/watch_service_provider.dart';
import '../../../services/ai/ai_debug_info.dart';
import '../../../services/voice_memo/transcription_engine.dart';
import '../../../services/voice_memo/voice_memo_sync_service.dart';
import '../../navigation/app_router.dart';

/// Transcript-first timeline view for synced voice notes.
class VoiceMemosScreen extends ConsumerStatefulWidget {
  const VoiceMemosScreen({super.key});

  @override
  ConsumerState<VoiceMemosScreen> createState() => _VoiceMemosScreenState();
}

class _VoiceMemosScreenState extends ConsumerState<VoiceMemosScreen> {
  late final TextEditingController _searchController;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController()
      ..addListener(() {
        if (!mounted) {
          return;
        }
        setState(() => _query = _searchController.text.trim().toLowerCase());
      });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoSync();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _autoSync() {
    final isConnected = ref.read(isWatchConnectedProvider);
    if (isConnected) {
      ref.read(voiceMemoActionsProvider.notifier).sync();
    }
  }

  void _openMemo(VoiceMemo memo) {
    context.push(AppRoutes.voiceMemoDetail(memo.id), extra: memo);
  }

  @override
  Widget build(BuildContext context) {
    final memosAsync = ref.watch(voiceMemoListProvider);
    final syncStateAsync = ref.watch(voiceMemoSyncStateProvider);
    final transcriptionConfiguredAsync =
        ref.watch(transcriptionConfiguredProvider);
    final isConnected = ref.watch(isWatchConnectedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Notes'),
        actions: [
          if (isConnected)
            IconButton(
              icon: const Icon(Icons.sync),
              tooltip: 'Sync from watch',
              onPressed: () => ref.read(voiceMemoActionsProvider.notifier).sync(),
            ),
        ],
      ),
      body: Column(
        children: [
          syncStateAsync.when(
            data: (syncState) => _SyncProgressBar(state: syncState),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          if (!isConnected)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingMd,
                vertical: AppTheme.spacingSm,
              ),
              color: Colors.orange.withValues(alpha: 0.15),
              child: Row(
                children: [
                  const Icon(
                    Icons.bluetooth_disabled,
                    size: 16,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: AppTheme.spacingSm),
                  Expanded(
                    child: Text(
                      'Connect to your watch to sync new notes',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.orange,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          transcriptionConfiguredAsync.when(
            data: (configured) {
              if (configured) {
                return const SizedBox.shrink();
              }

              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: AppTheme.spacingSm),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingMd,
                  vertical: AppTheme.spacingSm,
                ),
                color: AppTheme.warningColor.withValues(alpha: 0.15),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.settings_suggest,
                      size: 16,
                      color: AppTheme.warningColor,
                    ),
                    const SizedBox(width: AppTheme.spacingSm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Transcription model not configured',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: AppTheme.warningColor,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Choose and download a model in Settings > Voice Memos.',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppTheme.warningColor),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.push(AppRoutes.settings),
                      child: const Text('Setup'),
                    ),
                  ],
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacingMd,
              AppTheme.spacingMd,
              AppTheme.spacingMd,
              0,
            ),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search voice notes...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: _searchController.clear,
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
          ),
          Expanded(
            child: memosAsync.when(
              data: (memos) {
                final filteredMemos = _filterMemos(memos, _query);

                return RefreshIndicator(
                  onRefresh: () =>
                      ref.read(voiceMemoActionsProvider.notifier).sync(),
                  child: filteredMemos.isEmpty
                      ? _EmptyState(hasQuery: _query.isNotEmpty)
                      : _VoiceMemoTimeline(
                          memos: filteredMemos,
                          onOpenMemo: _openMemo,
                        ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text(
                  'Error loading notes: $error',
                  style: const TextStyle(color: AppTheme.errorColor),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class VoiceMemoDetailScreen extends ConsumerStatefulWidget {
  final int memoId;
  final VoiceMemo? initialMemo;

  const VoiceMemoDetailScreen({
    super.key,
    required this.memoId,
    this.initialMemo,
  });

  @override
  ConsumerState<VoiceMemoDetailScreen> createState() =>
      _VoiceMemoDetailScreenState();
}

class _VoiceMemoDetailScreenState extends ConsumerState<VoiceMemoDetailScreen> {
  late final TextEditingController _transcriptController;
  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _transcriptController = TextEditingController(
      text: widget.initialMemo?.transcription ?? '',
    );
  }

  @override
  void dispose() {
    _transcriptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final memoAsync = ref.watch(voiceMemoByIdProvider(widget.memoId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Note'),
      ),
      body: memoAsync.when(
        data: (memo) {
          final effectiveMemo = memo ?? widget.initialMemo;
          if (effectiveMemo == null) {
            return const _MissingNoteState();
          }

          final currentTranscript = effectiveMemo.transcription ?? '';
          if (!_isEditing && _transcriptController.text != currentTranscript) {
            _transcriptController.text = currentTranscript;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              12,
              12,
              12,
              16,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final showSideBySide = constraints.maxWidth >= 430;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TopSummarySection(
                      memo: effectiveMemo,
                      sideBySide: showSideBySide,
                    ),
                    const SizedBox(height: 12),
                    _AISummarySection(memo: effectiveMemo),
                    const SizedBox(height: 12),
                    _ExtractedActionsSection(memo: effectiveMemo),
                    const SizedBox(height: 12),
                    _SectionCard(
                      title: 'Transcript',
                      trailing: IconButton(
                        tooltip: _isEditing ? 'Cancel editing' : 'Edit transcript',
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints.tightFor(
                          width: 32,
                          height: 32,
                        ),
                        onPressed: () {
                          setState(() {
                            _isEditing = !_isEditing;
                            if (!_isEditing) {
                              _transcriptController.text = currentTranscript;
                            }
                          });
                        },
                        icon: Icon(
                          _isEditing ? Icons.close_rounded : Icons.edit_outlined,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_isEditing) ...[
                            TextField(
                              controller: _transcriptController,
                              minLines: 6,
                              maxLines: null,
                              decoration: const InputDecoration(
                                hintText: 'Edit transcript text...',
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                OutlinedButton(
                                  style: _compactOutlinedButtonStyle(),
                                  onPressed: _isSaving
                                      ? null
                                      : () {
                                          setState(() {
                                            _isEditing = false;
                                            _transcriptController.text =
                                                currentTranscript;
                                          });
                                        },
                                  child: const Text('Cancel'),
                                ),
                                const SizedBox(width: AppTheme.spacingSm),
                                FilledButton(
                                  style: _compactFilledButtonStyle(),
                                  onPressed: _isSaving
                                      ? null
                                      : () => _saveTranscript(effectiveMemo),
                                  child: Text(_isSaving ? 'Saving...' : 'Save'),
                                ),
                              ],
                            ),
                          ] else ...[
                            SelectableText(
                              currentTranscript.trim().isEmpty
                                  ? 'Transcription will appear here after sync and transcription finish.'
                                  : currentTranscript,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    height: 1.45,
                                    color: currentTranscript.trim().isEmpty
                                        ? AppTheme.textSecondary
                                        : AppTheme.textPrimary,
                                  ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: AppTheme.spacingSm,
                              runSpacing: AppTheme.spacingSm,
                              children: [
                                OutlinedButton.icon(
                                  style: _compactOutlinedButtonStyle(),
                                  onPressed: currentTranscript.trim().isEmpty
                                      ? null
                                      : () async {
                                          await Clipboard.setData(
                                            ClipboardData(text: currentTranscript),
                                          );
                                          if (!context.mounted) {
                                            return;
                                          }
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Transcript copied to clipboard'),
                                            ),
                                          );
                                        },
                                  icon: const Icon(Icons.copy_all_outlined),
                                  label: const Text('Copy text'),
                                ),
                                _TranscribeButton(
                                  memo: effectiveMemo,
                                  expand: false,
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SectionCard(
                      title: 'Actions',
                      child: Wrap(
                        spacing: AppTheme.spacingSm,
                        runSpacing: AppTheme.spacingSm,
                        children: [
                          OutlinedButton.icon(
                            style: _compactOutlinedButtonStyle(),
                            onPressed: () => _deleteMemo(effectiveMemo),
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Delete'),
                          ),
                          if (!_hasLocalAudio(effectiveMemo))
                            FilledButton.icon(
                              style: _compactFilledButtonStyle(),
                              onPressed: ref.watch(isWatchConnectedProvider)
                                  ? () => ref
                                      .read(voiceMemoActionsProvider.notifier)
                                      .sync()
                                  : null,
                              icon: const Icon(Icons.sync),
                              label: const Text('Sync now'),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            'Unable to load voice note: $error',
            style: const TextStyle(color: AppTheme.errorColor),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Future<void> _saveTranscript(VoiceMemo memo) async {
    setState(() => _isSaving = true);
    try {
      await ref.read(voiceMemoRepositoryProvider).updateTranscription(
            filename: memo.filename,
            transcription: _transcriptController.text.trim(),
          );
      if (!mounted) {
        return;
      }
      setState(() => _isEditing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transcript updated')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _deleteMemo(VoiceMemo memo) async {
    final shouldDelete = await _confirmDelete(context, memo);
    if (shouldDelete != true || !mounted) {
      return;
    }

    await ref.read(voiceMemoActionsProvider.notifier).delete(memo.filename);
    if (!mounted) {
      return;
    }
    context.pop();
  }
}

class _AISummarySection extends ConsumerWidget {
  final VoiceMemo memo;

  const _AISummarySection({required this.memo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aiEnabled = ref.watch(localAiEnabledProvider);
    final modelDownloadedAsync = ref.watch(llmModelDownloadedProvider);

    if (!aiEnabled) {
      return const SizedBox.shrink();
    }

    return modelDownloadedAsync.when(
      data: (modelDownloaded) {
        if (!modelDownloaded) {
          return const SizedBox.shrink();
        }

        final hasSummary = memo.summary != null && memo.summary!.isNotEmpty;
        final hasCategory = memo.aiCategory != null;
        final isProcessing = memo.isAiProcessing;
        final hasFailed = memo.aiProcessingStatus == VoiceNoteProcessingStatus.failed;

        if (!hasSummary && !hasCategory && !isProcessing && !hasFailed) {
          return _SectionCard(
            title: 'AI Analysis',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Get AI-powered insights including summary, category, and extracted actions.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: _compactOutlinedButtonStyle(),
                  onPressed: memo.transcription?.trim().isEmpty == true
                      ? null
                      : () => ref
                          .read(aiActionsProvider.notifier)
                          .processVoiceMemo(memo.filename),
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Process with AI'),
                ),
                if (memo.transcription?.trim().isEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Transcribe the audio first before AI processing.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                    ),
                  ),
              ],
            ),
          );
        }

        return _SectionCard(
          title: 'AI Summary',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isProcessing)
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _showAiDebugDialog(context, ref),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: AppTheme.spacingSm),
                        Text(
                          'Processing with AI...',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.bug_report_outlined,
                          size: 16,
                          color: AppTheme.textSecondary,
                        ),
                      ],
                    ),
                  ),
                )
              else if (hasFailed)
                Text(
                  'AI processing failed. Please try again.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.errorColor,
                      ),
                )
              else ...[
                if (hasCategory)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _CategoryBadge(category: memo.aiCategory!),
                  ),
                if (hasSummary)
                  SelectableText(
                    memo.summary!,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          height: 1.45,
                        ),
                  ),
              ],
              if (!isProcessing && (hasSummary || hasCategory))
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Wrap(
                    spacing: AppTheme.spacingSm,
                    children: [
                      OutlinedButton.icon(
                        style: _compactOutlinedButtonStyle(),
                        onPressed: () => ref
                            .read(aiActionsProvider.notifier)
                            .processVoiceMemo(memo.filename),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Re-process'),
                      ),
                      OutlinedButton.icon(
                        style: _compactOutlinedButtonStyle(),
                        onPressed: () => _showAiDebugDialog(context, ref),
                        icon: const Icon(Icons.bug_report_outlined),
                        label: const Text('Debug'),
                      ),
                    ],
                  ),
                ),
              if (hasSummary && memo.aiModel != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Model: ${memo.aiModel}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                        ),
                  ),
                ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  void _showAiDebugDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.elevatedSurfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => _AiDebugSheet(
          memo: memo,
          scrollController: scrollController,
        ),
      ),
    );
  }
}

class _AiDebugSheet extends ConsumerWidget {
  final VoiceMemo memo;
  final ScrollController scrollController;

  const _AiDebugSheet({
    required this.memo,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streamValue = ref.watch(aiProcessingDebugInfoProvider).valueOrNull;
    // Show live stream data only when it's for THIS memo
    final liveInfo = (streamValue != null &&
            streamValue.filename == memo.filename)
        ? streamValue
        : null;
    // For completed results, look up per-file cache
    final storedInfo = ref
        .read(voiceNoteAiPipelineProvider)
        .getDebugInfoForFile(memo.filename);
    // Prefer live (in-progress or just-completed) over stored
    final debugInfo = liveInfo ?? storedInfo;
    final theme = Theme.of(context);

    return Column(
      children: [
        // Handle bar
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.textSecondary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(Icons.bug_report_outlined, size: 20),
              const SizedBox(width: 8),
              Text('AI Debug Info', style: theme.textTheme.titleMedium),
              const Spacer(),
              if (debugInfo != null && !debugInfo.isComplete)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              if (debugInfo == null) ...[
                _debugNote(
                  context,
                  'No debug data available for the latest run. '
                  'Re-process this memo to see debug info.',
                ),
                const SizedBox(height: 16),
                _debugInfoFromMemo(context),
              ] else if (!debugInfo.isComplete) ...[
                // --- Live / in-progress view ---
                _livePhaseHeader(context, debugInfo),
                const SizedBox(height: 12),
                if (debugInfo.transcriptionResult != null) ...[
                  _debugBlock(
                    context,
                    title: 'Original Transcription',
                    content: debugInfo.transcriptionResult!,
                    icon: Icons.mic,
                  ),
                  const SizedBox(height: 12),
                ],
                // Only show the partial-response block once tokens are flowing
                if (debugInfo.phase != 'loading')
                  _debugBlock(
                    context,
                    title: '${_phaseLabel(debugInfo.phase)} (live)',
                    content: debugInfo.partialOutput.isEmpty
                        ? '...'
                        : debugInfo.partialOutput,
                    icon: debugInfo.phase == 'correcting'
                        ? Icons.auto_fix_high
                        : Icons.code,
                    mono: debugInfo.phase == 'classifying',
                  ),
              ] else ...[
                // --- Completed view ---
                _metricsRow(context, debugInfo),
                const SizedBox(height: 16),
                if (debugInfo.transcriptionResult != null &&
                    debugInfo.correctedTranscription != null &&
                    debugInfo.correctedTranscription !=
                        debugInfo.transcriptionResult) ...[
                  _transcriptionDiffBlock(
                    context,
                    original: debugInfo.transcriptionResult!,
                    corrected: debugInfo.correctedTranscription!,
                  ),
                  const SizedBox(height: 12),
                ] else if (debugInfo.transcriptionResult != null) ...[
                  _debugBlock(
                    context,
                    title: 'Transcription',
                    content: debugInfo.transcriptionResult!,
                    icon: Icons.mic,
                  ),
                  const SizedBox(height: 12),
                ],
                if (debugInfo.rawOutput != null) ...[
                  _debugBlock(
                    context,
                    title: 'Raw LLM Response',
                    content: debugInfo.rawOutput!,
                    icon: Icons.code,
                    mono: true,
                  ),
                  const SizedBox(height: 12),
                ],
                if (debugInfo.parsedJson != null) ...[                  _debugBlock(
                    context,
                    title: 'Parsed JSON',
                    content: aiFormatJson(debugInfo.parsedJson!),
                    icon: Icons.data_object,
                    mono: true,
                  ),
                  const SizedBox(height: 12),
                ],
                if (aiHasChronoDetails(
                  extractedIntent: debugInfo.extractedIntent,
                  extractedTitle: debugInfo.extractedTitle,
                  datetimeExpressionOriginal: debugInfo.datetimeExpressionOriginal,
                  datetimeExpressionEnglish: debugInfo.datetimeExpressionEnglish,
                  resolvedDateTime: debugInfo.resolvedDateTime,
                  resolverMethod: debugInfo.resolverMethod,
                  extractedActions: debugInfo.extractedActions,
                )) ...[
                  aiDebugBlock(
                    context,
                    title: 'Chrono Extraction / Resolution',
                    content: aiFormatChronoDetails(
                      extractedIntent: debugInfo.extractedIntent,
                      extractedTitle: debugInfo.extractedTitle,
                      datetimeExpressionOriginal: debugInfo.datetimeExpressionOriginal,
                      datetimeExpressionEnglish: debugInfo.datetimeExpressionEnglish,
                      resolvedDateTime: debugInfo.resolvedDateTime,
                      resolverMethod: debugInfo.resolverMethod,
                      extractedActions: debugInfo.extractedActions,
                    ),
                    icon: Icons.schedule,
                    showCopyButton: true,
                  ),
                  const SizedBox(height: 12),
                ],
                _resultRow(context, debugInfo),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _phaseLabel(String? phase) {
    switch (phase) {
      case 'correcting':
        return 'Correction Output';
      case 'classifying':
        return 'Classify Output';
      default:
        return 'Output';
    }
  }

  Widget _livePhaseHeader(BuildContext context, AiDebugInfo info) {
    final theme = Theme.of(context);
    final phaseText = switch (info.phase) {
      'loading' => 'Loading model...',
      'correcting' => 'Correcting transcription...',
      'classifying' => 'Classifying & summarizing...',
      _ => 'Processing...',
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            info.modelName,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                phaseText,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _metricChip(
                context,
                'Tokens',
                '${info.tokens}',
                Icons.token,
              ),
            ],
          ),
          if (aiMemoryInfoBlock(context, info) != null) ...[            const SizedBox(height: 8),
            aiMemoryInfoBlock(context, info)!,
          ],
        ],
      ),
    );
  }

  Widget _debugNote(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.textSecondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _debugInfoFromMemo(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (memo.aiModel != null)
          _kvRow(context, 'Model', memo.aiModel!),
        if (memo.summary != null)
          _kvRow(context, 'Summary', memo.summary!),
        if (memo.aiCategory != null)
          _kvRow(context, 'Category', memo.aiCategory!.name),
        if (memo.transcription != null) ...[
          const SizedBox(height: 12),
          Text('Transcription', style: theme.textTheme.labelMedium),
          const SizedBox(height: 4),
          SelectableText(
            memo.transcription!,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  Widget _metricsRow(BuildContext context, AiDebugInfo info) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            info.modelName,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              if (info.correctionElapsed > Duration.zero)
                _metricChip(
                  context,
                  'Correction',
                  '${info.correctionElapsed.inMilliseconds}ms',
                  Icons.timer_outlined,
                ),
              if (info.correctionTokensPerSecond != null)
                _metricChip(
                  context,
                  'Correction tok/s',
                  info.correctionTokensPerSecond!.toStringAsFixed(1),
                  Icons.speed,
                ),
              if (info.correctionTokens > 0)
                _metricChip(
                  context,
                  'Correction tokens',
                  '${info.correctionTokens}',
                  Icons.token,
                ),
              if (info.elapsed > Duration.zero)
                _metricChip(
                  context,
                  'Classify',
                  '${info.elapsed.inMilliseconds}ms',
                  Icons.timer_outlined,
                ),
              if (info.tokensPerSecond != null)
                _metricChip(
                  context,
                  'Classify tok/s',
                  info.tokensPerSecond!.toStringAsFixed(1),
                  Icons.speed,
                ),
              if (info.tokens > 0)
                _metricChip(
                  context,
                  'Classify tokens',
                  '${info.tokens}',
                  Icons.token,
                ),
            ],
          ),
          if (aiMemoryInfoBlock(context, info) != null) ...[
            const SizedBox(height: 8),
            aiMemoryInfoBlock(context, info)!,
          ],
        ],
      ),
    );
  }

  Widget _metricChip(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppTheme.textSecondary),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
                fontSize: 11,
              ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
        ),
      ],
    );
  }

  Widget _debugBlock(
    BuildContext context, {
    required String title,
    required String content,
    required IconData icon,
    bool mono = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: AppTheme.textSecondary),
            const SizedBox(width: 6),
            Text(
              title,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.copy, size: 16),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: content));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Copied $title'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.textSecondary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppTheme.textSecondary.withValues(alpha: 0.12),
            ),
          ),
          child: SelectableText(
            content,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: mono ? 'monospace' : null,
                  fontSize: mono ? 11 : null,
                  height: 1.5,
                ),
          ),
        ),
      ],
    );
  }

  /// Build a diff view showing words removed (from original) in red and words
  /// added (in corrected) in green. Uses a simple longest-common-subsequence
  /// approach on whitespace-split word arrays.
  Widget _transcriptionDiffBlock(
    BuildContext context, {
    required String original,
    required String corrected,
  }) {
    final origWords = original.split(RegExp(r'\s+'));
    final corrWords = corrected.split(RegExp(r'\s+'));
    final spans = _computeWordDiffSpans(origWords, corrWords, context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.compare_arrows, size: 16, color: AppTheme.textSecondary),
            const SizedBox(width: 6),
            Text(
              'Transcription Diff',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
            const Spacer(),
            _diffLegendChip(context, 'removed', const Color(0x40EF5350)),
            const SizedBox(width: 6),
            _diffLegendChip(context, 'added', const Color(0x4066BB6A)),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.textSecondary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppTheme.textSecondary.withValues(alpha: 0.12),
            ),
          ),
          child: Text.rich(
            TextSpan(children: spans),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.6),
          ),
        ),
      ],
    );
  }

  Widget _diffLegendChip(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
      ),
    );
  }

  /// Compute word-level diff spans using LCS (longest common subsequence).
  List<TextSpan> _computeWordDiffSpans(
    List<String> origWords,
    List<String> corrWords,
    BuildContext context,
  ) {
    final n = origWords.length;
    final m = corrWords.length;

    // Build LCS table
    final dp = List.generate(n + 1, (_) => List.filled(m + 1, 0));
    for (var i = 1; i <= n; i++) {
      for (var j = 1; j <= m; j++) {
        if (origWords[i - 1].toLowerCase() == corrWords[j - 1].toLowerCase()) {
          dp[i][j] = dp[i - 1][j - 1] + 1;
        } else {
          dp[i][j] = dp[i - 1][j] > dp[i][j - 1]
              ? dp[i - 1][j]
              : dp[i][j - 1];
        }
      }
    }

    // Backtrack to produce diff operations
    final ops = <_DiffOp>[];
    var i = n;
    var j = m;
    while (i > 0 || j > 0) {
      if (i > 0 &&
          j > 0 &&
          origWords[i - 1].toLowerCase() == corrWords[j - 1].toLowerCase()) {
        ops.add(_DiffOp.equal(corrWords[j - 1]));
        i--;
        j--;
      } else if (j > 0 && (i == 0 || dp[i][j - 1] >= dp[i - 1][j])) {
        ops.add(_DiffOp.insert(corrWords[j - 1]));
        j--;
      } else {
        ops.add(_DiffOp.delete(origWords[i - 1]));
        i--;
      }
    }
    ops.reversed; // reversed is lazy, need toList
    final orderedOps = ops.reversed.toList();

    // Convert to TextSpans
    final spans = <TextSpan>[];
    for (final op in orderedOps) {
      if (spans.isNotEmpty) {
        spans.add(const TextSpan(text: ' '));
      }
      switch (op.type) {
        case _DiffType.equal:
          spans.add(TextSpan(text: op.word));
          break;
        case _DiffType.delete:
          spans.add(TextSpan(
            text: op.word,
            style: const TextStyle(
              backgroundColor: Color(0x40EF5350),
              decoration: TextDecoration.lineThrough,
              decorationColor: Color(0xFFEF5350),
            ),
          ));
          break;
        case _DiffType.insert:
          spans.add(TextSpan(
            text: op.word,
            style: const TextStyle(
              backgroundColor: Color(0x4066BB6A),
              fontWeight: FontWeight.w600,
            ),
          ));
          break;
      }
    }
    return spans;
  }

  Widget _resultRow(BuildContext context, AiDebugInfo info) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.check_circle_outline, size: 16, color: AppTheme.textSecondary),
            const SizedBox(width: 6),
            Text(
              'Parsed Result',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (info.category != null) _kvRow(context, 'Category', info.category!),
        if (info.summary != null) _kvRow(context, 'Summary', info.summary!),
        _kvRow(context, 'Actions', '${info.actionCount}'),
        if (info.timestamp != null)
          _kvRow(
            context,
            'Processed',
            DateFormat('HH:mm:ss.SSS').format(info.timestamp!),
          ),
      ],
    );
  }

  Widget _kvRow(BuildContext context, String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              key,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExtractedActionsSection extends ConsumerStatefulWidget {
  final VoiceMemo memo;

  const _ExtractedActionsSection({required this.memo});

  @override
  ConsumerState<_ExtractedActionsSection> createState() =>
      _ExtractedActionsSectionState();
}

class _ExtractedActionsSectionState
    extends ConsumerState<_ExtractedActionsSection> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final aiEnabled = ref.watch(localAiEnabledProvider);

    if (!aiEnabled) {
      return const SizedBox.shrink();
    }

    final actionsAsync = ref.watch(
      extractedActionsForMemoProvider(widget.memo.id),
    );

    return actionsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (actions) {
        if (actions.isEmpty) {
          return const SizedBox.shrink();
        }

        return _SectionCard(
          title: 'Extracted Actions',
          trailing: IconButton(
            tooltip: _isExpanded ? 'Collapse' : 'Expand',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(
              width: 32,
              height: 32,
            ),
            onPressed: () => setState(() => _isExpanded = !_isExpanded),
            icon: Icon(
              _isExpanded ? Icons.expand_less : Icons.expand_more,
            ),
          ),
          child: _isExpanded
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(height: 10),
                      _ActionItem(action: actions[i]),
                    ],
                  ],
                )
              : Text(
                  '${actions.length} action${actions.length == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
        );
      },
    );
  }
}

class _ActionItem extends ConsumerStatefulWidget {
  final ExtractedAction action;

  const _ActionItem({required this.action});

  @override
  ConsumerState<_ActionItem> createState() => _ActionItemState();
}

class _ActionItemState extends ConsumerState<_ActionItem> {
  bool _isCreating = false;
  bool _isDismissing = false;
  bool _isOpening = false;

  ExtractedAction get action => widget.action;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _actionTypeColor(action.actionType).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
          child: Icon(
            _actionTypeIcon(action.actionType),
            size: 16,
            color: _actionTypeColor(action.actionType),
          ),
        ),
        const SizedBox(width: AppTheme.spacingSm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      action.title,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingSm),
                  _ActionStatusBadge(action: action),
                ],
              ),
              if (_timingLabel(action) case final timingLabel?) ...[
                const SizedBox(height: 4),
                Text(
                  timingLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
              ],
              if (action.notes != null && action.notes!.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  action.notes!.trim(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
              ],
              if (action.location != null) ...[
                const SizedBox(height: 4),
                Text(
                  action.location!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: AppTheme.spacingSm,
                runSpacing: AppTheme.spacingSm,
                children: [
                  if (!action.created && !action.dismissed)
                    FilledButton.icon(
                      style: _compactFilledButtonStyle(),
                      onPressed: _isCreating ? null : _createAction,
                      icon: _isCreating
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add_task_outlined),
                      label: Text(_isCreating ? 'Creating\u2026' : 'Create'),
                    ),
                  if (!action.created && !action.dismissed)
                    OutlinedButton.icon(
                      style: _compactOutlinedButtonStyle(),
                      onPressed: _isDismissing ? null : _dismissAction,
                      icon: _isDismissing
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.close_rounded),
                      label: const Text('Dismiss'),
                    ),
                  if (action.created && action.platformTargetId != null)
                    OutlinedButton.icon(
                      style: _compactOutlinedButtonStyle(),
                      onPressed: _isOpening ? null : _openCreatedAction,
                      icon: _isOpening
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.open_in_new_rounded),
                      label: const Text('Open'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _createAction() async {
    setState(() => _isCreating = true);
    try {
      final selectedCalendarId = ref.read(selectedProductivityCalendarIdProvider);
      final draft = ActionCreationDraft.fromAction(action).copyWith(
        platformCalendarId: Platform.isAndroid ? selectedCalendarId : null,
      );

      final message = await ref.read(extractedActionOperationsProvider).createAction(
            action: action,
            draft: draft,
          );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create action: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  Future<void> _dismissAction() async {
    setState(() => _isDismissing = true);
    try {
      await ref.read(extractedActionOperationsProvider).dismissAction(action.id);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to dismiss action: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isDismissing = false);
      }
    }
  }

  Future<void> _openCreatedAction() async {
    setState(() => _isOpening = true);
    try {
      await ref
          .read(extractedActionCreationServiceProvider)
          .openCreatedAction(action);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open created action: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isOpening = false);
      }
    }
  }

  IconData _actionTypeIcon(ExtractedActionType type) {
    return switch (type) {
      ExtractedActionType.task => Icons.check_box_outlined,
      ExtractedActionType.reminder => Icons.alarm,
      ExtractedActionType.calendarEvent => Icons.calendar_today,
    };
  }

  Color _actionTypeColor(ExtractedActionType type) {
    return switch (type) {
      ExtractedActionType.task => AppTheme.primaryColor,
      ExtractedActionType.reminder => AppTheme.warningColor,
      ExtractedActionType.calendarEvent => AppTheme.infoColor,
    };
  }

  String? _timingLabel(ExtractedAction action) {
    final dateFormat = DateFormat.yMMMd();
    final dateTimeFormat = DateFormat.yMMMd().add_jm();

    if (action.startTime != null) {
      final start = action.startTime!.toLocal();
      if (action.endTime != null) {
        final end = action.endTime!.toLocal();
        return 'When: ${dateTimeFormat.format(start)} \u2192 ${dateTimeFormat.format(end)}';
      }
      return 'When: ${dateTimeFormat.format(start)}';
    }

    if (action.dueDate != null) {
      return 'Due: ${dateFormat.format(action.dueDate!.toLocal())}';
    }

    return null;
  }
}

class _ActionStatusBadge extends StatelessWidget {
  final ExtractedAction action;

  const _ActionStatusBadge({required this.action});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch ((action.created, action.dismissed)) {
      (true, _) => ('Created', AppTheme.successColor),
      (_, true) => ('Dismissed', AppTheme.textSecondary),
      _ => ('Pending', AppTheme.warningColor),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  final VoiceNoteCategory category;

  const _CategoryBadge({required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: _categoryColor(category).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _categoryIcon(category),
            size: 16,
            color: _categoryColor(category),
          ),
          const SizedBox(width: 6),
          Text(
            _categoryLabel(category),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: _categoryColor(category),
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  IconData _categoryIcon(VoiceNoteCategory category) {
    return switch (category) {
      VoiceNoteCategory.idea => Icons.lightbulb_outline,
      VoiceNoteCategory.task => Icons.check_box_outlined,
      VoiceNoteCategory.reminder => Icons.alarm,
      VoiceNoteCategory.meeting => Icons.people_outline,
      VoiceNoteCategory.note => Icons.note_outlined,
    };
  }

  Color _categoryColor(VoiceNoteCategory category) {
    return switch (category) {
      VoiceNoteCategory.idea => const Color(0xFFFFA726),
      VoiceNoteCategory.task => AppTheme.primaryColor,
      VoiceNoteCategory.reminder => AppTheme.warningColor,
      VoiceNoteCategory.meeting => const Color(0xFF26A69A),
      VoiceNoteCategory.note => AppTheme.textSecondary,
    };
  }

  String _categoryLabel(VoiceNoteCategory category) {
    return switch (category) {
      VoiceNoteCategory.idea => 'Idea',
      VoiceNoteCategory.task => 'Task',
      VoiceNoteCategory.reminder => 'Reminder',
      VoiceNoteCategory.meeting => 'Meeting',
      VoiceNoteCategory.note => 'Note',
    };
  }
}

class _SyncProgressBar extends StatelessWidget {
  final VoiceMemoSyncState state;

  const _SyncProgressBar({required this.state});

  @override
  Widget build(BuildContext context) {
    if (!state.isSyncing) {
      return const SizedBox.shrink();
    }

    final phaseText = switch (state.phase) {
      VoiceMemoSyncPhase.fetchingList => 'Fetching recording list...',
      VoiceMemoSyncPhase.downloading =>
        'Downloading ${state.currentFilename ?? ''}...',
      VoiceMemoSyncPhase.verifying => 'Verifying download...',
      VoiceMemoSyncPhase.deleting => 'Cleaning up watch storage...',
      _ => 'Syncing...',
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMd,
        vertical: AppTheme.spacingSm,
      ),
      color: AppTheme.primaryColor.withValues(alpha: 0.1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: AppTheme.spacingSm),
              Expanded(
                child: Text(
                  phaseText,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              if (state.totalToSync > 0)
                Text(
                  '${state.completedCount}/${state.totalToSync}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
          if (state.phase == VoiceMemoSyncPhase.downloading)
            Padding(
              padding: const EdgeInsets.only(top: AppTheme.spacingXs),
              child: LinearProgressIndicator(
                value: state.downloadProgress,
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.2),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasQuery;

  const _EmptyState({this.hasQuery = false});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.55,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  hasQuery
                      ? Icons.search_off_rounded
                      : Icons.mic_none_rounded,
                  size: 64,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(height: AppTheme.spacingMd),
                Text(
                  hasQuery ? 'No matching notes' : 'No voice notes yet',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.grey.shade500,
                      ),
                ),
                const SizedBox(height: AppTheme.spacingSm),
                Text(
                  hasQuery
                      ? 'Try a different search term or clear the filter.'
                      : 'Press record on the watch to create your first note.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _VoiceMemoTimeline extends ConsumerWidget {
  final List<VoiceMemo> memos;
  final ValueChanged<VoiceMemo> onOpenMemo;

  const _VoiceMemoTimeline({
    required this.memos,
    required this.onOpenMemo,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sections = _groupMemosByDay(memos);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingMd,
        AppTheme.spacingMd,
        AppTheme.spacingMd,
        AppTheme.spacingLg,
      ),
      children: [
        for (final section in sections) ...[
          Padding(
            padding: const EdgeInsets.only(
              top: AppTheme.spacingSm,
              bottom: AppTheme.spacingSm,
            ),
            child: Text(
              section.label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
          ),
          for (final memo in section.memos)
            _VoiceNoteCard(
              memo: memo,
              onOpen: () => onOpenMemo(memo),
            ),
        ],
      ],
    );
  }
}

class _VoiceNoteCard extends ConsumerWidget {
  final VoiceMemo memo;
  final VoidCallback onOpen;

  const _VoiceNoteCard({
    required this.memo,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final previewText = _memoPreviewText(memo);
    final canPlay = _hasLocalAudio(memo);
    final isProcessing = memo.isAiProcessing;

    return Dismissible(
      key: ValueKey('voice-note-${memo.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
        decoration: BoxDecoration(
          color: AppTheme.errorColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppTheme.spacingLg),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) => _confirmDelete(context, memo),
      onDismissed: (_) {
        ref.read(voiceMemoActionsProvider.notifier).delete(memo.filename);
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (memo.aiCategory != null)
                      Padding(
                        padding: const EdgeInsets.only(right: AppTheme.spacingSm),
                        child: Icon(
                          _categoryIcon(memo.aiCategory!),
                          size: 20,
                          color: _categoryColor(memo.aiCategory!),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        _timelineTimestampLabel(memo.timestampUtc.toLocal()),
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppTheme.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingSm),
                Text(
                  previewText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        height: 1.35,
                        color: memo.summary != null ||
                                memo.transcription?.trim().isNotEmpty == true
                            ? AppTheme.textPrimary
                            : AppTheme.textSecondary,
                      ),
                ),
                const SizedBox(height: AppTheme.spacingSm),
                Wrap(
                  spacing: AppTheme.spacingSm,
                  runSpacing: AppTheme.spacingSm,
                  children: [
                    if (memo.aiCategory != null)
                      _MetaChip(
                        icon: _categoryIcon(memo.aiCategory!),
                        label: _categoryLabel(memo.aiCategory!),
                        color: _categoryColor(memo.aiCategory!),
                      ),
                    if (isProcessing)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.12),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusXLarge),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(strokeWidth: 1.5),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Processing',
                              style:
                                  Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: AppTheme.primaryColor,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 10.5,
                                      ),
                            ),
                          ],
                        ),
                      ),
                    _MetaChip(
                      icon: _syncStatusIcon(memo.syncStatus),
                      label: _syncStatusLabel(memo),
                      color: _syncStatusColor(memo.syncStatus),
                    ),
                    if (memo.syncedFromWatch)
                      const _MetaChip(
                        icon: Icons.smartphone_outlined,
                        label: 'Phone',
                        color: AppTheme.primaryColor,
                      ),
                    if (!memo.deletedOnWatch)
                      const _MetaChip(
                        icon: Icons.watch_outlined,
                        label: 'On watch',
                        color: AppTheme.warningColor,
                      ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingMd),
                Row(
                  children: [
                    Text(
                      memo.formattedDuration,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(width: AppTheme.spacingSm),
                    Text(
                      memo.formattedSize,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                    ),
                    const Spacer(),
                    Icon(
                      canPlay
                          ? Icons.play_circle_fill_rounded
                          : Icons.cloud_download_outlined,
                      color: canPlay
                          ? AppTheme.primaryColor
                          : AppTheme.warningColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _categoryIcon(VoiceNoteCategory category) {
    return switch (category) {
      VoiceNoteCategory.idea => Icons.lightbulb_outline,
      VoiceNoteCategory.task => Icons.check_box_outlined,
      VoiceNoteCategory.reminder => Icons.alarm,
      VoiceNoteCategory.meeting => Icons.people_outline,
      VoiceNoteCategory.note => Icons.note_outlined,
    };
  }

  Color _categoryColor(VoiceNoteCategory category) {
    return switch (category) {
      VoiceNoteCategory.idea => const Color(0xFFFFA726),
      VoiceNoteCategory.task => AppTheme.primaryColor,
      VoiceNoteCategory.reminder => AppTheme.warningColor,
      VoiceNoteCategory.meeting => const Color(0xFF26A69A),
      VoiceNoteCategory.note => AppTheme.textSecondary,
    };
  }

  String _categoryLabel(VoiceNoteCategory category) {
    return switch (category) {
      VoiceNoteCategory.idea => 'Idea',
      VoiceNoteCategory.task => 'Task',
      VoiceNoteCategory.reminder => 'Reminder',
      VoiceNoteCategory.meeting => 'Meeting',
      VoiceNoteCategory.note => 'Note',
    };
  }
}

class _MissingNoteState extends StatelessWidget {
  const _MissingNoteState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.description_outlined, size: 56),
          const SizedBox(height: AppTheme.spacingMd),
          Text(
            'Voice note not found',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

class _TopSummarySection extends StatelessWidget {
  final VoiceMemo memo;
  final bool sideBySide;

  const _TopSummarySection({
    required this.memo,
    required this.sideBySide,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compactWidth = constraints.maxWidth < 380;
            final rightColumnWidth = compactWidth ? 128.0 : 164.0;
            final audioWidget = _hasLocalAudio(memo)
                ? _AudioPlayerCard(
                    memo: memo,
                    compact: true,
                    alignRight: true,
                  )
                : _SyncPromptCard(
                    memo: memo,
                    compact: true,
                    alignRight: true,
                  );

            if (!sideBySide && constraints.maxWidth < 320) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _VoiceNoteHeaderContent(memo: memo),
                  const SizedBox(height: 10),
                  audioWidget,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _VoiceNoteHeaderContent(memo: memo)),
                const SizedBox(width: 10),
                SizedBox(
                  width: rightColumnWidth,
                  child: audioWidget,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _VoiceNoteHeaderContent extends StatelessWidget {
  final VoiceMemo memo;

  const _VoiceNoteHeaderContent({required this.memo});

  @override
  Widget build(BuildContext context) {
    final local = memo.timestampUtc.toLocal();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          DateFormat('MMMM d · HH:mm').format(local),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        Text(
          '${memo.formattedDuration} · ${memo.formattedSize}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: AppTheme.spacingSm,
          runSpacing: AppTheme.spacingSm,
          children: [
            _MetaChip(
              icon: _syncStatusIcon(memo.syncStatus),
              label: _syncStatusLabel(memo),
              color: _syncStatusColor(memo.syncStatus),
            ),
            if (memo.syncedFromWatch)
              const _MetaChip(
                icon: Icons.smartphone_outlined,
                label: 'Synced',
                color: AppTheme.primaryColor,
              ),
            if (!memo.deletedOnWatch)
              const _MetaChip(
                icon: Icons.watch_outlined,
                label: 'Still on watch',
                color: AppTheme.warningColor,
              ),
          ],
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const _SectionCard({
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _AudioPlayerCard extends ConsumerStatefulWidget {
  final VoiceMemo memo;
  final bool compact;
  final bool alignRight;

  const _AudioPlayerCard({
    required this.memo,
    this.compact = false,
    this.alignRight = false,
  });

  @override
  ConsumerState<_AudioPlayerCard> createState() => _AudioPlayerCardState();
}

class _AudioPlayerCardState extends ConsumerState<_AudioPlayerCard> {
  AudioPlayer? _player;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    final path = widget.memo.convertedFilePath ?? widget.memo.localFilePath;
    if (path == null || !File(path).existsSync()) {
      setState(() => _error = 'Audio file not found');
      return;
    }

    try {
      _player = AudioPlayer();
      final duration = await _player!.setFilePath(path);
      if (duration != null && mounted) {
        setState(() => _duration = duration);
      }

      _player!.positionStream.listen((position) {
        if (mounted) {
          setState(() => _position = position);
        }
      });

      _player!.playerStateStream.listen((state) {
        if (!mounted) {
          return;
        }
        setState(() => _isPlaying = state.playing);
        if (state.processingState == ProcessingState.completed) {
          _player!.seek(Duration.zero);
          _player!.pause();
        }
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Failed to load audio: $error');
      }
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Text(
        _error!,
        style: const TextStyle(color: AppTheme.errorColor),
      );
    }

    return Column(
      crossAxisAlignment:
          widget.alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment:
              widget.alignRight ? MainAxisAlignment.end : MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              constraints: BoxConstraints.tightFor(
                width: widget.compact ? 30 : 36,
                height: widget.compact ? 30 : 36,
              ),
              onPressed: () {
                final next = _position - const Duration(seconds: 10);
                _player?.seek(next < Duration.zero ? Duration.zero : next);
              },
              icon: const Icon(Icons.replay_10_rounded),
            ),
            SizedBox(width: widget.compact ? 4 : 8),
            IconButton.filled(
              style: IconButton.styleFrom(
                visualDensity: VisualDensity.compact,
                minimumSize: Size(widget.compact ? 34 : 40, widget.compact ? 34 : 40),
                padding: EdgeInsets.zero,
              ),
              iconSize: widget.compact ? 24 : 28,
              onPressed: () {
                if (_isPlaying) {
                  _player?.pause();
                } else {
                  _player?.play();
                }
              },
              icon: Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              ),
            ),
            SizedBox(width: widget.compact ? 4 : 8),
            IconButton(
              visualDensity: VisualDensity.compact,
              constraints: BoxConstraints.tightFor(
                width: widget.compact ? 30 : 36,
                height: widget.compact ? 30 : 36,
              ),
              onPressed: () {
                final next = _position + const Duration(seconds: 10);
                _player?.seek(next > _duration ? _duration : next);
              },
              icon: const Icon(Icons.forward_10_rounded),
            ),
          ],
        ),
        SizedBox(height: widget.compact ? 4 : AppTheme.spacingSm),
        Row(
          children: [
            Text(
              _formatDuration(_position),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: widget.compact ? 2 : null,
                  thumbShape: RoundSliderThumbShape(
                    enabledThumbRadius: widget.compact ? 5 : 8,
                  ),
                  overlayShape: RoundSliderOverlayShape(
                    overlayRadius: widget.compact ? 10 : 16,
                  ),
                ),
                child: Slider(
                  padding: widget.compact ? EdgeInsets.zero : null,
                  value: _duration.inMilliseconds == 0
                      ? 0
                      : _position.inMilliseconds
                          .clamp(0, _duration.inMilliseconds)
                          .toDouble(),
                  max: _duration.inMilliseconds == 0
                      ? 1
                      : _duration.inMilliseconds.toDouble(),
                  onChanged: (value) =>
                      _player?.seek(Duration(milliseconds: value.toInt())),
                ),
              ),
            ),
            Text(
              _formatDuration(_duration),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ],
    );
  }
}

class _TranscribeButton extends ConsumerWidget {
  final VoiceMemo memo;
  final bool expand;

  const _TranscribeButton({
    required this.memo,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engineStateAsync = ref.watch(transcriptionEngineStateProvider);
    final configuredAsync = ref.watch(transcriptionConfiguredProvider);

    return configuredAsync.when(
      data: (configured) {
        if (!configured) {
          return _ButtonBox(
            expand: expand,
            child: OutlinedButton.icon(
              style: _compactOutlinedButtonStyle(),
              icon: const Icon(Icons.settings, size: 18),
              label: const Text('Set up transcription model'),
              onPressed: () => context.push(AppRoutes.settings),
            ),
          );
        }

        return engineStateAsync.when(
          data: (engineState) {
            final isTranscribing =
                engineState.status == TranscriptionEngineStatus.transcribing;
            final buttonLabel =
                memo.transcription == null ? 'Transcribe' : 'Re-transcribe';

            return _ButtonBox(
              expand: expand,
              child: OutlinedButton.icon(
                style: _compactOutlinedButtonStyle(),
                icon: isTranscribing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.transcribe),
                label: Text(isTranscribing ? 'Transcribing...' : buttonLabel),
                onPressed: isTranscribing
                    ? null
                    : () => ref
                        .read(voiceMemoActionsProvider.notifier)
                        .retranscribe(memo),
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, _) => _ButtonBox(
            expand: expand,
            child: OutlinedButton.icon(
              style: _compactOutlinedButtonStyle(),
              icon: const Icon(Icons.transcribe, size: 18),
              label:
                  Text(memo.transcription == null ? 'Transcribe' : 'Re-transcribe'),
              onPressed: () =>
                  ref.read(voiceMemoActionsProvider.notifier).retranscribe(memo),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => engineStateAsync.when(
        data: (engineState) {
          final isTranscribing =
              engineState.status == TranscriptionEngineStatus.transcribing;

          return _ButtonBox(
            expand: expand,
            child: OutlinedButton.icon(
              style: _compactOutlinedButtonStyle(),
              icon: isTranscribing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.transcribe),
              label: Text(
                isTranscribing
                    ? 'Transcribing...'
                    : (memo.transcription == null
                        ? 'Transcribe'
                        : 'Re-transcribe'),
              ),
              onPressed: isTranscribing
                  ? null
                  : () => ref
                      .read(voiceMemoActionsProvider.notifier)
                      .retranscribe(memo),
            ),
          );
        },
        loading: () => const SizedBox.shrink(),
        error: (_, _) => _ButtonBox(
          expand: expand,
          child: OutlinedButton.icon(
            style: _compactOutlinedButtonStyle(),
            icon: const Icon(Icons.transcribe, size: 18),
            label:
                Text(memo.transcription == null ? 'Transcribe' : 'Re-transcribe'),
            onPressed: () =>
                ref.read(voiceMemoActionsProvider.notifier).retranscribe(memo),
          ),
        ),
      ),
    );
  }
}

class _SyncPromptCard extends ConsumerWidget {
  final VoiceMemo memo;
  final bool compact;
  final bool alignRight;

  const _SyncPromptCard({
    required this.memo,
    this.compact = false,
    this.alignRight = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isConnected = ref.watch(isWatchConnectedProvider);
    final syncStateAsync = ref.watch(voiceMemoSyncStateProvider);

    return Column(
      crossAxisAlignment:
          alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(compact ? 6 : AppTheme.spacingSm),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
          child: Row(
            children: [
              const Icon(Icons.cloud_download_outlined, color: Colors.orange),
              SizedBox(width: compact ? 6 : AppTheme.spacingSm),
              Expanded(
                child: Text(
                  'This note is still on the watch. Sync it to enable playback and transcription.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: compact ? 11 : null,
                      ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: compact ? 8 : AppTheme.spacingMd),
        syncStateAsync.when(
          data: (state) {
            if (!state.isSyncing) {
              return const SizedBox.shrink();
            }

            return Padding(
              padding: EdgeInsets.only(bottom: compact ? 8 : AppTheme.spacingMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const LinearProgressIndicator(),
                  const SizedBox(height: AppTheme.spacingXs),
                  Text(
                    'Syncing in progress...',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        ),
        SizedBox(
          width: compact && alignRight ? null : double.infinity,
          child: FilledButton.icon(
            style: _compactFilledButtonStyle(),
            onPressed: isConnected
                ? () => ref.read(voiceMemoActionsProvider.notifier).sync()
                : null,
            icon: const Icon(Icons.sync),
            label: const Text('Sync now'),
          ),
        ),
        if (!isConnected) ...[
          SizedBox(height: compact ? 6 : AppTheme.spacingSm),
          Text(
            'Connect to your watch to sync this note.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                  fontSize: compact ? 11 : null,
                ),
          ),
        ],
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MetaChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 10.5,
                ),
          ),
        ],
      ),
    );
  }
}

class _ButtonBox extends StatelessWidget {
  final bool expand;
  final Widget child;

  const _ButtonBox({required this.expand, required this.child});

  @override
  Widget build(BuildContext context) {
    if (expand) {
      return SizedBox(width: double.infinity, child: child);
    }

    return Align(alignment: Alignment.centerLeft, child: child);
  }
}

class _VoiceMemoTimelineSection {
  final String label;
  final List<VoiceMemo> memos;

  const _VoiceMemoTimelineSection({
    required this.label,
    required this.memos,
  });
}

List<VoiceMemo> _filterMemos(List<VoiceMemo> memos, String query) {
  if (query.isEmpty) {
    return memos;
  }

  return memos.where((memo) => _matchesQuery(memo, query)).toList();
}

List<_VoiceMemoTimelineSection> _groupMemosByDay(List<VoiceMemo> memos) {
  final grouped = <String, List<VoiceMemo>>{};

  for (final memo in memos) {
    final local = memo.timestampUtc.toLocal();
    final key = DateTime(local.year, local.month, local.day)
        .millisecondsSinceEpoch
        .toString();
    grouped.putIfAbsent(key, () => []).add(memo);
  }

  final keys = grouped.keys.toList()
    ..sort((a, b) => int.parse(b).compareTo(int.parse(a)));

  return keys.map((key) {
    final firstMemo = grouped[key]!.first;
    return _VoiceMemoTimelineSection(
      label: _dayGroupLabel(firstMemo.timestampUtc.toLocal()),
      memos: grouped[key]!,
    );
  }).toList();
}

bool _matchesQuery(VoiceMemo memo, String query) {
  final local = memo.timestampUtc.toLocal();
  final haystack = <String>[
    memo.filename,
    memo.transcription ?? '',
    memo.summary ?? '',
    _dayGroupLabel(local),
    _timelineTimestampLabel(local),
    DateFormat.yMMMMd().format(local),
    DateFormat('MMMM d yyyy').format(local),
  ].join(' ').toLowerCase();

  return haystack.contains(query);
}

String _memoPreviewText(VoiceMemo memo) {
  final aiSummary = memo.summary?.trim();
  if (aiSummary != null && aiSummary.isNotEmpty) {
    return aiSummary;
  }

  final transcript = memo.transcription?.trim();
  if (transcript != null && transcript.isNotEmpty) {
    final lines = transcript.split('\n');
    return lines.first;
  }

  if (memo.syncedFromWatch) {
    return 'Audio synced. Transcription pending.';
  }

  return 'On watch only. Sync to download and transcribe this note.';
}

bool _hasLocalAudio(VoiceMemo memo) {
  final path = memo.convertedFilePath ?? memo.localFilePath;
  return path != null && File(path).existsSync();
}

String _timelineTimestampLabel(DateTime dateTime) {
  return '${_dayGroupLabel(dateTime)} · ${DateFormat.Hm().format(dateTime)}';
}

String _dayGroupLabel(DateTime dateTime) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(dateTime.year, dateTime.month, dateTime.day);
  final difference = today.difference(target).inDays;

  if (difference == 0) {
    return 'Today';
  }
  if (difference == 1) {
    return 'Yesterday';
  }
  return DateFormat.MMMMEEEEd().format(dateTime);
}

String _syncStatusLabel(VoiceMemo memo) {
  if (memo.transcription?.trim().isNotEmpty == true) {
    return 'Ready';
  }
  if (memo.syncedFromWatch) {
    return 'Synced';
  }
  return 'On watch';
}

IconData _syncStatusIcon(VoiceMemoSyncStatus status) {
  return switch (status) {
    VoiceMemoSyncStatus.onWatchOnly => Icons.watch_outlined,
    VoiceMemoSyncStatus.downloading => Icons.downloading_rounded,
    VoiceMemoSyncStatus.synced => Icons.check_circle_outline,
    VoiceMemoSyncStatus.downloadFailed => Icons.error_outline,
    VoiceMemoSyncStatus.transcribed => Icons.text_snippet_outlined,
  };
}

Color _syncStatusColor(VoiceMemoSyncStatus status) {
  return switch (status) {
    VoiceMemoSyncStatus.onWatchOnly => AppTheme.warningColor,
    VoiceMemoSyncStatus.downloading => AppTheme.primaryColor,
    VoiceMemoSyncStatus.synced => AppTheme.successColor,
    VoiceMemoSyncStatus.downloadFailed => AppTheme.errorColor,
    VoiceMemoSyncStatus.transcribed => AppTheme.primaryColor,
  };
}

Future<bool?> _confirmDelete(BuildContext context, VoiceMemo memo) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete recording?'),
      content: Text(
        'Transcript and audio will be removed.\n\n${memo.formattedDuration} · ${_timelineTimestampLabel(memo.timestampUtc.toLocal())}',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
}

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds % 60;
  return '${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}';
}

ButtonStyle _compactOutlinedButtonStyle() {
  return OutlinedButton.styleFrom(
    visualDensity: VisualDensity.compact,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    minimumSize: const Size(0, 34),
    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
  );
}

ButtonStyle _compactFilledButtonStyle() {
  return FilledButton.styleFrom(
    visualDensity: VisualDensity.compact,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    minimumSize: const Size(0, 34),
    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
  );
}

// ---------------------------------------------------------------------------
// Word-level diff helpers
// ---------------------------------------------------------------------------

enum _DiffType { equal, delete, insert }

class _DiffOp {
  final _DiffType type;
  final String word;

  const _DiffOp._(this.type, this.word);
  factory _DiffOp.equal(String word) => _DiffOp._(_DiffType.equal, word);
  factory _DiffOp.delete(String word) => _DiffOp._(_DiffType.delete, word);
  factory _DiffOp.insert(String word) => _DiffOp._(_DiffType.insert, word);
}
