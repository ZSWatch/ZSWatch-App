package dev.zswatch.app

import android.app.ActivityManager
import android.app.ApplicationExitInfo
import android.content.Context
import android.os.Build
import android.os.Process
import android.os.SystemClock
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject

object LifecycleLogger {
    private const val TAG = "ZSWLifecycle"
    private const val PREFS_NAME = "zswatch_lifecycle_events"
    private const val KEY_EVENTS = "events_json"
    private const val KEY_EXIT_SIGNATURES = "exit_signatures_json"
    private const val MAX_EVENTS = 300
    private const val MAX_EXIT_SIGNATURES = 50

    @Volatile
    private var appContext: Context? = null

    fun initialize(context: Context) {
        appContext = context.applicationContext
    }

    fun recordStartupCause(source: String, detail: String) {
        log("StartupCause", "source=$source $detail")
    }

    fun trimMemoryLevelLabel(level: Int): String {
        return when (level) {
            80 -> "complete"
            60 -> "moderate"
            40 -> "background"
            20 -> "ui_hidden"
            15 -> "running_critical"
            10 -> "running_low"
            5 -> "running_moderate"
            else -> "unknown_$level"
        }
    }

    fun log(source: String, message: String) {
        val uptimeMs = SystemClock.uptimeMillis()
        val pid = Process.myPid()
        Log.d(TAG, "[$source][pid=$pid][uptimeMs=$uptimeMs] $message")
        if (!shouldPersist(source, message)) return

        appContext?.let { context ->
            record(
                context = context,
                source = source,
                message = message,
                timestampMillis = System.currentTimeMillis(),
                uptimeMs = uptimeMs,
                processId = pid,
                origin = "native",
            )
        }
    }

    @Synchronized
    fun record(
        context: Context,
        source: String,
        message: String,
        timestampMillis: Long = System.currentTimeMillis(),
        uptimeMs: Long = SystemClock.uptimeMillis(),
        processId: Int = Process.myPid(),
        origin: String = "native",
    ): Boolean {
        initialize(context)

        val event = JSONObject().apply {
            put("timestampMillis", timestampMillis)
            put("uptimeMs", uptimeMs)
            put("pid", processId)
            put("origin", origin)
            put("source", source)
            put("message", message)
        }

        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val current = parseEvents(prefs.getString(KEY_EVENTS, null))
        val trimmed = JSONArray()
        val start = maxOf(0, current.length() - MAX_EVENTS + 1)
        for (index in start until current.length()) {
            trimmed.put(current.get(index))
        }
        trimmed.put(event)

        return prefs.edit().putString(KEY_EVENTS, trimmed.toString()).commit()
    }

    fun shouldPersist(source: String, message: String): Boolean {
        val lowerSource = source.lowercase()
        val lowerMessage = message.lowercase()

        if (lowerSource == "processexitreason") return true
        if (lowerSource == "startupcause") return true
        if (lowerSource == "applifecycle" || lowerSource == "mainactivity") return true
        if (lowerSource == "bootreceiver") return true
        if (lowerSource.contains("notificationservice")) {
            return lowerMessage.contains("oncreate") ||
                lowerMessage.contains("ondestroy") ||
                lowerMessage.contains("onlowmemory") ||
                lowerMessage.contains("ontrimmemory") ||
                lowerMessage.contains("listenerconnected") ||
                lowerMessage.contains("listenerdisconnected")
        }
        if (lowerSource == "bleconnectionservice") {
            return lowerMessage.contains("oncreate") ||
                lowerMessage.contains("ondestroy") ||
                lowerMessage.contains("onlowmemory") ||
                lowerMessage.contains("ontrimmemory") ||
                lowerMessage.contains("ontaskremoved") ||
                lowerMessage.contains("start requested") ||
                lowerMessage.contains("stop requested") ||
                lowerMessage.contains("startforeground") ||
                lowerMessage.contains("stopforeground") ||
                lowerMessage.contains("action=dev.zswatch.app.start_foreground") ||
                lowerMessage.contains("action=dev.zswatch.app.stop_foreground")
        }
        if (lowerSource == "foregroundservice") {
            return lowerMessage.contains("created") ||
                lowerMessage.contains("startforeground") ||
                lowerMessage.contains("stop")
        }
        return lowerMessage.contains("oncreate") ||
            lowerMessage.contains("ondestroy") ||
            lowerMessage.contains("onlowmemory") ||
            lowerMessage.contains("ontrimmemory") ||
            lowerMessage.contains("ontaskremoved") ||
            lowerMessage.contains("boot_completed") ||
            lowerMessage.contains("my_package_replaced") ||
            lowerMessage.contains("force stop")
    }

    @Synchronized
    fun getEvents(context: Context): List<Map<String, Any?>> {
        initialize(context)
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val events = parseEvents(prefs.getString(KEY_EVENTS, null))
        val result = mutableListOf<Map<String, Any?>>()
        for (index in 0 until events.length()) {
            val event = events.optJSONObject(index) ?: continue
            result.add(
                mapOf(
                    "timestampMillis" to event.optLong("timestampMillis"),
                    "uptimeMs" to event.optLong("uptimeMs"),
                    "pid" to event.optInt("pid"),
                    "origin" to event.optString("origin"),
                    "source" to event.optString("source"),
                    "message" to event.optString("message"),
                ),
            )
        }
        return result
    }

    @Synchronized
    fun clearEvents(context: Context): Boolean {
        initialize(context)
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.edit().remove(KEY_EVENTS).remove(KEY_EXIT_SIGNATURES).commit()
    }

    @Synchronized
    fun recordHistoricalExitReasons(context: Context) {
        initialize(context)

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return

        val activityManager = context.getSystemService(ActivityManager::class.java) ?: return
        val exitReasons = try {
            activityManager.getHistoricalProcessExitReasons(context.packageName, 0, 8)
        } catch (error: Exception) {
            Log.w(TAG, "Failed to read historical process exit reasons", error)
            return
        }

        if (exitReasons.isNullOrEmpty()) return

        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val knownSignatures = parseEvents(prefs.getString(KEY_EXIT_SIGNATURES, null))
        val known = mutableSetOf<String>()
        for (index in 0 until knownSignatures.length()) {
            knownSignatures.optString(index).takeIf { it.isNotBlank() }?.let(known::add)
        }

        val updatedKnown = JSONArray()
        val mutableKnown = known.toMutableList()

        for (exitInfo in exitReasons.asReversed()) {
            val signature = "${exitInfo.timestamp}:${exitInfo.pid}:${exitInfo.reason}:${exitInfo.status}"
            if (!known.add(signature)) continue

            record(
                context = context,
                source = "ProcessExitReason",
                message = exitInfo.toDiagnosticMessage(),
                timestampMillis = exitInfo.timestamp,
                processId = exitInfo.pid,
                origin = "native",
            )
            mutableKnown.add(signature)
        }

        val start = maxOf(0, mutableKnown.size - MAX_EXIT_SIGNATURES)
        for (index in start until mutableKnown.size) {
            updatedKnown.put(mutableKnown[index])
        }
        prefs.edit().putString(KEY_EXIT_SIGNATURES, updatedKnown.toString()).commit()
    }

    private fun parseEvents(raw: String?): JSONArray {
        if (raw.isNullOrBlank()) return JSONArray()
        return try {
            JSONArray(raw)
        } catch (_: Exception) {
            JSONArray()
        }
    }

    private fun ApplicationExitInfo.toDiagnosticMessage(): String {
        val parts = mutableListOf(
            "reason=${reasonLabel(reason)}",
            "reasonCode=$reason",
            "importance=$importance",
            "status=$status",
            "pssKb=$pss",
            "rssKb=$rss",
        )
        if (timestamp > 0L) {
            parts.add("timestamp=${timestamp}")
        }
        description?.takeIf { it.isNotBlank() }?.let { parts.add("description=$it") }
        runtimeSummary?.takeIf { it.isNotBlank() }?.let { parts.add(it) }
        return parts.joinToString(" ")
    }

    private val ApplicationExitInfo.runtimeSummary: String?
        get() {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return null

            val summary = mutableListOf<String>()
            importanceLabel(importance)?.let { summary.add("importanceLabel=$it") }
            return summary.takeIf { it.isNotEmpty() }?.joinToString(",")
        }

    private fun importanceLabel(importance: Int): String? {
        return when (importance) {
            100 -> "foreground"
            125 -> "foreground_service"
            130 -> "visible"
            200 -> "service"
            230 -> "top_sleeping"
            300 -> "cached"
            325 -> "cant_save_state"
            350 -> "cached_empty"
            400 -> "gone"
            else -> null
        }
    }

    private fun reasonLabel(reason: Int): String {
        return when (reason) {
            ApplicationExitInfo.REASON_EXIT_SELF -> "exit_self"
            ApplicationExitInfo.REASON_SIGNALED -> "signaled"
            ApplicationExitInfo.REASON_LOW_MEMORY -> "low_memory"
            ApplicationExitInfo.REASON_CRASH -> "crash"
            ApplicationExitInfo.REASON_CRASH_NATIVE -> "crash_native"
            ApplicationExitInfo.REASON_ANR -> "anr"
            ApplicationExitInfo.REASON_INITIALIZATION_FAILURE -> "initialization_failure"
            ApplicationExitInfo.REASON_PERMISSION_CHANGE -> "permission_change"
            ApplicationExitInfo.REASON_EXCESSIVE_RESOURCE_USAGE -> "excessive_resource_usage"
            ApplicationExitInfo.REASON_USER_REQUESTED -> "user_requested"
            ApplicationExitInfo.REASON_USER_STOPPED -> "user_stopped"
            ApplicationExitInfo.REASON_DEPENDENCY_DIED -> "dependency_died"
            ApplicationExitInfo.REASON_OTHER -> "other"
            ApplicationExitInfo.REASON_FREEZER -> "freezer"
            ApplicationExitInfo.REASON_PACKAGE_STATE_CHANGE -> "package_state_change"
            ApplicationExitInfo.REASON_PACKAGE_UPDATED -> "package_updated"
            else -> "unknown_$reason"
        }
    }
}