import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/companion_firmware_status.dart';
import '../data/models/companion_watchface_status.dart';
import '../services/transfer/transfer_rate_estimator.dart';
import 'companion_runtime_providers.dart';

/// Monotonic time keeps transfer measurements independent of clock corrections.
final transferProgressClockProvider = Provider<Duration Function()>((ref) {
  final clock = Stopwatch()..start();
  ref.onDispose(clock.stop);
  return () => clock.elapsed;
});

enum NativeImageTransfer { firmware, watchface }

/// Shared with every progress view; observing never starts/replays native work.
final nativeTransferRateProvider =
    StateNotifierProvider.family<
      NativeTransferRateNotifier,
      TransferRate,
      NativeImageTransfer
    >((ref, transfer) {
      final notifier = NativeTransferRateNotifier(
        ref.watch(transferProgressClockProvider),
      );
      ref.listen(companionSnapshotProvider, (_, next) {
        final snapshot = next.asData?.value;
        if (snapshot == null || !snapshot.runtimeActive) {
          notifier.clear();
          return;
        }
        try {
          final fields = snapshot.fields;
          String? id, address, phase;
          var current = 0, total = 0;
          var measuring = false;
          if (transfer == NativeImageTransfer.firmware) {
            final status = CompanionFirmwareStatus.decode(fields);
            id = status?.id;
            address = status?.address;
            phase = status?.phase;
            current = status?.current ?? 0;
            total = status?.total ?? 0;
            measuring = {
              'uploading',
              'resource_uploading',
              'resource_verifying',
            }.contains(phase);
          } else {
            final status = CompanionWatchfaceStatus.decode(fields);
            id = status?.id;
            address = status?.address;
            phase = status?.phase;
            current = status?.current ?? 0;
            total = status?.total ?? 0;
            measuring = phase == 'uploading';
          }
          if (!measuring ||
              id == null ||
              address != fields['address'] ||
              total <= 0) {
            notifier.clear();
            return;
          }
          notifier.observe(
            '${fields['owner']}:$address:$id:$phase',
            current,
            total,
          );
        } on FormatException {
          notifier.clear();
        }
      }, fireImmediately: true);
      return notifier;
    });

class NativeTransferRateNotifier extends StateNotifier<TransferRate> {
  final Duration Function() _clock;
  final _estimator = TransferRateEstimator();
  Timer? _timer;
  String? _scope;
  int _current = 0, _total = 0;

  NativeTransferRateNotifier(this._clock) : super(const TransferRate());

  void observe(String scope, int current, int total) {
    if (_scope == scope && _current == current && _total == total) return;
    _scope = scope;
    _current = current;
    _total = total;
    _sample();
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) => _sample());
  }

  void _sample() {
    state = _estimator.sample(
      scope: _scope!,
      current: _current,
      total: _total,
      now: _clock(),
    );
  }

  void clear() {
    _timer?.cancel();
    _timer = null;
    _scope = null;
    _estimator.reset();
    state = const TransferRate();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
