import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  StreamSubscription<Map<String, dynamic>>? _watchMessageSubscription;

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
    final key = message['key'] as String?;

    if (action == null) return;

    switch (action) {
      case 'DISMISS':
        if (key != null) {
          _notificationService.dismissNotification(key);
          state = state.copyWith(dismissedCount: state.dismissedCount + 1);
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
    debugPrint('Started notification forwarding');
  }

  void _stopForwarding() {
    _notificationSubscription?.cancel();
    _notificationSubscription = null;
    debugPrint('Stopped notification forwarding');
  }

  void _forwardNotification(PhoneNotification notification) {
    // Don't forward if not enabled or no watch connected
    if (!state.isEnabled) return;
    if (!_watchService.isConnected) return;

    // Don't forward blocked apps
    if (state.blockedApps.contains(notification.packageName)) {
      debugPrint('Notification blocked: ${notification.appName}');
      return;
    }

    // Don't forward group summaries
    if (notification.isGroupSummary) {
      return;
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

  MediaControlNotifier(this._mediaService, this._watchService)
      : super(const MediaControlState()) {
    _initialize();
  }

  Future<void> _initialize() async {
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
          state = state.copyWith(
            playbackState: playbackState.state,
            positionSeconds: playbackState.positionSeconds,
          );
          _sendStateToWatch();
        });

        // Listen for metadata changes
        _metadataSubscription = _mediaService.metadataStream.listen((metadata) {
          state = state.copyWith(
            artist: metadata.artist,
            album: metadata.album,
            track: metadata.track,
            durationSeconds: metadata.durationSeconds,
          );
          _sendInfoToWatch();
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

  @override
  void dispose() {
    _playbackSubscription?.cancel();
    _metadataSubscription?.cancel();
    _watchMessageSubscription?.cancel();
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

