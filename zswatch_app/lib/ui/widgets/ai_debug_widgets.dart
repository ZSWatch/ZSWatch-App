import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../services/ai/ai_debug_info.dart';

/// Try to pretty-print a JSON string.  Returns the original string unchanged
/// when it isn't valid JSON.
String aiFormatJson(String raw) {
  try {
    final decoded = jsonDecode(raw);
    return const JsonEncoder.withIndent('  ').convert(decoded);
  } catch (_) {
    return raw;
  }
}

// ---------------------------------------------------------------------------
// Shared UI primitives for AI / benchmark debug bottom sheets.
//
// Used by both:
//   • _BenchmarkDebugSheet  (settings → AI models page)
//   • _AiDebugSheet         (voice memos page)
// ---------------------------------------------------------------------------

/// Drag handle bar shown at the top of a modal bottom sheet.
Widget aiDebugHandleBar() {
  return Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 8),
    child: Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: AppTheme.textSecondary.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}

/// Header row: bug icon · title · optional spinner · optional Stop · Close.
Widget aiDebugSheetHeader(
  BuildContext context, {
  required String title,
  bool showSpinner = false,
  VoidCallback? onStop,
  required VoidCallback onClose,
}) {
  final theme = Theme.of(context);
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      children: [
        const Icon(Icons.bug_report_outlined, size: 20),
        const SizedBox(width: 8),
        Text(title, style: theme.textTheme.titleMedium),
        const Spacer(),
        if (showSpinner)
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
        if (onStop != null)
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.errorColor,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            icon: const Icon(Icons.stop, size: 18),
            label: const Text('Stop'),
            onPressed: onStop,
          ),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: onClose,
        ),
      ],
    ),
  );
}

/// Informational note / empty-state box.
Widget aiDebugNote(BuildContext context, String text) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppTheme.textSecondary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        const Icon(Icons.info_outline, size: 16, color: AppTheme.textSecondary),
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

/// Content block with a title row, optional copy button, and body text.
Widget aiDebugBlock(
  BuildContext context, {
  required String title,
  required String content,
  required IconData icon,
  bool mono = false,
  bool showCopyButton = false,
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
          if (showCopyButton) ...[
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

String aiFormatPromptFlow({
  required String? strategy,
  required bool retryEnabled,
  required int attempts,
}) {
  return 'Strategy: ${strategy ?? 'unknown'}\n'
      'Retry invalid output: ${retryEnabled ? 'enabled' : 'disabled'}\n'
      'Attempts used: $attempts';
}

bool aiHasChronoDetails({
  String? extractedIntent,
  String? extractedTitle,
  String? datetimeExpressionOriginal,
  String? datetimeExpressionEnglish,
  String? resolvedDateTime,
  String? resolverMethod,
  List<ActionChronoDebug> extractedActions = const [],
}) {
  if (extractedActions.isNotEmpty) return true;
  return (extractedIntent?.isNotEmpty ?? false) ||
      (extractedTitle?.isNotEmpty ?? false) ||
      (datetimeExpressionOriginal?.isNotEmpty ?? false) ||
      (datetimeExpressionEnglish?.isNotEmpty ?? false) ||
      (resolvedDateTime?.isNotEmpty ?? false) ||
      (resolverMethod?.isNotEmpty ?? false);
}

String aiFormatChronoDetails({
  String? extractedIntent,
  String? extractedTitle,
  String? datetimeExpressionOriginal,
  String? datetimeExpressionEnglish,
  String? resolvedDateTime,
  String? resolverMethod,
  List<ActionChronoDebug> extractedActions = const [],
}) {
  String show(String? value) =>
      (value != null && value.trim().isNotEmpty) ? value.trim() : 'null';

  // When multiple actions are available, show all of them.
  if (extractedActions.length > 1) {
    final buf = StringBuffer();
    for (var i = 0; i < extractedActions.length; i++) {
      final a = extractedActions[i];
      if (i > 0) buf.writeln();
      buf.writeln('--- Action ${i + 1} ---');
      buf.writeln('Intent: ${show(a.intent)}');
      buf.writeln('Title: ${show(a.title)}');
      buf.writeln('Original time phrase: ${show(a.datetimeExpressionOriginal)}');
      buf.writeln('English time phrase: ${show(a.datetimeExpressionEnglish)}');
      buf.writeln('Resolved datetime: ${show(a.resolvedDateTime)}');
      buf.write('Resolver: ${show(a.resolverMethod)}');
    }
    return buf.toString();
  }

  // Single action — use the direct fields (or the single extractedAction).
  final a = extractedActions.isNotEmpty ? extractedActions.first : null;
  return 'Intent: ${show(a?.intent ?? extractedIntent)}\n'
      'Title: ${show(a?.title ?? extractedTitle)}\n'
      'Original time phrase: ${show(a?.datetimeExpressionOriginal ?? datetimeExpressionOriginal)}\n'
      'English time phrase: ${show(a?.datetimeExpressionEnglish ?? datetimeExpressionEnglish)}\n'
      'Resolved datetime: ${show(a?.resolvedDateTime ?? resolvedDateTime)}\n'
      'Resolver: ${show(a?.resolverMethod ?? resolverMethod)}';
}

/// Small label + value chip used inside metric rows.
Widget aiMetricChip(
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

/// Build the standard metric-chip [Wrap] from optional token / speed / time
/// values.  Returns an empty list when nothing should be shown.
List<Widget> aiMetricChips(
  BuildContext context, {
  int? tokens,
  double? tokensPerSecond,
  Duration? elapsed,
}) {
  return [
    if (tokens != null && tokens > 0)
      aiMetricChip(context, 'Tokens', '$tokens', Icons.token),
    if (tokensPerSecond != null && tokensPerSecond > 0)
      aiMetricChip(
        context,
        'Speed',
        '${tokensPerSecond.toStringAsFixed(1)} t/s',
        Icons.speed,
      ),
    if (elapsed != null && elapsed > Duration.zero)
      aiMetricChip(
        context,
        'Time',
        '${(elapsed.inMilliseconds / 1000).toStringAsFixed(1)}s',
        Icons.timer_outlined,
      ),
  ];
}

/// Live phase header: model name, animated spinner + phase label, metric chips.
Widget aiLivePhaseHeader(
  BuildContext context, {
  required String modelName,
  required String phaseText,
  int? tokens,
  double? tokensPerSecond,
  Duration? elapsed,
}) {
  final theme = Theme.of(context);
  final chips = aiMetricChips(
    context,
    tokens: tokens,
    tokensPerSecond: tokensPerSecond,
    elapsed: elapsed,
  );

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
          modelName,
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
        if (chips.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 16, runSpacing: 8, children: chips),
        ],
      ],
    ),
  );
}

/// Completed status header (benchmark-style: success / error colouring).
Widget aiCompletedHeader(
  BuildContext context, {
  required String modelName,
  required bool isError,
  int? tokens,
  double? tokensPerSecond,
  Duration? elapsed,
}) {
  final theme = Theme.of(context);
  final statusColor =
      isError ? AppTheme.errorColor : AppTheme.successColor;
  final chips = aiMetricChips(
    context,
    tokens: tokens,
    tokensPerSecond: tokensPerSecond,
    elapsed: elapsed,
  );

  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: statusColor.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              size: 18,
              color: statusColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                modelName,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              isError ? 'Failed' : 'Complete',
              style: theme.textTheme.labelSmall?.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        if (chips.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 16, runSpacing: 8, children: chips),
        ],
      ],
    ),
  );
}

/// Completed metrics banner for the voice-memo debug sheet.
/// Shows per-phase timing & throughput in a single box.
Widget aiCompletedMetricsHeader(
  BuildContext context, {
  required String modelName,
  List<Widget> extraChips = const [],
}) {
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
          modelName,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (extraChips.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 16, runSpacing: 8, children: extraChips),
        ],
      ],
    ),
  );
}

/// Memory & inference parameter info block.
///
/// Returns `null` when no memory data is available so callers can skip it with
/// a simple null check:
/// ```dart
/// final memBlock = aiMemoryInfoBlock(context, info);
/// if (memBlock != null) ...[const SizedBox(height: 12), memBlock],
/// ```
Widget? aiMemoryInfoBlock(BuildContext context, AiDebugInfo info) {
  if (info.availableMemoryMB == null) return null;

  final theme = Theme.of(context);
  final isLowMemory = (info.memoryHeadroomMB ?? 999) < 100;
  final statusColor = isLowMemory ? Colors.orange : AppTheme.textSecondary;

  return Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: isLowMemory
          ? Colors.orange.withValues(alpha: 0.08)
          : AppTheme.textSecondary.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(8),
      border: isLowMemory
          ? Border.all(color: Colors.orange.withValues(alpha: 0.3))
          : null,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.memory, size: 14, color: statusColor),
            const SizedBox(width: 4),
            Text(
              'Memory & Inference',
              style: theme.textTheme.labelSmall?.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (isLowMemory) ...[
              const SizedBox(width: 6),
              Icon(Icons.warning_amber_rounded,
                  size: 13, color: Colors.orange),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            if (info.availableMemoryMB != null)
              aiMetricChip(context, 'Available RAM',
                  '${info.availableMemoryMB}MB', Icons.memory),
            if (info.deviceMemoryMB != null)
              aiMetricChip(context, 'Total RAM',
                  '${info.deviceMemoryMB}MB', Icons.phone_android),
            if (info.modelSizeMB != null)
              aiMetricChip(context, 'Model',
                  '${info.modelSizeMB}MB', Icons.smart_toy_outlined),
            if (info.memoryHeadroomMB != null)
              aiMetricChip(context, 'Headroom',
                  '${info.memoryHeadroomMB}MB', Icons.expand),
            if (info.inferenceContextSize != null)
              aiMetricChip(context, 'nCtx',
                  '${info.inferenceContextSize}', Icons.tune),
            if (info.inferenceGpuLayers != null)
              aiMetricChip(context, 'GPU layers',
                  info.inferenceGpuLayers == 0
                      ? 'CPU only'
                      : '${info.inferenceGpuLayers}',
                  Icons.developer_board),
            if (info.inferenceMaxTokensCap != null)
              aiMetricChip(context, 'Max tokens cap',
                  '${info.inferenceMaxTokensCap}', Icons.compress),
          ],
        ),
      ],
    ),
  );
}
