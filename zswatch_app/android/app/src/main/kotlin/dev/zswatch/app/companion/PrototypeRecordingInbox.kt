package dev.zswatch.app.companion

import org.json.JSONException
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
                var skipped = 0
                var full = 0
                for (index in 0 until list.length()) {
                    // One unexpected entry must not drop the link; the same
                    // list returns after every reconnect. Journal failures still propagate.
                    val queued = try { queue(list.getJSONObject(index)) }
                        catch (_: JSONException) { Queued.INVALID }
                        catch (_: IllegalArgumentException) { Queued.INVALID }
                    when (queued) {
                        Queued.INVALID -> skipped++
                        Queued.FULL -> full++
                        Queued.OK -> {}
                    }
                }
                if (skipped > 0 || full > 0) store.update("recording_list_entries_skipped",
                    detail = mapOf("invalid" to skipped, "capacity" to full))
                val state = store.control()
                // Even an unchanged/empty list is a fresh watch response. This
                // does not alter receipts, retry failures or enable downloads.
                store.update("recording_list_received", mapOf("recording_list" to mapOf(
                    "address" to state["address"], "generation" to state["generation"],
                    "observed_ms" to System.currentTimeMillis(), "count" to list.length(),
                    "result_ack_version" to if (message.opt("result_ack_version") == 1) 1 else 0)))
            }
        }
    }

    private enum class Queued { OK, INVALID, FULL }

    private fun queue(json: JSONObject): Queued {
        val name = json.getString("filename")
        // Firmware filenames are char[32]; the result packet carries at most 31.
        require(Regex("[A-Za-z0-9_-]{1,31}").matches(name)) { "Unsafe recording filename" }
        val size = json.getLong("size_bytes")
        require(size in 34..(16L * 1024 * 1024)) { "Prototype recording size unsupported" }
        val timestamp = json.getLong("timestamp")
        val duration = json.getLong("duration_ms")
        require(timestamp in 0..0xffffffffL && duration > 0)
        val address = store.control()["address"] as String
        val key = "$address:$name:$timestamp:$size:$duration"
        if (store.record(key) != null) return Queued.OK
        if (!store.hasRecordRoom(key)) return Queued.FULL
        val request = PrototypeVoicePolicy.recordingRequest(store.control()["voice_processing_policy"], address)
        store.putRecord(key, mapOf("address" to address, "filename" to name, "timestamp" to timestamp,
            "size_bytes" to size, "duration_ms" to duration, "state" to "pending") +
            (request?.let { mapOf("processing_request" to it) } ?: emptyMap()))
        return Queued.OK
    }
}
