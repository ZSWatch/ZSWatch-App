import 'package:flutter/services.dart';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:zswatch_app/services/ai/companion_voice_processor.dart';
import 'support/companion_recording_fixture.dart';
import 'package:zswatch_app/services/ai/llm_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'transcription checkpoint completes without any STT or LLM model access',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'voice-transcribe-only-',
      );
      final recording = await seedCompanionRecording(root);
      const paths = MethodChannel('plugins.flutter.io/path_provider');
      final pathCalls = <String>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(paths, (call) async {
        pathCalls.add(call.method);
        if (call.method != 'getApplicationSupportDirectory') {
          throw StateError('Unexpected model/scratch access');
        }
        return root.path;
      });
      addTearDown(() async {
        messenger.setMockMethodCallHandler(paths, null);
        await root.delete(recursive: true);
      });
      final result = await processCompanionVoiceRecording(
        {
          'version': 1,
          'spec': {
            'provider': 'dart-voice-v1',
            'backend': 'local',
            'upload_authorized': false,
            'pipeline_revision': 'transcribe-v1',
            'recording_id': recording.identity,
            'input_sha256': recording.sha256,
            'watch_id': recording.watchId,
            'model': 'whisperTinyEn|model-that-is-not-installed|false',
          },
          'recording': {
            'address': recording.watchId,
            'filename': recording.filename,
            'timestamp': recording.timestampUtc.millisecondsSinceEpoch ~/ 1000,
            'duration_ms': recording.durationMs,
            'size_bytes': recording.sizeBytes,
            'state': 'downloaded',
            'local_path': recording.localPath,
            'sha256': recording.sha256,
          },
          'transcript': 'Saved speech from before process death',
        },
        saveTranscript: (_) async =>
            fail('Committed speech must not be retranscribed'),
      );
      expect(result, {
        'version': 1,
        'transcript': 'Saved speech from before process death',
        'summary': '',
        'category': '',
        'actions': <Object?>[],
      });
      expect(pathCalls, ['getApplicationSupportDirectory']);
      expect(File(recording.localPath!).existsSync(), isTrue);
    },
  );
  test(
    'unconfigured remote/hybrid jobs never fall back to local voice processing',
    () async {
      var checkpoints = 0;
      for (final spec in [
        {
          'provider': 'dart-voice-v1',
          'backend': 'remote',
          'upload_authorized': true,
        },
        {
          'provider': 'dart-voice-v1',
          'backend': 'hybrid',
          'upload_authorized': false,
        },
        {
          'provider': 'remote-provider',
          'backend': 'local',
          'upload_authorized': false,
        },
        {
          'provider': 'dart-voice-v1',
          'backend': 'local',
          'upload_authorized': true,
        },
      ]) {
        // Recording/files/model fields are deliberately absent. Unsupported mode
        // must reject before trying to decode input, open files or start models.
        await expectLater(
          processCompanionVoiceRecording(
            {'version': 1, 'spec': spec},
            saveTranscript: (_) async {
              checkpoints++;
            },
          ),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'reason',
              'Unsupported voice processing request',
            ),
          ),
        );
      }
      expect(checkpoints, 0);
    },
  );

  test('cancellation before binding prevents work', () async {
    final cancellation = CompanionVoiceCancellation();
    await cancellation.cancel();
    expect(cancellation.isCancelled, isTrue);
    expect(
      () => cancellation.bind(() async {}),
      throwsA(
        isA<PlatformException>().having((e) => e.code, 'code', 'CANCELLED'),
      ),
    );
    // This request is intentionally invalid: cancellation must win before any
    // platform/file/model access or input validation.
    await expectLater(
      processCompanionVoiceRecording(
        {},
        cancellation: cancellation,
        saveTranscript: (_) async {},
      ),
      throwsA(
        isA<PlatformException>().having((e) => e.code, 'code', 'CANCELLED'),
      ),
    );
  });

  test(
    'cancellation signals one active abort and cannot start another phase',
    () async {
      final cancellation = CompanionVoiceCancellation();
      var calls = 0;
      cancellation.bind(() async {
        calls++;
      });
      await cancellation.cancel();
      await cancellation.cancel();
      expect(calls, 1);
      expect(
        cancellation.check,
        throwsA(
          isA<PlatformException>().having((e) => e.code, 'code', 'CANCELLED'),
        ),
      );
    },
  );

  test('completed execution is detached before later cancellation', () async {
    final cancellation = CompanionVoiceCancellation();
    var calls = 0;
    cancellation.bind(() async {
      calls++;
    });
    cancellation.unbind();
    await cancellation.cancel();
    expect(calls, 0);
  });

  test('headless processing uses the existing no-speech policy', () {
    for (final text in [
      '',
      '  ',
      '<|nospeech|> <|nospeech|>',
      '[Music]',
      '...',
    ]) {
      expect(
        () => requireCompanionSpeech(text),
        throwsA(
          isA<PlatformException>().having((e) => e.code, 'code', 'NO_SPEECH'),
        ),
      );
    }
    requireCompanionSpeech('Påminn mig att köpa mjölk i morgon.');
    requireCompanionSpeech('Start a timer for three minutes.');
  });
  for (final mode in _AnalysisMode.values) {
    final emptyAnalysis = mode == _AnalysisMode.empty;
    test(
      switch (mode) {
        _AnalysisMode.empty =>
          'empty analysis of valid speech is not reported as silent audio',
        _AnalysisMode.actionsOnly =>
          'actions without a summary keep their titles as the summary',
        _AnalysisMode.summary =>
          'validated bilingual checkpoints continue past an uncertain router',
      },
      () async {
        final root = await Directory.systemTemp.createTemp('voice-analysis-');
        final recording = await seedCompanionRecording(root);
        final original = await File(recording.localPath!).readAsBytes();
        const paths = MethodChannel('plugins.flutter.io/path_provider');
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(paths, (call) async {
          expect(call.method, 'getApplicationSupportDirectory');
          return root.path;
        });
        addTearDown(() async {
          messenger.setMockMethodCallHandler(paths, null);
          await root.delete(recursive: true);
        });
        for (final text in [
          'Den blå cykeln står i garaget. Kaffebönorna ligger på den översta hyllan.',
          'The blue bicycle is in the garage. The coffee beans are on the top shelf.',
        ]) {
          final analyzer = _UncertainRouterAnalyzer(mode);
          final processing = processCompanionVoiceRecording(
            {
              'version': 1,
              'spec': {
                'provider': 'dart-voice-v1',
                'backend': 'local',
                'upload_authorized': false,
                'pipeline_revision': 'voice-v1',
                'recording_id': recording.identity,
                'input_sha256': recording.sha256,
                'watch_id': recording.watchId,
                'model': 'whisperSmallMultilingualQ5|fixture-analysis|false',
              },
              'recording': {
                'address': recording.watchId,
                'filename': recording.filename,
                'timestamp':
                    recording.timestampUtc.millisecondsSinceEpoch ~/ 1000,
                'duration_ms': recording.durationMs,
                'size_bytes': recording.sizeBytes,
                'state': 'downloaded',
                'local_path': recording.localPath,
                'sha256': recording.sha256,
              },
              'transcript': text,
            },
            saveTranscript: (_) async => fail('Saved speech was retranscribed'),
            analyzerFactory: () => analyzer,
          );
          if (emptyAnalysis) {
            await expectLater(
              processing,
              throwsA(
                isA<PlatformException>().having(
                  (error) => error.code,
                  'phase',
                  'ANALYSIS_EMPTY',
                ),
              ),
            );
          } else {
            final result = await processing;
            expect(result['transcript'], text);
            expect(
              result['summary'],
              mode == _AnalysisMode.actionsOnly
                  ? 'Buy coffee beans'
                  : isNotEmpty,
            );
          }
          expect(analyzer.discardValidatedSpeech, isFalse);
          expect(analyzer.disposed, isTrue);
          expect(await File(recording.localPath!).readAsBytes(), original);
        }
      },
    );
  }
}

/// Simulates the actual failing router: "none" discards the text unless the
/// caller requests normal analysis of independently validated speech.
enum _AnalysisMode { summary, empty, actionsOnly }

class _UncertainRouterAnalyzer extends Fake implements LlmService {
  _UncertainRouterAnalyzer(this.mode);
  final _AnalysisMode mode;
  bool? discardValidatedSpeech;
  bool disposed = false;

  @override
  void selectModel(String modelId) {}
  @override
  Future<bool> isModelDownloaded({String? modelId}) async => true;
  @override
  bool isBrainDump(String transcript) => false;
  @override
  Future<TranscriptResult> processTranscript(
    String transcript, {
    bool correctTranscription = true,
    String? classifyPromptOverride,
    String? promptStrategyOverride,
    bool rejectNoSpeechRoute = true,
    void Function(String phase, String partialResponse, int tokens)? onProgress,
  }) async {
    discardValidatedSpeech = rejectNoSpeechRoute;
    return TranscriptResult(
      summary: mode != _AnalysisMode.summary || rejectNoSpeechRoute
          ? ''
          : 'A saved factual note.',
      category: 'note',
      actions: [
        if (mode == _AnalysisMode.actionsOnly)
          const ExtractedActionResult(type: 'task', title: 'Buy coffee beans'),
      ],
      originalTranscription: transcript,
    );
  }

  @override
  void dispose() {
    disposed = true;
  }
}
