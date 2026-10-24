import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/companion_recording.dart';
import '../background/companion_prototype_client.dart';
import 'voice_memo_file_store.dart';

/// Keeps Voice Notes to the notes that still need the user: finished notes
/// are archived once, and Recently deleted empties itself after 30 days.
class VoiceNoteTidy {
  static const deletedRetention = Duration(days: 30);
  static const handledKey = 'voice_notes_auto_archived';
  static const _handledLimit = 2000;

  /// Every extracted action was created or dismissed; a note without actions
  /// (including a watch Chat answer) counts once the watch has shown it.
  static bool isDone(CompanionRecording recording, Map<Object?, Object?>? job) {
    if (job == null ||
        recording.archived ||
        recording.state != CompanionRecordingState.downloaded) {
      return false;
    }
    final actions = (job['action_types'] as List?)?.length ?? 0;
    if (actions == 0) return job['state'] == 'delivered';
    final resolved = job['actions_resolved'];
    return ['result_ready', 'delivered'].contains(job['state']) &&
        resolved is int &&
        resolved >= actions;
  }

  static bool isExpired(CompanionRecording recording, DateTime now) =>
      recording.state == CompanionRecordingState.deleted &&
      !recording.purged &&
      recording.deletedAt != null &&
      now.difference(recording.deletedAt!) > deletedRetention;

  static Future<void> apply({
    required List<CompanionRecording> recordings,
    required Map<String, Map<Object?, Object?>> jobs,
    required SharedPreferences prefs,
    required CompanionPrototypeClient client,
    DateTime? now,
  }) async {
    // Archive each note once, so one the user unarchives stays in the list.
    final handled = prefs.getStringList(handledKey) ?? <String>[];
    final known = handled.toSet();
    final done = recordings
        .where(
          (item) =>
              !known.contains(item.identity) &&
              isDone(item, jobs[item.identity]),
        )
        .toList();
    for (final item in done) {
      await client.updateRecording(item.identity, archived: true);
      handled.add(item.identity);
      await prefs.setStringList(
        handledKey,
        handled.length > _handledLimit
            ? handled.sublist(handled.length - _handledLimit)
            : handled,
      );
    }
    final expired = recordings
        .where((item) => isExpired(item, now ?? DateTime.now().toUtc()))
        .map((item) => item.identity)
        .toList();
    if (expired.isEmpty) return;
    debugPrint('[VoiceNoteTidy] purging ${expired.length} expired recordings');
    await VoiceMemoFileStore.exclusive(() async {
      for (var start = 0; start < expired.length; start += 100) {
        await client.purgeRecordings(
          expired.sublist(
            start,
            start + 100 > expired.length ? expired.length : start + 100,
          ),
        );
      }
    });
  }
}
