package dev.zswatch.app.companion

import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File

class PrototypeJobsTest {
    @get:Rule val temporary = TemporaryFolder()
    private val fixtures get() = File(requireNotNull(System.getProperty("companion.fixtures")))
    private fun fixture(name: String) = JSONObject(File(fixtures, name).readText())
    private fun store() = PrototypeStore(File(temporary.root, "jobs"))
    private fun spec() = fixture("job-v1.json")
    private fun rejected(action: () -> Unit) { try { action(); fail("Expected rejection") } catch (_: IllegalArgumentException) {} }

    @Test fun abandonedComputationsHaveABoundedRetryCount() {
        var jobs = PrototypeJobs(store())
        val id = jobs.create(spec().put("backend", "local").put("upload_authorized", false))
        repeat(3) { attempt ->
            assertNotNull(jobs.claim(id, 100 + attempt * 30L, maxAttempts = 3))
            jobs = PrototypeJobs(store()) // Recovery after a dead process.
        }
        assertNull(jobs.claim(id, 190, maxAttempts = 3))
        assertEquals("failed", jobs.state(id).getString("state"))
        assertEquals("execution_attempt_limit", jobs.state(id).getString("last_error"))
    }

    @Test fun newProcessRecoversLocalWorkImmediatelyAndRetainsCheckpoint() {
        var jobs = PrototypeJobs(store())
        val id = jobs.create(spec().put("backend", "local").put("upload_authorized", false)
            .put("provider", "dart-voice-v1"))
        val old = jobs.claim(id, 100, leaseSeconds = 900)!!
        assertTrue(jobs.checkpointTranscript(old, 101, "Saved speech"))
        jobs = PrototypeJobs(store())
        jobs.recoverLocalClaims()
        val current = jobs.claim(id, 102, leaseSeconds = 900)!!
        assertEquals("Saved speech", jobs.state(id).getString("transcript"))
        assertEquals(2, current.attempts)
        assertFalse(jobs.checkpointTranscript(old, 103, "Saved speech"))
        assertTrue(jobs.checkpointTranscript(current, 103, "Saved speech"))
    }

    @Test fun transcriptCheckpointSurvivesReopenAndRejectsStaleWorker() {
        var jobs = PrototypeJobs(store())
        val input = spec().put("backend", "local").put("upload_authorized", false).put("provider", "dart-voice-v1")
        val id = jobs.create(input); val first = jobs.claim(id, 100)!!
        assertTrue(jobs.checkpointTranscript(first, 101, "Påminn mig i morgon"))
        jobs = PrototypeJobs(store())
        assertEquals("Påminn mig i morgon", jobs.state(id).getString("transcript"))
        val reclaimed = jobs.claim(id, 130)!!
        assertFalse(jobs.checkpointTranscript(first, 131, "stale"))
        rejected { jobs.checkpointTranscript(reclaimed, 131, "changed") }
        assertTrue(jobs.checkpointTranscript(reclaimed, 131, "Påminn mig i morgon"))
        assertTrue(jobs.cancel(id))
        assertFalse(jobs.checkpointTranscript(reclaimed, 132, "Påminn mig i morgon"))
    }

    @Test fun localResultRetainsExistingTimerAndCalendarFields() {
        val result = fixture("result-v1.json")
        result.put("actions", org.json.JSONArray().put(JSONObject().put("type", "timer").put("title", "Tea")
            .put("duration_seconds", 180).put("notes", "Test"))
            .put(JSONObject().put("type", "calendar_event").put("title", "Meeting")
                .put("start_time", "2026-10-05T09:00:00Z").put("location", "Home")))
        PrototypeJobs.validateResult(result)
        rejected { PrototypeJobs.validateResult(JSONObject(result.toString()).put("actions", org.json.JSONArray()
            .put(JSONObject().put("type", "timer").put("title", "Tea").put("duration_seconds", -1)))) }
    }

    @Test fun goldenRecoveryTraceSurvivesReopensAndDroppedAck() {
        val trace = fixture("recovery-v1.json"); val spec = spec(); val result = fixture("result-v1.json")
        var jobs = PrototypeJobs(store()); val id = jobs.create(spec)
        assertEquals(trace.getString("job_key"), id)
        val remoteId = "fixture-$id"
        var fault = false; var serverReady = false; val serverJobs = mutableSetOf<String>()
        val receiver = File(temporary.root, "fake-watch-receipt.json")
        for (index in 0 until trace.getJSONArray("steps").length()) {
            val step = trace.getJSONArray("steps").getJSONObject(index)
            when (step.getString("op")) {
                "fault" -> fault = true
                "reopen" -> jobs = PrototypeJobs(store())
                "reopen_server" -> { /* fixture remote identity/state is retained */ }
                "complete_server" -> serverReady = true
                "advance" -> {
                    val now = step.getLong("now")
                    val claim = jobs.claim(id, now)
                    if (claim != null) {
                        if (claim.remoteId == null) {
                            serverJobs.add(remoteId)
                            if (fault) { fault = false; jobs.defer(claim, now, 10, "transport_error") }
                            else { jobs.accepted(claim, now, remoteId); jobs.defer(claim, now, 10, "server_pending") }
                        } else if (serverReady) jobs.complete(claim, now, result, remoteId)
                        else jobs.defer(claim, now, 10, "server_pending")
                    }
                }
                "deliver_drop_ack", "deliver_ack" -> {
                    val delivery = jobs.pending(spec.getString("watch_id")).single()
                    val payload = JSONObject(delivery.getString("payload"))
                    assertEquals(trace.getString("result_id"), payload.getString("result_id"))
                    // Fake persisted receiver deduplicates identical result identity/payload.
                    if (receiver.exists()) assertEquals(receiver.readText(), delivery.getString("payload"))
                    else receiver.writeText(delivery.getString("payload"))
                    if (step.getString("op") == "deliver_ack")
                        assertTrue(jobs.acknowledge(spec.getString("watch_id"), payload.getString("result_id"), "accepted"))
                }
                else -> fail("Unknown golden step")
            }
            assertEquals("step $index", step.getString("state"), jobs.state(id).getString("state"))
            assertEquals("step $index", step.getInt("pending"), jobs.pending(spec.getString("watch_id")).size)
        }
        assertEquals(trace.getInt("expected_remote_jobs"), serverJobs.size)
        assertTrue(receiver.exists())
        assertEquals(trace.getInt("expected_watch_receipts"), if (receiver.exists()) 1 else 0)
    }

    @Test fun leaseReclaimRejectsOldCompletionAndDeadlineUsesCallbackTime() {
        val jobs = PrototypeJobs(store()); val id = jobs.create(spec()); val old = jobs.claim(id, 100)!!
        assertNull(jobs.claim(id, 129))
        val current = jobs.claim(id, 130)!!
        assertFalse(jobs.accepted(old, 130, "server"))
        assertFalse(jobs.defer(current, 160, 10, "late"))
        val next = jobs.claim(id, 160)!!
        assertTrue(jobs.accepted(next, 161, "server"))
        assertTrue(jobs.complete(next, 162, fixture("result-v1.json"), "server"))
        assertEquals(1, PrototypeJobs(store()).pending("fixture-watch").size)
    }

    @Test fun cancelAndNewGenerationFenceCallbacksAndPendingDelivery() {
        val jobs = PrototypeJobs(store()); val original = spec(); val id = jobs.create(original)
        val claim = jobs.claim(id, 100)!!; jobs.accepted(claim, 100, "server")
        assertTrue(jobs.cancel(id)); assertFalse(jobs.complete(claim, 101, fixture("result-v1.json"), "server"))
        val updated = JSONObject(original.toString()).put("generation", 2)
        val newer = jobs.create(updated); val next = jobs.claim(newer, 100)!!
        jobs.accepted(next, 100, "server2"); jobs.complete(next, 101, fixture("result-v1.json"), "server2")
        assertEquals(1, jobs.pending("fixture-watch").size)
        jobs.create(JSONObject(updated.toString()).put("generation", 3))
        assertTrue(jobs.pending("fixture-watch").isEmpty())
        rejected { jobs.create(updated) }
        rejected { jobs.create(JSONObject(updated.toString()).put("generation", 3).put("model", "changed")) }
    }

    @Test fun authorizationBackendAndMatchingApplicationAckAreRequired() {
        rejected { PrototypeJobs.key(spec().put("upload_authorized", false)) }
        rejected { PrototypeJobs.key(spec().put("generation", 1.5)) }
        rejected { PrototypeJobs.key(spec().put("extra", "unknown")) }
        val jobs = PrototypeJobs(store()); val local = spec().put("backend", "local").put("upload_authorized", false)
        val id = jobs.create(local); val claim = jobs.claim(id, 0)!!
        rejected { jobs.accepted(claim, 0, "remote") }
        assertTrue(jobs.complete(claim, 1, fixture("result-v1.json"), null))
        val result = JSONObject(jobs.pending("fixture-watch").single().getString("payload"))
        assertFalse(jobs.acknowledge("wrong-watch", result.getString("result_id"), "accepted"))
        assertFalse(jobs.acknowledge("fixture-watch", result.getString("result_id"), "written"))
        assertTrue(jobs.acknowledge("fixture-watch", result.getString("result_id"), "accepted"))
        assertTrue(jobs.acknowledge("fixture-watch", result.getString("result_id"), "accepted"))
    }

    @Test fun blockedCredentialsNeedExplicitRefreshAndPendingIsNotAFailure() {
        val jobs = PrototypeJobs(store()); val id = jobs.create(spec()); var claim = jobs.claim(id, 100)!!
        jobs.defer(claim, 100, 10, "http_401", blocked = true)
        assertNull(jobs.claim(id, 1000)); assertTrue(jobs.refreshCredentials(id))
        claim = jobs.claim(id, 1000)!!; jobs.accepted(claim, 1000, "server")
        jobs.defer(claim, 1000, 10, "server_pending")
        assertEquals(0, jobs.state(id).getInt("attempts"))
        assertNull(jobs.claim(id, 1009))
        claim = jobs.claim(id, 1010)!!; jobs.defer(claim, 1010, 0, "permanent", maxAttempts = 1)
        assertEquals("failed", jobs.state(id).getString("state")); assertNull(jobs.claim(id, 1020))
    }

    @Test fun committedResultCannotBeMutatedThroughCallerJsonAlias() {
        val journal = store(); val jobs = PrototypeJobs(journal); val id = jobs.create(spec())
        val claim = jobs.claim(id, 0)!!; jobs.accepted(claim, 0, "server")
        val result = fixture("result-v1.json"); jobs.complete(claim, 1, result, "server")
        result.put("summary", "mutated")
        assertEquals("Ladda klockan 🔋", jobs.state(id).getJSONObject("result").getString("summary"))
        assertEquals("Ladda klockan 🔋", PrototypeJobs(store()).state(id).getJSONObject("result").getString("summary"))
        assertEquals(1, jobs.pending("fixture-watch").size)
    }

    @Test fun unicodeCanonicalIdentityMatchesPythonWithoutNormalizingOrEscapingSlash() {
        val spec = spec().put("watch_id", "Åk / klocka 🔋\n\"")
        assertEquals("28642e71a8fe3761ca2b4bddc42c8ab71c4dfb6a966fb914f05f2398a43eacc7", PrototypeJobs.key(spec))
        rejected { PrototypeJobs.key(spec().put("watch_id", "\uD800")) }
    }

    @Test fun malformedJobCollectionsFailClosedWithoutResettingTheFile() {
        val journal = store(); journal.update("fault", mapOf("jobs" to "not an object"))
        val file = File(temporary.root, "jobs/state-v1.json"); val saved = file.readText()
        rejected { PrototypeJobs(store()).identities() }
        assertEquals(saved, file.readText())
    }
}
