import 'dart:async';
import 'dart:io' show Platform, pid;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class LifecycleLogEntry {
  final DateTime timestamp;
  final int uptimeMs;
  final int pid;
  final String origin;
  final String source;
  final String message;

  const LifecycleLogEntry({
    required this.timestamp,
    required this.uptimeMs,
    required this.pid,
    required this.origin,
    required this.source,
    required this.message,
  });

  factory LifecycleLogEntry.fromMap(Map<Object?, Object?> map) {
    final timestampMillis = (map['timestampMillis'] as num?)?.toInt();
    return LifecycleLogEntry(
      timestamp: timestampMillis != null
          ? DateTime.fromMillisecondsSinceEpoch(timestampMillis)
          : DateTime.now(),
      uptimeMs: (map['uptimeMs'] as num?)?.toInt() ?? 0,
      pid: (map['pid'] as num?)?.toInt() ?? 0,
      origin: map['origin'] as String? ?? 'unknown',
      source: map['source'] as String? ?? 'unknown',
      message: map['message'] as String? ?? '',
    );
  }
}

abstract final class LifecycleLogger {
  static const _channel = MethodChannel('dev.zswatch.app/foreground_service');

  static void log(String source, String message) {
    final now = DateTime.now();
    debugPrint(
      '[ZSWLifecycle][$source][pid=$pid][${now.toIso8601String()}] $message',
    );

    if (!Platform.isAndroid) return;
    if (!shouldPersistDiagnostic(source, message)) return;

    unawaited(
      _channel
          .invokeMethod<bool>('recordLifecycleEvent', {
            'source': source,
            'message': message,
            'timestampMillis': now.millisecondsSinceEpoch,
            'pid': pid,
          })
          .catchError((Object error) => false),
    );
  }

  static bool shouldPersistDiagnostic(String source, String message) {
    final lowerSource = source.toLowerCase();
    final lowerMessage = message.toLowerCase();

    if (lowerSource == 'processexitreason') return true;
    if (lowerSource == 'applifecycle' || lowerSource == 'mainactivity') {
      return true;
    }
    if (lowerSource == 'bootreceiver') return true;
    if (lowerSource.contains('notificationservice')) {
      return lowerMessage.contains('oncreate') ||
          lowerMessage.contains('ondestroy') ||
          lowerMessage.contains('listenerconnected') ||
          lowerMessage.contains('listenerdisconnected');
    }
    if (lowerSource == 'bleconnectionservice') {
      return lowerMessage.contains('oncreate') ||
          lowerMessage.contains('ondestroy') ||
          lowerMessage.contains('ontaskremoved') ||
          lowerMessage.contains('start requested') ||
          lowerMessage.contains('stop requested') ||
          lowerMessage.contains('startforeground') ||
          lowerMessage.contains('stopforeground') ||
          lowerMessage.contains('action=dev.zswatch.app.start_foreground') ||
          lowerMessage.contains('action=dev.zswatch.app.stop_foreground');
    }
    if (lowerSource == 'foregroundservice') {
      return lowerMessage.contains('created') ||
          lowerMessage.contains('startforeground') ||
          lowerMessage.contains('stop');
    }

    return lowerMessage.contains('oncreate') ||
        lowerMessage.contains('ondestroy') ||
        lowerMessage.contains('ontaskremoved') ||
        lowerMessage.contains('boot_completed') ||
        lowerMessage.contains('my_package_replaced') ||
        lowerMessage.contains('force stop');
  }
}
