import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/app_database.dart';
import 'companion_runtime_providers.dart';
import 'watch_providers.dart';

bool isCompanionWatchAddress(String id) =>
    RegExp(r'^[0-9A-Fa-f]{2}(:[0-9A-Fa-f]{2}){5}$').hasMatch(id);

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
