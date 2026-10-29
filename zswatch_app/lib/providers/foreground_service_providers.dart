import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/background/foreground_service.dart';

/// Platform diagnostics and system settings; the native companion owns its lifecycle.
final foregroundServiceProvider = Provider<ForegroundService>(
  (ref) => ForegroundService.instance,
);
