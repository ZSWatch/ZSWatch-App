import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/connection.dart';
import '../data/models/notification.dart';
import '../services/notification/notification_service.dart';
import '../services/media/media_service.dart';
import '../services/protocol/protocol_service.dart';
import '../services/watch_service.dart';
import 'watch_service_provider.dart';

// Keys for SharedPreferences
const _notificationForwardingEnabledKey = 'notification_forwarding_enabled';
const _blockedAppsKey = 'notification_blocked_apps';

/// Provider for the notification service singleton
final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider for the media service singleton
final mediaServiceProvider = Provider<MediaService>((ref) {
  final service = MediaService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// State class for notification forwarding
class NotificationForwardingState {
  final bool isEnabled;
  final bool hasPermission;
  final bool isServiceRunning;
  final Set<String> blockedApps;
  final int forwardedCount;
  final int dismissedCount;

  const NotificationForwardingState({
    this.isEnabled = false,
    this.hasPermission = false,
    this.isServiceRunning = false,
    this.blockedApps = const {},
    this.forwardedCount = 0,
    this.dismissedCount = 0,
  });

  NotificationForwardingState copyWith({
    bool? isEnabled,
    bool? hasPermission,
    bool? isServiceRunning,
    Set<String>? blockedApps,
    int? forwardedCount,
    int? dismissedCount,
  }) {
    return NotificationForwardingState(
      isEnabled: isEnabled ?? this.isEnabled,
      hasPermission: hasPermission ?? this.hasPermission,
      isServiceRunning: isServiceRunning ?? this.isServiceRunning,
      blockedApps: blockedApps ?? this.blockedApps,
      forwardedCount: forwardedCount ?? this.forwardedCount,
      dismissedCount: dismissedCount ?? this.dismissedCount,
    );
  }
}

/// Notifier for notification forwarding state and actions
class NotificationForwardingNotifier extends StateNotifier<NotificationForwardingState> {
  final NotificationService _notificationService;
  final WatchService _watchService;
  
  StreamSubscription<PhoneNotification>? _notificationSubscription;
  StreamSubscription<int>? _notificationRemovedSubscription;
  StreamSubscription<Map<String, dynamic>>? _watchMessageSubscription;

  // Deduplication: Track recently sent notifications to avoid duplicates
  final Map<String, DateTime> _recentlySentNotifications = {};
  static const _deduplicationWindowMs = 2000; // 2 second window

  // Track notification id to key mapping for dismiss sync
  // Key: notification id (int), Value: notification key (String)
  final Map<int, String> _notificationIdToKey = {};

  NotificationForwardingNotifier(
    this._notificationService,
    this._watchService,
  ) : super(const NotificationForwardingState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    if (!Platform.isAndroid) {
      // iOS uses ANCS - nothing to initialize
      return;
    }

    try {
      // Load saved settings
      final prefs = await SharedPreferences.getInstance();
      final isEnabled = prefs.getBool(_notificationForwardingEnabledKey) ?? false;
      final blockedApps = prefs.getStringList(_blockedAppsKey)?.toSet() ?? {};

      // Check permission status
      await _notificationService.initialize();
      final hasPermission = await _notificationService.isNotificationAccessEnabled();
      final isServiceRunning = await _notificationService.isServiceRunning();

      state = state.copyWith(
        isEnabled: isEnabled,
        hasPermission: hasPermission,
        isServiceRunning: isServiceRunning,
        blockedApps: blockedApps,
      );

      // Start forwarding if enabled and has permission
      if (isEnabled && hasPermission) {
        _startForwarding();
      }

      // Listen for notification actions from watch
      _watchMessageSubscription = _watchService.incomingMessages.listen(_handleWatchMessage);
    } catch (e) {
      debugPrint('NotificationForwardingNotifier init error: $e');
    }
  }

  void _handleWatchMessage(Map<String, dynamic> message) {
    final type = message['t'] as String?;
    if (type != 'notify') return;

    final action = message['n'] as String?;
    // Watch sends 'id' (the notification id we sent), look up the Android key
    final id = message['id'] as int?;
    final key = id != null ? _notificationIdToKey[id] : null;

    if (action == null) return;
    
    debugPrint('Watch notification action: $action, id: $id, key: $key');

    switch (action) {
      case 'DISMISS':
        if (key != null) {
          _notificationService.dismissNotification(key);
          _notificationIdToKey.remove(id); // Clean up
          state = state.copyWith(dismissedCount: state.dismissedCount + 1);
          debugPrint('Dismissed notification with key: $key');
        } else {
          debugPrint('Cannot dismiss: no key found for id $id');
        }
        break;
      case 'DISMISS_ALL':
        // Dismiss all notifications - not directly supported
        break;
      case 'OPEN':
        // Could launch app if we stored the package name
        break;
      case 'MUTE':
        // Mute app - add to blocked list if we have the package
        break;
      case 'REPLY':
        // Reply not implemented - requires direct notification reply action
        break;
    }
  }

  void _startForwarding() {
    _notificationSubscription?.cancel();
    _notificationSubscription = _notificationService.notificationPosted.listen(_forwardNotification);
    
    // Also listen for notification removals to sync dismissals to watch
    _notificationRemovedSubscription?.cancel();
    _notificationRemovedSubscription = _notificationService.notificationRemoved.listen(_handleNotificationRemoved);
    
    debugPrint('Started notification forwarding');
  }

  void _stopForwarding() {
    _notificationSubscription?.cancel();
    _notificationSubscription = null;
    _notificationRemovedSubscription?.cancel();
    _notificationRemovedSubscription = null;
    debugPrint('Stopped notification forwarding');
  }

  void _handleNotificationRemoved(int id) {
    // Sync dismissal to watch if connected
    if (!_watchService.isConnected) {
      return;
    }
    
    // Remove from id-to-key map since it's dismissed
    _notificationIdToKey.remove(id);
    
    // Send dismiss to watch
    _watchService.removeNotification(id);
    debugPrint('Synced notification dismissal to watch: $id');
  }

  void _forwardNotification(PhoneNotification notification) {
    // Don't forward if not enabled or no watch connected
    if (!state.isEnabled) {
      debugPrint('Notification not forwarded: forwarding is disabled');
      return;
    }
    if (!_watchService.isConnected) {
      debugPrint('Notification not forwarded: watch not connected');
      return;
    }

    // Don't forward blocked apps
    if (state.blockedApps.contains(notification.packageName)) {
      debugPrint('Notification blocked: ${notification.appName}');
      return;
    }

    // Don't forward group summaries
    if (notification.isGroupSummary) {
      debugPrint('Notification not forwarded: is group summary');
      return;
    }

    // Deduplication: Skip if we recently sent this notification
    final dedupeKey = '${notification.id}_${notification.packageName}_${notification.title}';
    final now = DateTime.now();
    final lastSent = _recentlySentNotifications[dedupeKey];
    if (lastSent != null) {
      final elapsed = now.difference(lastSent).inMilliseconds;
      if (elapsed < _deduplicationWindowMs) {
        debugPrint('Notification skipped (duplicate within ${elapsed}ms): ${notification.appName}');
        return;
      }
    }
    
    // Clean up old entries periodically
    _recentlySentNotifications.removeWhere((key, time) => 
      now.difference(time).inSeconds > 10
    );
    
    // Record this send
    _recentlySentNotifications[dedupeKey] = now;

    // Store id-to-key mapping for dismiss sync (if key is available)
    if (notification.key != null) {
      _notificationIdToKey[notification.id] = notification.key!;
      // Clean up old entries (keep last 200 notifications)
      if (_notificationIdToKey.length > 200) {
        final keysToRemove = _notificationIdToKey.keys.take(_notificationIdToKey.length - 150).toList();
        for (final k in keysToRemove) {
          _notificationIdToKey.remove(k);
        }
      }
    }

    // Convert to watch notification format and send
    final watchNotification = WatchNotification(
      id: notification.id,
      source: notification.appName,
      title: notification.title,
      body: notification.body,
      sender: notification.sender,
      subject: notification.subject,
      phoneNumber: notification.phoneNumber,
      canReply: notification.canReply,
    );

    _sendNotificationToWatch(watchNotification);
    state = state.copyWith(forwardedCount: state.forwardedCount + 1);
  }

  Future<void> _sendNotificationToWatch(WatchNotification notification) async {
    try {
      await _watchService.sendNotification(
        id: notification.id,
        source: notification.source,
        title: notification.title,
        body: notification.body,
        sender: notification.sender,
        subject: notification.subject,
        phoneNumber: notification.phoneNumber,
        canReply: notification.canReply,
      );
      debugPrint('Forwarded notification: ${notification.source} - ${notification.title}');
    } catch (e) {
      debugPrint('Error forwarding notification: $e');
    }
  }

  /// Enable or disable notification forwarding
  Future<void> setEnabled(bool enabled) async {
    if (!state.hasPermission && enabled) {
      // Request permission first
      await _notificationService.requestNotificationAccess();
      return;
    }

    if (enabled) {
      _startForwarding();
    } else {
      _stopForwarding();
    }

    state = state.copyWith(isEnabled: enabled);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationForwardingEnabledKey, enabled);
  }

  /// Request notification access permission
  Future<void> requestPermission() async {
    await _notificationService.requestNotificationAccess();
  }

  /// Refresh permission status
  Future<void> refreshPermission() async {
    final hasPermission = await _notificationService.isNotificationAccessEnabled();
    final isServiceRunning = await _notificationService.isServiceRunning();
    
    state = state.copyWith(
      hasPermission: hasPermission,
      isServiceRunning: isServiceRunning,
    );

    // If permission was granted and forwarding is enabled, start forwarding
    if (hasPermission && state.isEnabled && _notificationSubscription == null) {
      _startForwarding();
    }
  }

  /// Block an app from notification forwarding
  Future<void> blockApp(String packageName) async {
    final newBlockedApps = {...state.blockedApps, packageName};
    state = state.copyWith(blockedApps: newBlockedApps);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_blockedAppsKey, newBlockedApps.toList());
  }

  /// Unblock an app for notification forwarding
  Future<void> unblockApp(String packageName) async {
    final newBlockedApps = {...state.blockedApps}..remove(packageName);
    state = state.copyWith(blockedApps: newBlockedApps);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_blockedAppsKey, newBlockedApps.toList());
  }

  /// Get list of apps with notification access
  Future<List<AppNotificationFilter>> getNotificationApps() async {
    final apps = await _notificationService.getNotificationApps();
    return apps.map((app) => app.copyWith(
      enabled: !state.blockedApps.contains(app.packageName),
    )).toList();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _notificationRemovedSubscription?.cancel();
    _watchMessageSubscription?.cancel();
    super.dispose();
  }
}

/// Provider for notification forwarding notifier
final notificationForwardingProvider = 
    StateNotifierProvider<NotificationForwardingNotifier, NotificationForwardingState>((ref) {
  final notificationService = ref.watch(notificationServiceProvider);
  final watchService = ref.watch(watchServiceProvider);
  return NotificationForwardingNotifier(notificationService, watchService);
});

/// State class for media control
class MediaControlState {
  final bool isInitialized;
  final String? playbackState; // play, pause, stop
  final int positionSeconds;
  final String? artist;
  final String? album;
  final String? track;
  final int? durationSeconds;

  const MediaControlState({
    this.isInitialized = false,
    this.playbackState,
    this.positionSeconds = 0,
    this.artist,
    this.album,
    this.track,
    this.durationSeconds,
  });

  bool get isPlaying => playbackState == 'play';
  bool get hasMedia => track != null;

  MediaControlState copyWith({
    bool? isInitialized,
    String? playbackState,
    int? positionSeconds,
    String? artist,
    String? album,
    String? track,
    int? durationSeconds,
  }) {
    return MediaControlState(
      isInitialized: isInitialized ?? this.isInitialized,
      playbackState: playbackState ?? this.playbackState,
      positionSeconds: positionSeconds ?? this.positionSeconds,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      track: track ?? this.track,
      durationSeconds: durationSeconds ?? this.durationSeconds,
    );
  }
}

/// Notifier for media control state and actions
class MediaControlNotifier extends StateNotifier<MediaControlState> {
  final MediaService _mediaService;
  final WatchService _watchService;
  
  StreamSubscription<MediaPlaybackState>? _playbackSubscription;
  StreamSubscription<MediaMetadata>? _metadataSubscription;
  StreamSubscription<Map<String, dynamic>>? _watchMessageSubscription;
  StreamSubscription<Connection>? _connectionSubscription;
  
  /// Track previous connection state to detect state changes (not just RSSI updates)
  bool _wasConnected = false;

  MediaControlNotifier(this._mediaService, this._watchService)
      : super(const MediaControlState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    // Listen for connection changes to sync on connect (FR-085)
    // Note: connectionStream emits on RSSI updates too, so we track state changes
    _connectionSubscription = _watchService.connectionStream.listen((connection) {
      final isNowConnected = connection.isConnected;
      // Only sync when transitioning from disconnected to connected
      if (isNowConnected && !_wasConnected) {
        // Small delay to ensure NUS is set up
        Future.delayed(const Duration(milliseconds: 500), () {
          syncCurrentStateToWatch();
        });
      }
      _wasConnected = isNowConnected;
    });

    if (!Platform.isAndroid) {
      // iOS uses AMS - nothing to initialize
      return;
    }

    try {
      final success = await _mediaService.initialize();
      state = state.copyWith(isInitialized: success);

      if (success) {
        // Listen for playback state changes
        _playbackSubscription = _mediaService.playbackStateStream.listen((playbackState) {
          final oldState = state.playbackState;
          final oldPosition = state.positionSeconds;
          
          state = state.copyWith(
            playbackState: playbackState.state,
            positionSeconds: playbackState.positionSeconds,
          );
          
          // Only send if state actually changed
          if (oldState != playbackState.state || oldPosition != playbackState.positionSeconds) {
            _sendStateToWatch();
          }
        });

        // Listen for metadata changes
        _metadataSubscription = _mediaService.metadataStream.listen((metadata) {
          final oldTrack = state.track;
          final oldArtist = state.artist;
          final oldAlbum = state.album;
          
          state = state.copyWith(
            artist: metadata.artist,
            album: metadata.album,
            track: metadata.track,
            durationSeconds: metadata.durationSeconds,
          );
          
          // Only send if metadata actually changed
          if (oldTrack != metadata.track || oldArtist != metadata.artist || oldAlbum != metadata.album) {
            _sendInfoToWatch();
          }
        });

        // Listen for music control from watch
        _watchMessageSubscription = _watchService.incomingMessages.listen(_handleWatchMessage);
      }
    } catch (e) {
      debugPrint('MediaControlNotifier init error: $e');
    }
  }

  void _handleWatchMessage(Map<String, dynamic> message) {
    final type = message['t'] as String?;
    if (type != 'music') return;

    final action = message['n'] as String?;
    if (action == null) return;

    debugPrint('Music control from watch: $action');

    switch (action) {
      case 'play':
        _mediaService.play();
        break;
      case 'pause':
        _mediaService.pause();
        break;
      case 'next':
        _mediaService.next();
        break;
      case 'previous':
        _mediaService.previous();
        break;
      case 'volumeup':
        _mediaService.volumeUp();
        break;
      case 'volumedown':
        _mediaService.volumeDown();
        break;
    }
  }

  Future<void> _sendStateToWatch() async {
    if (!_watchService.isConnected) return;
    if (state.playbackState == null) return;
    
    try {
      await _watchService.sendMusicState(
        state: state.playbackState!,
        positionSeconds: state.positionSeconds,
      );
      debugPrint('Sent music state to watch: ${state.playbackState}');
    } catch (e) {
      debugPrint('Error sending music state: $e');
    }
  }

  Future<void> _sendInfoToWatch() async {
    if (!_watchService.isConnected) return;
    if (state.track == null) return;
    
    try {
      await _watchService.sendMusicInfo(
        artist: state.artist,
        album: state.album,
        track: state.track,
        durationSeconds: state.durationSeconds,
      );
      debugPrint('Sent music info to watch: ${state.artist} - ${state.track}');
    } catch (e) {
      debugPrint('Error sending music info: $e');
    }
  }

  /// Manually refresh media state
  Future<void> refresh() async {
    if (!Platform.isAndroid) return;

    final hasSession = await _mediaService.hasActiveSession();
    if (!hasSession) {
      state = const MediaControlState(isInitialized: true);
      return;
    }

    // State will be updated via streams when we reinitialize
  }

  /// Send current media state to watch (FR-085)
  /// Call this on connection to sync initial state
  Future<void> syncCurrentStateToWatch() async {
    if (!Platform.isAndroid) return;
    if (!_watchService.isConnected) return;

    debugPrint('[MediaControl] Syncing current media state to watch');

    // Fetch fresh state from Android with up-to-date position calculation
    await _mediaService.fetchCurrentState();

    // Send playback state if available
    if (state.playbackState != null) {
      await _sendStateToWatch();
    }

    // Send metadata if available
    if (state.track != null) {
      await _sendInfoToWatch();
    }
  }

  @override
  void dispose() {
    _playbackSubscription?.cancel();
    _metadataSubscription?.cancel();
    _watchMessageSubscription?.cancel();
    _connectionSubscription?.cancel();
    super.dispose();
  }
}

/// Provider for media control notifier
final mediaControlProvider = 
    StateNotifierProvider<MediaControlNotifier, MediaControlState>((ref) {
  final mediaService = ref.watch(mediaServiceProvider);
  final watchService = ref.watch(watchServiceProvider);
  return MediaControlNotifier(mediaService, watchService);
});

/// Provider for whether notification forwarding is supported
final isNotificationForwardingSupported = Provider<bool>((ref) {
  return Platform.isAndroid;
});

/// Provider for whether media control is supported
final isMediaControlSupported = Provider<bool>((ref) {
  return Platform.isAndroid;
});

