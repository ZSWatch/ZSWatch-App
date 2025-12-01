package com.example.zswatch_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import kotlin.random.Random

/**
 * Utility for posting native Android notifications from the debug tools.
 *
 * The notification carries a dedicated extra so the listener service can treat
 * it as a debug notification and allow it to flow through the forwarding stack.
 */
object NotificationDebugHelper {
    const val EXTRA_DEBUG_NOTIFICATION = "zsw_debug_notification"

    private const val CHANNEL_ID = "zsw_debug_notifications"
    private const val CHANNEL_NAME = "ZSWatch Debug"
    private const val CHANNEL_DESCRIPTION = "Debug notifications for testing watch forwarding"
    private const val DEBUG_TAG = "zsw_debug_notification"

    /**
     * Post a debug notification and return the id/tag that Android will surface
     * to the NotificationListenerService.
     */
    fun postDebugNotification(context: Context, title: String, body: String): Map<String, Any?> {
        createChannel(context)

        val notificationId = Random.nextInt(1, Int.MAX_VALUE)

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setExtras(
                Bundle().apply {
                    putBoolean(EXTRA_DEBUG_NOTIFICATION, true)
                }
            )
            .build()

        NotificationManagerCompat.from(context).notify(DEBUG_TAG, notificationId, notification)

        return mapOf(
            "id" to notificationId,
            "tag" to DEBUG_TAG,
            "channelId" to CHANNEL_ID
        )
    }

    private fun createChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            NotificationManager.IMPORTANCE_DEFAULT
        ).apply {
            description = CHANNEL_DESCRIPTION
            enableLights(true)
            lightColor = Color.GREEN
        }

        manager.createNotificationChannel(channel)
    }
}
