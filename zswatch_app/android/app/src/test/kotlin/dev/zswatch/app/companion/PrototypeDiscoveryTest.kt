package dev.zswatch.app.companion

import org.junit.Assert.*
import org.junit.Test
import java.nio.file.Files

class PrototypeDiscoveryTest {
    private class Link : PrototypeTransport {
        val starts = mutableListOf<Pair<String, Long>>()
        override fun connect(address: String, generation: Long) { starts.add(address to generation) }
        override fun close() {}
    }
    private val first = "AA:BB:CC:DD:EE:FF"
    private val second = "11:22:33:44:55:66"

    @Test fun explicitAndroidCancellationReasonsDoNotHideDiscoveryFailures() {
        for (reason in listOf("canceled", "user_rejected")) assertEquals("CANCELLED", PrototypeDiscovery.failureCode(reason))
        for (reason in listOf(null, "discovery_timeout", "internal_error", "unknown"))
            assertEquals("ASSOCIATION_FAILED", PrototypeDiscovery.failureCode(reason))
    }

    @Test fun legacyGenericFailureAwaitsOnlyAnAlreadyOpenedPickerResult() {
        assertTrue(PrototypeDiscovery.awaitPickerResult(31, true, "ASSOCIATION_FAILED"))
        assertTrue(PrototypeDiscovery.awaitPickerResult(32, true, "ASSOCIATION_FAILED"))
        assertFalse(PrototypeDiscovery.awaitPickerResult(31, false, "ASSOCIATION_FAILED"))
        assertFalse(PrototypeDiscovery.awaitPickerResult(33, true, "ASSOCIATION_FAILED"))
        assertFalse(PrototypeDiscovery.awaitPickerResult(31, true, "CANCELLED"))
    }

    @Test fun selectionCannotClaimAStoppedIntentWithoutExactGenerationOrOverrideRunningOwner() {
        val state = mapOf<String, Any?>("generation" to 7L, "desired_running" to false)
        assertTrue(PrototypeDiscovery.canSelect(state, false, 7))
        assertFalse(PrototypeDiscovery.canSelect(state, true, 7))
        assertFalse(PrototypeDiscovery.canSelect(state, false, 6))
        for (intent in listOf(true, null, "false"))
            assertFalse(PrototypeDiscovery.canSelect(state + ("desired_running" to intent), false, 7))
        for (generation in listOf("7", 7.0, null))
            assertFalse(PrototypeDiscovery.canSelect(state + ("generation" to generation), false, 7))
    }

    @Test fun pickerHandoffStartsOneOwnerWithoutFabricatingReadyAndPreservesPoliciesAndReceipts() {
        val directory = Files.createTempDirectory("picker-handoff").toFile()
        try {
            val link = Link(); val store = PrototypeStore(directory); val owner = PrototypeRuntime(store, link)
            store.update("policy", mapOf("http_enabled" to false, "recording_sync_enabled" to false))
            store.putRecord("original", mapOf("state" to "downloaded"))
            val token = owner.generation
            assertTrue(owner.startDiscovered(first, token))
            assertEquals(listOf(first to token + 1), link.starts)
            assertEquals("connecting", store.control()["phase"])
            assertNull(store.control()["last_ready"])
            assertFalse(owner.startDiscovered(first, token))
            assertFalse(owner.startDiscovered(second, owner.generation))
            assertEquals(1, link.starts.size)
            assertEquals(false, store.control()["http_enabled"])
            assertEquals(false, store.control()["recording_sync_enabled"])
            assertEquals("downloaded", store.record("original")!!["state"])
        } finally { directory.deleteRecursively() }
    }

    @Test fun aNewStopBetweenPickerResultAndServiceStartWins() {
        val directory = Files.createTempDirectory("picker-stop").toFile()
        try {
            val link = Link(); val store = PrototypeStore(directory); val owner = PrototypeRuntime(store, link)
            val token = owner.generation
            assertTrue(PrototypeDiscovery.canSelect(store.control(), false, token))
            owner.stop()
            assertFalse(owner.startDiscovered(first, token))
            assertEquals(0, link.starts.size)
            assertEquals(false, store.control()["desired_running"])
            // A subsequent explicit picker can start from the new stopped generation.
            assertTrue(owner.startDiscovered(second, owner.generation))
            assertEquals(second, link.starts.single().first)
        } finally { directory.deleteRecursively() }
    }

    @Test fun aNewConnectionOrFrameworkDeathCannotMakeAnOldSelectionAuthoritative() {
        val directory = Files.createTempDirectory("picker-owner").toFile()
        try {
            val link = Link(); val store = PrototypeStore(directory); val owner = PrototypeRuntime(store, link)
            val token = owner.generation
            owner.start(first); owner.destroy()
            val restored = PrototypeRuntime(PrototypeStore(directory), link)
            assertFalse(restored.startDiscovered(second, token))
            assertFalse(restored.startDiscovered(second, restored.generation))
            assertTrue(restored.restore())
            assertEquals(listOf(first, first), link.starts.map { it.first })
        } finally { directory.deleteRecursively() }
    }
}
