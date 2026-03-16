import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../navigation/app_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/dfu_state.dart';
import '../../../data/models/filesystem_image.dart';
import '../../../data/models/firmware_image.dart';
import '../../../providers/dfu_providers.dart';
import '../../../providers/filesystem_providers.dart';
import '../../../providers/settings_providers.dart';
import '../../../providers/watch_service_provider.dart';
import '../../../services/dfu/firmware_manager.dart';
import '../../widgets/firmware/filesystem_upload_section.dart';

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
  bool _wakelockEnabled = false;
  bool _rotatedMode = false;

  @override
  void initState() {
    super.initState();
    _rotatedMode = ref.read(firmwareManagerProvider).useRotatedFirmware;
    
    // Reset state when entering the screen to clear any stale state
    // Use addPostFrameCallback to ensure ref is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(dfuNotifierProvider.notifier).reset();
      }
    });
    
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
  void dispose() {
    // Ensure wakelock is disabled when leaving the screen
    _disableWakelock();
    super.dispose();
  }

  /// Enable wakelock if setting is enabled and DFU is in progress
  void _updateWakelock(bool dfuInProgress) {
    final keepScreenOn = ref.read(keepScreenOnDuringDfuProvider);
    
    if (dfuInProgress && keepScreenOn && !_wakelockEnabled) {
      WakelockPlus.enable();
      _wakelockEnabled = true;
    } else if (!dfuInProgress && _wakelockEnabled) {
      _disableWakelock();
    }
  }

  void _disableWakelock() {
    if (_wakelockEnabled) {
      WakelockPlus.disable();
      _wakelockEnabled = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dfuState = ref.watch(dfuStateProvider);
    final operationState = ref.watch(dfuNotifierProvider);
    final downloadProgress = ref.watch(downloadProgressProvider);
    final watch = ref.watch(currentWatchProvider);
    final isConnected = ref.watch(isWatchConnectedProvider);
    final fsUploadState = ref.watch(filesystemUploadStateProvider);
    final hasSmp = ref.watch(hasSmpServiceProvider);

    // Manage wakelock based on DFU/upload state
    final isDfuInProgress = dfuState.status.isInProgress || 
                            fsUploadState.status.isInProgress ||
                            operationState.isDownloading;
    _updateWakelock(isDfuInProgress);

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
                        onReconnect: () => context.go(AppRoutes.scan),
                      ),

                    // SMP service not available warning
                    if (isConnected && !hasSmp)
                      const _SmpWarningCard(),

                    // Firmware selection sections (shown when idle)
                    if (dfuState.status == DfuStatus.idle &&
                        !operationState.isDownloading) ...[
                      // GitHub releases
                      _ReleasesSection(
                        boardPrefix: FirmwareManager.boardPrefixFromHardwareVersion(
                          watch?.hardwareVersion,
                        ),
                        onAssetSelected: (release, asset) {
                          ref
                              .read(dfuNotifierProvider.notifier)
                              .downloadReleaseAsset(release, asset);
                        },
                      ),

                      const SizedBox(height: AppTheme.spacingMd),

                      // CI Builds (GitHub Actions)
                      _CIBuildsSection(
                        boardPrefix: FirmwareManager.boardPrefixFromHardwareVersion(
                          watch?.hardwareVersion,
                        ),
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
                      FilesystemUploadSection(
                        onFileSelected: (path) {
                          ref
                              .read(dfuNotifierProvider.notifier)
                              .loadLocalFile(path);
                        },
                      ),

                      const SizedBox(height: AppTheme.spacingMd),

                      // Selected firmware card (shown when firmware is selected)
                      if (operationState.hasFirmware)
                        _SelectedFirmwareCard(
                          image: operationState.downloadedImage!,
                          filesystemImage: operationState.filesystemImage,
                          onClear: () =>
                              ref.read(dfuNotifierProvider.notifier).reset(),
                        ),

                      const SizedBox(height: AppTheme.spacingSm),

                      // Rotated firmware option (subtle)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spacingSm,
                            vertical: AppTheme.spacingSm / 2,
                          ),
                          child: Row(
                            children: [
                              Checkbox(
                                value: _rotatedMode,
                                visualDensity: VisualDensity.compact,
                                onChanged: (value) {
                                  final enabled = value ?? false;
                                  setState(() => _rotatedMode = enabled);
                                  ref.read(firmwareManagerProvider).useRotatedFirmware = enabled;
                                },
                              ),
                              Expanded(
                                child: Text(
                                  'Use rotated display firmware',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: AppTheme.textSecondary,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    // Progress/status card (shown during download or upload)
                    _StatusCard(
                      dfuState: dfuState,
                      downloadProgress: downloadProgress,
                    ),

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
                      hasSmpService: hasSmp,
                      onStartFirmware: () =>
                          ref.read(dfuNotifierProvider.notifier).startUpdate(),
                      onStartFilesystem: () =>
                          ref.read(dfuNotifierProvider.notifier).startFilesystemUpload(),
                      onStartBoth: () =>
                          ref.read(dfuNotifierProvider.notifier).startBothUpdates(),
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

class _SmpWarningCard extends ConsumerStatefulWidget {
  const _SmpWarningCard();

  @override
  ConsumerState<_SmpWarningCard> createState() => _SmpWarningCardState();
}

class _SmpWarningCardState extends ConsumerState<_SmpWarningCard> {
  bool _isChecking = false;
  bool _recheckFailed = false;

  Future<void> _recheck() async {
    setState(() {
      _isChecking = true;
      _recheckFailed = false;
    });
    try {
      final service = ref.read(watchServiceProvider);
      final found = await service.rediscoverServices();
      if (mounted) {
        if (found) {
          // Force the provider to re-evaluate with updated services
          ref.invalidate(hasSmpServiceProvider);
        } else {
          setState(() => _recheckFailed = true);
        }
      }
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.warningColor.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber, color: AppTheme.warningColor),
                const SizedBox(width: AppTheme.spacingSm),
                Expanded(
                  child: Text(
                    'Update Mode Not Enabled',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppTheme.warningColor,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingSm),
            Text(
              'The SMP service is not available on this watch. '
              'To enable firmware updates:\n'
              '1. On the watch, go to Apps → Update\n'
              '2. Set USB and/or BLE to ON\n'
              '3. Tap "Re-check" below',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_recheckFailed) ...[
              const SizedBox(height: AppTheme.spacingSm),
              Text(
                'SMP still not detected. Try disconnecting and reconnecting '
                'after enabling update mode on the watch.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.errorColor,
                    ),
              ),
            ],
            const SizedBox(height: AppTheme.spacingSm),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _isChecking ? null : _recheck,
                icon: _isChecking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 18),
                label: Text(_isChecking ? 'Checking...' : 'Re-check'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends ConsumerWidget {
  final DfuState dfuState;
  final DownloadProgress downloadProgress;

  const _StatusCard({
    required this.dfuState,
    required this.downloadProgress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDownloading = downloadProgress.status.isInProgress;
    final isDfuInProgress = dfuState.status.isInProgress;
    final fsUploadState = ref.watch(filesystemUploadStateProvider);
    final isFsUploading = fsUploadState.status.isInProgress;
    final operationState = ref.watch(dfuNotifierProvider);

    if (!isDownloading && !isDfuInProgress && !isFsUploading) {
      return const SizedBox.shrink();
    }

    // Determine which operation to show
    String statusTitle;
    double progress;
    String bytesText;
    String percentText;
    String? speedText;
    String? timeRemainingText;
    String? subStatusText;

    if (isDownloading) {
      statusTitle = 'Downloading...';
      progress = downloadProgress.progress;
      bytesText = '${downloadProgress.formattedBytesReceived} / ${downloadProgress.formattedTotalBytes}';
      percentText = '${downloadProgress.progressPercent}%';
    } else if (isFsUploading) {
      statusTitle = 'Uploading Filesystem...';
      progress = fsUploadState.progress;
      bytesText = '${fsUploadState.formattedBytesTransferred} / ${fsUploadState.formattedTotalBytes}';
      percentText = '${fsUploadState.progressPercent}%';
      speedText = 'Speed: ${fsUploadState.formattedSpeed}';
      timeRemainingText = 'Remaining: ${fsUploadState.formattedTimeRemaining}';
      subStatusText = fsUploadState.imageName;
    } else {
      statusTitle = dfuState.status.statusText;
      progress = dfuState.progress;
      bytesText = '${dfuState.formattedBytesTransferred} / ${dfuState.formattedTotalBytes}';
      percentText = '${dfuState.progressPercent}%';
      if (dfuState.status == DfuStatus.uploading) {
        speedText = 'Speed: ${dfuState.formattedSpeed}';
        timeRemainingText = 'Remaining: ${dfuState.formattedTimeRemaining}';
      }
      subStatusText = dfuState.currentImageName;
    }

    // Show step indicator for "both" updates
    if (operationState.isBothUpdating && operationState.totalSteps > 0) {
      statusTitle = operationState.currentStepDescription;
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
                      : (isFsUploading
                          ? DfuStatus.uploading
                          : (isDownloading ? DfuStatus.preparing : DfuStatus.idle)),
                ),
                const SizedBox(width: AppTheme.spacingSm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusTitle,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (subStatusText != null)
                        Text(
                          subStatusText,
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
              value: progress,
              backgroundColor: AppTheme.surfaceColor,
            ),

            const SizedBox(height: AppTheme.spacingSm),

            // Progress details
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(bytesText, style: Theme.of(context).textTheme.bodySmall),
                Text(percentText, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),

            // Speed and time remaining
            if (speedText != null && timeRemainingText != null)
              Padding(
                padding: const EdgeInsets.only(top: AppTheme.spacingSm),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(speedText, style: Theme.of(context).textTheme.bodySmall),
                    Text(timeRemainingText, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),

            // Multi-image progress (DFU only)
            if (isDfuInProgress && dfuState.totalImages > 1)
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
  final FilesystemImage? filesystemImage;
  final VoidCallback onClear;

  const _SelectedFirmwareCard({
    required this.image,
    required this.filesystemImage,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.primaryColor.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                        '${image.formattedSize} • ${image.displayName}',
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
            // Filesystem image indicator
            if (filesystemImage != null) ...[
              const SizedBox(height: AppTheme.spacingSm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingSm,
                  vertical: AppTheme.spacingSm / 2,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  border: Border.all(
                    color: AppTheme.successColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.storage,
                      size: 16,
                      color: AppTheme.successColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Filesystem image included (${filesystemImage!.formattedSize})',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.successColor,
                          ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: AppTheme.spacingSm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingSm,
                  vertical: AppTheme.spacingSm / 2,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.textSecondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: AppTheme.textSecondary.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Firmware only (no filesystem image)',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReleasesSection extends ConsumerWidget {
  final void Function(GitHubRelease, ReleaseAsset) onAssetSelected;
  final String? boardPrefix;

  const _ReleasesSection({required this.onAssetSelected, this.boardPrefix});

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
              return SizedBox(
                width: double.infinity,
                child: Card(
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
                ),
              );
            }
            return Column(
              children: releases
                  .take(5)
                  .map((release) => _ReleaseCard(
                        release: release,
                        boardPrefix: boardPrefix,
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
  final String? boardPrefix;
  final void Function(ReleaseAsset) onAssetSelected;

  const _ReleaseCard({
    required this.release,
    required this.onAssetSelected,
    this.boardPrefix,
  });

  @override
  Widget build(BuildContext context) {
    final compatibleAssets = FirmwareManager.filterCompatibleAssets(
      release.assets,
      boardPrefix,
    );

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
          '${release.version} • ${compatibleAssets.length} builds • ${release.formattedDate}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          // If exactly one compatible asset, download it directly
          if (boardPrefix != null && compatibleAssets.length == 1) {
            onAssetSelected(compatibleAssets.first);
          } else {
            _showAssetSelectionDialog(context, compatibleAssets);
          }
        },
      ),
    );
  }

  void _showAssetSelectionDialog(BuildContext context, List<ReleaseAsset> assetsToShow) {
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
              Text(
                boardPrefix != null
                    ? 'Showing builds for $boardPrefix:'
                    : 'Choose the build matching your hardware:',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: AppTheme.spacingSm),
              ...assetsToShow.map((asset) => _AssetTile(
                    asset: asset,
                    isCompatible: FirmwareManager.isAssetCompatible(
                      asset.name,
                      boardPrefix,
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      onAssetSelected(asset);
                    },
                  )),
            ],
          ),
        ),
        actions: [
          // Allow showing all assets if filtering is active
          if (boardPrefix != null && assetsToShow.length != release.assets.length)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showAssetSelectionDialog(context, release.assets);
              },
              child: const Text('Show All'),
            ),
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
  final bool isCompatible;

  const _AssetTile({
    required this.asset,
    required this.onTap,
    this.isCompatible = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingSm),
      child: ListTile(
        dense: true,
        leading: Icon(
          Icons.folder_zip,
          color: isCompatible ? AppTheme.primaryColor : AppTheme.textSecondary,
        ),
        title: Text(
          asset.displayName,
          style: TextStyle(
            fontSize: 13,
            color: isCompatible ? null : AppTheme.textSecondary,
          ),
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
  final String? boardPrefix;

  const _CIBuildsSection({
    required this.onOpenInBrowser,
    this.boardPrefix,
  });

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
              return SizedBox(
                width: double.infinity,
                child: Card(
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
                            boardPrefix: widget.boardPrefix,
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
  final String? boardPrefix;
  final bool isExpanded;
  final VoidCallback onToggle;
  final void Function(WorkflowArtifact) onOpenInBrowser;

  const _WorkflowRunTile({
    required this.run,
    required this.isExpanded,
    required this.onToggle,
    required this.onOpenInBrowser,
    this.boardPrefix,
  });

  @override
  Widget build(BuildContext context) {
    final filteredArtifacts = FirmwareManager.filterCompatibleArtifacts(
      run.artifacts,
      boardPrefix,
    );
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
                            '${filteredArtifacts.length} artifact${filteredArtifacts.length != 1 ? 's' : ''}',
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
              children: filteredArtifacts.map((artifact) {
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

class _ActionButtons extends ConsumerWidget {
  final DfuState dfuState;
  final DfuOperationState operationState;
  final bool isConnected;
  final bool hasSmpService;
  final VoidCallback onStartFirmware;
  final VoidCallback onStartFilesystem;
  final VoidCallback onStartBoth;
  final VoidCallback onCancel;
  final VoidCallback onReset;

  const _ActionButtons({
    required this.dfuState,
    required this.operationState,
    required this.isConnected,
    required this.hasSmpService,
    required this.onStartFirmware,
    required this.onStartFilesystem,
    required this.onStartBoth,
    required this.onCancel,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fsUploadState = ref.watch(filesystemUploadStateProvider);
    final isFsUploading = fsUploadState.status.isInProgress;
    final isFsCompleted = fsUploadState.status == FilesystemUploadStatus.completed;
    final isFsFailed = fsUploadState.status == FilesystemUploadStatus.failed;
    
    // During "both" update, only show completion when firmware DFU finishes (not just FS)
    final isBothUpdating = operationState.isBothUpdating;
    final showFsOnlyComplete = isFsCompleted && !isBothUpdating && dfuState.status == DfuStatus.idle;

    // Completed state - show reset button
    if (dfuState.status == DfuStatus.completed || showFsOnlyComplete) {
      final isFullComplete = dfuState.status == DfuStatus.completed;
      return Column(
        children: [
          const Icon(
            Icons.check_circle,
            color: AppTheme.successColor,
            size: 64,
          ),
          const SizedBox(height: AppTheme.spacingMd),
          Text(
            isFullComplete ? 'Update Complete!' : 'Filesystem Upload Complete!',
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
    if (dfuState.status == DfuStatus.failed || isFsFailed) {
      final errorMessage = dfuState.status == DfuStatus.failed
          ? dfuState.errorMessage
          : fsUploadState.errorMessage;
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
          if (errorMessage != null) ...[
            const SizedBox(height: AppTheme.spacingSm),
            Text(
              errorMessage,
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
                onPressed: operationState.canStartFirmwareUpdate ? onStartFirmware : null,
                child: const Text('Retry'),
              ),
            ],
          ),
        ],
      );
    }

    // Downloading state - show cancel button only
    if (operationState.isDownloading) {
      return OutlinedButton.icon(
        onPressed: onCancel,
        icon: const Icon(Icons.cancel),
        label: const Text('Cancel Download'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.errorColor,
        ),
      );
    }

    // In progress - show cancel button
    if (dfuState.status.isInProgress || isFsUploading || operationState.isBothUpdating) {
      final isCritical = dfuState.status.isCritical;
      final canCancel = dfuState.status.canCancel || isFsUploading;
      
      return Column(
        children: [
          if (isCritical)
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
          if (canCancel)
            OutlinedButton.icon(
              onPressed: onCancel,
              icon: const Icon(Icons.cancel),
              label: const Text('Cancel'),
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

    // Idle state - show start buttons
    return Column(
      children: [
        // Start Both button (shown when both are available)
        if (operationState.hasBoth) ...[
          FilledButton.icon(
            onPressed: operationState.canStartBoth && isConnected && hasSmpService ? onStartBoth : null,
            icon: const Icon(Icons.playlist_play),
            label: const Text('Start Both (FS + FW)'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              backgroundColor: AppTheme.successColor,
            ),
          ),
          const SizedBox(height: AppTheme.spacingSm),
          Text(
            'Uploads filesystem first, then firmware',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
          const SizedBox(height: AppTheme.spacingMd),
          const Divider(),
          const SizedBox(height: AppTheme.spacingSm),
          Text(
            'Or update individually:',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
          const SizedBox(height: AppTheme.spacingSm),
        ],
        
        // Individual buttons row
        Row(
          children: [
            // Firmware Update button
            Expanded(
              child: OutlinedButton.icon(
                onPressed: operationState.canStartFirmwareUpdate && isConnected && hasSmpService
                    ? onStartFirmware
                    : null,
                icon: const Icon(Icons.system_update, size: 18),
                label: const Text('FW Update'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                ),
              ),
            ),
            const SizedBox(width: AppTheme.spacingSm),
            // Filesystem Upload button
            Expanded(
              child: OutlinedButton.icon(
                onPressed: operationState.canStartFilesystemUpload && isConnected && hasSmpService
                    ? onStartFilesystem
                    : null,
                icon: const Icon(Icons.storage, size: 18),
                label: const Text('FS Upload'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                ),
              ),
            ),
          ],
        ),
        
        // Status messages
        if (!isConnected)
          Padding(
            padding: const EdgeInsets.only(top: AppTheme.spacingMd),
            child: Text(
              'Connect to your watch to start',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
          ),
        if (!operationState.hasFirmware && !operationState.hasFilesystem)
          Padding(
            padding: const EdgeInsets.only(top: AppTheme.spacingMd),
            child: Text(
              'Select a firmware package to continue',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
          ),
      ],
    );
  }
}

