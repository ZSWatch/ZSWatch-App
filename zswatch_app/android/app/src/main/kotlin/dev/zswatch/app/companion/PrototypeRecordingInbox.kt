package dev.zswatch.app.companion

import org.json.JSONObject

/** Only list entries contain the timestamp stored in the recording's header. */
class PrototypeRecordingInbox(private val store: PrototypeStore, private val requestList: () -> Unit) {
    fun receive(message: JSONObject) {
        if (message.optString("t") != "voice_memo") return
        when (message.optString("action")) {
            // Firmware's new-event timestamp is stop time, not the file's start time.
            "new" -> requestList()
            "list_result" -> {
                val list = message.optJSONArray("recordings") ?: return
                for (index in 0 until list.length()) queue(list.getJSONObject(index))
            }
        }
    }

    private fun queue(json: JSONObject) {
        val name = json.getString("filename")
        require(Regex("[A-Za-z0-9_-]{1,32}").matches(name)) { "Unsafe recording filename" }
        val size = json.getLong("size_bytes")
        require(size in 34..(16L * 1024 * 1024)) { "Prototype recording size unsupported" }
        val timestamp = json.getLong("timestamp")
        val duration = json.getLong("duration_ms")
        require(timestamp in 0..0xffffffffL && duration > 0)
        val address = store.control()["address"] as String
        val key = "$address:$name:$timestamp:$size:$duration"
        if (store.record(key) != null) return
        store.putRecord(key, mapOf("address" to address, "filename" to name, "timestamp" to timestamp,
            "size_bytes" to size, "duration_ms" to duration, "state" to "pending"))
    }
}
