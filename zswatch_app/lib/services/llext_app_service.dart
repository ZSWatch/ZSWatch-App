import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mcumgr_flutter/mcumgr_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rxdart/rxdart.dart';

import '../../data/models/filesystem_image.dart';
import '../../data/models/llext_app.dart';
import 'dfu/filesystem_upload_service.dart';
import 'watch_service.dart';

/// Service responsible for listing, installing, and removing LLEXT apps on
/// the connected ZSWatch over BLE.
///
/// **Listing:** [FsManager.status()] probes each known app path — success
/// means installed, [PlatformException] means absent. Requires SMP/MCUmgr.
///
/// **Installing:** 1. Sends a Gadgetbridge `llext mkdir` command to create
/// the app directory on the watch. 2. Uploads the .llext binary via MCUmgr
/// filesystem write.
///
/// **Removing:** A Gadgetbridge `llext rm` command instructs the watch to
/// unlink the .llext file and remove the app directory. Works over normal
/// BLE connection — SMP mode is not required.
class LlextAppService {
  final FilesystemUploadService _uploadService;
  final WatchService _watchService;

  final _appsStateController = BehaviorSubject<List<LlextAppState>>();
  final _logController = StreamController<String>.broadcast();

  FsManager? _fsManager;

  /// Stream of the full list of known apps with their current install state.
  Stream<List<LlextAppState>> get appsStream => _appsStateController.stream;

  /// Most recent snapshot of app states.
  List<LlextAppState> get currentApps =>
      _appsStateController.valueOrNull ?? _buildInitialState();

  /// Stream of log messages for debugging.
  Stream<String> get logStream => _logController.stream;

  LlextAppService(this._uploadService, this._watchService) {
    // Seed with empty state (not yet probed).
    _appsStateController.add(_buildInitialState());
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Probe the watch to determine which known LLEXT apps are installed.
  ///
  /// Calls [FsManager.status()] for each known app path. A successful response
  /// means the file is present; a [PlatformException] means absent.
  ///
  /// [deviceId] must be the BLE remote ID (MAC on Android, UUID on iOS).
  Future<void> refreshInstalledApps(String deviceId) async {
    _log('Refreshing installed apps (device: $deviceId)…');

    try {
      _fsManager = FsManager(deviceId);
    } catch (e) {
      _log('Failed to get FsManager: $e');
      rethrow;
    }

    final updated = <LlextAppState>[];

    for (final def in kBundledLlextApps) {
      try {
        final sizeBytes = await _fsManager!.status(def.watchPath);
        _log('  ${def.id}: installed ($sizeBytes bytes)');
        updated.add(LlextAppState(
          definition: def,
          isInstalled: true,
          watchFileSizeBytes: sizeBytes,
        ));
      } on PlatformException catch (e) {
        // A "file not found" error is expected — app is not installed.
        _log('  ${def.id}: not installed (${e.code}: ${e.message})');
        updated.add(LlextAppState(
          definition: def,
          isInstalled: false,
        ));
      } catch (e) {
        _log('  ${def.id}: probe error — $e');
        updated.add(LlextAppState(
          definition: def,
          isInstalled: false,
        ));
      }
    }

    await _fsManager?.kill();
    _fsManager = null;

    _appsStateController.add(updated);
    _log('Refresh complete.');
  }

  /// Install an LLEXT app onto the watch.
  ///
  /// 1. Loads the bundled .llext asset into memory.
  /// 2. Writes it to a temporary file (MCUmgr upload requires a file path).
  /// 3. Delegates to [FilesystemUploadService] for the BLE transfer.
  ///
  /// Returns once the [FilesystemUploadService] yields a terminal state
  /// (completed, failed, or cancelled). Call [refreshInstalledApps] after
  /// a successful install to update the list.
  Future<void> installApp({
    required String deviceId,
    required LlextAppDefinition definition,
  }) async {
    _log('Installing ${definition.id}…');

    // Mark as installing in the state list.
    _setInstalling(definition.id, true);

    try {
      // 1. Load asset bytes.
      final ByteData assetData = await rootBundle.load(definition.assetPath);
      final Uint8List bytes = assetData.buffer.asUint8List(
        assetData.offsetInBytes,
        assetData.lengthInBytes,
      );
      _log('Loaded asset ${definition.assetPath} (${bytes.length} bytes)');

      // 2. Write to temp file.
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/${definition.id}_app.llext');
      await tempFile.writeAsBytes(bytes);
      _log('Written to temp file: ${tempFile.path}');

      // 3. Create the app directory on the watch via Gadgetbridge before
      //    starting the MCUmgr file upload (the firmware can't do it for us).
      _log('Creating app directory for ${definition.id}…');
      await _watchService.llextMkdir(definition.id);
      // Allow the watch a moment to process the command before the upload starts.
      await Future<void>.delayed(const Duration(milliseconds: 500));

      // 4. Create the filesystem image descriptor.
      final image = FilesystemImage(
        name: definition.name,
        filePath: tempFile.path,
        targetPath: definition.watchPath,
        size: bytes.length,
      );

      // 5. Subscribe to upload state before starting.
      final uploadCompleter = Completer<void>();
      final sub = _uploadService.stateStream.listen((state) {
        if (state.status == FilesystemUploadStatus.completed) {
          if (!uploadCompleter.isCompleted) uploadCompleter.complete();
        } else if (state.status == FilesystemUploadStatus.failed ||
            state.status == FilesystemUploadStatus.cancelled) {
          if (!uploadCompleter.isCompleted) {
            uploadCompleter.completeError(
              Exception('Upload ${state.status.name}: ${state.errorMessage ?? ''}'),
            );
          }
        }
      });

      // 6. Upload via the existing service.
      await _uploadService.startUpload(deviceId: deviceId, image: image);
      await uploadCompleter.future;
      await sub.cancel();

      _log('Install of ${definition.id} completed');

      // 7. Hot-load the app on the watch (no reboot required).
      _log('Hot-loading ${definition.id} on watch…');
      await _watchService.llextLoad(definition.id);

      // Clean up temp file.
      await tempFile.delete().catchError((_) => tempFile);
    } catch (e) {
      _log('Install of ${definition.id} failed: $e');
      _setInstalling(definition.id, false);
      rethrow;
    }

    _setInstalling(definition.id, false);
  }

  /// Remove an LLEXT app from the watch via the Gadgetbridge protocol.
  ///
  /// Sends `{"t":"llext","op":"rm","id":appId}` to the watch. The firmware
  /// handler unlinks the .llext file and removes the app directory.
  /// SMP/MCUmgr mode is NOT required — works over normal BLE connection.
  Future<void> removeApp({
    required String appId,
  }) async {
    _log('Removing $appId via Gadgetbridge…');
    try {
      await _watchService.llextRemove(appId);
      _log('Remove command sent for $appId');

      // Optimistically update state — mark as not installed.
      final current = List<LlextAppState>.from(currentApps);
      final idx = current.indexWhere((s) => s.definition.id == appId);
      if (idx >= 0) {
        current[idx] = current[idx].copyWith(
          isInstalled: false,
          clearWatchFileSize: true,
        );
        _appsStateController.add(current);
      }
    } catch (e) {
      _log('Remove of $appId failed: $e');
      rethrow;
    }
  }

  /// Dispose all resources.
  Future<void> dispose() async {
    await _fsManager?.kill().catchError((_) {});
    await _appsStateController.close();
    await _logController.close();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  List<LlextAppState> _buildInitialState() {
    return kBundledLlextApps
        .map((def) => LlextAppState(definition: def, isInstalled: false))
        .toList();
  }

  void _setInstalling(String id, bool installing) {
    final current = List<LlextAppState>.from(currentApps);
    final idx = current.indexWhere((s) => s.definition.id == id);
    if (idx >= 0) {
      current[idx] = current[idx].copyWith(isInstalling: installing);
      _appsStateController.add(current);
    }
  }

  void _log(String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 23);
    _logController.add('[LLEXT] [$timestamp] $message');
    debugPrint('[LlextAppService] $message');
  }
}
