package dev.zswatch.app.companion

import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test

class PrototypeGpsTest {
    private class Source : PrototypeGpsSource {
        val fixes = mutableListOf<(PrototypeGpsFix) -> Unit>()
        val errors = mutableListOf<(String) -> Unit>()
        var releases = 0
        var failSynchronously = false
        override fun start(fix: (PrototypeGpsFix) -> Unit, failed: (String) -> Unit): () -> Unit {
            fixes.add(fix); errors.add(failed)
            if (failSynchronously) failed("location_unavailable")
            return { releases++ }
        }
    }
    private class Rig(val denyForeground: Boolean = false) {
        var time = 100000L
        var enabled = true
        var blocked: String? = null
        var admitted = true
        val timers = mutableListOf<Pair<Long, () -> Unit>>()
        val source = Source()
        val foreground = mutableListOf<Boolean>()
        val observed = mutableListOf<Triple<Long, String, Boolean>>()
        val packets = mutableListOf<String>()
        val guards = mutableListOf<() -> Boolean>()
        val completed = mutableListOf<() -> Unit>()
        val controller = PrototypeGps({ enabled }, { blocked }, {
            if (it && denyForeground) throw SecurityException("Private platform details")
            foreground.add(it)
        }, source,
            { time }, { delay, action -> timers.add(time + delay to action) },
            { _, packet, guard, done ->
                if (admitted) { packets.add(packet); guards.add(guard); completed.add(done) }
                admitted
            }, { generation, state, requested -> observed.add(Triple(generation, state, requested)) })
        fun message(value: Any?) = JSONObject().put("t", "gps_power").put("status", value)
        fun fix(at: Long = time) = PrototypeGpsFix(0.0, 0.0, at, 1700000000000)
        fun advance(ms: Long) {
            time += ms
            while (true) {
                val due = timers.firstOrNull { it.first <= time } ?: break
                timers.remove(due); due.second()
            }
        }
    }

    @Test fun wireUsesExistingGpsProtocolAndRejectsInvalidStaleOrFutureFixes() {
        val fix = PrototypeGpsFix(12.0, -34.0, 5000, 1700000000000, 42.0, 2.0, 180.0, 9.0)
        val packet = fix.packet(6000)!!
        val json = JSONObject(packet.removePrefix("GB(").removeSuffix(")"))
        assertEquals("gps", json.getString("t"))
        assertTrue(json.getBoolean("externalSource"))
        assertEquals("phone", json.getString("gpsSource"))
        assertEquals(7.2, json.getDouble("speed"), 0.000001)
        assertEquals(9.0, json.getDouble("hdop"), 0.0)
        assertNull(fix.packet(4000))
        assertNull(fix.packet(35001))
        assertNull(fix.copy(latitude = Double.NaN).packet(6000))
        assertNull(fix.copy(longitude = 181.0).packet(6000))
        assertNull(fix.copy(utcMs = 0).packet(6000))
        val optional = JSONObject(fix.copy(speedMps = -1.0, altitude = Double.NaN).packet(6000)!!.removePrefix("GB(").removeSuffix(")"))
        assertFalse(optional.has("speed")); assertFalse(optional.has("alt"))
    }

    @Test fun exactBooleanReadyAndPermissionsAreRequiredWithoutAnOsPrompt() {
        val rig = Rig()
        rig.controller.receive(rig.message(true), 1)
        rig.controller.ready(1)
        rig.controller.receive(rig.message("true"), 1)
        rig.controller.receive(rig.message(1), 1)
        rig.controller.receive(rig.message(true), 0)
        rig.controller.receive(JSONObject().put("t", "GPS_POWER").put("status", true), 1)
        assertTrue(rig.source.fixes.isEmpty())
        rig.blocked = "permission_required"
        rig.controller.receive(rig.message(true), 1)
        assertTrue(rig.foreground.isEmpty())
        assertEquals("permission_required", rig.observed.last().second)
        rig.blocked = null; rig.enabled = false
        rig.controller.receive(rig.message(true), 1)
        assertTrue(rig.source.fixes.isEmpty())
        assertEquals("disabled", rig.observed.last().second)
    }

    @Test fun repeatedTrueDoesNotCreateAnotherAcquisitionAndFalseFencesQueuedWrites() {
        val rig = Rig(); rig.controller.ready(2)
        repeat(10) { rig.controller.receive(rig.message(true), 2) }
        assertEquals(1, rig.source.fixes.size)
        rig.source.fixes.single()(rig.fix())
        assertEquals(1, rig.packets.size)
        assertTrue(rig.guards.single()())
        rig.controller.receive(rig.message(false), 2)
        assertFalse(rig.guards.single()())
        rig.source.fixes.single()(rig.fix())
        rig.completed.single()()
        assertEquals(1, rig.packets.size)
        assertEquals(1, rig.source.releases)
        assertEquals(listOf(true, false), rig.foreground)
        assertEquals("idle", rig.observed.last().second)
    }

    @Test fun rapidStopStartAndReconnectRejectOldFixesEvenAtSameGeneration() {
        val rig = Rig(); rig.controller.ready(2)
        rig.controller.receive(rig.message(true), 2)
        val old = rig.source.fixes.single()
        rig.controller.receive(rig.message(false), 2)
        rig.controller.receive(rig.message(true), 2)
        old(rig.fix()); assertTrue(rig.packets.isEmpty())
        rig.controller.close(); rig.controller.ready(3)
        rig.source.fixes.last()(rig.fix())
        rig.controller.receive(rig.message(true), 2)
        assertTrue(rig.packets.isEmpty())
        assertEquals(2, rig.source.releases)
        rig.controller.receive(rig.message(true), 3)
        rig.source.fixes.last()(rig.fix())
        assertEquals(1, rig.packets.size)
    }

    @Test fun coalescesWhileWritingAndLimitsUpdatesToFiveSeconds() {
        val rig = Rig(); rig.controller.ready(1); rig.controller.receive(rig.message(true), 1)
        rig.source.fixes.single()(rig.fix())
        repeat(10) { rig.source.fixes.single()(rig.fix().copy(latitude = it.toDouble())) }
        assertEquals(1, rig.packets.size)
        rig.completed.first()()
        rig.advance(4999); assertEquals(1, rig.packets.size)
        rig.advance(1); assertEquals(2, rig.packets.size)
        assertTrue(rig.packets.last().contains("\"lat\":9"))
    }

    @Test fun queueAdmissionFailureRetriesButAStaleFixIsNeverReplayed() {
        val rig = Rig(); rig.controller.ready(1); rig.controller.receive(rig.message(true), 1)
        rig.admitted = false
        rig.source.fixes.single()(rig.fix())
        assertTrue(rig.packets.isEmpty())
        rig.admitted = true; rig.advance(500)
        assertEquals(1, rig.packets.size)
        rig.advance(30001)
        assertFalse(rig.guards.single()())
        assertEquals("location_unavailable", rig.observed.last().second)
        assertEquals(1, rig.source.releases)
    }

    @Test fun failedAcquisitionTimesOutReleasesAndCanBeRetriedByWatch() {
        val rig = Rig(); rig.controller.ready(1); rig.controller.receive(rig.message(true), 1)
        rig.advance(10000)
        assertEquals("location_unavailable", rig.observed.last().second)
        assertEquals(1, rig.source.releases)
        rig.controller.receive(rig.message(true), 1)
        assertEquals(2, rig.source.fixes.size)
        rig.source.errors.last()("services_disabled")
        assertEquals(2, rig.source.releases)
    }

    @Test fun disabledPolicyAndRevokedPermissionStopAcquisitionWithoutBleStateChanges() {
        val rig = Rig(); rig.controller.ready(1); rig.controller.receive(rig.message(true), 1)
        rig.enabled = false; rig.controller.configurationChanged()
        assertEquals("disabled", rig.observed.last().second)
        assertEquals(1, rig.source.releases)
        rig.enabled = true; rig.controller.receive(rig.message(true), 1)
        rig.blocked = "permission_required"
        rig.source.fixes.last()(rig.fix())
        assertEquals("permission_required", rig.observed.last().second)
        assertEquals(2, rig.source.releases)
        assertTrue(rig.packets.isEmpty())
    }

    @Test fun foregroundRejectionDoesNotRegisterLocationOrEscapeTheWatchCallback() {
        val rig = Rig(denyForeground = true)
        rig.controller.ready(1); rig.controller.receive(rig.message(true), 1)
        assertTrue(rig.source.fixes.isEmpty())
        assertEquals("permission_required", rig.observed.last().second)
        assertFalse(rig.observed.last().third)
        assertTrue(rig.packets.isEmpty())
    }

    @Test fun synchronousSourceFailureReleasesRegistrationAndLateFixCannotSend() {
        val rig = Rig(); rig.source.failSynchronously = true
        rig.controller.ready(1); rig.controller.receive(rig.message(true), 1)
        assertEquals(1, rig.source.releases)
        assertEquals(listOf(true, false), rig.foreground)
        assertEquals("location_unavailable", rig.observed.last().second)
        rig.source.fixes.single()(rig.fix())
        rig.advance(10000)
        assertTrue(rig.packets.isEmpty())
        assertEquals(1, rig.source.releases)
    }
    @Test fun weatherCanUseRecentCachedFixWithoutRelaxingLiveGps() {
        val rig = Rig(); rig.time = 1000000L; rig.controller.ready(1)
        val cached = rig.fix().copy(elapsedMs = rig.time - 600000, accuracy = 5000.0)
        rig.controller.receive(rig.message(true), 1)
        rig.source.fixes.last()(cached)
        assertTrue(rig.packets.isEmpty())
        rig.controller.receive(rig.message(false), 1)
        rig.controller.receive(rig.message(true).put("purpose", "weather"), 1)
        rig.source.fixes.last()(cached)
        assertEquals(1, rig.packets.size)
        assertTrue(rig.guards.last()())
        assertNull(cached.copy(accuracy = 50001.0).packet(rig.time, weather = true))
        rig.advance(1200001)
        assertFalse(rig.guards.last()())
        assertNull(cached.packet(rig.time, weather = true))
    }

    @Test fun unrecognizedPurposeStillRequiresFreshLocation() {
        val rig = Rig(); rig.time = 1000000L; rig.controller.ready(1)
        rig.controller.receive(rig.message(true).put("purpose", "navigation"), 1)
        rig.source.fixes.last()(rig.fix().copy(elapsedMs = rig.time - 600000))
        assertTrue(rig.packets.isEmpty())
    }

}
