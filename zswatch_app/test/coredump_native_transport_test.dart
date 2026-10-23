import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zswatch_app/services/coredump/coredump_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('native byte download strips the binary header', () async {
    var downloads = 0;
    const text = '#CD:BEGIN#\nowned-data\n#CD:END#';
    final service = CoredumpService.native(() async {
      downloads++;
      return Uint8List.fromList([0, 255, 0, ...text.codeUnits]);
    });
    expect(await service.download(), text);
    expect(downloads, 1);
    expect(service.lastCoredumpTxt, text);
    expect(service.currentState.phase, CoredumpDownloadPhase.completed);
    service.dispose();
  });
  test('native download failure exposes failure without legacy SMP', () async {
    final service = CoredumpService.native(
      () async => throw StateError('connection changed'),
    );
    expect(await service.download(), isNull);
    expect(service.currentState.phase, CoredumpDownloadPhase.failed);
    expect(service.lastCoredumpTxt, isNull);
    service.dispose();
  });
}
