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

  @override
  Stream<Map<String, Object?>> communicationTraffic() {
    subscriptions++;
    return controller.stream;
  }

  @override
  Future<void> clearCommunicationTraffic() async => clears++;

  void receive(String text) => controller.add({
    'direction': 'rx',
    'data': text,
    'size_bytes': text.length,
    'chunk_count': 1,
    'utc_ms': 1700000000123,
    'generation': 10,
  });
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
}
