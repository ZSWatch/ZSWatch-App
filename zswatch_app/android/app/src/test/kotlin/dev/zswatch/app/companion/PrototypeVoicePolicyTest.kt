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

    @Test(expected = IllegalArgumentException::class)
    fun rejectsAmbiguousModelEncoding() {
        PrototypeVoicePolicy.configuration("kbWhisperBase", "model|true", false)
    }
}
