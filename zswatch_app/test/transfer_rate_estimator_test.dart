import 'package:flutter_test/flutter_test.dart';
import 'package:zswatch_app/data/models/dfu_state.dart';
import 'package:zswatch_app/data/models/filesystem_image.dart';
import 'package:zswatch_app/services/transfer/transfer_rate_estimator.dart';

void main() {
  test('measures confirmed byte deltas without counting a resumed offset', () {
    final estimator = TransferRateEstimator();
    TransferRate sample(
      int seconds,
      int bytes, {
      String scope = 'image',
      int total = 10000,
    }) => estimator.sample(
      scope: scope,
      current: bytes,
      total: total,
      now: Duration(seconds: seconds),
    );
    expect(sample(0, 4000).bytesPerSecond, 0);
    final rate = sample(1, 5000);
    expect(rate.bytesPerSecond, 1000);
    expect(rate.history, [1000]);
    expect(sample(2, 6000).history, [1000, 1000]);
    // A same-sized second image resets its counter and all speed samples.
    final secondImage = sample(3, 1000);
    expect(secondImage.bytesPerSecond, 0);
    expect(secondImage.history, isEmpty);
    expect(sample(4, 2000).bytesPerSecond, 1000);
    expect(sample(5, 5000, scope: 'verification').bytesPerSecond, 0);
    expect(sample(6, 6000, total: 12000).bytesPerSecond, 0);
    expect(sample(7, 7000, scope: 'retry').history, isEmpty);
  });

  test(
    'recent speed adapts, stalls decay to zero, and history stays bounded',
    () {
      final estimator = TransferRateEstimator();
      TransferRate sample(int seconds, int bytes) => estimator.sample(
        scope: 'upload',
        current: bytes,
        total: 1000000,
        now: Duration(seconds: seconds),
      );
      sample(0, 0);
      for (var second = 1; second <= 5; second++) {
        expect(sample(second, second * 1000).bytesPerSecond, 1000);
      }
      expect(sample(6, 5000).bytesPerSecond, 800);
      expect(sample(10, 5000).bytesPerSecond, 0);
      for (var second = 11; second <= 100; second++) {
        final rate = sample(second, 5000);
        expect(rate.bytesPerSecond, 0);
        expect(rate.history.length, lessThanOrEqualTo(60));
      }
      expect(sample(101, 5000).history, hasLength(60));
      estimator.reset();
      expect(sample(102, 500000).history, isEmpty);
      expect(sample(103, 501000).bytesPerSecond, 1000);
    },
  );

  test('ETA distinguishes startup, a stall, and completed bytes', () {
    const dfu = DfuState(
      status: DfuStatus.uploading,
      totalBytes: 10000,
      bytesTransferred: 1000,
    );
    const fs = FilesystemUploadState(
      status: FilesystemUploadStatus.uploading,
      totalBytes: 10000,
      bytesTransferred: 1000,
    );
    expect(dfu.formattedTimeRemaining, 'calculating...');
    expect(fs.formattedTimeRemaining, 'calculating...');
    expect(dfu.copyWith(speedHistory: [0]).formattedSpeed, '0 B/s');
    expect(
      dfu.copyWith(speedHistory: [0]).formattedTimeRemaining,
      'Waiting for data',
    );
    expect(
      fs.copyWith(speedHistory: [0]).formattedTimeRemaining,
      'Waiting for data',
    );
    expect(
      dfu.copyWith(speedBytesPerSecond: 1000).formattedTimeRemaining,
      '9 sec',
    );
    expect(fs.copyWith(speedBytesPerSecond: 1000).formattedTimeRemaining, '9s');
    expect(
      dfu
          .copyWith(bytesTransferred: 9999, speedBytesPerSecond: 1000)
          .estimatedSecondsRemaining,
      1,
    );
    expect(
      fs
          .copyWith(bytesTransferred: 9999, speedBytesPerSecond: 1000)
          .formattedTimeRemaining,
      '1s',
    );
    expect(
      dfu.copyWith(bytesTransferred: 10000).formattedTimeRemaining,
      '0 sec',
    );
    expect(fs.copyWith(bytesTransferred: 10000).formattedTimeRemaining, '0s');
  });
}
