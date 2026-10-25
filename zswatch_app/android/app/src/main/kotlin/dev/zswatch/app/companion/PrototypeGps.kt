package dev.zswatch.app.companion

import org.json.JSONObject

/** Coordinates exist only in memory and the watch wire packet. */
internal data class PrototypeGpsFix(
    val latitude: Double, val longitude: Double,
    val elapsedMs: Long, val utcMs: Long,
    val altitude: Double? = null, val speedMps: Double? = null,
    val bearing: Double? = null, val accuracy: Double? = null,
) {
    fun packet(nowMs: Long, weather: Boolean = false): String? {
        if (!latitude.isFinite() || latitude !in -90.0..90.0 ||
            !longitude.isFinite() || longitude !in -180.0..180.0 ||
            elapsedMs < 0 || nowMs < elapsedMs || nowMs - elapsedMs > (if (weather) 1800000 else 30000) || utcMs <= 0) return null
        if (weather && (accuracy == null || !accuracy.isFinite() || accuracy !in 0.0..50000.0)) return null
        val json = JSONObject().put("t", "gps").put("lat", latitude).put("lon", longitude)
            .put("time", utcMs).put("externalSource", true).put("gpsSource", "phone")
        altitude?.takeIf { it.isFinite() }?.let { json.put("alt", it) }
        speedMps?.takeIf { it.isFinite() && it >= 0 }?.let { json.put("speed", it * 3.6) }
        bearing?.takeIf { it.isFinite() && it in 0.0..360.0 }?.let { json.put("course", it) }
        // Preserve the existing Dart mapping: accuracy in meters, not actual HDOP.
        accuracy?.takeIf { it.isFinite() && it >= 0 }?.let { json.put("hdop", it) }
        return "GB($json)"
    }
}

internal interface PrototypeGpsSource {
    /** All callbacks and cancellation run on the same native worker. */
    fun start(fix: (PrototypeGpsFix) -> Unit, failed: (String) -> Unit): () -> Unit
}

/** Worker-owned acquisition. No permission prompts, durable locations or replay. */
internal class PrototypeGps(
    private val enabled: () -> Boolean,
    private val blocked: () -> String?,
    private val foreground: (Boolean) -> Unit,
    private val source: PrototypeGpsSource,
    private val now: () -> Long,
    private val later: (Long, () -> Unit) -> Unit,
    private val send: (Long, String, () -> Boolean, () -> Unit) -> Boolean,
    private val observe: (Long, String, Boolean) -> Unit,
) {
    private class Request(val generation: Long, val weather: Boolean) {
        var cancel: (() -> Unit)? = null
        var lastAdmittedMs: Long? = null
        var writing = false
        var pending: PrototypeGpsFix? = null
        var retryScheduled = false
    }
    private var generation: Long? = null
    private var request: Request? = null

    fun ready(token: Long) { close(); generation = token; observe(token, "idle", false) }

    fun receive(message: JSONObject, token: Long) {
        if (message.opt("t") != "gps_power" || token != generation) return
        val wanted = message.opt("status") as? Boolean ?: return
        if (!wanted) { release("idle"); return }
        if (!enabled()) { release("disabled"); return }
        blocked()?.let { release(it); return }
        if (request != null) return
        val next = Request(token, message.optString("purpose") == "weather")
        request = next
        try {
            foreground(true)
            observe(token, "acquiring", true)
            next.cancel = source.start({ fix ->
                if (request === next) {
                    blocked()?.let { release(it); return@start }
                    next.pending = fix
                    flush(next)
                }
            }, { error -> if (request === next) release(error) })
            // A source can reject synchronously. Do not leak its registration.
            if (request !== next) { next.cancel?.invoke(); return }
            later(10000) {
                if (request === next && next.lastAdmittedMs == null) release("location_unavailable")
            }
        } catch (_: SecurityException) { release("permission_required") }
        catch (_: Exception) { release("location_unavailable") }
    }

    fun configurationChanged() {
        if (!enabled()) release("disabled")
        else blocked()?.let { release(it) }
    }

    fun refresh() { request?.let { current ->
        blocked()?.let { release(it); return }
        flush(current)
    } }

    private fun flush(expected: Request) {
        if (request !== expected || expected.writing) return
        val time = now()
        val remaining = expected.lastAdmittedMs?.let { 5000 - (time - it) } ?: 0
        if (remaining > 0) { retry(expected, remaining); return }
        val fix = expected.pending ?: return
        val packet = fix.packet(time, expected.weather) ?: run { expected.pending = null; return }
        val previousAdmission = expected.lastAdmittedMs
        expected.pending = null
        expected.lastAdmittedMs = time
        expected.writing = true
        val accepted = send(expected.generation, packet, {
            val allowed = request === expected && enabled() && blocked() == null && fix.packet(now(), expected.weather) != null
            if (!allowed && request === expected) release(blocked() ?: "location_unavailable")
            allowed
        }, {
            if (request === expected) {
                expected.writing = false
                observe(expected.generation, "written", true)
                flush(expected)
            }
        })
        if (!accepted) {
            expected.writing = false
            expected.lastAdmittedMs = previousAdmission
            if (expected.pending == null) expected.pending = fix
            retry(expected, 500)
        }
    }

    private fun retry(expected: Request, delay: Long) {
        if (expected.retryScheduled) return
        expected.retryScheduled = true
        later(delay) {
            expected.retryScheduled = false
            if (request === expected) {
                blocked()?.let { release(it); return@later }
                flush(expected)
            }
        }
    }

    private fun release(state: String) {
        val old = request
        request = null
        if (old != null) {
            runCatching { old.cancel?.invoke() }
            runCatching { foreground(false) }
        }
        generation?.let { observe(it, state, false) }
    }

    fun close() { release("idle"); generation = null }
}
