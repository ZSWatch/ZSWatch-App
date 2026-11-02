import 'package:llm_integrations/llm_integrations.dart';

import '../ai/openrouter_client.dart';

/// Isolated OpenRouter-only planner for the optional ICA integration.
/// Account credentials never enter the model request.
class IcaShoppingProposalService {
  const IcaShoppingProposalService(this._client, this._model);

  final OpenRouterClient _client;
  final String _model;

  Future<ShoppingExtractionResult> propose(String transcript) async {
    const extractor = ShoppingExtraction();
    if (ShoppingExtraction.isNoSpeech(transcript)) {
      return ShoppingExtractionResult(drafts: const []);
    }
    final calls = await _client.proposeTools(
      _model,
      extractor.toolPrompt(),
      transcript,
      [extractor.tool],
    );
    return extractor.parseToolCalls(calls, transcript: transcript);
  }
}
