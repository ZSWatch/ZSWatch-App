// Runs the app's extraction pipeline against a llama.cpp server (or any
// OpenAI-compatible endpoint) and scores it with the benchmark cases.
//
//   llama-server -m models/<model>.gguf --port 8091 -c 4096 --jinja
//   dart run bin/server_bench.dart --sampling litert --runs 2
//
// Options:
//   --url <base>          Server URL (default http://127.0.0.1:8091)
//   --sampling <name>     fllama (app's llama.cpp path) or litert (Gemma)
//   --template <name>     compact (what the app uses) or default
//   --runs <n>            Repeat every case n times (default 1)
//   --set <name>          base, real, all (base + real) or heldout
//   --prompt-file <file>  Use this template text instead of --template
//   --filter <text>       Only cases whose name contains text
//   --out <file>          Write per-case results as JSON
import 'dart:convert';
import 'dart:io';

import 'package:ai_testbench/benchmark/benchmark_cases.dart';
import 'package:ai_testbench/benchmark/benchmark_scoring.dart';
import 'package:ai_testbench/benchmark/held_out_cases.dart';
import 'package:ai_testbench/benchmark/real_world_cases.dart';
import 'package:chrono_ai_flow/chrono_ai_flow.dart';

Future<void> main(List<String> args) async {
  String? arg(String name) {
    final i = args.indexOf('--$name');
    return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
  }

  final url = arg('url') ?? 'http://127.0.0.1:8091';
  final sampling = arg('sampling') ?? 'fllama';
  final promptFile = arg('prompt-file');
  final template = promptFile != null
      ? File(promptFile).readAsStringSync()
      : arg('template') == 'default'
      ? ChronoPromptTemplate.defaultTemplate
      : ChronoPromptTemplate.compactTemplate;
  final runs = int.parse(arg('runs') ?? '1');
  final filter = arg('filter');
  final set = arg('set') ?? 'all';
  final cases = [
    if (set == 'heldout') ...heldOutCases,
    if (set == 'base' || set == 'all') ...benchmarkCases,
    if (set == 'real' || set == 'all') ...realWorldCases,
  ].where((c) => filter == null || c.name.contains(filter)).toList();

  final client = _Client(url, sampling);
  final pipeline = ChronoExtractionPipeline();
  final results = <Map<String, Object?>>[];
  final byCategory = <String, (int, int)>{};
  var retries = 0;

  void record(
    BenchmarkCase c,
    List<String> failures,
    String raw,
    String? firstRaw,
  ) {
    final category = categoryOf(c);
    final (pass, total) = byCategory[category] ?? (0, 0);
    byCategory[category] = (pass + (failures.isEmpty ? 1 : 0), total + 1);
    results.add({
      'case': c.name,
      'category': category,
      'transcript': c.transcript,
      'passed': failures.isEmpty,
      'failures': failures,
      'raw': raw,
      'first_raw': ?firstRaw,
    });
  }

  for (var run = 0; run < runs; run++) {
    for (final c in cases) {
      final prompt = ChronoPromptTemplate.render(
        template,
        transcript: c.transcript,
        now: benchmarkReferenceTime,
      );
      // The app skips the model for no-speech transcripts.
      if (ChronoExtractionPipeline.isNoSpeech(c.transcript)) {
        record(c, scoreCase(c, const []), '[]', null);
        continue;
      }
      // Same attempts as LlmService: retry a copied example or invalid JSON.
      var raw = await client.complete(prompt);
      String? firstRaw;
      if (pipeline.copiedFromExamples(raw, c.transcript) ||
          pipeline.parser.extractFirstJsonArray(raw) == null) {
        retries++;
        firstRaw = raw;
        raw = await client.complete(
          ChronoExtractionPipeline.retryPrompt(prompt),
        );
      }
      record(c, scoreCase(c, pipeline.extract(raw)), raw, firstRaw);
    }
  }

  for (final r in results.where((r) => r['passed'] != true)) {
    stdout.writeln(
      'FAIL ${r['case']}: ${(r['failures'] as List).join('; ')}\n'
      '     ${(r['raw'] as String).replaceAll(RegExp(r'\s+'), ' ')}',
    );
  }
  final passed = results.where((r) => r['passed'] == true).length;
  stdout.writeln('');
  for (final MapEntry(key: category, value: (pass, total))
      in byCategory.entries.toList()..sort((a, b) => a.key.compareTo(b.key))) {
    stdout.writeln('${category.padRight(10)} $pass/$total');
  }
  stdout.writeln('TOTAL      $passed/${results.length}  retries=$retries');

  final out = arg('out');
  if (out != null) {
    File(
      out,
    ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(results));
  }
  client.close();
}

class _Client {
  _Client(this.url, this.sampling);

  final String url;
  final String sampling;
  final _http = HttpClient();

  /// Sampling as the app sends it: fllama for GGUF models, LiteRT-LM for Gemma.
  Future<String> complete(String prompt) async {
    for (var attempt = 0; ; attempt++) {
      try {
        return await _complete(prompt);
      } on Object catch (e) {
        if (e is! SocketException && e is! HttpException) rethrow;
        if (attempt == 2) rethrow;
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }
  }

  Future<String> _complete(String prompt) async {
    final request = await _http.postUrl(Uri.parse('$url/v1/chat/completions'));
    request.headers.contentType = ContentType.json;
    request.write(
      jsonEncode({
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
        'max_tokens': 512,
        'temperature': 0.3,
        'top_p': 1.0,
        if (sampling == 'litert') 'top_k': 40 else 'presence_penalty': 2.0,
        'chat_template_kwargs': {'enable_thinking': false},
      }),
    );
    final response = await request.close();
    final text = await response.transform(utf8.decoder).join();
    final choices = (jsonDecode(text) as Map)['choices'] as List?;
    if (choices == null) throw HttpException('Server error: $text');
    final choice = choices.first as Map;
    return (choice['message'] as Map)['content'] as String;
  }

  void close() => _http.close();
}
