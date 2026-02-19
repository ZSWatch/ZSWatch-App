import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/llext_app.dart';
import '../services/llext_app_service.dart';
import 'filesystem_providers.dart';
import 'watch_service_provider.dart';

/// Singleton provider for the LLEXT app service.
final llextAppServiceProvider = Provider<LlextAppService>((ref) {
  final uploadService = ref.watch(filesystemUploadServiceProvider);
  final watchService = ref.watch(watchServiceProvider);
  final service = LlextAppService(uploadService, watchService);
  ref.onDispose(() => service.dispose());
  return service;
});

/// Stream provider reflecting the full list of known apps + install status.
final llextAppsStreamProvider = StreamProvider<List<LlextAppState>>((ref) {
  final service = ref.watch(llextAppServiceProvider);
  return service.appsStream;
});

/// Provider for the current snapshot of app states (sync, uses last value).
final llextAppsProvider = Provider<List<LlextAppState>>((ref) {
  return ref.watch(llextAppsStreamProvider).valueOrNull ??
      ref.read(llextAppServiceProvider).currentApps;
});

/// Convenience: installed apps only.
final installedLlextAppsProvider = Provider<List<LlextAppState>>((ref) {
  return ref.watch(llextAppsProvider).where((a) => a.isInstalled).toList();
});

/// Convenience: available-but-not-installed apps.
final availableLlextAppsProvider = Provider<List<LlextAppState>>((ref) {
  return ref.watch(llextAppsProvider).where((a) => !a.isInstalled).toList();
});

/// Log stream for the LLEXT service.
final llextLogStreamProvider = StreamProvider<String>((ref) {
  final service = ref.watch(llextAppServiceProvider);
  return service.logStream;
});
