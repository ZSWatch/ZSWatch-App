import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:rxdart/rxdart.dart';

import '../core/constants/ble_constants.dart';
import '../data/models/connection.dart';
import '../data/models/connection_state.dart';
import '../data/models/watch.dart';
import 'ble/ble_scanner.dart';
import 'protocol/protocol_service.dart';

// Convert String UUIDs to Guid for flutter_blue_plus
Guid _guid(String uuid) => Guid(uuid);

/// Unified watch service that handles:
/// - BLE connection management
/// - Device info retrieval
/// - Protocol communication (Gadgetbridge)
/// - Battery monitoring
/// - Raw data streaming for log viewer
class WatchService {
  BluetoothDevice? _device;
  List<BluetoothService>? _services;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<List<int>>? _nusSubscription;
  StreamSubscription<List<int>>? _batterySubscription;
  Timer? _reconnectTimer;
  Timer? _rssiTimer;

  // Use BehaviorSubject to cache last value for new subscribers
  final _connectionController = BehaviorSubject<Connection>.seeded(
    const Connection(watchId: '', state: WatchConnectionState.disconnected),
  );
  final _watchInfoController = BehaviorSubject<Watch?>.seeded(null);
  final _batteryController = BehaviorSubject<int>.seeded(0);
  final _incomingMessageController = StreamController<Map<String, dynamic>>.broadcast();
  
  // Raw data streams for developer tools (FR-035a)
  final _rawIncomingDataController = StreamController<String>.broadcast();
  final _rawOutgoingDataController = StreamController<String>.broadcast();
  
  // Log streaming state (FR-035c, FR-035d)
  bool _logStreamingEnabled = false;
  
  // Buffer for multi-packet JSON messages
  String _messageBuffer = '';

  bool _autoReconnect = true;
  int _reconnectAttempts = 0;
  static const int _maxQuickReconnectAttempts = 3; // Quick retries for momentary disconnects
  bool _isSettingUp = false; // Prevent concurrent setup calls
  bool _isInBackgroundReconnect = false; // Track if we're using OS-level autoConnect
  bool _isCancelled = false; // Track if user has cancelled the connection
  bool _isReconnecting = false; // Track if reconnect is in progress (timer scheduled or running)
  bool _isInitialConnection = false; // Track if this is the first connection attempt (show Connecting not Reconnecting)
  bool _isWaitingForAutoConnect = false; // Track when waiting for autoConnect to establish connection
  bool _isInitiatingConnection = false; // Track when we're in the process of starting a connection (ignore initial disconnect)
  bool _pendingReconnectAfterSetup = false; // Track if we need to trigger reconnect after setup completes
  String? _pendingReconnectWatchId; // Watch ID for pending reconnect
  String? _pendingReconnectWatchName; // Watch name for pending reconnect

  /// Stream of connection state changes
  Stream<Connection> get connectionStream => _connectionController.stream;

  /// Stream of watch info updates
  Stream<Watch?> get watchInfoStream => _watchInfoController.stream;

  /// Stream of battery level updates
  Stream<int> get batteryStream => _batteryController.stream;

  /// Stream of incoming messages from watch
  Stream<Map<String, dynamic>> get incomingMessages => _incomingMessageController.stream;

  /// Stream of ALL raw incoming BLE NUS data for log viewer (FR-035a)
  /// Includes both logs and protocol messages
  Stream<String> get rawIncomingData => _rawIncomingDataController.stream;

  /// Stream of ALL raw outgoing BLE NUS data for log viewer
  Stream<String> get rawOutgoingData => _rawOutgoingDataController.stream;

  /// Whether log streaming is enabled on watch
  bool get logStreamingEnabled => _logStreamingEnabled;

  /// Current connection state
  Connection get currentConnection => _connectionController.value;

  /// Current watch info
  Watch? get currentWatch => _watchInfoController.value;

  /// Whether connected
  bool get isConnected => _connectionController.value.isConnected;

  /// Current BLE device (for sensor GATT service initialization)
  BluetoothDevice? get device => _device;

  /// Discovered BLE services (for sensor GATT service initialization)
  List<BluetoothService>? get services => _services;

  /// Whether the connected device has the MCUmgr/SMP service available
  /// (required for DFU and filesystem uploads)
  bool get hasSmpService => _findService(_guid(McumgrUuids.service)) != null;

  /// Re-discover BLE services on the connected device.
  /// Useful if the user enables SMP on the watch while already connected.
  /// Returns true if SMP service is found after re-discovery.
  Future<bool> rediscoverServices() async {
    if (_device == null || !isConnected) return false;
    debugPrint('[WatchService] Re-discovering services...');
    try {
      _services = await _device!.discoverServices();
      final hasSmp = hasSmpService;
      debugPrint('[WatchService] Re-discovery complete. SMP available: $hasSmp');
      return hasSmp;
    } catch (e) {
      debugPrint('[WatchService] Re-discovery failed: $e');
      return false;
    }
  }

  /// Connect to a scanned device
  Future<void> connect(ScannedWatch scannedDevice, {bool autoConnect = false}) async {
    debugPrint('[WatchService] connect() called: autoConnect=$autoConnect, _isCancelled=$_isCancelled');
    // Only reset _isCancelled for truly user-initiated connections
    // Don't reset if this might be from an auto-reconnect attempt
    if (!autoConnect) {
      _isCancelled = false;
      debugPrint('[WatchService] connect() - reset _isCancelled to false (user-initiated)');
    }
    await _connectToDevice(scannedDevice.device, scannedDevice.id, scannedDevice.name, autoConnect: autoConnect);
  }

  /// Connect by device ID (for saved watches)
  /// 
  /// [autoConnect] - If true, uses flutter_blue_plus's autoConnect feature which:
  ///   - Returns immediately (non-blocking)
  ///   - System handles reconnection when device appears
  ///   - Doesn't time out - keeps trying until device available
  ///   - Convenient for auto-reconnect on app launch
  Future<void> connectById(String deviceId, {bool autoConnect = false}) async {
    debugPrint('[WatchService] connectById() called: deviceId=$deviceId, autoConnect=$autoConnect, _isCancelled=$_isCancelled');
    // Only reset _isCancelled for truly user-initiated connections
    // Don't reset if this might be from an auto-reconnect attempt
    if (!autoConnect) {
      _isCancelled = false;
      debugPrint('[WatchService] connectById() - reset _isCancelled to false (user-initiated)');
    }
    final device = BluetoothDevice.fromId(deviceId);
    await _connectToDevice(device, deviceId, 'ZSWatch', autoConnect: autoConnect);
  }

  Future<void> _connectToDevice(BluetoothDevice device, String watchId, String name, {bool autoConnect = false, bool isReconnectAttempt = false}) async {
    debugPrint('[WatchService:$hashCode] _connectToDevice called: watchId=$watchId, autoConnect=$autoConnect, isReconnectAttempt=$isReconnectAttempt, _isCancelled=$_isCancelled, _autoReconnect=$_autoReconnect, currentState=${currentConnection.state}');
    
    // Don't connect if user has cancelled
    if (_isCancelled) {
      debugPrint('[WatchService:$hashCode] _connectToDevice skipped - cancelled by user');
      return;
    }

    // Don't reconnect if already connected to this device
    if (isConnected && _device?.remoteId.str == watchId) {
      debugPrint('[WatchService:$hashCode] _connectToDevice skipped - already connected');
      return;
    }
    
    // Don't start a new connection if already connecting
    final currentState = currentConnection.state;
    if (currentState == WatchConnectionState.connecting ||
        currentState == WatchConnectionState.bonding ||
        currentState == WatchConnectionState.discoveringServices ||
        currentState == WatchConnectionState.negotiating) {
      debugPrint('[WatchService:$hashCode] _connectToDevice skipped - already in state: $currentState');
      return;
    }

    // Only reset these for fresh connections, not reconnect attempts
    if (!isReconnectAttempt) {
      _autoReconnect = true;
      _reconnectAttempts = 0;
      _isInitialConnection = true; // Mark as initial connection
      _isInBackgroundReconnect = false;
    }
    // Note: Only reset _isCancelled for user-initiated connections, not internal reconnects
    // The public connect methods should reset this flag

    try {
      _updateConnection(Connection(
        watchId: watchId,
        watchName: name,
        state: WatchConnectionState.connecting,
      ));

      // Cancel existing subscriptions
      await _connectionSubscription?.cancel();

      // Mark that we're initiating a connection - ignore initial disconnect events
      // The BLE subscription may fire with the current state (disconnected) immediately
      // before the actual connection is established
      _isInitiatingConnection = true;

      // Subscribe to connection state BEFORE connecting
      _connectionSubscription = device.connectionState.listen(
        (state) => _handleConnectionStateChange(state, watchId, name),
      );

      _device = device;

      // Connect with optional autoConnect
      // When autoConnect is true:
      // - We don't await - let it run in background
      // - System will connect when device is available
      // - Connection events come through connectionState listener
      // Note: autoConnect is incompatible with mtu argument, so we request MTU after connection
      if (autoConnect) {
        // Final check before BLE call - user might have cancelled during setup
        if (_isCancelled) {
          debugPrint('[WatchService:$hashCode] autoConnect skipped - cancelled just before BLE call');
          _isInitiatingConnection = false;
          return;
        }
        // Mark that we're waiting for autoConnect - ignore initial disconnect events
        _isWaitingForAutoConnect = true;
        // Don't await - autoConnect runs in background
        // The connectionState listener will handle the connection event
        unawaited(device.connect(
          license: License.free,
          timeout: const Duration(seconds: 0),
          mtu: null, // autoConnect is incompatible with mtu
          autoConnect: true,
        ).catchError((e) {
          // Ignore errors for autoConnect - connection state listener handles everything
          debugPrint('[WatchService] AutoConnect error (ignored): $e');
          _isWaitingForAutoConnect = false;
          _isInitiatingConnection = false;
        }));
      } else {
        // Final check before BLE call - user might have cancelled during setup
        if (_isCancelled) {
          debugPrint('[WatchService:$hashCode] connect skipped - cancelled just before BLE call');
          _isInitiatingConnection = false;
          return;
        }
        // Use shorter timeout for reconnect attempts to cycle through them faster
        final timeout = isReconnectAttempt 
            ? const Duration(seconds: 10) 
            : BleConfig.connectionTimeout;
        debugPrint('[WatchService:$hashCode] About to call device.connect(autoConnect: false, timeout: ${timeout.inSeconds}s)');
        await device.connect(
          license: License.free,
          timeout: timeout,
          autoConnect: false,
        );
        // Clear the initiating flag - we're now connected
        _isInitiatingConnection = false;
        // Perform post-connection setup only for direct connections
        await _setupAfterConnect(watchId, name);
      }

    } catch (e) {
      _updateConnection(Connection.error(
        watchId,
        ConnectionErrorType.timeout,
        details: e.toString(),
      ));
      rethrow;
    }
  }

  /// Helper to check if device is still connected and setup should continue
  bool _shouldContinueSetup() {
    if (_isCancelled) {
      debugPrint('[Setup] Aborting - user cancelled');
      return false;
    }
    if (_device == null) {
      debugPrint('[Setup] Aborting - device is null');
      return false;
    }
    if (!_device!.isConnected) {
      debugPrint('[Setup] Aborting - device disconnected');
      return false;
    }
    return true;
  }

  Future<void> _setupAfterConnect(String watchId, String name) async {
    // Prevent concurrent setup calls (can happen on rapid reconnects)
    if (_isSettingUp) {
      debugPrint('Setup already in progress, skipping duplicate call');
      return;
    }
    
    // Check if user has cancelled
    if (_isCancelled) {
      debugPrint('Setup cancelled - user cancelled connection');
      return;
    }
    
    // Check if device is still valid and connected
    if (_device == null) {
      debugPrint('Setup cancelled - device is null');
      return;
    }
    
    if (!_device!.isConnected) {
      debugPrint('Setup cancelled - device not connected');
      return;
    }
    
    _isSettingUp = true;

    try {
      // Bonding (Android only - iOS handles bonding automatically)
      if (Platform.isAndroid) {
        _updateConnection(currentConnection.copyWith(
          state: WatchConnectionState.bonding,
        ));

        // Re-check device in case user cancelled during state updates
        if (!_shouldContinueSetup()) return;

        final bondState = await _device!.bondState.first;
        if (!_shouldContinueSetup()) return;
        
        if (bondState != BluetoothBondState.bonded) {
          await _device!.createBond();
          if (!_shouldContinueSetup()) return;
        }
      }

      // Discover services
      _updateConnection(currentConnection.copyWith(
        state: WatchConnectionState.discoveringServices,
      ));

      if (!_shouldContinueSetup()) return;
      _services = await _device!.discoverServices();

      // Negotiate MTU (Android only - iOS negotiates automatically)
      int mtu;
      if (Platform.isAndroid) {
        _updateConnection(currentConnection.copyWith(
          state: WatchConnectionState.negotiating,
        ));

        if (!_shouldContinueSetup()) return;
        mtu = await _device!.requestMtu(BleConfig.preferredMtu);
      } else {
        // On iOS, MTU is negotiated automatically (typically 185-512)
        mtu = 185;
      }

      // Note: We don't request connection priority here.
      // The watch manages connection intervals based on its current needs
      // (e.g., short intervals during DFU, longer intervals when idle).
      // Forcing high priority from the phone would override the watch's
      // power-saving preferences.

      if (!_shouldContinueSetup()) return;

      // Create or update watch object - preserve existing firmware/battery info
      final existingWatch = currentWatch;
      final watch = existingWatch != null && existingWatch.id == watchId
          ? existingWatch.copyWith(lastConnectedAt: DateTime.now())
          : Watch(
              id: watchId,
              name: name,
              createdAt: DateTime.now(),
              lastConnectedAt: DateTime.now(),
            );
      _watchInfoController.add(watch);

      // Setup NUS for Gadgetbridge protocol (needed for sync)
      if (!_shouldContinueSetup()) return;
      await _setupNus();

      // Subscribe to battery service
      if (!_shouldContinueSetup()) return;
      await _setupBatteryNotifications();
      
      // Read initial RSSI and start periodic updates
      if (_shouldContinueSetup()) {
        await _readAndUpdateRssi();
        _startRssiUpdates();
      }

      // Transition to syncing state (FR-088)
      // Connection is established but initial sync not yet complete
      if (!_shouldContinueSetup()) return;
      _updateConnection(currentConnection.copyWith(
        state: WatchConnectionState.syncing,
        mtu: mtu,
        connectedAt: DateTime.now(),
      ));

      // Perform initial sync operations (FR-084 to FR-087)
      // Time sync (FR-085)
      if (_shouldContinueSetup()) {
        await syncTime();
      }
      
      // Request device info via Gadgetbridge
      if (_shouldContinueSetup()) {
        await requestDeviceInfo();
      }

      // Note: Music state sync (FR-086) is handled by MediaControlNotifier
      // which listens to connectionStream and syncs when state becomes connected

      // Mark as fully connected and ready (FR-088)
      if (!_shouldContinueSetup()) return;
      _updateConnection(currentConnection.copyWith(
        state: WatchConnectionState.connected,
      ));

      // Reset reconnect attempts and flags on successful setup
      _reconnectAttempts = 0;
      _isInitialConnection = false;
      _isInBackgroundReconnect = false;

    } catch (e) {
      debugPrint('[Setup] Error during setup: $e');
      // Only report error and trigger reconnect if we're still supposed to be connected
      // If device disconnected during setup, let the disconnect handler manage state
      if (_device != null && _device!.isConnected) {
        _updateConnection(Connection.error(
          watchId,
          ConnectionErrorType.serviceDiscoveryFailed,
          details: e.toString(),
        ));
        // Disconnect the BLE device but DON'T call disconnect() which would set
        // _isCancelled=true and prevent auto-reconnect. Instead, just disconnect
        // the underlying device and let _handleDisconnect manage reconnection.
        try {
          await _device!.disconnect();
        } catch (_) {
          // Ignore disconnect errors
        }
        // Don't rethrow - we've handled the error by disconnecting and letting
        // the auto-reconnect mechanism try again
      } else {
        debugPrint('[Setup] Error during setup but device disconnected - marking for reconnect after setup completes: $e');
        // Device already disconnected - _handleDisconnect may have already been called
        // and scheduled a timer that checked _isSettingUp (which was true).
        // Mark that we need to trigger reconnect from the finally block.
        if (_autoReconnect && !_isCancelled) {
          _pendingReconnectAfterSetup = true;
          _pendingReconnectWatchId = watchId;
          _pendingReconnectWatchName = name;
        }
      }
    } finally {
      _isSettingUp = false;
      
      // Check if we need to trigger reconnect (setup failed while device was already disconnected)
      if (_pendingReconnectAfterSetup) {
        _pendingReconnectAfterSetup = false;
        final pendingWatchId = _pendingReconnectWatchId;
        final pendingWatchName = _pendingReconnectWatchName;
        _pendingReconnectWatchId = null;
        _pendingReconnectWatchName = null;
        
        if (pendingWatchId != null && pendingWatchName != null && !_isCancelled && _autoReconnect) {
          debugPrint('[Setup] Setup completed - triggering deferred reconnect for $pendingWatchId');
          // Use a short delay to let any pending state settle
          Timer(const Duration(milliseconds: 100), () {
            if (!_isCancelled && _autoReconnect && !_isReconnecting && !_isSettingUp) {
              _attemptReconnect(pendingWatchId, pendingWatchName);
            }
          });
        }
      }
    }
  }

  /// Read RSSI and update connection state
  Future<void> _readAndUpdateRssi() async {
    if (_device == null || !isConnected) return;
    
    try {
      final rssi = await _device!.readRssi();
      _updateConnection(currentConnection.copyWith(rssi: rssi));
    } catch (e) {
      debugPrint('[WatchService] Failed to read RSSI: $e');
    }
  }

  /// Start periodic RSSI updates (every 5 seconds)
  void _startRssiUpdates() {
    _rssiTimer?.cancel();
    _rssiTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _readAndUpdateRssi();
    });
  }

  /// Stop RSSI updates
  void _stopRssiUpdates() {
    _rssiTimer?.cancel();
    _rssiTimer = null;
  }

  Future<void> _setupNus() async {
    await _nusSubscription?.cancel();
    _nusSubscription = null;
    
    final nusService = _findService(_guid(NusUuids.service));
    if (nusService == null) return;

    final rxChar = _findCharacteristic(nusService, _guid(NusUuids.rxCharacteristic));
    if (rxChar == null) return;

    await rxChar.setNotifyValue(true);
    _nusSubscription = rxChar.onValueReceived.listen(_handleNusData);
  }

  // Tracks if we're currently inside a <BLELOG> section (may span multiple chunks)
  bool _inBleLog = false;

  void _handleNusData(List<int> data) {
    try {
      final chunk = utf8.decode(data);
      if (chunk.isEmpty) return;

      debugPrint('[BLE RX] $chunk');
      
      // Emit to raw data stream for log viewer (FR-035a)
      _rawIncomingDataController.add(chunk);

      // Filter out <BLELOG>...</BLELOG> sections before adding to message buffer.
      // These firmware debug logs contain curly braces in hex dumps that confuse
      // the JSON parser. They're still emitted to rawIncomingData for the log viewer.
      final filteredChunk = _filterBleLogSections(chunk);
      
      if (filteredChunk.isNotEmpty) {
        // Buffer data and process complete JSON messages
        _messageBuffer += filteredChunk;
        
        // Process all complete JSON messages in the buffer
        _processMessageBuffer();
      }
    } catch (e) {
      // Binary data that can't be decoded as UTF-8 - log raw bytes
      debugPrint('[BLE RX] Raw bytes: $data');
      // Still emit to raw stream for debugging
      _rawIncomingDataController.add('RAW: $data');
    }
  }

  /// Filter out <BLELOG>...</BLELOG> sections from incoming data.
  /// These sections contain firmware debug logs that shouldn't be parsed as JSON.
  /// Handles sections that span multiple BLE packets.
  String _filterBleLogSections(String chunk) {
    const bleLogStart = '<BLELOG>';
    const bleLogEnd = '</BLELOG>';
    
    var result = StringBuffer();
    var remaining = chunk;
    
    while (remaining.isNotEmpty) {
      if (_inBleLog) {
        // We're inside a BLELOG section - look for the end tag
        final endIndex = remaining.indexOf(bleLogEnd);
        if (endIndex == -1) {
          // End tag not found in this chunk - discard everything
          break;
        }
        // Found end tag - skip past it and continue processing
        remaining = remaining.substring(endIndex + bleLogEnd.length);
        _inBleLog = false;
      } else {
        // Look for start of a BLELOG section
        final startIndex = remaining.indexOf(bleLogStart);
        if (startIndex == -1) {
          // No BLELOG section in remaining data - keep it all
          result.write(remaining);
          break;
        }
        // Found start tag - keep everything before it
        result.write(remaining.substring(0, startIndex));
        remaining = remaining.substring(startIndex + bleLogStart.length);
        _inBleLog = true;
      }
    }
    
    return result.toString();
  }

  /// Process the message buffer to extract complete JSON messages.
  /// Handles multi-packet messages that arrive in chunks due to BLE MTU limits.
  void _processMessageBuffer() {
    while (_messageBuffer.isNotEmpty) {
      // Find the start of a JSON object
      final jsonStart = _messageBuffer.indexOf('{');
      if (jsonStart == -1) {
        // No JSON start found, clear buffer (non-JSON data)
        _messageBuffer = '';
        break;
      }
      
      // Skip any data before the JSON start
      if (jsonStart > 0) {
        _messageBuffer = _messageBuffer.substring(jsonStart);
      }
      
      // Try to find a complete JSON object by counting braces
      var braceCount = 0;
      var inString = false;
      var escaped = false;
      var jsonEnd = -1;
      
      for (var i = 0; i < _messageBuffer.length; i++) {
        final char = _messageBuffer[i];
        
        if (escaped) {
          escaped = false;
          continue;
        }
        
        if (char == r'\' && inString) {
          escaped = true;
          continue;
        }
        
        if (char == '"') {
          inString = !inString;
          continue;
        }
        
        if (!inString) {
          if (char == '{') {
            braceCount++;
          } else if (char == '}') {
            braceCount--;
            if (braceCount == 0) {
              jsonEnd = i + 1;
              break;
            }
          }
        }
      }
      
      if (jsonEnd == -1) {
        // Incomplete JSON, wait for more data
        debugPrint('[BLE RX] Buffering incomplete JSON (${_messageBuffer.length} bytes)');
        break;
      }
      
      // Extract the complete JSON string
      final jsonStr = _messageBuffer.substring(0, jsonEnd);
      _messageBuffer = _messageBuffer.substring(jsonEnd);
      
      debugPrint('[BLE RX] Complete message: ${jsonStr.length} bytes');
      
      // Parse and handle the message
      _parseAndHandleJson(jsonStr);
    }
  }

  /// Parse a JSON string and handle it as a Gadgetbridge message
  void _parseAndHandleJson(String jsonStr) {
    try {
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      _handleGadgetbridgeMessage(json);
    } catch (e) {
      // Watch sometimes sends malformed JSON with unquoted values like:
      // {"t":"music", "n": play} instead of {"t":"music", "n": "play"}
      // Try to fix and reparse
      final fixedMessage = _fixMalformedJson(jsonStr);
      if (fixedMessage != null) {
        try {
          final json = jsonDecode(fixedMessage) as Map<String, dynamic>;
          _handleGadgetbridgeMessage(json);
        } catch (e2) {
          debugPrint('[BLE RX] JSON parse failed even after fix: $e2');
        }
      } else {
        debugPrint('[BLE RX] JSON parse failed: $e');
      }
    }
  }

  /// Attempt to fix malformed JSON with unquoted keys and values.
  /// 
  /// Handles:
  /// - Unquoted string values: {"t":"music", "n": play} -> {"t":"music", "n": "play"}
  /// - Unquoted keys: {id:"4"} -> {"id":"4"}
  String? _fixMalformedJson(String message) {
    var fixed = message;
    var wasModified = false;
    
    // Fix unquoted keys: { id:"value" or , id:"value"
    // Pattern: after { or , and optional whitespace, find an unquoted key followed by :
    final unquotedKeyRegex = RegExp(r'([{,])\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*:');
    final fixedKeys = fixed.replaceAllMapped(unquotedKeyRegex, (match) {
      final prefix = match.group(1)!; // { or ,
      final key = match.group(2)!;
      return '$prefix"$key":';
    });
    if (fixedKeys != fixed) {
      fixed = fixedKeys;
      wasModified = true;
    }
    
    // Fix unquoted string values: : value, or : value}
    // Pattern: after a colon and optional whitespace, find an unquoted word
    // that isn't a number, true, false, or null
    final unquotedValueRegex = RegExp(r':\s*([a-zA-Z_][a-zA-Z0-9_]*)(\s*[,}])');
    final fixedValues = fixed.replaceAllMapped(unquotedValueRegex, (match) {
      final value = match.group(1)!;
      final suffix = match.group(2)!;
      // Don't quote true, false, null
      if (value == 'true' || value == 'false' || value == 'null') {
        return ': $value$suffix';
      }
      return ': "$value"$suffix';
    });
    if (fixedValues != fixed) {
      fixed = fixedValues;
      wasModified = true;
    }
    
    return wasModified ? fixed : null;
  }

  void _handleGadgetbridgeMessage(Map<String, dynamic> message) {
    _incomingMessageController.add(message);

    final type = message['t'] as String?;
    if (type == null) return;

    switch (type) {
      case 'ver':
        // Device info response
        final fw = message['fw'] as String?;
        final hw = message['hw'] as String?;
        final watch = currentWatch;
        if (watch != null) {
          _watchInfoController.add(watch.copyWith(
            firmwareVersion: fw,
            hardwareVersion: hw,
          ));
        }
        break;

      case 'status':
        // Status update (includes battery)
        final battery = message['bat'] as int?;
        final isCharging = message['chg'] == 1;
        if (battery != null) {
          _batteryController.add(battery);
          final watch = currentWatch;
          if (watch != null) {
            _watchInfoController.add(watch.copyWith(batteryLevel: battery));
          }
          _updateConnection(currentConnection.copyWith(isCharging: isCharging));
        }
        break;
    }
  }

  Future<void> _setupBatteryNotifications() async {
    await _batterySubscription?.cancel();
    _batterySubscription = null;
    
    final batteryService = _findService(_guid(BatteryUuids.service));
    if (batteryService == null) return;

    final levelChar = _findCharacteristic(batteryService, _guid(BatteryUuids.level));
    if (levelChar == null) return;

    // Read initial value
    try {
      final data = await levelChar.read();
      if (data.isNotEmpty) {
        final level = data[0];
        _batteryController.add(level);
        final watch = currentWatch;
        if (watch != null) {
          _watchInfoController.add(watch.copyWith(batteryLevel: level));
        }
      }
    } catch (_) {}

    // Subscribe to notifications
    try {
      await levelChar.setNotifyValue(true);
      _batterySubscription = levelChar.onValueReceived.listen((data) {
        if (data.isNotEmpty) {
          final level = data[0];
          _batteryController.add(level);
          final watch = currentWatch;
          if (watch != null) {
            _watchInfoController.add(watch.copyWith(batteryLevel: level));
          }
        }
      });
    } catch (_) {}
  }

  /// Send Gadgetbridge command
  Future<void> _sendGb(Map<String, dynamic> data) async {
    final json = jsonEncode(data);
    await _sendNus('GB($json)');
  }

  /// Send raw NUS data
  /// 
  /// Automatically chunks large messages to fit within BLE MTU.
  /// Watch can receive up to 2000 bytes total, but each BLE packet
  /// is limited by MTU (typically 244 bytes usable).
  Future<void> _sendNus(String data) async {
    final nusService = _findService(_guid(NusUuids.service));
    if (nusService == null) return;

    final txChar = _findCharacteristic(nusService, _guid(NusUuids.txCharacteristic));
    if (txChar == null) return;

    debugPrint('[BLE TX] $data');
    
    // Emit to raw data stream for log viewer (FR-035a)
    _rawOutgoingDataController.add(data);

    final bytes = utf8.encode(data);
    
    // Get current MTU from connection, default to minimum if not set
    final currentMtu = _connectionController.value.mtu ?? BleConfig.minimumMtu;
    // Usable payload is MTU - 3 (ATT header)
    final maxChunkSize = currentMtu - 3;
    
    // If data fits in one packet, send directly
    if (bytes.length <= maxChunkSize) {
      await txChar.write(bytes, withoutResponse: txChar.properties.writeWithoutResponse);
      return;
    }
    
    // Check if total data exceeds watch's max buffer (2000 bytes)
    if (bytes.length > 2000) {
      debugPrint('[BLE TX] WARNING: Data exceeds watch max buffer (${bytes.length} > 2000), truncating');
      // Truncate to fit - this shouldn't happen for notifications if we handle it properly
    }
    
    // Split into chunks and send sequentially
    int offset = 0;
    int chunkNum = 0;
    while (offset < bytes.length) {
      final end = (offset + maxChunkSize).clamp(0, bytes.length);
      final chunk = bytes.sublist(offset, end);
      
      chunkNum++;
      debugPrint('[BLE TX] Chunk $chunkNum: ${chunk.length} bytes (offset $offset)');
      
      await txChar.write(chunk, withoutResponse: txChar.properties.writeWithoutResponse);
      
      // Small delay between chunks to allow BLE stack to process
      if (end < bytes.length) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
      
      offset = end;
    }
    
    debugPrint('[BLE TX] Sent ${bytes.length} bytes in $chunkNum chunks');
  }

  /// Request device info from watch
  Future<void> requestDeviceInfo() async {
    await _sendGb({'t': 'ver'});
  }

  /// Sync time to watch
  Future<void> syncTime() async {
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch ~/ 1000;
    final tz = now.timeZoneOffset.inMinutes / 60.0;
    await _sendNus('setTime($timestamp);E.setTimeZone($tz);');
  }

  /// Send notification to watch
  Future<void> sendNotification({
    required int id,
    required String source,
    String? title,
    String? body,
    String? sender,
    String? subject,
    String? phoneNumber,
    bool canReply = false,
  }) async {
    final data = <String, dynamic>{
      't': 'notify',
      'id': id,
      'src': source,
    };
    if (title != null) data['title'] = title;
    if (body != null) data['body'] = body;
    if (sender != null) data['sender'] = sender;
    if (subject != null) data['subject'] = subject;
    if (phoneNumber != null) data['tel'] = phoneNumber;
    if (canReply) data['reply'] = true;

    await _sendGb(data);
  }

  /// Update an existing notification on watch
  Future<void> updateNotification(int id, String body) async {
    await _sendGb({
      't': 'notify~',
      'id': id,
      'body': body,
    });
  }

  /// Remove a notification from watch
  Future<void> removeNotification(int id) async {
    await _sendGb({'t': 'notify-', 'id': id});
  }

  /// Send music playback state to watch
  Future<void> sendMusicState({
    required String state,
    int? positionSeconds,
    bool shuffle = false,
    bool repeat = false,
  }) async {
    final data = <String, dynamic>{
      't': 'musicstate',
      'state': state,
    };
    if (positionSeconds != null) data['position'] = positionSeconds;
    if (shuffle) data['shuffle'] = 1;
    if (repeat) data['repeat'] = 1;

    await _sendGb(data);
  }

  /// Send music track info to watch
  Future<void> sendMusicInfo({
    String? artist,
    String? album,
    String? track,
    int? durationSeconds,
    int? trackNumber,
    int? trackCount,
  }) async {
    final data = <String, dynamic>{'t': 'musicinfo'};
    if (artist != null) data['artist'] = artist;
    if (album != null) data['album'] = album;
    if (track != null) data['track'] = track;
    if (durationSeconds != null) data['dur'] = durationSeconds;
    if (trackCount != null) data['c'] = trackCount;
    if (trackNumber != null) data['n'] = trackNumber;

    await _sendGb(data);
  }

  /// Start/stop find device (vibrate watch)
  Future<void> findDevice(bool enabled) async {
    await _sendGb({'t': 'find', 'n': enabled});
  }

  /// Vibrate watch with pattern
  Future<void> vibrate(int pattern) async {
    await _sendGb({'t': 'vibrate', 'n': pattern});
  }

  /// Send GPS data to watch (Gadgetbridge format)
  /// 
  /// Called in response to watch GPS power request ({"t":"gps_power","status":true})
  Future<void> sendGpsData(WatchGpsData data) async {
    final gpsData = <String, dynamic>{
      't': 'gps',
      'lat': data.latitude,
      'lon': data.longitude,
      'externalSource': true,
    };
    if (data.altitude != null) gpsData['alt'] = data.altitude;
    if (data.speedKph != null) gpsData['speed'] = data.speedKph;
    if (data.courseDegrees != null) gpsData['course'] = data.courseDegrees;
    if (data.timestampMs != null) gpsData['time'] = data.timestampMs;
    if (data.satellites != null) gpsData['satellites'] = data.satellites;
    if (data.hdop != null) gpsData['hdop'] = data.hdop;
    if (data.source != null) gpsData['gpsSource'] = data.source;

    await _sendGb(gpsData);
  }

  /// Send HTTP response to watch (for HTTP relay)
  /// 
  /// Used when watch requests a URL via `t:"http"` and app successfully fetches it.
  /// [requestId] is echoed back to match responses with requests.
  /// [response] is the response body or XPath-evaluated result.
  Future<void> sendHttpResponse(String requestId, String response) async {
    final data = <String, dynamic>{
      't': 'http',
      'resp': response,
    };
    if (requestId.isNotEmpty) {
      data['id'] = requestId;
    }
    await _sendGb(data);
  }

  /// Send HTTP error to watch (for HTTP relay)
  /// 
  /// Used when watch requests a URL via `t:"http"` and app fails to fetch it.
  /// [requestId] is echoed back to match responses with requests.
  /// [error] describes what went wrong.
  Future<void> sendHttpError(String requestId, String error) async {
    final data = <String, dynamic>{
      't': 'http',
      'err': error,
    };
    if (requestId.isNotEmpty) {
      data['id'] = requestId;
    }
    await _sendGb(data);
  }

  /// Enable/disable log streaming from watch (FR-035c, FR-035d)
  /// 
  /// Sends {"t":"log","status":true/false} to watch.
  /// Note: Watch may also have its own setting for this, so logs may be
  /// received even if the app hasn't explicitly requested them (FR-035e).
  Future<void> setLogStreaming(bool enabled) async {
    await _sendGb({'t': 'log', 'status': enabled});
    _logStreamingEnabled = enabled;
  }

  /// Enable log streaming from watch
  Future<void> enableLogStreaming() => setLogStreaming(true);

  /// Disable log streaming from watch
  Future<void> disableLogStreaming() => setLogStreaming(false);

  // ==================== LLEXT App Management ====================

  /// Prepare/create an LLEXT app directory on the watch filesystem.
  ///
  /// Sends `{"t":"llext","op":"mkdir","id":<appId>}` via Gadgetbridge.
  /// The watch creates `/lvgl_lfs/apps/<appId>` if it does not already exist.
  Future<void> llextMkdir(String appId) async {
    await _sendGb({'t': 'llext', 'op': 'mkdir', 'id': appId});
  }

  /// Remove an LLEXT app from the watch filesystem.
  ///
  /// Sends `{"t":"llext","op":"rm","id":<appId>}` via Gadgetbridge.
  /// The watch unlinks `/lvgl_lfs/apps/<appId>/app.llext` and the directory.
  Future<void> llextRemove(String appId) async {
    await _sendGb({'t': 'llext', 'op': 'rm', 'id': appId});
  }

  /// Hot-load an LLEXT app on the watch (no reboot required).
  ///
  /// Sends `{"t":"llext","op":"load","id":<appId>}` via Gadgetbridge.
  /// The watch loads the app from `/lvgl_lfs/apps/<appId>/app.llext`,
  /// registers it with the app manager, and shows a popup notification.
  Future<void> llextLoad(String appId) async {
    await _sendGb({'t': 'llext', 'op': 'load', 'id': appId});
  }

  // ==================== SMP (MCUmgr) Management ====================

  /// Enable MCUmgr/SMP on the watch via Gadgetbridge.
  ///
  /// Sends `{"t":"smp","status":true}`. The watch enables SMP BLE transport,
  /// switches to fast advertising/short connection interval, and starts
  /// a 3-minute auto-disable timer.
  Future<void> enableSmp() async {
    await _sendGb({'t': 'smp', 'status': true});
  }

  /// Disable MCUmgr/SMP on the watch via Gadgetbridge.
  ///
  /// Sends `{"t":"smp","status":false}`. The watch disables SMP and restores
  /// default BLE parameters.
  Future<void> disableSmp() async {
    await _sendGb({'t': 'smp', 'status': false});
  }

  // ==================== Watch Reset ====================

  /// Request the watch to perform a cold reboot.
  ///
  /// Sends `{"t":"reset"}` via Gadgetbridge. The watch will reboot
  /// after a short delay (to ACK the BLE packet).
  Future<void> resetWatch() async {
    await _sendGb({'t': 'reset'});
  }

  void _handleConnectionStateChange(
    BluetoothConnectionState state,
    String watchId,
    String name,
  ) {
    debugPrint('[WatchService:$hashCode] _handleConnectionStateChange: state=$state, _isCancelled=$_isCancelled, _isWaitingForAutoConnect=$_isWaitingForAutoConnect, _isInitiatingConnection=$_isInitiatingConnection');
    
    // If user has cancelled, ignore all connection events and disconnect
    if (_isCancelled) {
      debugPrint('[WatchService:$hashCode] Ignoring connection event - cancelled by user');
      if (state == BluetoothConnectionState.connected) {
        // Force disconnect if BLE layer reports connected after cancel
        BluetoothDevice.fromId(watchId).disconnect();
      }
      return;
    }

    switch (state) {
      case BluetoothConnectionState.connected:
        // Clear the waiting/initiating flags - we're now connected
        _isWaitingForAutoConnect = false;
        _isInitiatingConnection = false;
        
        // For autoConnect or background reconnect, we need to run setup when connection happens
        // Check if we're in connecting/reconnecting state (waiting for connection)
        final currentState = currentConnection.state;
        final isWaitingForConnection = currentState == WatchConnectionState.connecting ||
                                       currentState == WatchConnectionState.reconnecting;
        
        if (isWaitingForConnection && !_isSettingUp) {
          // Also check _autoReconnect - if false, user cancelled and we should disconnect
          if (!_autoReconnect) {
            debugPrint('[WatchService] Connection arrived but cancelled - disconnecting');
            _device?.disconnect();
            _cleanup();
            _updateConnection(Connection(
              watchId: watchId,
              watchName: name,
              state: WatchConnectionState.disconnected,
            ));
            return;
          }
          debugPrint('[WatchService] AutoConnect/BackgroundReconnect triggered - running setup');
          _setupAfterConnect(watchId, name);
        }
        break;
      case BluetoothConnectionState.disconnected:
        _handleDisconnect(watchId, name);
        break;
      // ignore: deprecated_member_use
      case BluetoothConnectionState.connecting:
      // ignore: deprecated_member_use
      case BluetoothConnectionState.disconnecting:
        // Transient states - no action needed
        break;
    }
  }

  void _handleDisconnect(String watchId, String name) {
    debugPrint('[WatchService:$hashCode] _handleDisconnect: _isCancelled=$_isCancelled, _autoReconnect=$_autoReconnect, _reconnectAttempts=$_reconnectAttempts, _isReconnecting=$_isReconnecting, _isSettingUp=$_isSettingUp, _isWaitingForAutoConnect=$_isWaitingForAutoConnect, _isInitiatingConnection=$_isInitiatingConnection, _isInBackgroundReconnect=$_isInBackgroundReconnect');
    
    // If user has cancelled, don't attempt reconnection
    if (_isCancelled) {
      debugPrint('[WatchService:$hashCode] Disconnect ignored - cancelled by user');
      _isReconnecting = false;
      _isWaitingForAutoConnect = false;
      _isInitiatingConnection = false;
      _isInBackgroundReconnect = false;
      _updateConnection(Connection(
        watchId: watchId,
        watchName: name,
        state: WatchConnectionState.disconnected,
      ));
      _cleanup();
      return;
    }
    
    // If we're in background reconnect mode, the OS is handling reconnection
    // Stay in reconnecting state and wait for the device to appear
    // This check must come BEFORE the _isWaitingForAutoConnect check
    if (_isInBackgroundReconnect) {
      debugPrint('[WatchService:$hashCode] Disconnect during background reconnect - OS will keep trying');
      // Keep the reconnecting state visible to user
      _updateConnection(currentConnection.copyWith(
        state: WatchConnectionState.reconnecting,
      ));
      return;
    }
    
    // If we're initiating a connection (either autoConnect or regular), this is just
    // the initial state notification (BLE layer reports disconnected when we first
    // subscribe to connection state). Don't treat this as a real disconnect.
    if (_isWaitingForAutoConnect || _isInitiatingConnection) {
      debugPrint('[WatchService:$hashCode] Disconnect ignored - connection in progress (waiting for BLE to connect)');
      return;
    }
    
    // Don't start another reconnect if one is already in progress
    if (_isReconnecting) {
      debugPrint('[WatchService:$hashCode] Disconnect ignored - reconnect already in progress');
      return;
    }
    
    // If setup is in progress, it will detect the disconnect via _shouldContinueSetup()
    // and exit gracefully. The setup's finally block will trigger reconnect if needed.
    // We just mark the pending reconnect info so setup knows what to reconnect to.
    if (_isSettingUp) {
      debugPrint('[WatchService:$hashCode] Setup in progress - setup will handle reconnect when it completes');
      // Mark pending reconnect - setup's finally block will check this
      if (_autoReconnect && !_isCancelled) {
        _pendingReconnectAfterSetup = true;
        _pendingReconnectWatchId = watchId;
        _pendingReconnectWatchName = name;
      }
      return;
    }

    final wasConnected = currentConnection.isConnected || 
                         currentConnection.state == WatchConnectionState.connecting ||
                         currentConnection.state == WatchConnectionState.bonding ||
                         currentConnection.state == WatchConnectionState.discoveringServices ||
                         currentConnection.state == WatchConnectionState.negotiating ||
                         currentConnection.state == WatchConnectionState.syncing ||
                         currentConnection.state == WatchConnectionState.error;

    if (wasConnected && _autoReconnect && _reconnectAttempts < _maxQuickReconnectAttempts) {
      // First try quick reconnects for momentary disconnects
      _attemptReconnect(watchId, name);
    } else if (wasConnected && _autoReconnect && !_isInBackgroundReconnect) {
      // After quick retries fail, switch to background auto-connect mode
      // This lets the OS handle reconnection when the device becomes available
      _startBackgroundReconnect(watchId, name);
    } else {
      _updateConnection(Connection(
        watchId: watchId,
        watchName: name,
        state: WatchConnectionState.disconnected,
      ));
      _cleanup();
    }
  }
  
  /// Start background reconnection using periodic retries
  /// 
  /// This is used after quick reconnect attempts fail. Will keep retrying
  /// with increasing delays until connected or cancelled.
  void _startBackgroundReconnect(String watchId, String name) {
    debugPrint('[WatchService:$hashCode] Starting background reconnect for $watchId');
    
    if (_isCancelled) {
      debugPrint('[WatchService:$hashCode] Background reconnect skipped - cancelled by user');
      return;
    }
    
    // Clean up any existing state first
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    
    _isInBackgroundReconnect = true;
    _isReconnecting = false; // Clear quick reconnect flag - we're now in background mode
    _isWaitingForAutoConnect = false;
    _isInitiatingConnection = false;
    
    // Show reconnecting state to user
    _updateConnection(Connection(
      watchId: watchId,
      watchName: name,
      state: WatchConnectionState.reconnecting,
      reconnectionCount: _reconnectAttempts,
    ));
    
    // Start periodic reconnect attempts
    _scheduleBackgroundReconnectAttempt(watchId, name);
  }
  
  /// Schedule a single background reconnect attempt
  void _scheduleBackgroundReconnectAttempt(String watchId, String name) {
    if (_isCancelled || !_isInBackgroundReconnect) {
      debugPrint('[WatchService:$hashCode] Background reconnect cancelled - stopping');
      return;
    }
    
    // Use exponential backoff with a cap: 5s, 10s, 15s, then stay at 15s
    final attemptNumber = _reconnectAttempts - _maxQuickReconnectAttempts;
    final delaySeconds = (5 + (attemptNumber * 5)).clamp(5, 15);
    final delay = Duration(seconds: delaySeconds);
    
    debugPrint('[WatchService:$hashCode] Scheduling background reconnect in ${delay.inSeconds}s (attempt $attemptNumber)');
    
    _reconnectTimer = Timer(delay, () async {
      if (_isCancelled || !_isInBackgroundReconnect) {
        debugPrint('[WatchService:$hashCode] Background reconnect timer cancelled');
        return;
      }
      
      _reconnectAttempts++;
      debugPrint('[WatchService:$hashCode] Background reconnect attempt $_reconnectAttempts');
      
      // Create fresh device instance
      _device = BluetoothDevice.fromId(watchId);
      
      // Cancel any existing subscription and create a new one
      await _connectionSubscription?.cancel();
      _connectionSubscription = _device!.connectionState.listen(
        (state) => _handleConnectionStateChange(state, watchId, name),
      );
      
      try {
        // Try to connect with a short timeout
        await _device!.connect(
          license: License.free,
          timeout: const Duration(seconds: 10),
          autoConnect: false,
        );
        // If we get here, connection succeeded - setup will handle the rest
        debugPrint('[WatchService:$hashCode] Background reconnect connected!');
        _isInBackgroundReconnect = false;
      } catch (e) {
        debugPrint('[WatchService:$hashCode] Background reconnect attempt failed: $e');
        // Schedule next attempt if not cancelled
        if (!_isCancelled && _isInBackgroundReconnect) {
          _scheduleBackgroundReconnectAttempt(watchId, name);
        }
      }
    });
  }

  void _attemptReconnect(String watchId, String name) {
    debugPrint('[WatchService:$hashCode] _attemptReconnect: _isCancelled=$_isCancelled, _autoReconnect=$_autoReconnect, _reconnectAttempts=$_reconnectAttempts');
    
    // If user has cancelled, don't attempt reconnection
    if (_isCancelled) {
      debugPrint('[WatchService:$hashCode] Reconnect skipped - cancelled by user');
      _isReconnecting = false;
      return;
    }

    // Cancel any existing reconnect timer to prevent stacking
    _reconnectTimer?.cancel();
    
    _reconnectAttempts++;
    _isReconnecting = true;  // Mark that we're in reconnect flow
    debugPrint('[WatchService:$hashCode] Scheduling reconnect timer (attempt $_reconnectAttempts)');

    // Only show "Reconnecting" if we've actually been connected before
    // For initial connection failures (e.g., autoConnect assertion error), keep showing "Connecting"
    if (_isInitialConnection) {
      debugPrint('[WatchService:$hashCode] Initial connection - keeping Connecting state');
      // Don't change state, keep showing "Connecting"
    } else {
      _updateConnection(currentConnection.copyWith(
        state: WatchConnectionState.reconnecting,
        reconnectionCount: _reconnectAttempts,
      ));
    }

    _reconnectTimer = Timer(BleConfig.reconnectionDelay, () async {
      debugPrint('[WatchService:$hashCode] Reconnect timer fired: _isCancelled=$_isCancelled, _autoReconnect=$_autoReconnect');
      // Double-check cancellation inside timer callback
      if (_isCancelled) {
        debugPrint('[WatchService:$hashCode] Reconnect timer skipped - cancelled by user');
        _isReconnecting = false;
        return;
      }
      if (_device != null && _autoReconnect && !_isSettingUp) {
        try {
          await _connectToDevice(_device!, watchId, name, isReconnectAttempt: true);
          _isReconnecting = false;  // Clear flag on successful connect start
        } catch (e) {
          debugPrint('[WatchService:$hashCode] Reconnect attempt $_reconnectAttempts failed: $e');
          _isReconnecting = false;  // Clear flag to allow next attempt
          _isInitiatingConnection = false; // Clear flag since connection attempt is done
          
          // Check if cancelled during the await - if so, don't continue reconnect logic
          if (_isCancelled) {
            debugPrint('[WatchService:$hashCode] Reconnect cancelled during attempt - cleaning up');
            _cleanup();
            return;
          }
          
          if (_reconnectAttempts >= _maxQuickReconnectAttempts) {
            // Quick retries exhausted - switch to background reconnect
            debugPrint('[WatchService:$hashCode] Quick retries exhausted - switching to background reconnect');
            _startBackgroundReconnect(watchId, name);
          } else {
            // More quick attempts remaining - schedule next one
            debugPrint('[WatchService:$hashCode] Scheduling next quick reconnect attempt');
            _attemptReconnect(watchId, name);
          }
        }
      } else {
        _isReconnecting = false;
      }
    });
  }

  /// Cancel any pending connection (for autoConnect scenarios)
  /// This prevents the connection from being established even if the device appears
  void cancelPendingConnection() {
    debugPrint('[WatchService:$hashCode] cancelPendingConnection() called - setting _isCancelled=true, _autoReconnect=false');
    _autoReconnect = false;
    _isCancelled = true; // Mark as cancelled to ignore future connection events
    _isReconnecting = false; // Clear reconnecting flag
    _isWaitingForAutoConnect = false; // Clear waiting flag
    _isInitiatingConnection = false; // Clear initiating flag
    _isInBackgroundReconnect = false; // Clear background reconnect flag
    _reconnectTimer?.cancel();
    
    // If we're in any connecting state, transition to disconnected
    final state = currentConnection.state;
    if (state.isConnectingOrReconnecting) {
      final watchId = currentConnection.watchId;
      final watchName = currentConnection.watchName;
      
      // IMPORTANT: Call disconnect BEFORE cleanup to cancel any pending BLE operation
      // Use both the stored device reference AND create one from ID for maximum coverage
      final device = _device;
      if (device != null) {
        debugPrint('[WatchService:$hashCode] Disconnecting device to cancel pending connection');
        device.disconnect();
      } else if (watchId.isNotEmpty) {
        // If _device is null but we have a watchId, create device from ID and disconnect
        debugPrint('[WatchService:$hashCode] Creating device from ID to cancel: $watchId');
        BluetoothDevice.fromId(watchId).disconnect();
      }
      
      _cleanup();
      _updateConnection(Connection(
        watchId: watchId,
        watchName: watchName,
        state: WatchConnectionState.disconnected,
      ));
    }
  }

  /// Disconnect from current device
  Future<void> disconnect() async {
    _autoReconnect = false;
    _isCancelled = true; // Mark as cancelled to ignore reconnection attempts
    _isInBackgroundReconnect = false; // Clear background reconnect flag
    _reconnectTimer?.cancel();

    final device = _device;
    final watchId = currentConnection.watchId;
    final watchName = currentConnection.watchName;

    _cleanup();

    if (device != null) {
      try {
        await device.disconnect();
      } catch (_) {}
    }

    _updateConnection(Connection(
      watchId: watchId,
      watchName: watchName,
      state: WatchConnectionState.disconnected,
    ));
  }

  void _cleanup() {
    _connectionSubscription?.cancel();
    _connectionSubscription = null;
    _nusSubscription?.cancel();
    _nusSubscription = null;
    _batterySubscription?.cancel();
    _batterySubscription = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _stopRssiUpdates();
    _device = null;
    _services = null;
    _isSettingUp = false;
    _isReconnecting = false;
    _isInitialConnection = false;
    _isWaitingForAutoConnect = false;
    _isInitiatingConnection = false;
    _isInBackgroundReconnect = false;
    _pendingReconnectAfterSetup = false;
    _pendingReconnectWatchId = null;
    _pendingReconnectWatchName = null;
    _messageBuffer = ''; // Clear any incomplete messages
    _inBleLog = false; // Clear BLELOG tracking state
  }

  void _updateConnection(Connection connection) {
    _connectionController.add(connection);
  }

  BluetoothService? _findService(Guid uuid) {
    return _services?.cast<BluetoothService?>().firstWhere(
          (s) => s?.uuid == uuid,
          orElse: () => null,
        );
  }

  BluetoothCharacteristic? _findCharacteristic(BluetoothService service, Guid uuid) {
    return service.characteristics.cast<BluetoothCharacteristic?>().firstWhere(
          (c) => c?.uuid == uuid,
          orElse: () => null,
        );
  }

  /// Dispose resources
  Future<void> dispose() async {
    await disconnect();
    await _connectionController.close();
    await _watchInfoController.close();
    await _batteryController.close();
    await _incomingMessageController.close();
    await _rawIncomingDataController.close();
    await _rawOutgoingDataController.close();
  }
}


