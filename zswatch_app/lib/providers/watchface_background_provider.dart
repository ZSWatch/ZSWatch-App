import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../core/utils/watchface_image_processor.dart';
import '../data/models/filesystem_image.dart';
import '../services/dfu/filesystem_upload_service.dart';
import 'filesystem_providers.dart';
import 'watch_service_provider.dart';

/// Target path for the background upload (temp name to avoid race condition)
const _uploadTargetPath = '/user/bg_new.bin';

/// Built-in background definition
class BuiltinBackground {
  final String name;
  final String assetBinPath;
  final String assetPreviewPath;

  const BuiltinBackground({
    required this.name,
    required this.assetBinPath,
    required this.assetPreviewPath,
  });
}

/// A group of related backgrounds
class BackgroundGroup {
  final String name;
  final List<BuiltinBackground> backgrounds;

  const BackgroundGroup({required this.name, required this.backgrounds});
}

/// All built-in backgrounds organized by group
const backgroundGroups = [
  BackgroundGroup(
    name: 'Round-Display Combos',
    backgrounds: [
      BuiltinBackground(
        name: 'Fume Guilloche',
        assetBinPath: 'assets/backgrounds/bg_fume_guilloche.bin',
        assetPreviewPath: 'assets/backgrounds/bg_fume_guilloche.png',
      ),
      BuiltinBackground(
        name: 'Topo Metal Arc',
        assetBinPath: 'assets/backgrounds/bg_topo_metal_arc.bin',
        assetPreviewPath: 'assets/backgrounds/bg_topo_metal_arc.png',
      ),
      BuiltinBackground(
        name: 'CRT Neon Grid',
        assetBinPath: 'assets/backgrounds/bg_crt_neon_grid.bin',
        assetPreviewPath: 'assets/backgrounds/bg_crt_neon_grid.png',
      ),
      BuiltinBackground(
        name: 'Flow Ink Parchment',
        assetBinPath: 'assets/backgrounds/bg_flow_ink_parchment.bin',
        assetPreviewPath: 'assets/backgrounds/bg_flow_ink_parchment.png',
      ),
      BuiltinBackground(
        name: 'Reaction Coral',
        assetBinPath: 'assets/backgrounds/bg_reaction_coral.bin',
        assetPreviewPath: 'assets/backgrounds/bg_reaction_coral.png',
      ),
    ],
  ),
  BackgroundGroup(
    name: 'Gradient & Atmosphere',
    backgrounds: [
      BuiltinBackground(
        name: 'Deep Space',
        assetBinPath: 'assets/backgrounds/bg_deep_space.bin',
        assetPreviewPath: 'assets/backgrounds/bg_deep_space.png',
      ),
      BuiltinBackground(
        name: 'Ocean',
        assetBinPath: 'assets/backgrounds/bg_ocean.bin',
        assetPreviewPath: 'assets/backgrounds/bg_ocean.png',
      ),
      BuiltinBackground(
        name: 'Ember',
        assetBinPath: 'assets/backgrounds/bg_ember.bin',
        assetPreviewPath: 'assets/backgrounds/bg_ember.png',
      ),
      BuiltinBackground(
        name: 'Aurora',
        assetBinPath: 'assets/backgrounds/bg_aurora.bin',
        assetPreviewPath: 'assets/backgrounds/bg_aurora.png',
      ),
      BuiltinBackground(
        name: 'Vortex',
        assetBinPath: 'assets/backgrounds/bg_vortex.bin',
        assetPreviewPath: 'assets/backgrounds/bg_vortex.png',
      ),
      BuiltinBackground(
        name: 'Midnight Frost',
        assetBinPath: 'assets/backgrounds/bg_midnight_frost.bin',
        assetPreviewPath: 'assets/backgrounds/bg_midnight_frost.png',
      ),
      BuiltinBackground(
        name: 'Solar Flare',
        assetBinPath: 'assets/backgrounds/bg_solar_flare.bin',
        assetPreviewPath: 'assets/backgrounds/bg_solar_flare.png',
      ),
      BuiltinBackground(
        name: 'Starfield',
        assetBinPath: 'assets/backgrounds/bg_starfield.bin',
        assetPreviewPath: 'assets/backgrounds/bg_starfield.png',
      ),
      BuiltinBackground(
        name: 'Lava Flow',
        assetBinPath: 'assets/backgrounds/bg_lava_flow.bin',
        assetPreviewPath: 'assets/backgrounds/bg_lava_flow.png',
      ),
      BuiltinBackground(
        name: 'Forest Canopy',
        assetBinPath: 'assets/backgrounds/bg_forest_canopy.bin',
        assetPreviewPath: 'assets/backgrounds/bg_forest_canopy.png',
      ),
      BuiltinBackground(
        name: 'Horizon Sunset',
        assetBinPath: 'assets/backgrounds/bg_horizon_sunset.bin',
        assetPreviewPath: 'assets/backgrounds/bg_horizon_sunset.png',
      ),
    ],
  ),
  BackgroundGroup(
    name: 'Structured Patterns',
    backgrounds: [
      BuiltinBackground(
        name: 'Matrix Rain',
        assetBinPath: 'assets/backgrounds/bg_matrix_rain.bin',
        assetPreviewPath: 'assets/backgrounds/bg_matrix_rain.png',
      ),
      BuiltinBackground(
        name: 'Copper Mesh',
        assetBinPath: 'assets/backgrounds/bg_copper_mesh.bin',
        assetPreviewPath: 'assets/backgrounds/bg_copper_mesh.png',
      ),
      BuiltinBackground(
        name: 'Topographic',
        assetBinPath: 'assets/backgrounds/bg_topographic.bin',
        assetPreviewPath: 'assets/backgrounds/bg_topographic.png',
      ),
      BuiltinBackground(
        name: 'Brushed Titanium',
        assetBinPath: 'assets/backgrounds/bg_brushed_titanium.bin',
        assetPreviewPath: 'assets/backgrounds/bg_brushed_titanium.png',
      ),
      BuiltinBackground(
        name: 'Pixel Neon',
        assetBinPath: 'assets/backgrounds/bg_pixel_neon.bin',
        assetPreviewPath: 'assets/backgrounds/bg_pixel_neon.png',
      ),
      BuiltinBackground(
        name: 'Retro Sunburst',
        assetBinPath: 'assets/backgrounds/bg_retro_sunburst.bin',
        assetPreviewPath: 'assets/backgrounds/bg_retro_sunburst.png',
      ),
      BuiltinBackground(
        name: 'SDF Rings',
        assetBinPath: 'assets/backgrounds/bg_sdf_rings.bin',
        assetPreviewPath: 'assets/backgrounds/bg_sdf_rings.png',
      ),
    ],
  ),
  BackgroundGroup(
    name: 'Material & Editorial',
    backgrounds: [
      BuiltinBackground(
        name: 'Ink Wash',
        assetBinPath: 'assets/backgrounds/bg_ink_wash.bin',
        assetPreviewPath: 'assets/backgrounds/bg_ink_wash.png',
      ),
      BuiltinBackground(
        name: 'Paper Cut',
        assetBinPath: 'assets/backgrounds/bg_paper_cut.bin',
        assetPreviewPath: 'assets/backgrounds/bg_paper_cut.png',
      ),
      BuiltinBackground(
        name: 'Halftone Poster',
        assetBinPath: 'assets/backgrounds/bg_halftone_poster.bin',
        assetPreviewPath: 'assets/backgrounds/bg_halftone_poster.png',
      ),
      BuiltinBackground(
        name: 'Warp Marble',
        assetBinPath: 'assets/backgrounds/bg_warp_marble.bin',
        assetPreviewPath: 'assets/backgrounds/bg_warp_marble.png',
      ),
      BuiltinBackground(
        name: 'Guilloche Dial',
        assetBinPath: 'assets/backgrounds/bg_guilloche_dial.bin',
        assetPreviewPath: 'assets/backgrounds/bg_guilloche_dial.png',
      ),
    ],
  ),
  BackgroundGroup(
    name: 'Cellular & Faceted',
    backgrounds: [
      BuiltinBackground(
        name: 'Mosaic Gem',
        assetBinPath: 'assets/backgrounds/bg_mosaic_gem.bin',
        assetPreviewPath: 'assets/backgrounds/bg_mosaic_gem.png',
      ),
      BuiltinBackground(
        name: 'Voronoi Glass',
        assetBinPath: 'assets/backgrounds/bg_voronoi_glass.bin',
        assetPreviewPath: 'assets/backgrounds/bg_voronoi_glass.png',
      ),
      BuiltinBackground(
        name: 'Low Poly Shards',
        assetBinPath: 'assets/backgrounds/bg_low_poly_shards.bin',
        assetPreviewPath: 'assets/backgrounds/bg_low_poly_shards.png',
      ),
    ],
  ),
  BackgroundGroup(
    name: 'Experimental',
    backgrounds: [
      BuiltinBackground(
        name: 'Flow Field Silk',
        assetBinPath: 'assets/backgrounds/bg_flow_field_silk.bin',
        assetPreviewPath: 'assets/backgrounds/bg_flow_field_silk.png',
      ),
      BuiltinBackground(
        name: 'Moire Interference',
        assetBinPath: 'assets/backgrounds/bg_moire_interference.bin',
        assetPreviewPath: 'assets/backgrounds/bg_moire_interference.png',
      ),
    ],
  ),
];

/// Flat list of all built-in backgrounds (for backward compat)
final builtinBackgrounds = backgroundGroups
    .expand((g) => g.backgrounds)
    .toList();

/// State for the watchface background feature
class WatchfaceBackgroundState {
  final bool isUploading;
  final bool isApplying;
  final String? error;
  final String? successMessage;

  const WatchfaceBackgroundState({
    this.isUploading = false,
    this.isApplying = false,
    this.error,
    this.successMessage,
  });

  WatchfaceBackgroundState copyWith({
    bool? isUploading,
    bool? isApplying,
    String? error,
    String? successMessage,
  }) {
    return WatchfaceBackgroundState(
      isUploading: isUploading ?? this.isUploading,
      isApplying: isApplying ?? this.isApplying,
      error: error,
      successMessage: successMessage,
    );
  }
}

/// Notifier for managing watchface background uploads
class WatchfaceBackgroundNotifier
    extends StateNotifier<WatchfaceBackgroundState> {
  final FilesystemUploadService _uploadService;
  final Ref _ref;
  StreamSubscription<FilesystemUploadState>? _uploadSub;
  int _smpConnectionGeneration = -1;

  WatchfaceBackgroundNotifier(this._uploadService, this._ref)
    : super(const WatchfaceBackgroundState());

  /// Upload a built-in background to the watch
  Future<void> uploadBuiltin(BuiltinBackground bg) async {
    try {
      state = const WatchfaceBackgroundState(isUploading: true);

      // Copy asset to temp file
      final data = await rootBundle.load(bg.assetBinPath);
      final dir = await getTemporaryDirectory();
      final tempPath = p.join(dir.path, 'bg_upload.bin');
      await File(tempPath).writeAsBytes(data.buffer.asUint8List());

      await _startUpload(tempPath, bg.name);
    } catch (e) {
      state = WatchfaceBackgroundState(error: 'Failed: $e');
    }
  }

  /// Upload a custom image (from gallery) to the watch
  Future<void> uploadCustomImage(String imagePath) async {
    try {
      state = const WatchfaceBackgroundState(isUploading: true);

      // Process image: crop, resize, circular mask, convert to LVGL binary
      final binPath = await WatchfaceImageProcessor.processImageFile(imagePath);

      await _startUpload(binPath, 'Custom Background');
    } catch (e) {
      state = WatchfaceBackgroundState(error: 'Failed to process image: $e');
    }
  }

  /// Upload pre-cropped image bytes (from interactive crop UI) to the watch
  Future<void> uploadCroppedImage(Uint8List imageBytes) async {
    try {
      state = const WatchfaceBackgroundState(isUploading: true);

      final bin = WatchfaceImageProcessor.processImageBytes(imageBytes);

      final dir = await getTemporaryDirectory();
      final outPath = p.join(dir.path, 'watchface_bg.bin');
      await File(outPath).writeAsBytes(bin);

      await _startUpload(outPath, 'Custom Background');
    } catch (e) {
      state = WatchfaceBackgroundState(error: 'Failed to process image: $e');
    }
  }

  /// Reset to the default compiled-in background
  Future<void> resetToDefault() async {
    try {
      state = const WatchfaceBackgroundState(isApplying: true);

      final watchService = _ref.read(watchServiceProvider);
      final result = await watchService.resetWatchfaceBackground();
      if (result['ok'] != true) {
        state = WatchfaceBackgroundState(
          error: 'Reset failed: ${_resultError(result)}',
        );
        return;
      }

      state = const WatchfaceBackgroundState(
        successMessage: 'Background reset to default',
      );
    } catch (e) {
      state = WatchfaceBackgroundState(error: 'Reset failed: $e');
    }
  }

  Future<void> _startUpload(String filePath, String name) async {
    final connection = _ref.read(watchConnectionProvider);
    if (!connection.isConnected || connection.watchId.isEmpty) {
      state = const WatchfaceBackgroundState(error: 'Watch not connected');
      return;
    }

    final watchService = _ref.read(watchServiceProvider);

    // Always enable SMP + rediscover services before upload.
    // Cannot rely on hasSmpService — it caches stale discovery results
    // after a previous SMP disable.
    try {
      _smpConnectionGeneration = watchService.connectionGeneration;
      await watchService.enableSmp();
      await Future<void>.delayed(const Duration(seconds: 2));
      final smpReady = await watchService.rediscoverServices();
      if (!smpReady) {
        _disableSmp();
        state = const WatchfaceBackgroundState(
          error: 'SMP service did not become available',
        );
        return;
      }
    } catch (e) {
      _disableSmp();
      state = WatchfaceBackgroundState(error: 'Failed to enable SMP: $e');
      return;
    }

    final image = FilesystemImage(
      name: name,
      filePath: filePath,
      targetPath: _uploadTargetPath,
      size: await File(filePath).length(),
    );

    // Reset service state from any previous upload so the BehaviorSubject
    // doesn't immediately replay a stale 'completed'/'failed' status.
    _uploadService.reset();

    // Listen for completion to trigger the GadgetBridge apply command.
    await _uploadSub?.cancel();
    _uploadSub = _uploadService.stateStream
        .where((s) => s.status != FilesystemUploadStatus.idle)
        .listen((uploadState) {
          if (uploadState.status == FilesystemUploadStatus.completed) {
            unawaited(_applyBackground());
          } else if (uploadState.status == FilesystemUploadStatus.failed) {
            state = WatchfaceBackgroundState(
              error: 'Upload failed: ${uploadState.errorMessage}',
            );
            _disableSmp();
            unawaited(_uploadSub?.cancel() ?? Future<void>.value());
          } else if (uploadState.status == FilesystemUploadStatus.cancelled) {
            state = const WatchfaceBackgroundState();
            _disableSmp();
            unawaited(_uploadSub?.cancel() ?? Future<void>.value());
          }
        });

    try {
      await _uploadService.startUpload(
        deviceId: connection.watchId,
        image: image,
      );
    } catch (e) {
      await _uploadSub?.cancel();
      _uploadSub = null;
      _disableSmp();
      state = WatchfaceBackgroundState(error: 'Upload failed to start: $e');
    }
  }

  void _disableSmp() {
    try {
      final watchService = _ref.read(watchServiceProvider);
      unawaited(
        watchService.disableSmpIfConnectionUnchanged(_smpConnectionGeneration),
      );
    } catch (e) {
      debugPrint('[WatchfaceBackground] Failed to disable SMP: $e');
    }
  }

  Future<void> _applyBackground() async {
    await _uploadSub?.cancel();
    state = const WatchfaceBackgroundState(isApplying: true);

    try {
      final watchService = _ref.read(watchServiceProvider);
      final result = await watchService.applyWatchfaceBackground();
      if (result['ok'] != true) {
        state = WatchfaceBackgroundState(
          error: 'Apply failed: ${_resultError(result)}',
        );
        return;
      }

      state = const WatchfaceBackgroundState(
        successMessage: 'Background applied!',
      );
    } catch (e) {
      state = WatchfaceBackgroundState(error: 'Apply failed: $e');
    } finally {
      _disableSmp();
    }
  }

  String _resultError(Map<String, dynamic> result) {
    final error = result['error'] as String?;
    final rc = result['rc'];
    if (error == null || error.isEmpty) {
      return rc == null ? 'unknown error' : 'error $rc';
    }
    return rc == null ? error : '$error ($rc)';
  }

  void clearMessages() {
    state = const WatchfaceBackgroundState();
  }

  @override
  void dispose() {
    unawaited(_uploadSub?.cancel() ?? Future<void>.value());
    super.dispose();
  }
}

/// Provider for the watchface background notifier
final watchfaceBackgroundProvider =
    StateNotifierProvider<
      WatchfaceBackgroundNotifier,
      WatchfaceBackgroundState
    >((ref) {
      final uploadService = ref.watch(filesystemUploadServiceProvider);
      return WatchfaceBackgroundNotifier(uploadService, ref);
    });
