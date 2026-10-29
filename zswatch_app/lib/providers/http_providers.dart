import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'companion_runtime_providers.dart';

final httpRelayEnabledProvider = Provider<bool>(
  (ref) =>
      ref.watch(companionHttpStatusProvider).asData?.value.enabled ?? false,
);
final httpRelayPendingCountProvider = Provider<int>(
  (ref) =>
      ref.watch(companionHttpStatusProvider).asData?.value.pendingCount ?? 0,
);
