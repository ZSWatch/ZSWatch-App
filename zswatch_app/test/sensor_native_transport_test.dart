import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zswatch_app/services/background/companion_prototype_client.dart';
import 'package:zswatch_app/services/ble/sensor_gatt_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const methods = MethodChannel('dev.zswatch.app/companion_v1');
  const events = MethodChannel('dev.zswatch.app/companion_sensors_v1');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  final subscriptions = <String>[];
  var failure = false;
  const names = [
    'temperature',
    'accelerometer',
    'light',
    'gyroscope',
    'magnetometer',
    'humidity',
    'pressure',
    'fusion',
  ];
  Map<String, Object?> state(int generation, List<String> available) => {
    'version': 1,
    'kind': 'state',
    'generation': generation,
    'available': available,
    'enabled': <String>[],
  };
  Future<void> emit(Map<String, Object?> event) async {
    await messenger.handlePlatformMessage(
      events.name,
      const StandardMethodCodec().encodeSuccessEnvelope(event),
      (_) {},
    );
    await Future<void>.delayed(Duration.zero);
  }

  Uint8List floats(List<double> values) {
    final bytes = ByteData(values.length * 4);
    for (var i = 0; i < values.length; i++) {
      bytes.setFloat32(i * 4, values[i], Endian.little);
    }
    return bytes.buffer.asUint8List();
  }

  setUp(() {
    calls.clear();
    subscriptions.clear();
    failure = false;
    messenger.setMockMethodCallHandler(events, (call) async {
      subscriptions.add(call.method);
      return null;
    });
    messenger.setMockMethodCallHandler(methods, (call) async {
      calls.add(call);
      if (call.method == 'sensorState') return state(10, names);
      if (call.method == 'setSensor') {
        if (failure) throw PlatformException(code: 'SENSOR_FAILED');
        return {'version': 1, 'completed': true};
      }
      throw StateError('Unexpected ${call.method}');
    });
  });
  test(
    'native samples reuse existing eight decoders and fence disconnection',
    () async {
      final service = SensorGattService.native(
        const CompanionPrototypeClient(),
      );
      expect(await service.initializeNative(), isTrue);
      expect(
        service.hasTemperature &&
            service.hasSensorFusion &&
            service.hasMagnetometer,
        isTrue,
      );
      await service.startAll();
      expect(calls.where((call) => call.method == 'setSensor'), hasLength(8));
      for (final call in calls.where((call) => call.method == 'setSensor')) {
        final args = call.arguments as Map;
        expect(args['generation'], 10);
        expect(args['enabled'], true);
      }
      final streams = [
        service.temperatureStream,
        service.accelerometerStream,
        service.lightStream,
        service.gyroscopeStream,
        service.magnetometerStream,
        service.humidityStream,
        service.pressureStream,
      ];
      for (var i = 0; i < streams.length; i++) {
        final result = streams[i].first;
        final vector = [1, 3, 4].contains(i);
        await emit({
          'version': 1,
          'kind': 'sample',
          'generation': 10,
          'sensor': names[i],
          'bytes': floats(vector ? [1.25, 2.5, -3.75] : [1.25]),
        });
        final reading = await result;
        expect(reading.x, 1.25);
        if (vector) {
          expect(reading.y, 2.5);
          expect(reading.z, -3.75);
        }
      }
      final quaternion = service.sensorFusionStream.first;
      await emit({
        'version': 1,
        'kind': 'sample',
        'generation': 10,
        'sensor': 'fusion',
        'bytes': floats([1, 0, 0, 0]),
      });
      expect((await quaternion).w, 1);
      final observed = <double>[];
      final watch = service.temperatureStream.listen(
        (reading) => observed.add(reading.x),
      );
      await emit(state(10, []));
      expect(service.isConnected, isFalse);
      await emit({
        'version': 1,
        'kind': 'sample',
        'generation': 10,
        'sensor': 'temperature',
        'bytes': floats([90]),
      });
      await emit(state(11, ['temperature']));
      await emit({
        'version': 1,
        'kind': 'sample',
        'generation': 10,
        'sensor': 'temperature',
        'bytes': floats([91]),
      });
      await emit({
        'version': 1,
        'kind': 'sample',
        'generation': 11,
        'sensor': 'temperature',
        'bytes': floats([22]),
      });
      expect(observed, [22]);
      await watch.cancel();
      await service.dispose();
      expect(subscriptions, ['listen', 'cancel']);
      expect(
        calls.every(
          (call) => ['sensorState', 'setSensor'].contains(call.method),
        ),
        isTrue,
      );
    },
  );
  test(
    'native subscription errors propagate and disposal cancels only once',
    () async {
      final service = SensorGattService.native(
        const CompanionPrototypeClient(),
      );
      await service.initializeNative();
      failure = true;
      await expectLater(
        service.startTemperature(),
        throwsA(isA<PlatformException>()),
      );
      await service.dispose();
      await service.dispose();
      expect(subscriptions, ['listen', 'cancel']);
    },
  );
}
