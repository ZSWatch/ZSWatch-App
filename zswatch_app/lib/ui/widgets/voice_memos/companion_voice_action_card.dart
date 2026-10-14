import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/models/extracted_action.dart';
import '../../../providers/settings_providers.dart';
import '../../../services/ai/extracted_action_creation_service.dart';

final companionActionCreationProvider =
    Provider<ExtractedActionCreationService>(
      (ref) => const ExtractedActionCreationService(),
    );

/// Shared Dart action review over the native journal, without starting models.
class CompanionVoiceActionCard extends ConsumerStatefulWidget {
  final String jobId;
  final int index;
  final Map<Object?, Object?> action;
  final Map<Object?, Object?>? state;
  final VoidCallback onChanged;
  final bool canCreate;

  const CompanionVoiceActionCard({
    super.key,
    required this.jobId,
    required this.index,
    required this.action,
    this.state,
    required this.onChanged,
    this.canCreate = true,
  });

  @override
  ConsumerState<CompanionVoiceActionCard> createState() =>
      _CompanionVoiceActionCardState();
}

class _CompanionVoiceActionCardState
    extends ConsumerState<CompanionVoiceActionCard> {
  bool busy = false;
  String? error;

  Future<void> run(
    Future<void> Function(ExtractedActionCreationService) operation,
  ) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await operation(ref.read(companionActionCreationProvider));
      if (mounted) widget.onChanged();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> review(ExtractedActionCreationService service) async {
    final draft = ActionCreationDraft.fromVoiceResult(widget.action);
    final calendars = await service.prepareCompanionAction(draft);
    if (!mounted) return;
    final selected = ref.read(selectedProductivityCalendarIdProvider);
    final confirmed = await showDialog<ActionCreationDraft>(
      context: context,
      builder: (context) => _ActionReviewDialog(
        draft: draft,
        calendars: calendars,
        calendarId: selected,
      ),
    );
    if (confirmed == null) return;
    await service.createCompanionDraft(widget.jobId, widget.index, confirmed);
  }

  Future<void> undo(ExtractedActionCreationService service) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove created calendar entry?'),
        content: const Text(
          'The transcript and original recording are retained.',
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
      await service.undoCompanionAction(widget.jobId, widget.index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state?['state'] as String?;
    final clock = ['timer', 'alarm'].contains(widget.action['type']);
    final note =
        widget.action['type'] == 'task' &&
        widget.action['due_date'] == null &&
        widget.action['start_time'] == null;
    final response = widget.state?['response'] as Map<Object?, Object?>?;
    final confirmed = widget.state?['draft'] as Map<Object?, Object?>?;
    final status = switch (state) {
      'created' =>
        defaultTargetPlatform == TargetPlatform.iOS &&
                ['task', 'reminder'].contains(widget.action['type'])
            ? 'Created in Reminders'
            : 'Created in calendar',
      'dispatched' =>
        defaultTargetPlatform == TargetPlatform.iOS
            ? 'Alert scheduled by ZSWatch.'
            : 'Sent to Clock. Manage or remove it in the Clock app.',
      'creating' when clock =>
        defaultTargetPlatform == TargetPlatform.iOS
            ? 'Scheduling was interrupted. An alert may already be scheduled.'
            : 'Interrupted request. Check Clock before creating another timer or alarm.',
      'creating' =>
        'Creation interrupted. Recover the confirmed calendar entry.',
      'undoing' => 'Removal interrupted. Retry to finish removal.',
      'undone' => 'Calendar entry removed',
      'dismissed' => 'Dismissed',
      _ => note ? 'Saved note' : 'Suggested action • Review before creating',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (confirmed?['title'] ?? widget.action['title']) as String,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              [
                widget.action['type'],
                widget.action['due_date'],
                widget.action['start_time'],
                if (widget.action['duration_seconds'] != null)
                  '${widget.action['duration_seconds']} seconds',
              ].whereType<String>().join(' • '),
            ),
            if (widget.action['notes'] is String)
              Text(widget.action['notes'] as String),
            Text(status),
            if (state == 'created' && response?['syncDisabled'] == true)
              const Text('Saved locally. Calendar sync is disabled.'),
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (busy) const LinearProgressIndicator(),
            Wrap(
              spacing: 8,
              children: [
                if (state == null && !note && widget.canCreate)
                  TextButton(
                    onPressed: busy ? null : () => run(review),
                    child: const Text('Review & create'),
                  ),
                if (state == null && widget.canCreate)
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => run(
                            (s) => s.dismissCompanionAction(
                              widget.jobId,
                              widget.index,
                            ),
                          ),
                    child: const Text('Dismiss'),
                  ),
                if (state == 'creating' && !clock && widget.canCreate)
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => run(
                            (s) => s.recoverCompanionAction(
                              widget.jobId,
                              widget.index,
                              widget.state!['draft'] as Map<Object?, Object?>,
                            ),
                          ),
                    child: const Text('Recover creation'),
                  ),
                if (state == 'created')
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => run(
                            (s) => s.openCompanionCalendarEntry(
                              response!['platformId'] as String,
                              ActionCreationDraft.fromVoiceResult(
                                widget.action,
                              ).scheduledAt,
                            ),
                          ),
                    child: const Text('Open calendar'),
                  ),
                if (state == 'created' || state == 'undoing')
                  TextButton(
                    onPressed: busy ? null : () => run(undo),
                    child: const Text('Undo creation'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionReviewDialog extends StatefulWidget {
  final ActionCreationDraft draft;
  final List<PlatformCalendar> calendars;
  final int? calendarId;
  const _ActionReviewDialog({
    required this.draft,
    required this.calendars,
    this.calendarId,
  });
  @override
  State<_ActionReviewDialog> createState() => _ActionReviewDialogState();
}

class _ActionReviewDialogState extends State<_ActionReviewDialog> {
  late final title = TextEditingController(text: widget.draft.title);
  late final seconds = TextEditingController(
    text: widget.draft.durationSeconds?.toString() ?? '',
  );
  late DateTime scheduled =
      widget.draft.scheduledAt ?? DateTime.now().add(const Duration(hours: 1));
  late DateTime end =
      widget.draft.endAt ?? scheduled.add(const Duration(minutes: 30));
  late int? calendarId = widget.calendars.any((c) => c.id == widget.calendarId)
      ? widget.calendarId
      : widget.calendars.firstOrNull?.id;
  String? error;
  bool get clock => [
    ExtractedActionType.timer,
    ExtractedActionType.alarm,
  ].contains(widget.draft.actionType);
  bool get timer => widget.draft.actionType == ExtractedActionType.timer;

  @override
  void dispose() {
    title.dispose();
    seconds.dispose();
    super.dispose();
  }

  Future<void> pick(bool ending) async {
    final current = ending ? end : scheduled;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(1970),
      lastDate: DateTime(2200),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null || !mounted) return;
    setState(() {
      final value = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      if (ending) {
        end = value;
      } else {
        final duration = end.difference(scheduled);
        scheduled = value;
        end = value.add(duration);
      }
    });
  }

  void confirm() {
    try {
      // iOS selects its writable default Calendar/Reminders list in EventKit.
      // Only Android requires a calendar ID from the review picker.
      if (!clock &&
          defaultTargetPlatform == TargetPlatform.android &&
          calendarId == null) {
        throw StateError('No writable calendar is available.');
      }
      final draft = widget.draft.copyWith(
        title: title.text.trim(),
        scheduledAt: scheduled,
        endAt: end,
        durationSeconds: timer ? int.tryParse(seconds.text) ?? 0 : null,
        platformCalendarId: calendarId,
        skipUi: false,
      );
      draft.validateForCreation();
      Navigator.pop(context, draft);
    } catch (e) {
      setState(() => error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Review action'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: title,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          if (timer)
            TextField(
              controller: seconds,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Duration in seconds',
              ),
            )
          else
            TextButton(
              onPressed: () => pick(false),
              child: Text(DateFormat.yMMMd().add_Hm().format(scheduled)),
            ),
          if (widget.draft.actionType == ExtractedActionType.calendarEvent)
            TextButton(
              onPressed: () => pick(true),
              child: Text('End: ${DateFormat.yMMMd().add_Hm().format(end)}'),
            ),
          if (!clock && widget.calendars.isNotEmpty)
            DropdownButton<int>(
              isExpanded: true,
              value: calendarId,
              items: [
                for (final calendar in widget.calendars)
                  DropdownMenuItem(
                    value: calendar.id,
                    child: Text(
                      calendar.label,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) => setState(() => calendarId = value),
            ),
          if (clock)
            Text(
              defaultTargetPlatform == TargetPlatform.iOS
                  ? 'ZSWatch schedules an app notification for this timer or alarm. Notification settings control its sound and delivery.'
                  : 'Opens Clock to review the request. Alarms use the next occurrence of the selected time. Manage or remove them in Clock.',
            ),
          if (error != null) Text(error!),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: confirm,
        child: Text(
          clock
              ? defaultTargetPlatform == TargetPlatform.iOS
                    ? 'Schedule alert'
                    : 'Send to Clock'
              : 'Create',
        ),
      ),
    ],
  );
}
