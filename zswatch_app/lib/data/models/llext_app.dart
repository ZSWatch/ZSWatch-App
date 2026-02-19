/// Represents a known LLEXT app that ships bundled with the companion app.
///
/// Each [LlextAppDefinition] describes one optional watch app that can be
/// installed to / uninstalled from the watch over BLE (MCUmgr filesystem).
class LlextAppDefinition {
  /// Unique filesystem-safe identifier — matches the directory name on watch.
  final String id;

  /// Human-readable display name.
  final String name;

  /// Short description shown in the app list.
  final String description;

  /// Category tag for grouping (e.g. 'tools', 'system', 'fitness').
  final String category;

  /// Flutter asset path for the bundled .llext binary.
  final String assetPath;

  /// Absolute path on the watch filesystem where the .llext should be placed.
  final String watchPath;

  const LlextAppDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.assetPath,
    required this.watchPath,
  });
}

/// The set of LLEXT apps bundled into this build of the companion app.
///
/// These are the two apps currently compiled and embedded as assets. Future
/// builds can extend this list as more LLEXT apps are created.
const List<LlextAppDefinition> kBundledLlextApps = [
  LlextAppDefinition(
    id: 'battery_ext',
    name: 'Battery',
    description: 'Detailed battery statistics including voltage history chart '
        'and charge cycle information.',
    category: 'tools',
    assetPath: 'assets/llext_apps/battery_ext/app.llext',
    watchPath: '/lvgl_lfs/apps/battery_ext/app.llext',
  ),
  LlextAppDefinition(
    id: 'about_ext',
    name: 'About',
    description: 'Displays firmware version, build date, and hardware revision '
        'information about the watch.',
    category: 'system',
    assetPath: 'assets/llext_apps/about_ext/app.llext',
    watchPath: '/lvgl_lfs/apps/about_ext/app.llext',
  ),
  LlextAppDefinition(
    id: 'compass_ext',
    name: 'Compass',
    description: 'Digital compass using the magnetometer sensor with heading '
        'display and calibration.',
    category: 'tools',
    assetPath: 'assets/llext_apps/compass_ext/app.llext',
    watchPath: '/lvgl_lfs/apps/compass_ext/app.llext',
  ),
  LlextAppDefinition(
    id: 'weather_ext',
    name: 'Weather',
    description: 'Current weather conditions and forecast synced from the '
        'companion app via BLE.',
    category: 'tools',
    assetPath: 'assets/llext_apps/weather_ext/app.llext',
    watchPath: '/lvgl_lfs/apps/weather_ext/app.llext',
  ),
  LlextAppDefinition(
    id: 'qr_code_ext',
    name: 'QR Code',
    description: 'Displays a QR code on the watch screen for quick sharing.',
    category: 'tools',
    assetPath: 'assets/llext_apps/qr_code_ext/app.llext',
    watchPath: '/lvgl_lfs/apps/qr_code_ext/app.llext',
  ),
  LlextAppDefinition(
    id: 'trivia_ext',
    name: 'Trivia',
    description: 'Fun trivia quiz game with questions fetched via the '
        'companion app.',
    category: 'games',
    assetPath: 'assets/llext_apps/trivia_ext/app.llext',
    watchPath: '/lvgl_lfs/apps/trivia_ext/app.llext',
  ),
  LlextAppDefinition(
    id: 'calculator_ext',
    name: 'Calculator',
    description: 'Basic calculator with arithmetic operations.',
    category: 'tools',
    assetPath: 'assets/llext_apps/calculator_ext/app.llext',
    watchPath: '/lvgl_lfs/apps/calculator_ext/app.llext',
  ),
];

/// Runtime state of a single LLEXT app.
class LlextAppState {
  final LlextAppDefinition definition;

  /// Whether the app ELF file is present on the watch filesystem.
  final bool isInstalled;

  /// Size in bytes of the on-watch file, or null if not installed.
  final int? watchFileSizeBytes;

  /// True while an install upload is in progress for this app.
  final bool isInstalling;

  const LlextAppState({
    required this.definition,
    required this.isInstalled,
    this.watchFileSizeBytes,
    this.isInstalling = false,
  });

  LlextAppState copyWith({
    bool? isInstalled,
    int? watchFileSizeBytes,
    bool? isInstalling,
    bool clearWatchFileSize = false,
  }) {
    return LlextAppState(
      definition: definition,
      isInstalled: isInstalled ?? this.isInstalled,
      watchFileSizeBytes:
          clearWatchFileSize ? null : (watchFileSizeBytes ?? this.watchFileSizeBytes),
      isInstalling: isInstalling ?? this.isInstalling,
    );
  }
}
