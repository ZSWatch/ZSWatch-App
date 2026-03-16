import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/filesystem_image.dart';
import '../services/dfu/filesystem_upload_service.dart';

/// Provider for the filesystem upload service singleton
final filesystemUploadServiceProvider = Provider<FilesystemUploadService>((ref) {
  final service = FilesystemUploadService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Stream provider for filesystem upload state
final filesystemUploadStateStreamProvider = StreamProvider<FilesystemUploadState>((ref) {
  final service = ref.watch(filesystemUploadServiceProvider);
  return service.stateStream;
});

/// Provider for current filesystem upload state
final filesystemUploadStateProvider = Provider<FilesystemUploadState>((ref) {
  final asyncValue = ref.watch(filesystemUploadStateStreamProvider);
  return asyncValue.valueOrNull ?? const FilesystemUploadState();
});

/// Provider for filesystem upload status
final filesystemUploadStatusProvider = Provider<FilesystemUploadStatus>((ref) {
  return ref.watch(filesystemUploadStateProvider).status;
});

/// Provider for whether filesystem upload is in progress
final isFilesystemUploadInProgressProvider = Provider<bool>((ref) {
  return ref.watch(filesystemUploadStatusProvider).isInProgress;
});

/// Provider for filesystem upload logs
final filesystemUploadLogsProvider = StreamProvider<String>((ref) {
  final service = ref.watch(filesystemUploadServiceProvider);
  return service.logStream;
});

