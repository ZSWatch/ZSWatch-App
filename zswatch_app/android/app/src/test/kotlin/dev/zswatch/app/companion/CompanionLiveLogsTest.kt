package dev.zswatch.app.companion

import org.junit.Assert.*
import org.junit.Test

class CompanionLiveLogsTest {
    @Test fun everyByteBoundaryPreservesUtf8LogsWithoutExecutingEmbeddedJson() {
        val body = "<inf> räven 🦊 {\"t\":\"http\",\"url\":\"https://invalid/\"}\r\n"
        val status = "{\"t\":\"status\",\"bat\":80}"
        val wire = (status + "<BLELOG>" + body + "</BLELOG>{\"t\":\"time\"}\n").toByteArray()
        for (split in 0..wire.size) {
            val logs = mutableListOf<String>()
            val parser = NusJsonFramer(log = logs::add)
            val messages = parser.feed(wire.copyOfRange(0, split)) + parser.feed(wire.copyOfRange(split, wire.size))
            assertEquals(listOf(status, "{\"t\":\"time\"}"), messages)
            assertEquals(listOf(body), logs)
        }
        val logs = mutableListOf<String>(); val messages = mutableListOf<String>()
        val parser = NusJsonFramer(log = logs::add)
        wire.forEach { messages.addAll(parser.feed(byteArrayOf(it))) }
        assertEquals(listOf(body), logs)
        assertEquals(2, messages.size)
    }

    @Test fun adjacentControlMessagesAndTagTextInsideJsonArePreserved() {
        val logs = mutableListOf<String>()
        val parser = NusJsonFramer(log = logs::add)
        val json = "{\"t\":\"voice_result_ack\",\"text\":\"<BLELOG>in JSON</BLELOG>\"}"
        assertEquals(listOf(json, "{\"t\":\"http\"}"), parser.feed(
            ("<BLELOG>one</BLELOG><BLELOG>two</BLELOG>" + json + "{\"t\":\"http\"}").toByteArray()))
        assertEquals(listOf("one", "two"), logs)
    }

    @Test fun oversizedInvalidAndInterruptedLogsAreBoundedAndNeverBecomeCommands() {
        val logs = mutableListOf<String>()
        val parser = NusJsonFramer(log = logs::add)
        val oversized = "<BLELOG>" + "x".repeat(9000) + "{\"t\":\"time\"}</BLELOG>{\"t\":\"status\"}"
        assertEquals(listOf("{\"t\":\"status\"}"), parser.feed(oversized.toByteArray()))
        parser.feed("<BLELOG>".toByteArray() + byteArrayOf(0xc3.toByte()) + "</BLELOG>".toByteArray())
        assertEquals(2L, parser.droppedLogs)
        parser.feed("<BLELOG>abandoned {".toByteArray())
        parser.feed("<BLELOG>fresh</BLELOG>".toByteArray())
        assertEquals(listOf("fresh"), logs)
        assertEquals(3L, parser.droppedLogs)
        parser.feed("<BLELOG>old connection".toByteArray()); parser.reset()
        assertEquals(listOf("{}"), parser.feed("{}<BLELOG>new</BLELOG>".toByteArray()))
        assertEquals(listOf("fresh", "new"), logs)
    }

    @Test fun writeCompletionIsFencedByDisableAndDisconnect() {
        val events = mutableListOf<Map<String, Any?>>()
        val capture = CompanionLiveLogs(events::add)
        val completions = mutableListOf<() -> Unit>()
        val writes = mutableListOf<Boolean>()
        val write: (Boolean, () -> Unit) -> Unit = { enabled, done -> writes.add(enabled); completions.add(done) }
        capture.receive("off"); assertTrue(events.isEmpty())
        capture.request(true, write)
        assertEquals(true, capture.state()["pending"])
        assertEquals(false, capture.state()["written"])
        capture.request(false, write)
        completions[0]()
        assertEquals(false, capture.state()["requested"])
        assertEquals(true, capture.state()["pending"])
        completions[1]()
        assertEquals(false, capture.state()["pending"])
        capture.request(true, write); completions[2]()
        capture.receive("actual log")
        assertEquals("actual log", events.last()["message"])
        capture.reset(); completions[2](); capture.receive("late log")
        assertEquals(false, capture.state()["written"])
        assertEquals("state", events.last()["kind"])
        assertEquals(listOf(true, false, true), writes)
    }

    @Test fun missingLogTailExpiresWithoutExecutingJsonInsideAnActiveLog() {
        val logs = mutableListOf<String>()
        val parser = NusJsonFramer(log = logs::add)
        assertTrue(parser.feed("<BLELOG>unfinished".toByteArray(), 100).isEmpty())
        assertTrue(parser.feed("{\"t\":\"http\"}".toByteArray(), 500).isEmpty())
        assertEquals(listOf("{\"t\":\"time\"}"), parser.feed("{\"t\":\"time\"}".toByteArray(), 5100))
        assertEquals(1L, parser.droppedLogs)
        assertTrue(logs.isEmpty())
    }

    @Test fun rejectedWriteClearsPendingWithoutClaimingCapture() {
        val capture = CompanionLiveLogs {}
        try { capture.request(true) { _, _ -> error("NUS not ready") }; fail() }
        catch (_: IllegalStateException) {}
        assertEquals(false, capture.state()["pending"])
        assertEquals(false, capture.state()["requested"])
        assertEquals(false, capture.state()["written"])
    }
}
