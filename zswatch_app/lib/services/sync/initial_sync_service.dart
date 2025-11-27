import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../media/media_service.dart';
import '../watch_service.dart';

/// Result of an initial sync operation
enum SyncResult {
  /// Sync completed successfully
  success,

  /// Sync failed (non-critical, connection still usable)
  failed,

  /// Sync was skipped (e.g., not applicable for platform)
  skipped,
}

/// Progress callback for sync operations
typedef SyncProgressCallback = void Function(String operation, double progress);

/// Service to orchestrate initial sync operations on watch connection (FR-084 to FR-088)
///
/// Handles:
/// - Time sync (FR-085)
/// - Music state sync (FR-086)
/// - Other relevant state sync (FR-087)
/// - Ensures connection is only marked "ready" after sync completes (FR-088)
class InitialSyncService {
  final WatchService _watchService;
  final MediaService _mediaService;

  /// Callback for sync progress updates
  SyncProgressCallback? onProgress;

  InitialSyncService({
    required WatchService watchService,
    required MediaService mediaService,
  })  : _watchService = watchService,
        _mediaService = mediaService;

  /// Perform all initial sync operations
  ///
  /// Returns true if all critical syncs succeeded.
  /// Non-critical sync failures (like music state) don't cause overall failure.
  Future<bool> performInitialSync() async {
    debugPrint('[InitialSync] Starting initial sync operations');
    
    var allSucceeded = true;

    // 1. Time sync (FR-085) - Critical
    onProgress?.call('Syncing time...', 0.0);
    final timeResult = await _syncTime();
    if (timeResult == SyncResult.failed) {
      allSucceeded = false;
      debugPrint('[InitialSync] Time sync failed');
    }

    // 2. Music state sync (FR-086) - Non-critical, Android only
    onProgress?.call('Syncing media...', 0.5);
    final musicResult = await _syncMusicState();
    if (musicResult == SyncResult.failed) {
      // Music sync failure is not critical
      debugPrint('[InitialSync] Music sync failed (non-critical)');
    }

    // 3. Future: Other state syncs (FR-087)
    // Add weather, calendar, etc. syncs here when implemented
    onProgress?.call('Sync complete', 1.0);

    debugPrint('[InitialSync] Initial sync completed: success=$allSucceeded');
    return allSucceeded;
  }

  /// Sync time to the watch (FR-085)
  Future<SyncResult> _syncTime() async {
    try {
      debugPrint('[InitialSync] Syncing time...');
      await _watchService.syncTime();
      debugPrint('[InitialSync] Time sync successful');
      return SyncResult.success;
    } catch (e) {
      debugPrint('[InitialSync] Time sync error: $e');
      return SyncResult.failed;
    }
  }

  /// Sync current music state to watch (FR-086)
  ///
  /// Only applicable on Android - iOS uses AMS directly.
  Future<SyncResult> _syncMusicState() async {
    if (!Platform.isAndroid) {
      debugPrint('[InitialSync] Music sync skipped (iOS uses AMS)');
      return SyncResult.skipped;
    }

    try {
      debugPrint('[InitialSync] Syncing music state...');

      // Check if media service is initialized
      if (!_mediaService.isInitialized) {
        debugPrint('[InitialSync] Media service not initialized, attempting init');
        await _mediaService.initialize();
      }

      // Get current playback state
      final playbackState = _mediaService.currentState;
      final metadata = _mediaService.currentMetadata;

      // Only send if there's something playing or paused (FR-083)
      if (playbackState != null && 
          (playbackState.isPlaying || playbackState.isPaused)) {
        
        // Send playback state
        await _watchService.sendMusicState(
          state: playbackState.state,
          positionSeconds: playbackState.positionSeconds,
        );
        debugPrint('[InitialSync] Sent music state: ${playbackState.state}');

        // Send metadata if available
        if (metadata != null && metadata.track != null) {
          await _watchService.sendMusicInfo(
            artist: metadata.artist,
            album: metadata.album,
            track: metadata.track,
            durationSeconds: metadata.durationSeconds,
            trackNumber: metadata.trackNumber,
            trackCount: metadata.trackCount,
          );
          debugPrint('[InitialSync] Sent music info: ${metadata.artist} - ${metadata.track}');
        }
        
        return SyncResult.success;
      } else {
        debugPrint('[InitialSync] No active media playback, skipping music sync');
        return SyncResult.skipped;
      }
    } catch (e) {
      debugPrint('[InitialSync] Music sync error: $e');
      return SyncResult.failed;
    }
  }

  /// Perform a quick sync (time only) for reconnection scenarios
  ///
  /// Use this for faster reconnection when the user was recently connected.
  Future<bool> performQuickSync() async {
    debugPrint('[InitialSync] Performing quick sync (time only)');
    final result = await _syncTime();
    return result == SyncResult.success;
  }
}
