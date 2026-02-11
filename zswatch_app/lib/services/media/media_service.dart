import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Media playback state
class MediaPlaybackState {
  final String state; // play, pause, stop, buffering, etc.
  final int positionSeconds;
  final double playbackSpeed;

  const MediaPlaybackState({
    required this.state,
    this.positionSeconds = 0,
    this.playbackSpeed = 1.0,
  });

  bool get isPlaying => state == 'play';
  bool get isPaused => state == 'pause';
  bool get isStopped => state == 'stop';

  factory MediaPlaybackState.fromMap(Map<String, dynamic> map) {
    return MediaPlaybackState(
      state: map['state'] as String? ?? 'unknown',
      positionSeconds: map['position'] as int? ?? 0,
      playbackSpeed: (map['playbackSpeed'] as num?)?.toDouble() ?? 1.0,
    );
  }

  @override
  String toString() => 'MediaPlaybackState(state: $state, position: $positionSeconds)';
}

/// Media track metadata
class MediaMetadata {
  final String? artist;
  final String? album;
  final String? track;
  final int? durationSeconds;
  final int? trackNumber;
  final int? trackCount;

  const MediaMetadata({
    this.artist,
    this.album,
    this.track,
    this.durationSeconds,
    this.trackNumber,
    this.trackCount,
  });

  factory MediaMetadata.fromMap(Map<String, dynamic> map) {
    return MediaMetadata(
      artist: map['artist'] as String?,
      album: map['album'] as String?,
      track: map['track'] as String?,
      durationSeconds: map['duration'] as int?,
      trackNumber: map['trackNumber'] as int?,
      trackCount: map['trackCount'] as int?,
    );
  }

  @override
  String toString() => 'MediaMetadata(artist: $artist, track: $track)';
}

/// Service for controlling media playback and receiving media state updates.
///
/// On Android:
/// - Uses MediaSessionManager via MethodChannel
/// - Requires NotificationListenerService permission
///
/// On iOS:
/// - Not applicable - AMS handles media control directly between iOS and watch
/// - This service provides a no-op implementation
class MediaService {
  static const _methodChannel = MethodChannel('dev.zswatch.app/media');
  static const _eventChannel = EventChannel('dev.zswatch.app/media_events');

  final _playbackStateController = StreamController<MediaPlaybackState>.broadcast();
  final _metadataController = StreamController<MediaMetadata>.broadcast();

  StreamSubscription<dynamic>? _eventSubscription;
  bool _initialized = false;

  MediaPlaybackState? _currentState;
  MediaMetadata? _currentMetadata;

  /// Stream of playback state changes
  Stream<MediaPlaybackState> get playbackStateStream => _playbackStateController.stream;

  /// Stream of metadata changes
  Stream<MediaMetadata> get metadataStream => _metadataController.stream;

  /// Current playback state
  MediaPlaybackState? get currentState => _currentState;

  /// Current track metadata
  MediaMetadata? get currentMetadata => _currentMetadata;

  /// Whether the service has been initialized
  bool get isInitialized => _initialized;

  /// Whether this platform supports media control
  bool get isSupported => Platform.isAndroid;

  /// Initialize the media service
  Future<bool> initialize() async {
    if (_initialized) return true;
    if (!Platform.isAndroid) {
      // iOS uses AMS directly between watch and iOS - app not involved
      debugPrint('MediaService: iOS uses AMS, not initializing');
      _initialized = true;
      return true;
    }

    try {
      // Start listening to media events
      _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
        _handleEvent,
        onError: (Object error) {
          debugPrint('MediaService event error: $error');
        },
      );

      // Initialize native side
      final result = await _methodChannel.invokeMethod<bool>('initialize');
      _initialized = result ?? false;

      if (_initialized) {
        // Get initial state
        await _fetchCurrentState();
      }

      debugPrint('MediaService initialized: $_initialized');
      return _initialized;
    } catch (e) {
      debugPrint('MediaService initialization failed: $e');
      return false;
    }
  }

  void _handleEvent(dynamic event) {
    if (event is! Map) return;

    final eventType = event['event'] as String?;
    final data = event['data'] as Map?;

    switch (eventType) {
      case 'playbackState':
        if (data != null) {
          try {
            _currentState = MediaPlaybackState.fromMap(Map<String, dynamic>.from(data));
            _playbackStateController.add(_currentState!);
            debugPrint('Playback state: ${_currentState!.state}');
          } catch (e) {
            debugPrint('Error parsing playback state: $e');
          }
        }
        break;

      case 'metadata':
        if (data != null) {
          try {
            _currentMetadata = MediaMetadata.fromMap(Map<String, dynamic>.from(data));
            _metadataController.add(_currentMetadata!);
            debugPrint('Metadata: ${_currentMetadata!.track}');
          } catch (e) {
            debugPrint('Error parsing metadata: $e');
          }
        }
        break;
    }
  }

  Future<void> _fetchCurrentState() async {
    try {
      final result = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>('getCurrentState');
      if (result != null) {
        final playback = result['playback'] as Map?;
        final metadata = result['metadata'] as Map?;

        if (playback != null) {
          _currentState = MediaPlaybackState.fromMap(Map<String, dynamic>.from(playback));
          _playbackStateController.add(_currentState!);
        }

        if (metadata != null) {
          _currentMetadata = MediaMetadata.fromMap(Map<String, dynamic>.from(metadata));
          _metadataController.add(_currentMetadata!);
        }
      }
    } catch (e) {
      debugPrint('Error fetching current state: $e');
    }
  }

  /// Fetch current state from native side with freshly calculated position.
  /// 
  /// This queries the native MediaSession to get the current state with
  /// position calculated based on elapsed time since last update.
  /// Use this when you need an up-to-date position (e.g., for initial sync).
  Future<void> fetchCurrentState() async {
    await _fetchCurrentState();
  }

  // Media control actions

  /// Play
  Future<bool> play() async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await _methodChannel.invokeMethod<bool>('play');
      return result ?? false;
    } catch (e) {
      debugPrint('Error sending play: $e');
      return false;
    }
  }

  /// Pause
  Future<bool> pause() async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await _methodChannel.invokeMethod<bool>('pause');
      return result ?? false;
    } catch (e) {
      debugPrint('Error sending pause: $e');
      return false;
    }
  }

  /// Toggle play/pause
  Future<bool> playPause() async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await _methodChannel.invokeMethod<bool>('playPause');
      return result ?? false;
    } catch (e) {
      debugPrint('Error sending playPause: $e');
      return false;
    }
  }

  /// Skip to next track
  Future<bool> next() async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await _methodChannel.invokeMethod<bool>('next');
      return result ?? false;
    } catch (e) {
      debugPrint('Error sending next: $e');
      return false;
    }
  }

  /// Skip to previous track
  Future<bool> previous() async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await _methodChannel.invokeMethod<bool>('previous');
      return result ?? false;
    } catch (e) {
      debugPrint('Error sending previous: $e');
      return false;
    }
  }

  /// Increase volume
  Future<bool> volumeUp() async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await _methodChannel.invokeMethod<bool>('volumeUp');
      return result ?? false;
    } catch (e) {
      debugPrint('Error sending volumeUp: $e');
      return false;
    }
  }

  /// Decrease volume
  Future<bool> volumeDown() async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await _methodChannel.invokeMethod<bool>('volumeDown');
      return result ?? false;
    } catch (e) {
      debugPrint('Error sending volumeDown: $e');
      return false;
    }
  }

  /// Seek to position
  Future<bool> seekTo(int positionSeconds) async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await _methodChannel.invokeMethod<bool>('seekTo', {'position': positionSeconds});
      return result ?? false;
    } catch (e) {
      debugPrint('Error sending seekTo: $e');
      return false;
    }
  }

  /// Check if there's an active media session
  Future<bool> hasActiveSession() async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await _methodChannel.invokeMethod<bool>('hasActiveSession');
      return result ?? false;
    } catch (e) {
      debugPrint('Error checking active session: $e');
      return false;
    }
  }

  /// Dispose the service
  Future<void> dispose() async {
    if (Platform.isAndroid) {
      try {
        await _methodChannel.invokeMethod<void>('dispose');
      } catch (e) {
        debugPrint('Error disposing native side: $e');
      }
    }

    await _eventSubscription?.cancel();
    await _playbackStateController.close();
    await _metadataController.close();
    _initialized = false;
  }
}

