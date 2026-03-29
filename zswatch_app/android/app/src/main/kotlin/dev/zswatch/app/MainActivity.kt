package dev.zswatch.app

import android.Manifest
import android.accounts.Account
import android.content.ContentResolver
import android.content.ContentUris
import android.content.ContentValues
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ActivityNotFoundException
import android.content.ServiceConnection
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import android.os.IBinder
import android.os.PowerManager
import android.provider.CalendarContract
import android.util.Log
import android.provider.Settings
import androidx.core.content.ContextCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.TimeZone

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
        private const val TAG = "ZSWProductivity"
        private const val NOTIFICATION_CHANNEL = "dev.zswatch.app/notifications"
        private const val NOTIFICATION_EVENTS_CHANNEL = "dev.zswatch.app/notification_events"
        private const val MEDIA_CHANNEL = "dev.zswatch.app/media"
        private const val MEDIA_EVENTS_CHANNEL = "dev.zswatch.app/media_events"
        private const val FOREGROUND_SERVICE_CHANNEL = "dev.zswatch.app/foreground_service"
        private const val LLM_COMPUTE_CHANNEL = "dev.zswatch.app/llm_compute"
        private const val PRODUCTIVITY_CHANNEL = "dev.zswatch.app/productivity"
    }

    private data class WritableCalendarInfo(
        val id: Long,
        val displayName: String?,
        val accountName: String?,
        val accountType: String?,
        val ownerAccount: String?,
        val isPrimary: Boolean,
    )
    
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
        
        // Create notification channels for foreground services
        BleConnectionForegroundService.createNotificationChannel(this)
        LlmComputeService.createNotificationChannel(this)
    }
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        setupNotificationChannel(flutterEngine)
        setupMediaChannel(flutterEngine)
        setupForegroundServiceChannel(flutterEngine)
        setupLlmComputeChannel(flutterEngine)
        setupProductivityChannel(flutterEngine)
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

    private fun setupLlmComputeChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LLM_COMPUTE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    LlmComputeService.start(this)
                    result.success(true)
                }
                "stop" -> {
                    LlmComputeService.stop(this)
                    result.success(true)
                }
                "isRunning" -> {
                    result.success(LlmComputeService.isRunning())
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun setupProductivityChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PRODUCTIVITY_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "createAction" -> handleCreateAction(call, result)
                "listWritableCalendars" -> handleListWritableCalendars(result)
                "openCalendarEntry" -> handleOpenCalendarEntry(call, result)
                "checkCalendarSyncHealth" -> handleCheckCalendarSyncHealth(call, result)
                "openCalendarSyncSettings" -> handleOpenCalendarSyncSettings(call, result)
                "getDeviceMemoryMB" -> {
                    val am = getSystemService(android.content.Context.ACTIVITY_SERVICE) as android.app.ActivityManager
                    val memInfo = android.app.ActivityManager.MemoryInfo()
                    am.getMemoryInfo(memInfo)
                    result.success((memInfo.totalMem / (1024 * 1024)).toInt())
                }
                "getAvailableMemoryMB" -> {
                    val am = getSystemService(android.content.Context.ACTIVITY_SERVICE) as android.app.ActivityManager
                    val memInfo = android.app.ActivityManager.MemoryInfo()
                    am.getMemoryInfo(memInfo)
                    result.success((memInfo.availMem / (1024 * 1024)).toInt())
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun handleOpenCalendarEntry(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
        val eventId = call.argument<String>("eventId")?.toLongOrNull()
            ?: call.argument<Number>("eventId")?.toLong()

        if (eventId == null) {
            result.error("INVALID_ARGUMENT", "eventId is required", null)
            return
        }

        val scheduledAtMillis = call.argument<Number>("scheduledAtMillis")?.toLong()

        try {
            // First verify the event still exists
            val eventProjection = arrayOf(
                CalendarContract.Events.DTSTART,
                CalendarContract.Events.DTEND,
                CalendarContract.Events.TITLE,
            )
            val eventUri = ContentUris.withAppendedId(CalendarContract.Events.CONTENT_URI, eventId)
            var eventStartMillis: Long? = null
            var eventEndMillis: Long? = null
            var eventTitle: String? = null

            contentResolver.query(eventUri, eventProjection, null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    eventStartMillis = cursor.getLong(0)
                    eventEndMillis = cursor.getLong(1)
                    eventTitle = cursor.getString(2)
                }
            }

            if (eventStartMillis == null) {
                Log.e(TAG, "Calendar event not found eventId=$eventId uri=$eventUri")
                result.error(
                    "EVENT_NOT_FOUND",
                    "The calendar event could not be found.",
                    null,
                )
                return
            }

            val beginTime = scheduledAtMillis ?: eventStartMillis!!
            val endTime = eventEndMillis ?: (beginTime + 30 * 60 * 1000L)

            // Use ACTION_VIEW with the direct event URI + begin/end extras.
            // This opens the event detail view in Google Calendar.
            val intent = Intent(Intent.ACTION_VIEW).apply {
                data = eventUri
                putExtra(CalendarContract.EXTRA_EVENT_BEGIN_TIME, beginTime)
                putExtra(CalendarContract.EXTRA_EVENT_END_TIME, endTime)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }

            try {
                startActivity(intent)
                Log.d(TAG, "Opened calendar event view eventId=$eventId title=$eventTitle uri=$eventUri")
                result.success(true)
            } catch (e: ActivityNotFoundException) {
                // Fallback: open calendar at the event's time
                val timeUri = CalendarContract.CONTENT_URI.buildUpon()
                    .appendPath("time")
                    .appendPath(beginTime.toString())
                    .build()
                val fallback = Intent(Intent.ACTION_VIEW).apply {
                    data = timeUri
                    putExtra(CalendarContract.EXTRA_EVENT_BEGIN_TIME, beginTime)
                    putExtra(CalendarContract.EXTRA_EVENT_END_TIME, endTime)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(fallback)
                Log.d(TAG, "Opened calendar time view (fallback) eventId=$eventId timeUri=$timeUri")
                result.success(true)
            }
        } catch (e: ActivityNotFoundException) {
            Log.e(TAG, "No activity available to open calendar entry eventId=$eventId", e)
            result.error("NO_CALENDAR_APP", "No calendar app is available to open the created event.", null)
        }
    }

    private fun handleListWritableCalendars(result: MethodChannel.Result) {
        if (!hasCalendarPermission()) {
            result.error(
                "PERMISSION_DENIED",
                "Calendar permission is required to list writable calendars.",
                null,
            )
            return
        }

        val calendars = getWritableCalendars().map { calendar ->
            mapOf(
                "id" to calendar.id,
                "displayName" to calendar.displayName,
                "accountName" to calendar.accountName,
                "accountType" to calendar.accountType,
                "ownerAccount" to calendar.ownerAccount,
                "isPrimary" to calendar.isPrimary,
            )
        }

        result.success(calendars)
    }

    private fun handleCreateAction(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
        Log.d(TAG, "handleCreateAction called with args=${call.arguments}")

        val actionType = call.argument<String>("actionType") ?: "task"
        val title = call.argument<String>("title")?.trim().orEmpty()
        val notes = call.argument<String>("notes")?.trim()?.takeIf { it.isNotEmpty() }
        val location = call.argument<String>("location")?.trim()?.takeIf { it.isNotEmpty() }
        val scheduledAtMillis = call.argument<Number>("scheduledAtMillis")?.toLong()
        val endAtMillis = call.argument<Number>("endAtMillis")?.toLong()
        val reminderMinutes = call.argument<Number>("reminderMinutes")?.toInt()
        val durationSeconds = call.argument<Number>("durationSeconds")?.toInt()
        val skipUi = call.argument<Boolean>("skipUi") ?: true
        val requestedCalendarId = call.argument<Number>("calendarId")?.toLong()

        // Timer and alarm use system intents — no calendar permission needed.
        if (actionType == "timer") {
            try {
                val response = createTimerViaIntent(
                    durationSeconds = durationSeconds ?: 0,
                    label = title,
                    skipUi = skipUi
                )
                Log.d(TAG, "createAction (timer) succeeded with response=$response")
                result.success(response)
            } catch (e: Exception) {
                Log.e(TAG, "createAction (timer) failed", e)
                result.error("CREATE_ACTION_FAILED", e.localizedMessage, null)
            }
            return
        }

        if (actionType == "alarm") {
            try {
                val response = createAlarmViaIntent(
                    triggerAtMillis = scheduledAtMillis,
                    label = title,
                    skipUi = skipUi
                )
                Log.d(TAG, "createAction (alarm) succeeded with response=$response")
                result.success(response)
            } catch (e: Exception) {
                Log.e(TAG, "createAction (alarm) failed", e)
                result.error("CREATE_ACTION_FAILED", e.localizedMessage, null)
            }
            return
        }

        if (!hasCalendarPermission()) {
            Log.w(TAG, "Calendar permission missing when attempting to create productivity action")
            result.error(
                "PERMISSION_DENIED",
                "Calendar permission is required to create events or reminders.",
                null
            )
            return
        }

        if (title.isEmpty()) {
            result.error("INVALID_ARGUMENT", "title is required", null)
            return
        }

        val calendars = getWritableCalendars()
        val calendar = if (requestedCalendarId != null) {
            val requestedCalendar = findCalendarById(calendars, requestedCalendarId)
            if (requestedCalendar == null) {
                Log.e(
                    TAG,
                    "Requested calendarId=$requestedCalendarId is unavailable. Available=${calendars.map { it.id to it.displayName }}",
                )
                result.error(
                    "SELECTED_CALENDAR_UNAVAILABLE",
                    "The selected default calendar is no longer available. Please choose another calendar in Settings.",
                    null,
                )
                return
            }
            requestedCalendar
        } else {
            chooseBestCalendar(calendars)
        }

        if (calendar == null) {
            Log.e(TAG, "No writable calendar available on device")
            result.error("NO_CALENDAR", "No writable calendar was found on this device.", null)
            return
        }

        Log.d(
            TAG,
            "Using calendar id=${calendar.id} name=${calendar.displayName} account=${calendar.accountName} owner=${calendar.ownerAccount} primary=${calendar.isPrimary}",
        )

        try {
            val response = when (actionType) {
                "calendar_event" -> createCalendarEntry(
                    calendarId = calendar.id,
                    title = title,
                    notes = notes,
                    location = location,
                    startMillis = scheduledAtMillis,
                    endMillis = endAtMillis,
                    reminderMinutes = reminderMinutes,
                    targetType = "calendar_event"
                )
                "reminder", "task" -> createReminderEntry(
                    calendarId = calendar.id,
                    title = title,
                    notes = notes,
                    scheduledAtMillis = scheduledAtMillis,
                    reminderMinutes = reminderMinutes,
                    targetType = "calendar_reminder"
                )
                else -> {
                    result.error("INVALID_ARGUMENT", "Unsupported action type: $actionType", null)
                    return
                }
            }

            Log.d(TAG, "createAction succeeded with response=$response")
            result.success(response)
        } catch (e: Exception) {
            Log.e(TAG, "createAction failed", e)
            result.error("CREATE_ACTION_FAILED", e.localizedMessage, null)
        }
    }

    private fun createTimerViaIntent(durationSeconds: Int, label: String, skipUi: Boolean = true): Map<String, Any?> {
        val intent = android.content.Intent(android.provider.AlarmClock.ACTION_SET_TIMER).apply {
            putExtra(android.provider.AlarmClock.EXTRA_LENGTH, durationSeconds)
            if (label.isNotEmpty()) {
                putExtra(android.provider.AlarmClock.EXTRA_MESSAGE, label)
            }
            putExtra(android.provider.AlarmClock.EXTRA_SKIP_UI, skipUi)
        }
        try {
            startActivity(intent)
        } catch (e: android.content.ActivityNotFoundException) {
            throw IllegalStateException("No app found that can handle timers. Please install a clock app.")
        }
        return mapOf(
            "platformId" to null,
            "targetType" to "timer",
            "syncDisabled" to false,
        )
    }

    private fun createAlarmViaIntent(triggerAtMillis: Long?, label: String, skipUi: Boolean = true): Map<String, Any?> {
        val intent = android.content.Intent(android.provider.AlarmClock.ACTION_SET_ALARM).apply {
            if (triggerAtMillis != null) {
                val cal = java.util.Calendar.getInstance().apply { timeInMillis = triggerAtMillis }
                putExtra(android.provider.AlarmClock.EXTRA_HOUR, cal.get(java.util.Calendar.HOUR_OF_DAY))
                putExtra(android.provider.AlarmClock.EXTRA_MINUTES, cal.get(java.util.Calendar.MINUTE))
            }
            if (label.isNotEmpty()) {
                putExtra(android.provider.AlarmClock.EXTRA_MESSAGE, label)
            }
            putExtra(android.provider.AlarmClock.EXTRA_SKIP_UI, skipUi)
        }
        try {
            startActivity(intent)
        } catch (e: android.content.ActivityNotFoundException) {
            throw IllegalStateException("No app found that can handle alarms. Please install a clock app.")
        }
        return mapOf(
            "platformId" to null,
            "targetType" to "alarm",
            "syncDisabled" to false,
        )
    }

    private fun hasCalendarPermission(): Boolean {
        return ContextCompat.checkSelfPermission(this, Manifest.permission.WRITE_CALENDAR) == PackageManager.PERMISSION_GRANTED
    }

    private fun getWritableCalendars(): List<WritableCalendarInfo> {
        val preferredCalendars = queryWritableCalendars(requireVisibleAndSynced = true)
        if (preferredCalendars.isNotEmpty()) {
            return preferredCalendars.sortedByDescending { scoreCalendar(it) }
        }

        return queryWritableCalendars(requireVisibleAndSynced = false)
            .sortedByDescending { scoreCalendar(it) }
    }

    private fun queryWritableCalendars(requireVisibleAndSynced: Boolean): List<WritableCalendarInfo> {
        val projection = arrayOf(
            CalendarContract.Calendars._ID,
            CalendarContract.Calendars.CALENDAR_DISPLAY_NAME,
            CalendarContract.Calendars.ACCOUNT_NAME,
            CalendarContract.Calendars.ACCOUNT_TYPE,
            CalendarContract.Calendars.OWNER_ACCOUNT,
            CalendarContract.Calendars.IS_PRIMARY,
            CalendarContract.Calendars.CALENDAR_ACCESS_LEVEL,
        )

        val selectionParts = mutableListOf<String>()
        if (requireVisibleAndSynced) {
            selectionParts += "${CalendarContract.Calendars.VISIBLE}=1"
            selectionParts += "${CalendarContract.Calendars.SYNC_EVENTS}=1"
        }
        selectionParts += "${CalendarContract.Calendars.CALENDAR_ACCESS_LEVEL}>=${CalendarContract.Calendars.CAL_ACCESS_CONTRIBUTOR}"
        val selection = selectionParts.joinToString(" AND ")
        val sortOrder = "${CalendarContract.Calendars.IS_PRIMARY} DESC, ${CalendarContract.Calendars._ID} ASC"
        val calendars = mutableListOf<WritableCalendarInfo>()

        contentResolver.query(
            CalendarContract.Calendars.CONTENT_URI,
            projection,
            selection,
            null,
            sortOrder,
        )?.use { cursor ->
            while (cursor.moveToNext()) {
                val calendar = WritableCalendarInfo(
                    id = cursor.getLong(0),
                    displayName = cursor.getString(1),
                    accountName = cursor.getString(2),
                    accountType = cursor.getString(3),
                    ownerAccount = cursor.getString(4),
                    isPrimary = cursor.getInt(5) == 1,
                )
                Log.d(
                    TAG,
                    "Writable calendar candidate id=${calendar.id} name=${calendar.displayName} account=${calendar.accountName} type=${calendar.accountType} owner=${calendar.ownerAccount} primary=${calendar.isPrimary}",
                )
                calendars.add(calendar)
            }
        }

        return calendars
    }

    private fun findCalendarById(
        calendars: List<WritableCalendarInfo>,
        calendarId: Long,
    ): WritableCalendarInfo? {
        return calendars.firstOrNull { it.id == calendarId }
    }

    private fun chooseBestCalendar(calendars: List<WritableCalendarInfo>): WritableCalendarInfo? {
        return calendars.maxByOrNull { scoreCalendar(it) }
    }

    private fun scoreCalendar(calendar: WritableCalendarInfo): Int {
        var score = 0

        if (calendar.isPrimary) {
            score += 100
        }

        val accountType = calendar.accountType.orEmpty().lowercase()
        val accountName = calendar.accountName.orEmpty().lowercase()
        val ownerAccount = calendar.ownerAccount.orEmpty().lowercase()
        val displayName = calendar.displayName.orEmpty().lowercase()

        if (accountType.contains("google")) {
            score += 80
        }
        if (accountType.contains("exchange") || accountType.contains("outlook")) {
            score += 60
        }
        if (accountType.contains("local") ||
            accountName.contains("local") ||
            ownerAccount.contains("local") ||
            displayName.contains("local")
        ) {
            score -= 40
        }

        return score
    }

    /**
     * Check if the sync adapter for a Google account's calendar authority is working.
     * Checks both isSyncable (sync adapter registered) and getSyncAutomatically (user toggle).
     * On some OEMs (OnePlus/ColorOS), isSyncable can be 0 even when the user has
     * Calendar sync enabled in Settings — so we also check getSyncAutomatically().
     */
    private fun isCalendarSyncWorking(calendar: WritableCalendarInfo?): Boolean {
        if (calendar == null) return false
        val accountName = calendar.accountName ?: return false
        val accountType = calendar.accountType ?: return false
        // Only relevant for cloud-backed calendar accounts (Google, Exchange, etc.)
        if (accountType.equals("LOCAL", ignoreCase = true)) return true
        val account = Account(accountName, accountType)
        return try {
            val isSyncable = ContentResolver.getIsSyncable(account, CalendarContract.AUTHORITY)
            val autoSync = ContentResolver.getSyncAutomatically(account, CalendarContract.AUTHORITY)
            val masterSync = ContentResolver.getMasterSyncAutomatically()
            Log.d(TAG, "isCalendarSyncWorking: account=$accountName isSyncable=$isSyncable autoSync=$autoSync masterSync=$masterSync")
            // Consider sync working if EITHER the sync adapter is registered (isSyncable>=1)
            // OR the user has auto-sync enabled (which means the Settings toggle is ON).
            // On some OEMs, isSyncable stays 0 even when the toggle is ON.
            (isSyncable >= 1) || (autoSync && masterSync)
        } catch (_: Exception) {
            false
        }
    }

    private fun createCalendarEntry(
        calendarId: Long,
        title: String,
        notes: String?,
        location: String?,
        startMillis: Long?,
        endMillis: Long?,
        reminderMinutes: Int?,
        targetType: String,
    ): Map<String, Any?> {
        val start = startMillis
            ?: throw IllegalArgumentException("A start time is required for calendar events.")
        val end = endMillis ?: (start + 30 * 60 * 1000L)

        Log.d(TAG, "createCalendarEntry calendarId=$calendarId title=$title reminderMinutes=$reminderMinutes")

        // Look up calendar info so we can set ORGANIZER (required for Google Calendar sync)
        val calendar = findCalendarById(getWritableCalendars(), calendarId)
        val organizerEmail = calendar?.ownerAccount ?: calendar?.accountName

        val syncWorking = isCalendarSyncWorking(calendar)

        val values = ContentValues().apply {
            put(CalendarContract.Events.CALENDAR_ID, calendarId)
            put(CalendarContract.Events.TITLE, title)
            put(CalendarContract.Events.DESCRIPTION, notes)
            put(CalendarContract.Events.EVENT_LOCATION, location)
            put(CalendarContract.Events.DTSTART, start)
            put(CalendarContract.Events.DTEND, end)
            put(CalendarContract.Events.EVENT_TIMEZONE, TimeZone.getDefault().id)
            put(CalendarContract.Events.STATUS, CalendarContract.Events.STATUS_CONFIRMED)
            put(CalendarContract.Events.ACCESS_LEVEL, CalendarContract.Events.ACCESS_DEFAULT)
            put(CalendarContract.Events.AVAILABILITY, CalendarContract.Events.AVAILABILITY_BUSY)
            put(CalendarContract.Events.HAS_ALARM, if (reminderMinutes != null) 1 else 0)
            if (!organizerEmail.isNullOrEmpty()) {
                put(CalendarContract.Events.ORGANIZER, organizerEmail)
            }
        }

        // Insert as sync adapter for cloud accounts (required on OnePlus/ColorOS)
        val accountName = calendar?.accountName ?: ""
        val accountType = calendar?.accountType ?: ""
        val isCloudAccount = !accountType.equals("LOCAL", ignoreCase = true) && accountName.isNotEmpty()

        val insertUri = if (isCloudAccount) {
            CalendarContract.Events.CONTENT_URI.buildUpon()
                .appendQueryParameter(CalendarContract.CALLER_IS_SYNCADAPTER, "true")
                .appendQueryParameter(CalendarContract.Calendars.ACCOUNT_NAME, accountName)
                .appendQueryParameter(CalendarContract.Calendars.ACCOUNT_TYPE, accountType)
                .build()
        } else {
            CalendarContract.Events.CONTENT_URI
        }

        val uri = contentResolver.insert(insertUri, values)
            ?: throw IllegalStateException("Failed to insert calendar event.")
        val eventId = ContentUris.parseId(uri)
        Log.d(TAG, "Calendar event inserted eventId=$eventId syncAdapter=$isCloudAccount")

        if (reminderMinutes != null) {
            insertReminder(eventId, reminderMinutes, accountName = calendar?.accountName, accountType = calendar?.accountType)
        }

        requestCalendarSync(calendar)

        return mapOf(
            "platformId" to eventId.toString(),
            "targetType" to targetType,
            "calendarDisplayName" to calendar?.displayName,
            "calendarAccountName" to calendar?.accountName,
            "syncDisabled" to !syncWorking,
        )
    }

    private fun createReminderEntry(
        calendarId: Long,
        title: String,
        notes: String?,
        scheduledAtMillis: Long?,
        reminderMinutes: Int?,
        targetType: String,
    ): Map<String, Any?> {
        val scheduledAt = scheduledAtMillis
            ?: throw IllegalArgumentException("A date/time is required to create reminders on Android.")

        Log.d(
            TAG,
            "createReminderEntry calendarId=$calendarId title=$title scheduledAt=$scheduledAt reminderMinutes=$reminderMinutes",
        )

        val event = createCalendarEntry(
            calendarId = calendarId,
            title = title,
            notes = notes,
            location = null,
            startMillis = scheduledAt,
            endMillis = scheduledAt + 30 * 60 * 1000L,
            reminderMinutes = reminderMinutes ?: 0,
            targetType = targetType,
        )

        return event
    }

    private fun requestCalendarSync(calendar: WritableCalendarInfo?) {
        if (calendar == null) return
        val accountName = calendar.accountName
        val accountType = calendar.accountType
        if (accountName.isNullOrEmpty() || accountType.isNullOrEmpty()) return
        val account = Account(accountName, accountType)

        try {
            // Ensure the sync adapter is marked as syncable
            if (ContentResolver.getIsSyncable(account, CalendarContract.AUTHORITY) <= 0) {
                ContentResolver.setIsSyncable(account, CalendarContract.AUTHORITY, 1)
            }
            if (!ContentResolver.getSyncAutomatically(account, CalendarContract.AUTHORITY)) {
                ContentResolver.setSyncAutomatically(account, CalendarContract.AUTHORITY, true)
            }

            val extras = Bundle().apply {
                putBoolean(ContentResolver.SYNC_EXTRAS_MANUAL, true)
                putBoolean(ContentResolver.SYNC_EXTRAS_EXPEDITED, true)
                putBoolean(ContentResolver.SYNC_EXTRAS_IGNORE_SETTINGS, true)
                putBoolean(ContentResolver.SYNC_EXTRAS_UPLOAD, true)
            }
            ContentResolver.requestSync(account, CalendarContract.AUTHORITY, extras)
            Log.d(TAG, "requestCalendarSync: requested sync for account=$accountName")
        } catch (e: Exception) {
            Log.e(TAG, "requestCalendarSync failed", e)
        }
    }

    private fun insertReminder(eventId: Long, minutes: Int, accountName: String? = null, accountType: String? = null) {
        Log.d(TAG, "insertReminder eventId=$eventId minutes=$minutes account=$accountName/$accountType")

        val values = ContentValues().apply {
            put(CalendarContract.Reminders.EVENT_ID, eventId)
            put(CalendarContract.Reminders.MINUTES, minutes)
            put(CalendarContract.Reminders.METHOD, CalendarContract.Reminders.METHOD_ALERT)
        }

        // Use CALLER_IS_SYNCADAPTER URI for cloud accounts to avoid re-dirtying the event
        val isCloudAccount = !accountType.isNullOrEmpty() && !accountType.equals("LOCAL", ignoreCase = true) && !accountName.isNullOrEmpty()
        val insertUri = if (isCloudAccount) {
            CalendarContract.Reminders.CONTENT_URI.buildUpon()
                .appendQueryParameter(CalendarContract.CALLER_IS_SYNCADAPTER, "true")
                .appendQueryParameter(CalendarContract.Calendars.ACCOUNT_NAME, accountName)
                .appendQueryParameter(CalendarContract.Calendars.ACCOUNT_TYPE, accountType)
                .build()
        } else {
            CalendarContract.Reminders.CONTENT_URI
        }

        val uri = contentResolver.insert(insertUri, values)
        Log.d(TAG, "Reminder inserted for eventId=$eventId")
    }

    /**
     * Check sync health for a specific calendar or the best available calendar.
     * Returns a map with sync diagnostics that Flutter can use to show warnings.
     */
    private fun handleCheckCalendarSyncHealth(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
        if (!hasCalendarPermission()) {
            result.error("PERMISSION_DENIED", "Calendar permission required", null)
            return
        }
        val requestedCalendarId = call.argument<Number>("calendarId")?.toLong()
        val calendars = getWritableCalendars()
        val calendar = if (requestedCalendarId != null) {
            findCalendarById(calendars, requestedCalendarId) ?: chooseBestCalendar(calendars)
        } else {
            chooseBestCalendar(calendars)
        }
        if (calendar == null) {
            result.success(mapOf("hasCalendar" to false, "syncWorking" to false))
            return
        }
        val accountName = calendar.accountName ?: ""
        val accountType = calendar.accountType ?: ""
        val isLocal = accountType.equals("LOCAL", ignoreCase = true)
        var isSyncable = -1
        var autoSync = false
        var masterSync = false
        if (!isLocal && accountName.isNotEmpty() && accountType.isNotEmpty()) {
            try {
                val account = Account(accountName, accountType)
                isSyncable = ContentResolver.getIsSyncable(account, CalendarContract.AUTHORITY)
                autoSync = ContentResolver.getSyncAutomatically(account, CalendarContract.AUTHORITY)
                masterSync = ContentResolver.getMasterSyncAutomatically()
            } catch (_: Exception) { /* ignore */ }
        }
        // On some OEMs (OnePlus/ColorOS), isSyncable can be 0 even when the user has
        // Calendar sync enabled in Settings. Check both conditions.
        val syncWorking = isLocal || (isSyncable >= 1) || (autoSync && masterSync)
        Log.d(TAG, "checkCalendarSyncHealth: calendar=${calendar.displayName} isSyncable=$isSyncable autoSync=$autoSync masterSync=$masterSync syncWorking=$syncWorking")
        result.success(mapOf(
            "hasCalendar" to true,
            "syncWorking" to syncWorking,
            "isSyncable" to isSyncable,
            "autoSync" to autoSync,
            "masterSync" to masterSync,
            "calendarId" to calendar.id,
            "calendarDisplayName" to calendar.displayName,
            "accountName" to accountName,
            "accountType" to accountType,
            "isLocal" to isLocal,
        ))
    }

    /**
     * Open the Android system Account Sync Settings for a specific account.
     * This allows the user to enable Calendar sync for their Google account.
     */
    private fun handleOpenCalendarSyncSettings(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
        // On OnePlus/ColorOS, ACCOUNT_SYNC_SETTINGS opens and immediately closes.
        // Skip it entirely and use intents that reliably stay open.

        // 1. Open "Passwords & accounts" / account management page
        try {
            val intent = Intent(android.provider.Settings.ACTION_SYNC_SETTINGS)
            startActivity(intent)
            Log.d(TAG, "Opened ACTION_SYNC_SETTINGS (Passwords & accounts)")
            result.success("sync_settings")
            return
        } catch (e: Exception) {
            Log.w(TAG, "ACTION_SYNC_SETTINGS failed: ${e.message}")
        }

        // 2. Fallback: general settings
        try {
            val intent = Intent(android.provider.Settings.ACTION_SETTINGS)
            startActivity(intent)
            Log.d(TAG, "Opened general settings (fallback)")
            result.success("general_settings")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to open any settings", e)
            result.error("SETTINGS_FAILED", "Could not open settings: ${e.message}", null)
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
