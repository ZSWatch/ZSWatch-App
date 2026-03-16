import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/voice_memo/voice_memo_sync_service.dart';

/// Displays sync progress at the top of the Voice Notes screen.
class VoiceMemoSyncProgressBar extends StatelessWidget {
  final VoiceMemoSyncState state;

  const VoiceMemoSyncProgressBar({super.key, required this.state});

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
