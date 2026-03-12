import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../services/time_extraction_benchmark_service.dart';

/// Screen for running the voice memo → time extraction pipeline testbench.
///
/// Auto-discovers models, auto-runs tests, and displays results in a
/// scrollable log view.
class TimeExtractionScreen extends StatefulWidget {
  const TimeExtractionScreen({super.key});

  @override
  State<TimeExtractionScreen> createState() => _TimeExtractionScreenState();
}

class _TimeExtractionScreenState extends State<TimeExtractionScreen> {
  final TimeExtractionBenchmarkService _service =
      TimeExtractionBenchmarkService();
  final ScrollController _scrollController = ScrollController();

  List<String> _availableModels = const [];
  String? _selectedModel;
  bool _isRunning = false;
  TimeExtractionProgress? _progress;
  List<TimeExtractionModelResult> _results = const [];
  final List<String> _logLines = [];

  @override
  void initState() {
    super.initState();
    _discoverModels();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _discoverModels() {
    final modelDir = Directory('models');
    if (!modelDir.existsSync()) {
      _log('No models/ directory found');
      return;
    }
    final models = modelDir
        .listSync()
        .whereType<File>()
        .map((f) => f.path)
        .where((p) => p.toLowerCase().endsWith('.gguf'))
        .toList()
      ..sort();

    setState(() {
      _availableModels = models;
      if (models.isNotEmpty) _selectedModel = models.first;
    });
    _log('Found ${models.length} model(s)');
    for (final m in models) {
      _log('  - ${m.split(Platform.pathSeparator).last}');
    }
  }

  void _log(String line) {
    setState(() => _logLines.add(line));
    // Auto-scroll after next frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _runTests() async {
    if (_selectedModel == null) return;

    setState(() {
      _isRunning = true;
      _results = [];
      _logLines.clear();
    });

    _log('══════════════════════════════════════════════════');
    _log('  Time Extraction Testbench');
    _log('  Model: ${_selectedModel!.split(Platform.pathSeparator).last}');
    _log('  Reference: ${TimeExtractionBenchmarkService.referenceTime}');
    _log('  Cases: ${TimeExtractionBenchmarkService.testCases.length}');
    _log('══════════════════════════════════════════════════');
    _log('');

    final results = await _service.runForModels(
      [_selectedModel!],
      onProgress: (p) {
        setState(() => _progress = p);
        _log('[${p.completedCases}/${p.totalCases}] ${p.currentCaseName}');
      },
    );

    setState(() {
      _results = results;
      _isRunning = false;
      _progress = null;
    });

    // Print formatted results to log
    final formatted = TimeExtractionBenchmarkService.formatResults(results);
    for (final line in formatted.split('\n')) {
      _log(line);
    }
  }

  Future<void> _runAllModels() async {
    if (_availableModels.isEmpty) return;

    setState(() {
      _isRunning = true;
      _results = [];
      _logLines.clear();
    });

    _log('══════════════════════════════════════════════════');
    _log('  Time Extraction Testbench — ALL MODELS');
    _log('  Models: ${_availableModels.length}');
    _log('══════════════════════════════════════════════════');
    _log('');

    final results = await _service.runForModels(
      _availableModels,
      onProgress: (p) {
        setState(() => _progress = p);
        _log('[${p.modelName}] [${p.completedCases}/${p.totalCases}] '
            '${p.currentCaseName}');
      },
    );

    setState(() {
      _results = results;
      _isRunning = false;
      _progress = null;
    });

    final formatted = TimeExtractionBenchmarkService.formatResults(results);
    for (final line in formatted.split('\n')) {
      _log(line);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Time Extraction Testbench'),
      ),
      body: Column(
        children: [
          // ── Controls bar ──
          _buildControlsBar(),
          // ── Progress indicator ──
          if (_isRunning && _progress != null)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: _progress!.fraction,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_progress!.modelName} — '
                    '${_progress!.completedCases}/${_progress!.totalCases}: '
                    '${_progress!.currentCaseName}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          const Divider(height: 1),
          // ── Results table ──
          if (_results.isNotEmpty) ...[
            _buildResultsSummary(),
            const Divider(height: 1),
          ],
          // ── Log output ──
          Expanded(child: _buildLog()),
        ],
      ),
    );
  }

  Widget _buildControlsBar() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // Model dropdown
          Expanded(
            child: DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Model',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              initialValue: _selectedModel,
              items: _availableModels.map((path) {
                final name = path.split(Platform.pathSeparator).last;
                return DropdownMenuItem(value: path, child: Text(name));
              }).toList(),
              onChanged: _isRunning
                  ? null
                  : (v) => setState(() => _selectedModel = v),
            ),
          ),
          const SizedBox(width: 12),
          // Run selected
          FilledButton.icon(
            onPressed: _isRunning ? null : _runTests,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Run'),
          ),
          const SizedBox(width: 8),
          // Run all
          OutlinedButton.icon(
            onPressed: _isRunning ? null : _runAllModels,
            icon: const Icon(Icons.all_inclusive),
            label: const Text('All Models'),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsSummary() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: DataTable(
        columnSpacing: 20,
        headingRowHeight: 36,
        dataRowMinHeight: 28,
        dataRowMaxHeight: 28,
        columns: const [
          DataColumn(label: Text('Model')),
          DataColumn(label: Text('Pass'), numeric: true),
          DataColumn(label: Text('Partial'), numeric: true),
          DataColumn(label: Text('Fail'), numeric: true),
          DataColumn(label: Text('Time'), numeric: true),
          DataColumn(label: Text('tok/s'), numeric: true),
        ],
        rows: _results.map((model) {
          return DataRow(cells: [
            DataCell(Text(model.modelName,
                style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(Text('${model.passedCount}',
                style: const TextStyle(color: Colors.green))),
            DataCell(Text('${model.partialCount}',
                style: const TextStyle(color: Colors.orange))),
            DataCell(Text('${model.failedCount}',
                style: const TextStyle(color: Colors.red))),
            DataCell(Text(
                '${(model.totalElapsed.inMilliseconds / 1000).toStringAsFixed(1)}s')),
            DataCell(
                Text(model.avgTokensPerSecond.toStringAsFixed(1))),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _buildLog() {
    return Container(
      color: Colors.black,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(12),
        itemCount: _logLines.length,
        itemBuilder: (context, index) {
          final line = _logLines[index];
          // Color-code based on content
          Color color = Colors.grey.shade300;
          if (line.contains('✅')) {
            color = Colors.green;
          } else if (line.contains('❌')) {
            color = Colors.red;
          } else if (line.contains('⚠️')) {
            color = Colors.orange;
          } else if (line.contains('═') || line.contains('║')) {
            color = Colors.cyan;
          }

          return Text(
            line,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: color,
              height: 1.4,
            ),
          );
        },
      ),
    );
  }
}
