package dev.zswatch.app.companion

import org.junit.Assert.*
import org.junit.Test
import java.nio.file.Files

class PrototypeResourceUpdateTest {
    private class Rig {
        var active=true;var now=0L
        var uploaded:(()->Unit)?=null;var progress:((Int,Int)->Unit)?=null
        var current:(()->Boolean)?=null;var resourceDone:((Result<Unit>)->Unit)?=null
        val states=mutableListOf<PrototypeFirmwareState>();val launches=mutableListOf<PrototypeFirmwareState>()
        val resets=mutableListOf<PrototypeFirmwareState>();val reconnects=mutableListOf<PrototypeFirmwareState>()
        val checks=mutableListOf<(Result<Unit>)->Unit>();val checkedStates=mutableListOf<PrototypeFirmwareState>();val releases=mutableListOf<PrototypeFirmwareState>()
        val timers=mutableListOf<Pair<Long,()->Unit>>()
        val target=ResourceSdkContract.prepare(ResourceSdkContractTest.image(),"watchdk@1").target
        val owner=PrototypeFirmware({active},{now},{delay,action->timers.add(now+delay to action)},
            {launches.add(it)},{reconnects.add(it)},{state,_,done->checkedStates.add(state);checks.add(done)}, {}, {states.add(it)},{releases.add(it)},
            resources={_,stillCurrent,onProgress,onUploaded,done-> current=stillCurrent;progress=onProgress;uploaded=onUploaded;resourceDone=done},
            resetResources={resets.add(it)})
        fun start(combined:Boolean=false)=owner.start("AA:BB:CC:DD:EE:FF",7,
            if(combined)listOf(FirmwareTarget(2,76,"ab".repeat(32))) else emptyList(),target)
        fun verified(){uploaded!!();resourceDone!!(Result.success(Unit))}
        fun advance(ms:Long){now+=ms;val due=timers.filter{it.first<=now};timers.removeAll(due.toSet());due.forEach{it.second()}}
    }
    @Test fun combinedStageCannotStartFirmwareBeforeFullResourceVerification() {
        val r=Rig();val id=r.start(true)
        assertEquals("resource_uploading",r.states.last().phase);assertTrue(r.launches.isEmpty());assertTrue(r.resets.isEmpty())
        r.owner.sdkCompleted(id);r.owner.sdkPhase(id,"applying");assertEquals("resource_uploading",r.states.last().phase)
        r.progress!!(32,64);assertEquals(32,r.states.last().current)
        r.uploaded!!();assertEquals("resource_verifying",r.states.last().phase);assertTrue(r.launches.isEmpty())
        r.resourceDone!!(Result.success(Unit));assertEquals(1,r.launches.size);assertTrue(r.resets.isEmpty())
        assertTrue(r.launches.single().resourceVerified);assertEquals("validating",r.owner.state?.phase)
        r.resourceDone!!(Result.success(Unit));assertEquals(1,r.launches.size)
        r.owner.sdkCompleted(id);assertEquals(1,r.reconnects.size);assertTrue(r.owner.busy)
        r.owner.ready("AA:BB:CC:DD:EE:FF");r.checks.single()(Result.success(Unit))
        assertEquals("completed",r.states.last().phase);assertFalse(r.states.last().resultUnknown)
    }
    @Test fun sdkSkippingAlreadyActiveFirmwareStillResetsNewResourcesExactlyOnce() {
        val r=Rig();val id=r.start(true);r.verified()
        repeat(2){r.owner.sdkCompleted(id,false)}
        assertEquals(1,r.resets.size);assertTrue(r.reconnects.isEmpty());assertTrue(r.owner.busy)
        assertTrue(r.owner.state!!.resourceResetRequested)
        r.owner.sdkCompleted(id);assertEquals(1,r.reconnects.size)
        r.owner.ready("AA:BB:CC:DD:EE:FF");r.checks.single()(Result.success(Unit))
        assertEquals("completed",r.states.last().phase)
    }
    @Test fun resourceOnlyRequiresResetThenFreshPostflightRatherThanUploadReceipt() {
        val r=Rig();val id=r.start();r.verified()
        assertTrue(r.launches.isEmpty());assertEquals(1,r.resets.size);assertTrue(r.owner.busy)
        assertEquals("rebooting",r.states.last().phase);r.owner.ready("AA:BB:CC:DD:EE:FF");assertTrue(r.checks.isEmpty())
        r.owner.sdkCompleted(id);r.owner.ready("AA:BB:CC:DD:EE:FF");assertEquals(1,r.checks.size)
        assertTrue(r.checkedStates.single().resourceVerified)
        assertEquals(r.target,r.checkedStates.single().resource)
        r.checks.single()(Result.failure(IllegalStateException("Resource not mounted after reset")))
        assertEquals("boot_check_failed",r.states.last().error);assertTrue(r.states.last().resultUnknown)
    }
    @Test fun sizeOrHashFailureCannotAdvanceOrAutomaticallyRetryFirmware() {
        for(combined in listOf(false,true)){
            val r=Rig();r.start(combined);r.uploaded!!();r.resourceDone!!(Result.failure(IllegalStateException("Readback mismatch")))
            assertTrue(r.launches.isEmpty());assertTrue(r.resets.isEmpty());assertEquals("resource_transfer_failed",r.states.last().error)
            assertTrue(r.states.last().resultUnknown);assertFalse(r.owner.busy);assertEquals(1,r.releases.size)
        }
        val r=Rig();r.start(true);r.resourceDone!!(Result.success(Unit))
        assertEquals("resource_unverified",r.states.last().error);assertTrue(r.launches.isEmpty())
    }
    @Test fun nonAtomicResourceAndCombinedReplacementCannotBeUserCancelled() {
        val r=Rig();val id=r.start(true)
        assertThrows(IllegalStateException::class.java){r.owner.requestCancel(id)}
        r.uploaded!!();assertThrows(IllegalStateException::class.java){r.owner.requestCancel(id)}
        r.resourceDone!!(Result.success(Unit));r.owner.sdkPhase(id,"uploading")
        assertThrows(IllegalStateException::class.java){r.owner.requestCancel(id)}
    }
    @Test fun stopDuringResourcesFencesLateUploadAndCannotStartSecondStage() {
        val r=Rig();r.start(true);val stale=r.resourceDone!!;r.active=false;r.owner.close()
        assertFalse(r.current!!());stale(Result.success(Unit));r.uploaded!!()
        assertTrue(r.launches.isEmpty());assertEquals(1,r.releases.size);assertEquals("interrupted",r.states.last().error)
    }
    @Test fun resourceProgressAndBoundedPostflightDeadlineRemainFenced() {
        val r=Rig();val id=r.start();r.progress!!(1,63)
        assertEquals("invalid_progress",r.states.last().error);assertFalse(r.owner.busy)
        val boot=Rig();val bootId=boot.start();boot.verified();boot.owner.sdkCompleted(bootId)
        boot.advance(89999);assertTrue(boot.owner.busy)
        boot.advance(1);assertEquals("boot_check_timeout",boot.states.last().error);assertEquals(1,boot.releases.size)
        r.owner.sdkCompleted(id);assertTrue(r.reconnects.isEmpty())
    }
    @Test fun persistedPartialResourceStageRecoversAsUnknownWithoutPayloadOrReplay() {
        val dir=Files.createTempDirectory("resource-recovery").toFile()
        try {
            val store=PrototypeStore(dir);val metadata=mapOf("id" to "resource-id","phase" to "resource_verifying",
                "resource" to mapOf("bytes" to 64,"hash" to "ab".repeat(32)),"resource_verified" to false,"targets" to emptyList<Any>())
            store.update("accepted",mapOf("firmware_operation" to metadata));PrototypeFirmware.markInterrupted(store)
            val recovered=PrototypeStore(dir).control()["firmware_operation"] as Map<*,*>
            assertEquals("failed",recovered["phase"]);assertEquals("interrupted",recovered["error"]);assertEquals(true,recovered["result_unknown"])
            assertEquals(metadata["resource"],recovered["resource"]);assertFalse((recovered["resource"] as Map<*,*>).containsKey("data"))
        } finally {dir.deleteRecursively()}
    }
}
