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
        fun start(context: Context, watchName: String, connectionState: String = STATE_CONNECTED) {
            val intent = Intent(context, BleConnectionForegroundService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_WATCH_NAME, watchName)
                putExtra(EXTRA_CONNECTION_STATE, connectionState)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        /**
         * Stop the foreground service
         */
        fun stop(context: Context) {
            val intent = Intent(context, BleConnectionForegroundService::class.java).apply {
                action = ACTION_STOP
            }
            context.startService(intent)
        }

        /**
         * Update the notification text
         */
        fun updateNotification(context: Context, watchName: String, connectionState: String) {
            if (!isRunning()) return
            val intent = Intent(context, BleConnectionForegroundService::class.java).apply {
                action = ACTION_UPDATE
                putExtra(EXTRA_WATCH_NAME, watchName)
                putExtra(EXTRA_CONNECTION_STATE, connectionState)
            }
            context.startService(intent)
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

    override fun onBind(intent: Intent?): IBinder = binder

    override fun onCreate() {
        super.onCreate()
        instance = this
        Log.d(TAG, "Service created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
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
                // Try to notify Flutter, but also handle locally if Flutter is not available
                val callbackInvoked = onDisconnectRequested != null
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
        
        val notification = buildNotification()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
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
            STATE_RECONNECTING -> Triple(
                "Reconnecting to $currentWatchName...",
                "Waiting for watch to be in range",
                android.R.drawable.stat_notify_sync
            )
            STATE_APP_KILLED -> Triple(
                "App killed — restart needed",
                "Connection lost, tap to reopen",
                android.R.drawable.stat_notify_error
            )
            else -> Triple(
                "ZSWatch Companion",
                "Background service running",
                android.R.drawable.stat_sys_data_bluetooth
            )
        }

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(icon)
            .setOngoing(true)
            .setContentIntent(openAppPendingIntent)
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "Disconnect",
                disconnectPendingIntent
            )
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }

    private fun updateNotificationContent() {
        val notificationManager = getSystemService(NotificationManager::class.java)
        notificationManager?.notify(NOTIFICATION_ID, buildNotification())
    }

    private fun stopForegroundService() {
        Log.d(TAG, "Stopping foreground service")
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        Log.d(TAG, "App task removed (swiped away), updating notification warning")
        // Flutter engine is dead at this point — BLE connection is lost.
        // Keep notification visible as a warning so the user knows.
        currentState = STATE_APP_KILLED
        updateNotificationContent()
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        instance = null
        Log.d(TAG, "Service destroyed")
        super.onDestroy()
    }
}
