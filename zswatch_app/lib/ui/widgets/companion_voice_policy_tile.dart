import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/ai_providers.dart';
import '../../providers/companion_runtime_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/voice_memo_providers.dart';
import '../../services/ai/llm_service.dart';
import '../navigation/app_router.dart';

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
    final stt = ref.read(transcriptionEngineTypeProvider);
    final llm = ref.read(selectedAiModelIdProvider);
    final correct = ref.read(aiCorrectionEnabledProvider);
    final analyzeEnabled =
        LlmService.localModelsSupported &&
        (analyze ??
            (snapshot?.fields['voice_processing_policy'] is Map
                ? (snapshot!.fields['voice_processing_policy']
                          as Map)['analysis_enabled'] !=
                      false
                : true));
    setState(() => _saving = true);
    try {
      if (enabled) {
        final speech = await ref.read(
          transcriptionModelStatusProvider(stt).future,
        );
        final missing = !speech.downloaded
            ? 'Download the selected speech model before enabling automatic processing.'
            : analyzeEnabled &&
                  !await ref.read(llmModelDownloadedProvider.future)
            ? 'Download the selected analysis model before enabling automatic processing.'
            : null;
        if (!mounted) return;
        if (missing != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(missing),
              // A SnackBar with an action stays until dismissed by default and
              // then covers e.g. the firmware update buttons on other screens.
              persist: false,
              action: SnackBarAction(
                label: 'Download models',
                onPressed: () => context.push(AppRoutes.aiModels),
              ),
            ),
          );
          return;
        }
      }
      await ref
          .read(companionClientProvider)
          .configureVoiceProcessing(
            watchId: watch.id,
            enabled: enabled,
            transcriptionModel: stt.name,
            analysisModel: llm,
            correctTranscription: correct,
            analyze: analyzeEnabled,
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
          subtitle: Text(
            '${LlmService.localModelsSupported ? 'Uses the selected local models' : 'Transcribes with the selected speech model'}. '
            'Audio stays on this phone. '
            'Existing recordings are processed manually. Turning this off '
            'leaves already queued jobs running.',
          ),
          value: enabled,
          onChanged: !_saving && (enabled || canSave) ? _save : null,
        ),
        if (LlmService.localModelsSupported)
          SwitchListTile(
            title: const Text('Analyze after transcription'),
            subtitle: const Text(
              'Turn off to automatically transcribe without an LLM.',
            ),
            value: policy['analysis_enabled'] != false,
            onChanged: canSave
                ? (value) => _save(enabled, analyze: value)
                : null,
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
