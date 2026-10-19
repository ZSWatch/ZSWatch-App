import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../data/models/voice_memo.dart';
import '../../../providers/companion_recording_import_providers.dart';
import '../../../providers/voice_memo_providers.dart';
import '../../../providers/demo_mode_provider.dart';
import '../../../services/voice_memo/retained_recording_playback.dart';
import '../../widgets/voice_memos/audio_playback_bar.dart';

final retainedVoiceMemosProvider = StreamProvider.autoDispose<List<VoiceMemo>>(
  (ref) => ref.watch(demoModeProvider)
      ? Stream.value([])
      : ref.watch(voiceMemoRepositoryProvider).watchAllMemos(),
);

/// Access existing rows directly; no filename adoption, BLE or inference owner.
class RetainedVoiceMemosView extends ConsumerStatefulWidget {
  const RetainedVoiceMemosView({super.key});
  @override
  ConsumerState<RetainedVoiceMemosView> createState() => _RetainedState();
}

class _RetainedState extends ConsumerState<RetainedVoiceMemosView> {
  String query = '';
  bool archived = false;
  bool busy = false;

  Future<void> shareFile(File file) async {
    if (!mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    await Share.shareXFiles(
      [XFile(file.path)],
      sharePositionOrigin: box == null
          ? null
          : box.localToGlobal(Offset.zero) & box.size,
    );
  }

  Future<void> audio(VoiceMemo memo, {bool export = false}) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final playback = await prepareRetainedRecording(
        memo,
        await getApplicationDocumentsDirectory(),
        await getApplicationSupportDirectory(),
      );
      if (!mounted) return;
      if (export) {
        await ref
            .read(companionRecordingExporterProvider)
            .audioFile(
              playback.path,
              playback.hash,
              'recording_${memo.id}',
              shareFile,
            );
      } else {
        await showModalBottomSheet<void>(
          context: context,
          builder: (_) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: AudioPlaybackBar(filePath: playback.path),
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This earlier audio could not be opened. Its source is retained.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> exportText(VoiceMemo memo) async {
    try {
      await ref
          .read(companionRecordingExporterProvider)
          .text(
            'recording_${memo.id}',
            memo.transcription ?? '',
            memo.summary ?? '',
            shareFile,
          );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not export this saved note. The original is retained.',
            ),
          ),
        );
      }
    }
  }

  Future<void> details(VoiceMemo memo) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                memo.summary?.isNotEmpty == true
                    ? memo.summary!
                    : memo.filename,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (memo.transcription != null) ...[
                const SizedBox(height: 16),
                SelectableText(memo.transcription!),
                TextButton.icon(
                  onPressed: () => Clipboard.setData(
                    ClipboardData(text: memo.transcription!),
                  ),
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy transcript'),
                ),
                TextButton.icon(
                  onPressed: () => exportText(memo),
                  icon: const Icon(Icons.ios_share),
                  label: const Text('Export text'),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Earlier recordings')),
    body: ref
        .watch(retainedVoiceMemosProvider)
        .when(
          data: (all) {
            final items = all
                .where(
                  (memo) =>
                      memo.archived == archived &&
                      [
                        memo.filename,
                        memo.transcription ?? '',
                        memo.summary ?? '',
                      ].any((value) => value.toLowerCase().contains(query)),
                )
                .toList();
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Recordings saved by the earlier app. Your original files and saved notes are retained.',
                ),
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search earlier recordings',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) =>
                      setState(() => query = value.trim().toLowerCase()),
                ),
                SwitchListTile(
                  title: const Text('Archived'),
                  value: archived,
                  onChanged: (value) => setState(() => archived = value),
                ),
                if (items.isEmpty) const Text('No earlier recordings'),
                for (final memo in items)
                  ListTile(
                    key: ValueKey('retained:${memo.id}'),
                    title: Text(
                      memo.summary?.isNotEmpty == true
                          ? memo.summary!
                          : memo.filename,
                    ),
                    subtitle: Text(
                      '${memo.filename} • ${memo.formattedDuration}',
                    ),
                    onTap: () => details(memo),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Play earlier recording',
                          onPressed: busy || memo.localFilePath == null
                              ? null
                              : () => audio(memo),
                          icon: const Icon(Icons.play_arrow),
                        ),
                        IconButton(
                          tooltip: 'Export earlier audio',
                          onPressed: busy || memo.localFilePath == null
                              ? null
                              : () => audio(memo, export: true),
                          icon: const Icon(Icons.ios_share),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) =>
              const Center(child: Text('Earlier recordings are unavailable')),
        ),
  );
}
