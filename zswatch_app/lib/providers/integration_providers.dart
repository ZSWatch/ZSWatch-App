import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/ica_status.dart';
import '../services/background/companion_prototype_client.dart';
import 'companion_runtime_providers.dart';

/// The ICA connection as the native owner reports it, with the user's lists.
class IcaStatusNotifier extends StateNotifier<AsyncValue<IcaStatus>> {
  IcaStatusNotifier(this._ref) : super(const AsyncValue.loading()) {
    refresh();
  }

  final Ref _ref;

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => _ref.read(companionClientProvider).icaStatus(),
    );
  }

  Future<void> connect(Map<String, Object?> session) =>
      _run((c) => c.setIcaSession(session));

  Future<void> disconnect() => _run((c) => c.clearIcaSession());

  Future<void> setTarget({required bool newest, String? listId}) =>
      _run((c) => c.setIcaTarget(newest: newest, listId: listId));

  /// Changes keep the shown status on failure; the caller reports the error.
  Future<void> _run(
    Future<IcaStatus> Function(CompanionPrototypeClient client) call,
  ) async {
    state = AsyncValue.data(await call(_ref.read(companionClientProvider)));
  }
}

final icaStatusProvider =
    StateNotifierProvider<IcaStatusNotifier, AsyncValue<IcaStatus>>(
      IcaStatusNotifier.new,
    );
