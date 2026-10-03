import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zswatch_app/services/background/companion_dart_worker.dart';

void main() {
  late Map<String, Object?> request;
  setUp(() {
    final spec =
        jsonDecode(
              File(
                '../scripts/companion_hil/remote_jobs/fixtures/job-v1.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    spec.addAll({
      'backend': 'local',
      'provider': 'dart-fixture',
      'upload_authorized': false,
      'recording_id': 'fixture-recording-local-001',
    });
    request = {'version': 1, 'job_id': 'native-owned', 'spec': spec};
  });

  test('Dart computation matches shared native and remote result contract', () {
    final golden = jsonDecode(
      File(
        '../scripts/companion_hil/remote_jobs/fixtures/result-v1.json',
      ).readAsStringSync(),
    );
    expect(companionLocalFixtureResult(request), golden);
  });

  test(
    'worker never accepts remote jobs, real recordings or model overrides',
    () {
      for (final change in [
        {'backend': 'remote'},
        {'provider': 'other'},
        {'upload_authorized': true},
        {'recording_id': 'real-recording'},
        {'model': 'real-model'},
        {'watch_id': 'AA:BB:CC:DD:EE:FF'},
        {'input_sha256': 'unknown'},
      ]) {
        final changed = Map<String, Object?>.from(request['spec']! as Map)
          ..addAll(change);
        expect(
          () => companionLocalFixtureResult({...request, 'spec': changed}),
          throwsFormatException,
        );
      }
    },
  );

  test('unsupported bridge envelopes cannot produce a result', () {
    for (final invalid in [
      {...request, 'version': 2},
      {...request, 'job_id': null},
      {...request, 'spec': null},
    ]) {
      expect(() => companionLocalFixtureResult(invalid), throwsFormatException);
    }
  });
}
