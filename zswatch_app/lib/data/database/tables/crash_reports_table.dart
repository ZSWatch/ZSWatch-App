import 'package:drift/drift.dart';

import 'watches_table.dart';

/// Crash reports table - persists crash summaries and analysis results
///
/// Each row represents one crash event received from the watch.
/// Analysis results (backtrace, registers) are stored after server decode.
@DataClassName('CrashReportEntity')
class CrashReports extends Table {
  /// Auto-incrementing row identifier
  IntColumn get id => integer().autoIncrement()();

  /// Foreign key to source watch
  TextColumn get watchId =>
      text().references(Watches, #id).named('watch_id')();

  /// Source file that crashed
  TextColumn get file => text()();

  /// Line number of the crash
  IntColumn get line => integer()();

  /// Crash timestamp as reported by the watch
  TextColumn get crashTime => text().named('crash_time')();

  /// Firmware version at time of crash
  TextColumn get fwVersion => text().named('fw_version')();

  /// Firmware commit SHA at time of crash
  TextColumn get fwCommitSha => text().named('fw_commit_sha')();

  /// Board identifier
  TextColumn get board => text()();

  /// Build type (debug/release)
  TextColumn get buildType => text().named('build_type')();

  /// When this crash was first received by the app
  DateTimeColumn get receivedAt => dateTime().named('received_at')();

  /// Whether analysis has been performed
  BoolColumn get analyzed =>
      boolean().withDefault(const Constant(false))();

  /// Decoded backtrace from server (null if not analyzed)
  TextColumn get backtrace => text().nullable()();

  /// Decoded registers from server (null if not analyzed)
  TextColumn get registers => text().nullable()();

  /// Raw GDB output from server (null if not analyzed)
  TextColumn get rawOutput => text().nullable().named('raw_output')();

  /// Error message if analysis failed
  TextColumn get analysisError =>
      text().nullable().named('analysis_error')();

  /// Whether ELF was available for analysis
  BoolColumn get elfAvailable =>
      boolean().withDefault(const Constant(false)).named('elf_available')();
}
