import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/watchface_image_processor.dart';
import 'companion_runtime_providers.dart';
import '../data/models/companion_watchface_status.dart';

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
  bool _localPreparing = false;
  String? _requestAddress, _lastId, _lastPhase;
  final Ref _ref;

  WatchfaceBackgroundNotifier(this._ref)
    : super(const WatchfaceBackgroundState());

  bool _beginNative() {
    if (state.isUploading || state.isApplying) return false;
    final snapshot = _ref.read(companionSnapshotProvider).valueOrNull;
    if (snapshot?.protocolReady != true) {
      state = const WatchfaceBackgroundState(error: 'Watch not connected');
      return false;
    }
    _requestAddress = snapshot!.fields['address'] as String;
    _localPreparing = true;
    return true;
  }

  void observeNative(
    CompanionWatchfaceStatus? status,
    String? selectedAddress,
  ) {
    if (!mounted || status == null || status.address != selectedAddress) return;
    if (_localPreparing && status.id == _lastId) return;
    if (status.id == _lastId && status.phase == _lastPhase) return;
    final initial = _lastId == null;
    _lastId = status.id;
    _lastPhase = status.phase;
    // The first delivered snapshot can be terminal after Home/background.
    // Only suppress an old terminal result when this UI has no submitted work.
    if (initial &&
        !status.busy &&
        !_localPreparing &&
        !state.isUploading &&
        !state.isApplying) {
      return;
    }
    _localPreparing = false;
    state = WatchfaceBackgroundState(
      isUploading: status.uploading,
      isApplying: status.phase == 'applying' || status.phase == 'resetting',
      successMessage: status.phase == 'completed'
          ? status.action == 'reset'
                ? 'Background reset to default'
                : 'Background applied!'
          : null,
      error: status.phase == 'failed'
          ? status.applicationUncertain
                ? 'The background result is unknown. Reconnect before retrying.'
                : 'Background update failed. Retry when the watch is connected.'
          : null,
    );
  }

  /// Upload a built-in background to the watch
  Future<void> uploadBuiltin(BuiltinBackground bg) async {
    if (!_beginNative()) return;
    try {
      state = const WatchfaceBackgroundState(isUploading: true);

      final data = await rootBundle.load(bg.assetBinPath);
      await _startNativeUpload(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        bg.name,
      );
    } catch (e) {
      _localPreparing = false;
      if (mounted) {
        state = WatchfaceBackgroundState(error: 'Failed: $e');
      }
    }
  }

  /// Upload a custom image (from gallery) to the watch
  Future<void> uploadCustomImage(String imagePath) async {
    if (!_beginNative()) return;
    try {
      state = const WatchfaceBackgroundState(isUploading: true);

      final bytes = await File(imagePath).readAsBytes();
      await _startNativeUpload(
        WatchfaceImageProcessor.processImageBytes(bytes),
        'Custom Background',
      );
    } catch (e) {
      _localPreparing = false;
      if (mounted) {
        state = WatchfaceBackgroundState(error: 'Failed to process image: $e');
      }
    }
  }

  /// Upload pre-cropped image bytes (from interactive crop UI) to the watch
  Future<void> uploadCroppedImage(Uint8List imageBytes) async {
    if (!_beginNative()) return;
    try {
      state = const WatchfaceBackgroundState(isUploading: true);

      final bin = WatchfaceImageProcessor.processImageBytes(imageBytes);
      await _startNativeUpload(bin, 'Custom Background');
    } catch (e) {
      _localPreparing = false;
      if (mounted) {
        state = WatchfaceBackgroundState(error: 'Failed to process image: $e');
      }
    }
  }

  /// Reset to the default compiled-in background
  Future<void> resetToDefault() async {
    if (!_beginNative()) return;
    try {
      state = const WatchfaceBackgroundState(isApplying: true);

      final snapshot = _ref.read(companionSnapshotProvider).requireValue;
      final client = _ref.read(companionClientProvider);
      await client.resetWatchface(snapshot.generation);
      _localPreparing = false;
    } catch (e) {
      _localPreparing = false;
      if (mounted) {
        state = WatchfaceBackgroundState(error: 'Reset failed: $e');
      }
    }
  }

  Future<void> _startNativeUpload(Uint8List data, String name) async {
    if (!mounted) return;
    CompanionWatchfaceStatus.validateImage(data);
    final snapshot = _ref.read(companionSnapshotProvider).requireValue;
    if (!snapshot.protocolReady ||
        snapshot.fields['address'] != _requestAddress) {
      throw StateError('Watch connection changed');
    }
    final client = _ref.read(companionClientProvider);
    final generation = await client.prepareShell(snapshot.generation);
    if (!mounted) return; // The service has not accepted the image yet.
    await client.startWatchface(generation, data, name);
    _localPreparing = false;
  }

  void clearMessages() {
    state = state.copyWith(error: null, successMessage: null);
  }
}

/// Provider for the watchface background notifier
final watchfaceBackgroundProvider =
    StateNotifierProvider<
      WatchfaceBackgroundNotifier,
      WatchfaceBackgroundState
    >((ref) {
      final notifier = WatchfaceBackgroundNotifier(ref);
      ref.listen(companionWatchfaceStatusProvider, (_, next) {
        notifier.observeNative(
          next.valueOrNull,
          ref.read(companionSnapshotProvider).valueOrNull?.fields['address']
              as String?,
        );
      }, fireImmediately: true);
      return notifier;
    });
