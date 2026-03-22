import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../core/constants/ble_constants.dart';

/// Scanned device result
class ScannedWatch {
  /// BLE device identifier
  final String id;

  /// Advertised device name
  final String name;

  /// Signal strength in dBm
  final int rssi;

  /// Underlying Bluetooth device
  final BluetoothDevice device;

  /// When the device was discovered
  final DateTime discoveredAt;

  /// Last time this device was seen (for timeout tracking)
  DateTime lastSeenAt;

  /// Whether this device is already connected at system level
  final bool isConnected;

  /// Whether this device is bonded/paired
  final bool isBonded;

  /// Whether we've seen this device advertising (vs only found in bonded list)
  final bool isAdvertising;

  ScannedWatch({
    required this.id,
    required this.name,
    required this.rssi,
    required this.device,
    required this.discoveredAt,
    DateTime? lastSeenAt,
    this.isConnected = false,
    this.isBonded = false,
    this.isAdvertising = true,
  }) : lastSeenAt = lastSeenAt ?? discoveredAt;

  /// Update RSSI and last seen time (marks as advertising)
  ScannedWatch updateRssi(int newRssi) {
    return ScannedWatch(
      id: id,
      name: name,
      rssi: newRssi,
      device: device,
      discoveredAt: discoveredAt,
      lastSeenAt: DateTime.now(),
      isConnected: isConnected,
      isBonded: isBonded,
      isAdvertising: true, // We saw it advertise
    );
  }

  /// Display name without status suffix
  String get displayName {
    // Remove (Connected) or (Paired) suffix if present
    return name.replaceAll(' (Connected)', '').replaceAll(' (Paired)', '');
  }

  /// Status text for display
  String get statusText {
    if (isConnected) return 'Connected';
    if (isBonded) return 'Paired';
    return rssiDescription;
  }

  /// Signal strength description
  String get rssiDescription {
    if (rssi >= -50) return 'Excellent';
    if (rssi >= -60) return 'Good';
    if (rssi >= -70) return 'Fair';
    return 'Weak';
  }

  /// Signal strength percentage (0-100)
  int get rssiPercentage {
    // Map RSSI from -100 to -30 dBm to 0-100%
    final clamped = rssi.clamp(-100, -30);
    return ((clamped + 100) * 100 ~/ 70).clamp(0, 100);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScannedWatch &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// BLE Scanner for discovering ZSWatch devices
class BleScanner {
  final _scannedDevices = <String, ScannedWatch>{};
  final _scanResultsController =
      StreamController<List<ScannedWatch>>.broadcast();
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  Timer? _staleDeviceTimer;
  bool _isScanning = false;

  /// Known watch IDs from database (set before scanning)
  Set<String> _knownWatchIds = {};

  /// Stream of discovered devices
  Stream<List<ScannedWatch>> get scanResults => _scanResultsController.stream;

  /// Current list of discovered devices
  List<ScannedWatch> get discoveredDevices =>
      _scannedDevices.values.toList()..sort((a, b) {
        // Connected devices first, then by RSSI
        if (a.isConnected != b.isConnected) {
          return a.isConnected ? -1 : 1;
        }
        return b.rssi.compareTo(a.rssi);
      });

  /// Whether currently scanning
  bool get isScanning => _isScanning;

  /// Set known watch IDs from database (call before startScan)
  void setKnownWatchIds(Set<String> ids) {
    _knownWatchIds = ids;
  }

  /// Start scanning for ZSWatch devices
  ///
  /// [timeout] - Duration to scan before auto-stopping
  /// [removeStaleAfter] - Remove devices not seen for this duration
  Future<void> startScan({
    Duration timeout = const Duration(seconds: 15),
    Duration removeStaleAfter = const Duration(seconds: 10),
  }) async {
    if (_isScanning) {
      await stopScan();
    }

    _scannedDevices.clear();
    _isScanning = true;

    // First, add already connected devices
    await _addConnectedDevices();

    // Listen to scan results
    _scanSubscription = FlutterBluePlus.scanResults.listen(_handleScanResult);

    // Start periodic stale device removal
    _staleDeviceTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _removeStaleDevices(removeStaleAfter),
    );

    // Start scanning
    await FlutterBluePlus.startScan(
      timeout: timeout,
      androidScanMode: AndroidScanMode.lowLatency,
    );

    // Auto-stop after timeout
    Future.delayed(timeout, () {
      if (_isScanning) {
        stopScan();
      }
    });
  }

  /// Add already connected/bonded devices to the list
  Future<void> _addConnectedDevices() async {
    try {
      // Get system-connected devices that we know about
      final connectedDevices = FlutterBluePlus.connectedDevices;

      for (final device in connectedDevices) {
        final deviceId = device.remoteId.str;
        final deviceName = device.advName.isNotEmpty
            ? device.advName
            : device.platformName;

        // Only show connected devices that are in our database OR are ZSWatch devices
        final isKnown = _knownWatchIds.contains(deviceId);
        final isZsWatch = deviceName.toLowerCase().contains(
          BleConfig.deviceNamePrefix.toLowerCase(),
        );

        if (isKnown || isZsWatch) {
          _scannedDevices[deviceId] = ScannedWatch(
            id: deviceId,
            name: deviceName.isNotEmpty ? deviceName : 'ZSWatch',
            rssi: 0, // Unknown RSSI for connected devices
            device: device,
            discoveredAt: DateTime.now(),
            isConnected: true,
            isBonded: true,
            isAdvertising: false, // Not from scan, from connected list
          );
        }
      }

      // Only show bonded devices that are in our app database
      if (_knownWatchIds.isNotEmpty) {
        final bondedDevices = await FlutterBluePlus.bondedDevices;

        for (final device in bondedDevices) {
          final deviceId = device.remoteId.str;

          // Skip if already added as connected
          if (_scannedDevices.containsKey(deviceId)) continue;

          // Only show if it's in our database
          if (_knownWatchIds.contains(deviceId)) {
            final deviceName = device.advName.isNotEmpty
                ? device.advName
                : device.platformName;

            _scannedDevices[deviceId] = ScannedWatch(
              id: deviceId,
              name: deviceName.isNotEmpty ? deviceName : 'ZSWatch',
              rssi: -100, // Low priority for paired-only devices
              device: device,
              discoveredAt: DateTime.now(),
              isConnected: false,
              isBonded: true,
              isAdvertising: false, // Not from scan, from bonded list
            );
          }
        }
      }

      if (_scannedDevices.isNotEmpty) {
        _emitDevices();
      }
    } catch (e) {
      // Ignore errors - connected/bonded device check is best-effort
    }
  }

  void _handleScanResult(List<ScanResult> results) {
    var updated = false;

    for (final result in results) {
      final deviceName = result.device.advName;

      // Filter for ZSWatch devices
      if (deviceName.isEmpty ||
          !deviceName.toLowerCase().contains(
            BleConfig.deviceNamePrefix.toLowerCase(),
          )) {
        continue;
      }

      final deviceId = result.device.remoteId.str;

      if (_scannedDevices.containsKey(deviceId)) {
        // Update existing device
        _scannedDevices[deviceId] = _scannedDevices[deviceId]!.updateRssi(
          result.rssi,
        );
      } else {
        // Add new device
        _scannedDevices[deviceId] = ScannedWatch(
          id: deviceId,
          name: deviceName,
          rssi: result.rssi,
          device: result.device,
          discoveredAt: DateTime.now(),
        );
      }
      updated = true;
    }

    if (updated) {
      _emitDevices();
    }
  }

  void _removeStaleDevices(Duration staleThreshold) {
    final now = DateTime.now();
    final staleIds = <String>[];

    for (final entry in _scannedDevices.entries) {
      if (now.difference(entry.value.lastSeenAt) > staleThreshold) {
        staleIds.add(entry.key);
      }
    }

    if (staleIds.isNotEmpty) {
      for (final id in staleIds) {
        _scannedDevices.remove(id);
      }
      _emitDevices();
    }
  }

  void _emitDevices() {
    _scanResultsController.add(discoveredDevices);
  }

  /// Stop scanning
  Future<void> stopScan() async {
    _isScanning = false;
    _staleDeviceTimer?.cancel();
    _staleDeviceTimer = null;
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    await FlutterBluePlus.stopScan();
  }

  /// Clear discovered devices
  void clearResults() {
    _scannedDevices.clear();
    _emitDevices();
  }

  /// Dispose resources
  Future<void> dispose() async {
    await stopScan();
    await _scanResultsController.close();
  }
}
