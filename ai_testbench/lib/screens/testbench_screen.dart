import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:chrono_ai_flow/chrono_ai_flow.dart';

import '../prompts/prompt_templates.dart';
import '../services/llm_service.dart';
import '../services/model_benchmark_service.dart';
import '../widgets/memo_card.dart';

/// Two-pane "Prompt Engineering Lab" for ZSWatch voice memo AI.
class TestbenchScreen extends StatefulWidget {
  const TestbenchScreen({
    super.key,
    this.autoStartBenchmark = true,
    this.searchDirectories,
  });

  final bool autoStartBenchmark;
  final List<String>? searchDirectories;

  @override
  State<TestbenchScreen> createState() => _TestbenchScreenState();
}

class _TestbenchScreenState extends State<TestbenchScreen> {
  // ── Services ──────────────────────────────────────────────────────────────
  final LlmService _llm = LlmService();
  final ModelBenchmarkService _benchmarkService = ModelBenchmarkService();

  // ── Input state ───────────────────────────────────────────────────────────
  String _selectedLanguage = 'English';
  String? _modelPath;
  List<String> _availableModelPaths = const [];
  final _transcriptController = TextEditingController(
    text:
        'Remind me to call the mechanic tomorrow at 3 PM about the brakes and also pick up milk on the way home.',
  );

  // ── Config ────────────────────────────────────────────────────────────────
  int _nCtx = 2048;
  int _nThreads = 4;
  int _maxTokens = 512;

  // ── Mode ──────────────────────────────────────────────────────────────────
  _RunMode _mode = _RunMode.classify;

  // ── Output state ──────────────────────────────────────────────────────────
  String _rawOutput = '';
  String _formattedPrompt = '';
  Map<String, dynamic>? _parsedJson;
  Duration _elapsed = Duration.zero;
  bool _isRunning = false;
  String? _error;

  // ── Streaming output ──────────────────────────────────────────────────────
  String _streamBuffer = '';
  bool _isBenchmarking = false;
  List<BenchmarkModelResult> _benchmarkResults = const [];
  BenchmarkProgress? _benchmarkProgress;
  DateTime? _benchmarkStartedAt;

  @override
  void initState() {
    super.initState();
    unawaited(_discoverModelsAndMaybeBenchmark());
  }

  @override
  void dispose() {
    _transcriptController.dispose();
    _llm.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Actions
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _pickModel() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      dialogTitle: 'Select a .gguf model file',
    );
    if (result != null && result.files.single.path != null) {
      final pickedPath = result.files.single.path!;
      setState(() {
        _modelPath = pickedPath;
        _availableModelPaths = {
          ..._availableModelPaths,
          pickedPath,
        }.toList()
          ..sort();
      });
    }
  }

  Future<void> _discoverModelsAndMaybeBenchmark() async {
    final discovered = <String>{};

    final candidateDirs = <String>{
      ...?widget.searchDirectories,
      if (Platform.isAndroid) ...{
        '/data/user/0/com.example.ai_testbench/cache/file_picker',
        '/sdcard/Download',
        '/storage/emulated/0/Download',
      },
      Directory('models').absolute.path,
    };

    for (final dirPath in candidateDirs) {
      try {
        final dir = Directory(dirPath);
        if (!dir.existsSync()) continue;
        for (final entity in dir.listSync(recursive: true)) {
          if (entity is File && entity.path.toLowerCase().endsWith('.gguf')) {
            discovered.add(entity.path);
          }
        }
      } catch (_) {
        // Ignore unreadable paths on Android scoped storage.
      }
    }

    final sorted = discovered.toList()..sort();
    if (!mounted) return;

    setState(() {
      _availableModelPaths = sorted;
      _modelPath ??= sorted.isNotEmpty ? sorted.first : null;
    });

    if (sorted.isNotEmpty && widget.autoStartBenchmark) {
      await _runBenchmarks(sorted);
    }
  }

  void _loadModel() {
    if (_modelPath == null) return;
    setState(() {
      _error = null;
    });
    try {
      _llm.setModel(_modelPath!);
      _llm.nCtx = _nCtx;
      _llm.nThreads = _nThreads;
      _llm.maxTokens = _maxTokens;
      setState(() {
        _rawOutput = 'Model set ✓ (loads on first inference)';
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _rawOutput = '';
      });
    }
  }

  Future<void> _runBenchmarks([List<String>? modelPaths]) async {
    final models = modelPaths ?? _availableModelPaths;
    if (models.isEmpty) return;

    setState(() {
      _isBenchmarking = true;
      _benchmarkResults = const [];
      _benchmarkProgress = null;
      _benchmarkStartedAt = DateTime.now();
    });

    try {
      final results = await _benchmarkService.runForModels(
        models,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() {
            _benchmarkProgress = progress;
          });
        },
      );
      if (!mounted) return;
      setState(() {
        _benchmarkResults = results;
        _benchmarkProgress = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Benchmark failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isBenchmarking = false;
          _benchmarkStartedAt = null;
        });
      }
    }
  }

  Future<void> _runInference() async {
    if (!_llm.isModelLoaded) {
      setState(() => _error = 'Load a model first.');
      return;
    }

    final transcript = _transcriptController.text.trim();
    if (transcript.isEmpty) {
      setState(() => _error = 'Enter a transcript.');
      return;
    }

    final prompt = _mode == _RunMode.classify
        ? ChronoPromptTemplate.render(
            ChronoPromptTemplate.defaultTemplate, transcript: transcript)
        : PromptTemplates.summarize(
            language: _selectedLanguage, transcript: transcript);

    setState(() {
      _formattedPrompt = prompt;
      _rawOutput = '';
      _streamBuffer = '';
      _parsedJson = null;
      _error = null;
      _isRunning = true;
      _elapsed = Duration.zero;
    });

    try {
      _llm.nCtx = _nCtx;
      _llm.nThreads = _nThreads;
      _llm.maxTokens = _maxTokens;

      final sw = Stopwatch()..start();

      // Stream tokens for live preview (fllama yields cumulative responses)
      int streamEvents = 0;
      await for (final cumulative in _llm.generateStream(prompt)) {
        streamEvents++;
        _streamBuffer = cumulative;
        setState(() => _rawOutput = _streamBuffer);
      }

      sw.stop();
      debugPrint('[Testbench] Stream done: $streamEvents events, '
          '${_streamBuffer.length} chars, ${sw.elapsedMilliseconds}ms');
      if (_streamBuffer.isNotEmpty) {
        debugPrint('[Testbench] Output preview: ${_streamBuffer.substring(0, _streamBuffer.length.clamp(0, 300))}');
      } else {
        debugPrint('[Testbench] WARNING: output is empty!');
      }

      setState(() {
        _elapsed = sw.elapsed;
        _rawOutput = _streamBuffer.trim();
        _isRunning = false;
      });

      _tryParseJson();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isRunning = false;
      });
    }
  }

  void _tryParseJson() {
    try {
      final raw = _rawOutput;
      final jsonStr = _extractFirstJsonObject(raw);
      if (jsonStr != null) {
        final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
        setState(() => _parsedJson = parsed);
      }
    } catch (_) {
      // Not valid JSON – that's fine, we still show raw output
    }
  }

  String? _extractFirstJsonObject(String raw) {
    final start = raw.indexOf('{');
    if (start == -1) return null;

    var depth = 0;
    var inString = false;
    var escaping = false;

    for (var i = start; i < raw.length; i++) {
      final char = raw[i];
      if (escaping) {
        escaping = false;
        continue;
      }
      if (char == '\\' && inString) {
        escaping = true;
        continue;
      }
      if (char == '"') {
        inString = !inString;
        continue;
      }
      if (inString) continue;
      if (char == '{') depth++;
      if (char == '}') {
        depth--;
        if (depth == 0) {
          return raw.substring(start, i + 1);
        }
      }
    }

    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ZSWatch AI Testbench'),
        actions: [
          if (_llm.isModelLoaded)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Chip(
                avatar: const Icon(Icons.check_circle, size: 18, color: Colors.green),
                label: Text(
                  _modelPath?.split(Platform.pathSeparator).last ?? '',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
        ],
      ),
      body: Row(
        children: [
          // ── LEFT PANE: Inputs ──────────────────────────────────────────
          Expanded(flex: 2, child: _buildInputPane()),
          const VerticalDivider(width: 1),
          // ── RIGHT PANE: Outputs ────────────────────────────────────────
          Expanded(flex: 3, child: _buildOutputPane()),
        ],
      ),
    );
  }

  Widget _buildInputPane() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          // ── Model selection ────────────────────────────────────────────
          Text('Model', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _modelPath,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  hint: const Text('No model selected'),
                  items: _availableModelPaths
                      .map(
                        (path) => DropdownMenuItem<String>(
                          value: path,
                          child: Text(
                            path.split(Platform.pathSeparator).last,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() => _modelPath = value);
                  },
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: _pickModel,
                icon: const Icon(Icons.folder_open, size: 18),
                label: const Text('Browse'),
              ),
            ],
          ),
          if (_modelPath != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _isRunning ? null : _loadModel,
                  icon: const Icon(Icons.memory, size: 18),
                  label: Text(_llm.isModelLoaded ? 'Reload Model' : 'Set Model'),
                ),
                OutlinedButton.icon(
                  onPressed: _isRunning || _isBenchmarking || _availableModelPaths.isEmpty
                      ? null
                      : () => _runBenchmarks(),
                  icon: _isBenchmarking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.analytics_outlined, size: 18),
                  label: Text(
                    _isBenchmarking && _benchmarkProgress != null
                        ? 'Benchmarking ${_benchmarkProgress!.completedRuns}/${_benchmarkProgress!.totalRuns}'
                        : _isBenchmarking
                            ? 'Benchmarking…'
                            : 'Benchmark All',
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 24),

          // ── Config ────────────────────────────────────────────────────
          Text('Configuration', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _NumberField(
                  label: 'Context (nCtx)',
                  value: _nCtx,
                  onChanged: (v) => setState(() => _nCtx = v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _NumberField(
                  label: 'Threads',
                  value: _nThreads,
                  onChanged: (v) => setState(() => _nThreads = v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _NumberField(
                  label: 'Max tokens',
                  value: _maxTokens,
                  onChanged: (v) => setState(() => _maxTokens = v),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Language selector ──────────────────────────────────────────
          Text('Language', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedLanguage,
            isExpanded: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: PromptTemplates.supportedLanguages
                .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                .toList(),
            onChanged: (v) => setState(() => _selectedLanguage = v!),
          ),

          const SizedBox(height: 24),

          // ── Mode selector ─────────────────────────────────────────────
          Text('Mode', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<_RunMode>(
            segments: const [
              ButtonSegment(
                value: _RunMode.classify,
                label: Text('Classify'),
                icon: Icon(Icons.category),
              ),
              ButtonSegment(
                value: _RunMode.summarize,
                label: Text('Summarize'),
                icon: Icon(Icons.summarize),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),

          const SizedBox(height: 24),

          // ── Transcript input ──────────────────────────────────────────
          Text('Transcript', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _transcriptController,
            maxLines: 8,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Paste a fake Whisper transcript here…',
            ),
          ),

          const SizedBox(height: 16),

          // ── Run button ────────────────────────────────────────────────
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: _isRunning ? null : _runInference,
              icon: _isRunning
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(_isRunning ? 'Running…' : 'Run Inference'),
            ),
          ),

          const SizedBox(height: 24),

          // ── Sample transcripts ─────────────────────────────────────────
          Text('Sample Transcripts',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ..._sampleTranscripts.map(
            (sample) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: ActionChip(
                label: Text(
                  sample.label,
                  overflow: TextOverflow.ellipsis,
                ),
                onPressed: () {
                  _transcriptController.text = sample.text;
                  setState(() => _selectedLanguage = sample.language);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutputPane() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          // ── Error banner ──────────────────────────────────────────────
          if (_error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
              ),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),

          // ── Stats bar ─────────────────────────────────────────────────
          if (_isBenchmarking) ...[
            _buildBenchmarkProgressCard(),
            const SizedBox(height: 16),
          ],

          if (_elapsed.inMilliseconds > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Wrap(
                spacing: 16,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer_outlined, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        '${(_elapsed.inMilliseconds / 1000).toStringAsFixed(2)}s',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.speed, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        _rawOutput.isNotEmpty && _elapsed.inMilliseconds > 0
                            ? '~${(_rawOutput.split(RegExp(r'\s+')).length / (_elapsed.inMilliseconds / 1000)).toStringAsFixed(1)} tok/s'
                            : '–',
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.text_fields, size: 16),
                      const SizedBox(width: 6),
                      Text('${_rawOutput.length} chars'),
                    ],
                  ),
                ],
              ),
            ),

          if (_benchmarkResults.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Benchmark Results',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ..._benchmarkResults.map(
              (result) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.modelName,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          Text('Pass: ${result.passedCases}/${result.cases.length}'),
                          Text(
                            'Avg tok/s: ${result.avgTokensPerSecond.toStringAsFixed(1)}',
                          ),
                          Text(
                            'Total: ${(result.totalElapsed.inMilliseconds / 1000).toStringAsFixed(1)}s',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...result.cases.map(
                        (caseResult) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${caseResult.passed ? '✅' : '❌'} ${caseResult.caseName}: '
                                'json=${caseResult.validJson ? '✓' : '✗'} · '
                                'intent=${caseResult.intent}${caseResult.intentMatch ? '✓' : '✗'} · '
                                'time=${caseResult.timePresenceMatch ? '✓' : '✗'} · '
                                'lang=${caseResult.titleLanguageMatch ? '✓' : '✗'} · '
                                'resolve=${caseResult.timeResolutionCorrect ? '✓' : '✗'} · '
                                'count=${caseResult.extractedCount}/${caseResult.expectedCount}${caseResult.countMatch ? '✓' : '✗'} · '
                                '${(caseResult.elapsed.inMilliseconds / 1000).toStringAsFixed(1)}s · '
                                '${caseResult.tokensPerSecond.toStringAsFixed(1)} tok/s',
                              ),
                              if (caseResult.title != null)
                                Text(
                                  'title: ${caseResult.title}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              if (caseResult.timeResolutionDetail != null)
                                Text(
                                  'time: ${caseResult.timeResolutionDetail}',
                                  style: TextStyle(
                                    color: caseResult.timeResolutionCorrect ? Colors.green : Colors.orangeAccent,
                                    fontSize: 11,
                                  ),
                                ),
                              if (caseResult.titleLanguageDetail != null &&
                                  !caseResult.titleLanguageMatch)
                                Text(
                                  'lang: ${caseResult.titleLanguageDetail}',
                                  style: const TextStyle(
                                    color: Colors.orangeAccent,
                                    fontSize: 11,
                                  ),
                                ),
                              if (caseResult.error != null)
                                Text(
                                  'error: ${caseResult.error}',
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 12,
                                  ),
                                ),
                              if (caseResult.itemFailures.isNotEmpty)
                                ...caseResult.itemFailures.map(
                                  (f) => Text(
                                    '  ⚠ $f',
                                    style: const TextStyle(
                                      color: Colors.orangeAccent,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],

          // ── Parsed card preview ───────────────────────────────────────
          if (_parsedJson != null) ...[
            Text('Card Preview',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            MemoCard(data: _parsedJson!),
            const SizedBox(height: 24),
          ],

          // ── Raw JSON output ───────────────────────────────────────────
          Text('Raw Model Output',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white12),
            ),
            child: SelectableText(
              _rawOutput.isEmpty ? '(output will appear here)' : _rawOutput,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Formatted prompt (expandable) ─────────────────────────────
          if (_formattedPrompt.isNotEmpty) ...[
            ExpansionTile(
              title: const Text('Full Prompt Sent to Model'),
              initiallyExpanded: false,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    _formattedPrompt,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      height: 1.4,
                      color: Colors.amber,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBenchmarkProgressCard() {
    final progress = _benchmarkProgress;
    final fraction = progress?.fractionComplete ?? 0;
    final completed = progress?.completedRuns ?? 0;
    final total = progress?.totalRuns ?? 0;
    final startedAt = _benchmarkStartedAt;

    Duration? eta;
    if (startedAt != null && completed > 0 && total > completed) {
      final elapsed = DateTime.now().difference(startedAt);
      final avgPerRunMs = elapsed.inMilliseconds / completed;
      eta = Duration(milliseconds: (avgPerRunMs * (total - completed)).round());
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  progress == null
                      ? 'Preparing benchmark…'
                      : 'Running ${progress.currentModelName} · case ${progress.currentCaseIndex + 1}/${progress.totalCasesPerModel}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: total == 0 ? null : fraction.clamp(0, 1)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              Text('Completed: $completed/$total'),
              if (progress != null)
                Text('Model: ${progress.currentModelIndex + 1}/${progress.totalModels}'),
              if (progress != null && progress.currentCaseName.isNotEmpty)
                Text('Case: ${progress.currentCaseName}'),
              if (eta != null) Text('ETA: ${_formatDuration(eta)}'),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Run mode
// ═════════════════════════════════════════════════════════════════════════════

enum _RunMode { classify, summarize }

// ═════════════════════════════════════════════════════════════════════════════
// Number field helper
// ═════════════════════════════════════════════════════════════════════════════

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      keyboardType: TextInputType.number,
      controller: TextEditingController(text: value.toString())
        ..selection = TextSelection.collapsed(offset: value.toString().length),
      onSubmitted: (v) {
        final n = int.tryParse(v);
        if (n != null && n > 0) onChanged(n);
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Sample transcripts for quick testing
// ═════════════════════════════════════════════════════════════════════════════

class _SampleTranscript {
  final String label;
  final String text;
  final String language;
  const _SampleTranscript(this.label, this.text, this.language);
}

const _sampleTranscripts = [
  _SampleTranscript(
    '🇬🇧 TODO: Errands',
    'I need to pick up the dry cleaning, buy groceries, and call the dentist to reschedule my appointment.',
    'English',
  ),
  _SampleTranscript(
    '🇬🇧 EVENT: Meeting',
    'Remind me about the team standup tomorrow at 9 AM in the main conference room.',
    'English',
  ),
  _SampleTranscript(
    '🇬🇧 NOTE: Idea',
    'Had an interesting idea about using sensor fusion for step detection. Should look into the BMI270 FIFO watermark interrupt as a trigger.',
    'English',
  ),
  _SampleTranscript(
    '🇸🇪 TODO: Handla',
    'Påminn mig om att köpa mjölk och fixa dörren i helgen.',
    'Swedish',
  ),
  _SampleTranscript(
    '🇸🇪 EVENT: Möte',
    'Jag har ett möte med tandläkaren på fredag klockan 14.',
    'Swedish',
  ),
  _SampleTranscript(
    '🇸🇪 NOTE: Anteckning',
    'Bra presentation idag om maskininlärning och edge computing. Kolla upp TensorFlow Lite för mikrokontrollers.',
    'Swedish',
  ),
];
