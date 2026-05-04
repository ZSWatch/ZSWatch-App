import 'dart:io';

import 'package:flutter/material.dart';

import 'benchmark_main.dart' as model_bench;
import 'correction_main.dart';
import 'router_benchmark_main.dart';
import 'screens/testbench_screen.dart';
import 'screens/time_extraction_screen.dart';
import 'time_extraction_main.dart';

void main(List<String> args) async {
  // Headless mode: run router pre-classifier benchmark
  if (args.contains('--headless-router')) {
    await runRouterBenchmark(args);
    exit(exitCode);
  }

  // Headless mode: run time extraction tests from CLI
  if (args.contains('--headless-time')) {
    await runHeadlessTimeExtraction(args);
    exit(exitCode);
  }

  // Headless mode: run correction benchmark from CLI
  if (args.contains('--headless-correction')) {
    WidgetsFlutterBinding.ensureInitialized();
    await runHeadlessCorrectionBenchmark(args);
    exit(exitCode);
  }

  // Headless mode: run model benchmark from CLI
  if (args.contains('--headless') ||
      Platform.environment['AI_BENCH_HEADLESS'] == '1') {
    await model_bench.main(args);
    exit(exitCode);
  }

  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AiTestbenchApp());
}

class AiTestbenchApp extends StatelessWidget {
  const AiTestbenchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZSWatch AI Testbench',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.dark,
        ),
      ),
      home: const _HomeShell(),
    );
  }
}

class _HomeShell extends StatefulWidget {
  const _HomeShell();

  @override
  State<_HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<_HomeShell> {
  int _index = 0;

  static const _screens = <Widget>[
    TestbenchScreen(autoStartBenchmark: false),
    TimeExtractionScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.science), label: 'Classify'),
          NavigationDestination(
            icon: Icon(Icons.access_time),
            label: 'Time Extract',
          ),
        ],
      ),
    );
  }
}
