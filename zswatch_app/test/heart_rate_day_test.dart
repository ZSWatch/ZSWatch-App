import 'package:flutter_test/flutter_test.dart';
import 'package:zswatch_app/data/models/health_sample.dart';
import 'package:zswatch_app/providers/health_providers.dart';

HealthSample _hr(DateTime at, int bpm) =>
    HealthSample.heartRate(watchId: 'w', bpm: bpm, timestamp: at);

void main() {
  final day = DateTime(2026, 11, 24);

  test('averages readings per bucket and leaves gaps empty', () {
    final buckets = bucketHeartRate([
      _hr(DateTime(2026, 11, 24, 0, 1), 60),
      _hr(DateTime(2026, 11, 24, 0, 4), 80),
      _hr(DateTime(2026, 11, 24, 23, 59), 100),
    ], day);
    expect(buckets.length, 288);
    expect(buckets.first, 70);
    expect(buckets[1], isNull);
    expect(buckets.last, 100);
  });

  test('ignores readings from other days', () {
    final buckets = bucketHeartRate([
      _hr(DateTime(2026, 11, 23, 23, 59), 60),
      _hr(DateTime(2026, 11, 25, 0, 0), 60),
    ], day);
    expect(buckets.whereType<double>(), isEmpty);
  });
}
