import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database/app_database.dart';
import '../services/background/companion_prototype_client.dart';
import '../services/background/companion_watch_catalogue.dart';
export '../services/background/companion_watch_catalogue.dart'
    show isCompanionWatchAddress;
import 'companion_runtime_providers.dart';
import 'demo_mode_provider.dart';
import 'watch_providers.dart';

/// Rename only the selected metadata column, preserving IDs, connection
/// history, primary selection, receipts and all processing state. No BLE call.
final companionRenameWatchProvider =
    Provider<Future<void> Function(String, String?)>((ref) {
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

/// Native forget fences the selection before its local row/history are removed.
/// System Bluetooth pairing is managed separately by the user.
final companionForgetWatchProvider = Provider<Future<void> Function(String)>((
  ref,
) {
  final db = ref.watch(databaseProvider);
  final client = ref.watch(companionClientProvider);
  return (id) async {
    if (!isCompanionWatchAddress(id)) {
      throw const FormatException('Expected a native watch identifier');
    }
    await ref
        .read(companionWatchPersistenceStateProvider.notifier)
        .forget(
          id,
          forgetNative: () async {
            final snapshot = await client.forgetWatch(id);
            return (snapshot.fields['forget_receipt'] as Map)['generation']
                as int;
          },
          // Drift keys preserve their original spelling, including legacy lowercase IDs.
          delete: () => db.deleteWatch(id),
        );
  };
});

final companionWatchCatalogueWriterProvider =
    Provider<Future<void> Function(CompanionWatchMetadata)>((ref) {
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
  final _forgetting = <String>{};
  final _forgotten = <String, int>{};
  Completer<void>? _drained;
  int _cursor = -1;

  void observe(CompanionPrototypeSnapshot snapshot) {
    if (_disposed || snapshot.cursor < _cursor) return;
    _cursor = snapshot.cursor;
    final tombstones = snapshot.fields['forgotten_watches'];
    if (tombstones is Map) {
      for (final entry in tombstones.entries) {
        if (entry.key is String && entry.value is int) {
          final address = (entry.key as String).toUpperCase();
          final generation = entry.value as int;
          if (generation > (_forgotten[address] ?? -1)) {
            _forgotten[address] = generation;
          }
        }
      }
    }
    final metadata = CompanionWatchMetadata.fromSnapshot(snapshot);
    if (metadata == null ||
        _blocked(metadata) ||
        metadata.fingerprint == _committed) {
      return;
    }
    _pending = metadata;
    if (!_writing) unawaited(_drain());
  }

  Future<void> _drain() async {
    _writing = true;
    final drained = _drained = Completer<void>();
    try {
      while (!_disposed && _pending != null) {
        final metadata = _pending!;
        _pending = null;
        if (_blocked(metadata) || metadata.fingerprint == _committed) continue;
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
      drained.complete();
    }
  }

  bool _blocked(CompanionWatchMetadata metadata) =>
      _forgetting.contains(metadata.address) ||
      metadata.generation <= (_forgotten[metadata.address] ?? -1);

  /// Discard queued saves and await any in-flight save before deleting. Native
  /// tombstones also fence old Ready snapshots after UI reattachment.
  Future<void> forget(
    String id, {
    required Future<int> Function() forgetNative,
    required Future<void> Function() delete,
  }) async {
    final address = id.toUpperCase();
    if (_disposed || !_forgetting.add(address)) {
      throw StateError('Watch Forget is already in progress or disposed');
    }
    if (_pending?.address == address) _pending = null;
    try {
      final generation = await forgetNative();
      if (generation > (_forgotten[address] ?? -1)) {
        _forgotten[address] = generation;
      }
      if (_writing) await _drained!.future;
      await delete();
    } finally {
      _forgetting.remove(address);
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
  if (ref.watch(demoModeProvider)) {
    return;
  }
  final writer = ref.watch(companionWatchPersistenceStateProvider.notifier);
  ref.listen(companionSnapshotProvider, (previous, next) {
    final snapshot = next.asData?.value;
    if (snapshot != null) writer.observe(snapshot);
  }, fireImmediately: true);
});
