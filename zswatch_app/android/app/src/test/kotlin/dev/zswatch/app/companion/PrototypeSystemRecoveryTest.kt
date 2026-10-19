package dev.zswatch.app.companion

import org.junit.Assert.*
import org.junit.Test
import java.nio.file.Files

class PrototypeSystemRecoveryTest {
    private val watch = "AA:BB:CC:DD:EE:FF"
    private val boot = "android.intent.action.BOOT_COMPLETED"
    private val replaced = "android.intent.action.MY_PACKAGE_REPLACED"

    @Test fun wakeupRequiresSupportedEventPermissionAndStrictSavedIntent() {
        val state = mapOf<String, Any?>("desired_running" to true, "address" to watch, "generation" to 7L)
        for (action in listOf(boot, replaced))
            assertEquals(PrototypeSystemRecovery.Request(watch, 7), PrototypeSystemRecovery.request(state, action, true))
        assertNull(PrototypeSystemRecovery.request(state, boot, false))
        for (action in listOf(null, "android.intent.action.LOCKED_BOOT_COMPLETED", "unknown"))
            assertNull(PrototypeSystemRecovery.request(state, action, true))
        for (patch in listOf(mapOf("desired_running" to false), mapOf("desired_running" to "true"),
            mapOf("address" to "invalid"), mapOf("generation" to -1L), mapOf("generation" to 7.0),
            mapOf("generation" to "7")))
            assertNull(PrototypeSystemRecovery.request(state + patch, boot, true))
    }

    private class Link : PrototypeTransport {
        val connections = mutableListOf<Pair<String, Long>>()
        override fun connect(address: String, generation: Long) { connections.add(address to generation) }
        override fun close() {}
    }

    @Test fun reopenRestoresOnceAndRetainsPolicyAndReceiptsWithoutUi() {
        val directory = Files.createTempDirectory("system-restore").toFile()
        try {
            val link = Link(); val initial = PrototypeStore(directory); val owner = PrototypeRuntime(initial, link)
            owner.start(watch); initial.update("policy", mapOf("http_enabled" to false, "recording_sync_enabled" to false))
            initial.putRecord("saved", mapOf("state" to "downloaded", "sha256" to "retained"))
            owner.destroy()
            val store = PrototypeStore(directory); val restored = PrototypeRuntime(store, link)
            val request = PrototypeSystemRecovery.request(store.control(), replaced, true)!!
            assertTrue(restored.restoreForSystem(request.address, request.generation))
            assertEquals(2, link.connections.size)
            assertFalse(restored.restoreForSystem(request.address, request.generation)) // Old queued wakeup.
            assertEquals(2, link.connections.size)
            val current = restored.generation
            assertTrue(restored.restoreForSystem(watch, current)) // Already owned, no second GATT.
            assertEquals(2, link.connections.size)
            assertEquals(false, store.control()["http_enabled"])
            assertEquals(false, store.control()["recording_sync_enabled"])
            assertEquals("retained", store.record("saved")!!["sha256"])
        } finally { directory.deleteRecursively() }
    }

    @Test fun delayedWakeupCannotUndoStopOrSwitchWatchAndNewEventRecoversSuspendedLink() {
        val directory = Files.createTempDirectory("system-fence").toFile()
        try {
            val link = Link(); val store = PrototypeStore(directory); val owner = PrototypeRuntime(store, link)
            owner.start(watch)
            val queued = owner.generation
            owner.stop()
            assertFalse(owner.restoreForSystem(watch, queued))
            assertFalse(owner.restoreForSystem(watch, owner.generation))
            assertEquals(1, link.connections.size)
            owner.start("11:22:33:44:55:66")
            assertFalse(owner.restoreForSystem(watch, queued))
            owner.suspendTransport("radio off")
            val request = PrototypeSystemRecovery.request(store.control(), boot, true)!!
            assertTrue(owner.restoreForSystem(request.address, request.generation))
            assertEquals(3, link.connections.size)
            assertEquals("11:22:33:44:55:66", link.connections.last().first)
        } finally { directory.deleteRecursively() }
    }
}
