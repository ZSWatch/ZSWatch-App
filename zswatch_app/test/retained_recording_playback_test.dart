import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zswatch_app/data/models/voice_memo.dart';
import 'package:zswatch_app/services/voice_memo/retained_recording_playback.dart';
import 'support/companion_recording_fixture.dart';

void main() {
  test(
    'earlier playback verifies supported source without adopting its filename or changing it',
    () async {
      final root = Directory(
        await (await Directory.systemTemp.createTemp(
          'retained-audio-',
        )).resolveSymbolicLinks(),
      );
      addTearDown(() => root.delete(recursive: true));
      final recording = await seedCompanionRecording(root);
      final original = await File(recording.localPath!).readAsBytes();
      final memo = VoiceMemo(
        id: 7,
        filename: 'old_name_without_watch_identity',
        timestampUtc: recording.timestampUtc,
        durationMs: recording.durationMs,
        sizeBytes: recording.sizeBytes,
        localFilePath: recording.localPath,
      );
      final playback = await prepareRetainedRecording(memo, root, root);
      expect(playback.path, isNot(recording.localPath));
      expect(
        sha256.convert(await File(playback.path).readAsBytes()).toString(),
        playback.hash,
      );
      expect(await File(recording.localPath!).readAsBytes(), original);
      await expectLater(
        prepareRetainedRecording(
          memo.copyWith(localFilePath: '/private/other.zsw_opus'),
          root,
          root,
        ),
        throwsStateError,
      );
    },
  );
}
