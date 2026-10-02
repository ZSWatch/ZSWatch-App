package dev.zswatch.app.companion

import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream

/** Private prototype journal. Never opens or migrates the Flutter/Drift DB. */
class PrototypeStore(private val directory: File, private val eventLimit: Int = 256) {
    private val file = File(directory, "state-v1.json")
    private var data: JSONObject
    var onChanged: (() -> Unit)? = null

    init {
        require(eventLimit > 0)
        directory.mkdirs()
        data = if (file.exists()) JSONObject(file.readText(Charsets.UTF_8)) else JSONObject()
            .put("version", 1).put("desired_running", false).put("address", "")
            .put("generation", 0L).put("phase", "stopped").put("last_error", JSONObject.NULL)
            .put("last_time_write_utc_ms", JSONObject.NULL).put("event_cursor", 0L)
            .put("acked_cursor", 0L).put("events", JSONArray()).put("recordings", JSONObject())
        require(data.getInt("version") == 1) { "Unsupported prototype journal version" }
    }

    @Synchronized fun control(): Map<String, Any?> = asMap(data)

    /** Commit state plus event in one flushed rename before notifying a UI. */
    @Synchronized fun update(kind: String, fields: Map<String, Any?> = emptyMap(),
                             detail: Map<String, Any?> = emptyMap()) {
        val next = JSONObject(data.toString())
        fields.forEach { (key, value) -> next.put(key, value ?: JSONObject.NULL) }
        val sequence = next.getLong("event_cursor") + 1
        next.put("event_cursor", sequence)
        val old = next.getJSONArray("events")
        val events = JSONArray()
        for (index in maxOf(0, old.length() - eventLimit + 1) until old.length()) events.put(old.get(index))
        events.put(JSONObject().put("seq", sequence).put("kind", kind)
            .put("utc_ms", System.currentTimeMillis()).put("detail", JSONObject(detail)))
        next.put("events", events)
        persist(next)
    }

    @Synchronized fun acknowledge(cursor: Long) {
        require(cursor in 0..data.getLong("event_cursor")) { "ACK beyond committed cursor" }
        if (cursor <= data.getLong("acked_cursor")) return
        val next = JSONObject(data.toString()).put("acked_cursor", cursor)
        val kept = JSONArray()
        val events = next.getJSONArray("events")
        for (index in 0 until events.length()) {
            if (events.getJSONObject(index).getLong("seq") > cursor) kept.put(events.get(index))
        }
        next.put("events", kept)
        persist(next)
    }

    @Synchronized fun record(key: String): Map<String, Any?>? =
        data.getJSONObject("recordings").optJSONObject(key)?.let(::asMap)

    @Synchronized fun putRecord(key: String, metadata: Map<String, Any?>) {
        val records = JSONObject(data.getJSONObject("recordings").toString())
        require(records.has(key) || records.length() < 100) { "Prototype receipt capacity reached" }
        records.put(key, JSONObject(metadata))
        update("recording_state", mapOf("recordings" to records), mapOf("recording_key" to key))
    }

    @Synchronized fun snapshot(active: Boolean): Map<String, Any?> {
        val map = asMap(data).toMutableMap()
        val events = data.getJSONArray("events")
        val oldest = if (events.length() == 0) data.getLong("event_cursor") + 1
                     else events.getJSONObject(0).getLong("seq")
        map["oldest_event_cursor"] = oldest
        map["event_gap"] = data.getLong("acked_cursor") < oldest - 1
        map["runtime_active"] = active
        map["protocol_ready"] = active && data.getString("phase") == "ready"
        map["owner"] = "android_service_native"
        return map
    }

    private fun persist(next: JSONObject) {
        val temporary = File.createTempFile("state-", ".partial", directory)
        try {
            FileOutputStream(temporary).use { stream ->
                stream.write(next.toString().toByteArray(Charsets.UTF_8))
                stream.fd.sync()
            }
            check(temporary.renameTo(file)) { "Prototype journal publication failed" }
            data = next
        } finally { temporary.delete() }
        onChanged?.invoke()
    }

    companion object {
        fun asMap(json: JSONObject): Map<String, Any?> = json.keys().asSequence().associateWith { key ->
            decode(json.get(key))
        }
        private fun decode(value: Any?): Any? = when (value) {
            JSONObject.NULL -> null
            is JSONObject -> asMap(value)
            is JSONArray -> (0 until value.length()).map { decode(value.get(it)) }
            else -> value
        }
    }
}
