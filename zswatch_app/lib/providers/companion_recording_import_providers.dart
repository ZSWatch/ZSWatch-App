import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../data/database/companion_recording_database.dart';
import '../data/models/companion_recording.dart';
import '../services/voice_memo/companion_recording_importer.dart';
import 'companion_runtime_providers.dart';

final companionRecordingSupportProvider = Provider<Future<Directory>>(
  (ref) => getApplicationSupportDirectory(),
);

final companionRecordingDatabaseProvider = Provider<CompanionRecordingDatabase>(
  (ref) {
    if (!ref.watch(nativeCompanionRuntimeProvider)) {
      throw StateError('Native companion is not selected');
    }
    final db = CompanionRecordingDatabase.open(
      ref.watch(companionRecordingSupportProvider),
    );
    ref.onDispose(db.close);
    return db;
  },
);

final companionRecordingImportsProvider =
    StreamProvider<List<ImportedRecording>>(
      (ref) => ref.watch(companionRecordingDatabaseProvider).watchImports(),
    );

final companionPreparePlaybackProvider =
    Provider<Future<ImportedRecording> Function(CompanionRecording)>((ref) {
      if (!ref.watch(nativeCompanionRuntimeProvider)) {
        throw StateError('Native companion is not selected');
      }
      return CompanionRecordingImporter(
        database: ref.watch(companionRecordingDatabaseProvider),
        supportDirectory: () => ref.read(companionRecordingSupportProvider),
      ).prepare;
    });
