package dev.zswatch.app.companion

import org.json.JSONObject
import org.json.JSONArray
import org.junit.Assert.*
import org.junit.Test

class PrototypeVoiceResultTest {
    private fun result() = JSONObject().put("version", 1).put("transcript", "Owned test")
        .put("summary", "Köp mjölk 🔋".repeat(20)).put("category", "reminder")
        .put("actions", JSONArray().put(JSONObject().put("type", "reminder").put("title", "Milk")
            .put("due_date", "2026-10-05T09:00:00.000+02:00")))
    private fun envelope() = JSONObject().put("result_id", "a".repeat(64)).put("recording_id", "watch:file:metadata")
        .put("generation", 1L).put("result", result())

    @Test fun popupBoundsPreserveUnicodeAndDoNotExecuteActions() {
        val packet = PrototypeVoiceResult.packet(envelope(), "owned_sample")
        assertTrue(packet.getString("text").toByteArray(Charsets.UTF_8).size <= 127)
        assertFalse(packet.getString("text").contains('\uFFFD'))
        assertTrue(packet.getBoolean("draft"))
        assertFalse(packet.has("actions"))
        assertEquals(PrototypeJobs.sha(PrototypeJobs.canonical(result())), packet.getString("result_sha256"))
    }

    @Test fun ackRequiresExactResultDigestRecordingAndIntegerGenerationAcrossJsonRoundtrip() {
        val packet = PrototypeVoiceResult.packet(envelope(), "owned_sample")
        val ack = JSONObject(packet.toString()).put("action", "result_ack").put("status", "accepted")
        assertTrue(PrototypeVoiceResult.matches(packet, ack))
        for (field in listOf("result_id", "recording_key", "result_sha256", "status")) {
            assertFalse(PrototypeVoiceResult.matches(packet, JSONObject(ack.toString()).put(field, "wrong")))
        }
        assertFalse(PrototypeVoiceResult.matches(packet, JSONObject(ack.toString()).put("generation", 2)))
        assertFalse(PrototypeVoiceResult.matches(packet, JSONObject(ack.toString()).put("generation", 1.0)))
        assertFalse(PrototypeVoiceResult.matches(packet, JSONObject(ack.toString()).put("version", 2)))
    }
}
