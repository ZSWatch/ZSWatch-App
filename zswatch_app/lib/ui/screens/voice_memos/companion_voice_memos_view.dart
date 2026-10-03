import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/models/companion_recording.dart';
import '../../../providers/companion_runtime_providers.dart';

/// Native receipt view used by the existing Voice Notes screen during migration.
/// It observes the core; opening this screen does not start sync or inference.
class CompanionVoiceMemosView extends ConsumerStatefulWidget {
  const CompanionVoiceMemosView({super.key});

  @override
  ConsumerState<CompanionVoiceMemosView> createState() =>
      _CompanionVoiceMemosViewState();
}

class _CompanionVoiceMemosViewState
    extends ConsumerState<CompanionVoiceMemosView> {
  bool refreshing = false;

  Future<void> refreshList() async {
    setState(() => refreshing = true);
    try {
      // Refresh metadata only. Native retains its download setting and owns
      // any already-enabled sync; this command never retries failed transfers.
      await ref.read(companionClientProvider).command('requestRecordingList');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not refresh the recording list')),
        );
      }
    } finally {
      if (mounted) setState(() => refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(companionSnapshotProvider).asData?.value;
    final recordings = ref.watch(companionRecordingsProvider);
    final ready = snapshot?.protocolReady == true;
    final paused = snapshot?.fields['recording_sync_enabled'] == false;
    final watchId = snapshot?.fields['address'];
    final observed = snapshot?.fields['recording_list'];
    final liveListCount =
        ready &&
            observed is Map &&
            observed['address'] == watchId &&
            observed['generation'] == snapshot?.generation &&
            observed['count'] is int
        ? observed['count'] as int
        : null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Notes'),
        actions: [
          IconButton(
            tooltip: 'Refresh recording list',
            onPressed: ready && !refreshing ? refreshList : null,
            icon: refreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: recordings.when(
        skipLoadingOnRefresh: false,
        skipLoadingOnReload: false,
        data: (all) {
          final items = all.where((item) => item.watchId == watchId).toList();
          final saved = items.where((item) => item.hasCommittedReceipt).length;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('${items.length} recordings • $saved saved on phone'),
              if (liveListCount != null)
                Text('Latest watch list: $liveListCount recordings'),
              Text(
                !ready
                    ? 'Watch disconnected — showing saved status'
                    : paused
                    ? 'Downloads paused'
                    : 'Downloads enabled',
              ),
              const SizedBox(height: 16),
              if (items.isEmpty)
                const Text('No recordings saved for this watch'),
              for (final item in items)
                ListTile(
                  key: ValueKey(item.identity),
                  leading: Icon(
                    item.hasCommittedReceipt
                        ? Icons.file_download_done
                        : Icons.mic,
                  ),
                  title: Text(item.filename),
                  subtitle: Text(
                    '${DateFormat.yMMMd().add_Hm().format(item.timestampUtc.toLocal())} • '
                    '${(item.durationMs / 1000).toStringAsFixed(1)} s\n'
                    '${status(item, ready, paused)}',
                  ),
                  isThreeLine: true,
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            const Center(child: Text('Recording status is unavailable')),
      ),
    );
  }

  String status(CompanionRecording item, bool ready, bool paused) =>
      switch (item.state) {
        CompanionRecordingState.downloaded => 'Saved on phone',
        CompanionRecordingState.failed => 'Download failed',
        CompanionRecordingState.downloading =>
          ready ? 'Downloading' : 'Interrupted transfer — awaiting recovery',
        CompanionRecordingState.pending =>
          paused
              ? 'Waiting — downloads paused'
              : ready
              ? 'Queued for download'
              : 'Waiting for connection',
      };
}
