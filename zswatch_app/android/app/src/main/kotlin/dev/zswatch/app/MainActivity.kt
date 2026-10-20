package dev.zswatch.app

import android.accounts.Account
import android.content.ContentResolver
import android.content.ContentUris
import android.content.Context
import android.content.Intent
import android.content.ActivityNotFoundException
import android.net.Uri
import android.os.Bundle
import android.os.PowerManager
import android.provider.CalendarContract
import android.util.Log
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import dev.zswatch.app.companion.PrototypeHub
import dev.zswatch.app.companion.PrototypeJobs
import dev.zswatch.app.companion.CompanionVoiceActions
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

    private val productivity by lazy { ProductivityActions(this) }
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

    private fun handleCreateAction(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
        @Suppress("UNCHECKED_CAST")
        val args = call.arguments as? Map<String, Any?> ?: emptyMap()
        try {
            result.success(productivity.create(args))
        } catch (failure: ActionFailure) {
            result.error(failure.code, failure.message, null)
        }
    }

    private fun handleCompanionAction(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
        val id = call.argument<String>("jobId") ?: return result.error("INVALID_ARGUMENT", "Job required", null)
        val index = call.argument<Number>("index")?.toInt() ?: return result.error("INVALID_ARGUMENT", "Action required", null)
        val operation = call.argument<String>("operation")
        val draft = call.argument<Map<String, Any?>>("draft")
        PrototypeHub.worker.post {
            try {
                require(Regex("[a-f0-9]{64}").matches(id))
                val jobs = PrototypeJobs(PrototypeHub.jobJournal(applicationContext))
                require(jobs.state(id).getJSONObject("spec").getString("watch_id") ==
                    PrototypeHub.journal(applicationContext).control()["address"])
                val response: Any? = when (operation) {
                    "dismiss" -> { jobs.dismissAction(id, index); null }
                    "undo" -> { CompanionVoiceActions.undoCreated(applicationContext, id, index); null }
                    "create" -> CompanionVoiceActions.create(applicationContext, id, index, JSONObject(draft ?: error("Draft required")))
                    else -> error("Unknown operation")
                }
                PrototypeHub.main.post { result.success(response) }
            } catch (failure: ActionFailure) {
                PrototypeHub.main.post { result.error(failure.code, failure.message, null) }
            } catch (error: Exception) {
                Log.w(TAG, "Companion action $operation failed", error)
                PrototypeHub.main.post { result.error("ACTION_FAILED", error.message, null) }
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
        if (!productivity.hasCalendarPermission()) {
            result.error(
                "PERMISSION_DENIED",
                "Calendar permission is required to list writable calendars.",
                null,
            )
            return
        }

        val calendars = productivity.getWritableCalendars().map { calendar ->
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

    /**
     * Check sync health for a specific calendar or the best available calendar.
     * Returns a map with sync diagnostics that Flutter can use to show warnings.
     */
    private fun handleCheckCalendarSyncHealth(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
        if (!productivity.hasCalendarPermission()) {
            result.error("PERMISSION_DENIED", "Calendar permission required", null)
            return
        }
        val requestedCalendarId = call.argument<Number>("calendarId")?.toLong()
        val calendars = productivity.getWritableCalendars()
        val calendar = if (requestedCalendarId != null) {
            productivity.findCalendarById(calendars, requestedCalendarId) ?: productivity.chooseBestCalendar(calendars)
        } else {
            productivity.chooseBestCalendar(calendars)
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
