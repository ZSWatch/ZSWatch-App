import 'package:equatable/equatable.dart';

/// Types of firmware images for ZSWatch DFU
enum FirmwareImageType {
  /// Main application firmware
  appCore,

  /// Network processor firmware (nRF5340)
  netCore,

  /// LittleFS filesystem image
  filesystem,

  /// Combined zip containing multiple images
  combined,
}

/// Extension methods for FirmwareImageType
extension FirmwareImageTypeExtension on FirmwareImageType {
  /// Human-readable name
  String get displayName {
    switch (this) {
      case FirmwareImageType.appCore:
        return 'Application';
      case FirmwareImageType.netCore:
        return 'Network Core';
      case FirmwareImageType.filesystem:
        return 'Filesystem';
      case FirmwareImageType.combined:
        return 'Combined Update';
    }
  }

  /// Short description
  String get description {
    switch (this) {
      case FirmwareImageType.appCore:
        return 'Main application firmware';
      case FirmwareImageType.netCore:
        return 'Bluetooth network processor';
      case FirmwareImageType.filesystem:
        return 'LittleFS filesystem image';
      case FirmwareImageType.combined:
        return 'Multi-image update package';
    }
  }
}

/// Represents a firmware image prepared for upload
///
/// This model holds metadata about firmware files that can be uploaded
/// to the watch via MCUmgr/SMP protocol.
class FirmwareImage extends Equatable {
  /// Display name for the firmware
  final String name;

  /// Firmware version string (e.g., "3.0.0", "v3.0.0-rc1")
  final String? version;

  /// Type of firmware image
  final FirmwareImageType type;

  /// Local file path where the firmware is stored
  final String filePath;

  /// File size in bytes
  final int size;

  /// MCUmgr image slot (0=app, 1=net, 2=external)
  final int? slot;

  /// SHA256 hash of the file (optional, for verification)
  final String? hash;

  /// When the firmware was downloaded (null for local files)
  final DateTime? downloadedAt;

  /// Source URL if downloaded from GitHub
  final String? sourceUrl;

  /// Git branch or tag name
  final String? branch;

  const FirmwareImage({
    required this.name,
    this.version,
    required this.type,
    required this.filePath,
    required this.size,
    this.slot,
    this.hash,
    this.downloadedAt,
    this.sourceUrl,
    this.branch,
  });

  /// Create a firmware image from a local file
  factory FirmwareImage.fromLocalFile({
    required String name,
    required String filePath,
    required int size,
    String? version,
    int? slot,
    String? board,
  }) {
    // Prefer manifest data (slot/image_index and board) if available
    final type = slot != null || board != null
        ? _determineTypeFromManifest(imageIndex: slot, board: board)
        : _determineTypeFromPath(filePath);

    return FirmwareImage(
      name: name,
      version: version,
      type: type,
      filePath: filePath,
      size: size,
      slot: slot,
    );
  }

  /// Create a firmware image from a GitHub download
  factory FirmwareImage.fromGitHub({
    required String name,
    required String version,
    required String filePath,
    required int size,
    required String sourceUrl,
    required String branch,
    String? hash,
    int? slot,
  }) {
    final type = _determineTypeFromPath(filePath);

    return FirmwareImage(
      name: name,
      version: version,
      type: type,
      filePath: filePath,
      size: size,
      slot: slot,
      hash: hash,
      downloadedAt: DateTime.now(),
      sourceUrl: sourceUrl,
      branch: branch,
    );
  }

  /// Determine type from manifest data (image_index and board)
  static FirmwareImageType _determineTypeFromManifest({
    int? imageIndex,
    String? board,
  }) {
    // image_index 1 is always netCore (network processor)
    if (imageIndex == 1) {
      return FirmwareImageType.netCore;
    }
    
    // Check board field for netCore indicator
    if (board != null && board.toLowerCase().contains('cpunet')) {
      return FirmwareImageType.netCore;
    }
    
    // image_index 0 and 2 are appCore (main app and external app)
    return FirmwareImageType.appCore;
  }

  static FirmwareImageType _determineTypeFromPath(String path) {
    final lowerPath = path.toLowerCase();
    if (lowerPath.endsWith('.zip')) {
      return FirmwareImageType.combined;
    } else if (lowerPath.contains('net_core') ||
        lowerPath.contains('netcore') ||
        lowerPath.contains('hci_ipc')) {
      return FirmwareImageType.netCore;
    } else if (lowerPath.contains('littlefs') ||
        lowerPath.contains('filesystem')) {
      return FirmwareImageType.filesystem;
    }
    return FirmwareImageType.appCore;
  }

  /// Human-readable file size
  String get formattedSize {
    if (size < 1024) {
      return '$size B';
    } else if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(size / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
  }

  /// Whether this is a combined/zip package
  bool get isCombined => type == FirmwareImageType.combined;

  /// Whether this is from GitHub
  bool get isFromGitHub => sourceUrl != null;

  /// File extension
  String get extension {
    final dotIndex = filePath.lastIndexOf('.');
    if (dotIndex == -1) return '';
    return filePath.substring(dotIndex + 1).toLowerCase();
  }

  /// Copy with modified fields
  FirmwareImage copyWith({
    String? name,
    String? version,
    FirmwareImageType? type,
    String? filePath,
    int? size,
    int? slot,
    String? hash,
    DateTime? downloadedAt,
    String? sourceUrl,
    String? branch,
  }) {
    return FirmwareImage(
      name: name ?? this.name,
      version: version ?? this.version,
      type: type ?? this.type,
      filePath: filePath ?? this.filePath,
      size: size ?? this.size,
      slot: slot ?? this.slot,
      hash: hash ?? this.hash,
      downloadedAt: downloadedAt ?? this.downloadedAt,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      branch: branch ?? this.branch,
    );
  }

  @override
  List<Object?> get props => [
        name,
        version,
        type,
        filePath,
        size,
        slot,
        hash,
        downloadedAt,
        sourceUrl,
        branch,
      ];

  @override
  String toString() {
    return 'FirmwareImage(name: $name, slot: $slot, version: $version, type: ${type.displayName}, size: $formattedSize)';
  }
}

/// Represents a single firmware asset in a GitHub release
class ReleaseAsset extends Equatable {
  /// Asset file name (e.g., "watchdk@1_nrf5340_cpuapp_debug.zip")
  final String name;

  /// Download URL
  final String downloadUrl;

  /// File size in bytes
  final int size;

  const ReleaseAsset({
    required this.name,
    required this.downloadUrl,
    required this.size,
  });

  /// Human-readable file size
  String get formattedSize {
    if (size < 1024) {
      return '$size B';
    } else if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(size / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
  }

  /// Display name - just the filename without .zip extension
  String get displayName {
    if (name.toLowerCase().endsWith('.zip')) {
      return name.substring(0, name.length - 4);
    }
    return name;
  }

  @override
  List<Object?> get props => [name, downloadUrl, size];
}

/// Represents a GitHub release with available firmware
class GitHubRelease extends Equatable {
  /// Release tag name (e.g., "v3.0.0")
  final String tagName;

  /// Release title
  final String name;

  /// Release description/body
  final String? body;

  /// Whether this is a prerelease
  final bool isPrerelease;

  /// When the release was published
  final DateTime publishedAt;

  /// All available firmware assets in this release
  final List<ReleaseAsset> assets;

  const GitHubRelease({
    required this.tagName,
    required this.name,
    this.body,
    required this.isPrerelease,
    required this.publishedAt,
    required this.assets,
  });

  /// Version string without 'v' prefix
  String get version {
    if (tagName.startsWith('v') || tagName.startsWith('V')) {
      return tagName.substring(1);
    }
    return tagName;
  }

  /// Formatted date
  String get formattedDate {
    return '${publishedAt.day}/${publishedAt.month}/${publishedAt.year}';
  }

  /// Whether this release has any firmware assets
  bool get hasFirmware => assets.isNotEmpty;

  @override
  List<Object?> get props => [
        tagName,
        name,
        body,
        isPrerelease,
        publishedAt,
        assets,
      ];
}

/// Represents a GitHub Actions workflow artifact
class GitHubArtifact extends Equatable {
  /// Branch name
  final String branch;

  /// Workflow run ID
  final String runId;

  /// Artifact name
  final String name;

  /// Artifact size in bytes
  final int size;

  /// When the artifact was created
  final DateTime createdAt;

  /// Download URL (requires authentication)
  final String downloadUrl;

  /// Commit SHA
  final String? commitSha;

  /// Commit message
  final String? commitMessage;

  const GitHubArtifact({
    required this.branch,
    required this.runId,
    required this.name,
    required this.size,
    required this.createdAt,
    required this.downloadUrl,
    this.commitSha,
    this.commitMessage,
  });

  /// Short commit SHA (first 7 chars)
  String get shortSha => commitSha?.substring(0, 7) ?? '';

  /// Human-readable file size
  String get formattedSize {
    if (size < 1024) {
      return '$size B';
    } else if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(size / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
  }

  /// Formatted date
  String get formattedDate {
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }

  @override
  List<Object?> get props => [
        branch,
        runId,
        name,
        size,
        createdAt,
        downloadUrl,
        commitSha,
        commitMessage,
      ];
}

