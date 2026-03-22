import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/voice_memo.dart';
import '../../../providers/voice_memo_providers.dart';

/// A dismissible card for a single voice memo in the timeline list.
class VoiceNoteCard extends ConsumerWidget {
  final VoiceMemo memo;
  final VoidCallback onOpen;

  const VoiceNoteCard({super.key, required this.memo, required this.onOpen});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final previewText = memoPreviewText(memo);
    final canPlay = hasLocalAudio(memo);
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
      confirmDismiss: (_) => confirmDeleteMemo(context, memo),
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
                        padding: const EdgeInsets.only(
                          right: AppTheme.spacingSm,
                        ),
                        child: Icon(
                          voiceNoteCategoryIcon(memo.aiCategory!),
                          size: 20,
                          color: voiceNoteCategoryColor(memo.aiCategory!),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        timelineTimestampLabel(memo.timestampUtc.toLocal()),
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
                    color:
                        memo.summary != null ||
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
                      VoiceMemoMetaChip(
                        icon: voiceNoteCategoryIcon(memo.aiCategory!),
                        label: voiceNoteCategoryLabel(memo.aiCategory!),
                        color: voiceNoteCategoryColor(memo.aiCategory!),
                      ),
                    if (isProcessing)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusXLarge,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Processing',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 10.5,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    VoiceMemoMetaChip(
                      icon: syncStatusIcon(memo.syncStatus),
                      label: syncStatusLabel(memo),
                      color: syncStatusColor(memo.syncStatus),
                    ),
                    if (memo.syncedFromWatch)
                      const VoiceMemoMetaChip(
                        icon: Icons.smartphone_outlined,
                        label: 'Phone',
                        color: AppTheme.primaryColor,
                      ),
                    if (!memo.deletedOnWatch)
                      const VoiceMemoMetaChip(
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

String memoPreviewText(VoiceMemo memo) {
  final aiSummary = memo.summary?.trim();
  if (aiSummary != null && aiSummary.isNotEmpty) return aiSummary;

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
