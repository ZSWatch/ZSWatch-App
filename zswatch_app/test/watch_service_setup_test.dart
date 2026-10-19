import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zswatch_app/core/constants/ble_constants.dart';
import 'package:zswatch_app/services/ble/ble_connection_service.dart';
import 'package:zswatch_app/services/watch_service.dart';

class _Service implements BluetoothService {
  @override
  final Guid uuid = Guid(NusUuids.service);
  @override
  final List<BluetoothCharacteristic> characteristics;

  _Service(this.characteristics);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Characteristic implements BluetoothCharacteristic {
  @override
  final Guid uuid;
  Object? subscriptionError;
  bool acceptsSubscription = true;
  final notifications = <bool>[];

  _Characteristic(String uuid) : uuid = Guid(uuid);

  @override
  Future<bool> setNotifyValue(
    bool notify, {
    int timeout = 15,
    bool forceIndications = false,
  }) async {
    notifications.add(notify);
    if (notify && subscriptionError != null) throw subscriptionError!;
    return !notify || acceptsSubscription;
  }

  @override
  Stream<List<int>> get onValueReceived => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BleConnectionService ble;
  late WatchService watch;
  late _Characteristic rx;
  late _Characteristic tx;

  setUp(() {
    ble = BleConnectionService();
    watch = WatchService(ble);
    rx = _Characteristic(NusUuids.rxCharacteristic);
    tx = _Characteristic(NusUuids.txCharacteristic);
  });

  tearDown(() async {
    await watch.dispose();
    await ble.dispose();
  });

  Future<void> setup(List<BluetoothService> services) => ble.onSetupRequired!(
    BluetoothDevice.fromId('AA:BB:CC:DD:EE:FF'),
    services,
    'AA:BB:CC:DD:EE:FF',
    'ZSWatch',
  );

  test('empty discovery fails the protocol setup callback', () async {
    await expectLater(setup([]), throwsStateError);
  });

  test('missing NUS notifications fail protocol setup', () async {
    await expectLater(
      setup([
        _Service([tx]),
      ]),
      throwsStateError,
    );
  });

  test('missing NUS writes fail before subscribing', () async {
    await expectLater(
      setup([
        _Service([rx]),
      ]),
      throwsStateError,
    );
    expect(rx.notifications, isEmpty);
  });

  test('CCCD failure reaches the connection owner', () async {
    final error = StateError('CCCD write failed');
    rx.subscriptionError = error;
    await expectLater(
      setup([
        _Service([rx, tx]),
      ]),
      throwsA(same(error)),
    );
  });

  test('rejected notification subscription fails setup', () async {
    rx.acceptsSubscription = false;
    await expectLater(
      setup([
        _Service([rx, tx]),
      ]),
      throwsStateError,
    );
  });

  test(
    'valid NUS permits setup without the optional battery service',
    () async {
      await setup([
        _Service([rx, tx]),
      ]);
      expect(rx.notifications, [true]);
    },
  );
}
