import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/shell/shell_service.dart';
import 'watch_service_provider.dart';

/// Provider for the shell service singleton.
final shellServiceProvider = Provider<ShellService>((ref) {
  final service = ShellService();
  ref.onDispose(() => service.dispose());

  // Auto-set device when connection changes.
  ref.listen(watchConnectionProvider, (prev, next) {
    if (next.isConnected && next.watchId.isNotEmpty) {
      service.setDevice(next.watchId);
    }
  }, fireImmediately: true);

  return service;
});

/// A single terminal line (command or output).
class TerminalLine {
  final String text;
  final bool isCommand;
  final bool isError;
  final DateTime timestamp;

  const TerminalLine({
    required this.text,
    this.isCommand = false,
    this.isError = false,
    required this.timestamp,
  });
}

/// State for the shell terminal.
class ShellTerminalState {
  final List<TerminalLine> lines;
  final bool isExecuting;
  final List<String> commandHistory;
  final int historyIndex;

  const ShellTerminalState({
    this.lines = const [],
    this.isExecuting = false,
    this.commandHistory = const [],
    this.historyIndex = -1,
  });

  ShellTerminalState copyWith({
    List<TerminalLine>? lines,
    bool? isExecuting,
    List<String>? commandHistory,
    int? historyIndex,
  }) {
    return ShellTerminalState(
      lines: lines ?? this.lines,
      isExecuting: isExecuting ?? this.isExecuting,
      commandHistory: commandHistory ?? this.commandHistory,
      historyIndex: historyIndex ?? this.historyIndex,
    );
  }
}

/// Notifier for the interactive shell terminal.
class ShellTerminalNotifier extends StateNotifier<ShellTerminalState> {
  final ShellService _shellService;

  ShellTerminalNotifier(this._shellService)
      : super(const ShellTerminalState());

  Future<void> execute(String command) async {
    if (command.trim().isEmpty) return;

    // Add command to history
    final history = [...state.commandHistory];
    // Remove duplicate if already the last entry
    if (history.isEmpty || history.last != command) {
      history.add(command);
    }

    state = state.copyWith(
      lines: [
        ...state.lines,
        TerminalLine(
          text: '\$ $command',
          isCommand: true,
          timestamp: DateTime.now(),
        ),
      ],
      isExecuting: true,
      commandHistory: history,
      historyIndex: -1,
    );

    try {
      final result = await _shellService.execute(command);
      state = state.copyWith(
        lines: [
          ...state.lines,
          if (result.output.isNotEmpty)
            TerminalLine(
              text: result.output,
              timestamp: DateTime.now(),
            ),
          if (result.returnCode != 0)
            TerminalLine(
              text: '[exit code: ${result.returnCode}]',
              isError: true,
              timestamp: DateTime.now(),
            ),
        ],
        isExecuting: false,
      );
    } catch (e) {
      state = state.copyWith(
        lines: [
          ...state.lines,
          TerminalLine(
            text: 'Error: $e',
            isError: true,
            timestamp: DateTime.now(),
          ),
        ],
        isExecuting: false,
      );
    }
  }

  void clear() {
    state = state.copyWith(lines: []);
  }

  String? historyUp() {
    if (state.commandHistory.isEmpty) return null;
    final newIndex = state.historyIndex == -1
        ? state.commandHistory.length - 1
        : (state.historyIndex - 1).clamp(0, state.commandHistory.length - 1);
    state = state.copyWith(historyIndex: newIndex);
    return state.commandHistory[newIndex];
  }

  String? historyDown() {
    if (state.commandHistory.isEmpty || state.historyIndex == -1) return null;
    final newIndex = state.historyIndex + 1;
    if (newIndex >= state.commandHistory.length) {
      state = state.copyWith(historyIndex: -1);
      return '';
    }
    state = state.copyWith(historyIndex: newIndex);
    return state.commandHistory[newIndex];
  }
}

final shellTerminalProvider =
    StateNotifierProvider<ShellTerminalNotifier, ShellTerminalState>((ref) {
  final shellService = ref.watch(shellServiceProvider);
  return ShellTerminalNotifier(shellService);
});

/// State for the live monitor.
class LiveMonitorState {
  final bool isEnabled;
  final String? powerData;
  final String? cpuData;
  final String? threadData;
  final DateTime? lastUpdate;
  final String? error;

  const LiveMonitorState({
    this.isEnabled = false,
    this.powerData,
    this.cpuData,
    this.threadData,
    this.lastUpdate,
    this.error,
  });

  LiveMonitorState copyWith({
    bool? isEnabled,
    String? powerData,
    String? cpuData,
    String? threadData,
    DateTime? lastUpdate,
    String? error,
  }) {
    return LiveMonitorState(
      isEnabled: isEnabled ?? this.isEnabled,
      powerData: powerData ?? this.powerData,
      cpuData: cpuData ?? this.cpuData,
      threadData: threadData ?? this.threadData,
      lastUpdate: lastUpdate ?? this.lastUpdate,
      error: error,
    );
  }
}

/// Notifier for the live monitor that polls thread/stack info.
class LiveMonitorNotifier extends StateNotifier<LiveMonitorState> {
  final ShellService _shellService;
  Timer? _pollTimer;

  LiveMonitorNotifier(this._shellService)
      : super(const LiveMonitorState());

  void toggle() {
    if (state.isEnabled) {
      stop();
    } else {
      start();
    }
  }

  void start() {
    state = state.copyWith(isEnabled: true, error: null);
    _poll();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _poll());
  }

  void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
    state = LiveMonitorState(
      isEnabled: false,
      powerData: state.powerData,
      cpuData: state.cpuData,
      threadData: state.threadData,
      lastUpdate: state.lastUpdate,
    );
  }

  Future<void> _poll() async {
    if (!state.isEnabled) return;

    try {
      String? powerOutput;
      try {
        final powerResult = await _shellService.execute('power status');
        if (state.isEnabled) powerOutput = powerResult.output;
      } catch (_) {}
      if (!state.isEnabled) return;

      String? cpuOutput;
      try {
        final cpuResult = await _shellService.execute('cpu freq');
        if (state.isEnabled) cpuOutput = cpuResult.output;
      } catch (_) {}

      String? threadOutput;
      try {
        final threadResult = await _shellService.execute('kernel thread list');
        if (state.isEnabled) threadOutput = threadResult.output;
      } catch (_) {}

      if (!state.isEnabled) return;
      state = state.copyWith(
        powerData: powerOutput,
        cpuData: cpuOutput,
        threadData: threadOutput,
        lastUpdate: DateTime.now(),
        error: null,
      );
    } catch (e) {
      if (state.isEnabled) {
        state = state.copyWith(error: e.toString());
      }
    }
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

final liveMonitorProvider =
    StateNotifierProvider<LiveMonitorNotifier, LiveMonitorState>((ref) {
  final shellService = ref.watch(shellServiceProvider);
  return LiveMonitorNotifier(shellService);
});
