import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zswatch_app/data/models/coredump_analysis.dart';
import 'package:zswatch_app/data/models/crash_summary.dart';
import 'package:zswatch_app/services/coredump/coredump_api_service.dart';
import 'package:zswatch_app/services/coredump/coredump_service.dart';
import 'package:zswatch_app/services/dfu/firmware_manager.dart';

class _Firmware extends FirmwareManager {
  @override
  Future<String?> getCachedElfHash(String commitSha) async => 'owned-elf';
}

class _Api extends CoredumpApiService {
  String? text;
  String? hash;
  @override
  Future<CoredumpAnalysis> analyze({
    required String coredumpTxt,
    required CrashSummary summary,
    String? elfHash,
    bool useLatestElf = false,
  }) async {
    text = coredumpTxt;
    hash = elfHash;
    return const CoredumpAnalysis(
      success: true,
      rawOutput: 'controlled response',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const summary = CrashSummary(
    file: 'owned.c',
    line: 123,
    time: 'owned time',
    fwVersion: '0.8.1',
    fwCommitSha: 'owned-sha',
    board: 'watchdk',
    buildType: 'debug',
  );
  test(
    'native byte download reuses shared header stripping ELF lookup and analysis',
    () async {
      final api = _Api();
      final firmware = _Firmware();
      var downloads = 0;
      const text = '#CD:BEGIN#\nowned-data\n#CD:END#';
      final service = CoredumpService.native(
        () async {
          downloads++;
          return Uint8List.fromList([0, 255, 0, ...text.codeUnits]);
        },
        api,
        firmware,
      );
      final result = await service.analyze(summary);
      expect(downloads, 1);
      expect(result?.success, isTrue);
      expect(api.text, text);
      expect(api.hash, 'owned-elf');
      expect(service.lastCoredumpTxt, text);
      expect(service.currentState.phase, CoredumpAnalysisPhase.completed);
      service.dispose();
      await firmware.dispose();
    },
  );
  test(
    'native download failure exposes failure without uploading or legacy SMP',
    () async {
      final api = _Api();
      final firmware = _Firmware();
      final service = CoredumpService.native(
        () async => throw StateError('connection changed'),
        api,
        firmware,
      );
      expect(await service.analyze(summary), isNull);
      expect(service.currentState.phase, CoredumpAnalysisPhase.failed);
      expect(api.text, isNull);
      service.dispose();
      await firmware.dispose();
    },
  );
}
