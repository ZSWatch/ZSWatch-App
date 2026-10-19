package dev.zswatch.app.companion

import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test

class PrototypeMediaTest {
    private fun json(packet: String) = JSONObject(packet.removePrefix("GB(").removeSuffix(")"))
    @Test fun watchControlsRequireExactSupportedStrings() {
        for (action in listOf("play", "pause", "next", "previous", "volumeup", "volumedown"))
            assertEquals(action, PrototypeMedia.action(JSONObject().put("t", "music").put("n", action)))
        for (action in listOf("PLAY", "seek", "playPause", "intent", 1, true, JSONObject.NULL))
            assertNull(PrototypeMedia.action(JSONObject().put("t", "music").put("n", action)))
        assertNull(PrototypeMedia.action(JSONObject().put("t", "http").put("n", "play")))
    }

    @Test fun noSessionExplicitlyClearsWatchMetadataAndPlayback() {
        val packets = PrototypeMedia.packets(null)
        val info = json(packets[0]); val state = json(packets[1])
        assertEquals("musicinfo", info.getString("t"))
        for (field in listOf("artist", "album", "track")) assertEquals("", info.getString(field))
        assertEquals(0, info.getInt("dur")); assertEquals("stop", state.getString("state"))
        assertEquals(0, state.getInt("position"))
    }

    @Test fun freshStateUsesExistingWireFieldsAndBoundsNumbers() {
        val packets = PrototypeMedia.packets(mapOf("playback" to mapOf("state" to "play", "position" to 12),
            "metadata" to mapOf("artist" to "Fixture Artist", "album" to "Fixture Album", "track" to "Fixture Track", "duration" to 120)))
        assertEquals("Fixture Track", json(packets[0]).getString("track"))
        assertEquals(120, json(packets[0]).getInt("dur"))
        assertEquals("play", json(packets[1]).getString("state")); assertEquals(12, json(packets[1]).getInt("position"))
        val invalid = PrototypeMedia.packets(mapOf("playback" to mapOf("state" to "unknown", "position" to -9),
            "metadata" to mapOf("duration" to Long.MAX_VALUE)))
        assertEquals("stop", json(invalid[1]).getString("state")); assertEquals(0, json(invalid[1]).getInt("position"))
        assertEquals(Int.MAX_VALUE, json(invalid[0]).getInt("dur"))
    }

    @Test fun escapedUnicodeMetadataFitsWatchFieldsAndPreservesWholeCodePoints() {
        for (value in listOf("😀".repeat(500), "\"\\\n".repeat(300), "a\u0000b", "x\uD800y")) {
            val packets = PrototypeMedia.packets(mapOf("metadata" to mapOf("artist" to value, "album" to value, "track" to value)))
            val info = json(packets[0])
            assertTrue(packets[0].toByteArray(Charsets.UTF_8).size <= 1024)
            for (field in listOf("artist", "album", "track")) {
                val text = info.getString(field)
                assertTrue(JSONObject.quote(text).toByteArray(Charsets.UTF_8).size <= 98)
                assertFalse(text.contains('\u0000'))
                assertTrue(text.codePoints().noneMatch { it in 0xD800..0xDFFF })
            }
        }
    }

    @Test fun aNewReadyEpochEvenWithSameGenerationRejectsOldMainCallbacks() {
        val lease = PrototypeMediaLease(); val old = lease.open(7); val fresh = lease.open(7)
        assertFalse(lease.owns(old)); assertTrue(lease.owns(fresh)); assertSame(fresh, lease.get(7))
        assertNull(lease.get(6)); lease.close(); assertFalse(lease.owns(fresh)); assertNull(lease.get(7))
    }

    @Test fun stoppedAndReconnectedCallbacksCannotPublishOrControlCurrentSession() {
        val lease = PrototypeMediaLease(); val delivery = PrototypeMediaDelivery(lease); val old = lease.open(7)
        val queued = { delivery.publish(old, PrototypeMedia.packets(null)) { fail("stale publication"); true } }
        lease.close(); queued()
        lease.open(8); queued()
        assertFalse(lease.owns(old))
    }

    @Test fun queuedControlsExpireEvenWhenConnectionGenerationIsUnchanged() {
        val lease = PrototypeMediaLease(); val session = lease.open(7)
        assertTrue(lease.authorizesControl(session, 100, 100))
        assertTrue(lease.authorizesControl(session, 100, 2100))
        assertFalse(lease.authorizesControl(session, 100, 2101))
        assertFalse(lease.authorizesControl(session, 100, 99))
        lease.close(); assertFalse(lease.authorizesControl(session, 100, 100))
    }

    @Test fun queueBackpressureRetriesOnlyPacketsNotAdmittedAndCoalescesFreshValues() {
        val lease = PrototypeMediaLease(); val delivery = PrototypeMediaDelivery(lease); val session = lease.open(7)
        val packets = PrototypeMedia.packets(null); val attempted = mutableListOf<String>()
        delivery.publish(session, packets) { attempted.add(it); it == packets[0] }
        assertEquals(packets, attempted); attempted.clear()
        delivery.publish(session, packets) { attempted.add(it); true }
        assertEquals(listOf(packets[1]), attempted); attempted.clear()
        delivery.publish(session, packets) { attempted.add(it); true }
        assertTrue(attempted.isEmpty())
        val changed = PrototypeMedia.packets(mapOf("playback" to mapOf("state" to "pause")))
        delivery.publish(session, changed) { attempted.add(it); true }
        assertEquals(listOf(changed[1]), attempted)
    }

    @Test fun reconnectAlwaysPublishesFreshSnapshotWithoutDurableReplay() {
        val lease = PrototypeMediaLease(); val delivery = PrototypeMediaDelivery(lease); val packets = PrototypeMedia.packets(null)
        val sent = mutableListOf<String>(); delivery.publish(lease.open(7), packets) { sent.add(it); true }
        lease.close(); delivery.clear()
        delivery.publish(lease.open(8), packets) { sent.add(it); true }
        assertEquals(packets + packets, sent)
    }
}
