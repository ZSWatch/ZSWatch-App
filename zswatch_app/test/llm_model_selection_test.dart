import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:zswatch_app/providers/ai_providers.dart';
import 'package:zswatch_app/providers/settings_providers.dart';
import 'package:zswatch_app/services/ai/llm_service.dart';

class CatalogFiles extends LlmService {
  @override
  Future<bool> isModelDownloaded({String? modelId}) async =>
      modelId == 'installed';
  @override
  Future<int?> modelFileSize({String? modelId}) async =>
      modelId == 'installed' ? 1024 : null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const liteRt = MethodChannel('dev.zswatch.app/litert_lm');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(liteRt, (call) async => null);
  test(
    'model status refreshes when asynchronous preferences replace the default selection',
    () async {
      final service = CatalogFiles();
      final selection = SelectedAiModelIdNotifier(null);
      final container = ProviderContainer(
        overrides: [
          llmServiceProvider.overrideWithValue(service),
          selectedAiModelIdProvider.overrideWith((ref) => selection),
        ],
      );
      try {
        expect(
          await container.read(llmModelDownloadedProvider.future),
          isFalse,
        );
        expect(await container.read(llmModelSizeProvider.future), isNull);
        // Same service instance: a status cache must follow model identity too.
        selection.setModelId('installed');
        expect(await container.read(llmModelDownloadedProvider.future), isTrue);
        expect(await container.read(llmModelSizeProvider.future), 1024);
        selection.setModelId('missing');
        expect(
          await container.read(llmModelDownloadedProvider.future),
          isFalse,
        );
        expect(await container.read(llmModelSizeProvider.future), isNull);
      } finally {
        container.dispose();
        service.dispose();
      }
    },
  );
}
