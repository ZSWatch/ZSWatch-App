import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/app_database.dart';
import '../data/repositories/crash_report_repository.dart';
import '../services/coredump/coredump_api_service.dart';
import '../services/coredump/coredump_service.dart';
import 'dfu_providers.dart';
import 'settings_providers.dart';
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

/// Provider for the backend API service.
final coredumpApiServiceProvider = Provider<CoredumpApiService>((ref) {
  final baseUrl = ref.watch(coredumpServerUrlProvider);
  return CoredumpApiService(baseUrl: baseUrl);
});

/// Provider for the coredump analysis orchestration service.
final coredumpServiceProvider = Provider<CoredumpService>((ref) {
  final apiService = ref.watch(coredumpApiServiceProvider);
  final firmwareManager = ref.watch(firmwareManagerProvider);
  final service = ref.watch(nativeCompanionRuntimeProvider)
      ? CoredumpService.native(
          () async {
            final client = ref.read(companionClientProvider);
            final snapshot = await client.snapshot();
            if (!snapshot.protocolReady) {
              throw StateError('Connect the watch first');
            }
            return client.downloadCoredump(snapshot.generation);
          },
          apiService,
          firmwareManager,
        )
      : CoredumpService(
          ref.watch(watchServiceProvider),
          apiService,
          firmwareManager,
        );
  ref.onDispose(() => service.dispose());
  return service;
});

/// Stream of coredump analysis state updates.
final coredumpAnalysisStateProvider = StreamProvider<CoredumpAnalysisState>((
  ref,
) {
  final service = ref.watch(coredumpServiceProvider);
  return service.stateStream;
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

/// Provider that auto-persists crash summaries and analysis results to DB.
/// Must be watched from a top-level widget to stay active.
final crashReportPersistenceProvider = Provider<void>((ref) {
  final repo = ref.watch(crashReportRepositoryProvider);
  final coredumpService = ref.watch(coredumpServiceProvider);

  // Persist crash summaries when received from watch
  int? lastSavedReportId;
  String? lastCrashKey;
  ref.listen(crashSummaryStreamProvider, (previous, next) async {
    final summary = next.valueOrNull;
    if (summary == null) return;

    // Reset analysis state when a new (different) crash arrives
    final crashKey = '${summary.file}:${summary.line}:${summary.time}';
    if (lastCrashKey != null && crashKey != lastCrashKey) {
      coredumpService.reset();
    }
    lastCrashKey = crashKey;

    final watchId = ref.read(currentWatchProvider)?.id;
    if (watchId == null) return;

    lastSavedReportId = await repo.saveCrashSummary(
      watchId: watchId,
      summary: summary,
    );
  }, fireImmediately: true);

  // Persist analysis results when analysis completes
  ref.listen(coredumpAnalysisStateProvider, (previous, next) async {
    final state = next.valueOrNull;
    if (state == null) return;
    if (state.phase != CoredumpAnalysisPhase.completed) return;
    if (state.result == null) return;
    if (lastSavedReportId == null) return;

    await repo.saveAnalysisResult(
      reportId: lastSavedReportId!,
      analysis: state.result!,
    );
    // Refresh stats after saving
    ref.invalidate(crashFileStatsProvider);
  });
});
