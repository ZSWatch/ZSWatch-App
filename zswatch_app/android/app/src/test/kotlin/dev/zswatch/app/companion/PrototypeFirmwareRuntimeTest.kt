package dev.zswatch.app.companion

import org.junit.Assert.*
import org.junit.Test
import java.nio.file.Files

class PrototypeFirmwareRuntimeTest {
    private class Link : PrototypeTransport {
        val connects=mutableListOf<Long>();var closes=0
        override fun connect(address:String,generation:Long){connects.add(generation)}
        override fun close(){closes++}
    }
    private fun rig(run:(PrototypeStore,Link,PrototypeRuntime,MutableList<String>)->Unit) {
        val dir=Files.createTempDirectory("firmware-runtime").toFile()
        try {
            val store=PrototypeStore(dir);val link=Link();val fences=mutableListOf<String>()
            val runtime=PrototypeRuntime(store,link){fences.add(it)}
            runtime.start("AA:BB:CC:DD:EE:FF");runtime.phase(runtime.generation,"ready")
            run(store,link,runtime,fences)
        }finally{dir.deleteRecursively()}
    }
    @Test fun acquireFencesOldNusAndSdkCallbacksWithoutChangingRunningIntent()=rig{store,link,runtime,fences->
        val old=runtime.generation;val exclusive=runtime.beginFirmware(old)
        assertEquals(old+1,exclusive);assertFalse(runtime.owns(old));assertTrue(runtime.owns(exclusive))
        assertEquals("upgrading",store.control()["phase"]);assertEquals(true,store.control()["desired_running"])
        assertEquals(1,link.closes);assertTrue(fences.isEmpty());assertEquals(listOf(old),link.connects)
        assertFalse(runtime.phase(old,"ready"));assertEquals("upgrading",store.control()["phase"])
    }
    @Test fun sdkReleaseReacquiresFreshNusOnceWithoutCancellingThePostflightOperation()=rig{store,link,runtime,fences->
        val exclusive=runtime.beginFirmware(runtime.generation);runtime.resumeAfterFirmware(exclusive)
        assertEquals(exclusive+1,runtime.generation);assertEquals("connecting",store.control()["phase"])
        assertEquals(2,link.connects.size);assertTrue(fences.isEmpty())
        runtime.resumeAfterFirmware(exclusive);assertEquals(2,link.connects.size)
    }
    @Test fun stopWinsOverSdkCompletionAndDestroysItsLease()=rig{store,link,runtime,fences->
        val exclusive=runtime.beginFirmware(runtime.generation);runtime.stop();runtime.resumeAfterFirmware(exclusive)
        assertEquals(listOf("stop"),fences);assertFalse(runtime.active);assertEquals(1,link.connects.size)
        assertEquals(false,store.control()["desired_running"]);assertEquals("stopped",store.control()["phase"])
    }
    @Test fun radioLossCancelsFirmwareAndOnlyOrdinaryCompanionMayRecover()=rig{store,link,runtime,fences->
        val exclusive=runtime.beginFirmware(runtime.generation);runtime.suspendTransport("Radio off")
        assertEquals(listOf("suspend"),fences);runtime.resumeAfterFirmware(exclusive);assertEquals(1,link.connects.size)
        runtime.recoverForSystem();assertEquals(2,link.connects.size);assertEquals("connecting",store.control()["phase"])
    }
    @Test fun frameworkDestructionPreservesIntentAndNextRestoreNeverReplaysFirmware()=rig{store,link,runtime,fences->
        runtime.beginFirmware(runtime.generation);runtime.destroy();assertEquals(listOf("destroy"),fences)
        assertEquals(true,store.control()["desired_running"]);assertFalse(runtime.active)
        runtime.restore();assertEquals("connecting",store.control()["phase"]);assertEquals(2,link.connects.size)
    }
    @Test fun staleAndNotReadyAcquireLeaveTheExistingConnectionUntouched()=rig{store,link,runtime,_->
        assertThrows(IllegalStateException::class.java){runtime.beginFirmware(runtime.generation-1)}
        runtime.phase(runtime.generation,"disconnected")
        assertThrows(IllegalStateException::class.java){runtime.beginFirmware(runtime.generation)}
        assertEquals(0,link.closes);assertEquals("disconnected",store.control()["phase"])
    }
    @Test fun failingFirmwareJournalCleanupStillClosesNusOnStop() {
        val dir=Files.createTempDirectory("firmware-runtime-failure").toFile()
        try {
            val store=PrototypeStore(dir);val link=Link();val runtime=PrototypeRuntime(store,link){error("Failed journal")}
            runtime.start("AA:BB:CC:DD:EE:FF")
            assertThrows(IllegalStateException::class.java){runtime.stop()}
            assertEquals(1,link.closes);assertFalse(runtime.active);assertEquals(false,store.control()["desired_running"])
        }finally{dir.deleteRecursively()}
    }
}
