package dev.zswatch.app.companion

import org.junit.Assert.*
import org.junit.Test
import java.nio.file.Files

class PrototypeWatchfaceTest {
    private fun image(): ByteArray = ByteArray(PrototypeWatchface.IMAGE_BYTES).also {
        byteArrayOf(0x19,0x12,0,0,0xf0.toByte(),0,0xf0.toByte(),0,0xe0.toByte(),1,0,0).copyInto(it)
    }
    private class Rig {
        var generation = 1L
        var time = 0L
        var canSend = true
        var throwObserve = false
        var copy: ByteArray? = null
        val timers = mutableListOf<Pair<Long, () -> Unit>>()
        val uploaded = mutableListOf<(Result<Unit>) -> Unit>()
        val progress = mutableListOf<(Int, Int) -> Unit>()
        val verified = mutableListOf<Pair<() -> Boolean, (Result<Unit>) -> Unit>>()
        val writes = mutableListOf<Pair<String, () -> Boolean>>()
        val states = mutableListOf<PrototypeWatchfaceState>()
        val releases = mutableListOf<Long>()
        val owner = PrototypeWatchface({ it == generation }, { time },
            { delay, action -> timers.add(time + delay to action) },
            { bytes, tick, done -> copy = bytes; progress.add(tick); uploaded.add(done) },
            { _, current, done -> verified.add(current to done) },
            { _, action, start -> writes.add(action to start); canSend },
            { if (throwObserve) error("Journal unavailable") else states.add(it) },
            { releases.add(it) })
        fun advance(ms: Long) {
            time += ms
            while (true) {
                val next = timers.filter { it.first <= time }.minByOrNull { it.first } ?: break
                timers.remove(next); next.second()
            }
        }
        fun finishUpload() { uploaded.last()(Result.success(Unit)); verified.last().second(Result.success(Unit)) }
    }
    @Test fun validatesImageAndOwnershipBeforeAnyWatchMutation() {
        val r = Rig()
        val bytes = image(); bytes[0] = 0
        for (invalid in listOf(byteArrayOf(), bytes, image().copyOf(PrototypeWatchface.IMAGE_BYTES - 1)))
            assertThrows(IllegalArgumentException::class.java) { r.owner.startUpload(1,invalid,"Test") }
        assertThrows(IllegalStateException::class.java) { r.owner.startUpload(0,image(),"Test") }
        assertThrows(IllegalArgumentException::class.java) { r.owner.startUpload(1,image(),"bad\nname") }
        assertTrue(r.states.isEmpty()); assertTrue(r.uploaded.isEmpty())
    }
    @Test fun nativePipelineCopiesInputAndAppliesOnlyAfterVerificationAndAcknowledgement() {
        val r = Rig(); val bytes = image(); val id = r.owner.startUpload(1, bytes, "Test"); bytes[12] = 7
        assertEquals(0.toByte(), r.copy!![12]); assertEquals(id, r.states.first().id)
        assertThrows(IllegalStateException::class.java) { r.owner.reset(1) }
        r.uploaded.single()(Result.success(Unit)); assertEquals("verifying",r.states.last().phase)
        assertTrue(r.writes.isEmpty()); r.verified.single().second(Result.success(Unit))
        assertEquals("apply", r.writes.single().first); assertTrue(r.owner.busy)
        r.owner.receive(1,"apply_result",true); assertTrue(r.owner.busy) // Not written yet.
        assertTrue(r.writes.single().second()); r.owner.receive(1,"apply_result",true)
        assertEquals("completed",r.states.last().phase); assertFalse(r.owner.busy)
        assertEquals(listOf(1L),r.releases); r.advance(300000); assertEquals(1,r.releases.size)
    }
    @Test fun corruptVerificationAndSdkErrorsNeverSendApply() {
        val r = Rig(); r.owner.startUpload(1,image(),"Test"); r.uploaded.single()(Result.success(Unit))
        r.verified.single().second(Result.failure(IllegalStateException("mismatch")))
        assertEquals("verify_failed",r.states.last().error); assertTrue(r.writes.isEmpty())
        val failed = Rig(); failed.owner.startUpload(1,image(),"Test")
        failed.uploaded.single()(Result.failure(IllegalStateException("SDK error")))
        assertEquals("upload_failed",failed.states.last().error); assertTrue(failed.verified.isEmpty())
    }
    @Test fun duplicateCallbacksCannotStartTwoVerificationsOrWrites() {
        val r = Rig(); r.owner.startUpload(1,image(),"Test")
        repeat(2) { r.uploaded.single()(Result.success(Unit)) }; assertEquals(1,r.verified.size)
        repeat(2) { r.verified.single().second(Result.success(Unit)) }; assertEquals(1,r.writes.size)
        r.writes.single().second(); repeat(2) { r.owner.receive(1,"apply_result",true) }
        assertEquals(1,r.releases.size)
    }
    @Test fun staleVerificationCannotStartSdkWorkForNewSameGenerationRequest() {
        val r = Rig(); r.owner.startUpload(1,image(),"First"); r.uploaded.single()(Result.success(Unit))
        val old = r.verified.single(); r.owner.close(); r.owner.startUpload(1,image(),"Second")
        assertFalse(old.first()); old.second(Result.success(Unit)); assertTrue(r.writes.isEmpty())
        assertEquals("Second",r.states.last().name); assertTrue(r.owner.busy)
    }
    @Test fun queuedWriteIsDroppedAfterDeadlineAndUnwrittenActionCanRetry() {
        val r = Rig(); r.owner.reset(1); val write = r.writes.single().second
        r.advance(10000); assertFalse(write()); assertFalse(r.states.last().applicationUncertain)
        r.owner.reset(1); assertTrue(r.owner.busy)
    }
    @Test fun missingResultQuarantinesOnlyItsActionUntilNewGeneration() {
        val r = Rig(); r.owner.reset(1); r.writes.single().second(); r.advance(10000)
        assertTrue(r.states.last().applicationUncertain)
        assertThrows(IllegalStateException::class.java) { r.owner.reset(1) }
        r.generation = 2; r.owner.reset(2)
        r.owner.receive(1,"reset_result",true); assertTrue(r.owner.busy)
        r.writes.last().second(); r.owner.receive(2,"reset_result",true)
        assertEquals("completed", r.states.last().phase)
    }
    @Test fun stopDuringUploadAndDuringWrittenApplyNeverReplay() {
        val r = Rig(); r.owner.startUpload(1,image(),"Test"); r.owner.close()
        r.uploaded.single()(Result.success(Unit)); assertTrue(r.verified.isEmpty()); assertFalse(r.states.last().applicationUncertain)
        val applying = Rig(); applying.owner.startUpload(1,image(),"Test"); applying.finishUpload()
        applying.writes.single().second(); applying.owner.close()
        assertTrue(applying.states.last().applicationUncertain); assertEquals("failed",applying.states.last().phase)
        applying.owner.receive(1,"apply_result",true); assertEquals(1,applying.releases.size)
    }
    @Test fun progressIsBoundedMonotonicAndJournalWritesAreThrottled() {
        val r = Rig(); r.owner.startUpload(1,image(),"Test")
        for (i in 1..100) r.progress.single()(i,PrototypeWatchface.IMAGE_BYTES)
        assertTrue(r.states.size < 5)
        r.time = 501; r.progress.single()(200,PrototypeWatchface.IMAGE_BYTES)
        assertEquals(200,r.states.last().current)
        r.progress.single()(100,PrototypeWatchface.IMAGE_BYTES)
        assertEquals("invalid_progress",r.states.last().error); assertEquals(1,r.releases.size)
    }
    @Test fun failedQueueAndWrongActionNeverProduceSuccess() {
        val r = Rig(); r.canSend = false; r.owner.reset(1)
        assertEquals("write_unavailable",r.states.last().error); assertFalse(r.states.last().applicationUncertain)
        val other = Rig(); other.owner.reset(1); other.writes.single().second()
        other.owner.receive(1,"apply_result",true); assertTrue(other.owner.busy)
        other.owner.receive(1,"reset_result",false); assertEquals("watch_rejected",other.states.last().error)
        // A definite negative watch acknowledgement is a failure, not an unknown result.
        assertFalse(other.states.last().applicationUncertain)
        other.owner.reset(1); assertTrue(other.owner.busy)
        other.writes.last().second(); other.owner.receive(1,"reset_result",true)
        assertEquals("completed",other.states.last().phase)
    }
    @Test fun generationLossAndDeadlineReleaseAcceptedWork() {
        val r = Rig(); r.owner.startUpload(1,image(),"Test"); r.generation = 2; r.advance(300000)
        assertEquals("connection_closed",r.states.last().error); assertFalse(r.owner.busy); assertEquals(listOf(1L),r.releases)
    }
    @Test fun journalFailureStillReleasesAndDoesNotUpload() {
        val r = Rig(); r.throwObserve = true
        assertThrows(IllegalStateException::class.java) { r.owner.startUpload(1,image(),"Test") }
        assertFalse(r.owner.busy); assertTrue(r.uploaded.isEmpty()); assertEquals(listOf(1L),r.releases)
    }
    @Test fun processRecoveryMarksUncertainPhaseWithoutReplayingOrChangingIdentity() {
        val dir = Files.createTempDirectory("watchface-test").toFile()
        try {
            val store = PrototypeStore(dir)
            store.update("test",mapOf("watchface_operation" to mapOf("id" to "a", "phase" to "applying",
                "generation" to 7, "address" to "AA:BB:CC:DD:EE:FF", "current" to PrototypeWatchface.IMAGE_BYTES)))
            PrototypeWatchface.markInterrupted(store)
            val recovered = PrototypeStore(dir).control()["watchface_operation"] as Map<*, *>
            assertEquals("a",recovered["id"]); assertEquals("failed",recovered["phase"])
            assertEquals("interrupted",recovered["error"]); assertEquals(true,recovered["application_uncertain"])
            assertFalse(recovered.containsKey("bytes"))
            val cursor = store.control()["event_cursor"]; PrototypeWatchface.markInterrupted(store)
            assertEquals(cursor,store.control()["event_cursor"])
        } finally { dir.deleteRecursively() }
    }
}
