package com.example.zswatch_app

import android.app.Notification
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.os.Build
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Base64
import android.util.Log
import java.io.ByteArrayOutputStream

/**
 * NotificationListenerService implementation that forwards Android notifications to Flutter.
 * 
 * This service:
 * - Listens to all posted/removed notifications
 * - Extracts relevant notification data
 * - Sends notification events to Flutter via a shared singleton
 * 
 * Note: User must grant notification access permission in system settings.
 */
class NotificationListenerServiceImpl : NotificationListenerService() {

    companion object {
        private const val TAG = "ZSWNotificationService"
        
        // Singleton instance for communication with Flutter
        private var instance: NotificationListenerServiceImpl? = null
        
        // Callback for notification events (set by Flutter plugin)
        var notificationCallback: NotificationCallback? = null
        
        // Check if service is running
        val isRunning: Boolean
            get() = instance != null
        
        // Check if notification access is enabled
        fun isNotificationAccessEnabled(context: android.content.Context): Boolean {
            val cn = ComponentName(context, NotificationListenerServiceImpl::class.java)
            val flat = android.provider.Settings.Secure.getString(
                context.contentResolver,
                "enabled_notification_listeners"
            )
            return flat != null && flat.contains(cn.flattenToString())
        }
        
        // Get currently active notifications
        fun getActiveNotifications(): List<Map<String, Any?>> {
            return instance?.activeNotifications
                ?.filter { !it.isOngoing }
                ?.mapNotNull { sbn -> instance?.extractNotificationData(sbn) }
                ?: emptyList()
        }
        
        // Dismiss a notification by key
        fun dismissNotification(key: String) {
            instance?.cancelNotification(key)
        }
        
        // Get list of apps that have posted notifications
        fun getNotificationApps(context: android.content.Context): List<Map<String, Any?>> {
            val pm = context.packageManager
            val apps = mutableSetOf<String>()
            
            instance?.activeNotifications?.forEach { sbn ->
                apps.add(sbn.packageName)
            }
            
            return apps.mapNotNull { packageName ->
                try {
                    val appInfo = pm.getApplicationInfo(packageName, 0)
                    val appName = pm.getApplicationLabel(appInfo).toString()
                    val iconBase64 = getAppIconBase64(pm, packageName)
                    
                    mapOf(
                        "packageName" to packageName,
                        "appName" to appName,
                        "iconBase64" to iconBase64
                    )
                } catch (e: PackageManager.NameNotFoundException) {
                    null
                }
            }
        }
        
        private fun getAppIconBase64(pm: PackageManager, packageName: String): String? {
            return try {
                val icon = pm.getApplicationIcon(packageName)
                val bitmap = drawableToBitmap(icon)
                val outputStream = ByteArrayOutputStream()
                bitmap.compress(Bitmap.CompressFormat.PNG, 50, outputStream)
                Base64.encodeToString(outputStream.toByteArray(), Base64.NO_WRAP)
            } catch (e: Exception) {
                null
            }
        }
        
        private fun drawableToBitmap(drawable: Drawable): Bitmap {
            if (drawable is BitmapDrawable) {
                return drawable.bitmap
            }
            
            val width = if (drawable.intrinsicWidth > 0) drawable.intrinsicWidth else 48
            val height = if (drawable.intrinsicHeight > 0) drawable.intrinsicHeight else 48
            
            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            drawable.setBounds(0, 0, canvas.width, canvas.height)
            drawable.draw(canvas)
            return bitmap
        }
    }
    
    interface NotificationCallback {
        fun onNotificationPosted(notification: Map<String, Any?>)
        fun onNotificationRemoved(notification: Map<String, Any?>)
    }
    
    override fun onCreate() {
        super.onCreate()
        instance = this
        Log.d(TAG, "NotificationListenerService created")
    }
    
    override fun onDestroy() {
        super.onDestroy()
        instance = null
        Log.d(TAG, "NotificationListenerService destroyed")
    }
    
    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.d(TAG, "NotificationListenerService connected")
    }
    
    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        Log.d(TAG, "NotificationListenerService disconnected")
    }
    
    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        sbn ?: return
        
        // Skip ongoing notifications (media players, downloads, etc.)
        if (sbn.isOngoing) {
            Log.d(TAG, "Skipping ongoing notification from ${sbn.packageName}")
            return
        }
        
        // Skip notifications from our own app
        if (sbn.packageName == packageName) {
            return
        }
        
        val notificationData = extractNotificationData(sbn)
        
        Log.d(TAG, "Notification posted: ${notificationData["appName"]} - ${notificationData["title"]}")
        
        notificationCallback?.onNotificationPosted(notificationData)
    }
    
    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        sbn ?: return
        
        // Skip our own notifications
        if (sbn.packageName == packageName) {
            return
        }
        
        val notificationData = mapOf(
            "id" to sbn.id,
            "packageName" to sbn.packageName,
            "key" to sbn.key
        )
        
        Log.d(TAG, "Notification removed: ${sbn.packageName} - ${sbn.id}")
        
        notificationCallback?.onNotificationRemoved(notificationData)
    }
    
    private fun extractNotificationData(sbn: StatusBarNotification): Map<String, Any?> {
        val notification = sbn.notification
        val extras = notification.extras
        
        // Get app name
        val pm = packageManager
        val appName = try {
            val appInfo = pm.getApplicationInfo(sbn.packageName, 0)
            pm.getApplicationLabel(appInfo).toString()
        } catch (e: PackageManager.NameNotFoundException) {
            sbn.packageName
        }
        
        // Extract text fields
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()
        val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()
        val subText = extras.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString()
        val summaryText = extras.getCharSequence(Notification.EXTRA_SUMMARY_TEXT)?.toString()
        
        // For messaging apps, try to get sender info
        val messages = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            extras.getParcelableArray(Notification.EXTRA_MESSAGES)
        } else {
            null
        }
        
        // Get conversation title (for messaging apps)
        val conversationTitle = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            extras.getCharSequence(Notification.EXTRA_CONVERSATION_TITLE)?.toString()
        } else {
            null
        }
        
        // Get category
        val category = notification.category
        
        // Check for reply action
        val hasReplyAction = notification.actions?.any { action ->
            action.remoteInputs?.isNotEmpty() == true
        } ?: false
        
        // Check if it's a group summary
        val isGroupSummary = (notification.flags and Notification.FLAG_GROUP_SUMMARY) != 0
        
        // Build the body text (prefer big text over regular text)
        val body = when {
            !bigText.isNullOrBlank() -> bigText
            !text.isNullOrBlank() -> text
            else -> summaryText
        }
        
        // Determine sender (for messaging)
        val sender = conversationTitle ?: subText
        
        return mapOf(
            "id" to sbn.id,
            "packageName" to sbn.packageName,
            "appName" to appName,
            "title" to title,
            "body" to body,
            "sender" to sender,
            "category" to category,
            "canReply" to hasReplyAction,
            "isGroupSummary" to isGroupSummary,
            "postedAt" to sbn.postTime,
            "key" to sbn.key
        )
    }
}


