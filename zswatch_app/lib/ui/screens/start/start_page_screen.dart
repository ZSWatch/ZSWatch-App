import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/database/app_database.dart';
import '../../../data/models/connection_state.dart';
import '../../../providers/auto_reconnect_provider.dart';
import '../../../providers/ble_providers.dart';
import '../../../providers/watch_providers.dart' as db;
import '../../../providers/watch_service_provider.dart';
import '../../widgets/connection_status_pill.dart';
import '../../widgets/watch_config_dialog.dart';

/// Start page showing stored watches and option to add new watch (FR-067 to FR-070)
///
/// This is the entry point of the app, displaying:
/// - List of previously paired watches with connection status
/// - Option to connect to a stored watch (tap to connect)
/// - Option to add a new watch (scan screen)
/// - Auto-reconnect status indicator when active
class StartPageScreen extends ConsumerStatefulWidget {
  const StartPageScreen({super.key});

  @override
  ConsumerState<StartPageScreen> createState() => _StartPageScreenState();
}

class _StartPageScreenState extends ConsumerState<StartPageScreen> {
  bool _isConnecting = false;
  String? _connectingWatchId;
  bool _autoReconnectStarted = false;

  @override
  void initState() {
    super.initState();
    // Start auto-reconnect on launch (FR-071)
    // Use post-frame callback to ensure providers are ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAutoReconnectIfEnabled();
    });
  }

  Future<void> _startAutoReconnectIfEnabled() async {
    // Only start once per widget instance
    if (_autoReconnectStarted) return;
    _autoReconnectStarted = true;
    
    final enabled = await ref.read(autoReconnectEnabledProvider.future);
    if (enabled && mounted) {
      final notifier = ref.read(autoReconnectNotifierProvider.notifier);
      unawaited(notifier.startAutoReconnect());
    }
  }

  Future<void> _connectToWatch(WatchEntity watch) async {
    if (_isConnecting) return;

    setState(() {
      _isConnecting = true;
      _connectingWatchId = watch.id;
    });

    // Cancel any ongoing auto-reconnect (FR-073)
    ref.read(autoReconnectNotifierProvider.notifier).cancel();

    try {
      final watchService = ref.read(watchServiceProvider);
      await watchService.connectById(watch.id);

      // Note: lastConnectedAt is now updated centrally by watchInfoPersistenceProvider
      // when connection state becomes connected

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connected to ${watch.customName ?? watch.name}'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        // Navigate to dashboard on successful connection (FR-074)
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to connect: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _connectingWatchId = null;
        });
      }
    }
  }

  void _navigateToScan() {
    // Cancel auto-reconnect when user wants to add new watch (FR-073)
    ref.read(autoReconnectNotifierProvider.notifier).cancel();
    context.push('/scan');
  }

  Future<void> _deleteWatch(WatchEntity watch) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Watch'),
        content: Text(
          'Remove "${watch.customName ?? watch.name}" from saved watches?\n\n'
          'You can pair it again later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(db.watchNotifierProvider.notifier).deleteWatch(watch.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${watch.customName ?? watch.name} removed'),
          ),
        );
      }
    }
  }

  /// Open the watch config dialog for renaming or forgetting a watch (T116)
  Future<void> _openWatchConfig(WatchEntity watch) async {
    final wasDeleted = await WatchConfigDialog.show(
      context: context,
      watch: watch,
      onRename: (watchId, customName) async {
        await ref.read(db.watchNotifierProvider.notifier).renameWatch(watchId, customName);
        if (mounted) {
          final newName = customName ?? watch.name;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Watch renamed to "$newName"'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      },
      onForget: (watchId) async {
        // Disconnect if currently connected to this watch
        final watchService = ref.read(watchServiceProvider);
        final currentDeviceId = watchService.currentConnection.watchId;
        if (currentDeviceId == watchId) {
          await watchService.disconnect();
        }
        
        // Forget the watch (removes from DB and unbonds BLE)
        await ref.read(db.watchNotifierProvider.notifier).forgetWatch(watchId);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${watch.customName ?? watch.name} forgotten'),
            ),
          );
        }
      },
    );

    // If watch was deleted/forgotten, the list will auto-refresh via provider
    if (wasDeleted == true && mounted) {
      // Already handled in onForget callback
    }
  }

  @override
  Widget build(BuildContext context) {
    final watchesAsync = ref.watch(db.allWatchesProvider);

    // Navigate to dashboard when connected (FR-074)
    ref.listen(connectionStateProvider, (previous, next) {
      if (next == WatchConnectionState.connected && mounted) {
        context.go('/');
      }
    });

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: SvgPicture.asset(
          'assets/images/ZSWatch_Text.svg',
          height: 24,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: watchesAsync.when(
              data: (watches) => watches.isEmpty
                  ? _buildEmptyState()
                  : _buildWatchList(watches),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _buildErrorState(error.toString()),
            ),
          ),
        ],
      ),
      // Add new watch FAB
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToScan,
        icon: const Icon(Icons.add),
        label: const Text('Add Watch'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/images/ZSWatch_Logo.svg',
              width: 80,
              height: 80,
            ),
            const SizedBox(height: AppTheme.spacingLg),
            Text(
              'No Watches Paired',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacingMd),
            Text(
              'Add your ZSWatch to get started.\n'
              'Make sure your watch is turned on and nearby.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWatchList(List<WatchEntity> watches) {
    // Sort: connected first, then by last connected time
    final sortedWatches = List<WatchEntity>.from(watches);
    sortedWatches.sort((a, b) {
      // Primary watch first
      if (a.isPrimary && !b.isPrimary) return -1;
      if (!a.isPrimary && b.isPrimary) return 1;
      
      // Then by last connected time (most recent first)
      if (a.lastConnectedAt == null && b.lastConnectedAt == null) return 0;
      if (a.lastConnectedAt == null) return 1;
      if (b.lastConnectedAt == null) return -1;
      return b.lastConnectedAt!.compareTo(a.lastConnectedAt!);
    });

    return ListView.builder(
      padding: const EdgeInsets.only(
        top: AppTheme.spacingMd,
        bottom: 88, // Space for FAB
      ),
      itemCount: sortedWatches.length,
      itemBuilder: (context, index) {
        final watch = sortedWatches[index];
        return _WatchListTile(
          watch: watch,
          isConnecting: _connectingWatchId == watch.id,
          onTap: () => _connectToWatch(watch),
          onConfig: () => _openWatchConfig(watch),
        );
      },
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AppTheme.errorColor,
            ),
            const SizedBox(height: AppTheme.spacingMd),
            Text(
              'Error Loading Watches',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppTheme.spacingSm),
            Text(
              error,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual watch list tile (FR-067, FR-068, T116)
class _WatchListTile extends StatelessWidget {
  final WatchEntity watch;
  final bool isConnecting;
  final VoidCallback onTap;
  final VoidCallback onConfig;

  const _WatchListTile({
    required this.watch,
    required this.isConnecting,
    required this.onTap,
    required this.onConfig,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = watch.customName ?? watch.name;
    
    return ListTile(
        leading: _buildLeadingIcon(),
        title: Row(
          children: [
            Expanded(
              child: Text(
                displayName,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            if (watch.isPrimary)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Primary',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        subtitle: _buildSubtitle(),
        trailing: _buildTrailing(),
        onTap: isConnecting ? null : onTap,
    );
  }

  Widget _buildTrailing() {
    if (isConnecting) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Config/Settings button (T116)
        IconButton(
          icon: const Icon(
            Icons.settings,
            color: AppTheme.textSecondary,
            size: 28,
          ),
          onPressed: onConfig,
          tooltip: 'Watch Settings',
        ),
        const Icon(
          Icons.chevron_right,
          color: AppTheme.textSecondary,
        ),
      ],
    );
  }

  Widget _buildLeadingIcon() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: isConnecting
          ? const Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Stack(
              alignment: Alignment.center,
              children: [
                SvgPicture.asset(
                  'assets/images/ZSWatch_Logo.svg',
                  width: 28,
                  height: 28,
                ),
                if (watch.batteryLevel != null)
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: _buildBatteryIndicator(),
                  ),
              ],
            ),
    );
  }

  Widget _buildBatteryIndicator() {
    final level = watch.batteryLevel ?? 0;
    final color = AppTheme.getBatteryColor(level);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        '$level%',
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSubtitle() {
    final parts = <String>[];
    
    // Show firmware version if available
    if (watch.firmwareVersion != null) {
      parts.add('v${watch.firmwareVersion}');
    }
    
    // Show last connected time
    if (watch.lastConnectedAt != null) {
      parts.add(_formatLastConnected(watch.lastConnectedAt!));
    }
    
    // Show ID as fallback
    if (parts.isEmpty) {
      parts.add(watch.id);
    }
    
    return Text(
      parts.join(' • '),
      style: const TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 12,
      ),
    );
  }

  String _formatLastConnected(DateTime lastConnected) {
    final now = DateTime.now();
    final diff = now.difference(lastConnected);
    
    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${lastConnected.day}/${lastConnected.month}/${lastConnected.year}';
    }
  }
}
