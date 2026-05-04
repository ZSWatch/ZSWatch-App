import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/battery_readings_table.dart';
import 'tables/chat_history_table.dart';
import 'tables/comm_log_entries_table.dart';
import 'tables/connection_events_table.dart';
import 'tables/crash_reports_table.dart';
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
  tables: [
    Watches,
    HealthSamples,
    BatteryReadings,
    CommLogEntries,
    ConnectionEvents,
    VoiceMemos,
    ExtractedActions,
    CrashReports,
    ChatHistory,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Database schema version
  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) => m.createAll(),
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          // v1 → v2: added ConnectionEvents, VoiceMemos, ExtractedActions tables.
          await m.createTable(connectionEvents);
          await m.createTable(voiceMemos);
          await m.createTable(extractedActions);
        }
        if (from < 3) {
          // v2 → v3: added CrashReports table.
          await m.createTable(crashReports);
        }
        if (from >= 2 && from < 4) {
          // v3 → v4: added duration_seconds column to extracted_actions.
          // Guard: only run when the table already existed (v2+). Fresh v1→v4
          // upgrades create the table with this column via createTable above.
          await m.addColumn(extractedActions, extractedActions.durationSeconds);
        }
        if (from >= 2 && from < 5) {
          // v4 → v5: added archived column to voice_memos.
          // Guard: only run when the table already existed (v2+).
          await m.addColumn(voiceMemos, voiceMemos.archived);
        }
        if (from < 6) {
          // v5 → v6: added ChatHistory table for voice chat feature.
          await m.createTable(chatHistory);
        }
      },
      beforeOpen: (details) async {
        // Reset memos stuck in intermediate processing states from a crash.
        await resetStuckProcessingMemos();
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
    return (select(
      watches,
    )..where((w) => w.isPrimary.equals(true))).getSingleOrNull();
  }

  /// Insert or update a watch
  Future<void> upsertWatch(WatchesCompanion watch) {
    return into(watches).insertOnConflictUpdate(watch);
  }

  /// Set a watch as primary (clears other primary flags)
  Future<void> setWatchAsPrimary(String watchId) async {
    await transaction(() async {
      // Clear all primary flags
      await (update(watches)..where((w) => w.isPrimary.equals(true))).write(
        const WatchesCompanion(isPrimary: Value(false)),
      );
      // Set the specified watch as primary
      await (update(watches)..where((w) => w.id.equals(watchId))).write(
        const WatchesCompanion(isPrimary: Value(true)),
      );
    });
  }

  /// Delete a watch and all its associated data
  Future<void> deleteWatch(String watchId) async {
    await transaction(() async {
      await (delete(
        healthSamples,
      )..where((h) => h.watchId.equals(watchId))).go();
      await (delete(
        batteryReadings,
      )..where((b) => b.watchId.equals(watchId))).go();
      await (delete(
        connectionEvents,
      )..where((c) => c.watchId.equals(watchId))).go();
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
          ..where(
            (h) =>
                h.watchId.equals(watchId) &
                h.type.equals(type) &
                h.timestamp.isBetweenValues(from, to),
          )
          ..orderBy([(h) => OrderingTerm.asc(h.timestamp)]))
        .get();
  }

  /// Delete health samples older than specified date
  Future<int> deleteOldHealthSamples(DateTime cutoff) {
    return (delete(
      healthSamples,
    )..where((h) => h.timestamp.isSmallerThanValue(cutoff))).go();
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
          ..where(
            (b) =>
                b.watchId.equals(watchId) &
                b.timestamp.isBetweenValues(from, to),
          )
          ..orderBy([(b) => OrderingTerm.asc(b.timestamp)]))
        .get();
  }

  /// Delete battery readings older than specified date
  Future<int> deleteOldBatteryReadings(DateTime cutoff) {
    return (delete(
      batteryReadings,
    )..where((b) => b.timestamp.isSmallerThanValue(cutoff))).go();
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
          ..where(
            (e) =>
                e.watchId.equals(watchId) &
                e.timestamp.isBetweenValues(from, to),
          )
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
          ..where(
            (e) =>
                e.watchId.equals(watchId) & e.eventType.equals('disconnected'),
          )
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
      ..where(
        connectionEvents.watchId.equals(watchId) &
            connectionEvents.eventType.equals(eventType) &
            connectionEvents.timestamp.isBetweenValues(from, to),
      );
    final result = await query.getSingle();
    return result.read(connectionEvents.id.count()) ?? 0;
  }

  /// Get the last connection event for a watch strictly before [before]
  Future<ConnectionEventEntity?> getLastConnectionEventBefore({
    required String watchId,
    required DateTime before,
  }) {
    return (select(connectionEvents)
          ..where(
            (e) =>
                e.watchId.equals(watchId) &
                e.timestamp.isSmallerThanValue(before),
          )
          ..orderBy([(e) => OrderingTerm.desc(e.timestamp)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Delete connection events older than specified date
  Future<int> deleteOldConnectionEvents(DateTime cutoff) {
    return (delete(
      connectionEvents,
    )..where((e) => e.timestamp.isSmallerThanValue(cutoff))).go();
  }

  /// Delete all connection events for a specific watch
  Future<int> deleteAllConnectionEventsForWatch(String watchId) {
    return (delete(
      connectionEvents,
    )..where((e) => e.watchId.equals(watchId))).go();
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
    return (select(
      voiceMemos,
    )..orderBy([(v) => OrderingTerm.desc(v.timestampUtc)])).get();
  }

  /// Watch all voice memos (reactive stream), newest first
  Stream<List<VoiceMemoEntity>> watchAllVoiceMemos() {
    return (select(
      voiceMemos,
    )..orderBy([(v) => OrderingTerm.desc(v.timestampUtc)])).watch();
  }

  /// Get voice memo by filename
  Future<VoiceMemoEntity?> getVoiceMemoByFilename(String filename) async {
    final rows = await (select(
      voiceMemos,
    )..where((v) => v.filename.equals(filename))).get();
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
          ..where(
            (v) => v.syncedFromWatch.equals(true) & v.transcription.isNull(),
          )
          ..orderBy([(v) => OrderingTerm.asc(v.timestampUtc)]))
        .get();
  }

  /// Get voice memos that are transcribed but not yet AI-processed
  Future<List<VoiceMemoEntity>> getUnprocessedVoiceMemos() {
    return (select(voiceMemos)
          ..where(
            (v) =>
                v.transcription.isNotNull() &
                v.summary.isNull() &
                (v.processingStatus.isNull() |
                    v.processingStatus.equals('failed')),
          )
          ..orderBy([(v) => OrderingTerm.asc(v.timestampUtc)]))
        .get();
  }

  /// Insert or update a voice memo (upsert by filename)
  Future<void> upsertVoiceMemo(VoiceMemosCompanion memo) async {
    // getVoiceMemoByFilename also deduplicates if stale duplicates exist.
    final existing = await getVoiceMemoByFilename(memo.filename.value);
    if (existing != null) {
      await (update(
        voiceMemos,
      )..where((v) => v.filename.equals(memo.filename.value))).write(memo);
    } else {
      await into(voiceMemos).insert(memo);
    }
  }

  /// Mark a voice memo as downloaded
  Future<void> updateVoiceMemoDownloaded({
    required String filename,
    required String localFilePath,
  }) {
    return (update(
      voiceMemos,
    )..where((v) => v.filename.equals(filename))).write(
      VoiceMemosCompanion(
        syncedFromWatch: const Value(true),
        localFilePath: Value(localFilePath),
        downloadedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Mark a voice memo as deleted on the watch
  Future<void> updateVoiceMemoDeletedOnWatch(String filename) {
    return (update(voiceMemos)..where((v) => v.filename.equals(filename)))
        .write(const VoiceMemosCompanion(deletedOnWatch: Value(true)));
  }

  /// Update transcription for a voice memo
  Future<void> updateVoiceMemoTranscription({
    required String filename,
    required String transcription,
  }) {
    return (update(
      voiceMemos,
    )..where((v) => v.filename.equals(filename))).write(
      VoiceMemosCompanion(
        transcription: Value(transcription),
        transcribedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Update converted file path for a voice memo
  Future<void> updateVoiceMemoConvertedPath({
    required String filename,
    required String convertedFilePath,
  }) {
    return (update(
      voiceMemos,
    )..where((v) => v.filename.equals(filename))).write(
      VoiceMemosCompanion(convertedFilePath: Value(convertedFilePath)),
    );
  }

  /// Update AI processing results for a voice memo
  Future<void> updateVoiceMemoAiResults({
    required String filename,
    required String summary,
    required String category,
    required String aiModel,
  }) {
    return (update(
      voiceMemos,
    )..where((v) => v.filename.equals(filename))).write(
      VoiceMemosCompanion(
        summary: Value(summary),
        category: Value(category),
        processingStatus: const Value('ready'),
        aiModel: Value(aiModel),
        aiProcessedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Update AI processing status
  Future<void> updateVoiceMemoProcessingStatus({
    required String filename,
    required String status,
  }) {
    return (update(voiceMemos)..where((v) => v.filename.equals(filename)))
        .write(VoiceMemosCompanion(processingStatus: Value(status)));
  }

  /// Reset any memos stuck in intermediate processing states back to 'failed'
  /// so they can be retried. This handles crash recovery on app startup.
  Future<int> resetStuckProcessingMemos() {
    return (update(voiceMemos)..where(
          (v) =>
              v.summary.isNull() &
              (v.processingStatus.equals('queued') |
                  v.processingStatus.equals('summarizing') |
                  v.processingStatus.equals('categorizing') |
                  v.processingStatus.equals('extractingActions')),
        ))
        .write(const VoiceMemosCompanion(processingStatus: Value('failed')));
  }

  /// Mark task created for a voice memo
  Future<void> updateVoiceMemoTaskCreated(String filename) {
    return (update(voiceMemos)..where((v) => v.filename.equals(filename)))
        .write(const VoiceMemosCompanion(taskCreated: Value(true)));
  }

  /// Mark calendar event created for a voice memo
  Future<void> updateVoiceMemoCalendarEventCreated(String filename) {
    return (update(voiceMemos)..where((v) => v.filename.equals(filename)))
        .write(const VoiceMemosCompanion(calendarEventCreated: Value(true)));
  }

  /// Set the archived flag for a voice memo
  Future<void> updateVoiceMemoArchived({
    required String filename,
    required bool archived,
  }) {
    return (update(voiceMemos)..where((v) => v.filename.equals(filename)))
        .write(VoiceMemosCompanion(archived: Value(archived)));
  }

  /// Delete a voice memo by filename
  Future<int> deleteVoiceMemo(String filename) {
    return (delete(voiceMemos)..where((v) => v.filename.equals(filename))).go();
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
    return (update(
      extractedActions,
    )..where((a) => a.id.equals(actionId))).write(
      ExtractedActionsCompanion(
        created: const Value(true),
        platformTargetId: Value(platformTargetId),
        createdAt: Value(DateTime.now()),
      ),
    );
  }

  /// Dismiss an extracted action
  Future<void> dismissExtractedAction(int actionId) {
    return (update(extractedActions)..where((a) => a.id.equals(actionId)))
        .write(const ExtractedActionsCompanion(dismissed: Value(true)));
  }

  /// Delete all extracted actions for a memo
  Future<int> deleteActionsForMemo(int memoId) {
    return (delete(
      extractedActions,
    )..where((a) => a.memoId.equals(memoId))).go();
  }

  /// Get all pending (not created, not dismissed) extracted actions
  Future<List<ExtractedActionEntity>> getPendingActions() {
    return (select(
      extractedActions,
    )..where((a) => a.created.equals(false) & a.dismissed.equals(false))).get();
  }

  /// Delete a single extracted action by id
  Future<int> deleteExtractedAction(int actionId) {
    return (delete(extractedActions)..where((a) => a.id.equals(actionId))).go();
  }

  /// Watch all alarm and timer extracted actions (reactive stream)
  Stream<List<ExtractedActionEntity>> watchAlarmTimerActions() {
    return (select(extractedActions)
          ..where(
            (a) => a.actionType.equals('alarm') | a.actionType.equals('timer'),
          )
          ..orderBy([
            (a) => OrderingTerm.asc(a.created),
            (a) => OrderingTerm.desc(a.id),
          ]))
        .watch();
  }

  /// Watch all extracted actions (for building memo→actionTypes map)
  Stream<List<ExtractedActionEntity>> watchAllExtractedActions() {
    return (select(
      extractedActions,
    )..orderBy([(a) => OrderingTerm.desc(a.id)])).watch();
  }

  // ==================== Crash Report Operations ====================

  /// Insert a crash report
  Future<int> insertCrashReport(CrashReportsCompanion report) {
    return into(crashReports).insert(report);
  }

  /// Get all crash reports for a watch, newest first
  Future<List<CrashReportEntity>> getCrashReports({
    required String watchId,
    int limit = 50,
  }) {
    return (select(crashReports)
          ..where((c) => c.watchId.equals(watchId))
          ..orderBy([(c) => OrderingTerm.desc(c.receivedAt)])
          ..limit(limit))
        .get();
  }

  /// Watch crash reports for a watch (reactive stream), newest first
  Stream<List<CrashReportEntity>> watchCrashReports({
    required String watchId,
    int limit = 50,
  }) {
    return (select(crashReports)
          ..where((c) => c.watchId.equals(watchId))
          ..orderBy([(c) => OrderingTerm.desc(c.receivedAt)])
          ..limit(limit))
        .watch();
  }

  /// Get all crash reports across all watches, newest first
  Stream<List<CrashReportEntity>> watchAllCrashReports({int limit = 50}) {
    return (select(crashReports)
          ..orderBy([(c) => OrderingTerm.desc(c.receivedAt)])
          ..limit(limit))
        .watch();
  }

  /// Update a crash report with analysis results
  Future<void> updateCrashReportAnalysis({
    required int reportId,
    required bool success,
    String? backtrace,
    String? registers,
    String? rawOutput,
    String? error,
    bool elfAvailable = false,
  }) {
    return (update(crashReports)..where((c) => c.id.equals(reportId))).write(
      CrashReportsCompanion(
        analyzed: const Value(true),
        backtrace: Value(backtrace),
        registers: Value(registers),
        rawOutput: Value(rawOutput),
        analysisError: Value(error),
        elfAvailable: Value(elfAvailable),
      ),
    );
  }

  /// Check if a crash report already exists (dedup by file+line+crashTime+watchId)
  Future<CrashReportEntity?> findExistingCrashReport({
    required String watchId,
    required String file,
    required int line,
    required String crashTime,
  }) {
    return (select(crashReports)
          ..where(
            (c) =>
                c.watchId.equals(watchId) &
                c.file.equals(file) &
                c.line.equals(line) &
                c.crashTime.equals(crashTime),
          )
          ..limit(1))
        .getSingleOrNull();
  }

  /// Get crash count per file (top crashers)
  Future<List<CrashFileStats>> getCrashFileStats({String? watchId}) async {
    final query = customSelect(
      'SELECT file, COUNT(*) as crash_count, MAX(received_at) as last_crash '
      'FROM crash_reports '
      '${watchId != null ? "WHERE watch_id = ?" : ""} '
      'GROUP BY file ORDER BY crash_count DESC LIMIT 10',
      variables: [if (watchId != null) Variable.withString(watchId)],
      readsFrom: {crashReports},
    );
    final rows = await query.get();
    return rows
        .map(
          (row) => CrashFileStats(
            file: row.read<String>('file'),
            count: row.read<int>('crash_count'),
            lastCrash: row.read<DateTime>('last_crash'),
          ),
        )
        .toList();
  }

  /// Delete all crash reports.
  Future<int> deleteAllCrashReports() {
    return delete(crashReports).go();
  }

  /// Delete old crash reports (keep last N)
  Future<void> deleteOldCrashReports({int keep = 100}) async {
    await customStatement(
      'DELETE FROM crash_reports WHERE id NOT IN '
      '(SELECT id FROM crash_reports ORDER BY received_at DESC LIMIT ?)',
      [keep],
    );
  }

  // ==================== Data Retention ====================

  /// Clean up old data (60-day retention)
  Future<void> cleanupOldData() async {
    final cutoff = DateTime.now().subtract(const Duration(days: 60));
    await deleteOldHealthSamples(cutoff);
    await deleteOldBatteryReadings(cutoff);
    await deleteOldConnectionEvents(cutoff);
  }

  // ==================== Chat History Operations ====================

  /// Insert a new chat history entry.
  Future<int> insertChatHistoryEntry(ChatHistoryCompanion entry) {
    return into(chatHistory).insert(entry);
  }

  /// Get all chat history entries, newest first.
  Future<List<ChatHistoryEntity>> getAllChatHistory() {
    return (select(chatHistory)
          ..orderBy([(t) => OrderingTerm.desc(t.timestampUtc)]))
        .get();
  }

  /// Get the N most recent chat history entries.
  Future<List<ChatHistoryEntity>> getRecentChatHistory(int limit) {
    return (select(chatHistory)
          ..orderBy([(t) => OrderingTerm.desc(t.timestampUtc)])
          ..limit(limit))
        .get();
  }

  /// Watch all chat history entries (stream), newest first.
  Stream<List<ChatHistoryEntity>> watchAllChatHistory() {
    return (select(chatHistory)
          ..orderBy([(t) => OrderingTerm.desc(t.timestampUtc)]))
        .watch();
  }

  /// Delete a chat history entry by ID.
  Future<int> deleteChatHistoryEntry(int id) {
    return (delete(chatHistory)..where((t) => t.id.equals(id))).go();
  }

  /// Delete all chat history entries.
  Future<int> deleteAllChatHistory() {
    return delete(chatHistory).go();
  }

  /// Delete chat history older than [cutoff].
  Future<int> deleteOldChatHistory(DateTime cutoff) {
    final cutoffEpoch = cutoff.toUtc().millisecondsSinceEpoch ~/ 1000;
    return (delete(chatHistory)
          ..where((t) => t.timestampUtc.isSmallerThanValue(cutoffEpoch)))
        .go();
  }
}

/// Stats for crash frequency per file
class CrashFileStats {
  final String file;
  final int count;
  final DateTime lastCrash;

  const CrashFileStats({
    required this.file,
    required this.count,
    required this.lastCrash,
  });
}

/// Opens the database connection
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'zswatch_app.db'));
    return NativeDatabase.createInBackground(file);
  });
}
