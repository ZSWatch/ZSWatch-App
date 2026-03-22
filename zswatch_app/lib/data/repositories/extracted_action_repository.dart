import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../database/app_database.dart';
import '../models/extracted_action.dart';
import 'base_repository.dart';

/// Repository for AI-extracted action operations
class ExtractedActionRepository
    extends BaseRepository<ExtractedAction, ExtractedActionEntity> {
  final AppDatabase _db;

  ExtractedActionRepository(this._db);

  // ==================== Read Operations ====================

  /// Get all extracted actions for a voice memo
  Future<List<ExtractedAction>> getActionsForMemo(int memoId) async {
    final entities = await _db.getActionsForMemo(memoId);
    return entities.map(_entityToModel).toList();
  }

  /// Watch extracted actions for a voice memo (reactive stream)
  Stream<List<ExtractedAction>> watchActionsForMemo(int memoId) {
    return _db
        .watchActionsForMemo(memoId)
        .map((entities) => entities.map(_entityToModel).toList());
  }

  /// Get all pending (not created, not dismissed) actions
  Future<List<ExtractedAction>> getPendingActions() async {
    final entities = await _db.getPendingActions();
    return entities.map(_entityToModel).toList();
  }

  // ==================== Write Operations ====================

  /// Insert an extracted action
  Future<int> insertAction({
    required int memoId,
    required ExtractedActionType actionType,
    required String title,
    String? notes,
    DateTime? startTime,
    DateTime? endTime,
    DateTime? dueDate,
    String? location,
    int? reminderMinutes,
  }) async {
    final id = await _db.insertExtractedAction(
      ExtractedActionsCompanion(
        memoId: Value(memoId),
        actionType: Value(ExtractedAction.typeToString(actionType)),
        title: Value(title),
        notes: Value(notes),
        startTime: Value(startTime),
        endTime: Value(endTime),
        dueDate: Value(dueDate),
        location: Value(location),
        reminderMinutes: Value(reminderMinutes),
      ),
    );
    debugPrint(
      '[ExtractedActionRepository] Inserted action $id for memo $memoId',
    );
    return id;
  }

  /// Mark an action as created in the OS
  Future<void> markCreated({
    required int actionId,
    String? platformTargetId,
  }) async {
    await _db.markExtractedActionCreated(
      actionId: actionId,
      platformTargetId: platformTargetId,
    );
  }

  /// Dismiss an action suggestion
  Future<void> dismiss(int actionId) async {
    await _db.dismissExtractedAction(actionId);
  }

  /// Delete all actions for a memo
  Future<void> deleteActionsForMemo(int memoId) async {
    await _db.deleteActionsForMemo(memoId);
  }

  // ==================== Private Helpers ====================

  @override
  ExtractedAction fromEntity(ExtractedActionEntity entity) =>
      _entityToModel(entity);

  ExtractedAction _entityToModel(ExtractedActionEntity entity) {
    return ExtractedAction(
      id: entity.id,
      memoId: entity.memoId,
      actionType: ExtractedAction.typeFromString(entity.actionType),
      title: entity.title,
      notes: entity.notes,
      startTime: entity.startTime,
      endTime: entity.endTime,
      dueDate: entity.dueDate,
      location: entity.location,
      reminderMinutes: entity.reminderMinutes,
      created: entity.created,
      dismissed: entity.dismissed,
      platformTargetId: entity.platformTargetId,
      createdAt: entity.createdAt,
    );
  }
}
