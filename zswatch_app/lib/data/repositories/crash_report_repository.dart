import 'package:flutter/foundation.dart';

import '../database/app_database.dart';
import '../models/coredump_analysis.dart';
import '../models/crash_summary.dart';

/// Repository for persisting and querying crash reports.
class CrashReportRepository {
  final AppDatabase _db;

  CrashReportRepository(this._db);

  /// Persist a crash summary received from the watch.
  /// Returns the report ID, or null if it was a duplicate.
  Future<int?> saveCrashSummary({
    required String watchId,
    required CrashSummary summary,
  }) async {
    // Dedup: don't store the same crash twice
    final existing = await _db.findExistingCrashReport(
      watchId: watchId,
      file: summary.file,
      line: summary.line,
      crashTime: summary.time,
    );
    if (existing != null) {
      debugPrint(
        '[CrashReportRepo] Duplicate crash, skipping: ${summary.file}:${summary.line}',
      );
      return existing.id;
    }

    final id = await _db.insertCrashReport(
      CrashReportsCompanion.insert(
        watchId: watchId,
        file: summary.file,
        line: summary.line,
        crashTime: summary.time,
        fwVersion: summary.fwVersion,
        fwCommitSha: summary.fwCommitSha,
        board: summary.board,
        buildType: summary.buildType,
        receivedAt: DateTime.now(),
      ),
    );
    debugPrint(
      '[CrashReportRepo] Saved crash report #$id: ${summary.file}:${summary.line}',
    );
    return id;
  }

  /// Update a crash report with analysis results.
  Future<void> saveAnalysisResult({
    required int reportId,
    required CoredumpAnalysis analysis,
  }) async {
    await _db.updateCrashReportAnalysis(
      reportId: reportId,
      success: analysis.success,
      backtrace: analysis.backtrace,
      registers: analysis.registers,
      rawOutput: analysis.rawOutput,
      error: analysis.error,
      elfAvailable: analysis.elfAvailable,
    );
  }

  /// Get crash reports for a watch.
  Future<List<CrashReportEntity>> getCrashReports({
    required String watchId,
    int limit = 50,
  }) {
    return _db.getCrashReports(watchId: watchId, limit: limit);
  }

  /// Watch crash reports for a watch (reactive stream).
  Stream<List<CrashReportEntity>> watchCrashReports({
    required String watchId,
    int limit = 50,
  }) {
    return _db.watchCrashReports(watchId: watchId, limit: limit);
  }

  /// Watch all crash reports across all watches.
  Stream<List<CrashReportEntity>> watchAllCrashReports({int limit = 50}) {
    return _db.watchAllCrashReports(limit: limit);
  }

  /// Get crash frequency stats per file.
  Future<List<CrashFileStats>> getCrashFileStats({String? watchId}) {
    return _db.getCrashFileStats(watchId: watchId);
  }

  /// Delete all crash reports.
  Future<int> deleteAll() {
    return _db.deleteAllCrashReports();
  }

  /// Clean up old crash reports.
  Future<void> cleanup({int keep = 100}) {
    return _db.deleteOldCrashReports(keep: keep);
  }
}
