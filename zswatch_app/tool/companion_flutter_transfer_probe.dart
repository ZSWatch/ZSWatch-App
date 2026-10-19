// Physical transfer diagnostic using the production Flutter services and SDK.
// No voice-sync provider, AI backend, or watch deletion is invoked here.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mcumgr_flutter/mcumgr_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:zswatch_app/services/ble/ble_connection_service.dart';
import 'package:zswatch_app/services/filesystem/file_system_service.dart';
import 'package:zswatch_app/services/watch_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kDebugMode || !Platform.isAndroid) {
    throw StateError('This diagnostic requires a debug Android build');
  }
  runApp(const MaterialApp(home: _TransferProbe()));
}

class _TransferProbe extends StatefulWidget {
  const _TransferProbe();

  @override
  State<_TransferProbe> createState() => _TransferProbeState();
}

class _TransferProbeState extends State<_TransferProbe> {
  final messages = <String>[];
  bool started = false;

  void report(String message) {
    debugPrint('[FlutterTransferProbe] $message');
    if (mounted) setState(() => messages.add(message));
  }

  Future<void> runProbe() async {
    const address = String.fromEnvironment('HIL_WATCH_ADDRESS');
    const filenames = String.fromEnvironment('HIL_RECORDINGS');
    final ble = BleConnectionService();
    final watch = WatchService(ble);
    final results = <Map<String, Object?>>[];
    final summary = <String, Object?>{
      'scope': 'FLUTTER_SDK_FOREGROUND_TRANSFER_DIAGNOSTIC',
      'started_utc': DateTime.now().toUtc().toIso8601String(),
      'recordings': results,
      'integrity': 'REQUIRES_INDEPENDENT_USB_COMPARISON',
      'background_acceptance': 'NOT_RUN',
    };
    int? smpGeneration;
    Directory? output;
    try {
      if (!RegExp(r'^[0-9A-F]{2}(:[0-9A-F]{2}){5}$').hasMatch(address)) {
        throw ArgumentError('Explicit HIL_WATCH_ADDRESS is required');
      }
      final names = filenames.split(',');
      if (names.length > 4 ||
          names.any(
            (name) => !RegExp(r'^[A-Za-z0-9_-]{1,32}$').hasMatch(name),
          )) {
        throw ArgumentError('HIL_RECORDINGS must select one to four filenames');
      }
      final documents = await getApplicationDocumentsDirectory();
      output = Directory(
        '${documents.path}/companion-flutter-probe/'
        '${DateTime.now().microsecondsSinceEpoch}',
      );
      await output.create(recursive: true);
      summary['output_directory'] = output.path;
      report('Connecting with existing WatchService');
      // connectById can return before asynchronous protocol setup finishes.
      await watch.connectById(address).timeout(const Duration(seconds: 45));
      await ble.phaseStream
          .firstWhere((phase) => phase.canOperate)
          .timeout(const Duration(seconds: 45));
      smpGeneration = watch.connectionGeneration;
      await watch.enableSmp();
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!await watch.rediscoverServices()) {
        throw StateError('SMP service not available after enabling');
      }
      for (final name in names) {
        final result = <String, Object?>{'filename': name};
        results.add(result);
        final timer = Stopwatch()..start();
        var abortBatch = false;
        try {
          report('Downloading $name with mcumgr_flutter');
          final bytes = await FileSystemService()
              .downloadFile('/user/recordings/$name.zsw_opus', address, (_) {})
              .timeout(const Duration(seconds: 60));
          final file = File('${output.path}/$name.zsw_opus');
          await file.writeAsBytes(bytes, flush: true);
          result.addAll({
            'state': 'received_unverified',
            'size_bytes': bytes.length,
            'local_path': file.path,
          });
          report('$name: received ${bytes.length} bytes; USB check pending');
        } catch (error) {
          // A caller timeout does not complete the service's asynchronous cleanup.
          // Cancel through the existing wrapper and stop; never overlap the next file.
          abortBatch = error is TimeoutException;
          result.addAll({'state': 'failed', 'error': error.toString()});
          report('$name: failed: $error');
        } finally {
          result['elapsed_ms'] = timer.elapsedMilliseconds;
          await FsManager(address).kill();
        }
        if (abortBatch) break;
      }
    } catch (error) {
      summary['error'] = error.toString();
      report('Probe error: $error');
    } finally {
      try {
        if (smpGeneration != null) {
          await watch.disableSmpIfConnectionUnchanged(smpGeneration);
        }
      } catch (error) {
        summary['cleanup_error'] = error.toString();
      }
      await watch.disconnect();
      await watch.dispose();
      await ble.dispose();
      summary['finished_utc'] = DateTime.now().toUtc().toIso8601String();
      if (output != null) {
        await File('${output.path}/result.json').writeAsString(
          const JsonEncoder.withIndent('  ').convert(summary),
          flush: true,
        );
        report('Result: ${output.path}/result.json');
      }
      report('Finished; no watch recording deleted or AI job started');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Flutter/Nordic transfer diagnostic')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilledButton(
            onPressed: started
                ? null
                : () {
                    setState(() => started = true);
                    unawaited(runProbe());
                  },
            child: const Text('Run foreground transfer diagnostic'),
          ),
          const SizedBox(height: 16),
          SelectableText(messages.join('\n')),
        ],
      ),
    ),
  );
}
