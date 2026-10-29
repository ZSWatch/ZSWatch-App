import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/filesystem_image.dart';
import 'companion_runtime_providers.dart';
import 'transfer_progress_providers.dart';

/// Provider for current filesystem upload state
final filesystemUploadStateProvider = Provider<FilesystemUploadState>((ref) {
  final snapshot = ref.watch(companionSnapshotProvider).valueOrNull;
  final status = ref.watch(companionWatchfaceStatusProvider).valueOrNull;
  final rate = ref.watch(
    nativeTransferRateProvider(NativeImageTransfer.watchface),
  );
  if (status == null || status.address != snapshot?.fields['address']) {
    return const FilesystemUploadState();
  }
  return FilesystemUploadState(
    status: status.busy
        ? FilesystemUploadStatus.uploading
        : status.phase == 'completed'
        ? FilesystemUploadStatus.completed
        : FilesystemUploadStatus.failed,
    progress: status.progress,
    bytesTransferred: status.current,
    totalBytes: status.total,
    speedBytesPerSecond: rate.bytesPerSecond,
    speedHistory: rate.history,
    imageName: status.name,
    errorMessage: status.error,
  );
});

/// Provider for filesystem upload status
final filesystemUploadStatusProvider = Provider<FilesystemUploadStatus>((ref) {
  return ref.watch(filesystemUploadStateProvider).status;
});

/// Provider for whether filesystem upload is in progress
final isFilesystemUploadInProgressProvider = Provider<bool>((ref) {
  return ref.watch(filesystemUploadStatusProvider).isInProgress;
});
