import 'dart:math' as math;

/// Parsed snapshot of a single Zephyr thread from `kernel thread list`.
class ThreadSnapshot {
  final String address;
  final String name;
  final String state;
  final int priority;
  final int totalCycles;
  final int stackSize;
  final int stackUsed;
  final int stackUnused;
  final int usagePercent;

  const ThreadSnapshot({
    required this.address,
    required this.name,
    required this.state,
    required this.priority,
    required this.totalCycles,
    required this.stackSize,
    required this.stackUsed,
    required this.stackUnused,
    required this.usagePercent,
  });
}

/// Per-thread tracked data across monitoring session.
class ThreadHistory {
  final String name;
  int maxStackUsed;
  int stackSize;
  int currentStackUsed;
  int currentUsagePercent;
  String state;
  int priority;

  /// Execution cycles from previous poll (for delta computation).
  int _prevCycles;

  /// Cycles/s history (one entry per poll).
  final List<double> cyclesPerSecHistory;

  /// The global poll index when this thread was first seen.
  final int firstSeenPoll;

  /// Whether the thread has disappeared from the shell output.
  bool removed = false;

  /// Timestamp when the thread was first marked as removed.
  DateTime? removedAt;

  /// Max number of history entries to keep.
  static const int maxHistory = 60;

  ThreadHistory({
    required this.name,
    required this.maxStackUsed,
    required this.stackSize,
    required this.currentStackUsed,
    required this.currentUsagePercent,
    required this.state,
    required this.priority,
    required int initialCycles,
    required this.firstSeenPoll,
  })  : _prevCycles = initialCycles,
        cyclesPerSecHistory = [];

  void update(ThreadSnapshot snapshot, double pollIntervalSec) {
    // Thread reappeared — clear removed status.
    if (removed) {
      removed = false;
      removedAt = null;
    }
    currentStackUsed = snapshot.stackUsed;
    currentUsagePercent = snapshot.usagePercent;
    stackSize = snapshot.stackSize;
    state = snapshot.state;
    priority = snapshot.priority;
    maxStackUsed = math.max(maxStackUsed, snapshot.stackUsed);

    final deltaCycles = snapshot.totalCycles - _prevCycles;
    _prevCycles = snapshot.totalCycles;

    final cps = (pollIntervalSec > 0 && deltaCycles >= 0) ? deltaCycles / pollIntervalSec : 0.0;
    cyclesPerSecHistory.add(cps);
    if (cyclesPerSecHistory.length > maxHistory) {
      cyclesPerSecHistory.removeAt(0);
    }
  }
}

/// Global scheduler cycles from the header line.
class SchedulerInfo {
  final int cyclesSinceLastCall;
  const SchedulerInfo({required this.cyclesSinceLastCall});
}

/// Result of parsing a full `kernel thread list` output.
class ThreadListParseResult {
  final SchedulerInfo? scheduler;
  final List<ThreadSnapshot> threads;
  const ThreadListParseResult({this.scheduler, required this.threads});
}

/// Parses the output of `kernel thread list`.
ThreadListParseResult parseThreadList(String output) {
  // Strip \r and split — SMP transport may use \r\n line endings.
  final lines = output.replaceAll('\r', '').split('\n');
  SchedulerInfo? scheduler;
  final threads = <ThreadSnapshot>[];

  // Parse scheduler line: "Scheduler: 10189 since last call"
  final schedRegex = RegExp(r'Scheduler:\s+(\d+)\s+since last call');

  int i = 0;
  while (i < lines.length) {
    final line = lines[i];

    final schedMatch = schedRegex.firstMatch(line);
    if (schedMatch != null) {
      scheduler = SchedulerInfo(
        cyclesSinceLastCall: int.parse(schedMatch.group(1)!),
      );
      i++;
      continue;
    }

    // Thread header line starts with optional '*' then hex address
    // e.g. " 0x20009488 mbox_wq #0" or "*0x2000b198 mcumgr smp"
    // Allow address with or without '0x' prefix.
    final headerRegex = RegExp(r'^\s*\*?((?:0x)?[0-9a-fA-F]{4,})\s+(.+)$');
    final headerMatch = headerRegex.firstMatch(line);
    if (headerMatch != null) {
      final address = headerMatch.group(1)!;
      final name = headerMatch.group(2)!.trim();

      // Parse following indented lines for this thread
      String state = '';
      int priority = 0;
      int totalCycles = 0;
      int stackSize = 0;
      int stackUsed = 0;
      int stackUnused = 0;
      int usagePercent = 0;

      i++;
      while (i < lines.length) {
        final sub = lines[i];
        if (sub.trim().isEmpty) {
          i++;
          continue;
        }
        // Stop if we hit the next thread header or non-indented line
        if (!sub.startsWith('\t') && !sub.startsWith('  ')) break;

        // "options: 0x0, priority: 7 timeout: 0"
        final prioMatch = RegExp(r'priority:\s*(-?\d+)').firstMatch(sub);
        if (prioMatch != null) {
          priority = int.parse(prioMatch.group(1)!);
        }

        // "state: pending, entry: 0x786d1"
        final stateMatch = RegExp(r'state:\s*(\w+)').firstMatch(sub);
        if (stateMatch != null) {
          state = stateMatch.group(1)!;
        }

        // "Total execution cycles: 4810 (0 %)"
        final cyclesMatch =
            RegExp(r'Total execution cycles:\s*(\d+)').firstMatch(sub);
        if (cyclesMatch != null) {
          totalCycles = int.parse(cyclesMatch.group(1)!);
        }

        // "stack size 1024, unused 576, usage 448 / 1024 (43 %)"
        final stackMatch = RegExp(
                r'stack size\s+(\d+),\s*unused\s+(\d+),\s*usage\s+(\d+)\s*/\s*\d+\s*\((\d+)\s*%\)')
            .firstMatch(sub);
        if (stackMatch != null) {
          stackSize = int.parse(stackMatch.group(1)!);
          stackUnused = int.parse(stackMatch.group(2)!);
          stackUsed = int.parse(stackMatch.group(3)!);
          usagePercent = int.parse(stackMatch.group(4)!);
        }

        i++;
      }

      threads.add(ThreadSnapshot(
        address: address,
        name: name,
        state: state,
        priority: priority,
        totalCycles: totalCycles,
        stackSize: stackSize,
        stackUsed: stackUsed,
        stackUnused: stackUnused,
        usagePercent: usagePercent,
      ));
      continue;
    }

    i++;
  }

  return ThreadListParseResult(scheduler: scheduler, threads: threads);
}

/// Parse CPU freq output like "CPU frequency profile: fast"
String? parseCpuFreq(String output) {
  final match = RegExp(r'CPU frequency profile:\s*(\w+)').firstMatch(output);
  return match?.group(1);
}

/// Parsed power status.
class PowerInfo {
  final String state;
  final int timeToSleepSec;
  final int uptimeSec;

  const PowerInfo({
    required this.state,
    required this.timeToSleepSec,
    required this.uptimeSec,
  });
}

/// Parse power status output.
PowerInfo? parsePowerStatus(String output) {
  final stateMatch = RegExp(r'State:\s*(.+)').firstMatch(output);
  final sleepMatch = RegExp(r'Time to sleep:\s*(\d+)\s*seconds').firstMatch(output);
  final uptimeMatch = RegExp(r'Total uptime:\s*(\d+)\s*seconds').firstMatch(output);

  if (stateMatch == null) return null;

  return PowerInfo(
    state: stateMatch.group(1)!.trim(),
    timeToSleepSec: sleepMatch != null ? int.parse(sleepMatch.group(1)!) : 0,
    uptimeSec: uptimeMatch != null ? int.parse(uptimeMatch.group(1)!) : 0,
  );
}
