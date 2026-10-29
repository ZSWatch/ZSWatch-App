import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../data/database/companion_recording_database.dart';
import '../data/models/companion_recording.dart';
import '../services/voice_memo/companion_recording_importer.dart';
import '../services/voice_memo/companion_recording_exporter.dart';
import 'companion_runtime_providers.dart';
import 'demo_mode_provider.dart';

final companionRecordingExporterProvider = Provider<CompanionRecordingExporter>(
  (ref) => const CompanionRecordingExporter(
    temporaryDirectory: getTemporaryDirectory,
  ),
);

/// Search returns identities, keeping private text out of the event stream.
final companionRecordingSearchProvider = FutureProvider.autoDispose
    .family<Set<String>, String>((ref, query) {
      ref.watch(
        companionSnapshotProvider.select((value) {
          final state = value.asData?.value;
          // Refresh search after durable recording/job changes.
          return state?.cursor;
        }),
      );
      return ref.watch(companionClientProvider).searchRecordings(query);
    });

final companionRecordingSupportProvider = Provider<Future<Directory>>(
  (ref) => getApplicationSupportDirectory(),
);

final companionRecordingDatabaseProvider = Provider<CompanionRecordingDatabase>(
  (ref) {
    final db = CompanionRecordingDatabase.open(
      ref.watch(companionRecordingSupportProvider),
    );
    ref.onDispose(db.close);
    return db;
  },
);

final companionRecordingImportsProvider =
    StreamProvider<List<ImportedRecording>>(
      (ref) => ref.watch(demoModeProvider)
          ? Stream.value([])
          : ref.watch(companionRecordingDatabaseProvider).watchImports(),
    );

final companionPreparePlaybackProvider =
    Provider<Future<ImportedRecording> Function(CompanionRecording)>((ref) {
      return CompanionRecordingImporter(
        database: ref.watch(companionRecordingDatabaseProvider),
        supportDirectory: () => ref.read(companionRecordingSupportProvider),
      ).prepare;
    });
