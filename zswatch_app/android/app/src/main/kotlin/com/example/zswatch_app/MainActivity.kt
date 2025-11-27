package com.example.zswatch_app

import android.content.Intent
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Main activity for ZSWatch companion app.
 * 
 * Sets up MethodChannels for:
 * - Notification forwarding (NotificationListenerService)
 * - Media control (MediaSession)
 */
class MainActivity : FlutterActivity() {
    
    companion object {
        private const val NOTIFICATION_CHANNEL = "com.example.zswatch_app/notifications"
        private const val NOTIFICATION_EVENTS_CHANNEL = "com.example.zswatch_app/notification_events"
        private const val MEDIA_CHANNEL = "com.example.zswatch_app/media"
        private const val MEDIA_EVENTS_CHANNEL = "com.example.zswatch_app/media_events"
    }
    
    private var mediaBridge: MediaSessionBridge? = null
    private var notificationEventSink: EventChannel.EventSink? = null
    private var mediaEventSink: EventChannel.EventSink? = null
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        setupNotificationChannel(flutterEngine)
        setupMediaChannel(flutterEngine)
    }
    
    private fun setupNotificationChannel(flutterEngine: FlutterEngine) {
        // Method channel for notification commands
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATION_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isNotificationAccessEnabled" -> {
                    val enabled = NotificationListenerServiceImpl.isNotificationAccessEnabled(this)
                    result.success(enabled)
                }
                "requestNotificationAccess" -> {
                    val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                    startActivity(intent)
                    result.success(null)
                }
                "getActiveNotifications" -> {
                    val notifications = NotificationListenerServiceImpl.getActiveNotifications()
                    result.success(notifications)
                }
                "dismissNotification" -> {
                    val key = call.argument<String>("key")
                    if (key != null) {
                        NotificationListenerServiceImpl.dismissNotification(key)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENT", "key is required", null)
                    }
                }
                "getNotificationApps" -> {
                    val apps = NotificationListenerServiceImpl.getNotificationApps(this)
                    result.success(apps)
                }
                "isServiceRunning" -> {
                    result.success(NotificationListenerServiceImpl.isRunning)
                }
                else -> result.notImplemented()
            }
        }
        
        // Event channel for notification events (posted/removed)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATION_EVENTS_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    android.util.Log.d("ZSWNotificationBridge", "Flutter started listening to notification events")
                    notificationEventSink = events
                    
                    // Set up callback to forward notifications to Flutter
                    NotificationListenerServiceImpl.notificationCallback = object : NotificationListenerServiceImpl.NotificationCallback {
                        override fun onNotificationPosted(notification: Map<String, Any?>) {
                            android.util.Log.d("ZSWNotificationBridge", "Callback invoked, forwarding to Flutter event sink")
                            runOnUiThread {
                                notificationEventSink?.success(mapOf(
                                    "event" to "posted",
                                    "notification" to notification
                                ))
                            }
                        }
                        
                        override fun onNotificationRemoved(notification: Map<String, Any?>) {
                            runOnUiThread {
                                notificationEventSink?.success(mapOf(
                                    "event" to "removed",
                                    "notification" to notification
                                ))
                            }
                        }
                    }
                }
                
                override fun onCancel(arguments: Any?) {
                    android.util.Log.d("ZSWNotificationBridge", "Flutter stopped listening to notification events")
                    notificationEventSink = null
                    NotificationListenerServiceImpl.notificationCallback = null
                }
            }
        )
    }
    
    private fun setupMediaChannel(flutterEngine: FlutterEngine) {
        mediaBridge = MediaSessionBridge(this)
        
        // Method channel for media commands
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MEDIA_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> {
                    val success = mediaBridge?.initialize() ?: false
                    result.success(success)
                }
                "dispose" -> {
                    mediaBridge?.dispose()
                    result.success(null)
                }
                "play" -> {
                    val success = mediaBridge?.play() ?: false
                    result.success(success)
                }
                "pause" -> {
                    val success = mediaBridge?.pause() ?: false
                    result.success(success)
                }
                "playPause" -> {
                    val success = mediaBridge?.playPause() ?: false
                    result.success(success)
                }
                "next" -> {
                    val success = mediaBridge?.next() ?: false
                    result.success(success)
                }
                "previous" -> {
                    val success = mediaBridge?.previous() ?: false
                    result.success(success)
                }
                "volumeUp" -> {
                    val success = mediaBridge?.volumeUp() ?: false
                    result.success(success)
                }
                "volumeDown" -> {
                    val success = mediaBridge?.volumeDown() ?: false
                    result.success(success)
                }
                "seekTo" -> {
                    val position = call.argument<Int>("position") ?: 0
                    val success = mediaBridge?.seekTo(position) ?: false
                    result.success(success)
                }
                "getCurrentState" -> {
                    val state = mediaBridge?.getCurrentState()
                    result.success(state)
                }
                "hasActiveSession" -> {
                    val hasSession = mediaBridge?.hasActiveSession() ?: false
                    result.success(hasSession)
                }
                else -> result.notImplemented()
            }
        }
        
        // Event channel for media events (state/metadata changes)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, MEDIA_EVENTS_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    mediaEventSink = events
                    
                    mediaBridge?.setCallback(object : MediaSessionBridge.MediaCallback {
                        override fun onPlaybackStateChanged(state: Map<String, Any?>) {
                            runOnUiThread {
                                mediaEventSink?.success(mapOf(
                                    "event" to "playbackState",
                                    "data" to state
                                ))
                            }
                        }
                        
                        override fun onMetadataChanged(metadata: Map<String, Any?>) {
                            runOnUiThread {
                                mediaEventSink?.success(mapOf(
                                    "event" to "metadata",
                                    "data" to metadata
                                ))
                            }
                        }
                    })
                }
                
                override fun onCancel(arguments: Any?) {
                    mediaEventSink = null
                    mediaBridge?.setCallback(null)
                }
            }
        )
    }
    
    override fun onDestroy() {
        mediaBridge?.dispose()
        mediaBridge = null
        NotificationListenerServiceImpl.notificationCallback = null
        super.onDestroy()
    }
}
