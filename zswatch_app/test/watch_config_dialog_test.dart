import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zswatch_app/data/database/app_database.dart';
import 'package:zswatch_app/ui/widgets/watch_config_dialog.dart';

void main() {
  const watchId = 'FE88C737-593F-DB9B-732D-E11FF4C463F5';

  Future<void> openDialog(
    WidgetTester tester, {
    String? customName,
    required Future<void> Function(String, String?) rename,
  }) async {
    final watch = WatchEntity(
      id: watchId,
      name: 'ZSWatch',
      customName: customName,
      isPrimary: true,
      supportsExtendedApi: true,
      createdAt: DateTime.utc(2026, 10, 12),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => WatchConfigDialog.show(
                context: context,
                watch: watch,
                onRename: rename,
                onForget: (_) async => fail('Rename must not forget the watch'),
                allowForget: false,
              ),
              child: const Text('Configure'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Configure'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'clearing a custom name restores default without changing identity',
    (tester) async {
      String? renamedId;
      String? renamedName = 'not called';
      await openDialog(
        tester,
        customName: 'My watch',
        rename: (id, name) async {
          renamedId = id;
          renamedName = name;
        },
      );
      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(renamedId, watchId);
      expect(renamedName, isNull);
      expect(find.text('Watch Settings'), findsNothing);
    },
  );

  testWidgets('clearing an already default name keeps Save disabled', (
    tester,
  ) async {
    await openDialog(tester, rename: (_, _) async => fail('No name change'));
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
          .onPressed,
      isNull,
    );
  });
}
