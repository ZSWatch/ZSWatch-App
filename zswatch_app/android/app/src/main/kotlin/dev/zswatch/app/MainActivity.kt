package dev.zswatch.app

import android.Manifest
import android.accounts.Account
import android.content.ContentResolver
import android.content.ContentUris
import android.content.ContentValues
import android.content.ContentProviderOperation
import android.content.Context
import android.content.Intent
import android.content.ActivityNotFoundException
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import android.os.PowerManager
import android.provider.CalendarContract
import android.util.Log
import android.provider.Settings
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.TimeZone
import dev.zswatch.app.companion.PrototypeHub
import dev.zswatch.app.companion.PrototypeJobs
import dev.zswatch.app.companion.PrototypeStore
import org.json.JSONObject

/**
 * Main activity for ZSWatch companion app.
 * 
 * Sets up MethodChannels for:
 * - Service-owned companion control and observation
 * - Lifecycle diagnostics, power settings and explicit AI/productivity actions
 */
class MainActivity : FlutterActivity() {
    private var companionPrototypeBridge: dev.zswatch.app.companion.CompanionPrototypeBridge? = null
    
    companion object {
        private const val TAG = "ZSWProductivity"
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
    
    private var liteRtLmBridge: LiteRtLmBridge? = null
    private var testSpeech: TestSpeech? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        LifecycleLogger.initialize(applicationContext)
        LifecycleLogger.recordHistoricalExitReasons(applicationContext)
        LifecycleLogger.recordStartupCause(
            source = "activity",
            detail = "savedInstanceState=${savedInstanceState != null} intentAction=${intent?.action}",
        )
        LifecycleLogger.log("MainActivity", "onCreate savedInstanceState=${savedInstanceState != null}")
        
        // Create notification channels for foreground services
        LlmComputeService.createNotificationChannel(this)
    }

    override fun onStart() {
        super.onStart()
        LifecycleLogger.log("MainActivity", "onStart")
    }

    override fun onResume() {
        super.onResume()
        LifecycleLogger.log("MainActivity", "onResume")
    }

    override fun onPause() {
        LifecycleLogger.log("MainActivity", "onPause")
        super.onPause()
    }

    override fun onStop() {
        LifecycleLogger.log("MainActivity", "onStop")
        super.onStop()
    }

    override fun onTrimMemory(level: Int) {
        LifecycleLogger.log(
            "MainActivity",
            "onTrimMemory level=$level label=${LifecycleLogger.trimMemoryLevelLabel(level)}",
        )
        super.onTrimMemory(level)
    }

    override fun onLowMemory() {
        LifecycleLogger.log("MainActivity", "onLowMemory")
        super.onLowMemory()
    }
    
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (companionPrototypeBridge?.onActivityResult(requestCode, resultCode, data) == true) return
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        LifecycleLogger.log("MainActivity", "configureFlutterEngine engine=${flutterEngine.hashCode()}")
        companionPrototypeBridge = dev.zswatch.app.companion.CompanionPrototypeBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        setupLifecycleAndPowerChannel(flutterEngine)
        setupLlmComputeChannel(flutterEngine)
        setupProductivityChannel(flutterEngine)
        testSpeech = TestSpeech(this, flutterEngine.dartExecutor.binaryMessenger)
        
        liteRtLmBridge = LiteRtLmBridge(this)
        liteRtLmBridge!!.setup(flutterEngine)
    }
    
    private fun setupLifecycleAndPowerChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FOREGROUND_SERVICE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isBatteryOptimizationDisabled" -> {
                    val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                    val isIgnoring = pm.isIgnoringBatteryOptimizations(packageName)
                    LifecycleLogger.log("ForegroundChannel", "isBatteryOptimizationDisabled=$isIgnoring")
                    result.success(isIgnoring)
                }
                "requestDisableBatteryOptimization" -> {
                    try {
                        LifecycleLogger.log("ForegroundChannel", "requestDisableBatteryOptimization")
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
                        LifecycleLogger.log("ForegroundChannel", "openBatteryOptimizationSettings")
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
                "recordLifecycleEvent" -> {
                    val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any?>()
                    val source = args["source"] as? String ?: "Flutter"
                    val message = args["message"] as? String ?: ""
                    val timestampMillis = (args["timestampMillis"] as? Number)?.toLong()
                        ?: System.currentTimeMillis()
                    val processId = (args["pid"] as? Number)?.toInt()
                        ?: android.os.Process.myPid()

                    if (!LifecycleLogger.shouldPersist(source, message)) {
                        result.success(true)
                        return@setMethodCallHandler
                    }

                    val recorded = LifecycleLogger.record(
                        context = this,
                        source = source,
                        message = message,
                        timestampMillis = timestampMillis,
                        processId = processId,
                        origin = "dart",
                    )
                    result.success(recorded)
                }
                "getLifecycleEvents" -> {
                    result.success(LifecycleLogger.getEvents(this))
                }
                "clearLifecycleEvents" -> {
                    result.success(LifecycleLogger.clearEvents(this))
                }
                else -> result.notImplemented()
            }
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
                "companionAction" -> handleCompanionAction(call, result)
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

    private fun handleCreateAction(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result, actionToken: String? = null) {

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
                    targetType = "calendar_event",
                    actionToken = actionToken,
                )
                "reminder", "task" -> createReminderEntry(
                    calendarId = calendar.id,
                    title = title,
                    notes = notes,
                    scheduledAtMillis = scheduledAtMillis,
                    reminderMinutes = reminderMinutes,
                    targetType = "calendar_reminder",
                    actionToken = actionToken,
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

    private fun handleCompanionAction(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
        val id = call.argument<String>("jobId") ?: return result.error("INVALID_ARGUMENT", "Job required", null)
        val index = call.argument<Number>("index")?.toInt() ?: return result.error("INVALID_ARGUMENT", "Action required", null)
        val operation = call.argument<String>("operation")
        val token = "zswatch://voice-action/$id/$index"
        PrototypeHub.worker.post {
            try {
                require(Regex("[a-f0-9]{64}").matches(id))
                val jobs = PrototypeJobs(PrototypeHub.jobJournal(applicationContext))
                require(jobs.state(id).getJSONObject("spec").getString("watch_id") ==
                    PrototypeHub.journal(applicationContext).control()["address"])
                if (operation == "dismiss") {
                    jobs.dismissAction(id, index)
                    PrototypeHub.main.post { result.success(null) }
                } else if (operation == "undo") {
                    val action = jobs.beginUndoAction(id, index)
                    PrototypeHub.main.post {
                        try {
                            check(hasCalendarPermission()) { "Calendar permission required" }
                            val eventId = action.getJSONObject("response").getString("platformId").toLong()
                            val uri = ContentUris.withAppendedId(CalendarContract.Events.CONTENT_URI, eventId)
                            contentResolver.query(uri, arrayOf(CalendarContract.Events.CUSTOM_APP_URI,
                                CalendarContract.Events.CUSTOM_APP_PACKAGE), null, null, null)?.use { cursor ->
                                if (cursor.moveToFirst()) check(cursor.getString(0) == token && cursor.getString(1) == packageName) {
                                    "Calendar entry is no longer owned by this action"
                                }
                            } ?: error("Calendar provider unavailable")
                            // Item URIs reject a selection on Android's CalendarProvider.
                            // Use the collection URI with both ID and ownership in one predicate.
                            contentResolver.delete(CalendarContract.Events.CONTENT_URI,
                                "${CalendarContract.Events._ID}=? AND ${CalendarContract.Events.CUSTOM_APP_URI}=? AND ${CalendarContract.Events.CUSTOM_APP_PACKAGE}=?",
                                arrayOf(eventId.toString(), token, packageName))
                            contentResolver.query(uri, arrayOf(CalendarContract.Events.DELETED), null, null, null)?.use { cursor ->
                                if (cursor.moveToFirst()) check(cursor.getInt(0) == 1) { "Calendar entry was not removed" }
                            } ?: error("Calendar provider unavailable")
                            PrototypeHub.worker.post {
                                try { jobs.finishUndoAction(id, index); PrototypeHub.main.post { result.success(null) } }
                                catch (error: Exception) { PrototypeHub.main.post { result.error("ACTION_FAILED", error.message, null) } }
                            }
                        } catch (error: Exception) {
                            Log.w(TAG, "Companion calendar removal failed", error)
                            result.error("ACTION_FAILED", error.message, null)
                        }
                    }
                } else {
                    require(operation == "create")
                    val input = JSONObject(call.argument<Map<String, Any?>>("draft") ?: error("Draft required"))
                    val type = input.getString("actionType")
                    require(input.getString("title").isNotBlank() && input.getString("title").length <= 1024)
                    if (type == "timer") require(input.getLong("durationSeconds") in 1..Int.MAX_VALUE.toLong())
                    else require(input.getLong("scheduledAtMillis") > 0)
                    if (type == "alarm") {
                        val zone = java.time.ZoneId.systemDefault()
                        val target = java.time.Instant.ofEpochMilli(input.getLong("scheduledAtMillis")).atZone(zone)
                        val now = java.time.ZonedDateTime.now(zone)
                        var next = now.toLocalDate().atTime(target.hour, target.minute).atZone(zone)
                        if (!next.isAfter(now)) next = next.toLocalDate().plusDays(1).atTime(target.hour, target.minute).atZone(zone)
                        require(target.toLocalDate() == next.toLocalDate()) { "Clock only supports the next occurrence of this time" }
                    }
                    require(input.isNull("reminderMinutes") || input.getLong("reminderMinutes") in 0..Int.MAX_VALUE.toLong())
                    if (type == "calendar_event" && !input.isNull("endAtMillis"))
                        require(input.getLong("endAtMillis") > input.getLong("scheduledAtMillis"))
                    val alreadyConfirmed = jobs.state(id).optJSONObject("action_states")?.has(index.toString()) == true
                    val action = jobs.beginAction(id, index, input)
                    PrototypeHub.main.post {
                        handleCreateAction(io.flutter.plugin.common.MethodCall("createAction",
                            PrototypeStore.asMap(action.getJSONObject("draft"))), object : MethodChannel.Result {
                            override fun success(response: Any?) {
                                PrototypeHub.worker.post {
                                    try {
                                        jobs.finishAction(id, index, JSONObject(response as Map<*, *>))
                                        PrototypeHub.main.post { result.success(response) }
                                    } catch (error: Exception) { PrototypeHub.main.post { result.error("ACTION_FAILED", error.message, null) } }
                                }
                            }
                            override fun error(code: String, message: String?, details: Any?) {
                                // Provider failures can follow insertion. Keep their confirmation for token-based recovery.
                                PrototypeHub.worker.post {
                                    try {
                                        if (!alreadyConfirmed && (code in listOf("PERMISSION_DENIED", "NO_CALENDAR", "SELECTED_CALENDAR_UNAVAILABLE") ||
                                            (type in listOf("timer", "alarm") && code == "CREATE_ACTION_FAILED"))) jobs.releaseAction(id, index)
                                        PrototypeHub.main.post { result.error(code, message, details) }
                                    } catch (error: Exception) { PrototypeHub.main.post { result.error("ACTION_FAILED", error.message, null) } }
                                }
                            }
                            override fun notImplemented() = result.notImplemented()
                        }, token)
                    }
                }
            } catch (error: Exception) { PrototypeHub.main.post { result.error("ACTION_FAILED", error.message, null) } }
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
        return listOf(Manifest.permission.WRITE_CALENDAR, Manifest.permission.READ_CALENDAR).all {
            ContextCompat.checkSelfPermission(this, it) == PackageManager.PERMISSION_GRANTED
        }
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
        actionToken: String? = null,
    ): Map<String, Any?> {
        val start = startMillis
            ?: throw IllegalArgumentException("A start time is required for calendar events.")
        val end = endMillis ?: (start + 30 * 60 * 1000L)
        if (actionToken != null) {
            contentResolver.query(CalendarContract.Events.CONTENT_URI,
                arrayOf(CalendarContract.Events._ID, CalendarContract.Events.CALENDAR_ID),
                "${CalendarContract.Events.CUSTOM_APP_PACKAGE}=? AND ${CalendarContract.Events.CUSTOM_APP_URI}=? AND ${CalendarContract.Events.DELETED}=0",
                arrayOf(packageName, actionToken), null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val existing = findCalendarById(getWritableCalendars(), cursor.getLong(1))
                    return mapOf("platformId" to cursor.getLong(0).toString(), "targetType" to targetType,
                        "calendarDisplayName" to existing?.displayName, "calendarAccountName" to existing?.accountName,
                        "syncDisabled" to !isCalendarSyncWorking(existing))
                }
            } ?: error("Calendar provider unavailable")
        }

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
            if (actionToken != null) {
                put(CalendarContract.Events.CUSTOM_APP_PACKAGE, packageName)
                put(CalendarContract.Events.CUSTOM_APP_URI, actionToken)
            }
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

        val operations = arrayListOf(ContentProviderOperation.newInsert(insertUri).withValues(values).build())
        if (reminderMinutes != null) {
            val reminderUri = insertUri.buildUpon().path("reminders").build()
            operations.add(ContentProviderOperation.newInsert(reminderUri)
                .withValueBackReference(CalendarContract.Reminders.EVENT_ID, 0)
                .withValue(CalendarContract.Reminders.MINUTES, reminderMinutes)
                .withValue(CalendarContract.Reminders.METHOD, CalendarContract.Reminders.METHOD_ALERT).build())
        }
        val inserted = contentResolver.applyBatch(CalendarContract.AUTHORITY, operations)
        val eventId = ContentUris.parseId(inserted[0].uri ?: error("Failed to insert calendar event"))
        Log.d(TAG, "Calendar event inserted eventId=$eventId syncAdapter=$isCloudAccount")


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
        actionToken: String? = null,
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
            actionToken = actionToken,
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
        companionPrototypeBridge?.dispose()
        companionPrototypeBridge = null
        testSpeech?.dispose()
        testSpeech = null
        LifecycleLogger.log("MainActivity", "onDestroy companionObserverDetached=true")
        super.onDestroy()
    }
}
