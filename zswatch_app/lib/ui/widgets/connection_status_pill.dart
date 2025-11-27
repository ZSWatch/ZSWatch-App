import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/connection.dart';
import '../../data/models/connection_state.dart';
import '../../providers/ble_providers.dart';

/// A pill-shaped widget that displays the current BLE connection status
///
/// Shows different colors and text based on connection state:
/// - Green: Connected
/// - Amber: Connecting/Reconnecting
/// - Gray: Disconnected
/// - Blue: Scanning
class ConnectionStatusPill extends ConsumerWidget {
  /// Optional callback when pill is tapped
  final VoidCallback? onTap;

  /// Whether to show the device name when connected
  final bool showDeviceName;

  /// Whether to show an icon
  final bool showIcon;

  /// Compact mode (smaller size)
  final bool compact;

  const ConnectionStatusPill({
    super.key,
    this.onTap,
    this.showDeviceName = false,
    this.showIcon = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connection = ref.watch(currentConnectionProvider);

    final (color, text, icon) = _getStateInfo(connection);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? AppTheme.spacingSm : AppTheme.spacingMd,
          vertical: compact ? AppTheme.spacingXs : AppTheme.spacingSm,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showIcon) ...[
              _buildStatusIcon(icon, color),
              SizedBox(width: compact ? 4 : 6),
            ],
            Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: compact ? 12 : 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(IconData icon, Color color) {
    return Icon(
      icon,
      size: compact ? 14 : 16,
      color: color,
    );
  }

  (Color, String, IconData) _getStateInfo(Connection? connection) {
    if (connection == null) {
      return (
        AppTheme.disconnected,
        'Disconnected',
        Icons.bluetooth_disabled_rounded,
      );
    }

    switch (connection.state) {
      case WatchConnectionState.connected:
        return (
          AppTheme.connected,
          showDeviceName ? 'Connected' : 'Connected',
          Icons.bluetooth_connected_rounded,
        );
      case WatchConnectionState.connecting:
        return (
          AppTheme.connecting,
          'Connecting...',
          Icons.bluetooth_searching_rounded,
        );
      case WatchConnectionState.bonding:
        return (
          AppTheme.connecting,
          'Pairing...',
          Icons.bluetooth_searching_rounded,
        );
      case WatchConnectionState.discoveringServices:
        return (
          AppTheme.connecting,
          'Discovering...',
          Icons.bluetooth_searching_rounded,
        );
      case WatchConnectionState.negotiating:
        return (
          AppTheme.connecting,
          'Optimizing...',
          Icons.bluetooth_searching_rounded,
        );
      case WatchConnectionState.syncing:
        return (
          AppTheme.connecting,
          'Syncing...',
          Icons.sync_rounded,
        );
      case WatchConnectionState.reconnecting:
        return (
          AppTheme.connecting,
          'Reconnecting...',
          Icons.bluetooth_searching_rounded,
        );
      case WatchConnectionState.scanning:
        return (
          AppTheme.infoColor,
          'Scanning...',
          Icons.search_rounded,
        );
      case WatchConnectionState.disconnecting:
        return (
          AppTheme.disconnected,
          'Disconnecting...',
          Icons.bluetooth_disabled_rounded,
        );
      case WatchConnectionState.error:
        return (
          AppTheme.errorColor,
          'Error',
          Icons.error_outline_rounded,
        );
      case WatchConnectionState.disconnected:
        return (
          AppTheme.disconnected,
          'Disconnected',
          Icons.bluetooth_disabled_rounded,
        );
    }
  }
}

/// A minimal connection indicator dot
class ConnectionStatusDot extends ConsumerWidget {
  final double size;

  const ConnectionStatusDot({
    super.key,
    this.size = 8,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isConnected = ref.watch(isConnectedProvider);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isConnected ? AppTheme.connected : AppTheme.disconnected,
        boxShadow: isConnected
            ? [
                BoxShadow(
                  color: AppTheme.connected.withValues(alpha: 0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
    );
  }
}
