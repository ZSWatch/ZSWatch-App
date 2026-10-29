import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/companion_runtime_providers.dart';
import '../../../providers/companion_clock_actions_provider.dart';
import '../../widgets/voice_memos/companion_voice_action_card.dart';

/// Dedicated screen for managing alarm and timer extracted actions.
///
/// On iOS these can't be handed off to the OS automatically, so users
/// need an explicit place to Set, Dismiss, or Delete them.
/// On Android the screen is still useful for reviewing what was created.
class AlarmsTimersScreen extends ConsumerWidget {
  const AlarmsTimersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ref.watch(companionClockActionsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Alarms & Timers')),
      body: actions.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Error loading actions: $error')),
        data: (items) => items.isEmpty
            ? const _EmptyState()
            : ListView(
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                children: [
                  for (final item in items)
                    CompanionVoiceActionCard(
                      key: ValueKey('${item.jobId}:${item.index}'),
                      jobId: item.jobId,
                      index: item.index,
                      action: item.action,
                      state: item.state,
                      canCreate: item.canCreate,
                      onChanged: () =>
                          ref.invalidate(companionVoiceJobProvider(item.jobId)),
                    ),
                ],
              ),
      ),
    );
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
          Icon(Icons.alarm_outlined, size: 64, color: Colors.grey.shade600),
          const SizedBox(height: AppTheme.spacingMd),
          Text(
            'No alarms or timers',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: Colors.grey.shade500),
          ),
          const SizedBox(height: AppTheme.spacingSm),
          Text(
            'Alarms and timers extracted from your voice notes\nwill appear here.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
