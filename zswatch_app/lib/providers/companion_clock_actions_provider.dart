import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'companion_runtime_providers.dart';

typedef CompanionClockAction = ({
  String jobId,
  int index,
  Map<Object?, Object?> action,
  Map<Object?, Object?>? state,
  bool canCreate,
});

/// Read the same saved results/action receipts as the individual recording view.
/// No database copy, inference, BLE operation or Clock dispatch on observation.
final companionClockActionsProvider =
    FutureProvider.autoDispose<List<CompanionClockAction>>((ref) async {
      ref.watch(
        companionSnapshotProvider.select((value) {
          final snapshot = value.valueOrNull;
          final rows = snapshot?.fields['voice_jobs'];
          return '${snapshot?.fields['address']}:${rows is List ? rows.whereType<Map<Object?, Object?>>().map((row) => '${row['job_id']}:${row['state']}:${row['selected']}:${row['action_revision']}').join('|') : ''}';
        }),
      );
      final snapshot = ref.read(companionSnapshotProvider).valueOrNull;
      final address = snapshot?.fields['address'];
      final rows = snapshot?.fields['voice_jobs'];
      if (address == null || rows is! List) return [];
      final ids = rows
          .whereType<Map<Object?, Object?>>()
          .where(
            (row) =>
                row['watch_id'] == address &&
                ((const ['result_ready', 'delivered'].contains(row['state']) &&
                        row['selected'] == true) ||
                    (row['action_revision'] as num? ?? 0) > 0),
          )
          .map((row) => row['job_id'] as String)
          .toList();
      final jobs = await Future.wait(
        ids.map((id) => ref.watch(companionVoiceJobProvider(id).future)),
      );
      final output = <CompanionClockAction>[];
      for (var i = 0; i < jobs.length; i++) {
        final job = jobs[i];
        final result = job['result'];
        if (result is! Map || result['actions'] is! List) continue;
        final states = job['action_states'] as Map?;
        final actions = result['actions'] as List;
        for (var index = 0; index < actions.length; index++) {
          final action = actions[index];
          final state = states?['$index'] as Map?;
          if (action is! Map ||
              !const ['alarm', 'timer'].contains(action['type'])) {
            continue;
          }
          // A replaced result can still own a dispatched/dismissed Clock action.
          // Hide only its old, unreviewed suggestions; never lose its receipt.
          if (job['selected'] != true && state == null) continue;
          output.add((
            jobId: ids[i],
            index: index,
            action: Map<Object?, Object?>.from(action),
            state: state == null ? null : Map<Object?, Object?>.from(state),
            canCreate: const [
              'result_ready',
              'delivered',
            ].contains(job['state']),
          ));
        }
      }
      return output;
    });
