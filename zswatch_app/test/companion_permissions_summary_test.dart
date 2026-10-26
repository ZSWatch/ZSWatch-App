import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:zswatch_app/core/theme/app_theme.dart';
import 'package:zswatch_app/providers/companion_runtime_providers.dart';
import 'package:zswatch_app/providers/companion_permission_setup_providers.dart';
import 'package:zswatch_app/providers/demo_mode_provider.dart';
import 'package:zswatch_app/ui/screens/settings/companion_permissions_summary.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter.baseflow.com/permissions/methods');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  const platforms = TargetPlatformVariant({
    TargetPlatform.android,
    TargetPlatform.iOS,
  });

  testWidgets(
    'foreground permission finishes before the background request starts',
    (tester) async {
      final requests = <int>[];
      final foreground = Completer<Map<int, int>>();
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'requestPermissions');
        final permission = (call.arguments as List).single as int;
        requests.add(permission);
        if (permission == Permission.locationWhenInUse.value) {
          return foreground.future;
        }
        return {
          Permission.locationAlways.value: PermissionStatus.granted.index,
        };
      });
      final container = ProviderContainer(
        overrides: [demoModeProvider.overrideWith((ref) => false)],
      );
      addTearDown(container.dispose);
      final pending = container.read(companionGpsPermissionsProvider)();
      await tester.pump();
      expect(requests, [Permission.locationWhenInUse.value]);
      foreground.complete({
        Permission.locationWhenInUse.value: PermissionStatus.granted.index,
      });
      await pending;
      expect(requests, [
        Permission.locationWhenInUse.value,
        Permission.locationAlways.value,
      ]);
    },
    variant: platforms,
  );

  testWidgets(
    'one guided location row becomes green only after background access',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final status = {
        'bluetooth': true,
        'notifications': true,
        'notification_access': true,
        'location': true,
        'background_location': false,
        'battery_exemption': true,
      };
      var requests = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            companionPermissionsStatusProvider.overrideWith(
              (ref) async => status,
            ),
            companionGpsPermissionsProvider.overrideWithValue(() async {
              requests++;
              status['background_location'] = true;
            }),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: CompanionPermissionsSummary(initiallyExpanded: true),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final location = find.widgetWithText(ListTile, 'Location');
      final allow = find.descendant(
        of: location,
        matching: find.widgetWithText(FilledButton, 'Allow'),
      );
      expect(location, findsOneWidget);
      expect(find.text('Background location'), findsNothing);
      expect(find.textContaining('While using app only'), findsOneWidget);
      expect(allow, findsOneWidget);
      await tester.tap(location);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('First choose'), findsNothing);
      await tester.tap(allow);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('First choose'), findsOneWidget);
      expect(
        find.textContaining('even when the app is closed'),
        findsOneWidget,
      );
      expect(requests, 0);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(requests, 0);
      await tester.tap(allow);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(requests, 1);
      expect(allow, findsNothing);
      final icon = tester.widget<Icon>(
        find.descendant(of: location, matching: find.byType(Icon)),
      );
      expect(icon.icon, Icons.check_circle);
      expect(icon.color, AppTheme.successColor);
      expect(
        find.textContaining('ZSWatch collects location data'),
        findsOneWidget,
      );
      if (defaultTargetPlatform == TargetPlatform.android) {
        expect(find.text('5 of 5 granted'), findsOneWidget);
      }
    },
    variant: platforms,
  );
}
