import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'dart:io';
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
  test(
    'deleting the selected import restores default without deleting it',
    () async {
      final root = await Directory.systemTemp.createTemp('llm-import-delete-');
      const paths = MethodChannel('plugins.flutter.io/path_provider');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(paths, (_) async => root.path);
      final service = LlmService();
      try {
        final defaultModel = LlmService.catalogModels.firstWhere(
          (m) => m.id == LlmService.defaultModelId,
        );
        final original = File(
          '${root.path}/llm_models/${defaultModel.filename}',
        );
        await original.parent.create(recursive: true);
        await original.writeAsBytes([1, 2, 3]);
        final source = File('${root.path}/owned.gguf');
        await source.writeAsBytes([4, 5, 6]);
        final imported = await service.importModel(source.path);
        expect(service.selectedModelId, imported.id);
        await service.deleteModel();
        expect(service.selectedModelId, LlmService.defaultModelId);
        expect(
          (await service.currentModelInfo()).id,
          LlmService.defaultModelId,
        );
        expect(await original.readAsBytes(), [1, 2, 3]);
        expect(await source.readAsBytes(), [4, 5, 6]);
        expect(
          File(
            '${root.path}/llm_models/imported/${imported.filename}',
          ).existsSync(),
          isFalse,
        );
        // Deleting an unselected import must preserve a later explicit choice.
        final second = await service.importModel(source.path);
        service.selectModel(LlmService.catalogModels.first.id);
        await service.deleteModel(modelId: second.id);
        expect(service.selectedModelId, LlmService.catalogModels.first.id);
        service.selectModel('custom::missing.gguf');
        await expectLater(service.deleteModel(), throwsStateError);
        expect(await original.readAsBytes(), [1, 2, 3]);
        // Catalog deletion keeps its selection so the user can download again.
        service.selectModel(LlmService.defaultModelId);
        await service.deleteModel();
        expect(service.selectedModelId, LlmService.defaultModelId);
        expect(original.existsSync(), isFalse);
      } finally {
        service.dispose();
        messenger.setMockMethodCallHandler(paths, null);
        await root.delete(recursive: true);
      }
    },
  );
}
