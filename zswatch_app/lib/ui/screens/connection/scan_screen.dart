import 'dart:async';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/database/app_database.dart';
import '../../../providers/ble_providers.dart' hide bleScannerProvider;
import '../../../providers/watch_providers.dart' hide watchNotifierProvider;
import '../../../providers/watch_service_provider.dart';
import '../../../services/ble/ble_scanner.dart';
import '../../widgets/connection_status_pill.dart';

// Use bleScannerProvider from ble_providers.dart
import '../../../providers/ble_providers.dart' as ble show bleScannerProvider;

/// Scan screen for discovering ZSWatch devices
///
/// This is the entry point for connecting to a watch. Users can:
/// - Scan for nearby ZSWatch devices
/// - See device signal strength
/// - Tap a device to connect
class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  bool _isInitializing = true;
  bool _hasPermissions = false;
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _initAndScan();
  }

  Future<void> _initAndScan() async {
    setState(() {
      _isInitializing = true;
    });

    try {
      // Load known watch IDs from database
      final knownIds = await ref.read(knownWatchIdsProvider.future);
      final scanner = ref.read(ble.bleScannerProvider);
      scanner.setKnownWatchIds(knownIds);

      // Just try to start scanning - flutter_blue_plus will trigger permission dialogs
      await _startScan();
      _hasPermissions = true;
    } catch (e) {
      // Permission denied or other error
      _hasPermissions = false;
      debugPrint('Permission/scan error: $e');
    }

    if (mounted) {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  Future<void> _startScan() async {
    final scanner = ref.read(ble.bleScannerProvider);
    await scanner.startScan(timeout: const Duration(seconds: 20));
  }

  Future<void> _stopScan() async {
    final scanner = ref.read(ble.bleScannerProvider);
    await scanner.stopScan();
  }

  Future<void> _requestPermissionsManually() async {
    final notifier = ref.read(bleNotifierProvider.notifier);
    final granted = await notifier.requestPermissions();
    if (granted) {
      unawaited(_initAndScan());
    }
  }

  Future<void> _connectToDevice(ScannedWatch device) async {
    setState(() => _isConnecting = true);
    
    try {
      // Use the new WatchNotifier
      final notifier = ref.read(watchNotifierProvider.notifier);
      await notifier.connect(device);

      // Save this watch to the database
      final db = ref.read(databaseProvider);
      await db.upsertWatch(WatchesCompanion(
        id: Value(device.id),
        name: Value(device.displayName),
        createdAt: Value(DateTime.now()),
        lastConnectedAt: Value(DateTime.now()),
      ));

      // Invalidate providers to refresh
      ref.invalidate(knownWatchIdsProvider);
      ref.invalidate(allWatchesProvider);

      if (mounted) {
        // Show success and navigate
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connected to ${device.displayName}'),
            backgroundColor: AppTheme.successColor,
          ),
        );
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
        setState(() => _isConnecting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bluetoothState = ref.watch(bluetoothAdapterStateProvider);
    final isBluetoothOn =
        bluetoothState.valueOrNull == BluetoothAdapterState.on;
    final scannedDevices = ref.watch(scannedDevicesProvider);
    final connectionState = ref.watch(connectionStateProvider);
    final isScanning = ref.watch(isScanningProvider).valueOrNull ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Watch'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: const [
          ConnectionStatusPill(
            compact: true,
            showIcon: true,
          ),
          SizedBox(width: 8),
        ],
      ),
      body: _isConnecting
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Connecting...'),
                ],
              ),
            )
          : _isInitializing
              ? const Center(child: CircularProgressIndicator())
              : !_hasPermissions
                  ? _buildPermissionRequest()
                  : !isBluetoothOn
                      ? _buildBluetoothOffMessage()
                      : _buildScanContent(scannedDevices, isScanning, connectionState),
      floatingActionButton: _hasPermissions && isBluetoothOn && !_isConnecting
          ? FloatingActionButton.extended(
              onPressed: isScanning ? _stopScan : _startScan,
              icon: Icon(
                isScanning ? Icons.stop : Icons.search,
              ),
              label: Text(isScanning ? 'Stop' : 'Scan'),
            )
          : null,
    );
  }

  Widget _buildPermissionRequest() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bluetooth_disabled,
              size: 80,
              color: AppTheme.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppTheme.spacingLg),
            Text(
              'Bluetooth Permission Required',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacingMd),
            Text(
              'ZSWatch needs Bluetooth permission to discover and connect to your watch.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacingLg),
            ElevatedButton.icon(
              onPressed: _requestPermissionsManually,
              icon: const Icon(Icons.security),
              label: const Text('Grant Permission'),
            ),
            const SizedBox(height: AppTheme.spacingSm),
            TextButton(
              onPressed: () async {
                final notifier = ref.read(bleNotifierProvider.notifier);
                await notifier.openBluetoothSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBluetoothOffMessage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bluetooth_disabled,
              size: 80,
              color: AppTheme.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppTheme.spacingLg),
            Text(
              'Bluetooth is Off',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacingMd),
            Text(
              'Please turn on Bluetooth to scan for your ZSWatch.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacingLg),
            ElevatedButton.icon(
              onPressed: () async {
                final notifier = ref.read(bleNotifierProvider.notifier);
                await notifier.turnOnBluetooth();
              },
              icon: const Icon(Icons.bluetooth),
              label: const Text('Turn On Bluetooth'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanContent(
    AsyncValue<List<ScannedWatch>> scannedDevices,
    bool isScanning,
    connectionState,
  ) {
    return Column(
      children: [
        // Scanning indicator
        if (isScanning)
          const LinearProgressIndicator(
            backgroundColor: AppTheme.surfaceColor,
          ),

        // Instructions
        Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          child: Text(
            isScanning
                ? 'Searching for ZSWatch devices nearby...'
                : 'Tap Scan to search for your watch',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
        ),

        // Device list
        Expanded(
          child: scannedDevices.when(
            data: (devices) {
              if (devices.isEmpty) {
                return _buildEmptyState(isScanning);
              }
              return _buildDeviceList(devices);
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _buildErrorState(error.toString()),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool isScanning) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isScanning ? Icons.radar : Icons.watch,
            size: 64,
            color: AppTheme.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppTheme.spacingMd),
          Text(
            isScanning ? 'Looking for devices...' : 'No devices found',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
          if (!isScanning) ...[
            const SizedBox(height: AppTheme.spacingSm),
            Text(
              'Make sure your ZSWatch is on and nearby',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textDisabled,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDeviceList(List<ScannedWatch> devices) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingSm),
      itemCount: devices.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final device = devices[index];
        return _DeviceListTile(
          device: device,
          onTap: () => _connectToDevice(device),
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
              'Scan Error',
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

/// Individual device list tile
class _DeviceListTile extends StatelessWidget {
  final ScannedWatch device;
  final VoidCallback onTap;

  const _DeviceListTile({
    required this.device,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _buildSignalIcon(),
      title: Row(
        children: [
          Expanded(
            child: Text(
              device.displayName,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          if (device.isConnected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Connected',
                style: TextStyle(
                  color: AppTheme.successColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else if (device.isBonded)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Paired',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      subtitle: Text(
        _getSubtitleText(),
        style: TextStyle(
          color: device.isConnected ? AppTheme.successColor : AppTheme.textSecondary,
          fontSize: 12,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: AppTheme.textSecondary,
      ),
      onTap: onTap,
    );
  }

  Widget _buildSignalIcon() {
    final color = _getSignalColor();
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Icon(
        _getIcon(),
        color: color,
        size: 24,
      ),
    );
  }

  Color _getSignalColor() {
    if (device.isConnected) return AppTheme.successColor;
    if (device.isBonded) return AppTheme.primaryColor;
    if (device.rssi >= -50) return AppTheme.successColor;
    if (device.rssi >= -70) return AppTheme.warningColor;
    return AppTheme.errorColor;
  }

  IconData _getIcon() {
    if (device.isConnected) return Icons.bluetooth_connected;
    if (device.isBonded) return Icons.watch;
    return Icons.watch;
  }

  String _getSubtitleText() {
    if (device.isConnected) {
      return 'Already connected • ${device.id}';
    }
    
    if (device.isAdvertising) {
      // Device is actively advertising - show signal strength
      final savedText = device.isBonded ? 'Saved • ' : '';
      return '$savedText${device.rssi} dBm • ${device.id}';
    }
    
    if (device.isBonded) {
      // Saved but not advertising - out of range
      return 'Saved • Out of range • ${device.id}';
    }
    
    return '${device.rssi} dBm • ${device.id}';
  }
}

