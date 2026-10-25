import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/ai_providers.dart';
import '../../providers/companion_runtime_providers.dart';
import '../../providers/openrouter_providers.dart';
import '../../providers/voice_memo_providers.dart';
import '../../services/voice_memo/transcription_engine.dart';
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
    if (snapshot == null) return;
    final watch = snapshot.watch;
    final config = ref.read(voiceModelConfigProvider);
    final analyzeEnabled =
        config.canAnalyze &&
        (analyze ??
            (snapshot.fields['voice_processing_policy'] is Map
                ? (snapshot.fields['voice_processing_policy']
                          as Map)['analysis_enabled'] !=
                      false
                : true));
    setState(() => _saving = true);
    try {
      if (enabled && config.cloud) {
        final key = await ref.read(companionClientProvider).cloudCredential();
        if (!mounted) return;
        if (key == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Add an OpenRouter key before enabling automatic processing.',
              ),
              persist: false,
              action: SnackBarAction(
                label: 'Add key',
                onPressed: () => context.push(AppRoutes.aiModels),
              ),
            ),
          );
          return;
        }
      } else if (enabled) {
        final speech = await ref.read(
          transcriptionModelStatusProvider(
            TranscriptionEngineType.values.byName(config.transcriptionModel),
          ).future,
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
            watchId: watch?.id ?? '',
            enabled: enabled,
            transcriptionModel: config.transcriptionModel,
            analysisModel: config.analysisModel,
            correctTranscription: config.correctTranscription,
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
        policy['enabled'] == true &&
        policy['watch_id'] == (snapshot?.watch?.id ?? '');
    final config = ref.watch(voiceModelConfigProvider);
    final changed =
        policy['transcription_model'] != config.transcriptionModel ||
        policy['analysis_model'] != config.analysisModel ||
        policy['correct_transcription'] != config.correctTranscription;
    final canSave = !_saving && snapshot != null;
    return Column(
      children: [
        SwitchListTile(
          title: const Text('Automatically process new recordings'),
          subtitle: Text(
            '${config.cloud ? 'Sends each new recording to OpenRouter with zero data retention, right after it arrives.' : '${config.canAnalyze ? 'Uses the selected local models' : 'Transcribes with the selected speech model'}. Audio stays on this phone.'} '
            '${snapshot?.watch == null ? 'Your choice is saved for when you connect your watch. ' : ''}'
            'Existing recordings are processed manually. Turning this off '
            'leaves already queued jobs running.',
          ),
          value: enabled,
          onChanged: !_saving && (enabled || canSave) ? _save : null,
        ),
        if (config.canAnalyze)
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
