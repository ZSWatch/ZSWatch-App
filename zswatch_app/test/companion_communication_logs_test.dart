import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zswatch_app/data/models/comm_log_entry.dart';
import 'package:zswatch_app/providers/companion_runtime_providers.dart';
import 'package:zswatch_app/providers/developer_providers.dart';
import 'package:zswatch_app/services/background/companion_prototype_client.dart';

class TrafficClient extends CompanionPrototypeClient {
  final controller = StreamController<Map<String, Object?>>();
  int clears = 0;
  int subscriptions = 0;
  int sequence = 0;
  Future<int> Function()? onClear;

  @override
  Stream<Map<String, Object?>> communicationTraffic() {
    subscriptions++;
    return controller.stream;
  }

  @override
  Future<int> clearCommunicationTraffic() async {
    clears++;
    return onClear == null ? sequence : await onClear!();
  }

  void receive(String text, {int? nativeSequence}) {
    final captured = nativeSequence ?? sequence + 1;
    if (captured > sequence) sequence = captured;
    controller.add({
      'sequence': captured,
      'direction': 'rx',
      'data': text,
      'size_bytes': text.length,
      'chunk_count': 1,
      'utc_ms': 1700000000123,
      'generation': 10,
    });
  }
}

void main() {
  test(
    'communication capture survives closing and reopening the viewer',
    () async {
      final client = TrafficClient();
      final container = ProviderContainer(
        overrides: [companionClientProvider.overrideWithValue(client)],
      );
      addTearDown(() async {
        container.dispose();
        await client.controller.close();
      });
      final view = container.listen<List<CommLogEntry>>(
        commLogEntriesProvider,
        (_, _) {},
      );
      client.receive('before leaving');
      await Future<void>.delayed(Duration.zero);
      view.close();
      await container.pump();
      client.receive('while away');
      await Future<void>.delayed(Duration.zero);
      await container.pump();
      final reopened = container.listen<List<CommLogEntry>>(
        commLogEntriesProvider,
        (_, _) {},
      );
      expect(reopened.read().map((e) => e.data), [
        'before leaving',
        'while away',
      ]);
      expect(client.subscriptions, 1);
      expect(
        reopened.read().last.timestamp.millisecondsSinceEpoch,
        1700000000123,
      );
      await container.read(commLogRepositoryProvider.notifier).clear();
      expect(client.clears, 1);
      expect(reopened.read(), isEmpty);
      client.receive('after clearing');
      await Future<void>.delayed(Duration.zero);
      expect(reopened.read().single.data, 'after clearing');
      reopened.close();
    },
  );

  test(
    'Clear rejects queued pre-clear traffic arriving after the reply',
    () async {
      final client = TrafficClient();
      final notifier = CommLogNotifier.native(
        client.communicationTraffic(),
        clearNative: () async => 2,
      );
      addTearDown(() async {
        notifier.dispose();
        await client.controller.close();
      });
      client.receive('visible before clear');
      await Future<void>.delayed(Duration.zero);
      await notifier.clear();
      client.receive('queued before clear', nativeSequence: 2);
      await Future<void>.delayed(Duration.zero);
      expect(notifier.state, isEmpty);
      client.receive('genuinely new', nativeSequence: 3);
      await Future<void>.delayed(Duration.zero);
      expect(notifier.state.single.data, 'genuinely new');
    },
  );

  test(
    'Clear preserves post-clear traffic received before its reply',
    () async {
      final reply = Completer<int>();
      final client = TrafficClient();
      final notifier = CommLogNotifier.native(
        client.communicationTraffic(),
        clearNative: () => reply.future,
      );
      addTearDown(() async {
        notifier.dispose();
        await client.controller.close();
      });
      client.receive('before clear');
      await Future<void>.delayed(Duration.zero);
      final clearing = notifier.clear();
      client.receive('after native clear', nativeSequence: 3);
      await Future<void>.delayed(Duration.zero);
      reply.complete(2);
      await clearing;
      expect(notifier.state.map((e) => e.data), ['after native clear']);
      client.receive('duplicate batch', nativeSequence: 3);
      client.receive('next event', nativeSequence: 4);
      await Future<void>.delayed(Duration.zero);
      expect(notifier.state.map((e) => e.data), [
        'after native clear',
        'next event',
      ]);
      expect(client.subscriptions, 1);
    },
  );

  test('Rejected Clear retains history and keeps capture active', () async {
    final client = TrafficClient();
    final notifier = CommLogNotifier.native(
      client.communicationTraffic(),
      clearNative: () async => throw StateError('native failure'),
    );
    addTearDown(() async {
      notifier.dispose();
      await client.controller.close();
    });
    client.receive('before clear');
    await Future<void>.delayed(Duration.zero);
    await expectLater(notifier.clear(), throwsStateError);
    client.receive('after rejected clear');
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state.map((e) => e.data), [
      'before clear',
      'after rejected clear',
    ]);
  });
}
