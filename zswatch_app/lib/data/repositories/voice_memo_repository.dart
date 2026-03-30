// ignore_for_file: avoid_slow_async_io
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../database/app_database.dart';
import '../models/voice_memo.dart';
import 'base_repository.dart';

/// Repository for voice memo data operations
///
/// Provides a clean interface for CRUD operations on voice memos,
/// abstracting the database layer from the rest of the app.
class VoiceMemoRepository extends BaseRepository<VoiceMemo, VoiceMemoEntity> {
  final AppDatabase _db;

  VoiceMemoRepository(this._db);

  // ==================== Read Operations ====================

  /// Get all voice memos, newest first
  Future<List<VoiceMemo>> getAllMemos() async {
    final entities = await _db.getAllVoiceMemos();
    return entities.map(_entityToModel).toList();
  }

  /// Watch all voice memos (reactive stream), newest first
  Stream<List<VoiceMemo>> watchAllMemos() {
    return _db.watchAllVoiceMemos().map(
      (entities) => entities.map(_entityToModel).toList(),
    );
  }

  /// Get a voice memo by filename
  Future<VoiceMemo?> getMemoByFilename(String filename) async {
    final entity = await _db.getVoiceMemoByFilename(filename);
    return entity != null ? _entityToModel(entity) : null;
  }

  /// Get memos that haven't been downloaded yet
  Future<List<VoiceMemo>> getUndownloadedMemos() async {
    final entities = await _db.getUndownloadedVoiceMemos();
    return entities.map(_entityToModel).toList();
  }

  /// Get memos that are synced but not yet transcribed
  Future<List<VoiceMemo>> getUntranscribedMemos() async {
    final entities = await _db.getUntranscribedVoiceMemos();
    return entities.map(_entityToModel).toList();
  }

  /// Get memos that have a local audio file and can be transcribed.
  Future<List<VoiceMemo>> getTranscribableMemos() async {
    final allMemos = await getAllMemos();
    return allMemos
        .where(
          (memo) =>
              memo.convertedFilePath != null || memo.localFilePath != null,
        )
        .toList();
  }

  // ==================== Write Operations ====================

  /// Insert or update a voice memo from watch metadata
  Future<void> upsertFromWatch({
    required String filename,
    required int timestampUtc,
    required int durationMs,
    required int sizeBytes,
  }) async {
    await _db.upsertVoiceMemo(
      VoiceMemosCompanion(
        filename: Value(filename),
        timestampUtc: Value(timestampUtc),
        durationMs: Value(durationMs),
        sizeBytes: Value(sizeBytes),
      ),
    );
  }

  /// Mark a memo as downloaded
  Future<void> markDownloaded({
    required String filename,
    required String localFilePath,
  }) async {
    await _db.updateVoiceMemoDownloaded(
      filename: filename,
      localFilePath: localFilePath,
    );
  }

  /// Mark a memo as deleted on the watch
  Future<void> markDeletedOnWatch(String filename) async {
    await _db.updateVoiceMemoDeletedOnWatch(filename);
  }

  /// Update transcription result
  Future<void> updateTranscription({
    required String filename,
    required String transcription,
  }) async {
    await _db.updateVoiceMemoTranscription(
      filename: filename,
      transcription: transcription,
    );
  }

  /// Update converted file path
  Future<void> updateConvertedPath({
    required String filename,
    required String convertedFilePath,
  }) async {
    await _db.updateVoiceMemoConvertedPath(
      filename: filename,
      convertedFilePath: convertedFilePath,
    );
  }

  /// Update AI processing results
  Future<void> updateAiResults({
    required String filename,
    required String summary,
    required String category,
    required String aiModel,
  }) async {
    await _db.updateVoiceMemoAiResults(
      filename: filename,
      summary: summary,
      category: category,
      aiModel: aiModel,
    );
  }

  /// Clear AI results (undo) — resets summary, category, and processing status
  /// while keeping raw audio and transcription intact.
  Future<void> clearAiResults(String filename) async {
    final memo = await _db.getVoiceMemoByFilename(filename);
    if (memo != null) {
      await _db.deleteActionsForMemo(memo.id);
    }

    await _db.updateVoiceMemoAiResults(
      filename: filename,
      summary: '',
      category: '',
      aiModel: '',
    );
    await _db.updateVoiceMemoProcessingStatus(
      filename: filename,
      status: 'transcribed',
    );
  }

  /// Update AI processing status
  Future<void> updateProcessingStatus({
    required String filename,
    required String status,
  }) async {
    await _db.updateVoiceMemoProcessingStatus(
      filename: filename,
      status: status,
    );
  }

  /// Reset memos stuck in intermediate processing states back to 'failed'.
  Future<int> resetStuckProcessingMemos() => _db.resetStuckProcessingMemos();

  /// Get memos that are transcribed but not yet AI-processed
  Future<List<VoiceMemo>> getUnprocessedMemos() async {
    final entities = await _db.getUnprocessedVoiceMemos();
    return entities.map(_entityToModel).toList();
  }

  /// Toggle the archived state of a voice memo
  Future<void> setArchived({
    required String filename,
    required bool archived,
  }) async {
    await _db.updateVoiceMemoArchived(filename: filename, archived: archived);
  }

  /// Delete a voice memo by filename (deletes local files and DB entry)
  Future<void> deleteMemo(String filename) async {
    // Get the memo first so we can clean up local files
    final entity = await _db.getVoiceMemoByFilename(filename);
    if (entity != null) {
      // Delete local .zsw_opus file
      if (entity.localFilePath != null) {
        try {
          final file = File(entity.localFilePath!);
          if (await file.exists()) {
            await file.delete();
            debugPrint(
              '[VoiceMemoRepository] Deleted local file: ${entity.localFilePath}',
            );
          }
        } catch (e) {
          debugPrint('[VoiceMemoRepository] Failed to delete local file: $e');
        }
      }
      // Delete converted .ogg file
      if (entity.convertedFilePath != null) {
        try {
          final file = File(entity.convertedFilePath!);
          if (await file.exists()) {
            await file.delete();
            debugPrint(
              '[VoiceMemoRepository] Deleted converted file: ${entity.convertedFilePath}',
            );
          }
        } catch (e) {
          debugPrint(
            '[VoiceMemoRepository] Failed to delete converted file: $e',
          );
        }
      }
    }
    await _db.deleteVoiceMemo(filename);
  }

  // ==================== Private Helpers ====================

  @override
  VoiceMemo fromEntity(VoiceMemoEntity entity) => _entityToModel(entity);

  VoiceMemo _entityToModel(VoiceMemoEntity entity) {
    return VoiceMemo(
      id: entity.id,
      filename: entity.filename,
      timestampUtc: DateTime.fromMillisecondsSinceEpoch(
        entity.timestampUtc * 1000,
        isUtc: true,
      ),
      durationMs: entity.durationMs,
      sizeBytes: entity.sizeBytes,
      localFilePath: entity.localFilePath,
      transcription: entity.transcription,
      syncedFromWatch: entity.syncedFromWatch,
      deletedOnWatch: entity.deletedOnWatch,
      downloadedAt: entity.downloadedAt,
      transcribedAt: entity.transcribedAt,
      convertedFilePath: entity.convertedFilePath,
      summary: entity.summary,
      category: entity.category,
      processingStatus: entity.processingStatus,
      aiModel: entity.aiModel,
      aiProcessedAt: entity.aiProcessedAt,
      taskCreated: entity.taskCreated,
      calendarEventCreated: entity.calendarEventCreated,
      actionReviewState: entity.actionReviewState,
      archived: entity.archived,
    );
  }
}
