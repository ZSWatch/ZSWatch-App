import 'package:zswatch_app/providers/watch_providers.dart' as database;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zswatch_app/providers/companion_runtime_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zswatch_app/data/models/connection_state.dart';
import 'package:zswatch_app/data/models/connection_phase.dart';
import 'package:zswatch_app/services/background/companion_prototype_client.dart';
import 'package:zswatch_app/ui/screens/developer/companion_prototype_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const methods = MethodChannel('dev.zswatch.app/companion_v1');
  const eventControl = MethodChannel('dev.zswatch.app/companion_events_v1');
  const client = CompanionPrototypeClient();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  final subscriptions = <MethodCall>[];
  late Map<String, Object?> saved;

  setUp(() {
    calls.clear();
    subscriptions.clear();
    saved = {
      'version': 1,
      'owner': 'android_service_native',
      'runtime_active': true,
      'protocol_ready': true,
      'phase': 'ready',
      'event_cursor': 4,
      'generation': 2,
      'address': 'AA:BB:CC:DD:EE:FF',
      'acked_cursor': 0,
      'event_gap': false,
      'events': [
        {'seq': 4, 'kind': 'recording_state'},
      ],
      'recordings': {
        'memo': {'state': 'downloaded', 'sha256': 'saved-hash'},
      },
    };
    messenger.setMockMethodCallHandler(methods, (call) async {
      calls.add(call);
      if (call.method == 'start') return {'version': 1, 'accepted': true};
      return saved;
    });
    messenger.setMockMethodCallHandler(eventControl, (call) async {
      subscriptions.add(call);
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(methods, null);
    messenger.setMockMethodCallHandler(eventControl, null);
  });

  test(
    'snapshot reattachment reads persisted events and recording receipt',
    () async {
      final first = await client.snapshot();
      final second = await const CompanionPrototypeClient().snapshot();
      expect(second.cursor, first.cursor);
      expect(second.generation, 2);
      expect(second.recordings['memo'], {
        'state': 'downloaded',
        'sha256': 'saved-hash',
      });
      expect(calls.map((call) => call.method), ['snapshot', 'snapshot']);
      expect(
        calls.every((call) => (call.arguments as Map)['version'] == 1),
        isTrue,
      );
    },
  );

  test(
    'start normalizes MAC and sends a versioned acceptance request',
    () async {
      await client.start(' aa:bb:cc:dd:ee:ff ');
      expect(calls.single.method, 'start');
      expect(calls.single.arguments, {
        'version': 1,
        'address': 'AA:BB:CC:DD:EE:FF',
      });
    },
  );

  test(
    'iOS snapshots and commands use UUIDs, never Android associations',
    () async {
      const uuid = 'F31A05BD-1C30-4B66-AAC0-157004320111';
      saved = {
        ...saved,
        'owner': 'ios_companion_native',
        'platform': 'ios',
        'address': uuid,
      };
      expect((await client.snapshot()).isIos, true);
      await client.start(uuid.toLowerCase());
      expect((calls.last.arguments as Map)['address'], uuid);
      saved = {
        ...saved,
        'address': '',
        'runtime_active': false,
        'protocol_ready': false,
        'forgotten_watches': {uuid: 2},
        'forget_receipt': {
          'address': uuid,
          'generation': 2,
          'selection_removed': true,
          'association_removed': false,
          'system_unpair_required': true,
        },
      };
      expect((await client.forgetWatch(uuid)).runtimeActive, false);
      saved = {
        ...saved,
        'forget_receipt': {
          'address': uuid,
          'generation': 2,
          'association_removed': true,
        },
      };
      await expectLater(client.forgetWatch(uuid), throwsFormatException);
      expect(
        () => CompanionPrototypeSnapshot.decode({
          ...saved,
          'address': 'AA:BB:CC:DD:EE:FF',
        }),
        throwsFormatException,
      );
    },
  );

  test('invalid address never reaches the native owner', () async {
    await expectLater(client.start('watch UUID'), throwsFormatException);
    expect(calls, isEmpty);
  });

  test(
    'automatic processing opt-in sends explicit local model choices',
    () async {
      await client.configureVoiceProcessing(
        watchId: 'AA:BB:CC:DD:EE:FF',
        enabled: true,
        transcriptionModel: 'kbWhisperBase',
        analysisModel: 'qwen',
        correctTranscription: false,
      );
      expect(calls.single.method, 'configureVoiceProcessing');
      expect(calls.single.arguments, {
        'version': 1,
        'watch_id': 'AA:BB:CC:DD:EE:FF',
        'enabled': true,
        'transcription_model': 'kbWhisperBase',
        'analysis_model': 'qwen',
        'correct_transcription': false,
        'analysis_enabled': true,
      });
    },
  );

  test('forget normalizes MAC and sends a native-first command', () async {
    final forgotten = Map<String, Object?>.from(saved)
      ..['runtime_active'] = false
      ..['protocol_ready'] = false
      ..['phase'] = 'stopped'
      ..['address'] = ''
      ..['forgotten_watches'] = {'AA:BB:CC:DD:EE:FF': 2}
      ..['forget_receipt'] = {
        'address': 'AA:BB:CC:DD:EE:FF',
        'generation': 2,
        'association_removed': true,
      }
      ..['last_ready'] = null
      ..['watch_info'] = null;
    messenger.setMockMethodCallHandler(methods, (call) async {
      calls.add(call);
      return forgotten;
    });
    final result = await client.forgetWatch(' aa:bb:cc:dd:ee:ff ');
    expect(result.runtimeActive, isFalse);
    expect(calls.single.method, 'forgetWatch');
    expect(calls.single.arguments, {
      'version': 1,
      'address': 'AA:BB:CC:DD:EE:FF',
    });
  });

  test('invalid forget address never reaches the native owner', () async {
    await expectLater(
      client.forgetWatch('old-ios-uuid'),
      throwsFormatException,
    );
    expect(calls, isEmpty);
  });

  test(
    'a valid snapshot without a Forget receipt cannot authorize deletion',
    () async {
      await expectLater(
        client.forgetWatch('AA:BB:CC:DD:EE:FF'),
        throwsFormatException,
      );
    },
  );

  test(
    'notification configuration and recording pause are native commands',
    () async {
      await client.setRecordingSync(false);
      await client.configureNotifications(true, ['com.zswatch.app']);
      expect(calls.map((c) => c.method), [
        'setRecordingSync',
        'configureNotifications',
      ]);
      expect(calls.first.arguments, {'version': 1, 'enabled': false});
      expect(calls.last.arguments, {
        'version': 1,
        'enabled': true,
        'packages': ['com.zswatch.app'],
      });
    },
  );

  test(
    'invalid notification package policy never reaches the service',
    () async {
      await expectLater(
        client.configureNotifications(true, ['*']),
        throwsFormatException,
      );
      await expectLater(
        client.configureNotifications(true, List.filled(65, 'com.zswatch.app')),
        throwsFormatException,
      );
      expect(calls, isEmpty);
    },
  );

  test(
    'diagnostic notification permission and posting require acceptance',
    () async {
      messenger.setMockMethodCallHandler(methods, (call) async {
        calls.add(call);
        return {'version': 1, 'accepted': true};
      });
      await client.notificationDiagnostic(requestAccess: true);
      await client.notificationDiagnostic();
      await client.notificationDiagnostic(delaySeconds: 15, closeUi: true);
      expect(calls.map((c) => c.method), [
        'requestNotificationAccess',
        'postTestNotification',
        'postTestNotification',
      ]);
      expect(calls.last.arguments, {
        'version': 1,
        'delaySeconds': 15,
        'closeUi': true,
      });
      final count = calls.length;
      await expectLater(
        client.notificationDiagnostic(delaySeconds: 61),
        throwsFormatException,
      );
      await expectLater(
        client.notificationDiagnostic(closeUi: true),
        throwsFormatException,
      );
      await expectLater(
        client.notificationDiagnostic(requestAccess: true, delaySeconds: 15),
        throwsFormatException,
      );
      expect(calls.length, count);
      messenger.setMockMethodCallHandler(
        methods,
        (_) async => {'version': 1, 'accepted': false},
      );
      await expectLater(client.notificationDiagnostic(), throwsFormatException);
    },
  );

  test(
    'presence setup is explicit and distinguishes association from support',
    () async {
      messenger.setMockMethodCallHandler(methods, (call) async {
        calls.add(call);
        return {
          'version': 1,
          'supported': true,
          'associated': call.method == 'associatePresence',
          'address': 'AA:BB:CC:DD:EE:FF',
        };
      });
      expect(
        (await client.presence(' aa:bb:cc:dd:ee:ff '))['associated'],
        false,
      );
      expect(
        (await client.presence(
          'AA:BB:CC:DD:EE:FF',
          associate: true,
        ))['associated'],
        true,
      );
      expect(calls.map((call) => call.method), [
        'presenceStatus',
        'associatePresence',
      ]);
      expect(calls.last.arguments, {
        'version': 1,
        'address': 'AA:BB:CC:DD:EE:FF',
      });
    },
  );

  test('presence status for a different watch cannot be accepted', () async {
    messenger.setMockMethodCallHandler(
      methods,
      (_) async => {
        'version': 1,
        'supported': true,
        'associated': true,
        'address': '11:22:33:44:55:66',
      },
    );
    await expectLater(
      client.presence('AA:BB:CC:DD:EE:FF'),
      throwsFormatException,
    );
    await expectLater(
      client.presence('watch UUID', associate: true),
      throwsFormatException,
    );
  });

  test(
    'association cancellation propagates without starting the runtime',
    () async {
      messenger.setMockMethodCallHandler(methods, (call) async {
        calls.add(call);
        throw PlatformException(
          code: 'ASSOCIATION_FAILED',
          message: 'Cancelled',
        );
      });
      await expectLater(
        client.presence('AA:BB:CC:DD:EE:FF', associate: true),
        throwsA(isA<PlatformException>()),
      );
      expect(calls.single.method, 'associatePresence');
    },
  );

  test('unaccepted start and native permission errors propagate', () async {
    messenger.setMockMethodCallHandler(
      methods,
      (_) async => {'version': 1, 'accepted': false},
    );
    await expectLater(client.start('AA:BB:CC:DD:EE:FF'), throwsFormatException);
    messenger.setMockMethodCallHandler(
      methods,
      (_) async => throw PlatformException(
        code: 'START_FAILED',
        message: 'permission required',
      ),
    );
    await expectLater(
      client.start('AA:BB:CC:DD:EE:FF'),
      throwsA(isA<PlatformException>()),
    );
  });

  test(
    'version and incomplete snapshot cannot be mistaken for readiness',
    () async {
      for (final invalid in [
        saved..['version'] = 2,
        <String, Object?>{'version': 1},
        null,
      ]) {
        messenger.setMockMethodCallHandler(methods, (_) async => invalid);
        await expectLater(client.snapshot(), throwsFormatException);
      }
    },
  );

  test('acknowledgment and commands use v1 envelope', () async {
    await client.command('ackEvents', cursor: 4);
    await client.command('syncTime');
    await client.command('retryRecordings');
    await client.command('stop');
    expect(calls.first.arguments, {'version': 1, 'cursor': 4});
    expect(calls.map((call) => call.method), [
      'ackEvents',
      'syncTime',
      'retryRecordings',
      'stop',
    ]);
  });

  test(
    'native snapshot supplies existing watch and connection UI models',
    () async {
      saved['watch_info'] = {
        'address': 'AA:BB:CC:DD:EE:FF',
        'firmware_version': '1.2.3',
        'hardware_version': 'WatchDK',
        'battery_level': 0,
        'is_charging': true,
        'first_seen_ms': 1000,
        'status_generation': 2,
      };
      saved['att_payload_bytes'] = 244;
      final snapshot = await client.snapshot();
      expect(snapshot.watch!.firmwareVersion, '1.2.3');
      expect(snapshot.watch!.batteryLevel, 0);
      expect(snapshot.connection.state, WatchConnectionState.connected);
      expect(snapshot.connection.mtu, 247);
      expect(snapshot.connection.isCharging, true);
      expect(snapshot.hasLiveStatus, true);
      await client.command('requestDeviceInfo');
      await client.command('startLocalFixture');
      expect(calls.last.arguments, {'version': 1});
    },
  );

  test(
    'native pairing uses the existing setup UI and is never Ready',
    () async {
      saved['phase'] = 'bonding';
      saved['protocol_ready'] = false;
      final snapshot = await client.snapshot();
      expect(
        snapshot.connectionPhase,
        const ConnectionPhase.settingUp(step: SetupStep.bonding),
      );
      expect(snapshot.connection.isConnected, false);
      expect(snapshot.protocolReady, false);
    },
  );

  test(
    'reconnection marks cached status stale and absent service is disconnected',
    () async {
      saved['watch_info'] = {
        'address': 'AA:BB:CC:DD:EE:FF',
        'battery_level': 80,
        'status_generation': 1,
      };
      expect((await client.snapshot()).hasLiveStatus, false);
      saved['runtime_active'] = false;
      saved['protocol_ready'] = false;
      final stopped = await client.snapshot();
      expect(stopped.phase, 'ready');
      expect(stopped.connection.state, WatchConnectionState.disconnected);
      expect(stopped.watch!.batteryLevel, 80);
      saved['address'] = '11:22:33:44:55:66';
      expect((await client.snapshot()).watch!.batteryLevel, null);
    },
  );

  test('invalid cursor and unknown commands do not reach the owner', () async {
    await expectLater(client.command('ackEvents'), throwsFormatException);
    await expectLater(
      client.command('ackEvents', cursor: -1),
      throwsFormatException,
    );
    await expectLater(client.command('deleteRecording'), throwsFormatException);
    expect(calls, isEmpty);
  });

  test(
    'synthetic remote fixture command contains no audio or backend override',
    () async {
      messenger.setMockMethodCallHandler(methods, (call) async {
        calls.add(call);
        return saved;
      });
      await client.command('startRemoteFixture');
      expect(calls.single.method, 'startRemoteFixture');
      expect(calls.single.arguments, {'version': 1});
    },
  );

  test('event observer delivers snapshots and cancel sends no stop', () async {
    final delivered = <CompanionPrototypeSnapshot>[];
    final subscription = client.watch().listen(delivered.add);
    await Future<void>.delayed(Duration.zero);
    expect(subscriptions.single.method, 'listen');
    expect(subscriptions.single.arguments, {'version': 1});
    await messenger.handlePlatformMessage(
      eventControl.name,
      const StandardMethodCodec().encodeSuccessEnvelope(saved),
      (_) {},
    );
    await Future<void>.delayed(Duration.zero);
    expect(delivered.single.cursor, 4);
    await subscription.cancel();
    expect(subscriptions.last.method, 'cancel');
    expect(calls, isEmpty);
  });

  testWidgets(
    'prototype UI detach and remount leave native receipts and owner alone',
    (tester) async {
      saved['watch_info'] = {
        'address': saved['address'],
        'first_seen_ms': 1000,
        'firmware_version': '0.8.1',
        'hardware_version': 'watchdk',
        'battery_level': 87,
        'status_generation': saved['generation'],
      };
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nativeCompanionRuntimeProvider.overrideWithValue(true),
            database.allWatchesProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: const CompanionPrototypeApp(),
        ),
      );
      await tester.pumpAndSettle();
      await messenger.handlePlatformMessage(
        eventControl.name,
        const StandardMethodCodec().encodeSuccessEnvelope(saved),
        (_) {},
      );
      await tester.pumpAndSettle();
      expect(find.text('Companion prototype'), findsOneWidget);
      expect(find.text('Firmware: 0.8.1'), findsOneWidget);
      expect(find.text('Battery: 87%'), findsOneWidget);
      await messenger.handlePlatformMessage(
        eventControl.name,
        const StandardMethodCodec().encodeErrorEnvelope(
          code: 'SNAPSHOT_FAILED',
        ),
        (_) {},
      );
      await tester.pumpAndSettle();
      expect(find.text('Protocol ready: false • generation 0'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nativeCompanionRuntimeProvider.overrideWithValue(true),
            database.allWatchesProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: const CompanionPrototypeApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      expect(saved['runtime_active'], true);
      expect(
        ((saved['recordings']! as Map)['memo'] as Map)['state'],
        'downloaded',
      );
      expect(subscriptions.map((call) => call.method), [
        'listen',
        'cancel',
        'listen',
      ]);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
