import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/thread_monitor_data.dart';
import '../services/shell/shell_service.dart';
import 'watch_service_provider.dart';

// The interactive terminal surfaces non-zero return codes in the UI; the live
// monitor handles them separately so it can stop polling when a capability is
// missing.

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
  final String? cpuFreq;
  final PowerInfo? powerInfo;
  final Map<String, ThreadHistory> threadHistories;
  final int? schedulerCycles;
  final DateTime? lastUpdate;
  final String? error;
  final int pollCount;

  const LiveMonitorState({
    this.isEnabled = false,
    this.cpuFreq,
    this.powerInfo,
    this.threadHistories = const {},
    this.schedulerCycles,
    this.lastUpdate,
    this.error,
    this.pollCount = 0,
  });

  LiveMonitorState copyWith({
    bool? isEnabled,
    String? cpuFreq,
    PowerInfo? powerInfo,
    Map<String, ThreadHistory>? threadHistories,
    int? schedulerCycles,
    DateTime? lastUpdate,
    String? error,
    int? pollCount,
  }) {
    return LiveMonitorState(
      isEnabled: isEnabled ?? this.isEnabled,
      cpuFreq: cpuFreq ?? this.cpuFreq,
      powerInfo: powerInfo ?? this.powerInfo,
      threadHistories: threadHistories ?? this.threadHistories,
      schedulerCycles: schedulerCycles ?? this.schedulerCycles,
      lastUpdate: lastUpdate ?? this.lastUpdate,
      error: error,
      pollCount: pollCount ?? this.pollCount,
    );
  }
}

/// Notifier for the live monitor that polls thread/stack info.
class LiveMonitorNotifier extends StateNotifier<LiveMonitorState> {
  final ShellService _shellService;
  Timer? _pollTimer;
  bool _polling = false;
  int _consecutiveErrors = 0;
  static const _pollInterval = Duration(seconds: 1);
  static const _maxConsecutiveErrors = 5;

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
    if (state.isEnabled) return;
    _consecutiveErrors = 0;
    state = state.copyWith(isEnabled: true, error: null);
    _poll();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _poll());
  }

  /// Cancel the polling timer without modifying provider state.
  /// Safe to call during widget lifecycle (build/deactivate/dispose).
  void cancelPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void stop() {
    cancelPolling();
    state = LiveMonitorState(
      isEnabled: false,
      cpuFreq: state.cpuFreq,
      powerInfo: state.powerInfo,
      threadHistories: state.threadHistories,
      schedulerCycles: state.schedulerCycles,
      lastUpdate: state.lastUpdate,
      pollCount: state.pollCount,
    );
  }

  void resetHistory() {
    state = state.copyWith(
      threadHistories: {},
      pollCount: 0,
    );
  }

  Future<void> _poll() async {
    if (!state.isEnabled || _polling) return;
    _polling = true;

    try {
      // Power status
      PowerInfo? powerInfo;
      try {
        final powerResult = await _shellService.execute('power status');
        if (state.isEnabled) {
          powerInfo = parsePowerStatus(powerResult.output);
        }
      } catch (_) {}
      if (!state.isEnabled) return;

      // CPU freq
      String? cpuFreq;
      try {
        final cpuResult = await _shellService.execute('cpu freq');
        if (state.isEnabled) {
          cpuFreq = parseCpuFreq(cpuResult.output);
        }
      } catch (_) {}

      // Thread list
      ThreadListParseResult? parsed;
      try {
        final threadResult = await _shellService.execute('kernel thread list');
        if (state.isEnabled) {
          parsed = parseThreadList(threadResult.output);
          debugPrint(
              '[LiveMonitor] Parsed ${parsed.threads.length} threads from ${threadResult.output.length} chars');
          if (parsed.threads.isEmpty) {
            debugPrint(
                '[LiveMonitor] Raw output (first 300): ${threadResult.output.substring(0, threadResult.output.length.clamp(0, 300))}');
          }
        }
      } catch (e) {
        debugPrint('[LiveMonitor] Thread parse error: $e');
      }
      if (!state.isEnabled) return;

      if (!state.isEnabled) return;

      // Update thread histories
      final histories = Map<String, ThreadHistory>.from(state.threadHistories);
      final pollSec = _pollInterval.inMilliseconds / 1000.0;

      if (parsed != null) {
        final seenKeys = <String>{};
        for (final snapshot in parsed.threads) {
          final key = snapshot.name;
          seenKeys.add(key);
          final existing = histories[key];
          if (existing != null) {
            existing.update(snapshot, pollSec);
          } else {
            histories[key] = ThreadHistory(
              name: snapshot.name,
              maxStackUsed: snapshot.stackUsed,
              stackSize: snapshot.stackSize,
              currentStackUsed: snapshot.stackUsed,
              currentUsagePercent: snapshot.usagePercent,
              state: snapshot.state,
              priority: snapshot.priority,
              initialCycles: snapshot.totalCycles,
              firstSeenPoll: state.pollCount,
            );
          }
        }
        // Mark threads no longer reported as removed (keep their last state).
        for (final entry in histories.entries) {
          if (!seenKeys.contains(entry.key) && !entry.value.removed) {
            entry.value.removed = true;
            entry.value.removedAt = DateTime.now();
            entry.value.state = 'removed';
          }
        }
      }

      _consecutiveErrors = 0;
      state = state.copyWith(
        cpuFreq: cpuFreq,
        powerInfo: powerInfo,
        threadHistories: histories,
        schedulerCycles: parsed?.scheduler?.cyclesSinceLastCall,
        lastUpdate: DateTime.now(),
        error: null,
        pollCount: state.pollCount + 1,
      );
    } catch (e) {
      _consecutiveErrors++;
      if (state.isEnabled) {
        if (_consecutiveErrors >= _maxConsecutiveErrors) {
          debugPrint('[LiveMonitor] Too many consecutive errors ($_consecutiveErrors), stopping');
          stop();
          state = state.copyWith(error: 'Stopped: SMP connection failed repeatedly');
        } else {
          state = state.copyWith(error: e.toString());
        }
      }
    } finally {
      _polling = false;
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
