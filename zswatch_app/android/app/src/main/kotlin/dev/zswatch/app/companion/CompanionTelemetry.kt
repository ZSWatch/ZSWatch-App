package dev.zswatch.app.companion

import org.json.JSONObject
import java.util.UUID

/** Existing health/analytics data, collected by the service even with no Flutter UI. */
internal interface TelemetrySink {
    fun health(address: String, values: Map<String, Double>, timestamp: Long)
    fun battery(address: String, level: Int, charging: Boolean, timestamp: Long)
    fun connection(address: String, type: String, reason: String?, session: String?, timestamp: Long)
    fun lastConnection(): Map<String, Any?>?
}

internal class CompanionTelemetry(private val sink: TelemetrySink, private val store: PrototypeStore,
                                 private val now: () -> Long = System::currentTimeMillis) {
    private var address: String? = null
    private var phase: String? = null
    private var session: String? = null
    private var initialized = false
    private var batteryAddress: String? = null
    private var batteryLevel: Int? = null
    private var batteryCharging: Boolean? = null
    private var batteryTime = 0L
    private var batteryReceipt = 0L

    fun observe(state: Map<String, Any?>) {
        val current = (state["address"] as? String)?.takeIf { it.isNotBlank() }
        val next = state["phase"] as? String
        val at = now()
        if (!initialized && current == null) return
        if (!initialized) {
            // A process can die without a disconnect callback. Close the old
            // persisted session once when the new owner actually changes state.
            sink.lastConnection()?.takeIf { it["event_type"] == "connected" }?.let {
                sink.connection(it["watch_id"] as String, "disconnected", "app_terminated", it["session_id"] as? String, at)
            }
            initialized = true
        }
        if (current != address || next != phase) {
            if (phase == "ready" && address != null) {
                val reason = when {
                    state["desired_running"] != true -> "user_requested"
                    state["last_error"] == "bluetooth_disabled" -> "bluetooth_disabled"
                    else -> "connection_lost"
                }
                sink.connection(address!!, "disconnected", reason, session, at)
            }
            if (current != null && next == "ready" && state["desired_running"] == true) {
                session = UUID.randomUUID().toString()
                sink.connection(current, "connected", null, session, at)
            } else if (current != null && next == "connecting" && state["desired_running"] == true && phase != null) {
                sink.connection(current, "reconnect_attempt", null, session, at)
            } else if (current != null && next == "error" && phase == "connecting") {
                sink.connection(current, "reconnect_failed", "connection_lost", session, at)
            }
            address = current; phase = next
        }
        if (current == null || next != "ready" || state["desired_running"] != true) return
        val info = state["watch_info"] as? Map<*, *> ?: return
        if (info["address"] != current || (info["status_generation"] as? Number)?.toLong() != (state["generation"] as? Number)?.toLong()) return
        val receipt = (info["status_observed_ms"] as? Number)?.toLong() ?: return
        if (receipt <= batteryReceipt && current == batteryAddress) return
        val level = (info["battery_level"] as? Number)?.toInt()?.takeIf { it in 0..100 } ?: return
        val charging = info["is_charging"] == true
        if (current != batteryAddress || batteryLevel == null ||
            kotlin.math.abs(level - batteryLevel!!) >= 5 || charging != batteryCharging || receipt - batteryTime >= 300000) {
            sink.battery(current, level, charging, receipt)
            batteryAddress = current; batteryLevel = level; batteryCharging = charging; batteryTime = receipt
        }
        batteryReceipt = receipt
    }

    fun close() {
        if (phase == "ready" && address != null) {
            sink.connection(address!!, "disconnected", "app_terminated", session, now())
        }
        phase = "stopped"
    }

    fun activity(message: JSONObject, generation: Long): Boolean {
        val state = store.control()
        if (message.optString("t") != "act" || state["desired_running"] != true ||
            state["phase"] != "ready" || (state["generation"] as Number).toLong() != generation) return false
        val watch = state["address"] as String
        fun integer(name: String): Long? = when (val value = message.opt(name)) {
            is Int -> value.toLong()
            is Long -> value
            else -> null
        }
        val at = integer("ts")?.takeIf { it >= 0 } ?: now()
        val values = mutableMapOf<String, Any?>("address" to watch, "generation" to generation, "ts" to at,
            "sequence" to (state["event_cursor"] as Number).toLong() + 1)
        val samples = linkedMapOf<String, Double>()
        integer("stp")?.takeIf { it in 0..Int.MAX_VALUE.toLong() }?.let {
            samples["steps"] = it.toDouble(); values["stp"] = it
        }
        integer("hrm")?.takeIf { it in 30..250 }?.let {
            samples["heartRate"] = it.toDouble(); values["hrm"] = it
        }
        (message.opt("act") as? String)?.let { name ->
            val value = listOf("UNKNOWN", "NOT_WORN", "DEEP_SLEEP", "LIGHT_SLEEP", "REM_SLEEP",
                "ACTIVITY", "RUNNING", "WALKING", "SWIMMING", "CYCLING", "EXERCISE").indexOf(name)
            if (value >= 0) { samples["activity"] = value.toDouble(); values["act"] = name }
        }
        if (samples.isEmpty()) return false
        sink.health(watch, samples, at)
        store.update("health_received", mapOf("latest_health" to values))
        return true
    }
}
