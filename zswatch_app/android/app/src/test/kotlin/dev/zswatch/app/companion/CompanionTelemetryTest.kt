package dev.zswatch.app.companion

import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class CompanionTelemetryTest {
    @get:Rule val temporary = TemporaryFolder()
    private val watch = "AA:BB:CC:DD:EE:FF"
    private var now = 1700000000000L
    private class Sink : TelemetrySink {
        val health = mutableListOf<List<Any?>>()
        val battery = mutableListOf<List<Any?>>()
        val connection = mutableListOf<List<Any?>>()
        var previous: Map<String, Any?>? = null
        var failHealth = false
        override fun health(address: String, values: Map<String, Double>, timestamp: Long) {
            if (failHealth) throw IllegalStateException("disk unavailable")
            health.add(listOf(address, values, timestamp))
        }
        override fun battery(address: String, level: Int, charging: Boolean, timestamp: Long) {
            battery.add(listOf(address, level, charging, timestamp))
        }
        override fun connection(address: String, type: String, reason: String?, session: String?, timestamp: Long) {
            connection.add(listOf(address, type, reason, session, timestamp))
            if (type in listOf("connected", "disconnected")) previous = mapOf("watch_id" to address, "event_type" to type, "session_id" to session)
        }
        override fun lastConnection() = previous
    }
    private fun journal() = PrototypeStore(temporary.root).also {
        it.update("start", mapOf("address" to watch, "generation" to 7L,
            "desired_running" to true, "phase" to "ready"))
    }
    private fun receiver(store: PrototypeStore, sink: Sink) = CompanionTelemetry(sink, store) { now }
    private fun status(store: PrototypeStore, receiver: CompanionTelemetry, level: Int, charging: Boolean = false,
                       generation: Long = 7L, address: String = watch) {
        store.update("battery", mapOf("watch_info" to mapOf("address" to address,
            "battery_level" to level, "is_charging" to charging,
            "status_generation" to generation, "status_observed_ms" to now)))
        receiver.observe(store.control())
    }

    @Test fun activityIsOneBatchAndDurableBeforeFlutterNotification() {
        val store = journal(); val sink = Sink(); val receiver = receiver(store, sink)
        var notified = false
        store.onChanged = {
            assertEquals(1, sink.health.size)
            assertNotNull(PrototypeStore(temporary.root).control()["latest_health"])
            notified = true
        }
        assertTrue(receiver.activity(JSONObject("""{"t":"act","stp":1234,"hrm":72,"act":"WALKING"}"""), 7))
        assertEquals(listOf(watch, mapOf("steps" to 1234.0, "heartRate" to 72.0, "activity" to 7.0), now), sink.health.single())
        assertTrue(notified)
    }

    @Test fun staleDisconnectedAndStoppedFramesCannotWriteHistory() {
        val store = journal(); val sink = Sink(); val receiver = receiver(store, sink)
        val packet = JSONObject("""{"t":"act","stp":4,"hrm":70}""")
        assertFalse(receiver.activity(packet, 6))
        store.update("loss", mapOf("phase" to "connecting"))
        assertFalse(receiver.activity(packet, 7))
        store.update("stop", mapOf("phase" to "ready", "desired_running" to false))
        assertFalse(receiver.activity(packet, 7))
        assertTrue(sink.health.isEmpty())
        assertNull(store.control()["latest_health"])
    }

    @Test fun malformedFieldsAreRejectedAndValidFieldsRemainUsable() {
        val store = journal(); val sink = Sink(); val receiver = receiver(store, sink)
        assertFalse(receiver.activity(JSONObject("""{"t":"act","stp":-1,"hrm":500,"act":"garbage"}"""), 7))
        assertFalse(receiver.activity(JSONObject("""{"t":"act","stp":"123","hrm":72.5}"""), 7))
        assertTrue(receiver.activity(JSONObject("""{"t":"act","stp":0,"hrm":0,"act":"NOT_WORN"}"""), 7))
        assertEquals(mapOf("steps" to 0.0, "activity" to 1.0), sink.health.single()[1])
        assertFalse((store.control()["latest_health"] as Map<*, *>).containsKey("hrm"))
        sink.failHealth = true
        val before = store.control()["event_cursor"]
        try { receiver.activity(JSONObject("""{"t":"act","stp":20}"""), 7); fail("Expected IO failure") }
        catch (_: IllegalStateException) { }
        assertEquals(before, store.control()["event_cursor"])
    }

    @Test fun batteryThrottlesDuplicatesButRecordsChargingFivePercentAndFiveMinuteChanges() {
        val store = journal(); val sink = Sink(); val receiver = receiver(store, sink)
        status(store, receiver, 80)
        now += 1000; status(store, receiver, 79)
        assertEquals(1, sink.battery.size)
        now += 1000; status(store, receiver, 79, true)
        now += 1000; status(store, receiver, 74, true)
        assertEquals(3, sink.battery.size)
        now += 299999; status(store, receiver, 73, true)
        assertEquals(3, sink.battery.size)
        now++; status(store, receiver, 73, true)
        assertEquals(4, sink.battery.size)
        receiver.observe(store.control())
        assertEquals(4, sink.battery.size)
    }

    @Test fun staleBatteryFromPreviousGenerationOrWatchIsNeverPersisted() {
        val store = journal(); val sink = Sink(); val receiver = receiver(store, sink)
        status(store, receiver, 80, generation = 6)
        now++; status(store, receiver, 80, address = "11:22:33:44:55:66")
        assertTrue(sink.battery.isEmpty())
        now++; status(store, receiver, 80)
        assertEquals(1, sink.battery.size)
    }

    @Test fun stopClosesOneSessionAndReconnectionGetsANewSession() {
        val store = journal(); val sink = Sink(); val receiver = receiver(store, sink)
        receiver.observe(store.control()); receiver.observe(store.control())
        val first = sink.connection.single()[3]
        store.update("stop", mapOf("phase" to "stopped", "desired_running" to false))
        receiver.observe(store.control()); receiver.close()
        assertEquals(2, sink.connection.size)
        assertEquals(listOf(watch, "disconnected", "user_requested", first, now), sink.connection.last())
        store.update("retry", mapOf("phase" to "connecting", "desired_running" to true))
        receiver.observe(store.control())
        store.update("ready", mapOf("phase" to "ready"))
        receiver.observe(store.control())
        assertNotEquals(first, sink.connection.last()[3])
        assertEquals(listOf("connected", "disconnected", "reconnect_attempt", "connected"), sink.connection.map { it[1] })
    }

    @Test fun processRecoveryClosesPreviousSessionOnlyOnce() {
        val store = journal(); val sink = Sink().also {
            it.previous = mapOf("watch_id" to watch, "event_type" to "connected", "session_id" to "old")
        }
        val receiver = receiver(store, sink)
        receiver.observe(store.control()); receiver.observe(store.control())
        assertEquals(2, sink.connection.size)
        assertEquals(listOf(watch, "disconnected", "app_terminated", "old", now), sink.connection.first())
        receiver.close(); receiver.close()
        assertEquals(3, sink.connection.size)
    }

    @Test fun watchSwitchCannotInheritHealthOrBatteryIdentity() {
        val store = journal(); val sink = Sink(); val receiver = receiver(store, sink)
        status(store, receiver, 80)
        val other = "11:22:33:44:55:66"
        store.update("switch", mapOf("address" to other, "generation" to 8L))
        receiver.observe(store.control())
        now++; status(store, receiver, 80, generation = 8, address = other)
        assertEquals(listOf(watch, other), sink.battery.map { it[0] })
        assertFalse(receiver.activity(JSONObject("""{"t":"act","stp":9}"""), 7))
        assertTrue(receiver.activity(JSONObject("""{"t":"act","stp":10}"""), 8))
        assertEquals(other, sink.health.single()[0])
        assertEquals(listOf("connected", "disconnected", "connected"), sink.connection.map { it[1] })
    }
}
