import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';

import '../data/models/dfu_state.dart';
import '../data/models/firmware_image.dart';
import '../services/dfu/dfu_service.dart';
import '../services/dfu/firmware_manager.dart';
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
      final image = await _firmwareManager.downloadReleaseAsset(release, asset);
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

  /// Start the DFU process
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

  /// Cancel the current operation
  Future<void> cancel() async {
    if (_dfuService.isInProgress) {
      await _dfuService.cancel();
    }
    _firmwareManager.cancelDownload();
    state = state.copyWith(
      isDownloading: false,
      isUpdating: false,
    );
  }

  /// Reset state
  void reset() {
    _dfuService.reset();
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
  final List<FirmwareImage> preparedImages;
  final bool isDownloading;
  final bool isUpdating;
  final String? error;

  const DfuOperationState({
    this.selectedRelease,
    this.selectedWorkflowRun,
    this.selectedArtifact,
    this.downloadedImage,
    this.preparedImages = const [],
    this.isDownloading = false,
    this.isUpdating = false,
    this.error,
  });

  bool get hasError => error != null;
  bool get hasFirmware => downloadedImage != null;
  bool get canStartUpdate => hasFirmware && !isDownloading && !isUpdating;

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

  DfuOperationState copyWith({
    GitHubRelease? selectedRelease,
    WorkflowRun? selectedWorkflowRun,
    WorkflowArtifact? selectedArtifact,
    FirmwareImage? downloadedImage,
    List<FirmwareImage>? preparedImages,
    bool? isDownloading,
    bool? isUpdating,
    String? error,
  }) {
    return DfuOperationState(
      selectedRelease: selectedRelease ?? this.selectedRelease,
      selectedWorkflowRun: selectedWorkflowRun ?? this.selectedWorkflowRun,
      selectedArtifact: selectedArtifact ?? this.selectedArtifact,
      downloadedImage: downloadedImage ?? this.downloadedImage,
      preparedImages: preparedImages ?? this.preparedImages,
      isDownloading: isDownloading ?? this.isDownloading,
      isUpdating: isUpdating ?? this.isUpdating,
      error: error,
    );
  }
}

/// Provider for DFU logs (combined from both services)
final dfuLogsProvider = StreamProvider<String>((ref) {
  final dfuService = ref.watch(dfuServiceProvider);
  final firmwareManager = ref.watch(firmwareManagerProvider);

  return Rx.merge([
    dfuService.logStream,
    firmwareManager.logStream,
  ]);
});

