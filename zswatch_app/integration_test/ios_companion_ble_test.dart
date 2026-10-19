import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:zswatch_app/main.dart' as app;
import 'package:zswatch_app/data/models/companion_watch_selection.dart';
import 'package:zswatch_app/services/background/companion_prototype_client.dart';

/// Physical test: one nearby ZSWatch, no recording erase or firmware mutation.
/// This proves foreground native BLE and observer detachment, not OS restoration.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'physical iOS native watch connection and session fencing',
    (tester) async {
      expect(defaultTargetPlatform, TargetPlatform.iOS);
      app.main();
      await tester.pump(const Duration(seconds: 2));
      const client = CompanionPrototypeClient();
      final initial = await client.snapshot();
      expect(initial.isIos, true);
      Future<CompanionPrototypeSnapshot> until(
        bool Function(CompanionPrototypeSnapshot) accepts,
      ) async {
        final deadline = DateTime.now().add(const Duration(seconds: 40));
        while (DateTime.now().isBefore(deadline)) {
          final state = await client.snapshot();
          if (accepts(state)) return state;
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
        final last = await client.snapshot();
        debugPrint(
          'HIL_TIMEOUT phase=${last.phase} scans=${last.fields['scan_results']} events=${last.fields['events']} error=${last.fields['last_error']}',
        );
        throw StateError('Native watch condition timed out');
      }

      try {
        await client.command('stop');
        debugPrint('HIL_PERMISSIONS ${await client.permissionStatus()}');
        await client.requestIosConnectionPermissions();
        debugPrint('HIL_PERMISSION_READY');
        await client.scan(start: true);
        debugPrint('HIL_SCAN_STARTED');
        final scan = await until(
          (s) => (s.fields['scan_results'] as List).isNotEmpty,
        );
        final found = (scan.fields['scan_results'] as List)
            .whereType<Map<Object?, Object?>>()
            .toList();
        expect(
          found,
          hasLength(1),
          reason: 'Test requires one identifiable nearby ZSWatch',
        );
        final id = found.single['address'] as String;
        await client.startDiscovered(
          CompanionWatchSelection(id, scan.generation, platform: 'ios'),
        );
        final ready = await until(
          (s) =>
              s.protocolReady &&
              s.watch?.firmwareVersion != null &&
              s.hasLiveStatus,
        );
        debugPrint(
          'HIL_READY address=$id generation=${ready.generation} payload=${ready.fields['att_payload_bytes']} firmware=${ready.watch?.firmwareVersion} battery=${ready.watch?.batteryLevel}',
        );
        await client.command('syncTime');
        final subscription = client.watch().listen((_) {});
        await Future<void>.delayed(const Duration(seconds: 1));
        await subscription.cancel();
        expect((await client.snapshot()).protocolReady, true);
        await client.command('stop');
        final stopped = await client.snapshot();
        expect(stopped.runtimeActive, false);
        expect(stopped.protocolReady, false);
        expect(stopped.generation, greaterThan(ready.generation));
        await Future<void>.delayed(const Duration(seconds: 2));
        expect((await client.snapshot()).runtimeActive, false);
        await client.start(id);
        final reconnected = await until(
          (s) => s.protocolReady && s.hasLiveStatus,
        );
        expect(reconnected.generation, greaterThan(stopped.generation));
        debugPrint('HIL_RECONNECTED generation=${reconnected.generation}');
      } finally {
        await client.scan(start: false);
        await client.command('stop');
        final address = initial.fields['address'];
        if (initial.runtimeActive && address is String && address.isNotEmpty) {
          await client.start(address);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
