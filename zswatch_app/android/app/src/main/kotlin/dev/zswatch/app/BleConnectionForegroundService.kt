package dev.zswatch.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Binder
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * Foreground service for maintaining persistent BLE connection (FR-089 to FR-092)
 *
 * This service:
 * - Keeps the app process alive when backgrounded
 * - Shows a persistent notification indicating connection status
 * - Allows the BLE connection to remain active for notification forwarding
 *
 * The service itself doesn't manage BLE - that's done by flutter_blue_plus.
 * This service just keeps the app alive and shows status to the user.
 */
class BleConnectionForegroundService : Service() {

    companion object {
        private const val TAG = "BleConnectionService"
        const val CHANNEL_ID = "ble_connection"
        const val CHANNEL_NAME = "Watch Connection"
        const val NOTIFICATION_ID = 1001

        const val ACTION_START = "dev.zswatch.app.START_FOREGROUND"
        const val ACTION_STOP = "dev.zswatch.app.STOP_FOREGROUND"
        const val ACTION_UPDATE = "dev.zswatch.app.UPDATE_NOTIFICATION"
        const val ACTION_DISCONNECT = "dev.zswatch.app.DISCONNECT"

        const val EXTRA_WATCH_NAME = "watch_name"
        const val EXTRA_CONNECTION_STATE = "connection_state"

        // Connection states
        const val STATE_CONNECTED = "connected"
        const val STATE_WATCHER = "watcher"
        const val STATE_RECONNECTING = "reconnecting"
        const val STATE_DISCONNECTED = "disconnected"
        const val STATE_APP_KILLED = "app_killed"

        private var instance: BleConnectionForegroundService? = null

        /**
         * Check if the service is currently running
         */
        fun isRunning(): Boolean = instance != null

        /**
         * Start the foreground service
         */
        fun start(context: Context, watchName: String, connectionState: String = STATE_CONNECTED): Boolean {
            val intent = Intent(context, BleConnectionForegroundService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_WATCH_NAME, watchName)
                putExtra(EXTRA_CONNECTION_STATE, connectionState)
            }
            return try {
                LifecycleLogger.log("BleConnectionService", "start requested watchName=$watchName state=$connectionState")
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
                true
            } catch (e: Exception) {
                LifecycleLogger.log("BleConnectionService", "start failed: ${e.javaClass.simpleName}: ${e.message}")
                false
            }
        }

        /**
         * Stop the foreground service
         */
        fun stop(context: Context): Boolean {
            val intent = Intent(context, BleConnectionForegroundService::class.java).apply {
                action = ACTION_STOP
            }
            return try {
                LifecycleLogger.log("BleConnectionService", "stop requested")
                context.startService(intent)
                true
            } catch (e: Exception) {
                LifecycleLogger.log("BleConnectionService", "stop failed: ${e.javaClass.simpleName}: ${e.message}")
                false
            }
        }

        /**
         * Update the notification text
         */
        fun updateNotification(context: Context, watchName: String, connectionState: String): Boolean {
            if (!isRunning()) return false
            val intent = Intent(context, BleConnectionForegroundService::class.java).apply {
                action = ACTION_UPDATE
                putExtra(EXTRA_WATCH_NAME, watchName)
                putExtra(EXTRA_CONNECTION_STATE, connectionState)
            }
            return try {
                LifecycleLogger.log("BleConnectionService", "update requested watchName=$watchName state=$connectionState")
                context.startService(intent)
                true
            } catch (e: Exception) {
                LifecycleLogger.log("BleConnectionService", "update failed: ${e.javaClass.simpleName}: ${e.message}")
                false
            }
        }

        /**
         * Create the notification channel (call on app startup)
         */
        fun createNotificationChannel(context: Context) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    CHANNEL_NAME,
                    NotificationManager.IMPORTANCE_LOW // Low importance for minimal intrusiveness
                ).apply {
                    description = "Shows watch connection status"
                    setShowBadge(false)
                    enableLights(false)
                    enableVibration(false)
                }
                val notificationManager = context.getSystemService(NotificationManager::class.java)
                notificationManager?.createNotificationChannel(channel)
                Log.d(TAG, "Notification channel created")
                LifecycleLogger.log(TAG, "notification channel created")
            }
        }
    }

    private val binder = LocalBinder()
    private var currentWatchName: String = "ZSWatch"
    private var currentState: String = STATE_DISCONNECTED

    // Callback for disconnect action
    var onDisconnectRequested: (() -> Unit)? = null

    inner class LocalBinder : Binder() {
        fun getService(): BleConnectionForegroundService = this@BleConnectionForegroundService
    }

    override fun onBind(intent: Intent?): IBinder {
        LifecycleLogger.log(TAG, "onBind action=${intent?.action}")
        return binder
    }

    override fun onUnbind(intent: Intent?): Boolean {
        LifecycleLogger.log(TAG, "onUnbind action=${intent?.action}")
        onDisconnectRequested = null
        return super.onUnbind(intent)
    }

    override fun onCreate() {
        super.onCreate()
        LifecycleLogger.initialize(applicationContext)
        LifecycleLogger.recordHistoricalExitReasons(applicationContext)
        LifecycleLogger.recordStartupCause(
            source = "foreground_service",
            detail = "service=${javaClass.simpleName}",
        )
        instance = this
        Log.d(TAG, "Service created")
        LifecycleLogger.log(TAG, "onCreate")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        LifecycleLogger.log(
            TAG,
            "onStartCommand action=${intent?.action} flags=$flags startId=$startId state=$currentState watch=$currentWatchName",
        )
        when (intent?.action) {
            ACTION_START -> {
                currentWatchName = intent.getStringExtra(EXTRA_WATCH_NAME) ?: "ZSWatch"
                currentState = intent.getStringExtra(EXTRA_CONNECTION_STATE) ?: STATE_CONNECTED
                startForegroundWithNotification()
            }
            ACTION_STOP -> {
                stopForegroundService()
            }
            ACTION_UPDATE -> {
                currentWatchName = intent.getStringExtra(EXTRA_WATCH_NAME) ?: currentWatchName
                currentState = intent.getStringExtra(EXTRA_CONNECTION_STATE) ?: currentState
                updateNotificationContent()
            }
            ACTION_DISCONNECT -> {
                Log.d(TAG, "Disconnect action triggered")
                LifecycleLogger.log(TAG, "disconnect/exit action triggered callbackAvailable=${onDisconnectRequested != null}")
                // Try to notify Flutter, but also handle locally if Flutter is not available
                onDisconnectRequested?.invoke()
                
                // Always stop the service when disconnect is pressed
                // The BLE disconnect will be handled by Flutter if available,
                // or user can reconnect manually
                stopForegroundService()
            }
        }
        return START_STICKY
    }

    private fun startForegroundWithNotification() {
        Log.d(TAG, "Starting foreground service for $currentWatchName")
        LifecycleLogger.log(TAG, "startForegroundWithNotification state=$currentState watch=$currentWatchName")
        
        val notification = buildNotification()

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (e: Exception) {
            LifecycleLogger.log(TAG, "startForeground failed: ${e.javaClass.simpleName}: ${e.message}")
            stopSelf()
        }
    }

    private fun buildNotification(): Notification {
        // Intent to open the app when notification is tapped
        val openAppIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val openAppPendingIntent = PendingIntent.getActivity(
            this,
            0,
            openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Intent for disconnect action
        val disconnectIntent = Intent(this, BleConnectionForegroundService::class.java).apply {
            action = ACTION_DISCONNECT
        }
        val disconnectPendingIntent = PendingIntent.getService(
            this,
            1,
            disconnectIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val (title, text, icon) = when (currentState) {
            STATE_CONNECTED -> Triple(
                "Connected to $currentWatchName",
                "ZSWatch companion is running",
                android.R.drawable.stat_sys_data_bluetooth
            )
            STATE_WATCHER -> Triple(
                "Watching $currentWatchName in background",
                "Keeping the companion ready while the app is hidden",
                android.R.drawable.stat_notify_sync_noanim
            )
            STATE_RECONNECTING -> Triple(
                "Reconnecting to $currentWatchName...",
                "Waiting for watch to be in range",
                android.R.drawable.stat_notify_sync
            )
            STATE_APP_KILLED -> Triple(
                "Reopen ZSWatch to restore BLE",
                "Flutter stopped; tap to reconnect the watch",
                android.R.drawable.stat_notify_error
            )
            else -> Triple(
                "ZSWatch Companion",
                "Background service running",
                android.R.drawable.stat_sys_data_bluetooth
            )
        }

        val actionLabel = if (currentState == STATE_APP_KILLED) "Exit" else "Disconnect"

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text))
            .setSmallIcon(icon)
            .setOngoing(true)
            .setContentIntent(openAppPendingIntent)
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                actionLabel,
                disconnectPendingIntent
            )
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setOnlyAlertOnce(true)
            .build()
    }

    private fun updateNotificationContent() {
        LifecycleLogger.log(TAG, "updateNotificationContent state=$currentState watch=$currentWatchName")
        val notificationManager = getSystemService(NotificationManager::class.java)
        notificationManager?.notify(NOTIFICATION_ID, buildNotification())
    }

    private fun stopForegroundService() {
        Log.d(TAG, "Stopping foreground service")
        LifecycleLogger.log(TAG, "stopForegroundService state=$currentState watch=$currentWatchName")
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        Log.d(TAG, "App task removed (swiped away), updating notification warning")
        LifecycleLogger.log(TAG, "onTaskRemoved rootAction=${rootIntent?.action} rootData=${rootIntent?.dataString}")
        // Flutter engine is dead at this point — BLE connection is lost.
        // Keep notification visible as a warning so the user knows.
        currentState = STATE_APP_KILLED
        updateNotificationContent()
        super.onTaskRemoved(rootIntent)
    }

    override fun onTrimMemory(level: Int) {
        LifecycleLogger.log(
            TAG,
            "onTrimMemory level=$level label=${LifecycleLogger.trimMemoryLevelLabel(level)} state=$currentState watch=$currentWatchName",
        )
        super.onTrimMemory(level)
    }

    override fun onLowMemory() {
        LifecycleLogger.log(TAG, "onLowMemory state=$currentState watch=$currentWatchName")
        super.onLowMemory()
    }

    override fun onDestroy() {
        instance = null
        Log.d(TAG, "Service destroyed")
        LifecycleLogger.log(TAG, "onDestroy state=$currentState watch=$currentWatchName")
        super.onDestroy()
    }
}
