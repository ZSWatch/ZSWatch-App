import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/background/companion_prototype_client.dart';
import '../services/background/ios_telemetry_projector.dart';
import 'companion_runtime_providers.dart';
import 'companion_watch_providers.dart';
import 'watch_providers.dart';

class IosTelemetryProjection extends StateNotifier<AsyncValue<void>> {
  final Future<int?> Function(CompanionPrototypeSnapshot) project;
  final Future<CompanionPrototypeSnapshot> Function(String, int) acknowledge;
  IosTelemetryProjection({required this.project, required this.acknowledge})
    : super(const AsyncValue.data(null));
  CompanionPrototypeSnapshot? _pending;
  bool _working = false;
  bool _disposed = false;

  void observe(CompanionPrototypeSnapshot snapshot) {
    if (_disposed || !snapshot.isIos) return;
    _pending = snapshot;
    if (!_working) unawaited(_drain());
  }

  Future<void> _drain() async {
    _working = true;
    try {
      while (!_disposed && _pending != null) {
        final snapshot = _pending!;
        _pending = null;
        state = const AsyncValue.loading();
        try {
          final cursor = await project(snapshot);
          if (cursor != null) {
            final next = await acknowledge(
              snapshot.fields['journal_id']! as String,
              cursor,
            );
            if (_pending == null &&
                (next.fields['telemetry'] as List).isNotEmpty) {
              _pending = next;
            }
          }
          if (!_disposed) state = const AsyncValue.data(null);
        } catch (error, stack) {
          if (!_disposed) state = AsyncValue.error(error, stack);
          // Retain native receipts. A new observation or explicit retry resumes.
        }
      }
    } finally {
      _working = false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _pending = null;
    super.dispose();
  }
}

final iosTelemetryProjectionStateProvider =
    StateNotifierProvider<IosTelemetryProjection, AsyncValue<void>>((ref) {
      return IosTelemetryProjection(
        project: (snapshot) =>
            IosTelemetryProjector(ref.read(databaseProvider)).project(snapshot),
        acknowledge: (namespace, cursor) =>
            ref.read(companionClientProvider).ackTelemetry(namespace, cursor),
      );
    });

final iosTelemetryProjectionProvider = Provider<void>((ref) {
  final writer = ref.watch(iosTelemetryProjectionStateProvider.notifier);
  void retry() {
    final snapshot = ref.read(companionSnapshotProvider).asData?.value;
    if (snapshot != null) writer.observe(snapshot);
  }

  ref.listen(companionSnapshotProvider, (_, next) {
    final snapshot = next.asData?.value;
    if (snapshot != null) writer.observe(snapshot);
  }, fireImmediately: true);
  // Initial discovery receipts may precede catalogue creation. Retry once its
  // Ready metadata commits; the projector itself never creates a watch row.
  ref.listen(companionWatchPersistenceStateProvider, (_, next) {
    if (next.hasValue && !next.isLoading && !next.hasError) retry();
  });
});
