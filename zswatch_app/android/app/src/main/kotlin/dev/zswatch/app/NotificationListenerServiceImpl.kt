package dev.zswatch.app

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
        
        // Unique ID generation: We generate our own IDs to avoid collisions across app restarts.
        // The counter is persisted in SharedPreferences and starts from a random offset on first run
        // to minimize chance of collision with watch's existing notifications.
        private const val PREFS_NAME = "notification_service_prefs"
        private const val PREF_NEXT_ID = "next_notification_id"
        private var nextNotificationId: Long = 0
        private var prefsInitialized = false
        
        // Map sbn.key -> our generated unique ID (for consistent ID during notification's lifetime)
        private val keyToUniqueId = mutableMapOf<String, Long>()
        
        // Track which notifications were actually forwarded to Flutter
        // (only these should trigger removal events)
        private val forwardedNotificationKeys = mutableSetOf<String>()
        
        // Track notification content hashes to detect true updates vs re-posts
        // Key: sbn.key, Value: hash of title+body
        private val notificationContentHashes = mutableMapOf<String, Int>()
        
        // Burst prevention: Track when last notification was sent per source (System.nanoTime())
        // Prevents rapid-fire notifications from same app within timeout period
        private val notificationBurstPrevention = mutableMapOf<String, Long>()
        
        // Old repeat prevention: Track notification.when timestamp per source
        // Prevents re-posts of old notifications (e.g., when user interacts with notification)
        private val notificationOldRepeatPrevention = mutableMapOf<String, Long>()
        
        // Burst prevention timeout in nanoseconds (default 0 = disabled)
        // Can be made configurable via settings
        private const val BURST_PREVENTION_TIMEOUT_NS = 0L  // Set to e.g. 1_000_000_000L for 1 second
        
        // === App lists from Gadgetbridge NotificationListener.java ===
        
        // SMS apps - notifications from these are handled separately (usually by system SMS handling)
        // From Gadgetbridge ~line 1165-1175
        private val SMS_APPS = setOf(
            "com.moez.QKSMS",
            "com.android.mms",
            "com.sonyericsson.conversations",
            "com.android.messaging",
            "org.smssecure.smssecure",
            "org.fossify.messages",
            "com.goodwy.smsmessenger",
            "com.simplemobiletools.smsmessenger",
            "dev.octoshrimpy.quik"
        )
        
        // Phone/dialer apps - call notifications, not regular notifications
        // From Gadgetbridge ~line 140-147
        private val PHONE_CALL_APPS = setOf(
            "com.android.dialer",
            "com.android.incallui",
            "com.asus.asusincallui",
            "com.google.android.dialer",
            "com.samsung.android.incallui",
            "org.fossify.phone"
        )
        
        // Apps that send group summaries that should be forwarded
        // From Gadgetbridge ~line 130-134
        private val GROUP_SUMMARY_WHITELIST = setOf(
            "com.microsoft.office.lync15",  // Skype for Business
            "com.skype.raider",             // Skype
            "mikado.bizcalpro"              // Business Calendar Pro
        )
        
        // Apps incorrectly marked as local-only that should still be forwarded
        // From Gadgetbridge ~line 1229-1245
        private val LOCAL_ONLY_WHITELIST = setOf(
            "com.tencent.mm",                    // WeChat
            "org.telegram.messenger",            // Telegram
            "com.microsoft.office.outlook",      // Outlook
            "com.skype.raider"                   // Skype
        )
        
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

        /**
         * Initialize the unique ID counter from SharedPreferences.
         * On first run, starts from a random offset to avoid collision with existing watch notifications.
         */
        @Synchronized
        fun initializeIdCounter(context: android.content.Context) {
            if (prefsInitialized) return
            
            val prefs = context.getSharedPreferences(PREFS_NAME, android.content.Context.MODE_PRIVATE)
            if (!prefs.contains(PREF_NEXT_ID)) {
                // First run: start from a random offset between 1M and 2M to avoid collision
                // with any existing notifications on the watch
                val randomOffset = (System.currentTimeMillis() % 1_000_000) + 1_000_000
                prefs.edit().putLong(PREF_NEXT_ID, randomOffset).apply()
                nextNotificationId = randomOffset
            } else {
                nextNotificationId = prefs.getLong(PREF_NEXT_ID, 1_000_000)
            }
            prefsInitialized = true
            Log.d(TAG, "Initialized notification ID counter at: $nextNotificationId")
        }
        
        @Synchronized
        private fun saveNextId(context: android.content.Context) {
            val prefs = context.getSharedPreferences(PREFS_NAME, android.content.Context.MODE_PRIVATE)
            prefs.edit().putLong(PREF_NEXT_ID, nextNotificationId).apply()
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
        LifecycleLogger.initialize(applicationContext)
        LifecycleLogger.recordHistoricalExitReasons(applicationContext)
        LifecycleLogger.recordStartupCause(
            source = "notification_listener",
            detail = "component=${javaClass.simpleName}",
        )
        instance = this
        initializeIdCounter(applicationContext)
        Log.d(TAG, "NotificationListenerService created")
        LifecycleLogger.log(TAG, "onCreate")
    }
    
    override fun onDestroy() {
        super.onDestroy()
        instance = null
        Log.d(TAG, "NotificationListenerService destroyed")
        LifecycleLogger.log(TAG, "onDestroy")
    }
    
    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.d(TAG, "NotificationListenerService connected")
        LifecycleLogger.log(TAG, "onListenerConnected activeNotifications=${activeNotifications?.size ?: 0}")
    }
    
    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        Log.d(TAG, "NotificationListenerService disconnected")
        LifecycleLogger.log(TAG, "onListenerDisconnected")
    }

    override fun onTrimMemory(level: Int) {
        LifecycleLogger.log(
            TAG,
            "onTrimMemory level=$level label=${LifecycleLogger.trimMemoryLevelLabel(level)}",
        )
        super.onTrimMemory(level)
    }

    override fun onLowMemory() {
        LifecycleLogger.log(TAG, "onLowMemory")
        super.onLowMemory()
    }
    
    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        sbn ?: return
        val isDebugNotification = sbn.notification.extras?.getBoolean(
            NotificationDebugHelper.EXTRA_DEBUG_NOTIFICATION
        ) == true
        
        // Skip ongoing notifications (media players, downloads, etc.)
        if (sbn.isOngoing) {
            Log.d(TAG, "Skipping ongoing notification from ${sbn.packageName}")
            return
        }
        
        // Skip notifications from our own app
        if (sbn.packageName == packageName && !isDebugNotification) {
            return
        }
        
        val notification = sbn.notification
        
        // Skip system apps that typically generate noise
        val systemBlacklist = setOf(
            "android",
            "com.android.systemui",
            "com.android.providers.downloads",
            "com.google.android.gms",  // Google Play Services
            "com.google.android.gsf",  // Google Services Framework
        )
        if (systemBlacklist.contains(sbn.packageName)) {
            Log.d(TAG, "Skipping system notification from ${sbn.packageName}")
            return
        }
        
        // Skip media transport notifications (category set by the OS)
        val category = notification.category
        if (category == Notification.CATEGORY_TRANSPORT) {
            Log.d(TAG, "Skipping CATEGORY_TRANSPORT notification from ${sbn.packageName}")
            return
        }
        
        // Skip service/status/progress notifications (usually background processes)
        if (category == Notification.CATEGORY_SERVICE ||
            category == Notification.CATEGORY_STATUS ||
            category == Notification.CATEGORY_PROGRESS) {
            Log.d(TAG, "Skipping $category notification from ${sbn.packageName}")
            return
        }
        
        // Skip promotional notifications
        if (category == Notification.CATEGORY_PROMO ||
            category == Notification.CATEGORY_RECOMMENDATION) {
            Log.d(TAG, "Skipping promo/recommendation notification from ${sbn.packageName}")
            return
        }
        
        // Skip foreground service notifications (these are persistent service indicators)
        if ((notification.flags and Notification.FLAG_FOREGROUND_SERVICE) != 0) {
            Log.d(TAG, "Skipping foreground service notification from ${sbn.packageName}")
            return
        }
        
        // Skip notifications that can't be cleared by user (persistent/pinned notifications)
        if ((notification.flags and Notification.FLAG_NO_CLEAR) != 0) {
            Log.d(TAG, "Skipping non-clearable notification from ${sbn.packageName}")
            return
        }
        
        // Skip local-only notifications (not meant to be bridged to other devices)
        // Exception: Some apps incorrectly mark notifications as local-only
        // These exceptions are from Gadgetbridge's NotificationListener.java (~line 1229-1245)
        if ((notification.flags and Notification.FLAG_LOCAL_ONLY) != 0 &&
            !LOCAL_ONLY_WHITELIST.contains(sbn.packageName)) {
            Log.d(TAG, "Skipping local-only notification from ${sbn.packageName}")
            return
        }
        
        // Skip group summary notifications (they are duplicates of child notifications)
        // Exception: Some apps only send group summaries, not individual notifications
        // This whitelist is from Gadgetbridge's NotificationListener.java (~line 130-134)
        if ((notification.flags and Notification.FLAG_GROUP_SUMMARY) != 0 &&
            !GROUP_SUMMARY_WHITELIST.contains(sbn.packageName)) {
            Log.d(TAG, "Skipping group summary notification from ${sbn.packageName}")
            return
        }
        
        // Skip notifications with media session (reliable indicator of media player notification)
        val extras = notification.extras
        if (extras.containsKey(Notification.EXTRA_MEDIA_SESSION)) {
            Log.d(TAG, "Skipping notification with media session from ${sbn.packageName}")
            return
        }
        
        // Check legacy priority (works on all Android versions)
        @Suppress("DEPRECATION")
        if (notification.priority < Notification.PRIORITY_DEFAULT) {
            Log.d(TAG, "Skipping low priority notification from ${sbn.packageName}, priority=${notification.priority}")
            return
        }
        
        // On Android O+, skip low importance notifications (silent/minimal notifications)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = try {
                val channelId = notification.channelId
                if (channelId != null) {
                    val nm = getSystemService(android.app.NotificationManager::class.java)
                    nm?.getNotificationChannel(channelId)
                } else null
            } catch (e: Exception) {
                null
            }
            
            // Skip if importance is LOW or MIN (these are silent notifications)
            if (channel != null && channel.importance <= android.app.NotificationManager.IMPORTANCE_LOW) {
                Log.d(TAG, "Skipping low importance notification from ${sbn.packageName}, importance=${channel.importance}")
                return
            }
        }
        
        // === Gadgetbridge-style duplicate prevention ===
        
        // Skip SMS app notifications (handled by system SMS bridge)
        // From Gadgetbridge ~line 1165-1175
        if (SMS_APPS.contains(sbn.packageName)) {
            Log.d(TAG, "Skipping SMS app notification from ${sbn.packageName}")
            return
        }
        
        // Skip phone/dialer app notifications (call notifications, not regular notifications)
        // From Gadgetbridge ~line 140-147
        if (PHONE_CALL_APPS.contains(sbn.packageName)) {
            Log.d(TAG, "Skipping phone/dialer app notification from ${sbn.packageName}")
            return
        }
        
        // Old repeat prevention: Skip notifications with older/same timestamp than last forwarded
        // This prevents re-posts of old notifications (e.g., Messenger updating same notification)
        // From Gadgetbridge ~line 412-425
        val notificationWhen = notification.`when`
        val previousWhen = notificationOldRepeatPrevention[sbn.packageName]
        if (previousWhen != null && notificationWhen > 0 && notificationWhen <= previousWhen) {
            Log.d(TAG, "Skipping old/repeat notification from ${sbn.packageName}, when=$notificationWhen <= previous=$previousWhen")
            return
        }
        
        // Burst prevention: Skip notifications that come too frequently from same source
        // From Gadgetbridge ~line 427-445
        if (BURST_PREVENTION_TIMEOUT_NS > 0) {
            val curTime = System.nanoTime()
            val lastBurstTime = notificationBurstPrevention[sbn.packageName]
            if (lastBurstTime != null) {
                val diff = curTime - lastBurstTime
                if (diff < BURST_PREVENTION_TIMEOUT_NS) {
                    Log.d(TAG, "Skipping burst notification from ${sbn.packageName}, ${diff / 1_000_000}ms since last")
                    return
                }
            }
            notificationBurstPrevention[sbn.packageName] = curTime
        }
        
        val notificationData = extractNotificationData(sbn)
        
        // Check if this is an update to an already-forwarded notification with identical content
        // This prevents duplicate notifications when user taps a notification and the app re-posts it
        val title = notificationData["title"] as? String ?: ""
        val body = notificationData["body"] as? String ?: ""
        val contentHash = (title + body).hashCode()
        val previousHash = notificationContentHashes[sbn.key]
        
        val isAlreadyForwarded = forwardedNotificationKeys.contains(sbn.key)
        val isSameContent = previousHash != null && previousHash == contentHash
        
        if (isAlreadyForwarded && isSameContent) {
            Log.d(TAG, "Skipping duplicate notification (same content): ${notificationData["appName"]} - ${notificationData["title"]}")
            return
        }
        
        // Update content hash
        notificationContentHashes[sbn.key] = contentHash
        
        Log.d(TAG, "Notification posted: ${notificationData["appName"]} - ${notificationData["title"]} (isUpdate=${isAlreadyForwarded})")
        
        if (notificationCallback == null) {
            Log.w(TAG, "Notification callback is null - Flutter not listening!")
            LifecycleLogger.log(
                TAG,
                "drop posted notification callback=null package=${sbn.packageName} key=${sbn.key}",
            )
        } else {
            Log.d(TAG, "Forwarding notification to Flutter via callback")
            LifecycleLogger.log(
                TAG,
                "forward posted notification package=${sbn.packageName} key=${sbn.key}",
            )
            // Track that this notification was forwarded
            forwardedNotificationKeys.add(sbn.key)
            
            // Update old repeat prevention timestamp after successful forward
            // From Gadgetbridge ~line 596-604
            // Only track if notification.when is valid (>0) and not in the future
            val notificationWhen = notification.`when`
            if (notificationWhen > 0 && notificationWhen <= System.currentTimeMillis() + 30_000L) {
                notificationOldRepeatPrevention[sbn.packageName] = notificationWhen
            } else {
                Log.d(TAG, "Not tracking notification.when for ${sbn.packageName}: when=$notificationWhen (invalid or future)")
            }
            
            notificationCallback?.onNotificationPosted(notificationData)
        }
    }
    
    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        sbn ?: return
        val isDebugNotification = sbn.notification.extras?.getBoolean(
            NotificationDebugHelper.EXTRA_DEBUG_NOTIFICATION
        ) == true
        
        // Skip our own notifications
        if (sbn.packageName == packageName && !isDebugNotification) {
            return
        }

        // Only send removal events for notifications that were actually forwarded
        // This prevents phantom dismiss events for filtered notifications
        if (!forwardedNotificationKeys.remove(sbn.key)) {
            Log.d(TAG, "Skipping removal for non-forwarded notification: ${sbn.packageName}")
            return
        }

        // Get the unique ID that was assigned when posted
        val uniqueId = keyToUniqueId[sbn.key]
        if (uniqueId == null) {
            Log.w(TAG, "No unique ID found for removed notification: ${sbn.key}")
            return
        }

        val notificationData = mapOf(
            "id" to uniqueId,
            "packageName" to sbn.packageName,
            "key" to sbn.key
        )

        Log.d(TAG, "Notification removed: ${sbn.packageName} - $uniqueId")

        if (notificationCallback == null) {
            LifecycleLogger.log(
                TAG,
                "drop removed notification callback=null package=${sbn.packageName} key=${sbn.key}",
            )
        } else {
            LifecycleLogger.log(
                TAG,
                "forward removed notification package=${sbn.packageName} key=${sbn.key}",
            )
        }
        notificationCallback?.onNotificationRemoved(notificationData)

        // Clean up mappings for this notification
        clearUniqueId(sbn.key)
        notificationContentHashes.remove(sbn.key)
    }
    
    private fun extractNotificationData(sbn: StatusBarNotification): Map<String, Any?> {
        val notification = sbn.notification
        val extras = notification.extras

        val uniqueId = getOrCreateUniqueId(sbn)
        
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
            "id" to uniqueId,
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

    /**
     * Get (or create) a unique ID for a notification.
     * Always generates a new ID for notifications with new content.
     * IDs are monotonically increasing and persist across app restarts.
     * 
     * Note: Unlike the previous implementation that reused IDs per sbn.key,
     * we now generate a new ID for each notification event with new content.
     * This matches Gadgetbridge's behavior and ensures messaging apps like
     * Messenger get unique IDs for each new message, even when they update
     * the same notification (same sbn.key) rather than creating new ones.
     */
    @Synchronized
    private fun getOrCreateUniqueId(sbn: StatusBarNotification): Long {
        // Always generate a new unique ID for each notification
        // (content deduplication happens earlier in onNotificationPosted)
        val uniqueId = nextNotificationId++
        
        // Store the mapping for dismiss sync
        keyToUniqueId[sbn.key] = uniqueId
        
        // Persist the counter
        saveNextId(applicationContext)
        
        return uniqueId
    }

    @Synchronized
    private fun clearUniqueId(key: String) {
        keyToUniqueId.remove(key)
    }
}
