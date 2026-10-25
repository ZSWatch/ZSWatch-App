package dev.zswatch.app.companion

import org.junit.Assert.*
import org.junit.Test
import org.junit.Rule
import org.junit.rules.TemporaryFolder
import org.json.JSONObject

class PrototypeVoicePolicyTest {
    @get:Rule val temporary = TemporaryFolder()

    @Test fun discoveryDoesNotEnrollOldRecordingsOrChangeAcceptedRequests() {
        var store = PrototypeStore(temporary.newFolder("inbox"))
        store.update("selected", mapOf("address" to "watch-a"))
        fun discover(name: String) = PrototypeRecordingInbox(store) {}.receive(JSONObject()
            .put("t", "voice_memo").put("action", "list_result").put("recordings",
                org.json.JSONArray().put(JSONObject().put("filename", name).put("timestamp", 123)
                    .put("size_bytes", 100).put("duration_ms", 1000))))
        discover("old")
        val config = PrototypeVoicePolicy.configuration("kbWhisperBase", "qwen", false)
        store.update("enabled", mapOf("voice_processing_policy" to
            (config + mapOf("watch_id" to "watch-a", "enabled" to true))))
        discover("old"); discover("new")
        store = PrototypeStore(java.io.File(temporary.root, "inbox"))
        assertFalse(store.record("watch-a:old:123:100:1000")!!.containsKey("processing_request"))
        assertEquals(config, store.record("watch-a:new:123:100:1000")!!["processing_request"])
        store.update("disabled", mapOf("voice_processing_policy" to
            (config + mapOf("watch_id" to "watch-a", "enabled" to false))))
        discover("new"); discover("off")
        assertEquals(config, store.record("watch-a:new:123:100:1000")!!["processing_request"])
        assertFalse(store.record("watch-a:off:123:100:1000")!!.containsKey("processing_request"))
    }
    @Test fun invalidAndOverCapacityListEntriesAreSkippedWithoutFailingTheList() {
        val store = PrototypeStore(temporary.newFolder("skip"))
        store.update("selected", mapOf("address" to "watch-a"))
        fun entry(name: String, size: Long = 100) = JSONObject().put("filename", name).put("timestamp", 123)
            .put("size_bytes", size).put("duration_ms", 1000)
        PrototypeRecordingInbox(store) {}.receive(JSONObject().put("t", "voice_memo").put("action", "list_result")
            .put("recordings", org.json.JSONArray().put(entry("bad name")).put(entry("huge", 32L * 1024 * 1024))
                .put(entry("a".repeat(32))).put(JSONObject().put("filename", "no_size")).put(entry("good"))))
        assertNotNull(store.record("watch-a:good:123:100:1000"))
        assertEquals(1, (store.control()["recordings"] as Map<*, *>).size)
        for (index in 1 until PrototypeStore.RECORD_LIMIT) store.putRecord("filler-$index", mapOf("state" to "downloaded"))
        PrototypeRecordingInbox(store) {}.receive(JSONObject().put("t", "voice_memo").put("action", "list_result")
            .put("recordings", org.json.JSONArray().put(entry("good")).put(entry("over"))))
        assertNull(store.record("watch-a:over:123:100:1000"))
        assertNotNull(store.record("watch-a:good:123:100:1000"))
        val skipped = (store.control()["events"] as List<*>).map { it as Map<*, *> }
            .last { it["kind"] == "recording_list_entries_skipped" }["detail"] as Map<*, *>
        assertEquals(1, skipped["capacity"])
    }
    @Test fun requestsAreWatchScopedAndCaptureConfiguration() {
        val config = PrototypeVoicePolicy.configuration("kbWhisperBase", "qwen", false)
        val policy = config + mapOf("watch_id" to "watch-a", "enabled" to true)
        assertNull(PrototypeVoicePolicy.recordingRequest(policy, "watch-b"))
        assertNull(PrototypeVoicePolicy.recordingRequest(policy + ("enabled" to false), "watch-a"))
        val request = PrototypeVoicePolicy.recordingRequest(policy, "watch-a")!!
        assertEquals("kbWhisperBase|qwen|false", PrototypeVoicePolicy.model(request))
        // A later preference change does not mutate the recording's captured request.
        val changed = policy + ("analysis_model" to "new-model")
        assertEquals("kbWhisperBase|new-model|false", PrototypeVoicePolicy.model(
            PrototypeVoicePolicy.recordingRequest(changed, "watch-a")!!))
        assertEquals("kbWhisperBase|qwen|false", PrototypeVoicePolicy.model(request))
    }
    @Test fun questionsUseThePolicyOfAnyWatch() {
        val policy = PrototypeVoicePolicy.configuration("kbWhisperBase", "openrouter:m", false) +
            mapOf("watch_id" to "watch-a", "enabled" to false)
        assertNull(PrototypeVoicePolicy.recordingRequest(policy, "watch-b", "20261022_103603"))
        assertNotNull(PrototypeVoicePolicy.recordingRequest(policy, "watch-b", "chat_20261022_103603"))
    }
    @Test fun dictatedRepliesAreAlwaysProcessedAndReachTheWatch() {
        val policy = PrototypeVoicePolicy.configuration("kbWhisperBase", "openrouter:m", false, analyze = false) +
            mapOf("watch_id" to "watch-a", "enabled" to false)
        val request = PrototypeVoicePolicy.recordingRequest(policy, "watch-b", "reply_20261025_001710")!!
        // Not transcription only, that result would stay on the phone.
        assertEquals(true, request["analysis_enabled"])
        assertFalse(PrototypeVoicePolicy.isReply("20261025_001710"))
    }

    @Test(expected = IllegalArgumentException::class)
    fun rejectsAmbiguousModelEncoding() {
        PrototypeVoicePolicy.configuration("kbWhisperBase", "model|true", false)
    }
}
