import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zswatch_app/data/models/crash_summary.dart';
import 'package:zswatch_app/providers/coredump_providers.dart';
import 'package:zswatch_app/providers/watch_service_provider.dart';
import 'package:zswatch_app/services/coredump/coredump_service.dart';
import 'package:zswatch_app/ui/screens/crash_report/crash_report_screen.dart';

class ExportPicker extends FilePicker {
  final bool mobile;
  bool cancel = false;
  Object? failure;
  Uint8List? receivedBytes;
  String? receivedName;

  ExportPicker({this.mobile = true});

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async {
    // Match file_picker's mobile requirement and macOS restriction.
    if (mobile && bytes == null) throw ArgumentError('Bytes are required');
    if (!mobile && bytes != null) throw UnsupportedError('Bytes on macOS');
    receivedBytes = bytes;
    receivedName = fileName;
    if (failure != null) throw failure!;
    return cancel ? null : 'content://documents/coredump.txt';
  }
}

void main() {
  const dump = '#CD:BEGIN#\nräven\n#CD:END#\n';
  late CoredumpService service;

  setUp(() {
    service = CoredumpService.native(() async => Uint8List(0))
      ..lastCoredumpTxt = dump;
  });
  tearDown(() {
    service.dispose();
  });

  Future<void> mount(WidgetTester tester, ExportPicker picker) async {
    FilePicker.platform = picker;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nativeCoredumpInspectionProvider.overrideWith((ref) async {}),
          crashReportPersistenceProvider.overrideWith((ref) {}),
          crashReportHistoryProvider.overrideWith((ref) => Stream.value([])),
          crashFileStatsProvider.overrideWith((ref) async => []),
          coredumpServiceProvider.overrideWithValue(service),
          crashSummaryProvider.overrideWithValue(
            const CrashSummary(
              file: 'crashed.c',
              line: 123,
              time: '2026-10-30 08:30:00',
              fwVersion: '0.8.1',
              fwCommitSha: 'abcd1234ffff',
              board: 'zswatch@1',
              buildType: 'release',
            ),
          ),
        ],
        child: const MaterialApp(home: CrashReportScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Export Raw Coredump'));
    await tester.pumpAndSettle();
  }

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform exports bytes through the document picker',
      (tester) async {
        final picker = ExportPicker();
        await mount(tester, picker);
        await tester.tap(find.text('Export Raw Coredump'));
        await tester.pumpAndSettle();
        expect(picker.receivedBytes, utf8.encode(dump));
        expect(picker.receivedName, 'coredump_abcd123.txt');
        // A document URI must not be reopened as a local dart:io File.
        expect(
          find.text('Coredump saved to content://documents/coredump.txt'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(platform),
    );
  }

  testWidgets('cancelling export preserves the downloaded coredump', (
    tester,
  ) async {
    final picker = ExportPicker()..cancel = true;
    await mount(tester, picker);
    await tester.tap(find.text('Export Raw Coredump'));
    await tester.pumpAndSettle();
    expect(service.lastCoredumpTxt, dump);
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('picker failures are visible and leave the coredump available', (
    tester,
  ) async {
    final picker = ExportPicker()
      ..failure = PlatformException(
        code: 'save_failed',
        message: 'Storage unavailable',
      );
    await mount(tester, picker);
    await tester.tap(find.text('Export Raw Coredump'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not export coredump:'), findsOneWidget);
    expect(service.lastCoredumpTxt, dump);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'macOS save dialog receives no unsupported bytes argument',
    (tester) async {
      final picker = ExportPicker(mobile: false)..cancel = true;
      await mount(tester, picker);
      await tester.tap(find.text('Export Raw Coredump'));
      await tester.pumpAndSettle();
      expect(picker.receivedName, 'coredump_abcd123.txt');
      expect(picker.receivedBytes, isNull);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );
}
