package dev.zswatch.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * Foreground execution window for local audio/AI processing. The wake lock
 * prevents CPU sleep; it does not guarantee CPU frequency or inference speed.
 */
class LlmComputeService : Service() {

    companion object {
        private const val TAG = "LlmComputeService"
        const val CHANNEL_ID = "llm_compute"
        const val CHANNEL_NAME = "AI Processing"
        const val NOTIFICATION_ID = 1002

        const val ACTION_START = "dev.zswatch.app.LLM_START"
        const val ACTION_STOP = "dev.zswatch.app.LLM_STOP"

        private var instance: LlmComputeService? = null
        private val main = Handler(Looper.getMainLooper())
        private var admission: ((Boolean) -> Unit)? = null
        private var interruption: (() -> Unit)? = null

        fun startForJob(context: Context, ready: (Boolean) -> Unit, interrupted: () -> Unit) {
            main.post {
                admission = ready
                interruption = interrupted
                try { start(context) } catch (error: Exception) {
                    admission = null; interruption = null
                    ready(false)
                }
            }
        }

        fun isRunning(): Boolean = instance != null

        fun start(context: Context) {
            val intent = Intent(context, LlmComputeService::class.java).apply {
                action = ACTION_START
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            main.post {
                admission = null; interruption = null
                context.stopService(Intent(context, LlmComputeService::class.java))
            }
        }

        fun createNotificationChannel(context: Context) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    CHANNEL_NAME,
                    NotificationManager.IMPORTANCE_LOW
                ).apply {
                    description = "Shown while processing voice commands with on-device AI"
                    setShowBadge(false)
                    enableLights(false)
                    enableVibration(false)
                }
                val nm = context.getSystemService(NotificationManager::class.java)
                nm?.createNotificationChannel(channel)
            }
        }
    }

    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel(this)
        instance = this
        Log.d(TAG, "Service created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                try {
                    startForegroundWithNotification()
                    acquireWakeLock()
                    val callback = admission; admission = null
                    callback?.invoke(true)
                } catch (error: Exception) {
                    Log.w(TAG, "Foreground execution denied: ${error.javaClass.simpleName}")
                    val callback = admission; admission = null; interruption = null
                    callback?.invoke(false)
                    stopSelf()
                }
            }
            ACTION_STOP -> {
                releaseWakeLock()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        releaseWakeLock()
        instance = null
        val pending = admission; admission = null
        val interrupted = interruption; interruption = null
        pending?.invoke(false)
        interrupted?.invoke()
        Log.d(TAG, "Service destroyed")
        super.onDestroy()
    }

    override fun onTimeout(startId: Int, fgsType: Int) {
        // Android 15's media-processing budget is shared across service starts.
        releaseWakeLock()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun startForegroundWithNotification() {
        val openAppIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        } ?: Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this, 0, openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Processing voice command…")
            .setContentText("On-device AI is running")
            .setSmallIcon(android.R.drawable.ic_menu_manage)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setSilent(true)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                if (Build.VERSION.SDK_INT >= 35) ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROCESSING
                else ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
            )
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, 0)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        Log.d(TAG, "Foreground notification posted")
    }

    private fun acquireWakeLock() {
        if (wakeLock == null) {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = pm.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "ZSWatch::LlmCompute"
            ).apply {
                // Matches the native job's 15-minute execution limit.
                acquire(15 * 60 * 1000L)
            }
            Log.d(TAG, "Wake lock acquired")
        }
    }

    private fun releaseWakeLock() {
        wakeLock?.let {
            if (it.isHeld) {
                it.release()
                Log.d(TAG, "Wake lock released")
            }
        }
        wakeLock = null
    }
}
