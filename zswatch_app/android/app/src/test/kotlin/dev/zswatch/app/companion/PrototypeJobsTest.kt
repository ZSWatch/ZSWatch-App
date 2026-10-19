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

    @Test fun standaloneTranscriptionIsDurableTerminalPhoneDataWithNoWatchOutbox() {
        val jobs = PrototypeJobs(store())
        val id = jobs.create(spec().put("backend", "local").put("upload_authorized", false)
            .put("provider", "dart-voice-v1").put("pipeline_revision", "transcribe-v1"))
        val claim = jobs.claim(id, 100)!!
        assertTrue(jobs.checkpointTranscript(claim, 101, "A real transcript"))
        val result = JSONObject().put("version", 1).put("transcript", "A real transcript")
            .put("summary", "").put("category", "").put("actions", org.json.JSONArray())
        assertTrue(jobs.complete(claim, 102, result, null))
        val reopened = PrototypeJobs(store())
        assertEquals("transcribed", reopened.state(id).getString("state"))
        assertEquals("A real transcript", reopened.state(id).getJSONObject("result").getString("transcript"))
        assertTrue(reopened.pending("fixture-watch").isEmpty())
        assertNull(reopened.claim(id, 103))
        assertFalse(reopened.complete(claim, 103, result, null))
        rejected { PrototypeJobs.validateResult(result) }
        rejected { PrototypeJobs.validateResult(JSONObject(result.toString()).put("summary", "Unexpected analysis"), true) }
        rejected { PrototypeJobs.validateResult(JSONObject(result.toString()).put("actions", org.json.JSONArray()
            .put(JSONObject().put("type", "timer").put("title", "Tea"))), true) }
    }

    @Test fun explicitReanalysisCapturesTranscriptBeforeClaimAndFencesOldExecution() {
        val jobs = PrototypeJobs(store())
        val first = jobs.create(spec().put("backend", "local").put("upload_authorized", false).put("provider", "dart-voice-v1"))
        val old = jobs.claim(first, 100)!!
        jobs.checkpointTranscript(old, 101, "Original speech")
        val next = jobs.create(JSONObject(old.spec.toString()).put("generation", 2), "Edited speech")
        val reopened = PrototypeJobs(store())
        val current = reopened.claim(next, 102)!!
        assertEquals("Edited speech", reopened.state(next).getString("transcript"))
        assertFalse(reopened.complete(old, 103, fixture("result-v1.json"), null))
        assertTrue(reopened.complete(current, 103, fixture("result-v1.json"), null))
        assertEquals(1, reopened.pending("fixture-watch").size)
        assertEquals(next, reopened.summary().single { it["selected"] == true }["job_id"])
    }
    @Test fun finishedJobsDoNotCountAgainstActiveCapacityAndSupersededFailuresArePruned() {
        val jobs = PrototypeJobs(store())
        fun voice(recording: String, generation: Long = 1) = spec().put("backend", "local").put("upload_authorized", false)
            .put("provider", "dart-voice-v1").put("recording_id", recording).put("generation", generation)
        for (index in 0 until 100) {
            val id = jobs.create(voice("done-$index"))
            assertTrue(jobs.complete(jobs.claim(id, 100)!!, 101, fixture("result-v1.json"), null))
        }
        // 100 finished results never block new work.
        val failed = jobs.create(voice("retry"))
        assertTrue(jobs.defer(jobs.claim(failed, 100)!!, 101, 0, "dart_worker_failed", maxAttempts = 1))
        assertEquals("failed", jobs.state(failed).getString("state"))
        val retry = jobs.create(voice("retry", 2))
        assertEquals(101, jobs.identities().size)
        assertFalse(failed in jobs.identities())
        assertTrue(retry in jobs.identities())
        for (index in 1 until 100) jobs.create(voice("queued-$index"))
        rejected { jobs.create(voice("one-too-many")) }
    }

    @Test fun transientExecutionBlocksAreQueuedAgainInANewProcess() {
        val jobs = PrototypeJobs(store())
        val id = jobs.create(spec().put("backend", "local").put("upload_authorized", false).put("provider", "dart-voice-v1"))
        assertTrue(jobs.defer(jobs.claim(id, 100)!!, 101, 10, "execution_not_allowed", blocked = true))
        assertEquals("blocked", jobs.state(id).getString("state"))
        PrototypeJobs(store()).recoverLocalClaims()
        val recovered = PrototypeJobs(store())
        assertEquals("ready", recovered.state(id).getString("state"))
        val claim = recovered.claim(id, 102)!!
        // A transient deferral does not spend an attempt.
        assertTrue(recovered.defer(claim, 103, 60, "execution_interrupted", countAttempt = false))
        assertEquals("ready", recovered.state(id).getString("state"))
        assertEquals(0, recovered.state(id).getInt("attempts"))
    }

    private fun rejected(action: () -> Unit) { try { action(); fail("Expected rejection") } catch (_: IllegalArgumentException) {} }

    private fun finishedVoice(type: String = "reminder"): Pair<PrototypeJobs, String> {
        val jobs = PrototypeJobs(store())
        val id = jobs.create(spec().put("backend", "local").put("upload_authorized", false).put("provider", "dart-voice-v1"))
        val claim = jobs.claim(id, 100)!!
        val result = fixture("result-v1.json").put("actions", org.json.JSONArray().put(JSONObject()
            .put("type", type).put("title", "Owned draft")))
        assertTrue(jobs.complete(claim, 101, result, null))
        return jobs to id
    }

    @Test fun selectingSavedResultAfterFailedModelSurvivesReopenWithoutRepeatingWorkOrActions() {
        val (jobs, saved) = finishedVoice()
        val delivery = JSONObject(jobs.pending("fixture-watch").single().getString("payload"))
        jobs.acknowledge("fixture-watch", delivery.getString("result_id"), "accepted")
        jobs.beginAction(saved, 0, JSONObject().put("actionType", "reminder").put("title", "Owned"))
        jobs.finishAction(saved, 0, JSONObject().put("platformId", "42"))
        val original = jobs.state(saved).toString()
        val outboxBefore = store().control()["outbox"]
        val failed = jobs.create(JSONObject(jobs.state(saved).getJSONObject("spec").toString())
            .put("generation", 2).put("model", "missing-model"))
        assertEquals(failed, jobs.summary().single { it["selected"] == true }["job_id"])
        assertTrue(jobs.defer(jobs.claim(failed, 100)!!, 101, 0, "model_missing", maxAttempts = 1))
        jobs.select(saved)
        val reopened = PrototypeJobs(store())
        assertEquals(saved, reopened.summary().single { it["selected"] == true }["job_id"])
        assertEquals(original, reopened.state(saved).toString())
        assertEquals(outboxBefore, store().control()["outbox"])
        assertEquals("failed", reopened.state(failed).getString("state"))
        assertNull(reopened.claim(failed, 102))
        assertTrue(reopened.pending("fixture-watch").isEmpty())
        val another = reopened.create(JSONObject(reopened.state(saved).getJSONObject("spec").toString())
            .put("recording_id", "another-recording"))
        assertEquals(setOf(saved, another), reopened.summary().filter { it["selected"] == true }
            .map { it["job_id"] }.toSet())
    }

    @Test fun deliveryAckNeverConfirmsAnActionAndCalendarRecoveryUsesConfirmedInput() {
        val (jobs, id) = finishedVoice()
        val delivery = JSONObject(jobs.pending("fixture-watch").single().getString("payload"))
        assertTrue(jobs.acknowledge("fixture-watch", delivery.getString("result_id"), "accepted"))
        assertFalse(jobs.state(id).has("action_states"))
        val original = JSONObject().put("actionType", "reminder").put("title", "Edited title").put("scheduledAtMillis", 123L)
        jobs.beginAction(id, 0, original)
        original.put("title", "Mutated caller")
        val reopened = PrototypeJobs(store())
        val recovery = reopened.beginAction(id, 0, JSONObject().put("actionType", "reminder").put("title", "New title"))
        assertEquals("Edited title", recovery.getJSONObject("draft").getString("title"))
        reopened.finishAction(id, 0, JSONObject().put("platformId", "42").put("targetType", "calendar_reminder"))
        rejected { reopened.beginAction(id, 0, original) }
        rejected { reopened.dismissAction(id, 0) }
        assertEquals(2L, reopened.state(id).getLong("action_revision"))
        assertEquals("delivered", reopened.state(id).getString("state"))
    }

    @Test fun interruptedClockDispatchCannotBeRepeatedAndDismissalSurvivesReopen() {
        val (jobs, id) = finishedVoice("timer")
        val draft = JSONObject().put("actionType", "timer").put("title", "Tea").put("durationSeconds", 60)
        jobs.beginAction(id, 0, draft)
        val reopened = PrototypeJobs(store())
        rejected { reopened.beginAction(id, 0, draft) }
        // Only a known pre-effect failure can release the reservation.
        reopened.releaseAction(id, 0)
        reopened.dismissAction(id, 0)
        rejected { PrototypeJobs(store()).beginAction(id, 0, draft) }
        assertEquals("dismissed", PrototypeJobs(store()).state(id).getJSONObject("action_states").getJSONObject("0").getString("state"))
    }

    @Test fun undoRecoverySurvivesReprocessAndDoesNotAlterRecordingOrDelivery() {
        val (jobs, id) = finishedVoice()
        jobs.beginAction(id, 0, JSONObject().put("actionType", "reminder").put("title", "Owned"))
        jobs.finishAction(id, 0, JSONObject().put("platformId", "42").put("targetType", "calendar_reminder"))
        val original = jobs.state(id).getJSONObject("result").toString()
        // Reprocessing cancels an older undelivered job, but its created item remains undoable.
        jobs.create(JSONObject(jobs.state(id).getJSONObject("spec").toString()).put("generation", 2))
        assertEquals("42", jobs.beginUndoAction(id, 0).getJSONObject("response").getString("platformId"))
        val reopened = PrototypeJobs(store())
        assertEquals("undoing", reopened.beginUndoAction(id, 0).getString("state"))
        reopened.finishUndoAction(id, 0)
        assertEquals(original, reopened.state(id).getJSONObject("result").toString())
        assertEquals("cancelled", reopened.state(id).getString("state"))
        rejected { reopened.beginAction(id, 0, JSONObject().put("actionType", "reminder")) }
    }

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

    @Test fun stoppedExecutionReleasesLeaseAndKeepsCheckpointForExplicitRestart() {
        val jobs = PrototypeJobs(store())
        val id = jobs.create(spec().put("backend", "local").put("upload_authorized", false)
            .put("provider", "dart-voice-v1"))
        val interrupted = jobs.claim(id, 100, leaseSeconds = 900)!!
        assertTrue(jobs.checkpointTranscript(interrupted, 101, "Saved speech"))
        assertTrue(jobs.defer(interrupted, 102, 0, "execution_interrupted"))
        assertTrue(jobs.state(id).isNull("lease_until"))
        assertFalse(jobs.complete(interrupted, 103, fixture("result-v1.json"), null))
        val resumed = jobs.claim(id, 103, leaseSeconds = 900)!!
        assertEquals(2, jobs.state(id).getInt("attempts"))
        assertEquals("Saved speech", jobs.state(id).getString("transcript"))
        assertTrue(resumed.fence > interrupted.fence)
        assertFalse(jobs.checkpointTranscript(interrupted, 104, "Late callback"))
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
