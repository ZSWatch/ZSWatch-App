package dev.zswatch.app.companion

import org.json.JSONObject

/** The watch receives the existing bounded result popup, not executable actions. */
object PrototypeVoiceResult {
    private fun bounded(text: String, limit: Int): String {
        var end = 0
        while (end < text.length) {
            val next = end + Character.charCount(text.codePointAt(end))
            if (text.substring(0, next).toByteArray(Charsets.UTF_8).size > limit) break
            end = next
        }
        return text.substring(0, end)
    }

    fun packet(envelope: JSONObject, filename: String): JSONObject {
        require(Regex("[A-Za-z0-9_-]{1,31}").matches(filename))
        require(envelope.getLong("generation") in 1..0xffffffffL)
        val result = envelope.getJSONObject("result")
        PrototypeJobs.validateResult(result)
        val first = result.getJSONArray("actions").optJSONObject(0)
        // Chat answers use the watch's larger answer buffer.
        val answer = result.getString("category") == "chat"
        return JSONObject().put("t", "voice_memo").put("action", "result").put("version", 1)
            .put("result_id", envelope.getString("result_id"))
            .put("recording_key", PrototypeJobs.sha(envelope.getString("recording_id")))
            .put("result_sha256", PrototypeJobs.sha(PrototypeJobs.canonical(result)))
            .put("generation", envelope.getLong("generation")).put("filename", filename)
            .put("text", bounded(result.getString("summary"), if (answer) 1023 else 127))
            .put("action_type", if (answer) "chat" else first?.optString("type") ?: "")
            .put("datetime", bounded(first?.optString("start_time")?.takeIf { it.isNotEmpty() }
                ?: first?.optString("due_date") ?: "", 31))
    }

    fun matches(packet: JSONObject, ack: JSONObject): Boolean =
        ack.optString("t") == "voice_memo" && ack.optString("action") == "result_ack" &&
        ack.opt("version") == 1 && ack.optString("status") == "accepted" &&
        listOf("result_id", "recording_key", "result_sha256").all { ack.opt(it) == packet.get(it) } &&
        (ack.opt("generation") is Int || ack.opt("generation") is Long) &&
        ack.getLong("generation") == packet.getLong("generation")
}
