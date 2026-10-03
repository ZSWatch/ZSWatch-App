import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zswatch_app/providers/companion_runtime_providers.dart';
import 'package:zswatch_app/providers/notification_providers.dart';

void main() {
  test(
    'native selection prevents a Flutter media owner before plugin calls',
    () {
      final container = ProviderContainer(
        overrides: [nativeCompanionRuntimeProvider.overrideWithValue(true)],
      );
      addTearDown(container.dispose);
      expect(() => container.read(mediaServiceProvider), throwsStateError);
      expect(() => container.read(mediaControlProvider), throwsStateError);
    },
  );
}
