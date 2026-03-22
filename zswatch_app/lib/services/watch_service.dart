import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:rxdart/rxdart.dart';

import '../core/constants/ble_constants.dart';
import '../data/models/connection.dart';
import '../data/models/connection_phase.dart';
import '../data/models/crash_summary.dart';
import '../data/models/watch.dart';
import 'ble/ble_connection_service.dart';
import 'ble/ble_scanner.dart';
import 'protocol/protocol_service.dart';

// Convert String UUIDs to Guid for flutter_blue_plus
Guid _guid(String uuid) => Guid(uuid);

/// Watch communication service.
///
/// Handles protocol communication (Gadgetbridge), message parsing/routing,
/// battery monitoring, and raw data streams for developer tools.
///
/// Connection lifecycle (connect, reconnect, disconnect) is delegated to
/// [BleConnectionService].
class WatchService {
  final BleConnectionService _ble;

  WatchService(this._ble) {
    // Register our setup callback so BleConnectionService calls us
    // after BLE-level setup (bonding, service discovery, MTU) is done.
    _ble.onSetupRequired = _onSetupRequired;

    // Mirror phase changes to keep our streams updated
    _phaseSubscription = _ble.phaseStream.listen(_onPhaseChanged);
  }

  StreamSubscription<ConnectionPhase>? _phaseSubscription;
  StreamSubscription<List<int>>? _nusSubscription;
  BluetoothCharacteristic? _nusRxChar;
  StreamSubscription<List<int>>? _batterySubscription;
  BluetoothCharacteristic? _batteryLevelChar;

  final _watchInfoController = BehaviorSubject<Watch?>.seeded(null);
  final _batteryController = BehaviorSubject<int>.seeded(0);
  final _crashSummaryController = BehaviorSubject<CrashSummary?>.seeded(null);
  final _incomingMessageController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Raw data streams for developer tools (FR-035a)
  final _rawIncomingDataController = StreamController<String>.broadcast();
  final _rawOutgoingDataController = StreamController<String>.broadcast();

  // Log streaming state (FR-035c, FR-035d)
  bool _logStreamingEnabled = false;

  // Buffer for multi-packet JSON messages
  String _messageBuffer = '';

  // Tracks if we're currently inside a <BLELOG> section (may span multiple chunks)
  bool _inBleLog = false;

  // --- Public API: streams ---

  /// Stream of connection state changes (delegates to BleConnectionService).
  Stream<Connection> get connectionStream => _ble.connectionStream;

  /// Stream of watch info updates.
  Stream<Watch?> get watchInfoStream => _watchInfoController.stream;

  /// Stream of battery level updates.
  Stream<int> get batteryStream => _batteryController.stream;

  /// Stream of incoming parsed messages from watch.
  Stream<Map<String, dynamic>> get incomingMessages =>
      _incomingMessageController.stream;

  /// Stream of ALL raw incoming BLE NUS data for log viewer (FR-035a).
  Stream<String> get rawIncomingData => _rawIncomingDataController.stream;

  /// Stream of ALL raw outgoing BLE NUS data for log viewer.
  Stream<String> get rawOutgoingData => _rawOutgoingDataController.stream;

  /// Stream of crash summary received on BLE connect (null if no crash).
  Stream<CrashSummary?> get crashSummaryStream =>
      _crashSummaryController.stream;

  /// Current crash summary.
  CrashSummary? get currentCrashSummary => _crashSummaryController.value;

  // Firmware identity from last 'ver' message
  String? _fwCommitSha;
  bool _fwIsDebug = false;

  /// Commit SHA from last firmware version message.
  String? get fwCommitSha => _fwCommitSha;

  // --- Public API: getters ---

  /// Whether log streaming is enabled on watch.
  bool get logStreamingEnabled => _logStreamingEnabled;

  /// Current connection state (delegates to BleConnectionService).
  Connection get currentConnection => _ble.currentConnection;

  /// Current connection phase.
  ConnectionPhase get currentPhase => _ble.currentPhase;

  /// Current watch info.
  Watch? get currentWatch => _watchInfoController.value;

  /// Whether connected.
  bool get isConnected => _ble.isConnected;

  /// Current BLE device (for sensor GATT service initialization).
  BluetoothDevice? get device => _ble.device;

  /// Discovered BLE services (for sensor GATT service initialization).
  List<BluetoothService>? get services => _ble.services;

  /// Whether the connected device has the MCUmgr/SMP service available.
  bool get hasSmpService => _ble.hasSmpService;

  // --- Public API: connection (delegates to BleConnectionService) ---

  /// Connect to a scanned device.
  Future<void> connect(
    ScannedWatch scannedDevice, {
    bool autoConnect = false,
  }) => _ble.connect(scannedDevice, autoConnect: autoConnect);

  /// Connect by device ID (for saved watches).
  Future<void> connectById(String deviceId, {bool autoConnect = false}) =>
      _ble.connectById(deviceId, autoConnect: autoConnect);

  /// Cancel any pending connection.
  void cancelPendingConnection() => _ble.cancelPendingConnection();

  /// Disconnect from current device.
  Future<void> disconnect() async {
    _cleanupProtocol();
    await _ble.disconnect();
  }

  /// Re-discover BLE services.
  Future<bool> rediscoverServices() => _ble.rediscoverServices();

  // --- Public API: protocol commands ---

  /// Request device info from watch.
  Future<void> requestDeviceInfo() async {
    await _sendGb({'t': 'ver'});
  }

  /// Sync time to watch.
  Future<void> syncTime() async {
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch ~/ 1000;
    final tz = now.timeZoneOffset.inMinutes / 60.0;
    await _sendNus('setTime($timestamp);E.setTimeZone($tz);');
  }

  /// Send notification to watch.
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
    final data = <String, dynamic>{'t': 'notify', 'id': id, 'src': source};
    if (title != null) data['title'] = title;
    if (body != null) data['body'] = body;
    if (sender != null) data['sender'] = sender;
    if (subject != null) data['subject'] = subject;
    if (phoneNumber != null) data['tel'] = phoneNumber;
    if (canReply) data['reply'] = true;
    await _sendGb(data);
  }

  /// Update an existing notification on watch.
  Future<void> updateNotification(int id, String body) async {
    await _sendGb({'t': 'notify~', 'id': id, 'body': body});
  }

  /// Remove a notification from watch.
  Future<void> removeNotification(int id) async {
    await _sendGb({'t': 'notify-', 'id': id});
  }

  /// Send music playback state to watch.
  Future<void> sendMusicState({
    required String state,
    int? positionSeconds,
    bool shuffle = false,
    bool repeat = false,
  }) async {
    final data = <String, dynamic>{'t': 'musicstate', 'state': state};
    if (positionSeconds != null) data['position'] = positionSeconds;
    if (shuffle) data['shuffle'] = 1;
    if (repeat) data['repeat'] = 1;
    await _sendGb(data);
  }

  /// Send music track info to watch.
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

  /// Start/stop find device (vibrate watch).
  Future<void> findDevice(bool enabled) async {
    await _sendGb({'t': 'find', 'n': enabled});
  }

  /// Vibrate watch with pattern.
  Future<void> vibrate(int pattern) async {
    await _sendGb({'t': 'vibrate', 'n': pattern});
  }

  /// Send GPS data to watch.
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

  /// Send HTTP response to watch.
  Future<void> sendHttpResponse(String requestId, String response) async {
    final data = <String, dynamic>{'t': 'http', 'resp': response};
    if (requestId.isNotEmpty) data['id'] = requestId;
    await _sendGb(data);
  }

  /// Send HTTP error to watch.
  Future<void> sendHttpError(String requestId, String error) async {
    final data = <String, dynamic>{'t': 'http', 'err': error};
    if (requestId.isNotEmpty) data['id'] = requestId;
    await _sendGb(data);
  }

  /// Enable/disable log streaming from watch.
  Future<void> setLogStreaming(bool enabled) async {
    await _sendGb({'t': 'log', 'status': enabled});
    _logStreamingEnabled = enabled;
  }

  /// Enable log streaming from watch.
  Future<void> enableLogStreaming() => setLogStreaming(true);

  /// Disable log streaming from watch.
  Future<void> disableLogStreaming() => setLogStreaming(false);

  /// Send a voice memo command to the watch.
  Future<void> sendVoiceMemoCommand(
    String action, {
    Map<String, dynamic>? extraData,
  }) async {
    final data = <String, dynamic>{'t': 'voice_memo', 'action': action};
    if (extraData != null) data.addAll(extraData);
    await _sendGb(data);
  }

  /// Enable MCUmgr/SMP on the watch.
  Future<void> enableSmp() => _sendGb({'t': 'smp', 'status': true});

  /// Disable MCUmgr/SMP on the watch.
  Future<void> disableSmp() => _sendGb({'t': 'smp', 'status': false});

  /// Request the watch to perform a cold reboot.
  Future<void> resetWatch() => _sendGb({'t': 'reset'});

  /// Erase the coredump on the watch.
  Future<void> eraseCoredump() async {
    await _sendGb({'t': 'coredump_erase'});
    _crashSummaryController.add(null);
  }

  // --- Setup callback (called by BleConnectionService) ---

  Future<void> _onSetupRequired(
    BluetoothDevice device,
    List<BluetoothService> services,
    String watchId,
    String name,
  ) async {
    // Create or update watch object
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

    // Setup NUS for Gadgetbridge protocol
    try {
      await _setupNus(services);
    } catch (e) {
      debugPrint('[WatchService] NUS setup failed: $e');
    }

    // Subscribe to battery service
    try {
      await _setupBatteryNotifications(services);
    } catch (e) {
      debugPrint('[WatchService] Battery setup failed: $e');
    }

    // Time sync + device info — await these before returning so they
    // complete while the connection is still being set up.  Previously
    // these were fire-and-forget, but that caused silent failures
    // (e.g. time never synced on reconnect).
    try {
      await syncTime();
    } catch (e) {
      debugPrint('[WatchService] syncTime failed: $e');
    }
    try {
      await requestDeviceInfo();
    } catch (e) {
      debugPrint('[WatchService] requestDeviceInfo failed: $e');
    }
  }

  // --- Phase change handler ---

  void _onPhaseChanged(ConnectionPhase phase) {
    if (phase is Disconnected || phase is PhaseError) {
      _cleanupProtocol();
    }
  }

  // --- Internal: NUS and message handling ---

  Future<void> _setupNus(List<BluetoothService> services) async {
    await _nusSubscription?.cancel();
    _nusSubscription = null;
    try {
      await _nusRxChar?.setNotifyValue(false);
    } catch (_) {}
    _nusRxChar = null;

    // Reset protocol state — critical for auto-reconnect where
    // _cleanupProtocol() is not called (phase goes Reconnecting, not
    // Disconnected). Without this, a crash mid-BLE-log-send leaves
    // _inBleLog=true, silently filtering all subsequent NUS data.
    _messageBuffer = '';
    _inBleLog = false;

    final nusService = _findServiceIn(services, _guid(NusUuids.service));
    if (nusService == null) return;

    final rxChar = _findCharacteristic(
      nusService,
      _guid(NusUuids.rxCharacteristic),
    );
    if (rxChar == null) return;

    _nusRxChar = rxChar;
    await rxChar.setNotifyValue(true);
    _nusSubscription = rxChar.onValueReceived.listen(_handleNusData);
  }

  void _handleNusData(List<int> data) {
    try {
      final chunk = utf8.decode(data);
      if (chunk.isEmpty) return;

      // Emit to raw data stream for log viewer (FR-035a)
      _rawIncomingDataController.add(chunk);

      // Filter out <BLELOG>...</BLELOG> sections
      final filteredChunk = _filterBleLogSections(chunk);

      if (filteredChunk.isNotEmpty) {
        _messageBuffer += filteredChunk;
        _processMessageBuffer();
      }
    } catch (e) {
      debugPrint('[BLE RX] Raw bytes: $data');
      _rawIncomingDataController.add('RAW: $data');
    }
  }

  String _filterBleLogSections(String chunk) {
    const bleLogStart = '<BLELOG>';
    const bleLogEnd = '</BLELOG>';

    final result = StringBuffer();
    var remaining = chunk;

    while (remaining.isNotEmpty) {
      if (_inBleLog) {
        final endIndex = remaining.indexOf(bleLogEnd);
        if (endIndex == -1) break;
        remaining = remaining.substring(endIndex + bleLogEnd.length);
        _inBleLog = false;
      } else {
        final startIndex = remaining.indexOf(bleLogStart);
        if (startIndex == -1) {
          result.write(remaining);
          break;
        }
        result.write(remaining.substring(0, startIndex));
        remaining = remaining.substring(startIndex + bleLogStart.length);
        _inBleLog = true;
      }
    }

    return result.toString();
  }

  void _processMessageBuffer() {
    while (_messageBuffer.isNotEmpty) {
      final jsonStart = _messageBuffer.indexOf('{');
      if (jsonStart == -1) {
        _messageBuffer = '';
        break;
      }

      if (jsonStart > 0) {
        _messageBuffer = _messageBuffer.substring(jsonStart);
      }

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
        debugPrint(
          '[BLE RX] Buffering incomplete JSON (${_messageBuffer.length} bytes)',
        );
        break;
      }

      final jsonStr = _messageBuffer.substring(0, jsonEnd);
      _messageBuffer = _messageBuffer.substring(jsonEnd);

      _parseAndHandleJson(jsonStr);
    }
  }

  void _parseAndHandleJson(String jsonStr) {
    try {
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      _handleGadgetbridgeMessage(json);
    } catch (e) {
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

  String? _fixMalformedJson(String message) {
    var fixed = message;
    var wasModified = false;

    final unquotedKeyRegex = RegExp(r'([{,])\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*:');
    final fixedKeys = fixed.replaceAllMapped(unquotedKeyRegex, (match) {
      final prefix = match.group(1)!;
      final key = match.group(2)!;
      return '$prefix"$key":';
    });
    if (fixedKeys != fixed) {
      fixed = fixedKeys;
      wasModified = true;
    }

    final unquotedValueRegex = RegExp(r':\s*([a-zA-Z_][a-zA-Z0-9_]*)(\s*[,}])');
    final fixedValues = fixed.replaceAllMapped(unquotedValueRegex, (match) {
      final value = match.group(1)!;
      final suffix = match.group(2)!;
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
        debugPrint(
          '[WatchService] Ver response: sha=${message['sha']}, dbg=${message['dbg']}',
        );
        final fw = message['fw'] as String?;
        final hw = message['hw'] as String?;
        _fwCommitSha = message['sha'] as String?;
        _fwIsDebug = message['dbg'] == 1;
        final watch = currentWatch;
        if (watch != null) {
          _watchInfoController.add(
            watch.copyWith(firmwareVersion: fw, hardwareVersion: hw),
          );
        }
        break;

      case 'coredump':
        debugPrint('[WatchService] Coredump message: $message');
        final available = message['available'] == true;
        if (available) {
          _crashSummaryController.add(
            CrashSummary(
              file: message['file'] as String? ?? '',
              line: message['line'] as int? ?? 0,
              time: message['time'] as String? ?? '',
              fwVersion: currentWatch?.firmwareVersion ?? '',
              fwCommitSha: _fwCommitSha ?? '',
              board: currentWatch?.hardwareVersion ?? 'watchdk',
              buildType: _fwIsDebug ? 'debug' : 'release',
            ),
          );
        } else {
          _crashSummaryController.add(null);
        }
        break;

      case 'status':
        final battery = message['bat'] as int?;
        final isCharging = message['chg'] == 1;
        if (battery != null) {
          _batteryController.add(battery);
          final watch = currentWatch;
          if (watch != null) {
            _watchInfoController.add(watch.copyWith(batteryLevel: battery));
          }
          _ble.updateConnectionField((c) => c.copyWith(isCharging: isCharging));
        }
        break;

      case 'voice_memo':
        debugPrint('[WatchService] Voice memo message: ${message['action']}');
        break;
    }
  }

  // --- Internal: battery ---

  Future<void> _setupBatteryNotifications(
    List<BluetoothService> services,
  ) async {
    await _batterySubscription?.cancel();
    _batterySubscription = null;
    try {
      await _batteryLevelChar?.setNotifyValue(false);
    } catch (_) {}
    _batteryLevelChar = null;

    final batteryService = _findServiceIn(
      services,
      _guid(BatteryUuids.service),
    );
    if (batteryService == null) return;

    final levelChar = _findCharacteristic(
      batteryService,
      _guid(BatteryUuids.level),
    );
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
    } catch (e) {
      debugPrint('[WatchService] Battery initial read failed (ignored): $e');
    }

    // Subscribe to notifications
    try {
      _batteryLevelChar = levelChar;
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
    } catch (e) {
      debugPrint('[WatchService] Battery notify setup failed (ignored): $e');
    }
  }

  // --- Internal: NUS send ---

  Future<void> _sendGb(Map<String, dynamic> data) async {
    final json = jsonEncode(data);
    await _sendNus('GB($json)');
  }

  Future<void> _sendNus(String data) async {
    if (!_ble.isDeviceConnected) return;
    final services = _ble.services;
    if (services == null) return;

    final nusService = _findServiceIn(services, _guid(NusUuids.service));
    if (nusService == null) return;

    final txChar = _findCharacteristic(
      nusService,
      _guid(NusUuids.txCharacteristic),
    );
    if (txChar == null) return;

    debugPrint('[BLE TX] $data');
    _rawOutgoingDataController.add(data);

    final bytes = utf8.encode(data);

    final currentMtu = _ble.currentConnection.mtu ?? BleConfig.minimumMtu;
    final maxChunkSize = currentMtu - 3;

    if (bytes.length <= maxChunkSize) {
      await txChar.write(
        bytes,
        withoutResponse: txChar.properties.writeWithoutResponse,
      );
      return;
    }

    if (bytes.length > 2000) {
      debugPrint(
        '[BLE TX] WARNING: Data exceeds watch max buffer (${bytes.length} > 2000)',
      );
    }

    int offset = 0;
    int chunkNum = 0;
    while (offset < bytes.length) {
      final end = (offset + maxChunkSize).clamp(0, bytes.length);
      final chunk = bytes.sublist(offset, end);

      chunkNum++;
      debugPrint(
        '[BLE TX] Chunk $chunkNum: ${chunk.length} bytes (offset $offset)',
      );

      await txChar.write(
        chunk,
        withoutResponse: txChar.properties.writeWithoutResponse,
      );

      if (end < bytes.length) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      offset = end;
    }

    debugPrint('[BLE TX] Sent ${bytes.length} bytes in $chunkNum chunks');
  }

  // --- Cleanup ---

  void _cleanupProtocol() {
    _nusSubscription?.cancel();
    _nusSubscription = null;
    _nusRxChar?.setNotifyValue(false).catchError((_) => false);
    _nusRxChar = null;
    _batterySubscription?.cancel();
    _batterySubscription = null;
    _batteryLevelChar?.setNotifyValue(false).catchError((_) => false);
    _batteryLevelChar = null;
    _messageBuffer = '';
    _inBleLog = false;
  }

  /// Dispose resources.
  Future<void> dispose() async {
    _cleanupProtocol();
    await _phaseSubscription?.cancel();
    // Don't dispose _ble here — it's owned by the provider that created it
    await _watchInfoController.close();
    await _batteryController.close();
    await _crashSummaryController.close();
    await _incomingMessageController.close();
    await _rawIncomingDataController.close();
    await _rawOutgoingDataController.close();
  }

  // --- Helpers ---

  BluetoothService? _findServiceIn(List<BluetoothService> services, Guid uuid) {
    return services.cast<BluetoothService?>().firstWhere(
      (s) => s?.uuid == uuid,
      orElse: () => null,
    );
  }

  BluetoothCharacteristic? _findCharacteristic(
    BluetoothService service,
    Guid uuid,
  ) {
    return service.characteristics.cast<BluetoothCharacteristic?>().firstWhere(
      (c) => c?.uuid == uuid,
      orElse: () => null,
    );
  }
}
