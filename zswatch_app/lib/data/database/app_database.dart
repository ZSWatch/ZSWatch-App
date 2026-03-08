import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/battery_readings_table.dart';
import 'tables/comm_log_entries_table.dart';
import 'tables/connection_events_table.dart';
import 'tables/extracted_actions_table.dart';
import 'tables/health_samples_table.dart';
import 'tables/voice_memos_table.dart';
import 'tables/watches_table.dart';

part 'app_database.g.dart';

/// Main application database using drift (SQLite)
///
/// Manages all persistent data:
/// - Watches: Paired ZSWatch devices
/// - HealthSamples: Steps, heart rate, and other health metrics
/// - BatteryReadings: Battery level history for analytics
/// - CommLogEntries: BLE communication logs for debugging
/// - ConnectionEvents: Connection/disconnection events for analytics
@DriftDatabase(
  tables: [Watches, HealthSamples, BatteryReadings, CommLogEntries, ConnectionEvents, VoiceMemos, ExtractedActions],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Database schema version - increment when making schema changes
  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Handle migrations here when schema changes
        if (from < 2) {
          // Add custom_name column for watch rename feature (FR-099 to FR-102)
          await m.addColumn(watches, watches.customName);
        }
        if (from < 3) {
          // Add connection events table for analytics (US9)
          await m.createTable(connectionEvents);
        }
        if (from < 4) {
          // Add voice memos table for voice recording sync
          await m.createTable(voiceMemos);
        }
        if (from < 5) {
          // Add AI-enhanced voice notes fields and extracted actions table
          await m.createTable(extractedActions);
          await m.addColumn(voiceMemos, voiceMemos.summary);
          await m.addColumn(voiceMemos, voiceMemos.category);
          await m.addColumn(voiceMemos, voiceMemos.processingStatus);
          await m.addColumn(voiceMemos, voiceMemos.aiModel);
          await m.addColumn(voiceMemos, voiceMemos.aiProcessedAt);
          await m.addColumn(voiceMemos, voiceMemos.taskCreated);
          await m.addColumn(voiceMemos, voiceMemos.calendarEventCreated);
          await m.addColumn(voiceMemos, voiceMemos.actionReviewState);
        }
      },
    );
  }

  // ==================== Watch Operations ====================

  /// Get all saved watches
  Future<List<WatchEntity>> getAllWatches() => select(watches).get();

  /// Watch all saved watches (stream)
  Stream<List<WatchEntity>> watchAllWatches() => select(watches).watch();

  /// Get watch by ID
  Future<WatchEntity?> getWatchById(String id) {
    return (select(watches)..where((w) => w.id.equals(id))).getSingleOrNull();
  }

  /// Get the primary watch
  Future<WatchEntity?> getPrimaryWatch() {
    return (select(watches)..where((w) => w.isPrimary.equals(true)))
        .getSingleOrNull();
  }

  /// Insert or update a watch
  Future<void> upsertWatch(WatchesCompanion watch) {
    return into(watches).insertOnConflictUpdate(watch);
  }

  /// Set a watch as primary (clears other primary flags)
  Future<void> setWatchAsPrimary(String watchId) async {
    await transaction(() async {
      // Clear all primary flags
      await (update(watches)..where((w) => w.isPrimary.equals(true)))
          .write(const WatchesCompanion(isPrimary: Value(false)));
      // Set the specified watch as primary
      await (update(watches)..where((w) => w.id.equals(watchId)))
          .write(const WatchesCompanion(isPrimary: Value(true)));
    });
  }

  /// Delete a watch and all its associated data
  Future<void> deleteWatch(String watchId) async {
    await transaction(() async {
      await (delete(healthSamples)..where((h) => h.watchId.equals(watchId)))
          .go();
      await (delete(batteryReadings)..where((b) => b.watchId.equals(watchId)))
          .go();
      await (delete(connectionEvents)
            ..where((c) => c.watchId.equals(watchId)))
          .go();
      await (delete(watches)..where((w) => w.id.equals(watchId))).go();
    });
  }

  /// Update watch connection timestamp
  Future<void> updateWatchLastConnected(String watchId) {
    return (update(watches)..where((w) => w.id.equals(watchId))).write(
      WatchesCompanion(lastConnectedAt: Value(DateTime.now())),
    );
  }

  /// Update watch battery level
  Future<void> updateWatchBattery(String watchId, int level) {
    return (update(watches)..where((w) => w.id.equals(watchId))).write(
      WatchesCompanion(batteryLevel: Value(level)),
    );
  }

  // ==================== Health Sample Operations ====================

  /// Insert a health sample
  Future<int> insertHealthSample(HealthSamplesCompanion sample) {
    return into(healthSamples).insert(sample);
  }

  /// Insert multiple health samples
  Future<void> insertHealthSamples(List<HealthSamplesCompanion> samples) {
    return batch((b) => b.insertAll(healthSamples, samples));
  }

  /// Get health samples for a watch within date range
  Future<List<HealthSampleEntity>> getHealthSamples({
    required String watchId,
    required String type,
    required DateTime from,
    required DateTime to,
  }) {
    return (select(healthSamples)
          ..where((h) =>
              h.watchId.equals(watchId) &
              h.type.equals(type) &
              h.timestamp.isBetweenValues(from, to))
          ..orderBy([(h) => OrderingTerm.asc(h.timestamp)]))
        .get();
  }

  /// Delete health samples older than specified date
  Future<int> deleteOldHealthSamples(DateTime cutoff) {
    return (delete(healthSamples)..where((h) => h.timestamp.isSmallerThanValue(cutoff)))
        .go();
  }

  // ==================== Battery Reading Operations ====================

  /// Insert a battery reading
  Future<int> insertBatteryReading(BatteryReadingsCompanion reading) {
    return into(batteryReadings).insert(reading);
  }

  /// Get battery readings for a watch within date range
  Future<List<BatteryReadingEntity>> getBatteryReadings({
    required String watchId,
    required DateTime from,
    required DateTime to,
  }) {
    return (select(batteryReadings)
          ..where((b) =>
              b.watchId.equals(watchId) &
              b.timestamp.isBetweenValues(from, to))
          ..orderBy([(b) => OrderingTerm.asc(b.timestamp)]))
        .get();
  }

  /// Delete battery readings older than specified date
  Future<int> deleteOldBatteryReadings(DateTime cutoff) {
    return (delete(batteryReadings)
          ..where((b) => b.timestamp.isSmallerThanValue(cutoff)))
        .go();
  }

  // ==================== Comm Log Operations ====================

  /// Insert a comm log entry
  Future<int> insertCommLogEntry(CommLogEntriesCompanion entry) {
    return into(commLogEntries).insert(entry);
  }

  /// Get recent comm log entries
  Future<List<CommLogEntryEntity>> getRecentCommLogs({int limit = 100}) {
    return (select(commLogEntries)
          ..orderBy([(c) => OrderingTerm.desc(c.timestamp)])
          ..limit(limit))
        .get();
  }

  /// Watch comm log entries (stream)
  Stream<List<CommLogEntryEntity>> watchCommLogs({int limit = 100}) {
    return (select(commLogEntries)
          ..orderBy([(c) => OrderingTerm.desc(c.timestamp)])
          ..limit(limit))
        .watch();
  }

  /// Get comm log entry count
  Future<int> getCommLogCount() async {
    final query = selectOnly(commLogEntries)
      ..addColumns([commLogEntries.id.count()]);
    final result = await query.getSingle();
    return result.read(commLogEntries.id.count()) ?? 0;
  }

  /// Rotate comm logs (keep most recent entries, delete oldest)
  Future<void> rotateCommLogs({int maxEntries = 5000}) async {
    final count = await getCommLogCount();
    if (count > maxEntries) {
      final deleteCount = count - maxEntries;
      await customStatement(
        'DELETE FROM comm_log_entries WHERE id IN '
        '(SELECT id FROM comm_log_entries ORDER BY timestamp ASC LIMIT ?)',
        [deleteCount],
      );
    }
  }

  /// Clear all comm logs
  Future<int> clearCommLogs() => delete(commLogEntries).go();

  // ==================== Connection Events Operations ====================

  /// Insert a connection event
  Future<int> insertConnectionEvent(ConnectionEventsCompanion event) {
    return into(connectionEvents).insert(event);
  }

  /// Get connection events for a watch within date range
  Future<List<ConnectionEventEntity>> getConnectionEvents({
    required String watchId,
    required DateTime from,
    required DateTime to,
  }) {
    return (select(connectionEvents)
          ..where((e) =>
              e.watchId.equals(watchId) &
              e.timestamp.isBetweenValues(from, to))
          ..orderBy([(e) => OrderingTerm.asc(e.timestamp)]))
        .get();
  }

  /// Get all connection events within date range (all watches)
  Future<List<ConnectionEventEntity>> getAllConnectionEvents({
    required DateTime from,
    required DateTime to,
  }) {
    return (select(connectionEvents)
          ..where((e) => e.timestamp.isBetweenValues(from, to))
          ..orderBy([(e) => OrderingTerm.asc(e.timestamp)]))
        .get();
  }

  /// Get recent disconnection events for a watch
  Future<List<ConnectionEventEntity>> getRecentDisconnections({
    required String watchId,
    int limit = 20,
  }) {
    return (select(connectionEvents)
          ..where((e) =>
              e.watchId.equals(watchId) &
              e.eventType.equals('disconnected'))
          ..orderBy([(e) => OrderingTerm.desc(e.timestamp)])
          ..limit(limit))
        .get();
  }

  /// Get connection events count by type for a watch within date range
  Future<int> getConnectionEventCount({
    required String watchId,
    required String eventType,
    required DateTime from,
    required DateTime to,
  }) async {
    final query = selectOnly(connectionEvents)
      ..addColumns([connectionEvents.id.count()])
      ..where(connectionEvents.watchId.equals(watchId) &
          connectionEvents.eventType.equals(eventType) &
          connectionEvents.timestamp.isBetweenValues(from, to));
    final result = await query.getSingle();
    return result.read(connectionEvents.id.count()) ?? 0;
  }

  /// Delete connection events older than specified date
  Future<int> deleteOldConnectionEvents(DateTime cutoff) {
    return (delete(connectionEvents)
          ..where((e) => e.timestamp.isSmallerThanValue(cutoff)))
        .go();
  }

  /// Watch connection events (stream)
  Stream<List<ConnectionEventEntity>> watchConnectionEvents({
    required String watchId,
    int limit = 100,
  }) {
    return (select(connectionEvents)
          ..where((e) => e.watchId.equals(watchId))
          ..orderBy([(e) => OrderingTerm.desc(e.timestamp)])
          ..limit(limit))
        .watch();
  }

  // ==================== Voice Memo Operations ====================

  /// Get all voice memos, newest first
  Future<List<VoiceMemoEntity>> getAllVoiceMemos() {
    return (select(voiceMemos)
          ..orderBy([(v) => OrderingTerm.desc(v.timestampUtc)]))
        .get();
  }

  /// Watch all voice memos (reactive stream), newest first
  Stream<List<VoiceMemoEntity>> watchAllVoiceMemos() {
    return (select(voiceMemos)
          ..orderBy([(v) => OrderingTerm.desc(v.timestampUtc)]))
        .watch();
  }

  /// Get voice memo by filename
  Future<VoiceMemoEntity?> getVoiceMemoByFilename(String filename) async {
    final rows = await (select(voiceMemos)
          ..where((v) => v.filename.equals(filename)))
        .get();
    if (rows.length > 1) {
      // Clean up stale duplicates (can occur from race conditions on double
      // BLE notification delivery). Keep the first row, delete the rest.
      for (final extra in rows.skip(1)) {
        await (delete(voiceMemos)..where((v) => v.id.equals(extra.id))).go();
      }
    }
    return rows.isEmpty ? null : rows.first;
  }

  /// Get voice memos not yet downloaded
  Future<List<VoiceMemoEntity>> getUndownloadedVoiceMemos() {
    return (select(voiceMemos)
          ..where((v) => v.syncedFromWatch.equals(false))
          ..orderBy([(v) => OrderingTerm.asc(v.timestampUtc)]))
        .get();
  }

  /// Get voice memos that are synced but not yet transcribed
  Future<List<VoiceMemoEntity>> getUntranscribedVoiceMemos() {
    return (select(voiceMemos)
          ..where((v) =>
              v.syncedFromWatch.equals(true) & v.transcription.isNull())
          ..orderBy([(v) => OrderingTerm.asc(v.timestampUtc)]))
        .get();
  }

  /// Get voice memos that are transcribed but not yet AI-processed
  Future<List<VoiceMemoEntity>> getUnprocessedVoiceMemos() {
    return (select(voiceMemos)
          ..where((v) =>
              v.transcription.isNotNull() &
              v.summary.isNull() &
              (v.processingStatus.isNull() |
                  v.processingStatus.equals('failed')))
          ..orderBy([(v) => OrderingTerm.asc(v.timestampUtc)]))
        .get();
  }

  /// Insert or update a voice memo (upsert by filename)
  Future<void> upsertVoiceMemo(VoiceMemosCompanion memo) async {
    // getVoiceMemoByFilename also deduplicates if stale duplicates exist.
    final existing = await getVoiceMemoByFilename(memo.filename.value);
    if (existing != null) {
      await (update(voiceMemos)
            ..where((v) => v.filename.equals(memo.filename.value)))
          .write(memo);
    } else {
      await into(voiceMemos).insert(memo);
    }
  }

  /// Mark a voice memo as downloaded
  Future<void> updateVoiceMemoDownloaded({
    required String filename,
    required String localFilePath,
  }) {
    return (update(voiceMemos)..where((v) => v.filename.equals(filename)))
        .write(VoiceMemosCompanion(
      syncedFromWatch: const Value(true),
      localFilePath: Value(localFilePath),
      downloadedAt: Value(DateTime.now()),
    ));
  }

  /// Mark a voice memo as deleted on the watch
  Future<void> updateVoiceMemoDeletedOnWatch(String filename) {
    return (update(voiceMemos)..where((v) => v.filename.equals(filename)))
        .write(const VoiceMemosCompanion(
      deletedOnWatch: Value(true),
    ));
  }

  /// Update transcription for a voice memo
  Future<void> updateVoiceMemoTranscription({
    required String filename,
    required String transcription,
  }) {
    return (update(voiceMemos)..where((v) => v.filename.equals(filename)))
        .write(VoiceMemosCompanion(
      transcription: Value(transcription),
      transcribedAt: Value(DateTime.now()),
    ));
  }

  /// Update converted file path for a voice memo
  Future<void> updateVoiceMemoConvertedPath({
    required String filename,
    required String convertedFilePath,
  }) {
    return (update(voiceMemos)..where((v) => v.filename.equals(filename)))
        .write(VoiceMemosCompanion(
      convertedFilePath: Value(convertedFilePath),
    ));
  }

  /// Update AI processing results for a voice memo
  Future<void> updateVoiceMemoAiResults({
    required String filename,
    required String summary,
    required String category,
    required String aiModel,
  }) {
    return (update(voiceMemos)..where((v) => v.filename.equals(filename)))
        .write(VoiceMemosCompanion(
      summary: Value(summary),
      category: Value(category),
      processingStatus: const Value('ready'),
      aiModel: Value(aiModel),
      aiProcessedAt: Value(DateTime.now()),
    ));
  }

  /// Update AI processing status
  Future<void> updateVoiceMemoProcessingStatus({
    required String filename,
    required String status,
  }) {
    return (update(voiceMemos)..where((v) => v.filename.equals(filename)))
        .write(VoiceMemosCompanion(
      processingStatus: Value(status),
    ));
  }

  /// Mark task created for a voice memo
  Future<void> updateVoiceMemoTaskCreated(String filename) {
    return (update(voiceMemos)..where((v) => v.filename.equals(filename)))
        .write(const VoiceMemosCompanion(
      taskCreated: Value(true),
    ));
  }

  /// Mark calendar event created for a voice memo
  Future<void> updateVoiceMemoCalendarEventCreated(String filename) {
    return (update(voiceMemos)..where((v) => v.filename.equals(filename)))
        .write(const VoiceMemosCompanion(
      calendarEventCreated: Value(true),
    ));
  }

  /// Delete a voice memo by filename
  Future<int> deleteVoiceMemo(String filename) {
    return (delete(voiceMemos)..where((v) => v.filename.equals(filename)))
        .go();
  }

  // ==================== Extracted Action Operations ====================

  /// Get all extracted actions for a voice memo
  Future<List<ExtractedActionEntity>> getActionsForMemo(int memoId) {
    return (select(extractedActions)
          ..where((a) => a.memoId.equals(memoId))
          ..orderBy([(a) => OrderingTerm.asc(a.id)]))
        .get();
  }

  /// Watch extracted actions for a voice memo (reactive stream)
  Stream<List<ExtractedActionEntity>> watchActionsForMemo(int memoId) {
    return (select(extractedActions)
          ..where((a) => a.memoId.equals(memoId))
          ..orderBy([(a) => OrderingTerm.asc(a.id)]))
        .watch();
  }

  /// Insert an extracted action
  Future<int> insertExtractedAction(ExtractedActionsCompanion action) {
    return into(extractedActions).insert(action);
  }

  /// Update an extracted action as created
  Future<void> markExtractedActionCreated({
    required int actionId,
    String? platformTargetId,
  }) {
    return (update(extractedActions)..where((a) => a.id.equals(actionId)))
        .write(ExtractedActionsCompanion(
      created: const Value(true),
      platformTargetId: Value(platformTargetId),
      createdAt: Value(DateTime.now()),
    ));
  }

  /// Dismiss an extracted action
  Future<void> dismissExtractedAction(int actionId) {
    return (update(extractedActions)..where((a) => a.id.equals(actionId)))
        .write(const ExtractedActionsCompanion(
      dismissed: Value(true),
    ));
  }

  /// Delete all extracted actions for a memo
  Future<int> deleteActionsForMemo(int memoId) {
    return (delete(extractedActions)..where((a) => a.memoId.equals(memoId)))
        .go();
  }

  /// Get all pending (not created, not dismissed) extracted actions
  Future<List<ExtractedActionEntity>> getPendingActions() {
    return (select(extractedActions)
          ..where(
              (a) => a.created.equals(false) & a.dismissed.equals(false)))
        .get();
  }

  // ==================== Data Retention ====================

  /// Clean up old data (60-day retention)
  Future<void> cleanupOldData() async {
    final cutoff = DateTime.now().subtract(const Duration(days: 60));
    await deleteOldHealthSamples(cutoff);
    await deleteOldBatteryReadings(cutoff);
    await deleteOldConnectionEvents(cutoff);
  }
}

/// Opens the database connection
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'zswatch_app.db'));
    return NativeDatabase.createInBackground(file);
  });
}

