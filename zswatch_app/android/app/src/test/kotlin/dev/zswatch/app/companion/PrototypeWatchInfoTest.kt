package dev.zswatch.app.companion

import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class PrototypeWatchInfoTest {
    @get:Rule val temporary = TemporaryFolder()
    private val address = "AA:BB:CC:DD:EE:FF"
    private fun store() = PrototypeStore(temporary.root).also {
        it.update("fixture", mapOf("desired_running" to true, "generation" to 1L, "address" to address))
    }
    private fun info(journal: PrototypeStore) = journal.control()["watch_info"] as Map<*, *>

    @Test fun coredumpSummaryPersistsAndVerifiedAbsenceClearsItForTheChosenWatch() {
        val journal = store(); val receiver = PrototypeWatchInfo(journal)
        val packet = PrototypeCoredumpSummary.packet("Stored coredumps: 1\n  Timestamp: owned time\n  File: owned.c\n  Line: 123\n")
        assertTrue(receiver.receive(packet, 1, 100))
        assertEquals("owned.c", (info(PrototypeStore(temporary.root))["coredump"] as Map<*, *>)["file"])
        assertFalse(receiver.receive(packet, 0, 101))
        assertFalse(receiver.receive(JSONObject("""{"t":"coredump","available":true,"file":"x","line":-1,"time":"x"}"""), 1, 102))
        assertTrue(receiver.receive(PrototypeCoredumpSummary.packet("No stored coredumps"), 1, 103))
        assertNull(info(journal)["coredump"])
    }

    @Test fun firmwareAndBatterySurviveProcessReopenAsCachedWatchData() {
        val journal = store(); val inbox = PrototypeWatchInfo(journal)
        assertTrue(inbox.receive(JSONObject("""{"t":"ver","fw":"1.2.3","hw":"WatchDK","sha":"abc","dbg":1}"""), 1, 100))
        assertTrue(inbox.receive(JSONObject("""{"t":"status","bat":0,"volt":3800,"chg":1}"""), 1, 110))
        val reopened = PrototypeStore(temporary.root)
        assertEquals("1.2.3", info(reopened)["firmware_version"])
        assertEquals(true, info(reopened)["firmware_debug"])
        assertEquals(0L, (info(reopened)["battery_level"] as Number).toLong())
        assertEquals(true, info(reopened)["is_charging"])
        assertEquals(100L, (info(reopened)["first_seen_ms"] as Number).toLong())
    }

    @Test fun newSessionRetainsCacheButOnlyItsOwnMessagesRefreshStatus() {
        val journal = store(); val inbox = PrototypeWatchInfo(journal)
        inbox.receive(JSONObject("""{"t":"status","bat":80,"chg":1}"""), 1, 100)
        journal.update("reconnect", mapOf("generation" to 2L))
        assertFalse(inbox.receive(JSONObject("""{"t":"status","bat":10}"""), 1, 110))
        assertEquals(1L, (info(journal)["status_generation"] as Number).toLong())
        assertTrue(inbox.receive(JSONObject("""{"t":"status","bat":79,"chg":0}"""), 2, 120))
        assertEquals(2L, (info(journal)["status_generation"] as Number).toLong())
        assertEquals(false, info(journal)["is_charging"])
    }

    @Test fun aDifferentWatchCannotInheritAnotherWatchesMetadata() {
        val journal = store(); val inbox = PrototypeWatchInfo(journal)
        inbox.receive(JSONObject("""{"t":"ver","fw":"old"}"""), 1, 100)
        journal.update("select", mapOf("address" to "11:22:33:44:55:66", "generation" to 2L))
        inbox.receive(JSONObject("""{"t":"status","bat":50}"""), 2, 120)
        assertEquals("11:22:33:44:55:66", info(journal)["address"])
        assertFalse(info(journal).containsKey("firmware_version"))
    }

    @Test fun malformedMessagesAndCallbacksAfterStopCannotOverwriteValidData() {
        val journal = store(); val inbox = PrototypeWatchInfo(journal)
        inbox.receive(JSONObject("""{"t":"status","bat":80}"""), 1, 100)
        for (invalid in listOf(
            """{"t":"status","bat":101,"chg":1}""",
            """{"t":"status","bat":50.5}""",
            """{"t":"status","bat":"50"}""",
            """{"t":"ver","fw":4}""",
            """{"t":"unknown","bat":5}""")) assertFalse(inbox.receive(JSONObject(invalid), 1, 110))
        journal.update("stop", mapOf("desired_running" to false))
        assertFalse(inbox.receive(JSONObject("""{"t":"status","bat":10}"""), 1, 120))
        assertEquals(80L, (info(journal)["battery_level"] as Number).toLong())
    }
}
