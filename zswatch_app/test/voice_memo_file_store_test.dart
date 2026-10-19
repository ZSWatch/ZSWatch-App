import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zswatch_app/services/voice_memo/voice_memo_file_store.dart';

void main() {
  late Directory directory;
  late File destination;
  final previous = Uint8List.fromList([1, 2, 3]);
  final incoming = Uint8List.fromList([4, 5, 6, 7]);

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('voice-file-store-test-');
    destination = File('${directory.path}/memo.zsw_opus');
    await destination.writeAsBytes(previous, flush: true);
  });
  tearDown(() => directory.delete(recursive: true));

  test(
    'staging cannot truncate or publish over the previous recording',
    () async {
      final staged = await VoiceMemoFileStore.prepare(destination, incoming);
      expect(await destination.readAsBytes(), previous);
      expect(await staged.stagedFile.readAsBytes(), incoming);
      await staged.discard();
      expect(await destination.readAsBytes(), previous);
    },
  );

  test('publishes complete bytes and removes staging after success', () async {
    expect(
      await VoiceMemoFileStore.write(destination, incoming),
      destination.path,
    );
    expect(await destination.readAsBytes(), incoming);
    expect(await directory.list().length, 1);
  });

  test(
    'failed publication preserves the existing destination and cleans its stage',
    () async {
      final target = Directory('${directory.path}/occupied');
      await target.create();
      final sentinel = File('${target.path}/original');
      await sentinel.writeAsBytes(previous);
      await expectLater(
        VoiceMemoFileStore.write(File(target.path), incoming),
        throwsA(isA<FileSystemException>()),
      );
      expect(await sentinel.readAsBytes(), previous);
      expect(
        (await directory.list().toList()).any(
          (f) => f.path.contains('.voice-receipt-'),
        ),
        false,
      );
    },
  );

  test(
    'process death after staging leaves previous audio intact and permits retry',
    () async {
      final storeUri = File(
        'lib/services/voice_memo/voice_memo_file_store.dart',
      ).absolute.uri;
      final worker = File('${directory.path}/worker.dart');
      await worker.writeAsString('''
import 'dart:io';
import 'dart:typed_data';
import '$storeUri';
Future<void> main(List<String> args) async {
  final receipt = await VoiceMemoFileStore.prepare(File(args[0]), Uint8List.fromList([4,5,6,7]));
  stdout.writeln(receipt.stagedFile.path);
  await stdin.first;
}
''');
      final child = await Process.start('dart', [
        worker.path,
        destination.path,
      ]);
      final errors = child.stderr.transform(utf8.decoder).join();
      try {
        final stagePath = await child.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .first
            .timeout(const Duration(seconds: 20));
        expect(await File(stagePath).readAsBytes(), incoming);
        expect(child.kill(ProcessSignal.sigkill), true);
        await child.exitCode;
        expect(await errors, isEmpty);
        expect(await destination.readAsBytes(), previous);
        await VoiceMemoFileStore.write(destination, incoming);
        expect(await destination.readAsBytes(), incoming);
      } finally {
        child.kill(ProcessSignal.sigkill);
        await child.exitCode;
      }
    },
    skip: Platform.isWindows,
  );
}
