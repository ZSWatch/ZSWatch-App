package dev.zswatch.app.companion

import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder

class PrototypeRecordingLibraryTest {
    @get:Rule val temporary = TemporaryFolder()

    private val key = "watch-a:memo:123:38:20"
    private val metadata = mapOf("address" to "watch-a", "filename" to "memo", "timestamp" to 123L,
        "size_bytes" to 38, "duration_ms" to 20L, "state" to "pending")

    // One 4-byte frame at 1000 Hz with 20-sample frames: 20 ms.
    private fun container(): ByteArray = ByteBuffer.allocate(38).order(ByteOrder.LITTLE_ENDIAN).apply {
        put("ZSWO".toByteArray()); putShort(1); putShort(1000); putShort(20)
        position(16); putInt(123); putInt(1); putInt(20)
        position(32); putShort(4); put(byteArrayOf(1, 2, 3, 4))
    }.array()

    private class Fixture(val store: PrototypeStore, val jobStore: PrototypeStore, val files: ReceiptFiles,
                          val root: File, val library: PrototypeRecordingLibrary)

    private fun fixture(): Fixture {
        val root = temporary.newFolder("files")
        val store = PrototypeStore(File(root, "companion-prototype"))
        store.update("selected", mapOf("address" to "watch-a"))
        val jobStore = PrototypeStore(File(root, "companion-prototype/jobs"), 64)
        val files = ReceiptFiles(File(root, "companion-prototype/recordings"))
        store.putRecord(key, files.publish(key, metadata, container()))
        return Fixture(store, jobStore, files, root, PrototypeRecordingLibrary(store, files) { PrototypeJobs(jobStore) })
    }

    private fun job(jobs: PrototypeJobs): String = jobs.create(JSONObject().put("version", 1).put("watch_id", "watch-a")
        .put("recording_id", key).put("input_sha256", "a".repeat(64)).put("backend", "local")
        .put("provider", "dart-voice-v1").put("model", "m").put("pipeline_revision", "voice-v1")
        .put("generation", 1).put("upload_authorized", false))

    @Test fun removeMovesToTrashAndRestoreBringsItBack() {
        val f = fixture()
        val jobs = PrototypeJobs(f.jobStore)
        val id = job(jobs)
        val audio = f.files.destination(key)
        f.library.remove(listOf(key))
        assertEquals("deleted", f.store.record(key)!!["state"])
        assertFalse(audio.exists())
        assertEquals("cancelled", jobs.state(id).getString("state"))
        f.library.restore(key)
        assertEquals("downloaded", f.store.record(key)!!["state"])
        assertTrue(audio.isFile)
    }

    @Test fun restoreBringsBackAProcessedResult() {
        val f = fixture()
        val jobs = PrototypeJobs(f.jobStore)
        val id = job(jobs)
        f.jobStore.update("seed", mapOf("jobs" to JSONObject().put(id, jobs.state(id).put("state", "result_ready")),
            "outbox" to JSONObject().put("r", JSONObject().put("job_id", id).put("watch_id", "watch-a").put("state", "pending"))))
        f.library.remove(listOf(key))
        assertEquals("cancelled", jobs.state(id).getString("state"))
        f.library.restore(key)
        assertEquals("result_ready", jobs.state(id).getString("state"))
        assertFalse(jobs.state(id).has("removed_from"))
        assertEquals(1, jobs.pending("watch-a").size)
    }

    @Test fun purgeRemovesFilesAndJobsForGood() {
        val f = fixture()
        val jobs = PrototypeJobs(f.jobStore)
        job(jobs)
        val playback = File(f.root, "companion-recording-imports-v1").apply { mkdirs() }
        val ogg = File(playback, "${ReceiptFiles.sha(key.toByteArray())}-${f.store.record(key)!!["sha256"]}-ogg-v1.ogg")
            .apply { writeText("ogg") }
        f.library.remove(listOf(key))
        f.library.purge(listOf(key))
        val record = f.store.record(key)!!
        assertEquals(true, record["purged"])
        assertEquals(false, record["purge_pending"])
        assertFalse(ogg.exists())
        assertTrue(File(f.root, "companion-prototype/recordings/recently-deleted").listFiles()!!.isEmpty())
        assertTrue(jobs.identities().isEmpty())
    }

    @Test fun recoverFinishesInterruptedDelete() {
        val f = fixture()
        f.store.putRecord(key, f.store.record(key)!! + mapOf("state" to "deleted"))
        f.library.recover()
        assertFalse(f.files.destination(key).exists())
        assertEquals("deleted", f.store.record(key)!!["state"])
    }

    @Test fun renameArchiveAndSearch() {
        val f = fixture()
        f.library.update(key, " Groceries ", true)
        assertEquals("Groceries", f.store.record(key)!!["title"])
        assertEquals(true, f.store.record(key)!!["archived"])
        assertEquals(setOf(key), f.library.search("grocer"))
        assertEquals(emptySet<String>(), f.library.search("nothing"))
    }

    @Test fun transcriptEditBecomesSelectedRevision() {
        val f = fixture()
        val jobs = PrototypeJobs(f.jobStore)
        val id = job(jobs)
        val item = jobs.state(id)
        f.jobStore.update("seed", mapOf("jobs" to JSONObject().put(id, item.put("state", "transcribed")
            .put("transcript", "old").put("result", JSONObject().put("version", 1).put("transcript", "old")
                .put("summary", "").put("category", "").put("actions", JSONArray())))))
        val edited = jobs.editTranscript(id, "new words")
        assertTrue(jobs.state(edited).optBoolean("selected"))
        assertFalse(jobs.state(id).optBoolean("selected"))
        assertEquals(setOf(key), jobs.search("new words"))
        assertNull(jobs.state(edited).opt("remote_id").takeIf { it != JSONObject.NULL })
    }
}
