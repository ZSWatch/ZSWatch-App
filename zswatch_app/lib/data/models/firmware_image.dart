import 'package:equatable/equatable.dart';

/// Represents a firmware image prepared for upload
///
/// This model holds metadata about firmware files that can be uploaded
/// to the watch via MCUmgr/SMP protocol.
class FirmwareImage extends Equatable {
  /// Display name for the firmware
  final String name;

  /// Firmware version string (e.g., "3.0.0", "v3.0.0-rc1")
  final String? version;

  /// Local file path where the firmware is stored
  final String filePath;

  /// File size in bytes
  final int size;

  /// MCUmgr image slot from manifest.json (0=app internal, 1=netCore, 2=app external)
  final int? slot;

  /// Board identifier from manifest.json (e.g., "watchdk" or "watchdk@1/nrf5340/cpunet")
  final String? board;

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
    required this.filePath,
    required this.size,
    this.slot,
    this.board,
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

  /// Copy with modified fields
  FirmwareImage copyWith({
    String? name,
    String? version,
    String? filePath,
    int? size,
    int? slot,
    String? board,
    String? hash,
    DateTime? downloadedAt,
    String? sourceUrl,
    String? branch,
  }) {
    return FirmwareImage(
      name: name ?? this.name,
      version: version ?? this.version,
      filePath: filePath ?? this.filePath,
      size: size ?? this.size,
      slot: slot ?? this.slot,
      board: board ?? this.board,
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
        filePath,
        size,
        slot,
        board,
        hash,
        downloadedAt,
        sourceUrl,
        branch,
      ];

  @override
  String toString() {
    return 'FirmwareImage(name: $name, slot: $slot, version: $version, type: $displayName, size: $formattedSize)';
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

