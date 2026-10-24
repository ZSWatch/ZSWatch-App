import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zswatch_app/data/models/companion_recording.dart';
import 'package:zswatch_app/services/background/companion_prototype_client.dart';
import 'package:zswatch_app/services/voice_memo/voice_note_tidy.dart';

const watch = 'AA:BB:CC:DD:EE:FF';
String identity(String name) => '$watch:$name:1000:100:1000';
CompanionRecording recording(
  String name, {
  String state = 'downloaded',
  bool archived = false,
  int? deletedAt,
}) => CompanionRecording.decode(identity(name), {
  'address': watch,
  'filename': name,
  'timestamp': 1000,
  'size_bytes': 100,
  'duration_ms': 1000,
  'state': state,
  'sha256': 'a' * 64,
  'local_path': '/private/$name.zsw_opus',
  'archived': archived,
  'deleted_at': ?deletedAt,
});
Map<Object?, Object?> job(String state, {int actions = 0, int resolved = 0}) =>
    {
      'state': state,
      'action_types': List.filled(actions, 'task'),
      'actions_resolved': resolved,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.zswatch.app/companion_v1');

  test(
    'done means every action handled, or shown on watch without actions',
    () {
      final memo = recording('memo');
      expect(VoiceNoteTidy.isDone(memo, null), false);
      expect(VoiceNoteTidy.isDone(memo, job('transcribed')), false);
      expect(VoiceNoteTidy.isDone(memo, job('result_ready')), false);
      expect(VoiceNoteTidy.isDone(memo, job('delivered')), true);
      expect(
        VoiceNoteTidy.isDone(memo, job('delivered', actions: 2, resolved: 1)),
        false,
      );
      expect(
        VoiceNoteTidy.isDone(
          memo,
          job('result_ready', actions: 2, resolved: 2),
        ),
        true,
      );
      expect(
        VoiceNoteTidy.isDone(
          recording('old', archived: true),
          job('delivered'),
        ),
        false,
      );
    },
  );

  test('deleted recordings expire after 30 days', () {
    final now = DateTime.utc(2026, 10, 24);
    final day = const Duration(days: 1).inMilliseconds;
    final at = now.millisecondsSinceEpoch;
    expect(
      VoiceNoteTidy.isExpired(
        recording('a', state: 'deleted', deletedAt: at - 31 * day),
        now,
      ),
      true,
    );
    expect(
      VoiceNoteTidy.isExpired(
        recording('b', state: 'deleted', deletedAt: at - 29 * day),
        now,
      ),
      false,
    );
    expect(
      VoiceNoteTidy.isExpired(recording('c', state: 'deleted'), now),
      false,
    );
  });

  test('archives each finished note once and purges expired ones', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return {
            'version': 1,
            'owner': 'android_service_native',
            'address': watch,
            'runtime_active': false,
            'protocol_ready': false,
            'generation': 1,
            'event_cursor': 1,
            'phase': 'ready',
            'events': <Object?>[],
            'recordings': <String, Object?>{},
          };
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    final now = DateTime.utc(2026, 10, 24);
    final items = [
      recording('done'),
      recording('open'),
      recording(
        'gone',
        state: 'deleted',
        deletedAt: now
            .subtract(const Duration(days: 40))
            .millisecondsSinceEpoch,
      ),
    ];
    final jobs = {
      identity('done'): job('delivered'),
      identity('open'): job('delivered', actions: 1),
    };
    const client = CompanionPrototypeClient();
    await VoiceNoteTidy.apply(
      recordings: items,
      jobs: jobs,
      prefs: prefs,
      client: client,
      now: now,
    );
    expect(calls.map((c) => c.method), ['updateRecording', 'purgeRecordings']);
    expect((calls.first.arguments as Map)['identity'], identity('done'));
    expect((calls.last.arguments as Map)['identities'], [identity('gone')]);
    calls.clear();
    // The user unarchived it; it stays in the list.
    await VoiceNoteTidy.apply(
      recordings: [recording('done')],
      jobs: jobs,
      prefs: prefs,
      client: client,
      now: now,
    );
    expect(calls, isEmpty);
  });
}
