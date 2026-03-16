import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Base class for notifiers that manage an [AsyncValue<void>] state.
///
/// Provides shared helpers for the loading/error/done lifecycle that every
/// action-notifier needs:
///   - [run] wraps an async operation with loading → done/error transitions.
///   - [reset] clears any current error and returns to the idle/data state.
abstract class BaseAsyncNotifier extends StateNotifier<AsyncValue<void>> {
  BaseAsyncNotifier() : super(const AsyncValue.data(null));

  /// Run [action], setting state to loading while in-flight and to
  /// [AsyncValue.error] on failure. Returns `true` on success.
  Future<bool> run(Future<void> Function() action, {bool rethrowError = false}) async {
    state = const AsyncValue.loading();
    try {
      await action();
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      if (rethrowError) rethrow;
      return false;
    }
  }

  /// Clear any error and return to the idle state.
  void reset() {
    state = const AsyncValue.data(null);
  }
}
