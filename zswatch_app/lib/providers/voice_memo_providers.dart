import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../data/repositories/voice_memo_repository.dart';
import '../services/voice_memo/transcription_engine.dart';
import '../services/voice_memo/voice_memo_recovery_service.dart';

import 'settings_providers.dart';
import 'watch_providers.dart';

// ==================== Repository Provider ====================

/// Provider for the voice memo repository singleton
final voiceMemoRepositoryProvider = Provider<VoiceMemoRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return VoiceMemoRepository(db);
});

/// A shared startup pass, also awaited before sync or displaying voice memos.
final voiceMemoRecoveryProvider = FutureProvider<VoiceMemoRecoveryReport>((
  ref,
) async {
  final report = await VoiceMemoRecoveryService(
    repository: ref.watch(voiceMemoRepositoryProvider),
    documentsDirectory: getApplicationDocumentsDirectory,
  ).recover();
  debugPrint(
    '[VoiceMemoRecovery] receipts=${report.recoveredReceipts} '
    'stages=${report.recoveredStages} conversions=${report.rebuiltConversions} '
    'missing=${report.missingRecordings} retained=${report.retainedFiles.length}',
  );
  for (final error in report.errors) {
    debugPrint('[VoiceMemoRecovery] $error');
  }
  return report;
});

// ==================== Transcription Engine Provider ====================

/// Provider for the transcription engine singleton.
/// Recreated automatically when the user changes the engine type in settings.
final transcriptionEngineProvider = Provider<TranscriptionEngine>((ref) {
  final engineType = ref.watch(transcriptionEngineTypeProvider);
  final engine = createTranscriptionEngine(engineType);
  ref.onDispose(() => engine.dispose());
  return engine;
});

/// Stream of transcription engine state
final transcriptionEngineStateProvider =
    StreamProvider<TranscriptionEngineState>((ref) {
      final engine = ref.watch(transcriptionEngineProvider);
      return engine.stateStream;
    });

class TranscriptionModelLocalStatus {
  final bool downloaded;
  final int? localSizeBytes;
  final String localPath;

  const TranscriptionModelLocalStatus({
    required this.downloaded,
    required this.localSizeBytes,
    required this.localPath,
  });
}

final transcriptionModelStatusProvider =
    FutureProvider.family<
      TranscriptionModelLocalStatus,
      TranscriptionEngineType
    >((ref, type) async {
      final engine = createTranscriptionEngine(type);
      try {
        final localPath = await engine.modelFilePath();
        final file = File(localPath);
        final downloaded = file.existsSync();

        return TranscriptionModelLocalStatus(
          downloaded: downloaded,
          localSizeBytes: downloaded ? file.lengthSync() : null,
          localPath: localPath,
        );
      } finally {
        engine.dispose();
      }
    });

final transcriptionConfiguredProvider = FutureProvider<bool>((ref) async {
  final selected = ref.watch(transcriptionEngineTypeProvider);
  final status = await ref.watch(
    transcriptionModelStatusProvider(selected).future,
  );
  return status.downloaded;
});
