import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../providers/ai_providers.dart';
import '../../../providers/settings_providers.dart';
import '../../../providers/voice_memo_providers.dart';
import '../../../services/ai/extracted_action_creation_service.dart';
import '../../../services/ai/llm_service.dart';
import '../../../services/ai/model_benchmark_service.dart';
import '../../../services/voice_memo/transcription_engine.dart';
import '../../../services/voice_memo/whisper_lifecycle_manager.dart';
import '../../widgets/ai_debug_widgets.dart';

// ---------------------------------------------------------------------------
// Benchmark provider (screen-scoped singleton)
// ---------------------------------------------------------------------------

final _benchmarkServiceProvider = Provider.autoDispose<ModelBenchmarkService>((ref) {
  final service = ModelBenchmarkService();
  ref.onDispose(() => service.dispose());
  return service;
});

final _benchmarkStateProvider = StreamProvider.autoDispose<BenchmarkState>((ref) {
  return ref.watch(_benchmarkServiceProvider).stateStream;
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

/// Unified settings page for both Transcription and AI Processing models.
///
/// Replaces the separate Voice Memos / AI Processing sections that were
/// previously inline in the main Settings screen.
class AiModelsSettingsScreen extends ConsumerWidget {
  const AiModelsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Voice Memo AI')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          // ---- Transcription section ----
          const _SectionHeader(
            title: 'Transcription Model',
            subtitle: 'Speech-to-text engine used for voice memos',
          ),
          const _TranscriptionModelSelector(),
          const _RetranscribeButton(),

          const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // ---- AI Processing section ----
          const _SectionHeader(
            title: 'AI Processing Model',
            subtitle: 'Local LLM for summarisation & classification',
          ),
          const _AiTogglesTile(),
          const _AiModelSelector(),
          const _ImportModelTile(),

          // ---- GPU / Metal section (iOS only) ----
          if (Platform.isIOS) ...[
            const SizedBox(height: 24),
            const Divider(height: 1),
            const SizedBox(height: 8),
            const _SectionHeader(
              title: 'GPU Acceleration (Metal)',
              subtitle: 'Controls Metal GPU for transcription & LLM inference',
            ),
            const _GpuModeTile(),
          ],

          if (ref.watch(localAiEnabledProvider)) ...[
            const SizedBox(height: 24),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // ---- Calendar / Reminders section ----
            const _SectionHeader(
              title: 'Calendar Integration',
              subtitle: 'When a voice memo mentions a meeting, deadline, or '
                  'reminder, the AI can create it directly in your calendar. '
                  'Grant access below to enable this.',
            ),
            const _CalendarPermissionTile(),
            if (Platform.isIOS) const _RemindersPermissionTile(),
            if (Platform.isAndroid) const _CalendarPickerTile(),
          ],

          const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // ---- Benchmark section ----
          const _SectionHeader(
            title: 'Model Benchmark',
            subtitle: 'Test model performance on your device',
          ),
          const _BenchmarkSection(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Common helpers
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingMd,
        AppTheme.spacingMd,
        AppTheme.spacingMd,
        4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

String _formatBytes(int bytes) {
  const kb = 1024;
  const mb = kb * 1024;
  const gb = mb * 1024;
  if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(2)} GB';
  if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(0)} MB';
  if (bytes >= kb) return '${(bytes / kb).toStringAsFixed(0)} KB';
  return '$bytes B';
}

// ---------------------------------------------------------------------------
// Transcription model selector (dropdown + download/delete)
// ---------------------------------------------------------------------------

class _TranscriptionModelSelector extends ConsumerStatefulWidget {
  const _TranscriptionModelSelector();

  @override
  ConsumerState<_TranscriptionModelSelector> createState() =>
      _TranscriptionModelSelectorState();
}

class _TranscriptionModelSelectorState
    extends ConsumerState<_TranscriptionModelSelector> {
  bool _isDownloading = false;
  double _downloadProgress = 0;

  Future<void> _downloadModel(TranscriptionEngineType type) async {
    final info = TranscriptionModelCatalog.info(type);
    final engine = createTranscriptionEngine(type);
    StreamSubscription<TranscriptionEngineState>? sub;

    try {
      setState(() {
        _isDownloading = true;
        _downloadProgress = 0;
      });

      sub = engine.stateStream.listen((state) {
        if (!mounted) return;
        if (state.status == TranscriptionEngineStatus.downloading) {
          setState(() => _downloadProgress = state.downloadProgress);
        }
      });

      await engine.initialize();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Downloaded ${info.name}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    } finally {
      await sub?.cancel();
      if (mounted) setState(() => _isDownloading = false);
      engine.dispose();
      _invalidateTranscription();
    }
  }

  Future<void> _deleteModel(TranscriptionEngineType type) async {
    final info = TranscriptionModelCatalog.info(type);
    final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete model?'),
            content: Text('Delete ${info.name} from local storage?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldDelete) return;

    final engine = createTranscriptionEngine(type);
    try {
      await engine.deleteModel();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted ${info.name}')),
        );
      }
    } finally {
      engine.dispose();
      _invalidateTranscription();
    }
  }

  void _invalidateTranscription() {
    for (final type in TranscriptionEngineType.values) {
      ref.invalidate(transcriptionModelStatusProvider(type));
    }
    ref.invalidate(transcriptionConfiguredProvider);
    ref.invalidate(transcriptionEngineProvider);
    ref.invalidate(transcriptionEngineStateProvider);
  }

  @override
  Widget build(BuildContext context) {
    final selectedType = ref.watch(transcriptionEngineTypeProvider);

    return Column(
      children: [
        // Dropdown selector
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacingMd,
            AppTheme.spacingSm,
            AppTheme.spacingMd,
            0,
          ),
          child: DropdownButtonFormField<TranscriptionEngineType>(
            value: selectedType,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Select model',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: TranscriptionModelCatalog.all.map((info) {
              return DropdownMenuItem<TranscriptionEngineType>(
                value: info.type,
                child: Text(info.name, overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: _isDownloading
                ? null
                : (value) {
                    if (value == null) return;
                    ref
                        .read(transcriptionEngineTypeProvider.notifier)
                        .setType(value);
                    _invalidateTranscription();
                  },
          ),
        ),

        // Selected model details card
        _TranscriptionModelCard(
          type: selectedType,
          isDownloading: _isDownloading,
          downloadProgress: _downloadProgress,
          onDownload: () => _downloadModel(selectedType),
          onDelete: () => _deleteModel(selectedType),
        ),
      ],
    );
  }
}

class _TranscriptionModelCard extends ConsumerWidget {
  final TranscriptionEngineType type;
  final bool isDownloading;
  final double downloadProgress;
  final VoidCallback onDownload;
  final VoidCallback onDelete;

  const _TranscriptionModelCard({
    required this.type,
    required this.isDownloading,
    required this.downloadProgress,
    required this.onDownload,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = TranscriptionModelCatalog.info(type);
    final statusAsync = ref.watch(transcriptionModelStatusProvider(type));

    return statusAsync.when(
      data: (status) {
        return Container(
          margin: const EdgeInsets.fromLTRB(
            AppTheme.spacingMd,
            AppTheme.spacingSm,
            AppTheme.spacingMd,
            0,
          ),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: status.downloaded
                ? AppTheme.successColor.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(
              color: status.downloaded
                  ? AppTheme.successColor.withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status row
              Row(
                children: [
                  Icon(
                    status.downloaded
                        ? Icons.check_circle
                        : Icons.cloud_download_outlined,
                    size: 18,
                    color: status.downloaded
                        ? AppTheme.successColor
                        : AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      status.downloaded ? 'Downloaded' : 'Not downloaded',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: status.downloaded
                                ? AppTheme.successColor
                                : AppTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Info rows
              _DetailRow(
                label: 'Language',
                value: info.language == 'auto'
                    ? 'Auto-detect'
                    : info.language.toUpperCase(),
              ),
              _DetailRow(
                label: 'Size',
                value: _formatBytes(info.expectedSizeBytes),
              ),
              if (status.localSizeBytes != null)
                _DetailRow(
                  label: 'Local',
                  value: _formatBytes(status.localSizeBytes!),
                ),
              _DetailRow(
                label: 'RAM needed',
                value: _ramEstimate(info.expectedSizeBytes),
              ),

              // Download progress
              if (isDownloading) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: downloadProgress > 0 ? downloadProgress : null,
                ),
                const SizedBox(height: 4),
                Text(
                  downloadProgress > 0
                      ? 'Downloading... ${(downloadProgress * 100).toStringAsFixed(0)}%'
                      : 'Downloading...',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
              ],

              const SizedBox(height: 8),

              // Action buttons
              Row(
                children: [
                  if (!status.downloaded)
                    _CompactButton(
                      icon: isDownloading ? null : Icons.download,
                      label: isDownloading ? 'Downloading...' : 'Download',
                      onPressed: isDownloading ? null : onDownload,
                      showSpinner: isDownloading,
                    )
                  else
                    _CompactButton(
                      icon: Icons.delete_outline,
                      label: 'Delete',
                      onPressed: isDownloading ? null : onDelete,
                    ),
                  const SizedBox(width: 8),
                  _CompactButton(
                    icon: Icons.open_in_new,
                    label: 'Source',
                    onPressed: () => launchUrl(
                      Uri.parse(info.sourceUrl),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(AppTheme.spacingMd),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Text('Error: $e', style: const TextStyle(color: AppTheme.errorColor)),
      ),
    );
  }

  static String _ramEstimate(int modelSizeBytes) {
    final mb = modelSizeBytes / (1024 * 1024);
    if (mb < 100) return '~200 MB';
    if (mb < 200) return '~500 MB';
    if (mb < 300) return '~500 MB';
    return '~1 GB';
  }
}

// ---------------------------------------------------------------------------
// Re-transcribe button
// ---------------------------------------------------------------------------

class _RetranscribeButton extends ConsumerWidget {
  const _RetranscribeButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actionsState = ref.watch(voiceMemoActionsProvider);
    final isBusy = actionsState.isLoading;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingMd,
        4,
        AppTheme.spacingMd,
        0,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.textSecondary,
            textStyle: Theme.of(context).textTheme.bodySmall,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: isBusy
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh, size: 16),
          label: Text(
            isBusy ? 'Re-transcribing...' : 'Re-transcribe all with selected model',
          ),
          onPressed: isBusy
              ? null
              : () async {
                  final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Re-transcribe all memos?'),
                          content: const Text(
                            'This will overwrite existing transcriptions '
                            'using the currently selected model.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: const Text('Re-transcribe'),
                            ),
                          ],
                        ),
                      ) ??
                      false;

                  if (!confirmed || !context.mounted) return;

                  try {
                    final count = await ref
                        .read(voiceMemoActionsProvider.notifier)
                        .retranscribeAll();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            count == 0
                                ? 'No downloaded memos to re-transcribe'
                                : 'Started re-transcribing $count memos',
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Re-transcription failed: $e')),
                      );
                    }
                  }
                },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AI Processing toggles
// ---------------------------------------------------------------------------

class _AiTogglesTile extends ConsumerWidget {
  const _AiTogglesTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localAiEnabled = ref.watch(localAiEnabledProvider);
    final autoProcess = ref.watch(autoProcessVoiceNotesProvider);

    return Column(
      children: [
        SwitchListTile(
          secondary: Icon(
            Icons.auto_awesome,
            color: localAiEnabled ? AppTheme.primaryColor : AppTheme.textSecondary,
          ),
          title: const Text('Enable Local AI'),
          subtitle: const Text('Process voice notes with on-device LLM'),
          value: localAiEnabled,
          onChanged: (value) {
            ref.read(localAiEnabledProvider.notifier).setEnabled(value);
          },
        ),
        Opacity(
          opacity: localAiEnabled ? 1.0 : 0.5,
          child: SwitchListTile(
            secondary: Icon(
              Icons.autorenew,
              color: autoProcess && localAiEnabled
                  ? AppTheme.primaryColor
                  : AppTheme.textSecondary,
            ),
            title: const Text('Auto-process after transcription'),
            subtitle: Text(
              localAiEnabled
                  ? 'Automatically run AI after each transcription'
                  : 'Enable Local AI first',
            ),
            value: autoProcess,
            onChanged: localAiEnabled
                ? (value) {
                    ref.read(autoProcessVoiceNotesProvider.notifier).setEnabled(value);
                  }
                : null,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// GPU inference mode selector (iOS Metal)
// ---------------------------------------------------------------------------

class _GpuModeTile extends ConsumerWidget {
  const _GpuModeTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(gpuInferenceModeProvider);
    final isBackground = GpuLifecycleManager.instance.isBackground;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMd,
        vertical: AppTheme.spacingSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<GpuInferenceMode>(
            segments: const [
              ButtonSegment(
                value: GpuInferenceMode.auto,
                label: Text('Auto'),
                icon: Icon(Icons.auto_mode, size: 18),
              ),
              ButtonSegment(
                value: GpuInferenceMode.alwaysGpu,
                label: Text('GPU'),
                icon: Icon(Icons.speed, size: 18),
              ),
              ButtonSegment(
                value: GpuInferenceMode.alwaysCpu,
                label: Text('CPU'),
                icon: Icon(Icons.memory, size: 18),
              ),
            ],
            selected: {mode},
            onSelectionChanged: (selected) {
              ref
                  .read(gpuInferenceModeProvider.notifier)
                  .setMode(selected.first);
            },
          ),
          const SizedBox(height: 8),
          Text(
            _modeDescription(mode, isBackground),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
        ],
      ),
    );
  }

  String _modeDescription(GpuInferenceMode mode, bool isBackground) {
    switch (mode) {
      case GpuInferenceMode.auto:
        return isBackground
            ? 'Auto: Currently using CPU (app backgrounded)'
            : 'Auto: Currently using Metal GPU (app in foreground). '
                'Switches to CPU automatically when backgrounded to '
                'prevent iOS Metal crashes.';
      case GpuInferenceMode.alwaysGpu:
        return 'Always use Metal GPU for maximum speed. '
            'Warning: may crash if inference runs while the app is '
            'backgrounded (e.g. auto-transcription after BLE sync).';
      case GpuInferenceMode.alwaysCpu:
        return 'Always use CPU. Slower but safe in all lifecycle states. '
            'Useful for benchmarking CPU vs GPU performance.';
    }
  }
}

// ---------------------------------------------------------------------------
// AI Model selector (dropdown + status + download/delete/import)
// ---------------------------------------------------------------------------

class _AiModelSelector extends ConsumerStatefulWidget {
  const _AiModelSelector();

  @override
  ConsumerState<_AiModelSelector> createState() => _AiModelSelectorState();
}

class _AiModelSelectorState extends ConsumerState<_AiModelSelector> {
  void _refreshProviders() {
    ref.invalidate(llmAvailableModelsProvider);
    ref.invalidate(selectedLlmModelInfoProvider);
    ref.invalidate(llmModelDownloadedProvider);
    ref.invalidate(llmModelSizeProvider);
    ref.invalidate(llmServiceStateProvider);
  }

  Future<void> _downloadModel() async {
    final llm = ref.read(llmServiceProvider);
    try {
      await llm.downloadModel();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Model downloaded')),
        );
      }
      _refreshProviders();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    }
  }

  Future<void> _deleteModel() async {
    final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete model?'),
            content: const Text('Delete the selected model from local storage?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldDelete) return;

    try {
      await ref.read(llmServiceProvider).deleteModel();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Model deleted')),
        );
      }
      _refreshProviders();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedModelId = ref.watch(selectedAiModelIdProvider);
    final availableAsync = ref.watch(llmAvailableModelsProvider);
    final selectedAsync = ref.watch(selectedLlmModelInfoProvider);
    final downloadedAsync = ref.watch(llmModelDownloadedProvider);
    final sizeAsync = ref.watch(llmModelSizeProvider);
    final serviceAsync = ref.watch(llmServiceStateProvider);

    return selectedAsync.when(
      data: (selectedModel) {
        return downloadedAsync.when(
          data: (isDownloaded) {
            final localSize = sizeAsync.whenOrNull(
              data: (s) => s != null ? _formatBytes(s) : null,
            );
            final isDownloading = serviceAsync.whenOrNull(
                  data: (s) => s.status == LlmServiceStatus.downloading,
                ) ??
                false;
            final downloadProgress = serviceAsync.whenOrNull(
                  data: (s) => s.downloadProgress,
                ) ??
                0.0;

            return Column(
              children: [
                // Dropdown
                availableAsync.when(
                  data: (models) => Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.spacingMd,
                      AppTheme.spacingSm,
                      AppTheme.spacingMd,
                      0,
                    ),
                    child: DropdownButtonFormField<String>(
                      value: models.any((m) => m.id == selectedModelId)
                          ? selectedModelId
                          : models.isNotEmpty
                              ? models.first.id
                              : null,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Select model',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: () {
                                // Assign ranks only to catalog models that
                                // have a benchmarkScore (already sorted best→worst).
                                final ranked = <String, int>{};
                                var rank = 1;
                                for (final m in models) {
                                  if (m.benchmarkScore != null) {
                                    ranked[m.id] = rank++;
                                  }
                                }
                                return models.map((m) {
                                  final modelRank = ranked[m.id];
                                  final Color rankColor;
                                  switch (modelRank) {
                                    case 1:
                                      rankColor = const Color(0xFFFFD700);
                                    case 2:
                                      rankColor = const Color(0xFFC0C0C0);
                                    case 3:
                                      rankColor = const Color(0xFFCD7F32);
                                    default:
                                      rankColor = AppTheme.textSecondary;
                                  }
                                  return DropdownMenuItem<String>(
                                    value: m.id,
                                    child: Row(
                                      children: [
                                        if (modelRank != null)
                                          Container(
                                            margin: const EdgeInsets.only(
                                                right: 8),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: rankColor
                                                  .withValues(alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '#$modelRank',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelSmall
                                                  ?.copyWith(
                                                    color: rankColor,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                          ),
                                        Expanded(
                                          child: Text(
                                            m.displayName,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList();
                              }(),
                      onChanged: isDownloading
                          ? null
                          : (value) {
                              if (value == null) return;
                              ref
                                  .read(selectedAiModelIdProvider.notifier)
                                  .setModelId(value);
                              _refreshProviders();
                            },
                    ),
                  ),
                  loading: () => const Padding(
                    padding: EdgeInsets.all(AppTheme.spacingMd),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.all(AppTheme.spacingMd),
                    child: Text('Error: $e',
                        style: const TextStyle(color: AppTheme.errorColor)),
                  ),
                ),

                // Status card
                Container(
                  margin: const EdgeInsets.fromLTRB(
                    AppTheme.spacingMd,
                    AppTheme.spacingSm,
                    AppTheme.spacingMd,
                    0,
                  ),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDownloaded
                        ? AppTheme.successColor.withValues(alpha: 0.06)
                        : Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    border: Border.all(
                      color: isDownloaded
                          ? AppTheme.successColor.withValues(alpha: 0.25)
                          : Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isDownloaded
                                ? Icons.check_circle
                                : Icons.cloud_download_outlined,
                            size: 18,
                            color: isDownloaded
                                ? AppTheme.successColor
                                : AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isDownloaded ? 'Downloaded' : 'Not downloaded',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: isDownloaded
                                        ? AppTheme.successColor
                                        : AppTheme.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (selectedModel.expectedSizeBytes != null)
                        _DetailRow(
                          label: 'Size',
                          value: _formatBytes(selectedModel.expectedSizeBytes!),
                        ),
                      if (localSize != null)
                        _DetailRow(label: 'Local', value: localSize),
                      _DetailRow(
                        label: 'Source',
                        value: selectedModel.userProvided
                            ? 'Imported'
                            : 'Catalog',
                      ),

                      // Memory fit indicator
                      _ModelMemoryFitBanner(model: selectedModel),

                      // Download progress
                      if (isDownloading) ...[
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: downloadProgress > 0 ? downloadProgress : null,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          downloadProgress > 0
                              ? 'Downloading... ${(downloadProgress * 100).toStringAsFixed(0)}%'
                              : 'Starting download...',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                        ),
                      ],

                      const SizedBox(height: 8),

                      // Action buttons
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (isDownloaded)
                            _CompactButton(
                              icon: Icons.delete_outline,
                              label: 'Delete',
                              onPressed: isDownloading ? null : _deleteModel,
                            )
                          else if (selectedModel.isDownloadable)
                            _CompactButton(
                              icon: isDownloading ? null : Icons.download,
                              label: isDownloading ? 'Downloading...' : 'Download',
                              onPressed: isDownloading ? null : _downloadModel,
                              showSpinner: isDownloading,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Process all button
                _ProcessAllButton(),
              ],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(AppTheme.spacingMd),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            child: Text('Error: $e',
                style: const TextStyle(color: AppTheme.errorColor)),
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(AppTheme.spacingMd),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Text('Error: $e',
            style: const TextStyle(color: AppTheme.errorColor)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Import custom model tile
// ---------------------------------------------------------------------------

/// Standalone tile that lets the user sideload a local .gguf file.
/// Kept separate from the catalog model selector so it's clear it's a
/// one-time "bring your own model" action, not tied to the selected model.
class _ImportModelTile extends ConsumerWidget {
  const _ImportModelTile();

  Future<void> _importModel(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        dialogTitle: 'Select a GGUF model file',
      );
      final path = result?.files.single.path;
      if (path == null) return;

      if (!path.toLowerCase().endsWith('.gguf')) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Only .gguf model files can be imported')),
          );
        }
        return;
      }

      final llm = ref.read(llmServiceProvider);
      final imported = await llm.importModel(path);
      ref.read(selectedAiModelIdProvider.notifier).setModelId(imported.id);
      ref.invalidate(llmAvailableModelsProvider);
      ref.invalidate(selectedLlmModelInfoProvider);
      ref.invalidate(llmModelDownloadedProvider);
      ref.invalidate(llmModelSizeProvider);
      ref.invalidate(llmServiceStateProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imported ${imported.filename}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: const Icon(Icons.upload_file_outlined),
      title: const Text('Import custom model'),
      subtitle: const Text('Use a local .gguf file from your device'),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: () => _importModel(context, ref),
    );
  }
}

class _ProcessAllButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localAiEnabled = ref.watch(localAiEnabledProvider);
    final aiActionsState = ref.watch(aiActionsProvider);
    final isBusy = aiActionsState.isLoading;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingMd,
        4,
        AppTheme.spacingMd,
        0,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.textSecondary,
            textStyle: Theme.of(context).textTheme.bodySmall,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: isBusy
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_awesome, size: 16),
          label: Text(isBusy ? 'Processing...' : 'Process all unprocessed'),
        onPressed: isBusy || !localAiEnabled
            ? null
            : () async {
                final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Process all unprocessed?'),
                        content: const Text(
                          'All voice memos not yet AI-processed will be processed now.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text('Process'),
                          ),
                        ],
                      ),
                    ) ??
                    false;

                if (!confirmed || !context.mounted) return;

                try {
                  await ref
                      .read(aiActionsProvider.notifier)
                      .processAllUnprocessed();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Started processing unprocessed memos'),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Processing failed: $e')),
                    );
                  }
                }
              },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Benchmark section  (debug-sheet-style live progress)
// ---------------------------------------------------------------------------

class _BenchmarkSection extends ConsumerStatefulWidget {
  const _BenchmarkSection();

  @override
  ConsumerState<_BenchmarkSection> createState() =>
      _BenchmarkSectionState();
}

class _BenchmarkSectionState extends ConsumerState<_BenchmarkSection> {
  late final TextEditingController _aiInputController;

  @override
  void initState() {
    super.initState();
    _aiInputController = TextEditingController(
      text: 'Remind me to buy groceries tomorrow and call the dentist at 2 PM.',
    );
  }

  @override
  void dispose() {
    _aiInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final benchState = ref.watch(_benchmarkStateProvider);
    final isRunning =
        benchState.whenOrNull(data: (s) => s.isRunning) ?? false;
    final runningType =
        benchState.whenOrNull(data: (s) => s.runningTestType);

    return Column(
      children: [
        _AiBenchmarkInputEditor(
          controller: _aiInputController,
          onReset: () {
            _aiInputController.text =
                'Remind me to buy groceries tomorrow and call the dentist at 2 PM.';
          },
        ),

        // ---------- Run buttons ----------
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacingMd,
            AppTheme.spacingSm,
            AppTheme.spacingMd,
            0,
          ),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  icon: runningType == 'transcription'
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white70,
                          ),
                        )
                      : const Icon(Icons.mic, size: 18),
                  label: Text(runningType == 'transcription'
                      ? 'Running…'
                      : 'Test Transcription'),
                  onPressed: isRunning
                      ? null
                      : () => _runTranscriptionBenchmark(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  icon: runningType == 'ai'
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white70,
                          ),
                        )
                      : const Icon(Icons.psychology, size: 18),
                  label: Text(
                      runningType == 'ai' ? 'Running…' : 'Test AI'),
                  onPressed: isRunning
                      ? null
                      : () => _runAiBenchmark(context),
                ),
              ),
            ],
          ),
        ),

        // ---------- Last result summary (shown after completion) ----------
        benchState.when(
          data: (state) {
            final progress = state.current;
            if (progress == null || !progress.isComplete) {
              return Padding(
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                child: Text(
                  'Run a quick test to see how fast the selected models '
                  'perform on your device.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
              );
            }
            // Show a compact last-result row with a "View" button to re-open
            return _LastResultTile(progress: progress);
          },
          loading: () => const SizedBox.shrink(),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            child: Text('Error: $e',
                style: const TextStyle(color: AppTheme.errorColor)),
          ),
        ),
      ],
    );
  }

  Future<void> _runTranscriptionBenchmark(BuildContext context) async {
    // Find a real voice recording to use
    final repo = ref.read(voiceMemoRepositoryProvider);
    final memos = await repo.getAllMemos();
    final usable = memos.where((m) {
      final path = m.convertedFilePath ?? m.localFilePath;
      return path != null && File(path).existsSync();
    }).toList();

    if (usable.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No voice recordings found — record one on the watch first.',
            ),
          ),
        );
      }
      return;
    }

    final memo = usable.first;
    final audioPath = memo.convertedFilePath ?? memo.localFilePath!;

    // Open debug sheet, then start the benchmark
    if (context.mounted) {
      _showBenchmarkSheet(context);
    }

    final selectedType = ref.read(transcriptionEngineTypeProvider);
    unawaited(
      ref
          .read(_benchmarkServiceProvider)
          .benchmarkTranscription(selectedType, audioPath),
    );
  }

  void _runAiBenchmark(BuildContext context) {
    final benchmarkInput = _aiInputController.text.trim();
    if (benchmarkInput.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Benchmark input cannot be empty.')),
      );
      return;
    }

    _showBenchmarkSheet(context);
    final llm = ref.read(llmServiceProvider);
    unawaited(
      ref.read(_benchmarkServiceProvider).benchmarkAiModel(
            llm,
            testInput: benchmarkInput,
          ),
    );
  }

  void _showBenchmarkSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.elevatedSurfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => _BenchmarkDebugSheet(
          scrollController: scrollController,
        ),
      ),
    );
  }
}

class _AiBenchmarkInputEditor extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onReset;

  const _AiBenchmarkInputEditor({
    required this.controller,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingMd,
        AppTheme.spacingSm,
        AppTheme.spacingMd,
        0,
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'AI benchmark input',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: onReset,
                  icon: const Icon(Icons.restart_alt, size: 16),
                  label: const Text('Reset'),
                ),
              ],
            ),
            Text(
              'Edit only the sample transcript here. The benchmark uses the same fixed AI prompt and chrono flow as the main app.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Test input text',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact tile shown in the benchmark section after a completed run.
class _LastResultTile extends StatelessWidget {
  final BenchmarkProgress progress;
  const _LastResultTile({required this.progress});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isError = progress.isError;
    final icon = progress.testType == 'transcription'
        ? Icons.mic
        : Icons.psychology;
    final statusColor =
        isError ? AppTheme.errorColor : AppTheme.successColor;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingMd,
        AppTheme.spacingSm,
        AppTheme.spacingMd,
        0,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(color: statusColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: statusColor),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    progress.modelName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (progress.elapsed > Duration.zero)
                    Text(
                      isError
                          ? 'Failed'
                          : '${(progress.elapsed.inMilliseconds / 1000).toStringAsFixed(1)}s'
                              '${progress.tokensPerSecond != null ? '  •  ${progress.tokensPerSecond!.toStringAsFixed(1)} t/s' : ''}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet showing live benchmark progress — uses shared debug widgets
/// from [ai_debug_widgets.dart] for visual parity with the voice-memo debug
/// sheet.
class _BenchmarkDebugSheet extends ConsumerWidget {
  final ScrollController scrollController;

  const _BenchmarkDebugSheet({required this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final benchState = ref.watch(_benchmarkStateProvider);
    final progress =
        benchState.whenOrNull(data: (s) => s.current);
    final isRunning =
        benchState.whenOrNull(data: (s) => s.isRunning) ?? false;

    return Column(
      children: [
        aiDebugHandleBar(),
        aiDebugSheetHeader(
          context,
          title: 'Benchmark Debug',
          showSpinner: progress != null && !progress.isComplete,
          onStop: isRunning
              ? () => ref.read(_benchmarkServiceProvider).abort()
              : null,
          onClose: () => Navigator.of(context).pop(),
        ),
        const Divider(),
        Expanded(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(16),
            children: _buildBody(context, progress),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildBody(BuildContext context, BenchmarkProgress? progress) {
    if (progress == null) {
      return [aiDebugNote(context, 'Waiting for benchmark to start…')];
    }

    if (!progress.isComplete) {
      // ---- Live / in-progress view ----
      final phaseText = switch (progress.phase) {
        'loading' => 'Loading model…',
        'running' => progress.testType == 'transcription'
            ? 'Transcribing…'
            : 'Generating…',
        _ => 'Processing…',
      };
      return [
        aiLivePhaseHeader(
          context,
          modelName: progress.modelName,
          phaseText: phaseText,
          tokens: progress.tokens,
          tokensPerSecond: progress.tokensPerSecond,
          elapsed: progress.elapsed,
        ),
        if (progress.partialOutput.isNotEmpty) ...[
          const SizedBox(height: 12),
          aiDebugBlock(
            context,
            title: progress.testType == 'transcription'
                ? 'Transcription Status'
                : 'LLM Output (live)',
            content: progress.partialOutput,
            icon: progress.testType == 'transcription'
                ? Icons.mic
                : Icons.code,
            mono: progress.testType == 'ai',
            showCopyButton: true,
          ),
        ],
      ];
    }

    // ---- Completed view ----
    return [
      aiCompletedHeader(
        context,
        modelName: progress.modelName,
        isError: progress.isError,
        tokens: progress.tokens,
        tokensPerSecond: progress.tokensPerSecond,
        elapsed: progress.elapsed,
      ),
      if (progress.testType == 'ai') ...[
        const SizedBox(height: 12),
        aiDebugBlock(
          context,
          title: 'Prompt / Flow',
          content: aiFormatPromptFlow(
            strategy: progress.promptStrategy,
            retryEnabled: progress.retryEnabled,
            attempts: progress.attempts,
          ),
          icon: Icons.tune,
          showCopyButton: true,
        ),
      ],
      if (progress.testType == 'ai' &&
          aiHasChronoDetails(
            extractedIntent: progress.extractedIntent,
            extractedTitle: progress.extractedTitle,
            datetimeExpressionOriginal: progress.datetimeExpressionOriginal,
            datetimeExpressionEnglish: progress.datetimeExpressionEnglish,
            resolvedDateTime: progress.resolvedDateTime,
            resolverMethod: progress.resolverMethod,
          )) ...[
        const SizedBox(height: 12),
        aiDebugBlock(
          context,
          title: 'Chrono Extraction / Resolution',
          content: aiFormatChronoDetails(
            extractedIntent: progress.extractedIntent,
            extractedTitle: progress.extractedTitle,
            datetimeExpressionOriginal: progress.datetimeExpressionOriginal,
            datetimeExpressionEnglish: progress.datetimeExpressionEnglish,
            resolvedDateTime: progress.resolvedDateTime,
            resolverMethod: progress.resolverMethod,
          ),
          icon: Icons.schedule,
          showCopyButton: true,
        ),
      ],
      // Show parsed summary for AI tests
      if (progress.partialOutput.isNotEmpty) ...[
        const SizedBox(height: 12),
        aiDebugBlock(
          context,
          title: progress.testType == 'transcription'
              ? 'Transcription Result'
              : 'Parsed Result',
          content: progress.partialOutput,
          icon: progress.testType == 'transcription'
              ? Icons.mic
              : Icons.check_circle_outline,
          showCopyButton: true,
        ),
      ],
      if (progress.parsedJson != null && progress.parsedJson!.isNotEmpty) ...[
        const SizedBox(height: 12),
        aiDebugBlock(
          context,
          title: 'Parsed JSON',
          content: progress.parsedJson!,
          icon: Icons.data_object,
          mono: true,
          showCopyButton: true,
        ),
      ],
      // Show full raw LLM output for AI tests (preserved after completion)
      if (progress.rawOutput != null &&
          progress.rawOutput!.isNotEmpty &&
          progress.rawOutput != progress.partialOutput) ...[
        const SizedBox(height: 12),
        aiDebugBlock(
          context,
          title: 'Raw LLM Output',
          content: progress.rawOutput!,
          icon: Icons.code,
          mono: true,
          showCopyButton: true,
        ),
      ],
      if (progress.isError && progress.error != null) ...[
        const SizedBox(height: 12),
        aiDebugBlock(
          context,
          title: 'Error',
          content: progress.error!,
          icon: Icons.error_outline,
          showCopyButton: true,
        ),
      ],
    ];
  }
}

// ---------------------------------------------------------------------------
// Shared small widgets
// ---------------------------------------------------------------------------

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactButton extends StatelessWidget {
  final IconData? icon;
  final String label;
  final VoidCallback? onPressed;
  final bool showSpinner;

  const _CompactButton({
    this.icon,
    required this.label,
    this.onPressed,
    this.showSpinner = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        minimumSize: const Size(48, 32),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      icon: showSpinner
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : icon != null
              ? Icon(icon, size: 16)
              : const SizedBox.shrink(),
      label: Text(label),
    );
  }
}

// ---------------------------------------------------------------------------
// Memory fit banner for the selected AI model
// ---------------------------------------------------------------------------

class _ModelMemoryFitBanner extends ConsumerWidget {
  const _ModelMemoryFitBanner({required this.model});

  final LlmModelInfo model;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fitAsync = ref.watch(llmModelFitProvider);

    return fitAsync.when(
      data: (fit) {
        final IconData icon;
        final Color color;
        final String label;

        switch (fit.fit) {
          case ModelMemoryFit.comfortable:
            icon = Icons.check_circle_outline;
            color = AppTheme.successColor;
            label = fit.summary;
          case ModelMemoryFit.reduced:
            icon = Icons.warning_amber_rounded;
            color = AppTheme.warningColor;
            label = fit.summary;
          case ModelMemoryFit.cpuFallback:
            icon = Icons.memory;
            color = AppTheme.errorColor;
            label = fit.summary;
        }

        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

// ---------------------------------------------------------------------------
// Calendar Integration
// ---------------------------------------------------------------------------

/// Shows calendar permission status and a button to grant it.
class _CalendarPermissionTile extends ConsumerStatefulWidget {
  const _CalendarPermissionTile();

  @override
  ConsumerState<_CalendarPermissionTile> createState() =>
      _CalendarPermissionTileState();
}

class _CalendarPermissionTileState
    extends ConsumerState<_CalendarPermissionTile>
    with WidgetsBindingObserver {
  bool _granted = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermission();
    }
  }

  Future<void> _checkPermission() async {
    final status = await Permission.calendarFullAccess.status;
    if (mounted) {
      setState(() {
        _granted = status.isGranted;
        _checking = false;
      });
    }
  }

  Future<void> _requestPermission() async {
    final status = await Permission.calendarFullAccess.request();
    if (status.isPermanentlyDenied && mounted) {
      await openAppSettings();
    }
    await _checkPermission();
    if (_granted) {
      // Refresh calendar list now that permission is granted
      ref.invalidate(writableCalendarsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const ListTile(
        leading: Icon(Icons.hourglass_empty, color: AppTheme.textSecondary),
        title: Text('Calendar Permission'),
        subtitle: Text('Checking...'),
      );
    }

    return ListTile(
      leading: Icon(
        _granted ? Icons.check_circle : Icons.calendar_month,
        color: _granted ? AppTheme.successColor : AppTheme.warningColor,
      ),
      title: const Text('Calendar Permission'),
      subtitle: Text(
        _granted
            ? 'Granted — AI can create calendar events and reminders'
            : 'Required for creating events from voice memos',
      ),
      trailing: _granted
          ? null
          : FilledButton(
              onPressed: _requestPermission,
              child: const Text('Grant'),
            ),
    );
  }
}

/// Shows iOS Reminders permission status (separate from calendar on iOS).
class _RemindersPermissionTile extends ConsumerStatefulWidget {
  const _RemindersPermissionTile();

  @override
  ConsumerState<_RemindersPermissionTile> createState() =>
      _RemindersPermissionTileState();
}

class _RemindersPermissionTileState
    extends ConsumerState<_RemindersPermissionTile>
    with WidgetsBindingObserver {
  bool _granted = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermission();
    }
  }

  Future<void> _checkPermission() async {
    final status = await Permission.reminders.status;
    if (mounted) {
      setState(() {
        _granted = status.isGranted;
        _checking = false;
      });
    }
  }

  Future<void> _requestPermission() async {
    final status = await Permission.reminders.request();
    if (status.isPermanentlyDenied && mounted) {
      await openAppSettings();
    }
    await _checkPermission();
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const ListTile(
        leading: Icon(Icons.hourglass_empty, color: AppTheme.textSecondary),
        title: Text('Reminders Permission'),
        subtitle: Text('Checking...'),
      );
    }

    return ListTile(
      leading: Icon(
        _granted ? Icons.check_circle : Icons.checklist,
        color: _granted ? AppTheme.successColor : AppTheme.warningColor,
      ),
      title: const Text('Reminders Permission'),
      subtitle: Text(
        _granted
            ? 'Granted — AI can create reminders'
            : 'Required for creating reminders from voice memos',
      ),
      trailing: _granted
          ? null
          : FilledButton(
              onPressed: _requestPermission,
              child: const Text('Grant'),
            ),
    );
  }
}

/// Shows the selected calendar and allows picking a different one.
/// Only visible when calendar permission is granted (Android only).
class _CalendarPickerTile extends ConsumerWidget {
  const _CalendarPickerTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendarsAsync = ref.watch(writableCalendarsProvider);
    final selectedCalendarId = ref.watch(selectedProductivityCalendarIdProvider);

    return calendarsAsync.when(
      data: (calendars) {
        if (calendars.isEmpty) {
          return const ListTile(
            leading: Icon(Icons.calendar_today, color: AppTheme.textSecondary),
            title: Text('Default Calendar'),
            subtitle: Text(
              'No writable calendars found. Grant calendar permission above.',
            ),
          );
        }

        final selectedCalendar = calendars
            .where((c) => c.id == selectedCalendarId)
            .cast<PlatformCalendar?>()
            .firstWhere((c) => c != null, orElse: () => calendars.first);

        final cal = selectedCalendar ?? calendars.first;

        return ListTile(
          leading: Icon(
            cal.looksLocal ? Icons.event_busy : Icons.calendar_today,
            color:
                cal.looksLocal ? AppTheme.warningColor : AppTheme.primaryColor,
          ),
          title: const Text('Default Calendar'),
          subtitle: Text(
            cal.looksLocal
                ? '${cal.label}\nLocal calendars may not sync to cloud.'
                : cal.label,
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showPicker(context, ref, calendars),
        );
      },
      loading: () => const ListTile(
        leading: Icon(Icons.calendar_today, color: AppTheme.textSecondary),
        title: Text('Default Calendar'),
        subtitle: Text('Loading calendars...'),
      ),
      error: (error, _) => ListTile(
        leading:
            const Icon(Icons.calendar_today, color: AppTheme.warningColor),
        title: const Text('Default Calendar'),
        subtitle: Text('Error: $error'),
        trailing: IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () => ref.invalidate(writableCalendarsProvider),
        ),
      ),
    );
  }

  Future<void> _showPicker(
    BuildContext context,
    WidgetRef ref,
    List<PlatformCalendar> calendars,
  ) async {
    final selectedId = ref.read(selectedProductivityCalendarIdProvider);
    final picked = await showModalBottomSheet<int>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(
                title: Text('Choose Calendar'),
                subtitle:
                    Text('Used for events and reminders created by AI.'),
              ),
              for (final calendar in calendars)
                ListTile(
                  leading: Icon(
                    calendar.id == selectedId
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: calendar.id == selectedId
                        ? AppTheme.primaryColor
                        : AppTheme.textSecondary,
                  ),
                  title: Text(calendar.label),
                  subtitle: calendar.looksLocal
                      ? const Text('Local — may not sync to cloud')
                      : null,
                  onTap: () => Navigator.of(context).pop(calendar.id),
                ),
            ],
          ),
        );
      },
    );

    if (picked != null) {
      ref
          .read(selectedProductivityCalendarIdProvider.notifier)
          .setCalendarId(picked);
    }
  }
}
