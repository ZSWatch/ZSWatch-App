import 'package:flutter/services.dart';

import 'companion_prototype_client.dart';

/// Demo reads are synthetic. Every hardware command is rejected before it can
/// reach a platform channel, including streams that use separate channel names.
class DemoCompanionClient extends CompanionPrototypeClient {
  final bool ios;
  DemoCompanionClient({required this.ios})
    : super(
        methods: _DemoMethods(ios),
        events: const EventChannel('dev.zswatch.app/demo-only'),
      );

  static Map<String, Object?> state(bool ios) => {
    'version': 1,
    'owner': ios ? 'ios_companion_native' : 'android_service_native',
    'address': '',
    'runtime_active': false,
    'protocol_ready': false,
    'phase': 'stopped',
    'generation': 0,
    'event_cursor': 0,
    'events': <Object?>[],
    'recordings': <String, Object?>{},
    'voice_jobs': <Object?>[],
    'demo': true,
    'capabilities': {'smp': false, 'voice_processing': false},
  };
  @override
  Stream<CompanionPrototypeSnapshot> watch() =>
      Stream.value(CompanionPrototypeSnapshot.decode(state(ios)));
  @override
  Stream<Map<String, Object?>> sensors() => const Stream.empty();
  @override
  Stream<Map<String, Object?>> liveLogs() => const Stream.empty();
  @override
  Stream<Map<String, Object?>> communicationTraffic() => const Stream.empty();
  @override
  Future<int> clearCommunicationTraffic() async => 0;
}

class _DemoMethods extends MethodChannel {
  final bool ios;
  _DemoMethods(this.ios) : super('dev.zswatch.app/demo-only');
  @override
  Future<T?> invokeMethod<T>(String method, [dynamic arguments]) async {
    final Object value;
    switch (method) {
      case 'snapshot':
        value = DemoCompanionClient.state(ios);
      case 'permissionStatus':
        value = {
          'version': 1,
          for (final key in [
            'bluetooth',
            'notifications',
            'notification_access',
            'location',
            'background_location',
            'battery_exemption',
          ])
            key: false,
        };
      case 'notificationStatus':
        value = {
          'version': 1,
          'access_granted': false,
          'listener_connected': false,
          'apps': <Object?>[],
        };
      // No OpenRouter key in Demo Mode.
      case 'cloudCredential':
        value = {'version': 1};
      case 'sensorState':
        value = {
          'version': 1,
          'kind': 'state',
          'generation': 0,
          'available': <Object?>[],
          'subscriptions': <String, Object?>{},
        };
      default:
        throw PlatformException(
          code: 'DEMO_NO_HARDWARE',
          message: 'Hardware controls are unavailable in Demo Mode.',
        );
    }
    return value as T;
  }
}
