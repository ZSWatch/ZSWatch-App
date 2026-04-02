import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/extracted_action.dart';
import '../../../providers/ai_providers.dart';
import '../../../providers/settings_providers.dart';
import '../../../services/ai/extracted_action_creation_service.dart';
import '../../navigation/app_router.dart';

/// Dedicated screen for managing alarm and timer extracted actions.
///
/// On iOS these can't be handed off to the OS automatically, so users
/// need an explicit place to Set, Dismiss, or Delete them.
/// On Android the screen is still useful for reviewing what was created.
class AlarmsTimersScreen extends ConsumerWidget {
  const AlarmsTimersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actionsAsync = ref.watch(alarmTimerActionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alarms & Timers'),
      ),
      body: actionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            'Error loading actions: $error',
            style: const TextStyle(color: AppTheme.errorColor),
          ),
        ),
        data: (actions) {
          if (actions.isEmpty) {
            return const _EmptyState();
          }

          final pending = actions
              .where((a) => !a.created && !a.dismissed)
              .toList();
          final completed = actions
              .where((a) => a.created || a.dismissed)
              .toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacingMd,
              0,
              AppTheme.spacingMd,
              AppTheme.spacingLg,
            ),
            children: [
              if (Platform.isIOS)
                Padding(
                  padding: const EdgeInsets.only(
                    top: AppTheme.spacingSm,
                    bottom: AppTheme.spacingMd,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.elevatedSurfaceColor.withValues(
                        alpha: 0.88,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color:
                            AppTheme.textSecondary.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Text.rich(
                      const TextSpan(
                        children: [
                          TextSpan(
                            text: 'Tip: ',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          TextSpan(
                            text:
                                'Pending items support Set, Dismiss, and Delete. '
                                'Delete removes the extracted action entirely.',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        height: 1.5,
                      ),
                    ),
                  ),
                ),

              // Pending section
              if (pending.isNotEmpty) ...[
                const _SectionHeader(label: 'Pending from notes'),
                for (final action in pending)
                  _AlarmTimerCard(action: action),
              ],

              // Completed section
              if (completed.isNotEmpty) ...[
                const _SectionHeader(label: 'Completed'),
                for (final action in completed)
                  Opacity(
                    opacity: 0.78,
                    child: _AlarmTimerCard(action: action),
                  ),
              ],

              // Manual creation FABs
              const SizedBox(height: 18),
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 10),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppTheme.textSecondary,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _AlarmTimerCard extends ConsumerStatefulWidget {
  final ExtractedAction action;
  const _AlarmTimerCard({required this.action});

  @override
  ConsumerState<_AlarmTimerCard> createState() => _AlarmTimerCardState();
}

class _AlarmTimerCardState extends ConsumerState<_AlarmTimerCard> {
  bool _isCreating = false;
  bool _isDismissing = false;
  bool _isDeleting = false;
  bool _isOpening = false;

  ExtractedAction get action => widget.action;

  @override
  Widget build(BuildContext context) {
    final isPending = !action.created && !action.dismissed;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: time + details
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Time display
                SizedBox(
                  width: 58,
                  child: Text(
                    _timeDisplay(),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Title + description
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        action.title.isNotEmpty
                            ? action.title
                            : (action.actionType == ExtractedActionType.alarm
                                ? 'Alarm'
                                : 'Timer'),
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      if (action.notes != null &&
                          action.notes!.trim().isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          action.notes!.trim(),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: AppTheme.textSecondary,
                                height: 1.5,
                              ),
                        ),
                      ],
                      // Source note link
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () => context.push(
                          AppRoutes.voiceMemoDetail(action.memoId),
                        ),
                        child: Text(
                          'Open source note',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                color: AppTheme.infoColor,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Action buttons
            const SizedBox(height: 12),
            Wrap(
              spacing: AppTheme.spacingSm,
              runSpacing: AppTheme.spacingSm,
              children: [
                if (isPending) ...[
                  FilledButton(
                    style: _compactFilledStyle(),
                    onPressed: _isCreating ? null : _createAction,
                    child: Text(_isCreating ? 'Setting...' : 'Set'),
                  ),
                  OutlinedButton(
                    style: _compactWarnStyle(),
                    onPressed: _isDismissing ? null : _dismissAction,
                    child: Text(_isDismissing ? 'Dismissing...' : 'Dismiss'),
                  ),
                ],
                if (action.created && action.platformTargetId != null)
                  OutlinedButton(
                    style: _compactOutlinedStyle(),
                    onPressed: _isOpening ? null : _openCreatedAction,
                    child: const Text('Open'),
                  ),
                // Delete is always available
                OutlinedButton(
                  style: _compactDangerStyle(),
                  onPressed: _isDeleting ? null : _deleteAction,
                  child: Text(_isDeleting ? 'Deleting...' : 'Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _timeDisplay() {
    if (action.actionType == ExtractedActionType.timer) {
      final d = action.durationSeconds ?? 0;
      final h = d ~/ 3600;
      final m = (d % 3600) ~/ 60;
      final s = d % 60;
      if (h > 0) return '${h}h${m}m';
      if (m > 0 && s > 0) return '${m}m${s}s';
      if (m > 0) return '${m}m';
      return '${s}s';
    }
    // Alarm — show time
    final time = action.startTime;
    if (time != null) {
      return DateFormat.Hm().format(time.toLocal());
    }
    return '--:--';
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to set: $error')),
      );
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  Future<void> _dismissAction() async {
    setState(() => _isDismissing = true);
    try {
      await ref.read(extractedActionOperationsProvider).dismissAction(action.id);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to dismiss: $error')),
      );
    } finally {
      if (mounted) setState(() => _isDismissing = false);
    }
  }

  Future<void> _deleteAction() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete action?'),
        content: const Text(
          'This will permanently remove the extracted action.',
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

    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      await ref.read(extractedActionOperationsProvider).deleteAction(action.id);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete: $error')),
      );
    } finally {
      if (mounted) setState(() => _isDeleting = false);
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
        SnackBar(content: Text('Failed to open: $error')),
      );
    } finally {
      if (mounted) setState(() => _isOpening = false);
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.alarm_outlined,
            size: 64,
            color: Colors.grey.shade600,
          ),
          const SizedBox(height: AppTheme.spacingMd),
          Text(
            'No alarms or timers',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: AppTheme.spacingSm),
          Text(
            'Alarms and timers extracted from your voice notes\nwill appear here.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── Button styles ───────────────────────────────────────────────────────

ButtonStyle _compactFilledStyle() {
  return FilledButton.styleFrom(
    visualDensity: VisualDensity.compact,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    minimumSize: const Size(0, 34),
    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
  );
}

ButtonStyle _compactOutlinedStyle() {
  return OutlinedButton.styleFrom(
    visualDensity: VisualDensity.compact,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    minimumSize: const Size(0, 34),
    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
  );
}

ButtonStyle _compactWarnStyle() {
  return OutlinedButton.styleFrom(
    foregroundColor: AppTheme.primaryColor,
    side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.18)),
    visualDensity: VisualDensity.compact,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    minimumSize: const Size(0, 34),
    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
  );
}

ButtonStyle _compactDangerStyle() {
  return OutlinedButton.styleFrom(
    foregroundColor: AppTheme.errorColor,
    side: BorderSide(color: AppTheme.errorColor.withValues(alpha: 0.18)),
    visualDensity: VisualDensity.compact,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    minimumSize: const Size(0, 34),
    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
  );
}
