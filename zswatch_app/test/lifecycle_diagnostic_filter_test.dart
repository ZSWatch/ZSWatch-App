import 'package:flutter_test/flutter_test.dart';
import 'package:zswatch_app/core/utils/lifecycle_logger.dart';

void main() {
  test(
    'Analytics retains native companion recovery and persistence diagnostics',
    () {
      for (final message in [
        'service_created pid=123',
        'task_removed runtimeOwnedByService=true',
        'service_start action=null',
        'telemetry_persistence_failed SQLiteException',
      ]) {
        expect(
          LifecycleLogger.shouldPersistDiagnostic(
            'CompanionPrototype',
            message,
          ),
          isTrue,
        );
      }
      expect(
        LifecycleLogger.shouldPersistDiagnostic(
          'StartupCause',
          'package replaced',
        ),
        isTrue,
      );
      expect(
        LifecycleLogger.shouldPersistDiagnostic(
          'WatchService',
          'high frequency packet',
        ),
        isFalse,
      );
    },
  );
}
