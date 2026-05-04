// ignore_for_file: avoid_slow_async_io
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:rxdart/rxdart.dart';

import '../../core/constants/filesystem_constants.dart';
import '../../data/models/filesystem_image.dart';
import '../../data/models/firmware_image.dart';

/// Manages firmware downloads from GitHub and local file handling
///
/// Handles:
/// - Fetching available releases from GitHub
/// - Fetching CI builds from GitHub Actions
/// - Downloading firmware artifacts
/// - Extracting zip files containing multiple images
/// - Managing single .bin files
class FirmwareManager {
  static const String _owner = 'ZSWatch';
  static const String _repo = 'ZSWatch';
  static const String _apiBase = 'https://api.github.com';

  /// Artifact name filters to match ZSWatch firmware artifacts
  static const List<String> _artifactFilters = ['watchdk@1', 'zswatch@1', '@5'];

  /// Whether to use the rotated firmware variant (dfu_application_rotated.zip)
  bool useRotatedFirmware = false;

  /// Extract the board prefix from a hardware version string.
  ///
  /// The watch reports hardware as e.g. `watchdk@1/nrf5340/cpuapp`.
  /// The board prefix is `watchdk@1` — the part before the first `/`.
  /// This matches the prefix used in release asset and CI artifact names
  /// (e.g. `watchdk@1_nrf5340_cpuapp_debug.zip`).
  ///
  /// Returns null if [hardwareVersion] is null or empty.
  static String? boardPrefixFromHardwareVersion(String? hardwareVersion) {
    if (hardwareVersion == null || hardwareVersion.isEmpty) return null;
    final slashIndex = hardwareVersion.indexOf('/');
    if (slashIndex == -1) return hardwareVersion;
    return hardwareVersion.substring(0, slashIndex);
  }

  /// Check whether a release asset name is compatible with the given board prefix.
  ///
  /// If [boardPrefix] is null the asset is always considered compatible.
  static bool isAssetCompatible(String assetName, String? boardPrefix) {
    if (boardPrefix == null) return true;
    return assetName.contains(boardPrefix);
  }

  /// Filter release assets to keep only those compatible with [boardPrefix].
  ///
  /// If [boardPrefix] is null or no assets match, returns all assets unfiltered.
  static List<ReleaseAsset> filterCompatibleAssets(
    List<ReleaseAsset> assets,
    String? boardPrefix,
  ) {
    if (boardPrefix == null) return assets;
    final compatible = assets
        .where((a) => isAssetCompatible(a.name, boardPrefix))
        .toList();
    return compatible.isNotEmpty ? compatible : assets;
  }

  /// Filter workflow artifacts to keep only those compatible with [boardPrefix].
  ///
  /// If [boardPrefix] is null or no artifacts match, returns all artifacts unfiltered.
  static List<WorkflowArtifact> filterCompatibleArtifacts(
    List<WorkflowArtifact> artifacts,
    String? boardPrefix,
  ) {
    if (boardPrefix == null) return artifacts;
    final compatible = artifacts
        .where((a) => a.name.contains(boardPrefix))
        .toList();
    return compatible.isNotEmpty ? compatible : artifacts;
  }

  final _downloadProgressController = BehaviorSubject<DownloadProgress>.seeded(
    const DownloadProgress(0, 0, DownloadStatus.idle),
  );
  final _logController = StreamController<String>.broadcast();

  http.Client? _httpClient;
  bool _cancelDownload = false;

  /// Stream of download progress
  Stream<DownloadProgress> get downloadProgressStream =>
      _downloadProgressController.stream;

  /// Current download progress
  DownloadProgress get currentProgress => _downloadProgressController.value;

  /// Stream of log messages
  Stream<String> get logStream => _logController.stream;

  /// Fetch available releases from GitHub
  Future<List<GitHubRelease>> fetchReleases({int limit = 10}) async {
    _log('Fetching releases from GitHub...');

    try {
      final response = await http.get(
        Uri.parse('$_apiBase/repos/$_owner/$_repo/releases?per_page=$limit'),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );

      if (response.statusCode != 200) {
        throw FirmwareDownloadException(
          'Failed to fetch releases: ${response.statusCode}',
        );
      }

      final data = jsonDecode(response.body) as List<dynamic>;
      final releases = <GitHubRelease>[];

      for (final release in data) {
        final Map<String, dynamic> releaseMap = release as Map<String, dynamic>;
        final assets = releaseMap['assets'] as List<dynamic>? ?? [];

        // Collect all firmware assets for this release
        final releaseAssets = <ReleaseAsset>[];
        for (final asset in assets) {
          final Map<String, dynamic> assetMap = asset as Map<String, dynamic>;
          final assetName = assetMap['name'] as String? ?? '';
          if (_isFirmwareAsset(assetName)) {
            releaseAssets.add(
              ReleaseAsset(
                name: assetName,
                downloadUrl: assetMap['browser_download_url'] as String,
                size: assetMap['size'] as int? ?? 0,
              ),
            );
          }
        }

        if (releaseAssets.isNotEmpty) {
          releases.add(
            GitHubRelease(
              tagName: releaseMap['tag_name'] as String? ?? '',
              name:
                  releaseMap['name'] as String? ??
                  releaseMap['tag_name'] as String? ??
                  '',
              body: releaseMap['body'] as String?,
              isPrerelease: releaseMap['prerelease'] as bool? ?? false,
              publishedAt: DateTime.parse(releaseMap['published_at'] as String),
              assets: releaseAssets,
            ),
          );
        }
      }

      _log('Found ${releases.length} releases with firmware');
      return releases;
    } catch (e) {
      _log('Error fetching releases: $e');
      rethrow;
    }
  }

  /// Fetch workflow runs with artifacts from GitHub Actions
  ///
  /// Similar to the website implementation, this fetches recent successful builds
  /// and prioritizes the main branch.
  Future<List<WorkflowRun>> fetchWorkflowRuns({int numRuns = 10}) async {
    _log('Fetching workflow runs from GitHub Actions...');

    try {
      // Fetch a large window so that non-firmware runs (security scans, etc.)
      // don't crowd out actual firmware builds from different branches.
      final responses = await Future.wait([
        http.get(
          Uri.parse('$_apiBase/repos/$_owner/$_repo/actions/runs?per_page=50'),
          headers: {'Accept': 'application/vnd.github.v3+json'},
        ),
        http.get(
          Uri.parse(
            '$_apiBase/repos/$_owner/$_repo/actions/runs?branch=main&status=success&per_page=1',
          ),
          headers: {'Accept': 'application/vnd.github.v3+json'},
        ),
      ]);

      final runsResponse = responses[0];
      final mainRunResponse = responses[1];

      if (runsResponse.statusCode != 200) {
        throw FirmwareDownloadException(
          'Failed to fetch workflow runs: ${runsResponse.statusCode}',
        );
      }

      final runsData = jsonDecode(runsResponse.body) as Map<String, dynamic>;
      final mainRunData =
          jsonDecode(mainRunResponse.body) as Map<String, dynamic>;

      final workflowRuns = (runsData['workflow_runs'] as List<dynamic>?) ?? [];
      final mainBranchRuns =
          (mainRunData['workflow_runs'] as List<dynamic>?) ?? [];

      if (workflowRuns.isEmpty && mainBranchRuns.isEmpty) {
        _log('No workflow runs found');
        return [];
      }

      _log('Found ${workflowRuns.length} workflow runs');

      // Filter for successful runs, excluding gh-pages
      final successfulRuns = workflowRuns
          .map((r) => r as Map<String, dynamic>)
          .where(
            (run) =>
                run['conclusion'] == 'success' &&
                run['head_branch'] != 'gh-pages',
          )
          .toList();

      // Find latest main run
      final latestMainRun = mainBranchRuns
          .map((r) => r as Map<String, dynamic>)
          .where((run) => run['conclusion'] == 'success')
          .firstOrNull;

      // Ensure main is present by prepending it before trimming
      final List<Map<String, dynamic>> runsWithMain = [
        if (latestMainRun != null) latestMainRun,
        ...successfulRuns,
      ];

      // Keep only the latest run per branch (runs are already sorted newest-first).
      // Deduplicating by branch ensures feature branches aren't crowded out by
      // multiple main-branch runs filling up the numRuns limit.
      final seenBranches = <String>{};
      final uniqueRuns = runsWithMain
          .where((run) {
            final branch = run['head_branch'] as String? ?? '';
            if (seenBranches.contains(branch)) return false;
            seenBranches.add(branch);
            return true;
          })
          .take(numRuns)
          .toList();

      _log('Fetching artifacts from ${uniqueRuns.length} workflow runs...');

      // Fetch artifacts for each run
      final runs = <WorkflowRun>[];
      for (final run in uniqueRuns) {
        final runId = run['id'] as int;
        final artifacts = await _fetchArtifactsForRun(runId);

        // Filter artifacts to match ZSWatch firmware
        final filteredArtifacts = artifacts.where((artifact) {
          return _artifactFilters.any(
            (filter) => artifact.name.contains(filter),
          );
        }).toList();

        if (filteredArtifacts.isEmpty) {
          _log('No matching artifacts for run $runId');
          continue;
        }

        final headCommit = run['head_commit'] as Map<String, dynamic>?;
        runs.add(
          WorkflowRun(
            id: runId,
            branch: run['head_branch'] as String? ?? 'unknown',
            user:
                (run['actor'] as Map<String, dynamic>?)?['login'] as String? ??
                'unknown',
            commitSha:
                run['head_sha'] as String? ??
                headCommit?['id'] as String? ??
                '',
            commitMessage:
                headCommit?['message'] as String? ??
                run['display_title'] as String? ??
                '',
            createdAt: DateTime.parse(run['created_at'] as String),
            artifacts: filteredArtifacts,
          ),
        );
      }

      _log('Found ${runs.length} runs with firmware artifacts');
      return runs;
    } catch (e) {
      _log('Error fetching workflow runs: $e');
      rethrow;
    }
  }

  /// Fetch artifacts for a specific workflow run
  Future<List<WorkflowArtifact>> _fetchArtifactsForRun(int runId) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$_apiBase/repos/$_owner/$_repo/actions/runs/$runId/artifacts',
        ),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );

      if (response.statusCode != 200) {
        _log(
          'Failed to fetch artifacts for run $runId: ${response.statusCode}',
        );
        return [];
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final artifacts = (data['artifacts'] as List<dynamic>?) ?? [];

      debugPrint(
        '[FirmwareManager] Found ${artifacts.length} artifacts for run $runId',
      );

      return artifacts
          .map((a) {
            final artifact = a as Map<String, dynamic>;
            debugPrint('[FirmwareManager] Artifact: ${artifact['name']}');
            debugPrint('[FirmwareManager]   ID: ${artifact['id']}');
            debugPrint(
              '[FirmwareManager]   Size: ${artifact['size_in_bytes']}',
            );
            debugPrint('[FirmwareManager]   Expired: ${artifact['expired']}');
            debugPrint(
              '[FirmwareManager]   archive_download_url: ${artifact['archive_download_url']}',
            );

            return WorkflowArtifact(
              id: artifact['id'] as int,
              name: artifact['name'] as String? ?? 'unknown',
              sizeInBytes: artifact['size_in_bytes'] as int? ?? 0,
              createdAt: DateTime.parse(artifact['created_at'] as String),
              expired: artifact['expired'] as bool? ?? false,
              archiveDownloadUrl: artifact['archive_download_url'] as String?,
            );
          })
          .where((a) => !a.expired)
          .toList();
    } catch (e) {
      _log('Error fetching artifacts for run $runId: $e');
      return [];
    }
  }

  /// Download firmware from a GitHub Actions artifact
  ///
  /// Uses the same URL format as the website:
  /// https://github.com/{owner}/{repo}/actions/runs/{runId}/artifacts/{artifactId}
  /// This triggers GitHub's download mechanism which works for public repos.
  Future<ReleaseExtractionResult> downloadArtifact(
    WorkflowRun run,
    WorkflowArtifact artifact,
  ) async {
    debugPrint('[FirmwareManager] downloadArtifact called');
    debugPrint(
      '[FirmwareManager] Artifact: ${artifact.name}, ID: ${artifact.id}',
    );
    debugPrint('[FirmwareManager] Run ID: ${run.id}, Branch: ${run.branch}');
    debugPrint(
      '[FirmwareManager] Archive Download URL from API: ${artifact.archiveDownloadUrl}',
    );

    _log('Downloading artifact: ${artifact.name} from run ${run.id}');
    _cancelDownload = false;

    // Try the GitHub web UI URL format first (same as website)
    // This URL format: https://github.com/{owner}/{repo}/actions/runs/{runId}/artifacts/{artifactId}
    final webUiUrl =
        'https://github.com/$_owner/$_repo/actions/runs/${run.id}/artifacts/${artifact.id}';

    // Also have the API URL as fallback
    final apiUrl =
        artifact.archiveDownloadUrl ??
        '$_apiBase/repos/$_owner/$_repo/actions/artifacts/${artifact.id}/zip';

    debugPrint('[FirmwareManager] Web UI URL: $webUiUrl');
    debugPrint('[FirmwareManager] API URL: $apiUrl');
    _log('Web UI URL: $webUiUrl');
    _log('API URL: $apiUrl');

    // Start with web UI URL (same as website does)
    final downloadUrl = webUiUrl;

    _updateProgress(
      DownloadProgress(0, artifact.sizeInBytes, DownloadStatus.downloading),
    );

    try {
      _httpClient = http.Client();

      // Follow redirects manually to handle GitHub's redirect chain
      var currentUrl = downloadUrl;
      http.StreamedResponse? response;
      final Map<String, String> cookies = {};

      for (int redirectCount = 0; redirectCount < 15; redirectCount++) {
        debugPrint(
          '[FirmwareManager] Request #$redirectCount: GET $currentUrl',
        );
        _log('Request #$redirectCount: GET $currentUrl');

        final request = http.Request('GET', Uri.parse(currentUrl));
        // Don't follow redirects automatically so we can handle them
        request.followRedirects = false;

        // Add cookies from previous responses
        if (cookies.isNotEmpty) {
          request.headers['Cookie'] = cookies.entries
              .map((e) => '${e.key}=${e.value}')
              .join('; ');
          debugPrint(
            '[FirmwareManager] Sending cookies: ${request.headers['Cookie']}',
          );
          _log('Sending cookies: ${request.headers['Cookie']}');
        }

        // Add common browser headers
        request.headers['User-Agent'] =
            'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36';
        request.headers['Accept'] = '*/*';

        response = await _httpClient!.send(request);

        debugPrint(
          '[FirmwareManager] Response: ${response.statusCode} ${response.reasonPhrase}',
        );
        _log('Response: ${response.statusCode} ${response.reasonPhrase}');
        _log('Response headers:');
        response.headers.forEach((key, value) {
          _log('  $key: $value');
        });

        // Collect any cookies
        final setCookie = response.headers['set-cookie'];
        if (setCookie != null) {
          _log('Set-Cookie: $setCookie');
          // Parse simple cookie (just name=value)
          final cookieParts = setCookie.split(';').first.split('=');
          if (cookieParts.length >= 2) {
            cookies[cookieParts[0]] = cookieParts.sublist(1).join('=');
          }
        }

        if (response.statusCode == 200) {
          // Success - download the file
          debugPrint('[FirmwareManager] Success! Starting file download...');
          _log('Success! Starting file download...');
          final contentLength = response.headers['content-length'];
          debugPrint('[FirmwareManager] Content-Length: $contentLength');
          _log('Content-Length: $contentLength');
          break;
        } else if (response.statusCode == 302 ||
            response.statusCode == 301 ||
            response.statusCode == 307 ||
            response.statusCode == 308) {
          // Follow redirect (301, 302, 307, 308 are all redirect codes)
          final location = response.headers['location'];
          if (location == null) {
            debugPrint(
              '[FirmwareManager] ERROR: Redirect without location header!',
            );
            _log('ERROR: Redirect without location header!');
            throw FirmwareDownloadException('Redirect without location header');
          }

          // Handle relative URLs
          if (location.startsWith('/')) {
            final uri = Uri.parse(currentUrl);
            currentUrl = '${uri.scheme}://${uri.host}$location';
          } else {
            currentUrl = location;
          }

          debugPrint(
            '[FirmwareManager] Following ${response.statusCode} redirect to: $currentUrl',
          );
          _log('Following ${response.statusCode} redirect to: $currentUrl');
          // Drain the response body before following redirect
          await response.stream.drain<void>();
        } else if (response.statusCode == 404) {
          debugPrint('[FirmwareManager] ERROR: Artifact not found (404)');
          debugPrint('[FirmwareManager] URL was: $currentUrl');
          _log('ERROR: Artifact not found (404)');
          throw FirmwareDownloadException(
            'Artifact not found. It may have expired.',
          );
        } else if (response.statusCode == 401 || response.statusCode == 403) {
          debugPrint(
            '[FirmwareManager] ERROR: Authentication required (${response.statusCode})',
          );
          _log('ERROR: Authentication required (${response.statusCode})');
          throw FirmwareDownloadException(
            'Authentication required. GitHub Actions artifacts may require login.',
          );
        } else {
          debugPrint(
            '[FirmwareManager] ERROR: Unexpected status code ${response.statusCode}',
          );
          _log('ERROR: Unexpected status code ${response.statusCode}');
          throw FirmwareDownloadException(
            'Download failed with status ${response.statusCode}',
          );
        }
      }

      if (response == null || response.statusCode != 200) {
        throw FirmwareDownloadException(
          'Failed to download after following redirects',
        );
      }

      final image = await _downloadFromStream(
        response.stream,
        artifact.name,
        artifact.sizeInBytes,
        run.branch,
        run.shortSha,
      );

      // Check if the downloaded zip is a release-style archive
      if (image.filePath.toLowerCase().endsWith('.zip')) {
        try {
          final file = File(image.filePath);
          final bytes = await file.readAsBytes();
          final archive = ZipDecoder().decodeBytes(bytes);

          if (_isReleaseArchive(archive)) {
            _log('CI artifact is a release archive, extracting...');
            final result = await _extractReleaseArchive(
              file,
              run.shortSha,
              run.branch,
            );
            // Clean up the outer zip — ignore errors (file may already be gone).
            try {
              await file.delete();
            } catch (e) {
              _log('Temp zip cleanup failed (ignored): $e');
            }
            return result;
          }
        } catch (e) {
          _log('Could not inspect artifact zip contents: $e');
        }
      }

      return ReleaseExtractionResult(firmwareImage: image);
    } catch (e) {
      _updateProgress(
        DownloadProgress(0, 0, DownloadStatus.failed, error: e.toString()),
      );
      _log('Download error: $e');
      rethrow;
    } finally {
      _httpClient?.close();
      _httpClient = null;
    }
  }

  Future<FirmwareImage> _downloadFromStream(
    http.ByteStream stream,
    String artifactName,
    int expectedSize,
    String branch,
    String commitSha,
  ) async {
    final downloadDir = await _getDownloadDirectory();
    final fileName = '${artifactName}_$commitSha.zip';
    final filePath = path.join(downloadDir.path, fileName);
    final file = File(filePath);
    final sink = file.openWrite();

    int bytesReceived = 0;

    await for (final chunk in stream) {
      if (_cancelDownload) {
        await sink.close();
        await file.delete();
        throw FirmwareDownloadException('Download cancelled');
      }

      sink.add(chunk);
      bytesReceived += chunk.length;
      _updateProgress(
        DownloadProgress(
          bytesReceived,
          expectedSize,
          DownloadStatus.downloading,
        ),
      );
    }

    await sink.close();
    _log('Download complete: ${file.path}');

    final actualSize = await file.length();
    _updateProgress(
      DownloadProgress(actualSize, actualSize, DownloadStatus.completed),
    );

    return FirmwareImage.fromGitHub(
      name: artifactName,
      version: commitSha,
      filePath: file.path,
      size: actualSize,
      sourceUrl: 'https://github.com/$_owner/$_repo/actions',
      branch: branch,
    );
  }

  /// Get the browser download URL for an artifact
  ///
  /// This can be used to open in browser for manual download
  String getArtifactBrowserUrl(WorkflowRun run, WorkflowArtifact artifact) {
    return 'https://github.com/$_owner/$_repo/actions/runs/${run.id}/artifacts/${artifact.id}';
  }

  /// Download firmware from a GitHub release asset
  ///
  /// Downloads the selected asset (e.g., watchdk@1_nrf5340_cpuapp_debug.zip),
  /// extracts it to find dfu_application.zip (and optionally lvgl_resources_raw.bin),
  /// and returns the extraction result.
  Future<ReleaseExtractionResult> downloadReleaseAsset(
    GitHubRelease release,
    ReleaseAsset asset,
  ) async {
    _log('Downloading release asset: ${asset.name}');
    _cancelDownload = false;

    _updateProgress(
      DownloadProgress(0, asset.size, DownloadStatus.downloading),
    );

    try {
      _httpClient = http.Client();
      final request = http.Request('GET', Uri.parse(asset.downloadUrl));
      final response = await _httpClient!.send(request);

      if (response.statusCode != 200) {
        throw FirmwareDownloadException(
          'Download failed: ${response.statusCode}',
        );
      }

      // Get download directory
      final downloadDir = await _getDownloadDirectory();
      final outerZipPath = path.join(downloadDir.path, asset.name);
      final outerZipFile = File(outerZipPath);
      final sink = outerZipFile.openWrite();

      int bytesReceived = 0;
      final totalBytes = response.contentLength ?? asset.size;

      await for (final chunk in response.stream) {
        if (_cancelDownload) {
          await sink.close();
          await outerZipFile.delete();
          throw FirmwareDownloadException('Download cancelled');
        }

        sink.add(chunk);
        bytesReceived += chunk.length;
        _updateProgress(
          DownloadProgress(
            bytesReceived,
            totalBytes,
            DownloadStatus.downloading,
          ),
        );
      }

      await sink.close();
      _log('Download complete: ${outerZipFile.path}');

      // Now extract the outer zip to find dfu_application.zip and lvgl_resources_raw.bin
      _log('Extracting release archive...');
      final result = await _extractReleaseArchive(
        outerZipFile,
        release.version,
        release.tagName,
      );

      // Clean up outer zip — ignore errors (file may already be gone).
      try {
        await outerZipFile.delete();
      } catch (e) {
        _log('Outer zip cleanup failed (ignored): $e');
      }

      _updateProgress(
        DownloadProgress(totalBytes, totalBytes, DownloadStatus.completed),
      );

      return result;
    } catch (e) {
      _updateProgress(
        DownloadProgress(0, 0, DownloadStatus.failed, error: e.toString()),
      );
      _log('Download error: $e');
      rethrow;
    } finally {
      _httpClient?.close();
      _httpClient = null;
    }
  }

  /// Extract dfu_application.zip and optionally lvgl_resources_raw.bin from an outer release zip
  ///
  /// [version] and [tagName] may be null when extracting local files or CI artifacts.
  /// When [useRotatedFirmware] is true, uses dfu_application_rotated.zip instead.
  Future<ReleaseExtractionResult> _extractReleaseArchive(
    File outerZipFile,
    String? version,
    String? tagName,
  ) async {
    final bytes = await outerZipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    // Cache ELF from archive if manifest.json + zephyr.elf.gz are present
    await _cacheElfFromArchive(archive);

    final downloadDir = await _getDownloadDirectory();

    FirmwareImage? standardFirmwareImage;
    FirmwareImage? rotatedFirmwareImage;
    FilesystemImage? filesystemImage;

    _log(
      'Extracting firmware variants (rotated preferred: $useRotatedFirmware)',
    );

    // Extract both DFU variants (if present) and filesystem image
    for (final file in archive) {
      if (!file.isFile) continue;

      final fileName = file.name.toLowerCase();
      final baseName = path.basename(fileName);

      // Standard DFU firmware
      if (baseName == 'dfu_application.zip') {
        final dfuZipPath = path.join(downloadDir.path, 'dfu_application.zip');
        final dfuZipFile = File(dfuZipPath);
        await dfuZipFile.writeAsBytes(file.content as List<int>);

        _log('Extracted dfu_application.zip: $dfuZipPath');

        standardFirmwareImage = version != null
            ? FirmwareImage.fromGitHub(
                name: 'dfu_application.zip',
                version: version,
                filePath: dfuZipPath,
                size: file.size,
                sourceUrl: outerZipFile.path,
                branch: tagName ?? '',
              )
            : FirmwareImage.fromLocalFile(
                name: 'dfu_application.zip',
                filePath: dfuZipPath,
                size: file.size,
              );
      }

      // Rotated DFU firmware
      if (baseName == 'dfu_application_rotated.zip') {
        final rotatedZipPath = path.join(
          downloadDir.path,
          'dfu_application_rotated.zip',
        );
        final rotatedZipFile = File(rotatedZipPath);
        await rotatedZipFile.writeAsBytes(file.content as List<int>);

        _log('Extracted dfu_application_rotated.zip: $rotatedZipPath');

        rotatedFirmwareImage = version != null
            ? FirmwareImage.fromGitHub(
                name: 'dfu_application_rotated.zip',
                version: version,
                filePath: rotatedZipPath,
                size: file.size,
                sourceUrl: outerZipFile.path,
                branch: tagName ?? '',
              )
            : FirmwareImage.fromLocalFile(
                name: 'dfu_application_rotated.zip',
                filePath: rotatedZipPath,
                size: file.size,
              );
      }

      // Check for filesystem image
      if (FilesystemConstants.isFilesystemImage(baseName)) {
        final fsImagePath = path.join(downloadDir.path, baseName);
        final fsImageFile = File(fsImagePath);
        await fsImageFile.writeAsBytes(file.content as List<int>);

        _log('Extracted filesystem image: $fsImagePath (${file.size} bytes)');

        filesystemImage = FilesystemImage.fromFile(
          filePath: fsImagePath,
          size: file.size,
          version: version,
          sourceUrl: outerZipFile.path,
        );
      }
    }

    final firmwareImage = useRotatedFirmware
        ? (rotatedFirmwareImage ?? standardFirmwareImage)
        : (standardFirmwareImage ?? rotatedFirmwareImage);

    if (firmwareImage == null) {
      throw FirmwareDownloadException(
        'No DFU firmware zip found in release archive',
      );
    }

    if (standardFirmwareImage != null && rotatedFirmwareImage != null) {
      _log('Release contains standard and rotated DFU variants');
    } else if (rotatedFirmwareImage != null) {
      _log('Release contains rotated DFU variant only');
    } else {
      _log('Release contains standard DFU variant only');
    }

    if (filesystemImage != null) {
      _log('Release contains both firmware and filesystem image');
    } else {
      _log('Release contains firmware only (no filesystem image)');
    }

    return ReleaseExtractionResult(
      firmwareImage: firmwareImage,
      filesystemImage: filesystemImage,
    );
  }

  /// Cancel an ongoing download
  void cancelDownload() {
    _cancelDownload = true;
    _httpClient?.close();
  }

  /// Extract firmware images from a zip file
  ///
  /// Parses the manifest.json inside the zip to get image_index for each file.
  Future<List<FirmwareImage>> extractZip(FirmwareImage zipImage) async {
    if (!zipImage.filePath.toLowerCase().endsWith('.zip')) {
      return [zipImage]; // Not a zip, return as-is
    }

    _log('Extracting firmware package: ${zipImage.name}');

    try {
      final zipFile = File(zipImage.filePath);
      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      final extractDir = await _getDownloadDirectory();
      final extractPath = path.join(
        extractDir.path,
        'extracted_${DateTime.now().millisecondsSinceEpoch}',
      );
      await Directory(extractPath).create(recursive: true);

      // First, look for and parse manifest.json
      Map<String, ManifestEntry>? manifestEntries;
      for (final file in archive) {
        if (file.isFile && file.name.toLowerCase().endsWith('manifest.json')) {
          try {
            final manifestContent = utf8.decode(file.content as List<int>);
            manifestEntries = _parseManifest(manifestContent);
            _log('Found manifest.json with ${manifestEntries.length} entries');
          } catch (e) {
            _log('Failed to parse manifest.json: $e');
          }
          break;
        }
      }

      final images = <FirmwareImage>[];

      for (final file in archive) {
        if (!file.isFile || !file.name.toLowerCase().endsWith('.bin')) {
          continue;
        }

        final fileName = path.basename(file.name);

        // Look up in manifest first
        final manifestEntry = manifestEntries?[fileName.toLowerCase()];

        if (manifestEntry != null) {
          // Extract this file - manifest tells us everything
          final outputPath = path.join(extractPath, fileName);
          final outputFile = File(outputPath);
          await outputFile.create(recursive: true);
          await outputFile.writeAsBytes(file.content as List<int>);

          _log(
            'Extracted: $fileName (image_index: ${manifestEntry.imageIndex})',
          );

          images.add(
            FirmwareImage.fromLocalFile(
              name: fileName,
              filePath: outputPath,
              size: file.size,
              version: manifestEntry.version ?? zipImage.version,
              slot: manifestEntry.imageIndex,
              board: manifestEntry.board,
            ),
          );
        } else if (manifestEntries == null) {
          // No manifest - fall back to filename-based detection (legacy support)
          if (_isFirmwareFile(file.name)) {
            final outputPath = path.join(extractPath, fileName);
            final outputFile = File(outputPath);
            await outputFile.create(recursive: true);
            await outputFile.writeAsBytes(file.content as List<int>);

            _log('Extracted (no manifest): $fileName');

            images.add(
              FirmwareImage.fromLocalFile(
                name: fileName,
                filePath: outputPath,
                size: file.size,
                version: zipImage.version,
              ),
            );
          }
        } else {
          _log('Skipping $fileName - not in manifest');
        }
      }

      if (images.isEmpty) {
        throw FirmwareDownloadException('No firmware files found in archive');
      }

      // Sort by image_index (slot)
      images.sort((a, b) {
        final slotA = a.slot ?? 99;
        final slotB = b.slot ?? 99;
        return slotA.compareTo(slotB);
      });

      _log(
        'Extracted ${images.length} firmware image(s): ${images.map((i) => '${i.name}(slot:${i.slot})').join(', ')}',
      );
      return images;
    } catch (e) {
      _log('Extraction error: $e');
      rethrow;
    }
  }

  /// Parse manifest.json content and return a map of filename -> ManifestEntry
  Map<String, ManifestEntry> _parseManifest(String jsonContent) {
    final json = jsonDecode(jsonContent) as Map<String, dynamic>;
    final files = json['files'] as List<dynamic>?;

    if (files == null) {
      return {};
    }

    final entries = <String, ManifestEntry>{};
    for (final fileEntry in files) {
      final entry = fileEntry as Map<String, dynamic>;
      final fileName = entry['file'] as String?;
      if (fileName == null) continue;

      // image_index can be int or string
      final imageIndexRaw = entry['image_index'];
      final imageIndex = imageIndexRaw is int
          ? imageIndexRaw
          : int.tryParse(imageIndexRaw?.toString() ?? '');

      entries[fileName.toLowerCase()] = ManifestEntry(
        file: fileName,
        imageIndex: imageIndex ?? 0,
        size: entry['size'] as int?,
        version:
            entry['version_MCUBOOT'] as String? ?? entry['version'] as String?,
        type: entry['type'] as String?,
        board: entry['board'] as String?,
      );
    }

    return entries;
  }

  /// Check if a zip file is a release-style archive (contains dfu_application.zip inside)
  ///
  /// Release archives (e.g. watchdk@1_nrf5340_cpuapp_debug.zip) contain both
  /// dfu_application.zip and optionally lvgl_resources_raw.bin.
  bool _isReleaseArchive(Archive archive) {
    for (final file in archive) {
      if (!file.isFile) continue;
      final baseName = path.basename(file.name).toLowerCase();
      if (baseName == 'dfu_application.zip' ||
          baseName == 'dfu_application_rotated.zip') {
        return true;
      }
    }
    return false;
  }

  /// Load a local firmware file (from file picker)
  ///
  /// If the file is a release-style archive (contains dfu_application.zip),
  /// it is extracted the same way as a GitHub release download, returning
  /// a [ReleaseExtractionResult] with both firmware and filesystem images.
  /// Otherwise returns a result with just the firmware image.
  Future<ReleaseExtractionResult> loadLocalFile(String filePath) async {
    _log('Loading local file: $filePath');

    final file = File(filePath);
    if (!await file.exists()) {
      throw FirmwareDownloadException('File not found: $filePath');
    }

    final size = await file.length();
    final name = path.basename(filePath);

    // Validate file extension
    final lower = name.toLowerCase();
    if (!lower.endsWith('.bin') && !lower.endsWith('.zip')) {
      throw FirmwareDownloadException(
        'Invalid file type. Expected .bin or .zip file.',
      );
    }

    // For zip files, check if it's a release-style archive
    if (lower.endsWith('.zip')) {
      try {
        final bytes = await file.readAsBytes();
        final archive = ZipDecoder().decodeBytes(bytes);

        if (_isReleaseArchive(archive)) {
          _log('Detected release archive, extracting...');
          return _extractReleaseArchive(file, null, null);
        }
      } catch (e) {
        _log('Could not inspect zip contents: $e');
        // Fall through to treat as a plain firmware zip
      }
    }

    // Plain .bin or simple dfu_application.zip
    final image = FirmwareImage.fromLocalFile(
      name: name,
      filePath: filePath,
      size: size,
    );
    return ReleaseExtractionResult(firmwareImage: image);
  }

  /// Prepare firmware for upload (extract if needed, validate)
  Future<List<FirmwareImage>> prepareFirmware(FirmwareImage image) async {
    final selectedImage = await _selectPreferredDfuVariant(image);
    _log('Preparing firmware: ${selectedImage.name}');

    if (selectedImage.isCombined) {
      return await extractZip(selectedImage);
    }

    // Validate single file
    final file = File(selectedImage.filePath);
    if (!await file.exists()) {
      throw FirmwareDownloadException(
        'File not found: ${selectedImage.filePath}',
      );
    }

    return [selectedImage];
  }

  /// Select standard/rotated DFU variant based on [useRotatedFirmware].
  ///
  /// If the opposite variant is already selected and the preferred sibling file
  /// exists in the same directory, this switches to the preferred variant.
  Future<FirmwareImage> _selectPreferredDfuVariant(FirmwareImage image) async {
    final lowerName = path.basename(image.name).toLowerCase();
    final isStandard = lowerName == 'dfu_application.zip';
    final isRotated = lowerName == 'dfu_application_rotated.zip';

    if (!isStandard && !isRotated) {
      return image;
    }

    final imageDir = path.dirname(image.filePath);
    final standardPath = path.join(imageDir, 'dfu_application.zip');
    final rotatedPath = path.join(imageDir, 'dfu_application_rotated.zip');

    if (useRotatedFirmware && !isRotated) {
      final rotatedFile = File(rotatedPath);
      if (await rotatedFile.exists()) {
        final size = await rotatedFile.length();
        _log('Using rotated DFU variant for upload');
        return image.copyWith(
          name: 'dfu_application_rotated.zip',
          filePath: rotatedPath,
          size: size,
        );
      }
      _log('Rotated DFU variant requested but not found, using standard');
    }

    if (!useRotatedFirmware && !isStandard) {
      final standardFile = File(standardPath);
      if (await standardFile.exists()) {
        final size = await standardFile.length();
        _log('Using standard DFU variant for upload');
        return image.copyWith(
          name: 'dfu_application.zip',
          filePath: standardPath,
          size: size,
        );
      }
      _log('Standard DFU variant requested but not found, using rotated');
    }

    return image;
  }

  /// Clean up downloaded/extracted files
  Future<void> cleanup({List<FirmwareImage>? images}) async {
    if (images != null) {
      for (final image in images) {
        try {
          final file = File(image.filePath);
          if (await file.exists()) {
            await file.delete();
            _log('Cleaned up: ${image.filePath}');
          }
        } catch (e) {
          _log('Cleanup error: $e');
        }
      }
    }

    // Clean up old extracted directories
    try {
      final downloadDir = await _getDownloadDirectory();
      final entities = await downloadDir.list().toList();

      for (final entity in entities) {
        if (entity is Directory && entity.path.contains('extracted_')) {
          final stat = await entity.stat();
          final age = DateTime.now().difference(stat.modified);
          if (age.inHours > 24) {
            await entity.delete(recursive: true);
            _log('Cleaned up old extraction: ${entity.path}');
          }
        }
      }
    } catch (e) {
      _log('Cleanup error: $e');
    }
  }

  Future<Directory> _getDownloadDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final downloadDir = Directory(path.join(appDir.path, 'firmware'));
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }
    return downloadDir;
  }

  /// Check if a release asset is a firmware file
  /// Simply checks for .zip extension - all zip files in releases are firmware
  bool _isFirmwareAsset(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.zip');
  }

  /// Check if a file inside an archive is a firmware binary (fallback for zips without manifest)
  bool _isFirmwareFile(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.bin');
  }

  void _updateProgress(DownloadProgress progress) {
    _downloadProgressController.add(progress);
  }

  void _log(String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 23);
    _logController.add('[$timestamp] $message');
  }

  /// Reset progress to idle
  void resetProgress() {
    _updateProgress(const DownloadProgress(0, 0, DownloadStatus.idle));
  }

  // ==================== ELF Cache for Coredump Analysis ====================

  static const String _elfCacheDir = 'elf_cache';
  static const int _maxCachedElfs = 5;

  /// Get the ELF cache directory.
  Future<Directory> _getElfCacheDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(path.join(appDir.path, _elfCacheDir));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Cache an ELF (gzipped bytes) keyed by commit SHA.
  Future<void> cacheElf(String commitSha, List<int> elfGzBytes) async {
    final dir = await _getElfCacheDirectory();
    final file = File(path.join(dir.path, '$commitSha.elf.gz'));
    await file.writeAsBytes(elfGzBytes);
    _log('Cached ELF for commit $commitSha (${elfGzBytes.length} bytes)');

    // Evict old entries (keep last N by modification time)
    final entries = dir.listSync().whereType<File>().toList()
      ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    for (var i = _maxCachedElfs; i < entries.length; i++) {
      _log('Evicting old ELF cache entry: ${entries[i].path}');
      await entries[i].delete();
    }
  }

  /// Get a cached ELF file for the given commit SHA (gzipped).
  /// Returns null if not cached. Supports prefix matching for truncated SHAs
  /// (the watch reports a short SHA, but the cache uses the full SHA from CI).
  Future<File?> getCachedElf(String commitSha) async {
    final dir = await _getElfCacheDirectory();
    // Try exact match first
    final file = File(path.join(dir.path, '$commitSha.elf.gz'));
    if (await file.exists()) {
      _log('ELF cache hit for commit $commitSha');
      return file;
    }
    // Prefix match for truncated SHAs
    final entries = dir.listSync().whereType<File>().where(
      (f) => f.path.endsWith('.elf.gz'),
    );
    for (final entry in entries) {
      final name = path.basenameWithoutExtension(
        path.basenameWithoutExtension(entry.path),
      ); // strip .elf.gz
      if (name.startsWith(commitSha) || commitSha.startsWith(name)) {
        _log('ELF cache prefix hit: $commitSha matched $name');
        return entry;
      }
    }
    return null;
  }

  /// Get the cached elf_hash for a given commit SHA, if known from manifest.
  /// Supports prefix matching for truncated SHAs.
  Future<String?> getCachedElfHash(String commitSha) async {
    final dir = await _getElfCacheDirectory();
    // Try exact match first
    final metaFile = File(path.join(dir.path, '$commitSha.meta'));
    if (await metaFile.exists()) {
      return (await metaFile.readAsString()).trim();
    }
    // Prefix match for truncated SHAs
    final entries = dir.listSync().whereType<File>().where(
      (f) => f.path.endsWith('.meta'),
    );
    for (final entry in entries) {
      final name = path.basenameWithoutExtension(entry.path); // strip .meta
      if (name.startsWith(commitSha) || commitSha.startsWith(name)) {
        _log('ELF meta prefix hit: $commitSha matched $name');
        return (await entry.readAsString()).trim();
      }
    }
    return null;
  }

  /// Extract and cache ELF from a release/CI artifact zip if manifest.json
  /// and zephyr.elf.gz are present.
  Future<void> _cacheElfFromArchive(Archive archive) async {
    // Look for manifest.json to get commit_sha and elf_hash
    String? commitSha;
    String? elfHash;
    List<int>? elfGzBytes;

    for (final file in archive) {
      if (!file.isFile) continue;
      final baseName = path.basename(file.name).toLowerCase();

      if (baseName == 'manifest.json') {
        try {
          final content = utf8.decode(file.content as List<int>);
          final manifest = jsonDecode(content) as Map<String, dynamic>;
          commitSha = manifest['commit_sha'] as String?;
          elfHash = manifest['elf_hash'] as String?;
          _log('Found manifest.json: commit_sha=$commitSha elf_hash=$elfHash');
        } catch (e) {
          _log('Failed to parse manifest.json: $e');
        }
      }

      if (baseName == 'zephyr.elf.gz') {
        elfGzBytes = file.content as List<int>;
        _log('Found zephyr.elf.gz (${elfGzBytes.length} bytes)');
      }
    }

    if (commitSha != null && commitSha.isNotEmpty && elfGzBytes != null) {
      await cacheElf(commitSha, elfGzBytes);
      // Store elf_hash metadata alongside the cached ELF
      if (elfHash != null && elfHash.isNotEmpty) {
        final dir = await _getElfCacheDirectory();
        final metaFile = File(path.join(dir.path, '$commitSha.meta'));
        await metaFile.writeAsString(elfHash);
      }
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    cancelDownload();
    await _downloadProgressController.close();
    await _logController.close();
  }
}

/// Download status
enum DownloadStatus {
  idle,
  downloading,
  extracting,
  completed,
  failed,
  cancelled,
}

/// Extension methods for DownloadStatus
extension DownloadStatusExtension on DownloadStatus {
  bool get isInProgress =>
      this == DownloadStatus.downloading || this == DownloadStatus.extracting;

  String get statusText {
    switch (this) {
      case DownloadStatus.idle:
        return 'Ready';
      case DownloadStatus.downloading:
        return 'Downloading...';
      case DownloadStatus.extracting:
        return 'Extracting...';
      case DownloadStatus.completed:
        return 'Complete';
      case DownloadStatus.failed:
        return 'Failed';
      case DownloadStatus.cancelled:
        return 'Cancelled';
    }
  }
}

/// Download progress state
class DownloadProgress {
  final int bytesReceived;
  final int totalBytes;
  final DownloadStatus status;
  final String? error;

  const DownloadProgress(
    this.bytesReceived,
    this.totalBytes,
    this.status, {
    this.error,
  });

  /// Progress as 0.0 to 1.0
  double get progress {
    if (totalBytes == 0) return 0.0;
    return (bytesReceived / totalBytes).clamp(0.0, 1.0);
  }

  /// Progress as percentage
  int get progressPercent => (progress * 100).round();

  /// Human-readable bytes received
  String get formattedBytesReceived => _formatBytes(bytesReceived);

  /// Human-readable total bytes
  String get formattedTotalBytes => _formatBytes(totalBytes);

  static String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
  }
}

/// Exception for firmware download errors
class FirmwareDownloadException implements Exception {
  final String message;

  FirmwareDownloadException(this.message);

  @override
  String toString() => 'FirmwareDownloadException: $message';
}

/// Result of extracting a release archive
///
/// Contains the firmware image (dfu_application.zip) and optionally
/// a filesystem image (lvgl_resources_raw.bin) if found in the archive.
class ReleaseExtractionResult {
  /// The extracted firmware image (dfu_application.zip)
  final FirmwareImage firmwareImage;

  /// The extracted filesystem image (lvgl_resources_raw.bin), if found
  final FilesystemImage? filesystemImage;

  const ReleaseExtractionResult({
    required this.firmwareImage,
    this.filesystemImage,
  });

  /// Whether a filesystem image was found
  bool get hasFilesystemImage => filesystemImage != null;
}

/// Represents a GitHub Actions workflow run with firmware artifacts
class WorkflowRun {
  /// Workflow run ID
  final int id;

  /// Branch name
  final String branch;

  /// User who triggered the run
  final String user;

  /// Commit SHA
  final String commitSha;

  /// Commit message
  final String commitMessage;

  /// When the run was created
  final DateTime createdAt;

  /// List of firmware artifacts in this run
  final List<WorkflowArtifact> artifacts;

  const WorkflowRun({
    required this.id,
    required this.branch,
    required this.user,
    required this.commitSha,
    required this.commitMessage,
    required this.createdAt,
    required this.artifacts,
  });

  /// Short commit SHA (first 7 characters)
  String get shortSha =>
      commitSha.length > 7 ? commitSha.substring(0, 7) : commitSha;

  /// First line of commit message
  String get shortCommitMessage {
    final firstLine = commitMessage.split('\n').first;
    return firstLine.length > 60
        ? '${firstLine.substring(0, 57)}...'
        : firstLine;
  }

  /// Whether this is from the main branch
  bool get isMainBranch => branch == 'main';

  /// Formatted date
  String get formattedDate {
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }
}

/// Represents a GitHub Actions artifact
class WorkflowArtifact {
  /// Artifact ID
  final int id;

  /// Artifact name
  final String name;

  /// Size in bytes
  final int sizeInBytes;

  /// When the artifact was created
  final DateTime createdAt;

  /// Whether the artifact has expired
  final bool expired;

  /// GitHub API download URL (requires auth)
  final String? archiveDownloadUrl;

  const WorkflowArtifact({
    required this.id,
    required this.name,
    required this.sizeInBytes,
    required this.createdAt,
    required this.expired,
    this.archiveDownloadUrl,
  });

  /// Human-readable size
  String get formattedSize {
    if (sizeInBytes < 1024) {
      return '$sizeInBytes B';
    } else if (sizeInBytes < 1024 * 1024) {
      return '${(sizeInBytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
  }
}

/// Represents an entry from manifest.json inside a DFU zip
class ManifestEntry {
  /// Filename (e.g., "app.internal.bin")
  final String file;

  /// MCUmgr image index (0, 1, 2, etc.)
  final int imageIndex;

  /// File size in bytes
  final int? size;

  /// Version string (from version_MCUBOOT or version field)
  final String? version;

  /// Type (e.g., "application")
  final String? type;

  /// Board identifier
  final String? board;

  const ManifestEntry({
    required this.file,
    required this.imageIndex,
    this.size,
    this.version,
    this.type,
    this.board,
  });
}
