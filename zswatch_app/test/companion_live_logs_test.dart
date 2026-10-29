import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zswatch_app/data/models/log_entry.dart';
import 'package:zswatch_app/data/models/log_filter.dart';
import 'package:zswatch_app/providers/developer_providers.dart';

void main() {
  test(
    'capture and enabled state survive leaving and reopening the viewer',
    () async {
      var cancellations = 0;
      final events = StreamController<Map<String, Object?>>(
        onCancel: () => cancellations++,
      );
      final container = ProviderContainer(
        overrides: [
          companionLiveLogEventsProvider.overrideWith((ref) => events.stream),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await events.close();
      });
      final stateView = container.listen<LogStreamingState>(
        logStreamingStateProvider,
        (_, _) {},
      );
      final entriesView = container.listen<List<LogEntry>>(
        logEntriesProvider,
        (_, _) {},
      );
      events.add({
        'kind': 'state',
        'requested': true,
        'written': true,
        'pending': false,
      });
      events.add({'kind': 'log', 'message': 'before leaving', 'utc_ms': 1234});
      await Future<void>.delayed(Duration.zero);
      await container.pump();
      stateView.close();
      entriesView.close();
      await Future<void>.delayed(Duration.zero);
      await container.pump();
      events.add({'kind': 'log', 'message': 'while away', 'utc_ms': 2345});
      await Future<void>.delayed(Duration.zero);
      await container.pump();
      expect(cancellations, 0);
      expect(container.read(logStreamingStateProvider).enabledOnWatch, true);
      expect(container.read(logEntriesProvider).map((entry) => entry.message), [
        'before leaving',
        'while away',
      ]);
      expect(
        container.read(logEntriesProvider).last.timestamp,
        DateTime.fromMillisecondsSinceEpoch(2345),
      );

      // Disconnect resets the write receipt, not the user's request or history.
      events.add({
        'kind': 'state',
        'requested': true,
        'written': false,
        'pending': false,
      });
      await Future<void>.delayed(Duration.zero);
      await container.pump();
      expect(container.read(logStreamingStateProvider).requestedByApp, true);
      expect(container.read(logStreamingStateProvider).enabledOnWatch, false);
      events.add({
        'kind': 'state',
        'requested': true,
        'written': true,
        'pending': false,
      });
      events.add({'kind': 'log', 'message': 'reconnected'});
      await Future<void>.delayed(Duration.zero);
      await container.pump();
      expect(container.read(logStreamingStateProvider).enabledOnWatch, true);
      expect(container.read(logEntriesProvider).length, 3);
      container.read(logEntriesProvider.notifier).clear();
      expect(container.read(logEntriesProvider), isEmpty);
      expect(container.read(logStreamingStateProvider).requestedByApp, true);
    },
  );
}
