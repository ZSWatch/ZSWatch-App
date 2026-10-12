import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/companion_runtime_providers.dart';
import '../../providers/settings_providers.dart';

/// Explicit opt-in. Saving preferences never starts inference in this isolate.
class CompanionVoicePolicyTile extends ConsumerStatefulWidget {
  const CompanionVoicePolicyTile({super.key});

  @override
  ConsumerState<CompanionVoicePolicyTile> createState() => _VoicePolicyState();
}

class _VoicePolicyState extends ConsumerState<CompanionVoicePolicyTile> {
  bool _saving = false;

  Future<void> _save(bool enabled, {bool? analyze}) async {
    final snapshot = ref.read(companionSnapshotProvider).asData?.value;
    final watch = snapshot?.watch;
    if (watch == null) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(companionClientProvider)
          .configureVoiceProcessing(
            watchId: watch.id,
            enabled: enabled,
            transcriptionModel: ref.read(transcriptionEngineTypeProvider).name,
            analysisModel: ref.read(selectedAiModelIdProvider),
            correctTranscription: ref.read(aiCorrectionEnabledProvider),
            analyze:
                analyze ??
                (snapshot?.fields['voice_processing_policy'] is Map
                    ? (snapshot!.fields['voice_processing_policy']
                              as Map)['analysis_enabled'] !=
                          false
                    : true),
          );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save automatic processing: $error'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(companionSnapshotProvider).asData?.value;
    final raw = snapshot?.fields['voice_processing_policy'];
    final policy = raw is Map ? raw : const <Object?, Object?>{};
    final enabled =
        policy['enabled'] == true && policy['watch_id'] == snapshot?.watch?.id;
    final changed =
        policy['transcription_model'] !=
            ref.watch(transcriptionEngineTypeProvider).name ||
        policy['analysis_model'] != ref.watch(selectedAiModelIdProvider) ||
        policy['correct_transcription'] !=
            ref.watch(aiCorrectionEnabledProvider);
    final canSave =
        !_saving &&
        snapshot?.watch != null &&
        snapshot?.fields['desired_running'] == true;
    return Column(
      children: [
        SwitchListTile(
          title: const Text('Automatically process new recordings'),
          subtitle: const Text(
            'Uses the selected local models. Audio stays on this phone. '
            'Existing recordings are processed manually. Turning this off '
            'leaves already queued jobs running.',
          ),
          value: enabled,
          onChanged: !_saving && (enabled || canSave) ? _save : null,
        ),
        SwitchListTile(
          title: const Text('Analyze after transcription'),
          subtitle: const Text(
            'Turn off to automatically transcribe without an LLM.',
          ),
          value: policy['analysis_enabled'] != false,
          onChanged: canSave ? (value) => _save(enabled, analyze: value) : null,
        ),
        if (enabled && changed)
          ListTile(
            title: const Text('Model selection has changed'),
            subtitle: const Text('Apply these models to future recordings.'),
            trailing: TextButton(
              onPressed: canSave ? () => _save(true) : null,
              child: const Text('Apply'),
            ),
          ),
      ],
    );
  }
}
