import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/filesystem_image.dart';
import '../../../data/models/llext_app.dart';
import '../../../providers/filesystem_providers.dart';
import '../../../providers/llext_providers.dart';
import '../../../providers/watch_service_provider.dart';

/// Screen for managing optional LLEXT apps on the watch.
///
/// The watch must be in firmware-update mode (SMP enabled via the watch's
/// "Update Firmware" menu) for MCUmgr filesystem commands to work.
///
/// Features:
/// - Probe the watch to detect which known apps are installed.
/// - Install a bundled app via MCUmgr file upload.
/// - Remove placeholder (delete via MCUmgr not yet available in this Zephyr version).
class AppsScreen extends ConsumerStatefulWidget {
  const AppsScreen({super.key});

  @override
  ConsumerState<AppsScreen> createState() => _AppsScreenState();
}

class _AppsScreenState extends ConsumerState<AppsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _showLogs = false;
  final List<String> _logs = [];
  bool _isRefreshing = false;
  bool _wakelockEnabled = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Listen to service logs.
      ref.read(llextAppServiceProvider).logStream.listen((log) {
        if (mounted) setState(() => _logs.add(log));
      });
      // Reset upload service state from any previous operation.
      ref.read(filesystemUploadServiceProvider).reset();
      // Auto-refresh installed apps when screen opens.
      unawaited(_refreshApps());
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _disableWakelock();
    super.dispose();
  }

  void _disableWakelock() {
    if (_wakelockEnabled) {
      WakelockPlus.disable();
      _wakelockEnabled = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _refreshApps() async {
    final connection = ref.read(watchConnectionProvider);
    final deviceId = connection.watchId;

    if (deviceId.isEmpty) {
      _showError('No watch connected.');
      return;
    }

    setState(() {
      _isRefreshing = true;
      _logs.clear();
    });

    final watchService = ref.read(watchServiceProvider);

    try {
      // Enable SMP so MCUmgr filesystem status commands work.
      await watchService.enableSmp();
      await Future<void>.delayed(const Duration(seconds: 2));
      await watchService.rediscoverServices();

      await ref
          .read(llextAppServiceProvider)
          .refreshInstalledApps(deviceId);
    } catch (e) {
      if (mounted) _showError('Refresh failed: $e');
    } finally {
      // Disable SMP after probing.
      try {
        await watchService.disableSmp();
      } catch (_) {}
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _installApp(LlextAppDefinition definition) async {
    final connection = ref.read(watchConnectionProvider);
    final deviceId = connection.watchId;

    if (deviceId.isEmpty) {
      _showError('No watch connected.');
      return;
    }

    // Enable wakelock during install.
    unawaited(WakelockPlus.enable());
    _wakelockEnabled = true;

    try {
      // Auto-enable SMP on the watch before starting the MCUmgr upload.
      final watchService = ref.read(watchServiceProvider);
      await watchService.enableSmp();
      // Give the watch a moment to register the SMP transport.
      await Future<void>.delayed(const Duration(seconds: 2));
      // Re-discover services so the app sees the SMP service.
      await watchService.rediscoverServices();
      ref.invalidate(hasSmpServiceProvider);

      // Reset upload state so the progress widget shows fresh.
      ref.read(filesystemUploadServiceProvider).reset();

      await ref.read(llextAppServiceProvider).installApp(
            deviceId: deviceId,
            definition: definition,
          );

      // Refresh list after successful install (while SMP is still enabled).
      await ref
          .read(llextAppServiceProvider)
          .refreshInstalledApps(deviceId);

      // Disable SMP now that we're done with MCUmgr operations.
      await watchService.disableSmp();
    } catch (e) {
      // Try to disable SMP even on failure.
      try {
        await ref.read(watchServiceProvider).disableSmp();
      } catch (_) {}
      if (mounted) _showError('Install failed: $e');
    } finally {
      _disableWakelock();
    }
  }

  Future<void> _removeApp(LlextAppDefinition definition) async {
    final connection = ref.read(watchConnectionProvider);
    final deviceId = connection.watchId;

    if (deviceId.isEmpty) {
      _showError('No watch connected.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${definition.name}?'),
        content: const Text(
          'This will delete the app from the watch filesystem.\n\n'
          'The watch needs to be restarted for the change to take effect.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ref
          .read(llextAppServiceProvider)
          .removeApp(appId: definition.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${definition.name} removed. Restart the watch to apply.'),
            backgroundColor: AppTheme.textSecondary,
          ),
        );
      }
    } catch (e) {
      if (mounted) _showError('Remove failed: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorColor,
      ),
    );
  }

  Future<void> _resetWatch() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restart Watch?'),
        content: const Text(
          'The watch will reboot. You will be briefly disconnected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restart'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ref.read(watchServiceProvider).resetWatch();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Restart command sent to watch.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) _showError('Restart failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Listen for disconnection and navigate back to home when it happens.
    ref.listen<bool>(isWatchConnectedProvider, (prev, next) {
      if (prev == true && next == false && mounted) {
        context.go('/');
      }
    });

    final fsUploadState = ref.watch(filesystemUploadStateProvider);
    final isUploading = fsUploadState.status == FilesystemUploadStatus.uploading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Watch Apps'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.install_mobile), text: 'Installed'),
            Tab(icon: Icon(Icons.extension), text: 'Available'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: 'Restart watch',
            onPressed: isUploading ? null : _resetWatch,
          ),
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'Refresh installed apps',
            onPressed: _isRefreshing || isUploading ? null : _refreshApps,
          ),
          IconButton(
            icon: Icon(_showLogs ? Icons.terminal : Icons.terminal_outlined),
            tooltip: 'Toggle logs',
            onPressed: () => setState(() => _showLogs = !_showLogs),
          ),
        ],
      ),
      body: Column(
        children: [
          // Upload progress (shown when an install is running).
          if (isUploading || fsUploadState.status == FilesystemUploadStatus.completed ||
              fsUploadState.status == FilesystemUploadStatus.failed)
            _UploadProgressCard(state: fsUploadState),

          // Tab content.
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _InstalledTab(
                  onRemove: _removeApp,
                  isUploading: isUploading,
                ),
                _AvailableTab(
                  onInstall: _installApp,
                  isUploading: isUploading,
                ),
              ],
            ),
          ),

          // Log panel (collapsible).
          if (_showLogs) _LogPanel(logs: _logs),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Widgets
// ---------------------------------------------------------------------------

class _UploadProgressCard extends StatelessWidget {
  final FilesystemUploadState state;

  const _UploadProgressCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final isUploading = state.status == FilesystemUploadStatus.uploading;
    final isDone = state.status == FilesystemUploadStatus.completed;
    final isFailed = state.status == FilesystemUploadStatus.failed;

    return Card(
      margin: const EdgeInsets.all(AppTheme.spacingSm),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isDone
                      ? Icons.check_circle
                      : isFailed
                          ? Icons.error
                          : Icons.upload,
                  color: isDone
                      ? AppTheme.successColor
                      : isFailed
                          ? AppTheme.errorColor
                          : AppTheme.primaryColor,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  isUploading
                      ? 'Installing${state.imageName != null ? ' ${state.imageName}' : ''}…'
                      : isDone
                          ? 'Install complete'
                          : isFailed
                              ? 'Install failed'
                              : '',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (isUploading && state.speedBytesPerSecond > 0) ...[
                  const Spacer(),
                  Text(
                    '${(state.speedBytesPerSecond / 1024).toStringAsFixed(1)} KB/s',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                ],
              ],
            ),
            if (isUploading) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: state.progress,
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
              const SizedBox(height: 4),
              Text(
                '${(state.progress * 100).toStringAsFixed(1)}%  '
                '${_formatBytes(state.bytesTransferred)} / ${_formatBytes(state.totalBytes)}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppTheme.textSecondary),
              ),
            ],
            if (isFailed && state.errorMessage != null) ...[
              const SizedBox(height: 4),
              Text(
                state.errorMessage!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.errorColor,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '$bytes B';
  }
}

// ---------------------------------------------------------------------------
// Tab: Installed
// ---------------------------------------------------------------------------

class _InstalledTab extends ConsumerWidget {
  final void Function(LlextAppDefinition) onRemove;
  final bool isUploading;

  const _InstalledTab({required this.onRemove, required this.isUploading});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final installed = ref.watch(installedLlextAppsProvider);

    if (installed.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.install_mobile_outlined, size: 64, color: AppTheme.textSecondary),
            SizedBox(height: 16),
            Text(
              'No apps installed',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            SizedBox(height: 8),
            Text(
              'Tap Refresh to detect installed apps, or\n'
              'go to "Available" to install one.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spacingSm),
      itemCount: installed.length,
      itemBuilder: (_, i) => _AppCard(
        state: installed[i],
        action: _AppCardAction.remove,
        onAction: () => onRemove(installed[i].definition),
        actionEnabled: !isUploading && !installed[i].isInstalling,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab: Available
// ---------------------------------------------------------------------------

class _AvailableTab extends ConsumerWidget {
  final void Function(LlextAppDefinition) onInstall;
  final bool isUploading;

  const _AvailableTab({required this.onInstall, required this.isUploading});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final available = ref.watch(availableLlextAppsProvider);

    if (available.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: AppTheme.successColor),
            SizedBox(height: 16),
            Text(
              'All bundled apps are installed!',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spacingSm),
      itemCount: available.length,
      itemBuilder: (_, i) => _AppCard(
        state: available[i],
        action: _AppCardAction.install,
        onAction: () => onInstall(available[i].definition),
        actionEnabled: !isUploading && !available[i].isInstalling,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// App card
// ---------------------------------------------------------------------------

enum _AppCardAction { install, remove }

class _AppCard extends StatelessWidget {
  final LlextAppState state;
  final _AppCardAction action;
  final VoidCallback onAction;
  final bool actionEnabled;

  const _AppCard({
    required this.state,
    required this.action,
    required this.onAction,
    required this.actionEnabled,
  });

  @override
  Widget build(BuildContext context) {
    final def = state.definition;
    final isInstalling = state.isInstalling;

    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingSm),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.extension, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        def.name,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          _CategoryChip(category: def.category),
                          if (state.watchFileSizeBytes != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              _formatBytes(state.watchFileSizeBytes!),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppTheme.textSecondary),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (isInstalling)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  _ActionButton(
                    action: action,
                    enabled: actionEnabled,
                    onPressed: onAction,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              def.description,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '$bytes B';
  }
}

class _CategoryChip extends StatelessWidget {
  final String category;

  const _CategoryChip({required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        category,
        style: const TextStyle(
          fontSize: 10,
          color: AppTheme.primaryColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final _AppCardAction action;
  final bool enabled;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.action,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (action == _AppCardAction.install) {
      return FilledButton.icon(
        onPressed: enabled ? onPressed : null,
        icon: const Icon(Icons.download, size: 16),
        label: const Text('Install'),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          textStyle: const TextStyle(fontSize: 13),
        ),
      );
    } else {
      return OutlinedButton.icon(
        onPressed: enabled ? onPressed : null,
        icon: const Icon(Icons.delete_outline, size: 16),
        label: const Text('Remove'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.errorColor,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          textStyle: const TextStyle(fontSize: 13),
        ),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Log panel
// ---------------------------------------------------------------------------

class _LogPanel extends StatelessWidget {
  final List<String> logs;

  const _LogPanel({required this.logs});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      color: Colors.black87,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                const Text(
                  'Log',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Text(
                  '${logs.length} entries',
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white12),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              reverse: true,
              itemCount: logs.length,
              itemBuilder: (_, i) => Text(
                logs[logs.length - 1 - i],
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
