import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';

/// Standard loading/error/data wrapper for [AsyncValue].
///
/// Usage:
/// ```dart
/// AsyncValueWidget<List<Watch>>(
///   value: ref.watch(watchListProvider),
///   data: (watches) => WatchList(watches: watches),
/// )
/// ```
///
/// Error display follows the app contract:
/// - [errorBuilder] overrides the default snackbar-style error card.
/// - The default error card is non-blocking (inline, not full-screen).
class AsyncValueWidget<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final Widget Function(Object error, StackTrace? st)? errorBuilder;
  final Widget? loading;

  const AsyncValueWidget({
    super.key,
    required this.value,
    required this.data,
    this.errorBuilder,
    this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: data,
      loading: () =>
          loading ?? const Center(child: CircularProgressIndicator()),
      error: (e, st) =>
          errorBuilder?.call(e, st) ?? _DefaultErrorWidget(error: e),
    );
  }
}

/// Inline error card for transient / non-blocking errors.
class _DefaultErrorWidget extends StatelessWidget {
  final Object error;

  const _DefaultErrorWidget({required this.error});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: AppTheme.errorColor, size: 40),
          const SizedBox(height: AppTheme.spacingSm),
          Text(
            error.toString(),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.errorColor),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
