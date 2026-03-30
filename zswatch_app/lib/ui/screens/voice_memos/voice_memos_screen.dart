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
import '../../navigation/app_router.dart';
import '../../widgets/voice_memos/memo_list_item.dart';
import '../../widgets/voice_memos/sync_progress_bar.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Filter enum for list view
// ═══════════════════════════════════════════════════════════════════════════

enum _NoteFilter { all, notes, tasks, reminders, timersAlarms, archived }

// ═══════════════════════════════════════════════════════════════════════════
// LIST VIEW
// ═══════════════════════════════════════════════════════════════════════════

class VoiceMemosScreen extends ConsumerStatefulWidget {
  const VoiceMemosScreen({super.key});

  @override
  ConsumerState<VoiceMemosScreen> createState() => _VoiceMemosScreenState();
}

class _VoiceMemosScreenState extends ConsumerState<VoiceMemosScreen> {
  late final TextEditingController _searchController;
  String _query = '';
  _NoteFilter _filter = _NoteFilter.notes;

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
    FocusManager.instance.primaryFocus?.unfocus();
    context.push(AppRoutes.voiceMemoDetail(memo.id), extra: memo);
  }

  @override
  Widget build(BuildContext context) {
    final memosAsync = ref.watch(voiceMemoListProvider);
    final syncStateAsync = ref.watch(voiceMemoSyncStateProvider);
    final transcriptionConfiguredAsync = ref.watch(
      transcriptionConfiguredProvider,
    );
    final isConnected = ref.watch(isWatchConnectedProvider);
    final actionTypesMap = ref.watch(memoActionTypesMapProvider).valueOrNull ?? {};
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Notes'),
        actions: [
          if (isConnected)
            IconButton(
              icon: const Icon(Icons.sync),
              tooltip: 'Sync from watch',
              onPressed: () =>
                  ref.read(voiceMemoActionsProvider.notifier).sync(),
            ),
        ],
      ),
      body: Column(
        children: [
          syncStateAsync.when(
            data: (syncState) => VoiceMemoSyncProgressBar(state: syncState),
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
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.orange),
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
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: AppTheme.warningColor,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Choose and download a model in Settings > Voice Memos.',
                            style: Theme.of(context).textTheme.bodySmall
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

          // Filter pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacingMd,
              AppTheme.spacingSm,
              AppTheme.spacingMd,
              0,
            ),
            child: Row(
              children: [
                for (final filter in _NoteFilter.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _FilterPill(
                      label: _filterLabel(filter),
                      icon: _filterIcon(filter),
                      selected: _filter == filter,
                      onTap: () => setState(() => _filter = filter),
                    ),
                  ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacingMd,
              AppTheme.spacingSm,
              AppTheme.spacingMd,
              0,
            ),
            child: TextField(
              controller: _searchController,
              autofocus: false,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText:
                    'Search titles, transcript text, or extracted actions...',
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

          // Count + sort info
          memosAsync.when(
            data: (memos) {
              final filtered = _applyFilters(memos, _filter, _query, actionTypesMap);
              final label = _filter == _NoteFilter.archived
                  ? '${filtered.length} archived'
                  : '${filtered.length} active notes';
              return Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.spacingMd,
                  AppTheme.spacingSm,
                  AppTheme.spacingMd,
                  0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.06,
                      ),
                    ),
                    Text(
                      'Sorted by newest',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.06,
                      ),
                    ),
                  ],
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),

          // Note list
          Expanded(
            child: memosAsync.when(
              data: (memos) {
                final filteredMemos = _applyFilters(memos, _filter, _query, actionTypesMap);

                return RefreshIndicator(
                  onRefresh: () =>
                      ref.read(voiceMemoActionsProvider.notifier).sync(),
                  child: filteredMemos.isEmpty
                      ? _EmptyState(hasQuery: _query.isNotEmpty)
                      : _VoiceMemoTimeline(
                          memos: filteredMemos,
                          onOpenMemo: _openMemo,
                          showArchiveSection: _filter == _NoteFilter.all,
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

  String _filterLabel(_NoteFilter filter) => switch (filter) {
    _NoteFilter.all => 'All',
    _NoteFilter.notes => 'Notes',
    _NoteFilter.tasks => 'Tasks',
    _NoteFilter.reminders => 'Reminders',
    _NoteFilter.timersAlarms => 'Alarms & Timers',
    _NoteFilter.archived => 'Archived',
  };

  IconData _filterIcon(_NoteFilter filter) => switch (filter) {
    _NoteFilter.all => Icons.all_inbox_outlined,
    _NoteFilter.notes => Icons.note_outlined,
    _NoteFilter.tasks => Icons.check_circle_outline,
    _NoteFilter.reminders => Icons.notifications_outlined,
    _NoteFilter.timersAlarms => Icons.alarm_outlined,
    _NoteFilter.archived => Icons.archive_outlined,
  };
}

class _FilterPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppTheme.primaryColor : AppTheme.textSecondary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryColor.withValues(alpha: 0.14)
              : AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? AppTheme.primaryColor.withValues(alpha: 0.22)
                : AppTheme.textSecondary.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DETAIL VIEW
// ═══════════════════════════════════════════════════════════════════════════

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
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              final memo = memoAsync.valueOrNull ?? widget.initialMemo;
              if (memo == null) return;
              switch (value) {
                case 'archive':
                  ref
                      .read(voiceMemoActionsProvider.notifier)
                      .setArchived(memo.filename, archived: !memo.archived);
                case 'delete':
                  _deleteMemo(memo);
                case 'sync':
                  ref.read(voiceMemoActionsProvider.notifier).sync();
              }
            },
            itemBuilder: (context) {
              final memo = memoAsync.valueOrNull ?? widget.initialMemo;
              return [
                PopupMenuItem(
                  value: 'archive',
                  child: Row(
                    children: [
                      Icon(
                        memo?.archived == true
                            ? Icons.unarchive_outlined
                            : Icons.archive_outlined,
                      ),
                      const SizedBox(width: 8),
                      Text(memo?.archived == true ? 'Unarchive' : 'Archive'),
                    ],
                  ),
                ),
                if (ref.watch(isWatchConnectedProvider))
                  const PopupMenuItem(
                    value: 'sync',
                    child: Row(
                      children: [
                        Icon(Icons.sync),
                        SizedBox(width: 8),
                        Text('Sync'),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: AppTheme.errorColor),
                      SizedBox(width: 8),
                      Text('Delete',
                          style: TextStyle(color: AppTheme.errorColor)),
                    ],
                  ),
                ),
              ];
            },
          ),
        ],
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
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category badge + metadata line
                _DetailMetaLine(memo: effectiveMemo),
                const SizedBox(height: 12),

                // Large title
                Text(
                  memoTitleText(effectiveMemo),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 10),

                // Transcript (editable inline)
                _InlineTranscript(
                  memo: effectiveMemo,
                  controller: _transcriptController,
                  isEditing: _isEditing,
                  isSaving: _isSaving,
                  onToggleEdit: () {
                    setState(() {
                      _isEditing = !_isEditing;
                      if (!_isEditing) {
                        _transcriptController.text = currentTranscript;
                      }
                    });
                  },
                  onSave: () => _saveTranscript(effectiveMemo),
                  onCancel: () {
                    setState(() {
                      _isEditing = false;
                      _transcriptController.text = currentTranscript;
                    });
                  },
                ),

                // Quick status chips
                const SizedBox(height: 14),
                _QuickStatusChips(memo: effectiveMemo),

                // Audio player
                const SizedBox(height: 18),
                _DetailAudioPlayer(memo: effectiveMemo),

                // Micro tools
                const SizedBox(height: 14),
                _MicroTools(memo: effectiveMemo),

                // Extracted Actions (at bottom)
                const SizedBox(height: 20),
                _ExtractedActionsSection(memo: effectiveMemo),

                // Bottom toolbar
                const SizedBox(height: 18),
                _BottomToolbar(
                  memo: effectiveMemo,
                  onDelete: () => _deleteMemo(effectiveMemo),
                ),
              ],
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
      await ref
          .read(voiceMemoRepositoryProvider)
          .updateTranscription(
            filename: memo.filename,
            transcription: _transcriptController.text.trim(),
          );
      if (!mounted) {
        return;
      }
      setState(() => _isEditing = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Transcript updated')));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _deleteMemo(VoiceMemo memo) async {
    final shouldDelete = await confirmDeleteMemo(context, memo);
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

// ─── Detail sub-widgets ──────────────────────────────────────────────────

class _DetailMetaLine extends StatelessWidget {
  final VoiceMemo memo;
  const _DetailMetaLine({required this.memo});

  @override
  Widget build(BuildContext context) {
    final local = memo.timestampUtc.toLocal();
    final dateStr = DateFormat('MMMM d, HH:mm').format(local);
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (memo.aiCategory != null)
          _CategoryBadge(category: memo.aiCategory!),
        Text(
          '$dateStr · ${memo.formattedDuration} · ${memo.formattedSize}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// Combined transcript display + inline edit. Replaces both _AISummaryLede
/// and _TranscriptSection so there's a single transcript area.
class _InlineTranscript extends ConsumerWidget {
  final VoiceMemo memo;
  final TextEditingController controller;
  final bool isEditing;
  final bool isSaving;
  final VoidCallback onToggleEdit;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  const _InlineTranscript({
    required this.memo,
    required this.controller,
    required this.isEditing,
    required this.isSaving,
    required this.onToggleEdit,
    required this.onSave,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aiEnabled = ref.watch(localAiEnabledProvider);
    final isProcessing = memo.isAiProcessing;
    final hasFailed =
        memo.aiProcessingStatus == VoiceNoteProcessingStatus.failed;
    final currentTranscript = memo.transcription ?? '';
    final hasTranscript = currentTranscript.trim().isNotEmpty;

    // AI processing status line (compact)
    if (isProcessing) {
      return _aiProcessingRow(context, ref);
    }

    if (hasFailed) {
      return _aiFailedRow(context, ref);
    }

    // Editing mode
    if (isEditing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            minLines: 4,
            maxLines: null,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.65,
              color: const Color(0xFFC5D0DA),
            ),
            decoration: const InputDecoration(
              hintText: 'Edit transcript text...',
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              OutlinedButton(
                style: _compactOutlinedButtonStyle(),
                onPressed: isSaving ? null : onCancel,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: AppTheme.spacingSm),
              FilledButton(
                style: _compactFilledButtonStyle(),
                onPressed: isSaving ? null : onSave,
                child: Text(isSaving ? 'Saving...' : 'Save'),
              ),
            ],
          ),
        ],
      );
    }

    // Normal display
    if (!hasTranscript) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Transcription will appear here after sync and transcription finish.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.65,
              color: AppTheme.textSecondary,
            ),
          ),
          if (aiEnabled &&
              memo.summary == null) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: _compactOutlinedButtonStyle(),
              onPressed: null,
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: const Text('Process with AI'),
            ),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(
          currentTranscript,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            height: 1.65,
            color: const Color(0xFFB6C0CA),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            GestureDetector(
              onTap: onToggleEdit,
              child: Text(
                'Edit',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (aiEnabled && memo.summary == null) ...[
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () => ref
                    .read(aiActionsProvider.notifier)
                    .processVoiceMemo(memo.filename),
                child: Text(
                  'Process with AI',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _aiProcessingRow(BuildContext context, WidgetRef ref) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _showAiDebugDialog(context),
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
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppTheme.textSecondary),
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
    );
  }

  Widget _aiFailedRow(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Text(
          'AI processing failed.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: AppTheme.errorColor),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          style: _compactOutlinedButtonStyle(),
          onPressed: () => ref
              .read(aiActionsProvider.notifier)
              .processVoiceMemo(memo.filename),
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Retry'),
        ),
      ],
    );
  }

  void _showAiDebugDialog(BuildContext context) {
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
        builder: (context, scrollController) =>
            _AiDebugSheet(memo: memo, scrollController: scrollController),
      ),
    );
  }
}

class _QuickStatusChips extends StatelessWidget {
  final VoiceMemo memo;
  const _QuickStatusChips({required this.memo});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        if (memo.isAiProcessed) _statusChip(context, 'AI processed'),
        if (memo.syncedFromWatch)
          _statusChip(context, 'Synced from watch'),
        if (hasLocalAudio(memo))
          _statusChip(context, 'Stored on phone'),
        if (!memo.deletedOnWatch)
          _statusChip(context, 'On watch'),
        if (memo.archived)
          _statusChip(context, 'Archived'),
      ],
    );
  }

  Widget _statusChip(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppTheme.textSecondary.withValues(alpha: 0.12),
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppTheme.textSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DetailAudioPlayer extends ConsumerWidget {
  final VoiceMemo memo;
  const _DetailAudioPlayer({required this.memo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (hasLocalAudio(memo)) {
      return _AudioPlayerBar(memo: memo);
    }

    return _SyncPromptCard(memo: memo);
  }
}

class _AudioPlayerBar extends ConsumerStatefulWidget {
  final VoiceMemo memo;
  const _AudioPlayerBar({required this.memo});

  @override
  ConsumerState<_AudioPlayerBar> createState() => _AudioPlayerBarState();
}

class _AudioPlayerBarState extends ConsumerState<_AudioPlayerBar> {
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
    final path =
        widget.memo.convertedFilePath ?? widget.memo.localFilePath;
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
        if (mounted) setState(() => _position = position);
      });

      _player!.playerStateStream.listen((state) {
        if (!mounted) return;
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
      return Text(_error!, style: const TextStyle(color: AppTheme.errorColor));
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.elevatedSurfaceColor.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.textSecondary.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          // Play button
          GestureDetector(
            onTap: () {
              if (_isPlaying) {
                _player?.pause();
              } else {
                _player?.play();
              }
            },
            child: Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: AppTheme.primaryColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.black,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Slider
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 6,
                ),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                padding: EdgeInsets.zero,
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
          const SizedBox(width: 8),
          Text(
            '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MicroTools extends ConsumerWidget {
  final VoiceMemo memo;
  const _MicroTools({required this.memo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTranscript = memo.transcription ?? '';
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MicroToolButton(
            label: 'Copy',
            icon: Icons.copy_outlined,
            onPressed: currentTranscript.trim().isEmpty
                ? null
                : () async {
                    await Clipboard.setData(
                      ClipboardData(text: currentTranscript),
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Transcript copied to clipboard'),
                      ),
                    );
                  },
          ),
          const SizedBox(width: AppTheme.spacingSm),
          _TranscribeButton(memo: memo, expand: false),
          if (ref.watch(localAiEnabledProvider)) ...[
            const SizedBox(width: AppTheme.spacingSm),
            _MicroToolButton(
              label: 'Re-process',
              icon: Icons.auto_awesome_outlined,
              onPressed: currentTranscript.trim().isEmpty
                  ? null
                  : () => ref
                        .read(aiActionsProvider.notifier)
                        .processVoiceMemo(memo.filename),
            ),
          ],
          const SizedBox(width: AppTheme.spacingSm),
          _MicroToolButton(
            label: 'Debug',
            icon: Icons.bug_report_outlined,
            onPressed: () {
              showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                backgroundColor: AppTheme.elevatedSurfaceColor,
                shape: const RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(16)),
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
            },
          ),
        ],
      ),
    );
  }
}

class _MicroToolButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  const _MicroToolButton({required this.label, this.icon, this.onPressed});

  @override
  Widget build(BuildContext context) {
    if (icon != null) {
      return OutlinedButton.icon(
        style: _compactOutlinedButtonStyle(),
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label),
      );
    }
    return OutlinedButton(
      style: _compactOutlinedButtonStyle(),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

class _BottomToolbar extends ConsumerWidget {
  final VoiceMemo memo;
  final VoidCallback onDelete;

  const _BottomToolbar({required this.memo, required this.onDelete});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: AppTheme.textSecondary.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Wrap(
        spacing: AppTheme.spacingSm,
        runSpacing: AppTheme.spacingSm,
        children: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.errorColor,
              side: BorderSide(
                color: AppTheme.errorColor.withValues(alpha: 0.18),
              ),
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              minimumSize: const Size(0, 34),
              textStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            onPressed: onDelete,
            child: const Text('Delete'),
          ),
          OutlinedButton(
            style: _compactOutlinedButtonStyle(),
            onPressed: () {
              ref
                  .read(voiceMemoActionsProvider.notifier)
                  .setArchived(memo.filename, archived: !memo.archived);
            },
            child: Text(memo.archived ? 'Unarchive' : 'Archive'),
          ),
          if (ref.watch(isWatchConnectedProvider) && !hasLocalAudio(memo))
            OutlinedButton(
              style: _compactOutlinedButtonStyle(),
              onPressed: () =>
                  ref.read(voiceMemoActionsProvider.notifier).sync(),
              child: const Text('Sync'),
            ),
        ],
      ),
    );
  }
}

class _DividerLabel extends StatelessWidget {
  final String label;

  const _DividerLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 1,
            color: AppTheme.textSecondary.withValues(alpha: 0.08),
          ),
        ),
      ],
    );
  }
}

// ─── Extracted Actions in detail view ────────────────────────────────────

class _ExtractedActionsSection extends ConsumerStatefulWidget {
  final VoiceMemo memo;

  const _ExtractedActionsSection({required this.memo});

  @override
  ConsumerState<_ExtractedActionsSection> createState() =>
      _ExtractedActionsSectionState();
}

class _ExtractedActionsSectionState
    extends ConsumerState<_ExtractedActionsSection> {
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

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DividerLabel(label: 'Extracted actions · ${actions.length}'),
            const SizedBox(height: 10),
            for (final action in actions) ...[
              _ActionCard(action: action),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}

class _ActionCard extends ConsumerStatefulWidget {
  final ExtractedAction action;

  const _ActionCard({required this.action});

  @override
  ConsumerState<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends ConsumerState<_ActionCard> {
  bool _isCreating = false;
  bool _isDismissing = false;
  bool _isOpening = false;

  ExtractedAction get action => widget.action;

  Color get _accentColor => switch (action.actionType) {
    ExtractedActionType.calendarEvent => AppTheme.infoColor,
    ExtractedActionType.reminder => AppTheme.warningColor,
    ExtractedActionType.alarm => AppTheme.primaryColor,
    ExtractedActionType.timer => Colors.teal,
    ExtractedActionType.task => AppTheme.successColor,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.textSecondary.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left color bar
            Container(width: 4, color: _accentColor),
            // Content
            Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppTheme.textSecondary.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _actionTypeIcon(action.actionType),
                          size: 16,
                          color: _accentColor,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _actionDisplayTitle(action),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            if (_timingLabel(action) case final timing?)
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Text(
                                  timing,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: AppTheme.textSecondary,
                                      ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      _ActionStatusBadge(action: action),
                    ],
                  ),
                  if (action.notes != null &&
                      action.notes!.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      action.notes!.trim(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                  // Action buttons
                  if (action.actionType != ExtractedActionType.task ||
                      action.startTime != null ||
                      action.dueDate != null ||
                      action.durationSeconds != null) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: AppTheme.spacingSm,
                      runSpacing: AppTheme.spacingSm,
                      children: [
                        if (!action.created && !action.dismissed)
                          FilledButton(
                            style: _compactFilledButtonStyle(),
                            onPressed: _isCreating ? null : _createAction,
                            child: Text(
                              _isCreating
                                  ? 'Creating...'
                                  : _createLabel(action),
                            ),
                          ),
                        if (!action.created && !action.dismissed)
                          OutlinedButton(
                            style: _compactOutlinedWarnStyle(),
                            onPressed: _isDismissing ? null : _dismissAction,
                            child: const Text('Dismiss'),
                          ),
                        if (action.created && action.platformTargetId != null)
                          OutlinedButton(
                            style: _compactOutlinedButtonStyle(),
                            onPressed: _isOpening ? null : _openCreatedAction,
                            child: const Text('Open'),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }

  String _createLabel(ExtractedAction action) {
    if (Platform.isIOS &&
        (action.actionType == ExtractedActionType.alarm ||
            action.actionType == ExtractedActionType.timer)) {
      return 'Set on iPhone';
    }
    return 'Create';
  }

  Future<void> _createAction() async {
    setState(() => _isCreating = true);
    try {
      final selectedCalendarId = ref.read(
        selectedProductivityCalendarIdProvider,
      );
      final draft = ActionCreationDraft.fromAction(action).copyWith(
        platformCalendarId: Platform.isAndroid ? selectedCalendarId : null,
      );

      final message = await ref
          .read(extractedActionOperationsProvider)
          .createAction(action: action, draft: draft);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
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
      await ref
          .read(extractedActionOperationsProvider)
          .dismissAction(action.id);
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
}

ButtonStyle _compactOutlinedWarnStyle() {
  return OutlinedButton.styleFrom(
    foregroundColor: AppTheme.primaryColor,
    side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.18)),
    visualDensity: VisualDensity.compact,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    minimumSize: const Size(0, 34),
    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
  );
}

IconData _actionTypeIcon(ExtractedActionType type) {
  return switch (type) {
    ExtractedActionType.task => Icons.check_box_outlined,
    ExtractedActionType.reminder => Icons.alarm,
    ExtractedActionType.calendarEvent => Icons.calendar_today,
    ExtractedActionType.timer => Icons.timer,
    ExtractedActionType.alarm => Icons.alarm_add,
  };
}

String _actionDisplayTitle(ExtractedAction action) {
  if (action.actionType == ExtractedActionType.timer) {
    final d = action.durationSeconds ?? 0;
    final h = d ~/ 3600;
    final m = (d % 3600) ~/ 60;
    final s = d % 60;
    final parts = <String>[
      if (h > 0) '${h}h',
      if (m > 0) '${m}m',
      if (s > 0 || (h == 0 && m == 0)) '${s}s',
    ];
    final duration = parts.join(' ');
    if (action.title.isNotEmpty) {
      return 'Timer $duration — ${action.title}';
    }
    return 'Timer $duration';
  }
  if (action.actionType == ExtractedActionType.alarm) {
    final time = action.startTime;
    if (time != null) {
      final t = time.toLocal();
      final formatted = DateFormat.jm().format(t);
      if (action.title.isNotEmpty) {
        return 'Alarm at $formatted — ${action.title}';
      }
      return 'Alarm at $formatted';
    }
    if (action.title.isNotEmpty) return 'Alarm — ${action.title}';
    return 'Alarm';
  }
  return action.title;
}

String? _timingLabel(ExtractedAction action) {
  if (action.actionType == ExtractedActionType.timer ||
      action.actionType == ExtractedActionType.alarm) {
    return null;
  }

  final dateFormat = DateFormat.yMMMd();
  final dateTimeFormat = DateFormat.yMMMd().add_jm();

  if (action.startTime != null) {
    final start = action.startTime!.toLocal();
    if (action.endTime != null) {
      final end = action.endTime!.toLocal();
      return '${dateTimeFormat.format(start)} \u2192 ${dateTimeFormat.format(end)}';
    }
    return dateTimeFormat.format(start);
  }

  if (action.dueDate != null) {
    return 'Due: ${dateFormat.format(action.dueDate!.toLocal())}';
  }

  return null;
}

class _ActionStatusBadge extends StatelessWidget {
  final ExtractedAction action;

  const _ActionStatusBadge({required this.action});

  @override
  Widget build(BuildContext context) {
    // For simple tasks with no timing info, there's nothing to "create"
    // so don't show a misleading "Pending" badge.
    final isActionable = action.actionType != ExtractedActionType.task ||
        action.startTime != null ||
        action.dueDate != null ||
        action.durationSeconds != null;

    final (label, color) = switch ((action.created, action.dismissed)) {
      (true, _) => ('Created', AppTheme.successColor),
      (_, true) => ('Dismissed', AppTheme.textSecondary),
      _ when isActionable => ('Pending', AppTheme.warningColor),
      _ => (null, null),
    };

    if (label == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color!.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 10,
          letterSpacing: 0.05,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: voiceNoteCategoryColor(category).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        voiceNoteCategoryLabel(category).toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: voiceNoteCategoryColor(category),
          fontWeight: FontWeight.w800,
          fontSize: 11,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─── AI Debug Sheet ──────────────────────────────────────────────────────

class _AiDebugSheet extends ConsumerWidget {
  final VoiceMemo memo;
  final ScrollController scrollController;

  const _AiDebugSheet({required this.memo, required this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streamValue = ref.watch(aiProcessingDebugInfoProvider).valueOrNull;
    final liveInfo =
        (streamValue != null && streamValue.filename == memo.filename)
        ? streamValue
        : null;
    final storedInfo = ref
        .read(voiceNoteAiPipelineProvider)
        .getDebugInfoForFile(memo.filename);
    final debugInfo = liveInfo ?? storedInfo;
    final theme = Theme.of(context);

    return Column(
      children: [
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
                const Padding(
                  padding: EdgeInsets.only(right: 8),
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
                if (debugInfo.parsedJson != null) ...[
                  _debugBlock(
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
                  datetimeExpressionOriginal:
                      debugInfo.datetimeExpressionOriginal,
                  datetimeExpressionEnglish:
                      debugInfo.datetimeExpressionEnglish,
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
                      datetimeExpressionOriginal:
                          debugInfo.datetimeExpressionOriginal,
                      datetimeExpressionEnglish:
                          debugInfo.datetimeExpressionEnglish,
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
              const SizedBox(
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
              _metricChip(context, 'Tokens', '${info.tokens}', Icons.token),
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

  Widget _debugNote(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.textSecondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline,
            size: 16,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
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
        if (memo.aiModel != null) _kvRow(context, 'Model', memo.aiModel!),
        if (memo.summary != null) _kvRow(context, 'Summary', memo.summary!),
        if (memo.aiCategory != null)
          _kvRow(context, 'Category', memo.aiCategory!.name),
        if (memo.transcription != null) ...[
          const SizedBox(height: 12),
          Text('Transcription', style: theme.textTheme.labelMedium),
          const SizedBox(height: 4),
          SelectableText(memo.transcription!, style: theme.textTheme.bodySmall),
        ],
      ],
    );
  }

  Widget _metricsRow(BuildContext context, AiDebugInfo info) {
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
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
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
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: AppTheme.textSecondary),
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
            const Icon(
              Icons.compare_arrows,
              size: 16,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              'Transcription Diff',
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: AppTheme.textSecondary),
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

  List<TextSpan> _computeWordDiffSpans(
    List<String> origWords,
    List<String> corrWords,
    BuildContext context,
  ) {
    final n = origWords.length;
    final m = corrWords.length;

    final dp = List.generate(n + 1, (_) => List.filled(m + 1, 0));
    for (var i = 1; i <= n; i++) {
      for (var j = 1; j <= m; j++) {
        if (origWords[i - 1].toLowerCase() == corrWords[j - 1].toLowerCase()) {
          dp[i][j] = dp[i - 1][j - 1] + 1;
        } else {
          dp[i][j] =
              dp[i - 1][j] > dp[i][j - 1] ? dp[i - 1][j] : dp[i][j - 1];
        }
      }
    }

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
    final orderedOps = ops.reversed.toList();

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
          spans.add(
            TextSpan(
              text: op.word,
              style: const TextStyle(
                backgroundColor: Color(0x40EF5350),
                decoration: TextDecoration.lineThrough,
                decorationColor: Color(0xFFEF5350),
              ),
            ),
          );
          break;
        case _DiffType.insert:
          spans.add(
            TextSpan(
              text: op.word,
              style: const TextStyle(
                backgroundColor: Color(0x4066BB6A),
                fontWeight: FontWeight.w600,
              ),
            ),
          );
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
            const Icon(
              Icons.check_circle_outline,
              size: 16,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              'Parsed Result',
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: AppTheme.textSecondary),
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
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
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

// ─── List view shared widgets ────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool hasQuery;

  const _EmptyState({this.hasQuery = false});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.45,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  hasQuery ? Icons.search_off_rounded : Icons.mic_none_rounded,
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
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
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
  final bool showArchiveSection;

  const _VoiceMemoTimeline({
    required this.memos,
    required this.onOpenMemo,
    this.showArchiveSection = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Split archived and active
    final active = memos.where((m) => !m.archived).toList();
    final archived = memos.where((m) => m.archived).toList();
    final activeSections = _groupMemosByDay(active);
    final archivedSections = _groupMemosByDay(archived);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingMd,
        AppTheme.spacingSm,
        AppTheme.spacingMd,
        AppTheme.spacingLg,
      ),
      children: [
        for (final section in activeSections) ...[
          Padding(
            padding: const EdgeInsets.only(
              top: AppTheme.spacingSm,
              bottom: AppTheme.spacingSm,
            ),
            child: Text(
              section.label.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
          for (final memo in section.memos)
            _MemoCardWithActionCount(
              memo: memo,
              onOpen: () => onOpenMemo(memo),
            ),
        ],
        // Archived section (only if showing all or explicit archived filter)
        if (showArchiveSection && archived.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(
              top: AppTheme.spacingMd,
              bottom: AppTheme.spacingSm,
            ),
            child: Text(
              'ARCHIVED',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
          for (final section in archivedSections) ...[
            for (final memo in section.memos)
              Opacity(
                opacity: 0.88,
                child: _MemoCardWithActionCount(
                  memo: memo,
                  onOpen: () => onOpenMemo(memo),
                ),
              ),
          ],
        ],
        // When showing archived filter only, show them without opacity change
        if (!showArchiveSection)
          for (final section in _groupMemosByDay(memos.where((m) => m.archived).toList()))
            ...[
              Padding(
                padding: const EdgeInsets.only(
                  top: AppTheme.spacingSm,
                  bottom: AppTheme.spacingSm,
                ),
                child: Text(
                  section.label.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              for (final memo in section.memos)
                _MemoCardWithActionCount(
                  memo: memo,
                  onOpen: () => onOpenMemo(memo),
                ),
            ],
      ],
    );
  }
}

/// Wrapper that watches the action count for a memo before rendering the card.
class _MemoCardWithActionCount extends ConsumerWidget {
  final VoiceMemo memo;
  final VoidCallback onOpen;

  const _MemoCardWithActionCount({
    required this.memo,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actionsAsync = ref.watch(extractedActionsForMemoProvider(memo.id));
    final actionCount = actionsAsync.valueOrNull?.length ?? 0;

    return VoiceNoteCard(
      memo: memo,
      onOpen: onOpen,
      extractedActionCount: actionCount,
    );
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

class _SyncPromptCard extends ConsumerWidget {
  final VoiceMemo memo;

  const _SyncPromptCard({required this.memo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isConnected = ref.watch(isWatchConnectedProvider);
    final syncStateAsync = ref.watch(voiceMemoSyncStateProvider);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_download_outlined, color: Colors.orange),
              const SizedBox(width: AppTheme.spacingSm),
              Expanded(
                child: Text(
                  'This note is still on the watch. Sync to enable playback.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          syncStateAsync.when(
            data: (state) {
              if (!state.isSyncing) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  children: [
                    const LinearProgressIndicator(),
                    const SizedBox(height: 4),
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
          FilledButton.icon(
            style: _compactFilledButtonStyle(),
            onPressed: isConnected
                ? () => ref.read(voiceMemoActionsProvider.notifier).sync()
                : null,
            icon: const Icon(Icons.sync),
            label: const Text('Sync now'),
          ),
          if (!isConnected) ...[
            const SizedBox(height: 6),
            Text(
              'Connect to your watch to sync this note.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TranscribeButton extends ConsumerWidget {
  final VoiceMemo memo;
  final bool expand;

  const _TranscribeButton({required this.memo, this.expand = true});

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
              label: const Text('Set up transcription'),
              onPressed: () => context.push(AppRoutes.settings),
            ),
          );
        }

        return engineStateAsync.when(
          data: (engineState) {
            final isTranscribing =
                engineState.status == TranscriptionEngineStatus.transcribing;
            final buttonLabel = memo.transcription == null
                ? 'Transcribe'
                : 'Re-transcribe';

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
              label: Text(
                memo.transcription == null ? 'Transcribe' : 'Re-transcribe',
              ),
              onPressed: () => ref
                  .read(voiceMemoActionsProvider.notifier)
                  .retranscribe(memo),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
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

// ─── Shared helpers ──────────────────────────────────────────────────────

class _VoiceMemoTimelineSection {
  final String label;
  final List<VoiceMemo> memos;

  const _VoiceMemoTimelineSection({required this.label, required this.memos});
}

List<VoiceMemo> _applyFilters(
  List<VoiceMemo> memos,
  _NoteFilter filter,
  String query,
  Map<int, Set<String>> actionTypesMap,
) {
  var result = memos;

  // Apply filter
  result = switch (filter) {
    _NoteFilter.all => result.where((m) => !m.archived).toList(),
    _NoteFilter.notes => result.where((m) {
        if (m.archived) return false;
        // Exclude memos that have any reminder/timer/alarm actions
        final types = actionTypesMap[m.id];
        if (types != null &&
            types.any((t) => t == 'alarm' || t == 'timer' || t == 'reminder')) {
          return false;
        }
        return true;
      }).toList(),
    _NoteFilter.tasks => result
        .where((m) {
          if (m.archived) return false;
          final types = actionTypesMap[m.id];
          return types != null && types.any((t) => t == 'task' || t == 'calendar_event');
        })
        .toList(),
    _NoteFilter.reminders => result
        .where((m) {
          if (m.archived) return false;
          final types = actionTypesMap[m.id];
          return types != null && types.contains('reminder');
        })
        .toList(),
    _NoteFilter.timersAlarms => result
        .where((m) {
          if (m.archived) return false;
          final types = actionTypesMap[m.id];
          return types != null && types.any((t) => t == 'alarm' || t == 'timer');
        })
        .toList(),
    _NoteFilter.archived => result.where((m) => m.archived).toList(),
  };

  // Apply search query
  if (query.isNotEmpty) {
    result = result.where((memo) => _matchesQuery(memo, query)).toList();
  }

  return result;
}

List<_VoiceMemoTimelineSection> _groupMemosByDay(List<VoiceMemo> memos) {
  final grouped = <String, List<VoiceMemo>>{};

  for (final memo in memos) {
    final local = memo.timestampUtc.toLocal();
    final key = DateTime(
      local.year,
      local.month,
      local.day,
    ).millisecondsSinceEpoch.toString();
    grouped.putIfAbsent(key, () => []).add(memo);
  }

  final keys = grouped.keys.toList()
    ..sort((a, b) => int.parse(b).compareTo(int.parse(a)));

  return keys.map((key) {
    final firstMemo = grouped[key]!.first;
    return _VoiceMemoTimelineSection(
      label: dayGroupLabel(firstMemo.timestampUtc.toLocal()),
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
    dayGroupLabel(local),
    timelineTimestampLabel(local),
    DateFormat.yMMMMd().format(local),
    DateFormat('MMMM d yyyy').format(local),
  ].join(' ').toLowerCase();

  return haystack.contains(query);
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
