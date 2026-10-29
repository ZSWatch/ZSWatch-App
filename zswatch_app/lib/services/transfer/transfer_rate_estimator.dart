/// Display-only measurements from acknowledged byte progress. The first offset
/// is a baseline: resumed bytes must never count as newly transferred data.
class TransferRate {
  final int bytesPerSecond;
  final List<int> history;
  const TransferRate({this.bytesPerSecond = 0, this.history = const []});
}

class TransferRateEstimator {
  static const _window = Duration(seconds: 5);
  static const _historyLimit = 60;
  final List<({Duration time, int bytes})> _samples = [];
  final List<int> _history = [];
  String? _scope;
  int _total = 0;
  Duration? _historyAt;

  void reset() {
    _scope = null;
    _samples.clear();
    _history.clear();
    _historyAt = null;
  }

  TransferRate sample({
    required String scope,
    required int current,
    required int total,
    required Duration now,
  }) {
    if (_scope != scope ||
        _total != total ||
        (_samples.isNotEmpty &&
            (current < _samples.last.bytes || now < _samples.last.time))) {
      reset();
      _scope = scope;
      _total = total;
    }
    if (_samples.isEmpty) {
      _samples.add((time: now, bytes: current));
      _historyAt = now;
      return const TransferRate();
    }
    if (now > _samples.last.time) {
      _samples.add((time: now, bytes: current));
    } else {
      _samples[_samples.length - 1] = (time: now, bytes: current);
    }
    // Keep an anchor at/before the window boundary, including while stalled.
    while (_samples.length > 2 && _samples[1].time <= now - _window) {
      _samples.removeAt(0);
    }
    final elapsed = now - _samples.first.time;
    final delta = current - _samples.first.bytes;
    final speed = elapsed.inMicroseconds <= 0
        ? 0
        : (delta * Duration.microsecondsPerSecond / elapsed.inMicroseconds)
              .round();
    if (now - _historyAt! >= const Duration(seconds: 1)) {
      _historyAt = now;
      _history.add(speed);
      if (_history.length > _historyLimit) _history.removeAt(0);
    }
    return TransferRate(
      bytesPerSecond: speed,
      history: List.unmodifiable(_history),
    );
  }
}
