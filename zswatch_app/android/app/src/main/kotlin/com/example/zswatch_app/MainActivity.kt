package com.example.zswatch_app

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.net.Uri
import android.os.Bundle
import android.os.IBinder
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
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
 * - Foreground service for persistent BLE connection
 */
class MainActivity : FlutterActivity() {
    
    companion object {
        private const val NOTIFICATION_CHANNEL = "com.example.zswatch_app/notifications"
        private const val NOTIFICATION_EVENTS_CHANNEL = "com.example.zswatch_app/notification_events"
        private const val MEDIA_CHANNEL = "com.example.zswatch_app/media"
        private const val MEDIA_EVENTS_CHANNEL = "com.example.zswatch_app/media_events"
        private const val FOREGROUND_SERVICE_CHANNEL = "com.example.zswatch_app/foreground_service"
    }
    
    private var mediaBridge: MediaSessionBridge? = null
    private var notificationEventSink: EventChannel.EventSink? = null
    private var mediaEventSink: EventChannel.EventSink? = null
    
    // Foreground service
    private var foregroundService: BleConnectionForegroundService? = null
    private var foregroundServiceBound = false
    private var pendingDisconnectCallback: (() -> Unit)? = null
    
    private val foregroundServiceConnection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, service: IBinder?) {
            val binder = service as BleConnectionForegroundService.LocalBinder
            foregroundService = binder.getService()
            foregroundServiceBound = true
            
            // Set up disconnect callback
            foregroundService?.onDisconnectRequested = {
                pendingDisconnectCallback?.invoke()
            }
        }
        
        override fun onServiceDisconnected(name: ComponentName?) {
            foregroundService = null
            foregroundServiceBound = false
        }
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Create notification channel for foreground service (FR-092)
        BleConnectionForegroundService.createNotificationChannel(this)
    }
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        setupNotificationChannel(flutterEngine)
        setupMediaChannel(flutterEngine)
        setupForegroundServiceChannel(flutterEngine)
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
                "sendTestNotification" -> {
                    val title = call.argument<String>("title") ?: "ZSWatch debug notification"
                    val body = call.argument<String>("body") ?: "This is a native Android test notification."

                    val notificationsEnabled = NotificationManagerCompat.from(this).areNotificationsEnabled()
                    if (!notificationsEnabled) {
                        result.error(
                            "NOTIFICATIONS_DISABLED",
                            "Posting notifications is not allowed (permission not granted)",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    try {
                        val posted = NotificationDebugHelper.postDebugNotification(this, title, body)
                        result.success(posted)
                    } catch (e: SecurityException) {
                        result.error(
                            "NOTIFICATION_PERMISSION",
                            "Missing POST_NOTIFICATIONS permission",
                            e.localizedMessage
                        )
                    } catch (e: Exception) {
                        result.error(
                            "NOTIFICATION_ERROR",
                            e.localizedMessage ?: "Failed to post notification",
                            null
                        )
                    }
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
    
    private fun setupForegroundServiceChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FOREGROUND_SERVICE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val watchName = call.argument<String>("watchName") ?: "ZSWatch"
                    val connectionState = call.argument<String>("connectionState") 
                        ?: BleConnectionForegroundService.STATE_CONNECTED
                    
                    BleConnectionForegroundService.start(this, watchName, connectionState)
                    
                    // Bind to service to receive disconnect callbacks
                    val intent = Intent(this, BleConnectionForegroundService::class.java)
                    bindService(intent, foregroundServiceConnection, Context.BIND_AUTO_CREATE)
                    
                    result.success(true)
                }
                "stop" -> {
                    if (foregroundServiceBound) {
                        unbindService(foregroundServiceConnection)
                        foregroundServiceBound = false
                    }
                    BleConnectionForegroundService.stop(this)
                    result.success(true)
                }
                "updateNotification" -> {
                    val watchName = call.argument<String>("watchName") ?: "ZSWatch"
                    val connectionState = call.argument<String>("connectionState") 
                        ?: BleConnectionForegroundService.STATE_CONNECTED
                    
                    BleConnectionForegroundService.updateNotification(this, watchName, connectionState)
                    result.success(true)
                }
                "isRunning" -> {
                    result.success(BleConnectionForegroundService.isRunning())
                }
                "isBatteryOptimizationDisabled" -> {
                    val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                    val isIgnoring = pm.isIgnoringBatteryOptimizations(packageName)
                    result.success(isIgnoring)
                }
                "requestDisableBatteryOptimization" -> {
                    try {
                        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                            data = Uri.parse("package:$packageName")
                        }
                        if (intent.resolveActivity(packageManager) != null) {
                            startActivity(intent)
                            result.success(true)
                        } else {
                            android.util.Log.e("MainActivity", "No activity to handle ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS")
                            // Fallback to general battery optimization settings
                            val fallbackIntent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                            startActivity(fallbackIntent)
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        android.util.Log.e("MainActivity", "Failed to request battery optimization exemption", e)
                        result.error("BATTERY_OPT_ERROR", e.localizedMessage, null)
                    }
                }
                "openBatteryOptimizationSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                        if (intent.resolveActivity(packageManager) != null) {
                            startActivity(intent)
                            result.success(true)
                        } else {
                            android.util.Log.e("MainActivity", "No activity to handle ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS")
                            // Fallback to app detail settings
                            val fallbackIntent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.parse("package:$packageName")
                            }
                            startActivity(fallbackIntent)
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        android.util.Log.e("MainActivity", "Failed to open battery optimization settings", e)
                        result.error("BATTERY_OPT_SETTINGS_ERROR", e.localizedMessage, null)
                    }
                }
                "setDisconnectCallback" -> {
                    // Store callback ID to invoke later
                    // For now, we'll use event channel for this
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
        
        // Set up disconnect callback to notify Flutter
        pendingDisconnectCallback = {
            // Use method channel to notify Flutter of disconnect request
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FOREGROUND_SERVICE_CHANNEL)
                .invokeMethod("onDisconnectRequested", null)
        }
    }
    
    override fun onDestroy() {
        if (foregroundServiceBound) {
            unbindService(foregroundServiceConnection)
            foregroundServiceBound = false
        }
        mediaBridge?.dispose()
        mediaBridge = null
        NotificationListenerServiceImpl.notificationCallback = null
        super.onDestroy()
    }
}
