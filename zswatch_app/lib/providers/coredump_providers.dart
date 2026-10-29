import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database/app_database.dart';
import '../data/repositories/crash_report_repository.dart';
import '../services/coredump/coredump_service.dart';
import 'watch_providers.dart';
import 'watch_service_provider.dart';
import 'companion_runtime_providers.dart';

/// Query the existing watch shell only when the Crash Reports view is opened or
/// refreshed. Dashboard observation never opens an additional SMP operation.
final nativeCoredumpInspectionProvider = FutureProvider.autoDispose<void>((
  ref,
) async {
  final client = ref.read(companionClientProvider);
  final snapshot = await client.snapshot();
  if (!snapshot.protocolReady) {
    throw StateError('Connect the watch to inspect crashes');
  }
  await client.inspectCoredump(snapshot.generation);
});

final coredumpServiceProvider = Provider<CoredumpService>((ref) {
  final service = CoredumpService.native(() async {
    final client = ref.read(companionClientProvider);
    final snapshot = await client.snapshot();
    if (!snapshot.protocolReady) {
      throw StateError('Connect the watch first');
    }
    return client.downloadCoredump(snapshot.generation);
  });
  ref.onDispose(() => service.dispose());
  return service;
});

final coredumpDownloadStateProvider = StreamProvider<CoredumpDownloadState>((
  ref,
) {
  return ref.watch(coredumpServiceProvider).stateStream;
});

/// Provider for the crash report repository.
final crashReportRepositoryProvider = Provider<CrashReportRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return CrashReportRepository(db);
});

/// Stream of all crash reports (history), newest first.
final crashReportHistoryProvider = StreamProvider<List<CrashReportEntity>>((
  ref,
) {
  final repo = ref.watch(crashReportRepositoryProvider);
  return repo.watchAllCrashReports(limit: 50);
});

/// Crash file frequency stats.
final crashFileStatsProvider = FutureProvider<List<CrashFileStats>>((ref) {
  final repo = ref.watch(crashReportRepositoryProvider);
  return repo.getCrashFileStats();
});

/// Provider that auto-persists crash summaries to DB.
/// Must be watched from a top-level widget to stay active.
final crashReportPersistenceProvider = Provider<void>((ref) {
  final repo = ref.watch(crashReportRepositoryProvider);
  final coredumpService = ref.watch(coredumpServiceProvider);

  // Persist crash summaries when received from watch
  String? lastCrashKey;
  ref.listen(crashSummaryStreamProvider, (previous, next) async {
    final summary = next.valueOrNull;
    if (summary == null) return;

    // Forget the previous download when a new (different) crash arrives
    final crashKey = '${summary.file}:${summary.line}:${summary.time}';
    if (lastCrashKey != null && crashKey != lastCrashKey) {
      coredumpService.reset();
    }
    lastCrashKey = crashKey;

    final watchId = ref.read(currentWatchProvider)?.id;
    if (watchId == null) return;

    await repo.saveCrashSummary(watchId: watchId, summary: summary);
    ref.invalidate(crashFileStatsProvider);
  }, fireImmediately: true);
});
