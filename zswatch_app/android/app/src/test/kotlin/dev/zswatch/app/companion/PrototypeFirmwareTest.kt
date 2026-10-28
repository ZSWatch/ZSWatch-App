package dev.zswatch.app.companion

import org.junit.Assert.*
import org.junit.Test
import java.nio.file.Files

class PrototypeFirmwareTest {
    private fun targets() = listOf(FirmwareTarget(2, 2048, "ab".repeat(32)))
    private class Rig {
        var active = true
        var time = 0L
        var journalFails = false
        var launchFails = false
        var cancels = 0
        val timers = mutableListOf<Pair<Long, () -> Unit>>()
        val launches = mutableListOf<PrototypeFirmwareState>()
        val reconnects = mutableListOf<PrototypeFirmwareState>()
        val checks = mutableListOf<Pair<() -> Boolean, (Result<Unit>) -> Unit>>()
        val states = mutableListOf<PrototypeFirmwareState>()
        val releases = mutableListOf<PrototypeFirmwareState>()
        val owner = PrototypeFirmware({ active }, { time },
            { delay, action -> timers.add(time + delay to action) },
            { launches.add(it); if (launchFails) error("SDK start failed") },
            { reconnects.add(it) }, { _, current, done -> checks.add(current to done) },
            { cancels++ }, { if (journalFails) error("Journal unavailable") else states.add(it) },
            { releases.add(it) })
        fun start() = owner.start("AA:BB:CC:DD:EE:FF", 7, listOf(FirmwareTarget(2,2048,"ab".repeat(32))))
        fun advance(ms: Long) {
            time += ms
            while (true) {
                val due = timers.filter { it.first <= time }.minByOrNull { it.first } ?: break
                timers.remove(due); due.second()
            }
        }
    }
    @Test fun targetsValidateIndicesSizesAndHashesBeforeAnySdkWork() {
        val good = targets().single()
        for (bad in listOf(emptyList(), listOf(good,good), listOf(good.copy(index=3)), listOf(good.copy(bytes=0)),
            listOf(good.copy(bytes=PrototypeFirmware.MAX_IMAGE_BYTES+1)), listOf(good.copy(hash="bad")))) {
            assertThrows(IllegalArgumentException::class.java) { PrototypeFirmware.validate(bad) }
        }
        PrototypeFirmware.validate(listOf(good,good.copy(index=0),good.copy(index=1)))
        val r=Rig();r.active=false
        assertThrows(IllegalStateException::class.java) { r.start() }
        assertTrue(r.launches.isEmpty());assertTrue(r.states.isEmpty())
    }
    @Test fun bootConnectionRetryPreservesVerificationWithoutReplayingUpload() {
        val r=Rig();val id=r.start();r.owner.sdkCompleted(id)
        r.owner.connectionRetry();r.owner.connectionRetry()
        assertTrue(r.owner.busy);assertEquals("reconnecting",r.owner.state?.phase)
        assertEquals(1,r.launches.size);assertEquals(1,r.reconnects.size)
        r.owner.ready("AA:BB:CC:DD:EE:FF")
        r.checks.single().second(Result.success(Unit))
        assertEquals("completed",r.states.last().phase)
    }
    @Test fun verificationReconnectStartsAFreshCheckAndRejectsItsOldCallback() {
        val r=Rig();val id=r.start();r.owner.sdkCompleted(id)
        r.owner.ready("AA:BB:CC:DD:EE:FF")
        val stale=r.checks.single()
        r.active=false // Runtime fences verification before acquiring the new connection.
        r.owner.connectionRetry()
        assertTrue(r.owner.busy)
        assertEquals("reconnecting",r.owner.state?.phase)
        assertFalse(stale.first())
        r.active=true
        r.owner.ready("AA:BB:CC:DD:EE:FF")
        assertEquals(2,r.checks.size)
        assertFalse(stale.first())
        stale.second(Result.success(Unit))
        assertEquals("verifying",r.owner.state?.phase)
        stale.second(Result.failure(IllegalStateException("Old SMP preparation cancelled")))
        assertEquals("verifying",r.owner.state?.phase)
        assertTrue(r.checks.last().first())
        r.checks.last().second(Result.success(Unit))
        assertEquals("completed",r.states.last().phase)
        assertFalse(r.states.last().resultUnknown)
        assertEquals(1,r.launches.size)
        assertEquals(1,r.reconnects.size)
    }
    @Test fun verificationReconnectsKeepTheOriginalDeadlineAndStopWins() {
        val r=Rig();val id=r.start();r.owner.sdkCompleted(id)
        r.owner.ready("AA:BB:CC:DD:EE:FF")
        r.advance(89000);r.owner.connectionRetry()
        r.owner.ready("AA:BB:CC:DD:EE:FF")
        r.advance(1000)
        assertEquals("boot_check_timeout",r.states.last().error)
        assertEquals(1,r.releases.size)
        val stopped=Rig();val stoppedId=stopped.start();stopped.owner.sdkCompleted(stoppedId)
        stopped.owner.ready("AA:BB:CC:DD:EE:FF");stopped.owner.connectionRetry();stopped.owner.close()
        stopped.owner.ready("AA:BB:CC:DD:EE:FF")
        assertEquals("interrupted",stopped.states.last().error)
        assertEquals(1,stopped.checks.size)
        assertEquals(1,stopped.releases.size)
    }
    @Test fun bootConnectionRetriesKeepOriginalDeadlineAndStopStillWins() {
        val r=Rig();val id=r.start();r.owner.sdkCompleted(id)
        r.advance(89000);r.owner.connectionRetry();r.advance(1001)
        assertEquals("boot_check_timeout",r.states.last().error)
        val stopped=Rig();val stoppedId=stopped.start();stopped.owner.sdkCompleted(stoppedId)
        stopped.owner.connectionRetry();stopped.owner.close()
        assertEquals("interrupted",stopped.states.last().error);assertFalse(stopped.owner.busy)
        val uploading=Rig();uploading.start();uploading.owner.connectionRetry()
        assertEquals("interrupted",uploading.states.last().error)
    }
    @Test fun sdkCompletionAloneCannotCompleteWithoutFreshWatchVerification() {
        val r=Rig();val id=r.start()
        r.owner.sdkPhase(id,"uploading");r.owner.progress(id,1024,2048)
        r.owner.sdkPhase(id,"applying");r.owner.sdkPhase(id,"rebooting");r.owner.sdkCompleted(id)
        assertEquals("reconnecting",r.states.last().phase);assertTrue(r.owner.busy);assertEquals(1,r.reconnects.size)
        r.owner.ready("OTHER");assertTrue(r.checks.isEmpty())
        r.owner.ready("AA:BB:CC:DD:EE:FF");assertEquals("verifying",r.states.last().phase)
        assertTrue(r.checks.single().first());assertTrue(r.owner.busy)
        r.checks.single().second(Result.success(Unit))
        assertEquals("completed",r.states.last().phase);assertFalse(r.states.last().resultUnknown)
        assertFalse(r.owner.busy);assertEquals(1,r.releases.size)
    }
    @Test fun wrongActiveImageFailsAndNeverClaimsSuccessfulBoot() {
        val r=Rig();val id=r.start();r.owner.sdkCompleted(id);r.owner.ready("AA:BB:CC:DD:EE:FF")
        r.checks.single().second(Result.failure(IllegalStateException("Wrong active hash")))
        assertEquals("boot_check_failed",r.states.last().error);assertTrue(r.states.last().resultUnknown)
        assertEquals("failed",r.states.last().phase);assertFalse(r.owner.busy)
    }
    @Test fun unreportedImageStateIsExplicitlyUnknownRatherThanAnUploadFailureOrSuccess() {
        val r=Rig();val id=r.start();r.owner.sdkCompleted(id);r.owner.ready("AA:BB:CC:DD:EE:FF")
        r.checks.single().second(Result.failure(FirmwareVerificationUnavailable(listOf(1))))
        assertEquals("boot_check_unavailable",r.states.last().error);assertTrue(r.states.last().resultUnknown)
        assertFalse(r.owner.busy);assertEquals(1,r.releases.size)
    }
    @Test fun duplicateSdkCallbacksAndLateChecksCannotAcknowledgeAnotherOperation() {
        val r=Rig();val id=r.start();repeat(2){r.owner.sdkCompleted(id)}
        assertEquals(1,r.reconnects.size);repeat(2){r.owner.ready("AA:BB:CC:DD:EE:FF")};assertEquals(1,r.checks.size)
        val stale=r.checks.single();r.owner.close();val next=r.start()
        assertFalse(stale.first());stale.second(Result.success(Unit));r.owner.sdkPhase(id,"uploading")
        assertEquals(next,r.owner.state?.id);assertEquals("validating",r.owner.state?.phase)
        r.owner.sdkCompleted(next);assertEquals(2,r.reconnects.size)
    }
    @Test fun progressIsPerImageBoundedAndAllowsSdkImageCounterReset() {
        val r=Rig();val id=r.start();r.owner.sdkPhase(id,"uploading")
        for (count in 1..20) r.owner.progress(id,count,2048)
        assertTrue(r.states.size<8)
        r.owner.progress(id,2048,2048);r.owner.progress(id,0,1024)
        assertEquals(0,r.owner.state?.current);assertEquals(1024,r.states.last().total)
        r.owner.progress(id,1025,1024);assertEquals("invalid_progress",r.states.last().error)
        assertFalse(r.owner.busy);assertEquals(1,r.releases.size)
    }
    @Test fun cancelIsOnlyRequestedDuringUploadAndWaitsForSdkTerminalCallback() {
        val r=Rig();val id=r.start()
        assertThrows(IllegalStateException::class.java){r.owner.requestCancel(id)}
        r.owner.sdkPhase(id,"uploading");repeat(2){r.owner.requestCancel(id)}
        assertEquals(1,r.cancels);assertTrue(r.owner.busy);assertTrue(r.states.last().cancelRequested)
        r.owner.sdkCancelled(id);assertEquals("cancelled",r.states.last().phase);assertTrue(r.states.last().resultUnknown)
        assertFalse(r.owner.busy)
    }
    @Test fun resetConfirmationAndBootCheckCannotBeUserCancelled() {
        for (phase in listOf("applying","rebooting")) {
            val r=Rig();val id=r.start();r.owner.sdkPhase(id,phase)
            assertThrows(IllegalStateException::class.java){r.owner.requestCancel(id)}
            assertEquals(0,r.cancels)
        }
        val r=Rig();val id=r.start();r.owner.sdkCompleted(id)
        assertThrows(IllegalStateException::class.java){r.owner.requestCancel(id)}
        r.owner.ready("AA:BB:CC:DD:EE:FF")
        assertThrows(IllegalStateException::class.java){r.owner.requestCancel(id)}
    }
    @Test fun stopReleasesAndLateSdkCompletionDoesNotReconnect() {
        val r=Rig();val id=r.start();r.owner.sdkPhase(id,"rebooting");r.active=false;r.owner.close()
        r.owner.sdkCompleted(id);assertTrue(r.reconnects.isEmpty());assertEquals(1,r.releases.size)
        assertTrue(r.states.last().resultUnknown);assertEquals("interrupted",r.states.last().error)
    }
    @Test fun overallAndBootCheckDeadlinesReleaseExactlyOnce() {
        val r=Rig();val id=r.start();r.advance(20*60*1000L)
        assertEquals("deadline",r.states.last().error);r.owner.sdkCompleted(id);assertEquals(1,r.releases.size)
        val boot=Rig();val bootId=boot.start();boot.owner.sdkCompleted(bootId);boot.advance(90000)
        assertEquals("boot_check_timeout",boot.states.last().error);assertEquals(1,boot.releases.size)
        boot.advance(20*60*1000L);assertEquals(1,boot.releases.size)
    }
    @Test fun launchAndJournalFailuresStillReleaseTheExclusiveOwner() {
        val r=Rig();r.launchFails=true;r.start();assertEquals("start_failed",r.states.last().error);assertEquals(1,r.releases.size)
        val journal=Rig();journal.journalFails=true
        assertThrows(IllegalStateException::class.java){journal.start()}
        assertTrue(journal.launches.isEmpty());assertFalse(journal.owner.busy);assertEquals(1,journal.releases.size)
    }
    @Test fun processRecoveryKeepsIdentityAndRequiresExplicitActionWithoutFirmwarePayload() {
        val dir=Files.createTempDirectory("firmware-test").toFile()
        try {
            val store=PrototypeStore(dir)
            store.update("test",mapOf("firmware_operation" to mapOf("id" to "a", "phase" to "rebooting", "generation" to 7,
                "address" to "AA:BB:CC:DD:EE:FF", "targets" to listOf(mapOf("index" to 2,"hash" to "ab".repeat(32))))))
            PrototypeFirmware.markInterrupted(store)
            val result=PrototypeStore(dir).control()["firmware_operation"] as Map<*,*>
            assertEquals("a",result["id"]);assertEquals("failed",result["phase"]);assertEquals(true,result["result_unknown"])
            assertFalse(result.containsKey("bytes"));val cursor=store.control()["event_cursor"]
            PrototypeFirmware.markInterrupted(store);assertEquals(cursor,store.control()["event_cursor"])
        } finally {dir.deleteRecursively()}
    }
}
