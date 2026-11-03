// Synthetic OpenRouter tool-calling experiment. No real recordings or ICA data.
import 'dart:convert';
import 'dart:io';

import 'package:ai_testbench/benchmark/shopping_cases.dart';
import 'package:chrono_ai_flow/chrono_ai_flow.dart';
import 'package:llm_integrations/llm_integrations.dart';

Future<void> main(List<String> args) async {
  String? arg(String name) {
    final i = args.indexOf('--$name');
    return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
  }

  final model = arg('model') ?? OpenRouterRequest.defaultAnalysisModel;
  final set = arg('set') ?? 'all';
  final mode = arg('mode') ?? 'suggested';
  final limit = int.tryParse(arg('limit') ?? '1000') ?? 0;
  if (!['all', 'base', 'heldout'].contains(set) ||
      !['suggested', 'explicit'].contains(mode) ||
      limit < 1) {
    throw ArgumentError('Invalid set, mode, or limit');
  }
  final path =
      arg('credentials-file') ??
      '${Platform.environment['HOME']}/Documents/zswatch-integration-credentials.json';
  final credential = jsonDecode(File(path).readAsStringSync()) as Map;
  final key = credential['openrouter_api_key'];
  if (key is! String || key.trim().isEmpty) {
    throw StateError('Missing OpenRouter key');
  }
  final extractor = ShoppingExtraction(requireExplicitList: mode == 'explicit');
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
  final cases = shoppingCases
      .where((c) => set == 'all' || (set == 'heldout') == c.heldOut)
      .take(limit)
      .toList();
  final results = <Map<String, Object?>>[];
  var cost = 0.0;

  try {
    for (final c in cases) {
      if (ShoppingExtraction.isNoSpeech(c.transcript)) {
        results.add({
          'case': c.name,
          'passed': true,
          'skipped_no_speech': true,
        });
        stdout.writeln('PASS ${c.name} (no speech)');
        continue;
      }
      final request = await client.postUrl(
        Uri.parse('${OpenRouterRequest.baseUrl}/chat/completions'),
      );
      OpenRouterRequest.headers(key).forEach(request.headers.set);
      request.write(
        jsonEncode(
          OpenRouterRequest.toolProposal(
            model,
            extractor.toolPrompt(),
            c.transcript,
            [extractor.tool],
          ),
        ),
      );
      final response = await request.close().timeout(
        const Duration(seconds: 90),
      );
      final body =
          jsonDecode(
                await response
                    .transform(utf8.decoder)
                    .join()
                    .timeout(const Duration(seconds: 90)),
              )
              as Map;
      if (response.statusCode != 200 || body['error'] != null) {
        throw OpenRouterFailure.fromResponse(
          response.statusCode,
          Map<String, Object?>.from(body),
        );
      }
      final usage = body['usage'];
      if (usage is Map && usage['cost'] is num) {
        cost += (usage['cost'] as num).toDouble();
      }
      final choices = body['choices'];
      final message = choices is List && choices.isNotEmpty
          ? (choices.first as Map)['message'] as Map?
          : null;
      final proposal = extractor.parseToolCalls(
        message?['tool_calls'],
        transcript: c.transcript,
      );
      final expected = mode == 'explicit' && !c.explicit
          ? <List<String>>[]
          : c.items;
      // Items keep their case: brands must reach ICA as spoken.
      String collapse(String s) => s.trim().replaceAll(RegExp(r'\s+'), ' ');
      String normalize(String s) => collapse(s).toLowerCase();
      final actual = proposal.drafts
          .map((d) => d.items.map(collapse).toList())
          .toList();
      final names = proposal.drafts
          .map((d) => normalize(d.listName ?? ''))
          .toList();
      final passed =
          proposal.isValid &&
          jsonEncode(actual) ==
              jsonEncode(
                expected.map((g) => g.map(collapse).toList()).toList(),
              ) &&
          jsonEncode(names) ==
              jsonEncode(
                (expected.isEmpty ? <String?>[] : c.names)
                    .map((n) => normalize(n ?? ''))
                    .toList(),
              );
      results.add({
        'case': c.name,
        'passed': passed,
        'problem': proposal.problem,
        'expected': expected,
        'actual': actual,
        'names': names,
        'model_message': message,
      });
      stdout.writeln('${passed ? 'PASS' : 'FAIL'} ${c.name}');
    }
  } finally {
    client.close(force: true);
    final passed = results.where((r) => r['passed'] == true).length;
    final out = arg('out');
    if (out != null) {
      File(out).writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert({
          'model': model,
          'mode': mode,
          'set': set,
          'passed': passed,
          'total': results.length,
          'cost_usd': cost,
          'results': results,
        }),
      );
    }
    stdout.writeln(
      '$passed/${results.length}; cost USD ${cost.toStringAsFixed(5)}',
    );
    if (passed != results.length) exitCode = 1;
  }
}
