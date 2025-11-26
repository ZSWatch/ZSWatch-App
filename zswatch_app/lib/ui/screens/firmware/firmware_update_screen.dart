import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/dfu_state.dart';
import '../../../data/models/firmware_image.dart';
import '../../../providers/dfu_providers.dart';
import '../../../providers/watch_service_provider.dart';
import '../../../services/dfu/firmware_manager.dart';

/// Firmware update screen for DFU operations
///
/// Features:
/// - GitHub releases list with prebuilt firmware
/// - Local file picker for .zip/.bin files
/// - Upload progress with percentage, speed, stage
/// - Battery level warning (informational)
/// - Navigation lock during critical phase
/// - Reconnection handling after reboot
class FirmwareUpdateScreen extends ConsumerStatefulWidget {
  const FirmwareUpdateScreen({super.key});

  @override
  ConsumerState<FirmwareUpdateScreen> createState() =>
      _FirmwareUpdateScreenState();
}

class _FirmwareUpdateScreenState extends ConsumerState<FirmwareUpdateScreen> {
  bool _showLogs = false;
  final List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    // Listen to DFU logs
    ref.read(dfuServiceProvider).logStream.listen((log) {
      if (mounted) {
        setState(() => _logs.add(log));
      }
    });
    ref.read(firmwareManagerProvider).logStream.listen((log) {
      if (mounted) {
        setState(() => _logs.add(log));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final dfuState = ref.watch(dfuStateProvider);
    final operationState = ref.watch(dfuNotifierProvider);
    final downloadProgress = ref.watch(downloadProgressProvider);
    final watch = ref.watch(currentWatchProvider);
    final isConnected = ref.watch(isWatchConnectedProvider);

    // Prevent back navigation during critical DFU phase
    return PopScope(
      canPop: !dfuState.status.isCritical,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && dfuState.status.isCritical) {
          _showCriticalWarning(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Firmware Update'),
          leading: dfuState.status.isCritical
              ? IconButton(
                  icon: const Icon(Icons.warning, color: AppTheme.warningColor),
                  onPressed: () => _showCriticalWarning(context),
                )
              : null,
          actions: [
            IconButton(
              icon: Icon(_showLogs ? Icons.list : Icons.terminal),
              onPressed: () => setState(() => _showLogs = !_showLogs),
              tooltip: _showLogs ? 'Hide Logs' : 'Show Logs',
            ),
          ],
        ),
        body: _showLogs
            ? _LogView(logs: _logs)
            : SingleChildScrollView(
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Battery warning
                    if (watch != null && watch.isBatteryLow)
                      _BatteryWarningCard(level: watch.batteryLevel ?? 0),

                    // Connection status
                    if (!isConnected)
                      _ConnectionWarningCard(
                        onReconnect: () => context.go('/scan'),
                      ),

                    // Current status card
                    _StatusCard(
                      dfuState: dfuState,
                      downloadProgress: downloadProgress,
                    ),

                    const SizedBox(height: AppTheme.spacingMd),

                    // Firmware selection or progress
                    if (dfuState.status == DfuStatus.idle &&
                        !operationState.isDownloading) ...[
                      // Selected firmware card
                      if (operationState.hasFirmware)
                        _SelectedFirmwareCard(
                          image: operationState.downloadedImage!,
                          onClear: () =>
                              ref.read(dfuNotifierProvider.notifier).reset(),
                        ),

                      // GitHub releases
                      _ReleasesSection(
                        onAssetSelected: (release, asset) {
                          ref
                              .read(dfuNotifierProvider.notifier)
                              .downloadReleaseAsset(release, asset);
                        },
                      ),

                      const SizedBox(height: AppTheme.spacingMd),

                      // CI Builds (GitHub Actions)
                      _CIBuildsSection(
                        onOpenInBrowser: (run, artifact) async {
                          final url = ref
                              .read(dfuNotifierProvider.notifier)
                              .getArtifactBrowserUrl(run, artifact);
                          final uri = Uri.parse(url);
                          try {
                            final launched = await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                            if (context.mounted) {
                              if (launched) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Opening in browser. After download, '
                                      'use "Select from file system" to load the file.',
                                    ),
                                    duration: Duration(seconds: 5),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Could not open browser. URL: $url'),
                                    backgroundColor: AppTheme.errorColor,
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to open URL: $e'),
                                  backgroundColor: AppTheme.errorColor,
                                ),
                              );
                            }
                          }
                        },
                      ),

                      const SizedBox(height: AppTheme.spacingMd),

                      // Local file picker
                      _LocalFileSection(
                        onFileSelected: (path) {
                          ref
                              .read(dfuNotifierProvider.notifier)
                              .loadLocalFile(path);
                        },
                      ),
                    ],

                    // Error display
                    if (operationState.hasError)
                      _ErrorCard(
                        error: operationState.error!,
                        onDismiss: () =>
                            ref.read(dfuNotifierProvider.notifier).reset(),
                      ),

                    const SizedBox(height: AppTheme.spacingLg),

                    // Action buttons
                    _ActionButtons(
                      dfuState: dfuState,
                      operationState: operationState,
                      isConnected: isConnected,
                      onStart: () =>
                          ref.read(dfuNotifierProvider.notifier).startUpdate(),
                      onCancel: () =>
                          ref.read(dfuNotifierProvider.notifier).cancel(),
                      onReset: () =>
                          ref.read(dfuNotifierProvider.notifier).reset(),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  void _showCriticalWarning(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: AppTheme.warningColor),
            SizedBox(width: 8),
            Text('Update in Progress'),
          ],
        ),
        content: const Text(
          'A critical firmware update is in progress. '
          'Leaving this screen or disconnecting the watch could result in a bricked device.\n\n'
          'Please wait for the update to complete.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _LogView extends StatelessWidget {
  final List<String> logs;

  const _LogView({required this.logs});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: logs.length,
        itemBuilder: (context, index) {
          return Text(
            logs[index],
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: Colors.green,
            ),
          );
        },
      ),
    );
  }
}

class _BatteryWarningCard extends StatelessWidget {
  final int level;

  const _BatteryWarningCard({required this.level});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.warningColor.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Row(
          children: [
            const Icon(Icons.battery_alert, color: AppTheme.warningColor),
            const SizedBox(width: AppTheme.spacingSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Low Battery ($level%)',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppTheme.warningColor,
                        ),
                  ),
                  Text(
                    'Consider charging your watch before updating.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionWarningCard extends StatelessWidget {
  final VoidCallback onReconnect;

  const _ConnectionWarningCard({required this.onReconnect});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.errorColor.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Row(
          children: [
            const Icon(Icons.bluetooth_disabled, color: AppTheme.errorColor),
            const SizedBox(width: AppTheme.spacingSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Watch Not Connected',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppTheme.errorColor,
                        ),
                  ),
                  Text(
                    'Connect to your watch to update firmware.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: onReconnect,
              child: const Text('Connect'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final DfuState dfuState;
  final DownloadProgress downloadProgress;

  const _StatusCard({
    required this.dfuState,
    required this.downloadProgress,
  });

  @override
  Widget build(BuildContext context) {
    final isDownloading = downloadProgress.status.isInProgress;
    final isDfuInProgress = dfuState.status.isInProgress;

    if (!isDownloading && !isDfuInProgress) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status header
            Row(
              children: [
                _StatusIcon(
                  status: isDfuInProgress
                      ? dfuState.status
                      : (isDownloading ? DfuStatus.preparing : DfuStatus.idle),
                ),
                const SizedBox(width: AppTheme.spacingSm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isDownloading
                            ? 'Downloading Firmware...'
                            : dfuState.status.statusText,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (dfuState.currentImageName != null)
                        Text(
                          dfuState.currentImageName!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppTheme.spacingMd),

            // Progress bar
            LinearProgressIndicator(
              value: isDownloading
                  ? downloadProgress.progress
                  : dfuState.progress,
              backgroundColor: AppTheme.surfaceColor,
            ),

            const SizedBox(height: AppTheme.spacingSm),

            // Progress details
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isDownloading
                      ? '${downloadProgress.formattedBytesReceived} / ${downloadProgress.formattedTotalBytes}'
                      : '${dfuState.formattedBytesTransferred} / ${dfuState.formattedTotalBytes}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  isDownloading
                      ? '${downloadProgress.progressPercent}%'
                      : '${dfuState.progressPercent}%',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),

            // Speed and time remaining (DFU only)
            if (isDfuInProgress && dfuState.status == DfuStatus.uploading)
              Padding(
                padding: const EdgeInsets.only(top: AppTheme.spacingSm),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Speed: ${dfuState.formattedSpeed}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      'Remaining: ${dfuState.formattedTimeRemaining}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),

            // Multi-image progress
            if (dfuState.totalImages > 1)
              Padding(
                padding: const EdgeInsets.only(top: AppTheme.spacingSm),
                child: Text(
                  'Image ${dfuState.currentImage} of ${dfuState.totalImages}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final DfuStatus status;

  const _StatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;

    switch (status) {
      case DfuStatus.idle:
        icon = Icons.download;
        color = AppTheme.textSecondary;
        break;
      case DfuStatus.preparing:
        icon = Icons.hourglass_top;
        color = AppTheme.primaryColor;
        break;
      case DfuStatus.uploading:
        icon = Icons.upload;
        color = AppTheme.primaryColor;
        break;
      case DfuStatus.validating:
        icon = Icons.verified;
        color = AppTheme.primaryColor;
        break;
      case DfuStatus.applying:
        icon = Icons.memory;
        color = AppTheme.warningColor;
        break;
      case DfuStatus.rebooting:
        icon = Icons.restart_alt;
        color = AppTheme.warningColor;
        break;
      case DfuStatus.reconnecting:
        icon = Icons.bluetooth_searching;
        color = AppTheme.primaryColor;
        break;
      case DfuStatus.completed:
        icon = Icons.check_circle;
        color = AppTheme.successColor;
        break;
      case DfuStatus.failed:
        icon = Icons.error;
        color = AppTheme.errorColor;
        break;
      case DfuStatus.cancelled:
        icon = Icons.cancel;
        color = AppTheme.textSecondary;
        break;
    }

    return Icon(icon, color: color, size: 32);
  }
}

class _SelectedFirmwareCard extends StatelessWidget {
  final FirmwareImage image;
  final VoidCallback onClear;

  const _SelectedFirmwareCard({
    required this.image,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.primaryColor.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Row(
          children: [
            Icon(
              image.isCombined ? Icons.folder_zip : Icons.description,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(width: AppTheme.spacingSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    image.name,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    '${image.formattedSize} • ${image.type.displayName}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (image.version != null)
                    Text(
                      'Version: ${image.version}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: onClear,
              tooltip: 'Clear selection',
            ),
          ],
        ),
      ),
    );
  }
}

class _ReleasesSection extends ConsumerWidget {
  final void Function(GitHubRelease, ReleaseAsset) onAssetSelected;

  const _ReleasesSection({required this.onAssetSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final releasesAsync = ref.watch(releasesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingSm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Available Releases',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: () => ref.read(releasesProvider.notifier).fetch(),
                tooltip: 'Load releases',
              ),
            ],
          ),
        ),
        releasesAsync.when(
          data: (releases) {
            if (releases.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingMd),
                  child: Column(
                    children: [
                      Icon(
                        Icons.cloud_download_outlined,
                        color: AppTheme.textSecondary.withValues(alpha: 0.5),
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      const Text('No releases loaded'),
                      Text(
                        'Tap refresh to fetch from GitHub',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
              );
            }
            return Column(
              children: releases
                  .take(5)
                  .map((release) => _ReleaseCard(
                        release: release,
                        onAssetSelected: (asset) => onAssetSelected(release, asset),
                      ))
                  .toList(),
            );
          },
          loading: () => const Card(
            child: Padding(
              padding: EdgeInsets.all(AppTheme.spacingMd),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (error, _) => Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              child: Column(
                children: [
                  const Icon(Icons.error_outline, color: AppTheme.errorColor),
                  const SizedBox(height: 8),
                  Text('Failed to load releases: $error'),
                  TextButton(
                    onPressed: () => ref.read(releasesProvider.notifier).fetch(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReleaseCard extends StatelessWidget {
  final GitHubRelease release;
  final void Function(ReleaseAsset) onAssetSelected;

  const _ReleaseCard({required this.release, required this.onAssetSelected});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingSm),
      child: ListTile(
        leading: Icon(
          release.isPrerelease ? Icons.science : Icons.new_releases,
          color:
              release.isPrerelease ? AppTheme.warningColor : AppTheme.successColor,
        ),
        title: Text(release.name),
        subtitle: Text(
          '${release.version} • ${release.assets.length} builds • ${release.formattedDate}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showAssetSelectionDialog(context),
      ),
    );
  }

  void _showAssetSelectionDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Firmware Build'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${release.name} (${release.version})',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
              const SizedBox(height: AppTheme.spacingMd),
              const Text(
                'Choose the build matching your hardware:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: AppTheme.spacingSm),
              ...release.assets.map((asset) => _AssetTile(
                    asset: asset,
                    onTap: () {
                      Navigator.pop(context);
                      onAssetSelected(asset);
                    },
                  )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

class _AssetTile extends StatelessWidget {
  final ReleaseAsset asset;
  final VoidCallback onTap;

  const _AssetTile({required this.asset, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingSm),
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.folder_zip, color: AppTheme.primaryColor),
        title: Text(
          asset.displayName,
          style: const TextStyle(fontSize: 13),
        ),
        subtitle: Text(
          asset.formattedSize,
          style: const TextStyle(fontSize: 11),
        ),
        trailing: const Icon(Icons.download, size: 20),
        onTap: onTap,
      ),
    );
  }
}

/// CI Builds section showing GitHub Actions workflow runs
class _CIBuildsSection extends ConsumerStatefulWidget {
  final void Function(WorkflowRun, WorkflowArtifact) onOpenInBrowser;

  const _CIBuildsSection({required this.onOpenInBrowser});

  @override
  ConsumerState<_CIBuildsSection> createState() => _CIBuildsSectionState();
}

class _CIBuildsSectionState extends ConsumerState<_CIBuildsSection> {
  final Map<String, bool> _expandedBranches = {};

  @override
  Widget build(BuildContext context) {
    final workflowRunsAsync = ref.watch(workflowRunsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingSm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'CI Builds',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'GitHub Actions',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.primaryColor,
                          ),
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: () => ref.read(workflowRunsProvider.notifier).fetch(),
                tooltip: 'Load CI builds',
              ),
            ],
          ),
        ),
        workflowRunsAsync.when(
          data: (runs) {
            if (runs.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingMd),
                  child: Column(
                    children: [
                      Icon(
                        Icons.build_circle_outlined,
                        color: AppTheme.textSecondary.withValues(alpha: 0.5),
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      const Text('No CI builds loaded'),
                      Text(
                        'Tap refresh to fetch from GitHub Actions',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Group runs by branch
            final Map<String, List<WorkflowRun>> runsByBranch = {};
            for (final run in runs) {
              runsByBranch.putIfAbsent(run.branch, () => []).add(run);
            }

            return Column(
              children: runsByBranch.entries.map((entry) {
                final branch = entry.key;
                final branchRuns = entry.value;
                final isMainBranch = branch == 'main';

                return Card(
                  margin: const EdgeInsets.only(bottom: AppTheme.spacingSm),
                  child: Column(
                    children: [
                      // Branch header
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingMd,
                          vertical: AppTheme.spacingSm,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor.withValues(alpha: 0.5),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.account_tree,
                              size: 16,
                              color: isMainBranch
                                  ? AppTheme.successColor
                                  : AppTheme.primaryColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              branch,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isMainBranch
                                    ? AppTheme.successColor.withValues(alpha: 0.1)
                                    : AppTheme.primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                isMainBranch ? 'Release' : 'Debug',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: isMainBranch
                                          ? AppTheme.successColor
                                          : AppTheme.primaryColor,
                                      fontSize: 10,
                                    ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${branchRuns.length} build${branchRuns.length != 1 ? 's' : ''}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      // Runs for this branch
                      ...branchRuns.map((run) => _WorkflowRunTile(
                            run: run,
                            isExpanded: _expandedBranches['${branch}_${run.id}'] ?? false,
                            onToggle: () {
                              setState(() {
                                final key = '${branch}_${run.id}';
                                _expandedBranches[key] = !(_expandedBranches[key] ?? false);
                              });
                            },
                            onOpenInBrowser: (artifact) {
                              widget.onOpenInBrowser(run, artifact);
                            },
                          )),
                    ],
                  ),
                );
              }).toList(),
            );
          },
          loading: () => const Card(
            child: Padding(
              padding: EdgeInsets.all(AppTheme.spacingMd),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (error, _) => Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              child: Column(
                children: [
                  const Icon(Icons.error_outline, color: AppTheme.errorColor),
                  const SizedBox(height: 8),
                  Text(
                    'Failed to load CI builds',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    error.toString(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  TextButton(
                    onPressed: () => ref.read(workflowRunsProvider.notifier).fetch(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Individual workflow run tile with expandable artifacts
class _WorkflowRunTile extends StatelessWidget {
  final WorkflowRun run;
  final bool isExpanded;
  final VoidCallback onToggle;
  final void Function(WorkflowArtifact) onOpenInBrowser;

  const _WorkflowRunTile({
    required this.run,
    required this.isExpanded,
    required this.onToggle,
    required this.onOpenInBrowser,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Run header (clickable)
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingMd,
              vertical: AppTheme.spacingSm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'by ${run.user}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${run.artifacts.length} artifact${run.artifacts.length != 1 ? 's' : ''}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            run.shortSha,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontFamily: 'monospace',
                                  color: AppTheme.textSecondary,
                                ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              run.shortCommitMessage,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.expand_more, size: 20),
                ),
              ],
            ),
          ),
        ),
        // Expanded artifacts
        if (isExpanded)
          Container(
            padding: const EdgeInsets.only(
              left: AppTheme.spacingMd,
              right: AppTheme.spacingMd,
              bottom: AppTheme.spacingSm,
            ),
            child: Column(
              children: run.artifacts.map((artifact) {
                return Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingSm,
                    vertical: AppTheme.spacingSm,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.textSecondary.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.archive, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              artifact.name,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontFamily: 'monospace',
                                  ),
                            ),
                            Text(
                              artifact.formattedSize,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.textSecondary,
                                    fontSize: 10,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => onOpenInBrowser(artifact),
                        icon: const Icon(Icons.open_in_browser, size: 16),
                        label: const Text('Open'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          minimumSize: const Size(0, 32),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        // Divider between runs
        const Divider(height: 1),
      ],
    );
  }
}

class _LocalFileSection extends StatelessWidget {
  final void Function(String) onFileSelected;

  const _LocalFileSection({required this.onFileSelected});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingSm),
          child: Text(
            'Or Select Downloaded File',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Card(
          child: InkWell(
            onTap: () => _pickFile(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingLg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.folder_open,
                    color: AppTheme.primaryColor.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: AppTheme.spacingSm),
                  Text(
                    'Select .zip firmware file',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppTheme.primaryColor,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spacingSm),
        Text(
          'Select a dfu_application.zip file downloaded from GitHub Actions.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
              ),
        ),
      ],
    );
  }

  Future<void> _pickFile(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.path != null) {
          onFileSelected(file.path!);
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not access the selected file'),
                backgroundColor: AppTheme.errorColor,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking file: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }
}

class _ErrorCard extends StatelessWidget {
  final String error;
  final VoidCallback onDismiss;

  const _ErrorCard({
    required this.error,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.errorColor.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppTheme.errorColor),
            const SizedBox(width: AppTheme.spacingSm),
            Expanded(
              child: Text(
                error,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.errorColor,
                    ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: onDismiss,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final DfuState dfuState;
  final DfuOperationState operationState;
  final bool isConnected;
  final VoidCallback onStart;
  final VoidCallback onCancel;
  final VoidCallback onReset;

  const _ActionButtons({
    required this.dfuState,
    required this.operationState,
    required this.isConnected,
    required this.onStart,
    required this.onCancel,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    // Completed state - show reset button
    if (dfuState.status == DfuStatus.completed) {
      return Column(
        children: [
          const Icon(
            Icons.check_circle,
            color: AppTheme.successColor,
            size: 64,
          ),
          const SizedBox(height: AppTheme.spacingMd),
          Text(
            'Firmware Update Complete!',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.successColor,
                ),
          ),
          const SizedBox(height: AppTheme.spacingLg),
          FilledButton.icon(
            onPressed: () {
              onReset();
              context.pop();
            },
            icon: const Icon(Icons.done),
            label: const Text('Done'),
          ),
        ],
      );
    }

    // Failed state - show retry/reset buttons
    if (dfuState.status == DfuStatus.failed) {
      return Column(
        children: [
          const Icon(
            Icons.error,
            color: AppTheme.errorColor,
            size: 64,
          ),
          const SizedBox(height: AppTheme.spacingMd),
          Text(
            'Update Failed',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.errorColor,
                ),
          ),
          if (dfuState.errorMessage != null) ...[
            const SizedBox(height: AppTheme.spacingSm),
            Text(
              dfuState.errorMessage!,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: AppTheme.spacingLg),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                onPressed: onReset,
                child: const Text('Reset'),
              ),
              const SizedBox(width: AppTheme.spacingMd),
              FilledButton(
                onPressed: operationState.canStartUpdate ? onStart : null,
                child: const Text('Retry'),
              ),
            ],
          ),
        ],
      );
    }

    // In progress - show cancel button
    if (dfuState.status.isInProgress) {
      return Column(
        children: [
          if (dfuState.status.isCritical)
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning, color: AppTheme.warningColor),
                  SizedBox(width: AppTheme.spacingSm),
                  Expanded(
                    child: Text(
                      'Do not disconnect or close the app during this phase.',
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppTheme.spacingMd),
          if (dfuState.status.canCancel)
            OutlinedButton.icon(
              onPressed: onCancel,
              icon: const Icon(Icons.cancel),
              label: const Text('Cancel Update'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.errorColor,
              ),
            )
          else
            const Text(
              'Update cannot be cancelled at this stage',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
        ],
      );
    }

    // Idle state - show start button
    return Column(
      children: [
        FilledButton.icon(
          onPressed:
              operationState.canStartUpdate && isConnected ? onStart : null,
          icon: const Icon(Icons.system_update),
          label: const Text('Start Update'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(200, 48),
          ),
        ),
        if (!isConnected)
          Padding(
            padding: const EdgeInsets.only(top: AppTheme.spacingSm),
            child: Text(
              'Connect to your watch to start the update',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
          ),
        if (!operationState.hasFirmware)
          Padding(
            padding: const EdgeInsets.only(top: AppTheme.spacingSm),
            child: Text(
              'Select a firmware to continue',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
          ),
      ],
    );
  }
}

