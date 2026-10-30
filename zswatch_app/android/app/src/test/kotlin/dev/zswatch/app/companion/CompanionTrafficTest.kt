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

    @Test fun stalledUiCatchesUpBeyond64EventsWithoutDuplicatesOrAnUnboundedQueue() {
        val main = ArrayDeque<() -> Unit>()
        val received = mutableListOf<Long>()
        lateinit var delivery: CompanionTrafficDelivery
        val traffic = CompanionTraffic { delivery.changed() }
        delivery = CompanionTrafficDelivery(traffic) { batch, completed ->
            main.addLast { received.addAll(batch.map { it["sequence"] as Long }); completed() }
        }
        repeat(250) { traffic.publish("rx", "$it", 4, 1, 10) }
        assertEquals(1, main.size)
        main.removeFirst()() // Acknowledge the first batch while more traffic arrives.
        repeat(250) { traffic.publish("tx", "$it", 4, 1, 11) }
        assertEquals(1, main.size)
        while (main.isNotEmpty()) {
            assertEquals(1, main.size)
            main.removeFirst()()
        }
        assertEquals((1L..500L).toList(), received)
        delivery.changed()
        assertTrue(main.isEmpty())
    }

    @Test fun closingDeliveryFencesItsQueuedAcknowledgement() {
        val main = ArrayDeque<() -> Unit>()
        lateinit var delivery: CompanionTrafficDelivery
        val traffic = CompanionTraffic { delivery.changed() }
        delivery = CompanionTrafficDelivery(traffic) { _, completed -> main.addLast(completed) }
        repeat(100) { traffic.publish("rx", "$it", 4, 1, 10) }
        assertEquals(1, main.size)
        delivery.close()
        main.removeFirst()()
        assertTrue(main.isEmpty())
        // A new attachment starts with its own cursor and all retained traffic.
        var replayed = emptyList<Long>()
        delivery = CompanionTrafficDelivery(traffic) { batch, completed ->
            replayed = batch.map { it["sequence"] as Long }; completed()
        }
        delivery.changed()
        assertEquals((1L..100L).toList(), replayed)
    }

    @Test fun clearReturnsTheQueuedEventCutoffAndDoesNotReuseIds() {
        val traffic = CompanionTraffic {}
        traffic.publish("rx", "before clear", 12, 1, 10)
        val queued = traffic.replay().single()
        assertEquals(1L, traffic.clear())
        traffic.publish("rx", "after clear", 11, 1, 10)
        assertEquals(1L, queued["sequence"])
        assertEquals(2L, traffic.replay(1).single()["sequence"])
        assertEquals(2L, traffic.clear())
        assertEquals(2L, traffic.clear())
    }
}
