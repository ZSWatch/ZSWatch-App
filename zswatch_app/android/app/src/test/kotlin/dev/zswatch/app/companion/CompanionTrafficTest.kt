package dev.zswatch.app.companion

import org.junit.Assert.*
import org.junit.Test

class CompanionTrafficTest {
    @Test fun captureBeforeAttachmentPreservesOrderAndMetadataAcrossReattachment() {
        val delivered = mutableListOf<Map<String, Any?>>()
        var attached = false
        val traffic = CompanionTraffic { if (attached) delivered.add(it) }
        traffic.publish("rx", "räven 🦊", 11, 2, 10)
        assertTrue(delivered.isEmpty())
        attached = true
        delivered.addAll(traffic.replay())
        traffic.publish("tx", "command", 7, 1, 11)
        assertEquals(listOf("räven 🦊", "command"), delivered.map { it["data"] })
        assertEquals(11, delivered.first()["size_bytes"])
        assertEquals(2, delivered.first()["chunk_count"])
        assertEquals(10L, delivered.first()["generation"])
        assertTrue(delivered.first()["utc_ms"] is Long)
        attached = false
        traffic.publish("rx", "while detached", 14, 1, 12)
        assertEquals(2, delivered.size)
        assertEquals(listOf("räven 🦊", "command", "while detached"), traffic.replay().map { it["data"] })
    }

    @Test fun historyRotatesAtEntryAndByteLimitsWithoutDiscardingValidHistoryForOversizedTraffic() {
        val traffic = CompanionTraffic {}
        repeat(5002) { traffic.publish("rx", "$it", 4, 1, 10) }
        assertEquals(5000, traffic.replay().size)
        assertEquals("2", traffic.replay().first()["data"])
        traffic.clear()
        repeat(81) { traffic.publish("rx", "$it", 65536, 1, 10) }
        assertEquals(80, traffic.replay().size)
        assertEquals("1", traffic.replay().first()["data"])
        traffic.publish("rx", "oversized", 65537, 1, 10)
        traffic.publish("rx", "empty", 0, 1, 10)
        assertEquals(80, traffic.replay().size)
        traffic.clear()
        assertTrue(traffic.replay().isEmpty())
        traffic.publish("tx", "new", 3, 1, 11)
        assertEquals("new", traffic.replay().single()["data"])
    }
}
