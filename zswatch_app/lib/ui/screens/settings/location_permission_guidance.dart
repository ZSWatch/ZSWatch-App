import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// One explanation for the foreground request followed by the Always upgrade.
Future<bool?> showLocationPermissionGuidance(
  BuildContext context,
) => showDialog<bool>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Share location with your watch?'),
    content: Text(
      defaultTargetPlatform == TargetPlatform.iOS
          ? 'Watch weather and GPS need location access while the app is closed. '
                'First choose Allow While Using App, then choose Change to Always '
                'when iOS asks. If the second prompt does not appear, open '
                'Settings → ZSWatch → Location and choose Always. '
                'Enable Precise Location for GPS. Granting access turns sharing on. You can turn it off in the app.'
          : 'Watch weather and GPS need location access while the app is closed. '
                'First choose While using the app. We will then open the next '
                'Android permission step: choose Allow all the time. '
                'If Android opens app settings, go to Permissions → Location '
                'and choose Allow all the time. Granting access turns sharing on. You can turn it off in the app.',
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, true),
        child: const Text('Continue'),
      ),
    ],
  ),
);
