import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mcumgr_flutter/mcumgr_flutter.dart';
import 'package:rxdart/rxdart.dart';

import '../data/models/dfu_state.dart';
import '../data/models/companion_firmware_status.dart';
import '../core/constants/filesystem_constants.dart';
import 'companion_runtime_providers.dart';
import '../data/models/filesystem_image.dart';
import '../data/models/firmware_image.dart';
import '../services/dfu/dfu_service.dart';
import '../services/dfu/firmware_manager.dart';
import 'filesystem_providers.dart';
import 'watch_service_provider.dart';

part 'dfu_providers.freezed.dart';

/// Provider for the DFU service singleton
final dfuServiceProvider = Provider<DfuService>((ref) {
  if (ref.watch(nativeCompanionRuntimeProvider)) {
    throw StateError('Native firmware owner is selected');
  }
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

final companionFirmwareStatusProvider =
    Provider<AsyncValue<CompanionFirmwareStatus?>>((ref) {
      return ref.watch(companionSnapshotProvider).whenData((snapshot) {
        final status = CompanionFirmwareStatus.decode(snapshot.fields);
        return status?.address == snapshot.fields['address'] ? status : null;
      });
    });

// Local UI dismissal never resets, cancels or replays native work.
final _submittedFirmwareGenerationProvider = StateProvider<int?>((ref) => null);
final _dismissedFirmwareProvider =
    StateNotifierProvider<_FirmwareResultDismissal, String?>((ref) {
      final dismissal = _FirmwareResultDismissal();
      ref.listen(companionFirmwareStatusProvider, (_, next) {
        dismissal.observe(
          next.valueOrNull,
          acceptedId: ref.read(_acceptedFirmwareProvider)?.id,
          submittedGeneration: ref.read(_submittedFirmwareGenerationProvider),
        );
      }, fireImmediately: true);
      return dismissal;
    });
final _acceptedFirmwareProvider = StateProvider<CompanionFirmwareAcceptance?>(
  (ref) => null,
);

/// Show terminal results only for updates started or observed by this UI session.
class _FirmwareResultDismissal extends StateNotifier<String?> {
  _FirmwareResultDismissal() : super(null);

  String? _observedActiveId;

  void observe(
    CompanionFirmwareStatus? status, {
    String? acceptedId,
    int? submittedGeneration,
  }) {
    if (status == null) return;
    if (status.busy) {
      _observedActiveId = status.id;
    } else if (status.id != _observedActiveId &&
        status.id != acceptedId &&
        status.generation != submittedGeneration) {
      state = status.id;
    }
  }

  void dismiss(String? id) => state = id;
}

/// Metadata for display; retained native work remains busy after UI reattachment.
final effectiveDfuOperationStateProvider = Provider<DfuOperationState>((ref) {
  final local = ref.watch(dfuNotifierProvider);
  if (!ref.watch(nativeCompanionRuntimeProvider)) return local;
  final status = ref.watch(companionFirmwareStatusProvider).valueOrNull;
  final both =
      status?.resource != null && status!.indices.isNotEmpty && status.busy;
  return local.copyWith(
    isUpdating: ref.watch(dfuStateProvider).status.isInProgress,
    isBothUpdating: both,
    currentStep: both ? (status.resourceStage ? 1 : 2) : 0,
    totalSteps: both ? 2 : 0,
  );
});

/// Resource state comes from the same service-owned package, never watchface receipts.
final firmwareFilesystemStateProvider = Provider<FilesystemUploadState>((ref) {
  if (!ref.watch(nativeCompanionRuntimeProvider)) {
    return ref.watch(filesystemUploadStateProvider);
  }
  final status = ref.watch(companionFirmwareStatusProvider).valueOrNull;
  final dismissed = ref.watch(_dismissedFirmwareProvider);
  if (status == null ||
      status.resource == null ||
      (!status.busy && status.id == dismissed)) {
    return const FilesystemUploadState();
  }
  return FilesystemUploadState(
    status: status.resourceStage
        ? FilesystemUploadStatus.uploading
        : status.phase == 'completed'
        ? FilesystemUploadStatus.completed
        : status.busy
        ? FilesystemUploadStatus.idle
        : FilesystemUploadStatus.failed,
    progress: status.total == 0 ? 0 : status.current / status.total,
    bytesTransferred: status.current,
    totalBytes: status.total,
    imageName: status.phase == 'resource_verifying'
        ? 'Verifying LVGL resources'
        : 'LVGL resources',
    errorMessage: status.errorMessage,
  );
});

/// Provider for current DFU state
final dfuStateProvider = Provider<DfuState>((ref) {
  if (ref.watch(nativeCompanionRuntimeProvider)) {
    final asyncStatus = ref.watch(companionFirmwareStatusProvider);
    // Subscribe before returning an active state so its completion is observed.
    final dismissed = ref.watch(_dismissedFirmwareProvider);
    if (asyncStatus.hasError || asyncStatus.isLoading) {
      return const DfuState(
        status: DfuStatus.failed,
        errorMessage:
            'Firmware status is unavailable. Reopen the screen when companion status is available.',
      );
    }
    final status = asyncStatus.valueOrNull;
    final submitted = ref.watch(_submittedFirmwareGenerationProvider);
    final receipt = ref.watch(_acceptedFirmwareProvider);
    final local = ref.watch(dfuNotifierProvider);
    if (status?.busy == true) {
      if (ref.watch(companionSnapshotProvider).valueOrNull?.runtimeActive !=
          true) {
        return const DfuState(
          status: DfuStatus.failed,
          errorMessage:
              'The background service is unavailable during a firmware operation. The installed firmware is unverified. Reconnect and check the watch.',
        );
      }
      return status!.dfuState;
    }
    if (!local.isUpdating &&
        submitted != null &&
        status?.generation != submitted &&
        receipt == null) {
      return const DfuState(
        status: DfuStatus.failed,
        errorMessage:
            'Firmware acceptance is unknown. Check companion status and the watch before selecting another update.',
      );
    }
    if (local.isUpdating || (receipt != null && status?.id != receipt.id)) {
      return const DfuState(status: DfuStatus.preparing);
    }
    if (status == null || status.id == dismissed) {
      return DfuState.idle;
    }
    return status.dfuState;
  }
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
  return asyncValue.valueOrNull ??
      const DownloadProgress(0, 0, DownloadStatus.idle);
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
    StateNotifierProvider<ReleasesNotifier, AsyncValue<List<GitHubRelease>>>((
      ref,
    ) {
      final manager = ref.watch(firmwareManagerProvider);
      return ReleasesNotifier(manager);
    });

/// State notifier for workflow runs (manual fetch to avoid rate limiting)
class WorkflowRunsNotifier
    extends StateNotifier<AsyncValue<List<WorkflowRun>>> {
  final FirmwareManager _manager;

  WorkflowRunsNotifier(this._manager) : super(const AsyncValue.data([]));

  Future<void> fetch() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _manager.fetchWorkflowRuns());
  }
}

/// Provider for GitHub Actions workflow runs (manual fetch)
final workflowRunsProvider =
    StateNotifierProvider<WorkflowRunsNotifier, AsyncValue<List<WorkflowRun>>>((
      ref,
    ) {
      final manager = ref.watch(firmwareManagerProvider);
      return WorkflowRunsNotifier(manager);
    });

/// State notifier for DFU operations
class DfuNotifier extends StateNotifier<DfuOperationState> {
  final DfuService? _dfuService;
  int _nativeAttempt = 0;
  final FirmwareManager _firmwareManager;
  final Ref _ref;

  DfuNotifier(this._dfuService, this._firmwareManager, this._ref)
    : super(const DfuOperationState());

  bool get _nativeSelectionBlocked =>
      _ref.read(nativeCompanionRuntimeProvider) &&
      (state.isAnyInProgress ||
          _ref.read(companionFirmwareStatusProvider).valueOrNull?.busy ==
              true ||
          _ref.read(_acceptedFirmwareProvider) != null ||
          _ref.read(_submittedFirmwareGenerationProvider) != null);

  /// Download firmware from a GitHub release asset
  Future<void> downloadReleaseAsset(
    GitHubRelease release,
    ReleaseAsset asset,
  ) async {
    if (_nativeSelectionBlocked) return;
    state = state.copyWith(
      selectedRelease: release,
      isDownloading: true,
      error: null,
    );

    try {
      final result = await _firmwareManager.downloadReleaseAsset(
        release,
        asset,
      );
      state = state.copyWith(
        downloadedImage: result.firmwareImage,
        filesystemImage: result.filesystemImage,
        isDownloading: false,
      );
    } catch (e) {
      state = state.copyWith(isDownloading: false, error: e.toString());
    }
  }

  /// Download firmware from a GitHub Actions artifact
  Future<void> downloadArtifact(
    WorkflowRun run,
    WorkflowArtifact artifact,
  ) async {
    if (_nativeSelectionBlocked) return;
    debugPrint('[DfuNotifier] downloadArtifact called');
    debugPrint(
      '[DfuNotifier] Run: ${run.id}, Branch: ${run.branch}, SHA: ${run.shortSha}',
    );
    debugPrint(
      '[DfuNotifier] Artifact: ${artifact.name}, ID: ${artifact.id}, Size: ${artifact.sizeInBytes}',
    );

    state = state.copyWith(
      selectedWorkflowRun: run,
      selectedArtifact: artifact,
      isDownloading: true,
      error: null,
    );

    try {
      final result = await _firmwareManager.downloadArtifact(run, artifact);
      state = state.copyWith(
        downloadedImage: result.firmwareImage,
        filesystemImage: result.filesystemImage,
        isDownloading: false,
      );
    } catch (e) {
      debugPrint('[DfuNotifier] downloadArtifact error: $e');
      state = state.copyWith(isDownloading: false, error: e.toString());
    }
  }

  /// Get browser URL for artifact download (for manual download fallback)
  String getArtifactBrowserUrl(WorkflowRun run, WorkflowArtifact artifact) {
    return _firmwareManager.getArtifactBrowserUrl(run, artifact);
  }

  /// Load a local firmware file
  Future<void> loadLocalFile(String filePath) async {
    if (_nativeSelectionBlocked) return;
    state = state.copyWith(isDownloading: true, error: null);

    try {
      final result = await _firmwareManager.loadLocalFile(filePath);
      state = state.copyWith(
        downloadedImage: result.firmwareImage,
        filesystemImage: result.filesystemImage,
        isDownloading: false,
      );
    } catch (e) {
      state = state.copyWith(isDownloading: false, error: e.toString());
    }
  }

  /// Ensure SMP is enabled on the watch before DFU/FS operations.
  ///
  /// Sends the GadgetBridge `smp_enable` command, waits for the watch to
  /// register the SMP BT transport, then re-discovers services so the
  /// MCUmgr GATT service appears.
  Future<void> _ensureSmpEnabled() async {
    final watchService = _ref.read(watchServiceProvider);

    // Do not trust the cached discovery state here. SMP may have been
    // disabled on the watch after the last service discovery, leaving
    // hasSmpService stuck at true until we explicitly re-discover.
    debugPrint('[DfuNotifier] Ensuring SMP is enabled...');
    await watchService.enableSmp();
    await Future<void>.delayed(const Duration(seconds: 2));
    final ready = await watchService.rediscoverServices();
    if (!ready) {
      throw Exception(
        'SMP service did not become available. '
        'If your watch firmware is older, you may need to manually enable it: '
        'on the watch go to Apps → Update → Enable FW Update.',
      );
    }
    _ref.invalidate(hasSmpServiceProvider);
    debugPrint('[DfuNotifier] SMP enabled and discovered');
  }

  /// Start the DFU process (firmware only)
  Future<void> startUpdate() async {
    if (_ref.read(nativeCompanionRuntimeProvider)) {
      await _startNativeFirmware();
      return;
    }
    final image = state.downloadedImage;
    if (image == null) {
      state = state.copyWith(error: 'No firmware selected');
      return;
    }

    state = state.copyWith(isUpdating: true, error: null);

    try {
      // Prepare firmware (extract if needed)
      final images = await _firmwareManager.prepareFirmware(image);
      state = state.copyWith(preparedImages: images);

      // Get the connected device
      final watchService = _ref.read(watchServiceProvider);
      if (!watchService.isConnected) {
        throw Exception('Watch not connected');
      }

      // Auto-enable SMP on the watch if needed
      await _ensureSmpEnabled();

      // The device ID is needed to create a BluetoothDevice
      final connection = watchService.currentConnection;
      final deviceId = connection.watchId;
      if (deviceId.isEmpty) {
        throw Exception('No device ID available');
      }

      // Create a BluetoothDevice from the ID
      final bluetoothDevice = BluetoothDevice.fromId(deviceId);

      // Start the DFU
      await _dfuService!.startUpdate(
        device: bluetoothDevice,
        firmwareImages: images,
      );

      state = state.copyWith(isUpdating: false);
    } catch (e) {
      state = state.copyWith(isUpdating: false, error: e.toString());
    }
  }

  Future<void> _startNativeFirmware({
    bool firmware = true,
    bool resources = false,
  }) async {
    final nativeStatus = _ref.read(companionFirmwareStatusProvider);
    if (state.isAnyInProgress ||
        _ref.read(_submittedFirmwareGenerationProvider) != null ||
        _ref.read(_acceptedFirmwareProvider) != null ||
        (nativeStatus.valueOrNull != null &&
            nativeStatus.valueOrNull!.id !=
                _ref.read(_dismissedFirmwareProvider))) {
      return;
    }
    if (nativeStatus.hasError || nativeStatus.isLoading) {
      state = state.copyWith(error: 'Companion firmware status is unavailable');
      return;
    }
    final image = firmware ? state.downloadedImage : null;
    final resourceImage = resources ? state.filesystemImage : null;
    if ((firmware && image == null) || (resources && resourceImage == null)) {
      state = state.copyWith(error: 'No selected update image available');
      return;
    }
    final snapshot = _ref.read(companionSnapshotProvider).valueOrNull;
    if (snapshot == null ||
        !snapshot.runtimeActive ||
        !snapshot.protocolReady) {
      state = state.copyWith(
        error: 'Connect the watch before updating firmware',
      );
      return;
    }
    final address = snapshot.fields['address'];
    final attempt = ++_nativeAttempt;
    state = state.copyWith(isUpdating: true, error: null);
    try {
      final images = image == null
          ? <FirmwareImage>[]
          : await _firmwareManager.prepareFirmware(image);
      if (!mounted || attempt != _nativeAttempt) return;
      state = state.copyWith(preparedImages: images);
      if ((firmware && images.isEmpty) || images.length > 3) {
        throw const FormatException('Expected one to three firmware images');
      }
      final payloads = <CompanionFirmwareImage>[];
      for (final prepared in images) {
        // Preserve manifest image_index, including single external index 2.
        // Multiple images without indices must not silently target image 0.
        final index = prepared.slot ?? (images.length == 1 ? 0 : -1);
        if (index < 0 ||
            index > 2 ||
            payloads.any((item) => item.index == index)) {
          throw const FormatException(
            'Firmware package needs distinct image indices',
          );
        }
        if (!FirmwareManager.firmwareBoardMatches(
          prepared.board,
          snapshot.watch?.hardwareVersion,
        )) {
          throw const FormatException(
            'Firmware package is for another watch board',
          );
        }
        final file = File(prepared.filePath);
        final size = await file.length();
        if (size < 1 ||
            size > CompanionFirmwareStatus.maxImageBytes ||
            size != prepared.size) {
          throw const FormatException(
            'Unsupported or changed firmware image size',
          );
        }
        final bytes = await file.readAsBytes();
        if (bytes.length != size) {
          throw const FormatException('Firmware image changed while reading');
        }
        payloads.add(CompanionFirmwareImage(index, bytes));
      }
      Uint8List? resourceBytes;
      if (resourceImage != null) {
        if (resourceImage.targetPath != FilesystemConstants.targetPath) {
          throw const FormatException('Unexpected resource target path');
        }
        final file = File(resourceImage.filePath);
        final size = await file.length();
        if (size < 20 ||
            size > CompanionFirmwareStatus.maxImageBytes ||
            size != resourceImage.size) {
          throw const FormatException(
            'Unsupported or changed resource image size',
          );
        }
        resourceBytes = await file.readAsBytes();
        if (resourceBytes.length != size) {
          throw const FormatException('Resource image changed while reading');
        }
        CompanionResourceTarget.validatePayload(resourceBytes);
      }
      CompanionFirmwareImage.validate(
        payloads,
        allowEmpty: resourceBytes != null,
      );
      if (!mounted || attempt != _nativeAttempt) return;
      final current = _ref.read(companionSnapshotProvider).valueOrNull;
      if (current == null ||
          !current.runtimeActive ||
          !current.protocolReady ||
          current.fields['address'] != address ||
          current.generation != snapshot.generation) {
        throw StateError('Watch connection changed while preparing firmware');
      }
      final client = _ref.read(companionClientProvider);
      final preparedGeneration = await client.prepareShell(snapshot.generation);
      if (!mounted || attempt != _nativeAttempt) return;
      _ref.read(_acceptedFirmwareProvider.notifier).state = null;
      _ref.read(_submittedFirmwareGenerationProvider.notifier).state =
          preparedGeneration + 1;
      final receipt = await client.startFirmware(
        preparedGeneration,
        payloads,
        resources: resourceBytes,
      );
      if (!mounted) return; // UI disposal never stops accepted native work.
      _ref.read(_acceptedFirmwareProvider.notifier).state = receipt;
      _ref.read(_dismissedFirmwareProvider.notifier).dismiss(null);
      state = state.copyWith(isUpdating: false);
    } catch (error) {
      if (mounted && attempt == _nativeAttempt) {
        state = state.copyWith(isUpdating: false, error: error.toString());
      }
    }
  }

  /// Start filesystem upload only
  Future<void> startFilesystemUpload() async {
    if (_ref.read(nativeCompanionRuntimeProvider)) {
      await _startNativeFirmware(firmware: false, resources: true);
      return;
    }
    final fsImage = state.filesystemImage;
    if (fsImage == null) {
      state = state.copyWith(error: 'No filesystem image available');
      return;
    }

    state = state.copyWith(isFilesystemUploading: true, error: null);

    try {
      // Get the connected device
      final watchService = _ref.read(watchServiceProvider);
      if (!watchService.isConnected) {
        throw Exception('Watch not connected');
      }

      // Auto-enable SMP on the watch if needed
      await _ensureSmpEnabled();

      final connection = watchService.currentConnection;
      final deviceId = connection.watchId;
      if (deviceId.isEmpty) {
        throw Exception('No device ID available');
      }

      // Start the filesystem upload
      final fsService = _ref.read(filesystemUploadServiceProvider);
      await fsService.startUpload(deviceId: deviceId, image: fsImage);

      // Wait for filesystem upload to complete before restarting
      await fsService.stateStream.firstWhere((s) => s.status.isTerminal);

      if (fsService.currentState.status == FilesystemUploadStatus.completed) {
        // Restart the watch so the new filesystem resources take effect
        debugPrint('[DfuNotifier] FS upload complete, restarting watch...');
        try {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          await OsManager.reset(deviceId);
          debugPrint('[DfuNotifier] Watch restart command sent');
        } catch (e) {
          debugPrint(
            '[DfuNotifier] Failed to restart watch after FS upload: $e',
          );
          // Don't fail the overall operation — the upload itself succeeded
        }
      }

      state = state.copyWith(isFilesystemUploading: false);
    } catch (e) {
      state = state.copyWith(isFilesystemUploading: false, error: e.toString());
    }
  }

  /// Start both filesystem upload and firmware update (filesystem first, then firmware)
  Future<void> startBothUpdates() async {
    if (_ref.read(nativeCompanionRuntimeProvider)) {
      await _startNativeFirmware(firmware: true, resources: true);
      return;
    }
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

      // Auto-enable SMP on the watch if needed
      await _ensureSmpEnabled();

      final connection = watchService.currentConnection;
      final deviceId = connection.watchId;
      if (deviceId.isEmpty) {
        throw Exception('No device ID available');
      }

      // Step 1: Upload filesystem if available
      if (fsImage != null) {
        state = state.copyWith(currentStep: 1);

        final fsService = _ref.read(filesystemUploadServiceProvider);
        await fsService.startUpload(deviceId: deviceId, image: fsImage);

        // Wait for filesystem upload to complete
        await fsService.stateStream.firstWhere((s) => s.status.isTerminal);

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
        await _dfuService!.startUpdate(
          device: bluetoothDevice,
          firmwareImages: images,
        );
      }

      state = state.copyWith(isBothUpdating: false);
    } catch (e) {
      state = state.copyWith(isBothUpdating: false, error: e.toString());
    }
  }

  /// Cancel the current operation
  Future<void> cancel() async {
    if (_ref.read(nativeCompanionRuntimeProvider)) {
      final status = _ref.read(companionFirmwareStatusProvider).valueOrNull;
      if (status != null && status.busy) {
        if (!status.canCancel) return;
        try {
          await _ref.read(companionClientProvider).cancelFirmware(status.id);
        } catch (error) {
          if (mounted) state = state.copyWith(error: error.toString());
        }
        return; // Wait for Nordic terminal status; do not invent cancellation.
      }
      if (state.isUpdating) return; // Start receipt may still be in flight.
      _firmwareManager.cancelDownload();
      state = state.copyWith(isDownloading: false);
      return;
    }
    if (_dfuService!.isInProgress) {
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
    if (_ref.read(nativeCompanionRuntimeProvider)) {
      final status = _ref.read(companionFirmwareStatusProvider).valueOrNull;
      if (state.isUpdating || status?.busy == true) return;
      _nativeAttempt++;
      _ref.read(_dismissedFirmwareProvider.notifier).dismiss(status?.id);
      _ref.read(_acceptedFirmwareProvider.notifier).state = null;
      _ref.read(_submittedFirmwareGenerationProvider.notifier).state = null;
      _firmwareManager.resetProgress();
      state = const DfuOperationState();
      return;
    }
    _dfuService!.reset();
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
      final dfuService = ref.watch(nativeCompanionRuntimeProvider)
          ? null
          : ref.watch(dfuServiceProvider);
      final firmwareManager = ref.watch(firmwareManagerProvider);
      return DfuNotifier(dfuService, firmwareManager, ref);
    });

/// State for DFU operations
@freezed
abstract class DfuOperationState with _$DfuOperationState {
  const DfuOperationState._();

  const factory DfuOperationState({
    GitHubRelease? selectedRelease,
    WorkflowRun? selectedWorkflowRun,
    WorkflowArtifact? selectedArtifact,
    FirmwareImage? downloadedImage,
    FilesystemImage? filesystemImage,
    @Default(<FirmwareImage>[]) List<FirmwareImage> preparedImages,
    @Default(false) bool isDownloading,
    @Default(false) bool isUpdating,
    @Default(false) bool isFilesystemUploading,
    @Default(false) bool isBothUpdating,
    @Default(0) int currentStep,
    @Default(0) int totalSteps,
    String? error,
  }) = _DfuOperationState;

  bool get hasError => error != null;
  bool get hasFirmware => downloadedImage != null;
  bool get hasFilesystem => filesystemImage != null;
  bool get hasBoth => hasFirmware && hasFilesystem;

  /// Whether any operation is in progress
  bool get isAnyInProgress =>
      isDownloading || isUpdating || isFilesystemUploading || isBothUpdating;

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
}

/// Provider for DFU logs (combined from all services)
final dfuLogsProvider = StreamProvider<String>((ref) {
  final firmwareManager = ref.watch(firmwareManagerProvider);
  if (ref.watch(nativeCompanionRuntimeProvider)) {
    return Rx.merge([
      firmwareManager.logStream,
      companionValues(ref, (snapshot) {
        CompanionFirmwareStatus? status;
        try {
          status = CompanionFirmwareStatus.decode(snapshot.fields);
        } on FormatException {
          return 'Firmware status unavailable';
        }
        return status == null
            ? 'Companion firmware status available'
            : 'Firmware: ${status.phase}${status.error == null ? '' : ' (${status.error})'}';
      }).distinct(),
    ]);
  }
  final dfuService = ref.watch(dfuServiceProvider);
  final fsService = ref.watch(filesystemUploadServiceProvider);

  return Rx.merge([
    dfuService.logStream,
    firmwareManager.logStream,
    fsService.logStream,
  ]);
});
