import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zswatch_app/providers/settings_providers.dart';
import 'package:zswatch_app/services/ai/extracted_action_creation_service.dart';
import 'package:zswatch_app/ui/widgets/voice_memos/companion_voice_action_card.dart';

class FakeActions extends ExtractedActionCreationService {
  final created = <ActionCreationDraft>[];
  final identities = <(String, int)>[];
  final pending = Completer<void>();
  int undos = 0;
  @override
  Future<List<PlatformCalendar>> prepareCompanionAction(
    ActionCreationDraft draft,
  ) async => [];
  @override
  Future<void> createCompanionDraft(
    String jobId,
    int index,
    ActionCreationDraft draft,
  ) {
    created.add(draft);
    identities.add((jobId, index));
    return pending.future;
  }

  @override
  Future<void> undoCompanionAction(String jobId, int index) async {
    undos++;
    identities.add((jobId, index));
  }
}

void main() {
  test(
    'voice draft preserves absolute instants and validates Clock date limitations',
    () {
      final event = ActionCreationDraft.fromVoiceResult({
        'type': 'calendar_event',
        'title': 'Meeting',
        'start_time': '2026-10-05T10:00:00+02:00',
      });
      expect(event.scheduledAt!.toUtc(), DateTime.utc(2026, 10, 5, 8));
      expect(
        event.endAt!.difference(event.scheduledAt!),
        const Duration(minutes: 30),
      );
      final alarm = ActionCreationDraft.fromVoiceResult({
        'type': 'alarm',
        'title': 'Wake',
        'due_date': '2026-10-06T09:00:00',
      });
      expect(
        () => alarm.validateForCreation(now: DateTime(2026, 10, 5, 10)),
        returnsNormally,
      );
      expect(
        () => alarm.validateForCreation(now: DateTime(2026, 10, 5, 8)),
        throwsStateError,
      );
      expect(
        () => ActionCreationDraft.fromVoiceResult({
          'type': 'unknown',
          'title': 'Bad',
        }),
        throwsFormatException,
      );
      expect(
        () => ActionCreationDraft.fromVoiceResult({
          'type': 'timer',
          'title': 'Tea',
          'duration_seconds': 0,
        }).validateForCreation(),
        throwsStateError,
      );
    },
  );

  Future<void> mount(
    WidgetTester tester,
    FakeActions service, {
    Map<Object?, Object?>? state,
    Map<Object?, Object?> action = const {
      'type': 'timer',
      'title': 'Tea',
      'duration_seconds': 60,
    },
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          companionActionCreationProvider.overrideWithValue(service),
          selectedProductivityCalendarIdProvider.overrideWith(
            (ref) => SelectedProductivityCalendarIdNotifier(null),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: CompanionVoiceActionCard(
              jobId: 'owned-job',
              index: 2,
              action: action,
              state: state,
              onChanged: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'opening and cancelling review have no effects; double tap dispatches once',
    (tester) async {
      final service = FakeActions();
      await mount(tester, service);
      expect(service.created, isEmpty);
      await tester.tap(find.text('Review & create'));
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(service.created, isEmpty);
      await tester.tap(find.text('Review & create'));
      await tester.pump(const Duration(seconds: 1));
      await tester.enterText(find.byType(TextField).first, 'Owned tea');
      await tester.tap(find.text('Send to Clock'));
      await tester.pump(const Duration(seconds: 1));
      // Reservation stays busy while native durability/effect completion is pending.
      await tester.tap(find.text('Review & create'));
      await tester.pump();
      expect(service.created, hasLength(1));
      expect(service.created.single.title, 'Owned tea');
      expect(service.created.single.skipUi, isFalse);
      expect(service.identities.single, ('owned-job', 2));
      service.pending.complete();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('interrupted Clock request exposes no retry or pretend undo', (
    tester,
  ) async {
    final service = FakeActions();
    await mount(tester, service, state: {'state': 'creating'});
    expect(find.textContaining('Check Clock'), findsOneWidget);
    expect(find.text('Review & create'), findsNothing);
    expect(find.text('Recover creation'), findsNothing);
    expect(find.text('Undo creation'), findsNothing);
    expect(service.created, isEmpty);
  });

  testWidgets(
    'calendar undo requires confirmation and uses the original action identity',
    (tester) async {
      final service = FakeActions();
      await mount(
        tester,
        service,
        action: {
          'type': 'reminder',
          'title': 'Owned reminder',
          'due_date': '2026-10-06T09:00:00',
        },
        state: {
          'state': 'created',
          'response': {'platformId': '42'},
        },
      );
      await tester.tap(find.text('Undo creation'));
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(service.undos, 0);
      await tester.tap(find.text('Undo creation'));
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(service.undos, 1);
      expect(service.identities.single, ('owned-job', 2));
    },
  );

  testWidgets(
    'removed action retains the confirmed title and drops the creation sync warning',
    (tester) async {
      final service = FakeActions();
      await mount(
        tester,
        service,
        action: {'type': 'reminder', 'title': 'Original suggestion'},
        state: {
          'state': 'undone',
          'draft': {'title': 'Edited confirmation'},
          'response': {'syncDisabled': true},
        },
      );
      expect(find.text('Edited confirmation'), findsOneWidget);
      expect(find.text('Original suggestion'), findsNothing);
      expect(find.text('Calendar entry removed'), findsOneWidget);
      expect(find.textContaining('sync is disabled'), findsNothing);
    },
  );
}
