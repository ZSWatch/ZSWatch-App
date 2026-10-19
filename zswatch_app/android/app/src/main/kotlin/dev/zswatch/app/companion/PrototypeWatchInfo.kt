package dev.zswatch.app.companion

import org.json.JSONObject

/** Existing Gadgetbridge version/status messages, owned and cached by the service. */
class PrototypeWatchInfo(private val store: PrototypeStore) {
    fun receive(message: JSONObject, generation: Long, now: Long): Boolean {
        val state = store.control()
        if (state["desired_running"] != true || (state["generation"] as Number).toLong() != generation) return false
        val address = state["address"] as? String ?: return false
        val old = state["watch_info"] as? Map<*, *>
        val info = if (old?.get("address") == address) JSONObject(old)
            else JSONObject().put("address", address).put("first_seen_ms", now)
        val fields = mutableMapOf<String, Any>()
        when (message.optString("t")) {
            "ver" -> {
                for ((wire, field) in listOf("fw" to "firmware_version", "hw" to "hardware_version", "sha" to "firmware_sha")) {
                    val value = message.opt(wire)
                    if (value is String && value.isNotBlank() && value.toByteArray(Charsets.UTF_8).size <= 160)
                        fields[field] = value
                }
                (message.opt("dbg") as? Int)?.takeIf { it in 0..1 }?.let { fields["firmware_debug"] = it == 1 }
                if (fields.isEmpty()) return false
                fields["version_generation"] = generation
                fields["version_observed_ms"] = now
            }
            "status" -> {
                fun integer(name: String, range: LongRange): Long? {
                    val value = message.opt(name)
                    if (value !is Int && value !is Long) return null
                    return (value as Number).toLong().takeIf { it in range }
                }
                val battery = integer("bat", 0L..100L) ?: return false
                fields["battery_level"] = battery
                integer("volt", 0L..10000L)?.let { fields["battery_mv"] = it }
                integer("chg", 0L..1L)?.let { fields["is_charging"] = it == 1L }
                if (fields.isEmpty()) return false
                fields["status_generation"] = generation
                fields["status_observed_ms"] = now
            }
            "coredump" -> {
                val available = message.opt("available") as? Boolean ?: return false
                if (available) {
                    val file = message.opt("file") as? String ?: return false
                    val time = message.opt("time") as? String ?: return false
                    val line = message.opt("line")
                    if (line !is Int || line < 0 || file.toByteArray(Charsets.UTF_8).size > 512 ||
                        time.length !in 1..80) return false
                    fields["coredump"] = JSONObject().put("file", file).put("line", line).put("time", time)
                } else fields["coredump"] = JSONObject.NULL
                fields["coredump_generation"] = generation
                fields["coredump_observed_ms"] = now
            }
            else -> return false
        }
        fields.forEach { (key, value) -> info.put(key, value) }
        store.update("watch_info_received", mapOf("watch_info" to info), mapOf("type" to message.getString("t")))
        return true
    }
}
