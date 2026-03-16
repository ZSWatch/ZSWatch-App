import 'package:freezed_annotation/freezed_annotation.dart';

part 'firmware_image.freezed.dart';

/// Represents a firmware image prepared for upload
///
/// This model holds metadata about firmware files that can be uploaded
/// to the watch via MCUmgr/SMP protocol.
@freezed
abstract class FirmwareImage with _$FirmwareImage {
  const FirmwareImage._();

  const factory FirmwareImage({
    /// Display name for the firmware
    required String name,

    /// Firmware version string (e.g., "3.0.0", "v3.0.0-rc1")
    String? version,

    /// Local file path where the firmware is stored
    required String filePath,

    /// File size in bytes
    required int size,

    /// MCUmgr image slot from manifest.json (0=app internal, 1=netCore, 2=app external)
    int? slot,

    /// Board identifier from manifest.json (e.g., "watchdk" or "watchdk@1/nrf5340/cpunet")
    String? board,

    /// SHA256 hash of the file (optional, for verification)
    String? hash,

    /// When the firmware was downloaded (null for local files)
    DateTime? downloadedAt,

    /// Source URL if downloaded from GitHub
    String? sourceUrl,

    /// Git branch or tag name
    String? branch,
  }) = _FirmwareImage;

  /// Create a firmware image from a local file
  factory FirmwareImage.fromLocalFile({
    required String name,
    required String filePath,
    required int size,
    String? version,
    int? slot,
    String? board,
  }) {
    return FirmwareImage(
      name: name,
      version: version,
      filePath: filePath,
      size: size,
      slot: slot,
      board: board,
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
    String? board,
  }) {
    return FirmwareImage(
      name: name,
      version: version,
      filePath: filePath,
      size: size,
      slot: slot,
      board: board,
      hash: hash,
      downloadedAt: DateTime.now(),
      sourceUrl: sourceUrl,
      branch: branch,
    );
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
  bool get isCombined => filePath.toLowerCase().endsWith('.zip');

  /// Human-readable display name derived from manifest data
  String get displayName {
    // Combined zip packages
    if (isCombined) {
      return 'Combined Update';
    }

    // Use manifest data if available
    if (slot != null || board != null) {
      // image_index 1 is always netCore (network processor)
      if (slot == 1) {
        return 'Network Core';
      }

      // Check board field for netCore indicator
      if (board?.toLowerCase().contains('cpunet') ?? false) {
        return 'Network Core';
      }

      // image_index 0 and 2 are application (main app and external app)
      if (slot == 0) {
        return 'Application (Internal)';
      } else if (slot == 2) {
        return 'Application (External)';
      }

      return 'Application';
    }

    // Fallback: guess from filename (for local files without manifest)
    final lowerPath = filePath.toLowerCase();
    if (lowerPath.contains('net_core') ||
        lowerPath.contains('netcore') ||
        lowerPath.contains('hci_ipc') ||
        lowerPath.contains('ipc_radio')) {
      return 'Network Core';
    } else if (lowerPath.contains('littlefs') ||
        lowerPath.contains('filesystem')) {
      return 'Filesystem';
    }

    return 'Application';
  }

  /// Whether this is from GitHub
  bool get isFromGitHub => sourceUrl != null;

  /// File extension
  String get extension {
    final dotIndex = filePath.lastIndexOf('.');
    if (dotIndex == -1) return '';
    return filePath.substring(dotIndex + 1).toLowerCase();
  }
}

/// Represents a single firmware asset in a GitHub release
@freezed
abstract class ReleaseAsset with _$ReleaseAsset {
  const ReleaseAsset._();

  const factory ReleaseAsset({
    /// Asset file name (e.g., "watchdk@1_nrf5340_cpuapp_debug.zip")
    required String name,

    /// Download URL
    required String downloadUrl,

    /// File size in bytes
    required int size,
  }) = _ReleaseAsset;

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
}

/// Represents a GitHub release with available firmware
@freezed
abstract class GitHubRelease with _$GitHubRelease {
  const GitHubRelease._();

  const factory GitHubRelease({
    /// Release tag name (e.g., "v3.0.0")
    required String tagName,

    /// Release title
    required String name,

    /// Release description/body
    String? body,

    /// Whether this is a prerelease
    required bool isPrerelease,

    /// When the release was published
    required DateTime publishedAt,

    /// All available firmware assets in this release
    required List<ReleaseAsset> assets,
  }) = _GitHubRelease;

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
}

/// Represents a GitHub Actions workflow artifact
@freezed
abstract class GitHubArtifact with _$GitHubArtifact {
  const GitHubArtifact._();

  const factory GitHubArtifact({
    /// Branch name
    required String branch,

    /// Workflow run ID
    required String runId,

    /// Artifact name
    required String name,

    /// Artifact size in bytes
    required int size,

    /// When the artifact was created
    required DateTime createdAt,

    /// Download URL (requires authentication)
    required String downloadUrl,

    /// Commit SHA
    String? commitSha,

    /// Commit message
    String? commitMessage,
  }) = _GitHubArtifact;

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
}
