package dev.zswatch.app.companion

import org.junit.Assert.*
import org.junit.Test
import java.nio.file.Files

class PrototypeForgetTest {
    private class Link : PrototypeTransport {
        override fun connect(address: String, generation: Long) = Unit
        override fun close() = Unit
    }

    @Test fun finalizeRequiresExactAddressStoppedOwnerAndStoppedPhase() {
        val address = "AA:BB:CC:DD:EE:FF"
        val state = mapOf<String, Any?>(
            "address" to address, "desired_running" to false, "phase" to "stopped",
        )
        assertTrue(PrototypeForget.canFinalize(state, address.lowercase(), false))
        assertFalse(PrototypeForget.canFinalize(state, address, true))
        assertFalse(PrototypeForget.canFinalize(state + ("desired_running" to true), address, false))
        assertFalse(PrototypeForget.canFinalize(state + ("phase" to "connecting"), address, false))
        assertFalse(PrototypeForget.canFinalize(state, "11:22:33:44:55:66", false))
        assertFalse(PrototypeForget.canFinalize(state, "watch", false))
    }

    @Test fun stopFencesDelayedPresenceBeforeForget() {
        val directory = Files.createTempDirectory("forget-fence").toFile()
        try {
            val store = PrototypeStore(directory)
            val owner = PrototypeRuntime(store, Link())
            val address = "AA:BB:CC:DD:EE:FF"
            owner.start(address)
            val staleGeneration = owner.generation
            owner.stop()
            assertFalse(owner.restoreForPresence(address, staleGeneration))
            assertTrue(PrototypeForget.canFinalize(store.control(), address, owner.active))
        } finally { directory.deleteRecursively() }
    }

    @Test fun selectedForgetStopsBeforeOsCallsAndSurvivesJournalReopenWithoutRestoration() {
        val directory = Files.createTempDirectory("forget-selected").toFile()
        try {
            val address = "AA:BB:CC:DD:EE:FF"
            val store = PrototypeStore(directory)
            val owner = PrototypeRuntime(store, Link())
            owner.start(address)
            val token = owner.generation
            owner.phase(token, "ready")
            store.putRecord("original", mapOf("state" to "downloaded"))
            store.update("policy", mapOf("http_enabled" to false, "recording_sync_enabled" to false))
            val calls = mutableListOf<String>()
            val receipt = PrototypeForget(store, owner, {
                assertFalse(owner.active)
                assertEquals(false, store.control()["desired_running"])
                calls.add("stop_observing:$it")
            }, {
                assertFalse(owner.owns(token))
                calls.add("disassociate:$it")
                true
            }).forget(address.lowercase())
            assertEquals(listOf("stop_observing:$address", "disassociate:$address"), calls)
            assertEquals(address, receipt["address"])
            assertEquals(token + 1, receipt["generation"])
            val reopened = PrototypeStore(directory)
            assertEquals("", reopened.control()["address"])
            assertNull(reopened.control()["last_ready"])
            assertNull(reopened.control()["watch_info"])
            assertEquals(token + 1, ((reopened.control()["forgotten_watches"] as Map<*, *>)[address] as Number).toLong())
            assertEquals("downloaded", reopened.record("original")!!["state"])
            assertEquals(false, reopened.control()["http_enabled"])
            assertEquals(false, reopened.control()["recording_sync_enabled"])
            val restored = PrototypeRuntime(reopened, Link())
            assertFalse(restored.restore())
            assertFalse(restored.restoreForPresence(address, token))
            assertFalse(restored.restoreForSystem(address, token))
            assertFalse(owner.phase(token, "ready"))
            // A new, explicit user selection remains possible, with a newer Ready generation.
            assertTrue(restored.startDiscovered(address, restored.generation))
            assertTrue(restored.generation > (receipt["generation"] as Long))
        } finally { directory.deleteRecursively() }
    }

    @Test fun forgettingAnotherSavedWatchDoesNotInterruptActiveOwner() {
        val directory = Files.createTempDirectory("forget-other").toFile()
        try {
            val active = "AA:BB:CC:DD:EE:FF"
            val other = "11:22:33:44:55:66"
            val store = PrototypeStore(directory)
            val owner = PrototypeRuntime(store, Link())
            owner.start(active)
            owner.phase(owner.generation, "ready")
            val before = store.control()
            val receipt = PrototypeForget(store, owner, { assertEquals(other, it) }, { it == other }).forget(other)
            assertTrue(owner.active)
            for (key in listOf("address", "desired_running", "phase", "generation", "last_ready"))
                assertEquals(before[key], store.control()[key])
            assertEquals(other, receipt["address"])
        } finally { directory.deleteRecursively() }
    }

    @Test fun absentOwnerIsStoppedDurablyAndOsFailureDoesNotPublishSuccess() {
        val directory = Files.createTempDirectory("forget-retry").toFile()
        try {
            val address = "AA:BB:CC:DD:EE:FF"
            val store = PrototypeStore(directory)
            val original = PrototypeRuntime(store, Link())
            original.start(address)
            original.phase(original.generation, "ready")
            original.destroy()
            val ready = store.control()["last_ready"]
            var removed = false
            val forget = PrototypeForget(store, null, {
                assertEquals(false, store.control()["desired_running"])
            }, { removed })
            try { forget.forget(address); fail("Expected association failure") }
            catch (_: IllegalStateException) { }
            assertEquals(false, store.control()["desired_running"])
            assertEquals(address, store.control()["address"])
            assertEquals(ready, store.control()["last_ready"])
            assertNull(store.control()["forgotten_watches"])
            removed = true
            forget.forget(address)
            forget.forget(address) // Retry after Flutter deletion failed, even after address was cleared.
            assertEquals("", store.control()["address"])
            assertNotNull(store.control()["forgotten_watches"])
        } finally { directory.deleteRecursively() }
    }

    @Test fun forgettingOldWatchFencesPendingPickerAndInvalidAddressDoesNothing() {
        val directory = Files.createTempDirectory("forget-picker").toFile()
        try {
            val store = PrototypeStore(directory)
            val owner = PrototypeRuntime(store, Link())
            val token = owner.generation
            val forget = PrototypeForget(store, owner, {}, { true })
            val before = store.control()
            try { forget.forget("old-ios-id"); fail("Expected invalid address") }
            catch (_: IllegalStateException) { }
            assertEquals(before, store.control())
            forget.forget("AA:BB:CC:DD:EE:FF")
            assertFalse(owner.startDiscovered("AA:BB:CC:DD:EE:FF", token))
        } finally { directory.deleteRecursively() }
    }
}
