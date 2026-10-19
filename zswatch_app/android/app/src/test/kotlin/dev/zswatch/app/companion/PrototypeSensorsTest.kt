package dev.zswatch.app.companion

import org.junit.Assert.*
import org.junit.Test

class PrototypeSensorsTest {
    @Test fun writesAreSerializedAndCompletionIsRequiredBeforeSamples() {
        val events = mutableListOf<Map<String, Any?>>()
        val sensors = PrototypeSensors(events::add)
        sensors.reset(12, setOf("accelerometer", "temperature"))
        var finished = 0
        sensors.request("accelerometer", true) { assertTrue(it.isSuccess); finished++ }
        sensors.request("temperature", true) { assertTrue(it.isSuccess); finished++ }
        val first = sensors.next()!!
        assertNull(sensors.next())
        sensors.receive("accelerometer", ByteArray(12))
        assertEquals(1, events.size)
        sensors.complete(first, true)
        sensors.complete(first, true) // Late duplicate cannot finish a new write.
        sensors.receive("accelerometer", ByteArray(12))
        assertEquals("sample", events.last()["kind"])
        sensors.receive("accelerometer", ByteArray(11))
        assertEquals(3, events.size)
        val second = sensors.next()!!
        assertEquals("temperature", second.name)
        sensors.complete(second, true)
        assertEquals(2, finished)
    }
    @Test fun detachDuringEnableQueuesDisableAndCancelsUnsubmittedWork() {
        val sensors = PrototypeSensors({})
        sensors.reset(1, setOf("fusion", "light"))
        sensors.request("fusion", true) {}
        var cancelled = false
        sensors.request("light", true) { cancelled = it.isFailure }
        val enabling = sensors.next()!!
        sensors.stopAll()
        assertTrue(cancelled)
        assertNull(sensors.next())
        sensors.complete(enabling, true)
        val disabling = sensors.next()!!
        assertEquals("fusion", disabling.name); assertFalse(disabling.enabled)
        sensors.complete(disabling, true)
        assertEquals(emptyList<String>(), sensors.state()["enabled"])
    }
    @Test fun reconnectFencesPendingAndDisabledMalformedUnavailableSamples() {
        val events = mutableListOf<Map<String, Any?>>()
        val sensors = PrototypeSensors(events::add)
        sensors.reset(1, setOf("light"))
        assertThrows(IllegalArgumentException::class.java) { sensors.request("invented", true) {} }
        var failed = false
        sensors.request("light", true) { failed = it.isFailure }
        val old = sensors.next()!!
        sensors.reset(2, setOf("temperature"))
        assertTrue(failed)
        sensors.complete(old, true)
        sensors.receive("light", ByteArray(4))
        assertEquals(2, events.size)
        assertEquals(2L, sensors.state()["generation"])
        assertEquals(emptyList<String>(), sensors.state()["enabled"])
    }
}
