import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/connection.dart';
import '../data/models/connection_state.dart';

import 'companion_runtime_providers.dart';
import 'watch_service_provider.dart';

/// Connection state projected from the native companion.
final bleConnectionProvider = StreamProvider<Connection>((ref) {
  return companionValues(ref, (s) => s.connection);
});

/// Provider for current connection info (non-stream).
final currentConnectionProvider = Provider<Connection?>((ref) {
  return ref.watch(watchConnectionProvider);
});

/// Provider for connection state enum.
final connectionStateProvider = Provider<WatchConnectionState>((ref) {
  final connection = ref.watch(currentConnectionProvider);
  return connection?.state ?? WatchConnectionState.disconnected;
});

/// Provider for connection status (simplified boolean).
final isConnectedProvider = Provider<bool>((ref) {
  final state = ref.watch(connectionStateProvider);
  return state == WatchConnectionState.connected;
});

/// Provider for whether connecting or reconnecting.
final isConnectingProvider = Provider<bool>((ref) {
  final state = ref.watch(connectionStateProvider);
  return state.isConnectingOrReconnecting;
});

/// Provider for connection RSSI.
final connectionRssiProvider = Provider<int?>((ref) {
  final connection = ref.watch(currentConnectionProvider);
  return connection?.rssi;
});

/// Provider for connection MTU.
final connectionMtuProvider = Provider<int?>((ref) {
  final connection = ref.watch(currentConnectionProvider);
  return connection?.mtu;
});

/// Provider for connected watch ID.
final connectedWatchIdProvider = Provider<String?>((ref) {
  final connection = ref.watch(currentConnectionProvider);
  return connection?.isConnected == true ? connection?.watchId : null;
});
