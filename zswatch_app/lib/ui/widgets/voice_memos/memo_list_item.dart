import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/extracted_action.dart';
import '../../../data/models/voice_memo.dart';
import '../../../providers/voice_memo_providers.dart';

/// A dismissible card for a single voice memo in the timeline list.
///
/// Swipe left to delete, swipe right to archive/unarchive.
class VoiceNoteCard extends ConsumerWidget {
  final VoiceMemo memo;
  final VoidCallback onOpen;
  final int extractedActionCount;
  final Set<ExtractedActionType> actionTypes;

  const VoiceNoteCard({
    super.key,
    required this.memo,
    required this.onOpen,
    this.extractedActionCount = 0,
    this.actionTypes = const {},
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final previewText = memoPreviewText(memo);
    final canPlay = hasLocalAudio(memo);
    final titleText = memoTitleText(memo);

    return Dismissible(
      key: ValueKey('voice-note-${memo.id}'),
      background: Container(
        margin: const EdgeInsets.only(bottom: AppTheme.spacingSm),
        decoration: BoxDecoration(
          color: memo.archived ? AppTheme.primaryColor : AppTheme.warningColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: AppTheme.spacingLg),
        child: Icon(
          memo.archived ? Icons.unarchive_outlined : Icons.archive_outlined,
          color: Colors.white,
        ),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.only(bottom: AppTheme.spacingSm),
        decoration: BoxDecoration(
          color: AppTheme.errorColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppTheme.spacingLg),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          return confirmDeleteMemo(context, memo);
        }
        // Archive/unarchive — no confirmation needed
        await ref
            .read(voiceMemoActionsProvider.notifier)
            .setArchived(memo.filename, archived: !memo.archived);
        return false; // Don't remove the widget, the stream will update
      },
      onDismissed: (_) {
        ref.read(voiceMemoActionsProvider.notifier).delete(memo.filename);
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: AppTheme.spacingSm),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: category icon + title
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CategoryIcon(
                      category: memo.aiCategory,
                      actionTypes: actionTypes,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            titleText,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  height: 1.3,
                                ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            timelineTimestampLabel(memo.timestampUtc.toLocal()),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Preview text
                if (previewText != titleText) ...[
                  const SizedBox(height: 8),
                  Text(
                    previewText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.5,
                      color: const Color(0xFFB6C0CA),
                    ),
                  ),
                ],

                // Footer: tags + play icon
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _NoteTag(label: memo.formattedDuration),
                          if (extractedActionCount > 0)
                            _NoteTag(
                              label: '$extractedActionCount extracted',
                              color: AppTheme.primaryColor,
                              filled: true,
                            ),
                          if (memo.syncedFromWatch)
                            const _NoteTag(
                              label: 'synced',
                              color: AppTheme.successColor,
                              filled: true,
                            ),
                          if (!memo.deletedOnWatch)
                            const _NoteTag(
                              label: 'on watch',
                              color: AppTheme.infoColor,
                              filled: true,
                            ),
                          if (memo.archived)
                            const _NoteTag(
                              label: 'archived',
                              color: AppTheme.textSecondary,
                              filled: true,
                            ),
                          if (!memo.syncedFromWatch &&
                              memo.transcription == null)
                            const _NoteTag(
                              label: 'phone only',
                              color: AppTheme.textSecondary,
                              filled: true,
                            ),
                          if (memo.isAiProcessing)
                            _NoteTag(
                              label: memo.processingStatus == 'queued'
                                  ? 'queued'
                                  : 'processing',
                              color: AppTheme.primaryColor,
                              filled: true,
                              showSpinner: memo.processingStatus != 'queued',
                            ),
                        ],
                      ),
                    ),
                    if (canPlay)
                      const Icon(
                        Icons.play_circle_fill_rounded,
                        color: AppTheme.primaryColor,
                        size: 22,
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
}

class _CategoryIcon extends StatelessWidget {
  final VoiceNoteCategory? category;
  final Set<ExtractedActionType> actionTypes;

  const _CategoryIcon({this.category, this.actionTypes = const {}});

  @override
  Widget build(BuildContext context) {
    final resolved = _resolveIconAndColor();

    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: resolved.bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(resolved.icon, size: 18, color: resolved.color),
    );
  }

  ({IconData icon, Color color, Color bgColor}) _resolveIconAndColor() {
    // Action types take priority for timer/alarm since VoiceNoteCategory
    // doesn't have those values
    if (actionTypes.contains(ExtractedActionType.alarm) ||
        actionTypes.contains(ExtractedActionType.timer)) {
      return (
        icon: Icons.alarm_outlined,
        color: AppTheme.warningColor,
        bgColor: AppTheme.warningColor.withValues(alpha: 0.14),
      );
    }
    if (category != null) {
      return (
        icon: voiceNoteCategoryIcon(category!),
        color: voiceNoteCategoryColor(category!),
        bgColor: _categoryBgColor(category!),
      );
    }
    return (
      icon: Icons.mic_none_rounded,
      color: AppTheme.textSecondary,
      bgColor: AppTheme.textSecondary.withValues(alpha: 0.08),
    );
  }

  Color _categoryBgColor(VoiceNoteCategory cat) {
    return switch (cat) {
      VoiceNoteCategory.idea => AppTheme.primaryColor.withValues(alpha: 0.14),
      VoiceNoteCategory.meeting => AppTheme.infoColor.withValues(alpha: 0.14),
      VoiceNoteCategory.task => AppTheme.successColor.withValues(alpha: 0.14),
      VoiceNoteCategory.reminder => AppTheme.warningColor.withValues(
        alpha: 0.14,
      ),
      VoiceNoteCategory.note => AppTheme.textSecondary.withValues(alpha: 0.08),
    };
  }
}

class _NoteTag extends StatelessWidget {
  final String label;
  final Color? color;
  final bool filled;
  final bool showSpinner;

  const _NoteTag({
    required this.label,
    this.color,
    this.filled = false,
    this.showSpinner = false,
  });

  @override
  Widget build(BuildContext context) {
    final tagColor = color ?? AppTheme.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: filled
            ? tagColor.withValues(alpha: 0.12)
            : AppTheme.textSecondary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showSpinner) ...[
            SizedBox(
              width: 8,
              height: 8,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: tagColor,
              ),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: filled ? tagColor : AppTheme.textSecondary,
              fontWeight: FontWeight.w800,
              fontSize: 10,
              letterSpacing: 0.04,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small icon+label chip used throughout the voice memo UI.
class VoiceMemoMetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const VoiceMemoMetaChip({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
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

// ── Shared helpers ──────────────────────────────────────────────────────────

/// Clean up AI summary text that may contain raw JSON from a previous run.
String cleanSummary(String summary) {
  final trimmed = summary.trim();
  if (trimmed.startsWith('[') || trimmed.startsWith('{')) {
    // Attempt to extract a readable title from JSON
    final titleMatch = RegExp(r'"title"\s*:\s*"([^"]*)"').firstMatch(trimmed);
    final intentMatch = RegExp(r'"intent"\s*:\s*"([^"]*)"').firstMatch(trimmed);
    final intent = intentMatch?.group(1);
    final title = titleMatch?.group(1);

    if (intent == 'timer') {
      final durMatch = RegExp(
        r'"duration_seconds"\s*:\s*(\d+)',
      ).firstMatch(trimmed);
      final d = int.tryParse(durMatch?.group(1) ?? '') ?? 0;
      final h = d ~/ 3600;
      final m = (d % 3600) ~/ 60;
      final s = d % 60;
      final parts = <String>[
        if (h > 0) '${h}h',
        if (m > 0) '${m}m',
        if (s > 0 || (h == 0 && m == 0)) '${s}s',
      ];
      final dur = parts.join(' ');
      return (title != null && title.isNotEmpty)
          ? 'Timer $dur — $title'
          : 'Timer $dur';
    }
    if (intent == 'alarm') {
      final expr = RegExp(
        r'"datetime_expression_english"\s*:\s*"([^"]*)"',
      ).firstMatch(trimmed)?.group(1);
      if (expr != null && expr.isNotEmpty) {
        return (title != null && title.isNotEmpty)
            ? 'Alarm $expr — $title'
            : 'Alarm $expr';
      }
      return (title != null && title.isNotEmpty) ? 'Alarm — $title' : 'Alarm';
    }
    if (title != null && title.isNotEmpty) return title;
  }
  return trimmed;
}

/// Extract a title from the memo — prefer AI summary, fall back to transcript.
String memoTitleText(VoiceMemo memo) {
  final aiSummary = memo.summary?.trim();
  if (aiSummary != null && aiSummary.isNotEmpty) {
    return cleanSummary(aiSummary);
  }

  final transcript = memo.transcription?.trim();
  if (transcript != null && transcript.isNotEmpty) {
    // Use first sentence or first 80 chars as title
    final firstLine = transcript.split('\n').first;
    final periodIdx = firstLine.indexOf('. ');
    if (periodIdx > 0 && periodIdx < 80) {
      return firstLine.substring(0, periodIdx + 1);
    }
    if (firstLine.length > 80) return '${firstLine.substring(0, 77)}...';
    return firstLine;
  }

  if (memo.syncedFromWatch) return 'Audio synced — transcription pending';
  return 'On watch only — sync to download';
}

String memoPreviewText(VoiceMemo memo) {
  final aiSummary = memo.summary?.trim();
  if (aiSummary != null && aiSummary.isNotEmpty) {
    return cleanSummary(aiSummary);
  }

  final transcript = memo.transcription?.trim();
  if (transcript != null && transcript.isNotEmpty) {
    return transcript.split('\n').first;
  }

  if (memo.syncedFromWatch) return 'Audio synced. Transcription pending.';
  return 'On watch only. Sync to download and transcribe this note.';
}

bool hasLocalAudio(VoiceMemo memo) {
  final path = memo.convertedFilePath ?? memo.localFilePath;
  return path != null && File(path).existsSync();
}

String timelineTimestampLabel(DateTime dateTime) =>
    '${dayGroupLabel(dateTime)} · ${DateFormat.Hm().format(dateTime)}';

String dayGroupLabel(DateTime dateTime) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(dateTime.year, dateTime.month, dateTime.day);
  final difference = today.difference(target).inDays;
  if (difference == 0) return 'Today';
  if (difference == 1) return 'Yesterday';
  return DateFormat.MMMMEEEEd().format(dateTime);
}

String syncStatusLabel(VoiceMemo memo) {
  if (memo.transcription?.trim().isNotEmpty == true) return 'Ready';
  if (memo.syncedFromWatch) return 'Synced';
  return 'On watch';
}

IconData syncStatusIcon(VoiceMemoSyncStatus status) => switch (status) {
  VoiceMemoSyncStatus.onWatchOnly => Icons.watch_outlined,
  VoiceMemoSyncStatus.downloading => Icons.downloading_rounded,
  VoiceMemoSyncStatus.synced => Icons.check_circle_outline,
  VoiceMemoSyncStatus.downloadFailed => Icons.error_outline,
  VoiceMemoSyncStatus.transcribed => Icons.text_snippet_outlined,
};

Color syncStatusColor(VoiceMemoSyncStatus status) => switch (status) {
  VoiceMemoSyncStatus.onWatchOnly => AppTheme.warningColor,
  VoiceMemoSyncStatus.downloading => AppTheme.primaryColor,
  VoiceMemoSyncStatus.synced => AppTheme.successColor,
  VoiceMemoSyncStatus.downloadFailed => AppTheme.errorColor,
  VoiceMemoSyncStatus.transcribed => AppTheme.primaryColor,
};

IconData voiceNoteCategoryIcon(VoiceNoteCategory category) =>
    switch (category) {
      VoiceNoteCategory.idea => Icons.lightbulb_outline,
      VoiceNoteCategory.task => Icons.check_box_outlined,
      VoiceNoteCategory.reminder => Icons.alarm,
      VoiceNoteCategory.meeting => Icons.people_outline,
      VoiceNoteCategory.note => Icons.note_outlined,
    };

Color voiceNoteCategoryColor(VoiceNoteCategory category) => switch (category) {
  VoiceNoteCategory.idea => const Color(0xFFFFA726),
  VoiceNoteCategory.task => AppTheme.primaryColor,
  VoiceNoteCategory.reminder => AppTheme.warningColor,
  VoiceNoteCategory.meeting => const Color(0xFF26A69A),
  VoiceNoteCategory.note => AppTheme.textSecondary,
};

String voiceNoteCategoryLabel(VoiceNoteCategory category) => switch (category) {
  VoiceNoteCategory.idea => 'Idea',
  VoiceNoteCategory.task => 'Task',
  VoiceNoteCategory.reminder => 'Reminder',
  VoiceNoteCategory.meeting => 'Meeting',
  VoiceNoteCategory.note => 'Note',
};

Future<bool?> confirmDeleteMemo(BuildContext context, VoiceMemo memo) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete recording?'),
      content: Text(
        'Transcript and audio will be removed.\n\n'
        '${memo.formattedDuration} · ${timelineTimestampLabel(memo.timestampUtc.toLocal())}',
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
