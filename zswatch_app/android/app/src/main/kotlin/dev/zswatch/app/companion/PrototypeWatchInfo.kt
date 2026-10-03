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
            else -> return false
        }
        fields.forEach { (key, value) -> info.put(key, value) }
        store.update("watch_info_received", mapOf("watch_info" to info), mapOf("type" to message.getString("t")))
        return true
    }
}
