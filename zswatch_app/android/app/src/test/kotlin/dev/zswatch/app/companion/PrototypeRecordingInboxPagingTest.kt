package dev.zswatch.app.companion

import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class PrototypeRecordingInboxPagingTest {
    @get:Rule val temporary = TemporaryFolder()

    private fun store() = PrototypeStore(temporary.newFolder("inbox")).also {
        it.update("selected", mapOf("address" to "watch-a"))
    }

    private fun list(vararg names: String, more: Boolean) = JSONObject()
        .put("t", "voice_memo").put("action", "list_result").put("more", more)
        .put("recordings", JSONArray().apply {
            names.forEach { put(JSONObject().put("filename", it).put("timestamp", 123)
                .put("size_bytes", 100).put("duration_ms", 1000)) }
        })

    private fun key(name: String) = "watch-a:$name:123:100:1000"

    @Test fun downloadedListEntriesAreDeletedOnWatchAndNextPageRequested() {
        val store = store()
        val deleted = mutableListOf<String>()
        var requests = 0
        val inbox = PrototypeRecordingInbox(store, { deleted += it }) { requests++ }
        inbox.receive(list("a", "b", more = true))
        assertEquals(emptyList<String>(), deleted)
        assertEquals(0, requests)

        store.putRecord(key("a"), store.record(key("a"))!! + mapOf("state" to "downloaded"))
        inbox.receive(list("a", "b", more = true))
        assertEquals(listOf("a"), deleted)
        assertEquals(1, requests)
        assertEquals(true, (store.control()["recording_list"] as Map<*, *>)["more"])
    }

    @Test fun lastPageDoesNotRequestAgain() {
        val store = store()
        var requests = 0
        val inbox = PrototypeRecordingInbox(store, {}) { requests++ }
        inbox.receive(list("a", more = false))
        store.putRecord(key("a"), store.record(key("a"))!! + mapOf("state" to "downloaded"))
        inbox.receive(list("a", more = false))
        assertEquals(0, requests)
    }

    @Test fun watchDeleteAndFailedRetryAreBounded() {
        val store = store()
        val deleted = mutableListOf<String>()
        val inbox = PrototypeRecordingInbox(store, { deleted += it }) {}
        inbox.receive(list("a", "b", more = false))
        store.putRecord(key("a"), store.record(key("a"))!! + mapOf("state" to "downloaded"))
        repeat(5) {
            store.putRecord(key("b"), store.record(key("b"))!! + mapOf("state" to "failed"))
            inbox.receive(list("a", "b", more = false))
        }
        assertEquals(3, deleted.size)
        assertEquals("failed", store.record(key("b"))!!["state"])
        assertEquals(3, (store.record(key("b"))!!["list_retries"] as Number).toInt())
    }
}
