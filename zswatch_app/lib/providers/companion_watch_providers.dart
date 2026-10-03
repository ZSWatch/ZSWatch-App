import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/app_database.dart';
import '../services/background/companion_prototype_client.dart';
import '../services/background/companion_watch_catalogue.dart';
export '../services/background/companion_watch_catalogue.dart'
    show isCompanionWatchAddress;
import 'companion_runtime_providers.dart';
import 'watch_providers.dart';

/// Rename only the selected metadata column, preserving IDs, connection
/// history, primary selection, receipts and all processing state. No BLE call.
final companionRenameWatchProvider =
    Provider<Future<void> Function(String, String?)>((ref) {
      if (!ref.watch(nativeCompanionRuntimeProvider)) {
        throw StateError('Native companion is not selected');
      }
      final db = ref.watch(databaseProvider);
      return (id, name) async {
        final trimmed = name?.trim();
        final changed =
            await (db.update(
              db.watches,
            )..where((row) => row.id.equals(id))).write(
              WatchesCompanion(
                customName: Value(
                  trimmed == null || trimmed.isEmpty ? null : trimmed,
                ),
              ),
            );
        if (changed != 1) throw StateError('Saved watch no longer exists');
      };
    });

final companionWatchCatalogueWriterProvider =
    Provider<Future<void> Function(CompanionWatchMetadata)>((ref) {
      if (!ref.watch(nativeCompanionRuntimeProvider)) {
        throw StateError('Native companion is not selected');
      }
      return CompanionWatchCatalogue(ref.watch(databaseProvider)).save;
    });

/// One serial writer; repeated snapshots coalesce, failed writes remain retryable.
class CompanionWatchPersistence extends StateNotifier<AsyncValue<void>> {
  final Future<void> Function(CompanionWatchMetadata) write;
  CompanionWatchPersistence(this.write) : super(const AsyncValue.data(null));
  CompanionWatchMetadata? _pending;
  String? _committed;
  bool _writing = false;
  bool _disposed = false;

  void observe(CompanionPrototypeSnapshot snapshot) {
    final metadata = CompanionWatchMetadata.fromSnapshot(snapshot);
    if (_disposed || metadata == null || metadata.fingerprint == _committed) {
      return;
    }
    _pending = metadata;
    if (!_writing) unawaited(_drain());
  }

  Future<void> _drain() async {
    _writing = true;
    try {
      while (!_disposed && _pending != null) {
        final metadata = _pending!;
        _pending = null;
        if (metadata.fingerprint == _committed) continue;
        state = const AsyncValue.loading();
        try {
          await write(metadata);
          _committed = metadata.fingerprint;
          if (!_disposed) state = const AsyncValue.data(null);
        } catch (error, stack) {
          if (!_disposed) state = AsyncValue.error(error, stack);
        }
      }
    } finally {
      _writing = false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _pending = null;
    super.dispose();
  }
}

final companionWatchPersistenceStateProvider =
    StateNotifierProvider<CompanionWatchPersistence, AsyncValue<void>>(
      (ref) => CompanionWatchPersistence(
        // Lazy DB access: an old journal without a Ready receipt performs no write.
        (metadata) => ref.read(companionWatchCatalogueWriterProvider)(metadata),
      ),
    );

/// App-lifetime projection, independent of which Flutter screen is visible.
/// Disposal cancels observation; native BLE and its durable journal continue.
final companionWatchPersistenceProvider = Provider<void>((ref) {
  if (!ref.watch(nativeCompanionRuntimeProvider)) return;
  final writer = ref.watch(companionWatchPersistenceStateProvider.notifier);
  ref.listen(companionSnapshotProvider, (previous, next) {
    final snapshot = next.asData?.value;
    if (snapshot != null) writer.observe(snapshot);
  }, fireImmediately: true);
});
