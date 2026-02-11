import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mcumgr_flutter/mcumgr_flutter.dart';
import 'package:rxdart/rxdart.dart';

import '../data/models/dfu_state.dart';
import '../data/models/filesystem_image.dart';
import '../data/models/firmware_image.dart';
import '../services/dfu/dfu_service.dart';
import '../services/dfu/firmware_manager.dart';
import 'filesystem_providers.dart';
import 'watch_service_provider.dart';

/// Provider for the DFU service singleton
final dfuServiceProvider = Provider<DfuService>((ref) {
  final service = DfuService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider for the firmware manager singleton
final firmwareManagerProvider = Provider<FirmwareManager>((ref) {
  final manager = FirmwareManager();
  ref.onDispose(() => manager.dispose());
  return manager;
});

/// Stream provider for DFU state
final dfuStateStreamProvider = StreamProvider<DfuState>((ref) {
  final service = ref.watch(dfuServiceProvider);
  return service.stateStream;
});

/// Provider for current DFU state
final dfuStateProvider = Provider<DfuState>((ref) {
  final asyncValue = ref.watch(dfuStateStreamProvider);
  return asyncValue.valueOrNull ?? DfuState.idle;
});

/// Provider for DFU status
final dfuStatusProvider = Provider<DfuStatus>((ref) {
  return ref.watch(dfuStateProvider).status;
});

/// Provider for whether DFU is in progress
final isDfuInProgressProvider = Provider<bool>((ref) {
  return ref.watch(dfuStatusProvider).isInProgress;
});

/// Provider for whether DFU is in a critical phase
final isDfuCriticalProvider = Provider<bool>((ref) {
  return ref.watch(dfuStatusProvider).isCritical;
});

/// Stream provider for download progress
final downloadProgressStreamProvider = StreamProvider<DownloadProgress>((ref) {
  final manager = ref.watch(firmwareManagerProvider);
  return manager.downloadProgressStream;
});

/// Provider for current download progress
final downloadProgressProvider = Provider<DownloadProgress>((ref) {
  final asyncValue = ref.watch(downloadProgressStreamProvider);
  return asyncValue.valueOrNull ?? const DownloadProgress(0, 0, DownloadStatus.idle);
});

/// Provider for whether download is in progress
final isDownloadInProgressProvider = Provider<bool>((ref) {
  return ref.watch(downloadProgressProvider).status.isInProgress;
});

/// State notifier for GitHub releases (manual fetch to avoid rate limiting)
class ReleasesNotifier extends StateNotifier<AsyncValue<List<GitHubRelease>>> {
  final FirmwareManager _manager;

  ReleasesNotifier(this._manager) : super(const AsyncValue.data([]));

  Future<void> fetch() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _manager.fetchReleases());
  }
}

/// Provider for available GitHub releases (manual fetch)
final releasesProvider =
    StateNotifierProvider<ReleasesNotifier, AsyncValue<List<GitHubRelease>>>(
        (ref) {
  final manager = ref.watch(firmwareManagerProvider);
  return ReleasesNotifier(manager);
});

/// State notifier for workflow runs (manual fetch to avoid rate limiting)
class WorkflowRunsNotifier extends StateNotifier<AsyncValue<List<WorkflowRun>>> {
  final FirmwareManager _manager;

  WorkflowRunsNotifier(this._manager) : super(const AsyncValue.data([]));

  Future<void> fetch() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _manager.fetchWorkflowRuns());
  }
}

/// Provider for GitHub Actions workflow runs (manual fetch)
final workflowRunsProvider =
    StateNotifierProvider<WorkflowRunsNotifier, AsyncValue<List<WorkflowRun>>>(
        (ref) {
  final manager = ref.watch(firmwareManagerProvider);
  return WorkflowRunsNotifier(manager);
});

/// State notifier for DFU operations
class DfuNotifier extends StateNotifier<DfuOperationState> {
  final DfuService _dfuService;
  final FirmwareManager _firmwareManager;
  final Ref _ref;

  DfuNotifier(this._dfuService, this._firmwareManager, this._ref)
      : super(const DfuOperationState());

  /// Download firmware from a GitHub release asset
  Future<void> downloadReleaseAsset(GitHubRelease release, ReleaseAsset asset) async {
    state = state.copyWith(
      selectedRelease: release,
      isDownloading: true,
      error: null,
    );

    try {
      final result = await _firmwareManager.downloadReleaseAsset(release, asset);
      state = state.copyWith(
        downloadedImage: result.firmwareImage,
        filesystemImage: result.filesystemImage,
        isDownloading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isDownloading: false,
        error: e.toString(),
      );
    }
  }

  /// Download firmware from a GitHub Actions artifact
  Future<void> downloadArtifact(WorkflowRun run, WorkflowArtifact artifact) async {
    print('[DfuNotifier] downloadArtifact called');
    print('[DfuNotifier] Run: ${run.id}, Branch: ${run.branch}, SHA: ${run.shortSha}');
    print('[DfuNotifier] Artifact: ${artifact.name}, ID: ${artifact.id}, Size: ${artifact.sizeInBytes}');
    
    state = state.copyWith(
      selectedWorkflowRun: run,
      selectedArtifact: artifact,
      isDownloading: true,
      error: null,
    );

    try {
      final image = await _firmwareManager.downloadArtifact(run, artifact);
      state = state.copyWith(
        downloadedImage: image,
        isDownloading: false,
      );
    } catch (e) {
      print('[DfuNotifier] downloadArtifact error: $e');
      state = state.copyWith(
        isDownloading: false,
        error: e.toString(),
      );
    }
  }

  /// Get browser URL for artifact download (for manual download fallback)
  String getArtifactBrowserUrl(WorkflowRun run, WorkflowArtifact artifact) {
    return _firmwareManager.getArtifactBrowserUrl(run, artifact);
  }

  /// Load a local firmware file
  Future<void> loadLocalFile(String filePath) async {
    state = state.copyWith(
      isDownloading: true,
      error: null,
    );

    try {
      final image = await _firmwareManager.loadLocalFile(filePath);
      state = state.copyWith(
        downloadedImage: image,
        isDownloading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isDownloading: false,
        error: e.toString(),
      );
    }
  }

  /// Start the DFU process (firmware only)
  Future<void> startUpdate() async {
    final image = state.downloadedImage;
    if (image == null) {
      state = state.copyWith(error: 'No firmware selected');
      return;
    }

    state = state.copyWith(
      isUpdating: true,
      error: null,
    );

    try {
      // Prepare firmware (extract if needed)
      final images = await _firmwareManager.prepareFirmware(image);
      state = state.copyWith(preparedImages: images);

      // Get the connected device
      final watchService = _ref.read(watchServiceProvider);
      if (!watchService.isConnected) {
        throw Exception('Watch not connected');
      }

      // The device ID is needed to create a BluetoothDevice
      final connection = watchService.currentConnection;
      final deviceId = connection.watchId;
      if (deviceId.isEmpty) {
        throw Exception('No device ID available');
      }

      // Create a BluetoothDevice from the ID
      final bluetoothDevice = BluetoothDevice.fromId(deviceId);
      
      // Start the DFU
      await _dfuService.startUpdate(
        device: bluetoothDevice,
        firmwareImages: images,
      );

      state = state.copyWith(isUpdating: false);

    } catch (e) {
      state = state.copyWith(
        isUpdating: false,
        error: e.toString(),
      );
    }
  }

  /// Start filesystem upload only
  Future<void> startFilesystemUpload() async {
    final fsImage = state.filesystemImage;
    if (fsImage == null) {
      state = state.copyWith(error: 'No filesystem image available');
      return;
    }

    state = state.copyWith(
      isFilesystemUploading: true,
      error: null,
    );

    try {
      // Get the connected device
      final watchService = _ref.read(watchServiceProvider);
      if (!watchService.isConnected) {
        throw Exception('Watch not connected');
      }

      final connection = watchService.currentConnection;
      final deviceId = connection.watchId;
      if (deviceId.isEmpty) {
        throw Exception('No device ID available');
      }

      // Start the filesystem upload
      final fsService = _ref.read(filesystemUploadServiceProvider);
      await fsService.startUpload(
        deviceId: deviceId,
        image: fsImage,
      );

      // Wait for filesystem upload to complete before restarting
      await fsService.stateStream.firstWhere(
        (s) => s.status.isTerminal,
      );

      if (fsService.currentState.status == FilesystemUploadStatus.completed) {
        // Restart the watch so the new filesystem resources take effect
        debugPrint('[DfuNotifier] FS upload complete, restarting watch...');
        try {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          await OsManager.reset(deviceId);
          debugPrint('[DfuNotifier] Watch restart command sent');
        } catch (e) {
          debugPrint('[DfuNotifier] Failed to restart watch after FS upload: $e');
          // Don't fail the overall operation — the upload itself succeeded
        }
      }

      state = state.copyWith(isFilesystemUploading: false);

    } catch (e) {
      state = state.copyWith(
        isFilesystemUploading: false,
        error: e.toString(),
      );
    }
  }

  /// Start both filesystem upload and firmware update (filesystem first, then firmware)
  Future<void> startBothUpdates() async {
    final fsImage = state.filesystemImage;
    final fwImage = state.downloadedImage;

    if (fsImage == null && fwImage == null) {
      state = state.copyWith(error: 'No images available');
      return;
    }

    state = state.copyWith(
      isBothUpdating: true,
      currentStep: fsImage != null ? 1 : 2,
      totalSteps: fsImage != null ? 2 : 1,
      error: null,
    );

    try {
      // Get the connected device
      final watchService = _ref.read(watchServiceProvider);
      if (!watchService.isConnected) {
        throw Exception('Watch not connected');
      }

      final connection = watchService.currentConnection;
      final deviceId = connection.watchId;
      if (deviceId.isEmpty) {
        throw Exception('No device ID available');
      }

      // Step 1: Upload filesystem if available
      if (fsImage != null) {
        state = state.copyWith(currentStep: 1);
        
        final fsService = _ref.read(filesystemUploadServiceProvider);
        await fsService.startUpload(
          deviceId: deviceId,
          image: fsImage,
        );

        // Wait for filesystem upload to complete
        await fsService.stateStream.firstWhere(
          (s) => s.status.isTerminal,
        );

        final fsState = fsService.currentState;
        if (fsState.status != FilesystemUploadStatus.completed) {
          throw Exception('Filesystem upload failed: ${fsState.errorMessage}');
        }
        
        // Give BLE transport time to fully release before DFU
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }

      // Step 2: Start firmware update if available
      if (fwImage != null) {
        state = state.copyWith(currentStep: 2);
        
        // Prepare firmware (extract if needed)
        final images = await _firmwareManager.prepareFirmware(fwImage);
        state = state.copyWith(preparedImages: images);

        // Create a BluetoothDevice from the ID
        final bluetoothDevice = BluetoothDevice.fromId(deviceId);
        
        // Start the DFU
        await _dfuService.startUpdate(
          device: bluetoothDevice,
          firmwareImages: images,
        );
      }

      state = state.copyWith(isBothUpdating: false);

    } catch (e) {
      state = state.copyWith(
        isBothUpdating: false,
        error: e.toString(),
      );
    }
  }

  /// Cancel the current operation
  Future<void> cancel() async {
    if (_dfuService.isInProgress) {
      await _dfuService.cancel();
    }
    
    final fsService = _ref.read(filesystemUploadServiceProvider);
    if (fsService.isInProgress) {
      await fsService.cancel();
    }
    
    _firmwareManager.cancelDownload();
    state = state.copyWith(
      isDownloading: false,
      isUpdating: false,
      isFilesystemUploading: false,
      isBothUpdating: false,
    );
  }

  /// Reset state
  void reset() {
    _dfuService.reset();
    _ref.read(filesystemUploadServiceProvider).reset();
    _firmwareManager.resetProgress();
    state = const DfuOperationState();
  }

  /// Clean up downloaded files
  Future<void> cleanup() async {
    final images = <FirmwareImage>[];
    if (state.downloadedImage != null) {
      images.add(state.downloadedImage!);
    }
    images.addAll(state.preparedImages);
    await _firmwareManager.cleanup(images: images);
  }
}

/// Provider for DFU notifier
final dfuNotifierProvider =
    StateNotifierProvider<DfuNotifier, DfuOperationState>((ref) {
  final dfuService = ref.watch(dfuServiceProvider);
  final firmwareManager = ref.watch(firmwareManagerProvider);
  return DfuNotifier(dfuService, firmwareManager, ref);
});

/// State for DFU operations
class DfuOperationState {
  final GitHubRelease? selectedRelease;
  final WorkflowRun? selectedWorkflowRun;
  final WorkflowArtifact? selectedArtifact;
  final FirmwareImage? downloadedImage;
  final FilesystemImage? filesystemImage;
  final List<FirmwareImage> preparedImages;
  final bool isDownloading;
  final bool isUpdating;
  final bool isFilesystemUploading;
  final bool isBothUpdating;
  final int currentStep;
  final int totalSteps;
  final String? error;

  const DfuOperationState({
    this.selectedRelease,
    this.selectedWorkflowRun,
    this.selectedArtifact,
    this.downloadedImage,
    this.filesystemImage,
    this.preparedImages = const [],
    this.isDownloading = false,
    this.isUpdating = false,
    this.isFilesystemUploading = false,
    this.isBothUpdating = false,
    this.currentStep = 0,
    this.totalSteps = 0,
    this.error,
  });

  bool get hasError => error != null;
  bool get hasFirmware => downloadedImage != null;
  bool get hasFilesystem => filesystemImage != null;
  bool get hasBoth => hasFirmware && hasFilesystem;
  
  /// Whether any operation is in progress
  bool get isAnyInProgress => isDownloading || isUpdating || isFilesystemUploading || isBothUpdating;
  
  /// Whether user can start firmware update
  bool get canStartFirmwareUpdate => hasFirmware && !isAnyInProgress;
  
  /// Whether user can start filesystem upload
  bool get canStartFilesystemUpload => hasFilesystem && !isAnyInProgress;
  
  /// Whether user can start both updates
  bool get canStartBoth => hasBoth && !isAnyInProgress;
  
  /// Legacy: alias for canStartFirmwareUpdate
  bool get canStartUpdate => canStartFirmwareUpdate;

  /// Source description for the selected firmware
  String? get sourceDescription {
    if (selectedRelease != null) {
      return 'Release: ${selectedRelease!.name}';
    }
    if (selectedWorkflowRun != null && selectedArtifact != null) {
      return 'CI Build: ${selectedWorkflowRun!.branch} (${selectedWorkflowRun!.shortSha})';
    }
    return null;
  }

  /// Description of what's included in the download
  String get contentDescription {
    if (hasBoth) {
      return 'Firmware + Filesystem';
    } else if (hasFirmware) {
      return 'Firmware only';
    } else if (hasFilesystem) {
      return 'Filesystem only';
    }
    return 'No content';
  }

  /// Current step description for "both" updates
  String get currentStepDescription {
    if (totalSteps == 0) return '';
    if (currentStep == 1) return 'Step 1/$totalSteps: Uploading filesystem...';
    if (currentStep == 2) return 'Step 2/$totalSteps: Updating firmware...';
    return 'Step $currentStep/$totalSteps';
  }

  DfuOperationState copyWith({
    GitHubRelease? selectedRelease,
    WorkflowRun? selectedWorkflowRun,
    WorkflowArtifact? selectedArtifact,
    FirmwareImage? downloadedImage,
    FilesystemImage? filesystemImage,
    List<FirmwareImage>? preparedImages,
    bool? isDownloading,
    bool? isUpdating,
    bool? isFilesystemUploading,
    bool? isBothUpdating,
    int? currentStep,
    int? totalSteps,
    String? error,
  }) {
    return DfuOperationState(
      selectedRelease: selectedRelease ?? this.selectedRelease,
      selectedWorkflowRun: selectedWorkflowRun ?? this.selectedWorkflowRun,
      selectedArtifact: selectedArtifact ?? this.selectedArtifact,
      downloadedImage: downloadedImage ?? this.downloadedImage,
      filesystemImage: filesystemImage ?? this.filesystemImage,
      preparedImages: preparedImages ?? this.preparedImages,
      isDownloading: isDownloading ?? this.isDownloading,
      isUpdating: isUpdating ?? this.isUpdating,
      isFilesystemUploading: isFilesystemUploading ?? this.isFilesystemUploading,
      isBothUpdating: isBothUpdating ?? this.isBothUpdating,
      currentStep: currentStep ?? this.currentStep,
      totalSteps: totalSteps ?? this.totalSteps,
      error: error,
    );
  }
}

/// Provider for DFU logs (combined from all services)
final dfuLogsProvider = StreamProvider<String>((ref) {
  final dfuService = ref.watch(dfuServiceProvider);
  final firmwareManager = ref.watch(firmwareManagerProvider);
  final fsService = ref.watch(filesystemUploadServiceProvider);

  return Rx.merge([
    dfuService.logStream,
    firmwareManager.logStream,
    fsService.logStream,
  ]);
});

