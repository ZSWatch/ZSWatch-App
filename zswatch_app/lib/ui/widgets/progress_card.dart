import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// A card widget that displays progress information
///
/// Used for:
/// - DFU upload progress
/// - Sync progress
/// - Any operation with percentage completion
class ProgressCard extends StatelessWidget {
  /// Title of the operation
  final String title;

  /// Subtitle/description
  final String? subtitle;

  /// Current progress (0.0 to 1.0)
  final double progress;

  /// Optional status text (e.g., "Uploading...")
  final String? statusText;

  /// Optional additional info (e.g., "2.5 MB / 10 MB")
  final String? infoText;

  /// Optional speed text (e.g., "125 KB/s")
  final String? speedText;

  /// Optional time remaining text
  final String? timeRemainingText;

  /// Whether the operation is indeterminate
  final bool indeterminate;

  /// Whether the operation is complete
  final bool complete;

  /// Whether the operation failed
  final bool error;

  /// Error message if failed
  final String? errorMessage;

  /// Callback when cancel is pressed
  final VoidCallback? onCancel;

  /// Callback when retry is pressed (only shown on error)
  final VoidCallback? onRetry;

  /// Primary color for progress
  final Color? color;

  const ProgressCard({
    super.key,
    required this.title,
    this.subtitle,
    this.progress = 0,
    this.statusText,
    this.infoText,
    this.speedText,
    this.timeRemainingText,
    this.indeterminate = false,
    this.complete = false,
    this.error = false,
    this.errorMessage,
    this.onCancel,
    this.onRetry,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final progressColor = error
        ? AppTheme.errorColor
        : complete
            ? AppTheme.successColor
            : color ?? AppTheme.primaryColor;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                _buildIcon(progressColor),
                const SizedBox(width: AppTheme.spacingSm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                if (onCancel != null && !complete && !error)
                  IconButton(
                    onPressed: onCancel,
                    icon: const Icon(Icons.close_rounded),
                    iconSize: 20,
                    tooltip: 'Cancel',
                  ),
              ],
            ),

            const SizedBox(height: AppTheme.spacingMd),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              child: LinearProgressIndicator(
                value: indeterminate ? null : progress.clamp(0, 1),
                backgroundColor: AppTheme.surfaceColor,
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                minHeight: 8,
              ),
            ),

            const SizedBox(height: AppTheme.spacingSm),

            // Status row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (error && errorMessage != null)
                  Expanded(
                    child: Text(
                      errorMessage!,
                      style: const TextStyle(
                        color: AppTheme.errorColor,
                        fontSize: 12,
                      ),
                    ),
                  )
                else if (statusText != null)
                  Text(
                    statusText!,
                    style: Theme.of(context).textTheme.bodySmall,
                  )
                else if (complete)
                  const Text(
                    'Complete',
                    style: TextStyle(
                      color: AppTheme.successColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  )
                else
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                if (infoText != null && !error)
                  Text(
                    infoText!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),

            // Speed and time remaining
            if ((speedText != null || timeRemainingText != null) &&
                !complete &&
                !error)
              Padding(
                padding: const EdgeInsets.only(top: AppTheme.spacingXs),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (speedText != null)
                      Text(
                        speedText!,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    if (timeRemainingText != null)
                      Text(
                        timeRemainingText!,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                  ],
                ),
              ),

            // Retry button for errors
            if (error && onRetry != null)
              Padding(
                padding: const EdgeInsets.only(top: AppTheme.spacingMd),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Retry'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(Color color) {
    IconData icon;
    if (error) {
      icon = Icons.error_outline_rounded;
    } else if (complete) {
      icon = Icons.check_circle_rounded;
    } else if (indeterminate) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
        ),
      );
    } else {
      icon = Icons.download_rounded;
    }

    return Icon(
      icon,
      color: color,
      size: 24,
    );
  }
}

/// A compact inline progress indicator
class InlineProgress extends StatelessWidget {
  final double progress;
  final String? label;
  final bool indeterminate;

  const InlineProgress({
    super.key,
    this.progress = 0,
    this.label,
    this.indeterminate = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(width: AppTheme.spacingSm),
        ],
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: indeterminate ? null : progress.clamp(0, 1),
              backgroundColor: AppTheme.surfaceColor,
              minHeight: 4,
            ),
          ),
        ),
        if (!indeterminate) ...[
          const SizedBox(width: AppTheme.spacingSm),
          Text(
            '${(progress * 100).toInt()}%',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ],
    );
  }
}

