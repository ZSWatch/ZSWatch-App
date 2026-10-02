package dev.zswatch.app.companion

import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.json.JSONObject
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.charset.CharacterCodingException
import java.util.concurrent.TimeUnit

class PrototypeContractsTest {
    @get:Rule val temporary = TemporaryFolder()
    private val address = "AA:BB:CC:DD:EE:FF"
    private fun store(limit: Int = 256) = PrototypeStore(temporary.root, limit)
    private class Link : PrototypeTransport {
        val sessions = mutableListOf<Pair<String, Long>>()
        var closes = 0
        var onConnect: ((Long) -> Unit)? = null
        override fun connect(address: String, generation: Long) { sessions.add(address to generation); onConnect?.invoke(generation) }
        override fun close() { closes++ }
    }
    private fun rejected(action: () -> Unit) {
        try { action(); fail("Expected rejection") } catch (_: IllegalArgumentException) {}
    }

    @Test fun duplicateStartDoesNotAcquireAnotherTransport() {
        val link = Link(); val runtime = PrototypeRuntime(store(), link)
        runtime.start(address); runtime.start(address)
        assertEquals(1, link.sessions.size)
        assertEquals(0, link.closes)
        assertTrue(runtime.active)
    }

    @Test fun changingAnActiveWatchDoesNotCloseItsOwner() {
        val link = Link(); val runtime = PrototypeRuntime(store(), link)
        runtime.start(address)
        try { runtime.start("11:22:33:44:55:66"); fail() } catch (_: IllegalStateException) {}
        assertEquals(address, runtime.store.control()["address"])
        assertEquals(0, link.closes)
        assertTrue(runtime.owns(link.sessions.single().second))
    }

    @Test fun generationIsCommittedBeforeSynchronousConnectCallback() {
        val link = Link(); val runtime = PrototypeRuntime(store(), link)
        link.onConnect = { assertTrue(runtime.owns(it)); assertTrue(runtime.phase(it, "ready")) }
        runtime.start(address)
        assertTrue(runtime.store.snapshot(true)["protocol_ready"] == true)
        assertEquals("ready", store().control()["phase"])
    }

    @Test fun destructionPreservesIntentAndNewOwnerRejectsOldCallbacks() {
        val firstLink = Link(); val first = PrototypeRuntime(store(), firstLink)
        first.start(address); val old = first.generation
        first.destroy()
        assertFalse(first.owns(old))
        val nextLink = Link(); val next = PrototypeRuntime(store(), nextLink)
        assertTrue(next.restore())
        assertTrue(next.generation > old)
        assertFalse(next.phase(old, "ready"))
        assertEquals("connecting", next.store.control()["phase"])
        assertEquals(address, nextLink.sessions.single().first)
    }

    @Test fun explicitStopPersistsAndCannotBeRestored() {
        val runtime = PrototypeRuntime(store(), Link()); runtime.start(address)
        val old = runtime.generation; runtime.stop()
        assertFalse(runtime.phase(old, "ready"))
        val next = PrototypeRuntime(store(), Link())
        assertFalse(next.restore()); assertFalse(next.active)
        assertEquals(false, next.store.control()["desired_running"])
    }

    @Test fun reconnectFencesThePreviousConnection() {
        val link = Link(); val runtime = PrototypeRuntime(store(), link)
        runtime.start(address); val old = runtime.generation; runtime.reconnect()
        assertEquals(2, link.sessions.size); assertEquals(1, link.closes)
        assertFalse(runtime.phase(old, "disconnected"))
        assertTrue(runtime.phase(runtime.generation, "ready"))
    }

    @Test fun failedConnectRetainsUserIntentAndReportsInactiveProtocol() {
        val link = Link(); link.onConnect = { throw IllegalStateException("radio off") }
        val runtime = PrototypeRuntime(store(), link); runtime.start(address)
        assertEquals("error", runtime.store.control()["phase"])
        assertEquals(true, runtime.store.control()["desired_running"])
        assertEquals(false, runtime.store.snapshot(runtime.active)["protocol_ready"])
        assertEquals(1, link.closes)
    }

    @Test fun queuedEventsAndReceiptSurviveReopenAndAck() {
        val journal = store()
        journal.update("connection_state", mapOf("phase" to "ready"))
        journal.putRecord("memo", mapOf("state" to "pending", "filename" to "recording"))
        val reopened = store()
        assertEquals(2, (reopened.control()["events"] as List<*>).size)
        reopened.acknowledge(1)
        assertEquals(1, (store().control()["events"] as List<*>).size)
        reopened.acknowledge(2); reopened.acknowledge(1)
        assertTrue((store().control()["events"] as List<*>).isEmpty())
        assertEquals("pending", store().record("memo")!!["state"])
        assertEquals(false, store().snapshot(false)["event_gap"])
        assertEquals(false, store().snapshot(false)["protocol_ready"])
    }

    @Test fun boundedDiagnosticRingReportsGapWithoutDroppingReceipt() {
        val journal = store(3)
        journal.putRecord("memo", mapOf("state" to "downloaded"))
        repeat(5) { journal.update("connection_state") }
        val snapshot = store(3).snapshot(false)
        assertEquals(3, (snapshot["events"] as List<*>).size)
        assertEquals(4L, snapshot["oldest_event_cursor"])
        assertEquals(true, snapshot["event_gap"])
        assertEquals("downloaded", journal.record("memo")!!["state"])
        journal.acknowledge(6)
        assertEquals(false, journal.snapshot(false)["event_gap"])
    }

    @Test fun futureAckIsRejectedAndDoesNotAlterJournal() {
        val journal = store(); journal.update("event")
        val previous = File(temporary.root, "state-v1.json").readText()
        rejected { journal.acknowledge(2) }; rejected { journal.acknowledge(-1) }
        assertEquals(previous, File(temporary.root, "state-v1.json").readText())
    }

    @Test fun corruptJournalIsRetainedAndNeverReset() {
        val file = File(temporary.root, "state-v1.json"); file.writeText("broken")
        try { store(); fail() } catch (_: org.json.JSONException) {}
        assertEquals("broken", file.readText())
        file.writeText("{\"version\":2}")
        rejected { store() }; assertEquals("{\"version\":2}", file.readText())
    }

    @Test fun fullReceiptStoreRejectsNewEntriesAndAllowsUpdatingExisting() {
        val journal = store()
        repeat(100) { journal.putRecord("memo$it", mapOf("state" to "pending")) }
        rejected { journal.putRecord("overflow", mapOf("state" to "pending")) }
        journal.putRecord("memo0", mapOf("state" to "downloaded"))
        assertEquals(100, (store().control()["recordings"] as Map<*, *>).size)
        assertEquals("downloaded", store().record("memo0")!!["state"])
    }

    @Test fun fragmentedUtf8AndQuotedBracesFrameExactlyOnce() {
        val framer = NusJsonFramer()
        val message = "{\"t\":\"voice_memo\",\"text\":\"räv 🦊 } \\\" {\",\"nested\":{\"x\":1}}"
        val results = mutableListOf<String>()
        for (byte in ("GB(" + message + ")\n").toByteArray()) results.addAll(framer.feed(byteArrayOf(byte)))
        assertEquals(listOf(message), results)
    }

    @Test fun severalMessagesAndResetDiscardIncompleteOldConnection() {
        val framer = NusJsonFramer()
        assertEquals(listOf("{\"a\":1}", "{\"b\":2}"), framer.feed("prefix{\"a\":1}\n{\"b\":2}".toByteArray()))
        framer.feed("{\"stale\":".toByteArray()); framer.reset()
        assertEquals(listOf("{\"fresh\":1}"), framer.feed("{\"fresh\":1}".toByteArray()))
    }

    @Test fun oversizedAndInvalidUtf8MessagesRejectAndReset() {
        val framer = NusJsonFramer(12)
        rejected { framer.feed("{\"a\":\"0123456789\"}".toByteArray()) }
        assertEquals(listOf("{}"), framer.feed("{}".toByteArray()))
        try { framer.feed(byteArrayOf(123, 34, 120, 34, 58, 34, 0xc3.toByte(), 34, 125)); fail() }
        catch (_: CharacterCodingException) {}
        assertEquals(listOf("{}"), framer.feed("{}".toByteArray()))
    }

    private fun fixture(): ByteArray {
        val buffer = ByteBuffer.allocate(5472).order(ByteOrder.LITTLE_ENDIAN)
        buffer.put("ZSWO".toByteArray()).putShort(1).putShort(16000).putShort(160).putShort(0)
            .putInt(32000).putInt(1700000000).putInt(160).putInt(1600).putInt(0)
        repeat(160) { frame -> buffer.putShort(32); repeat(32) { buffer.put(((frame + it) % 256).toByte()) } }
        return buffer.array()
    }
    private fun metadata() = mapOf<String, Any?>("timestamp" to 1700000000L, "duration_ms" to 1600L,
        "size_bytes" to 5472L, "state" to "downloading")
    private fun files() = ReceiptFiles(File(temporary.root, "recordings"))

    @Test fun newRecordingUsesListHeaderTimestampAndPublishesOnlyOneReceipt() {
        val journal = store(); journal.update("selected", mapOf("address" to address))
        var requests = 0
        val inbox = PrototypeRecordingInbox(journal) { requests++ }
        // zsw_recording_manager.c emits stop time; the list reads start time from the header.
        val event = JSONObject("""{"t":"voice_memo","action":"new","filename":"REC_001",
            "timestamp":1700000002,"size_bytes":5472,"duration_ms":1600}""")
        inbox.receive(event)
        assertEquals(1, requests)
        assertTrue((journal.control()["recordings"] as Map<*, *>).isEmpty())
        val response = JSONObject("""{"t":"voice_memo","action":"list_result","recordings":[
            {"filename":"REC_001","timestamp":1700000000,"size_bytes":5472,"duration_ms":1600}]}""")
        inbox.receive(response)
        val key = (journal.control()["recordings"] as Map<*, *>).keys.single() as String
        val receipt = files().publish(key, journal.record(key)!!, fixture())
        journal.putRecord(key, receipt)
        inbox.receive(event); inbox.receive(response)
        val reopened = store()
        assertEquals(2, requests)
        assertEquals(1, (reopened.control()["recordings"] as Map<*, *>).size)
        assertEquals("downloaded", reopened.record(key)!!["state"])
        assertEquals(1700000000L, (reopened.record(key)!!["timestamp"] as Number).toLong())
        assertArrayEquals(fixture(), File(receipt["local_path"] as String).readBytes())
    }

    @Test fun newRecordingHintDoesNotRequireOrTrustItsMetadata() {
        val journal = store()
        var requests = 0
        val inbox = PrototypeRecordingInbox(journal) { requests++ }
        inbox.receive(JSONObject("""{"t":"voice_memo","action":"new"}"""))
        inbox.receive(JSONObject("""{"t":"unrelated","action":"new"}"""))
        assertEquals(1, requests)
        assertTrue((journal.control()["recordings"] as Map<*, *>).isEmpty())
    }

    /** Wire-level subset of ble_gadgetbridge_input/parse_time/parse_time_zone.
     * Each call represents one ATT write; clock commands have no reassembly.
     * This tests delivery to the parser, not main.c's application of the timezone.
     */
    private fun firmwareClockEvent(packet: ByteArray): Pair<String, Double>? {
        val text = packet.toString(Charsets.UTF_8)
        for ((prefix, event) in listOf("setTime(" to "seconds", ";E.setTimeZone(" to "timezone")) {
            val start = text.indexOf(prefix)
            if (start < 0) continue
            val end = text.indexOf(')', start + prefix.length)
            if (end < 0) return null
            return event to text.substring(start + prefix.length, end).toDouble()
        }
        return null
    }

    private fun clockEvents(offset: Double, payload: Int): List<Pair<String, Double>?> =
        PrototypeClockCommands.packets(1700000000L, offset, payload).map { bytes ->
            val write = NusWrite(bytes, packetSize = bytes.size)
            val packet = write.packet()
            assertTrue(packet.size <= payload)
            assertTrue(write.advance()) // Each command must finish in exactly one ATT write.
            firmwareClockEvent(packet)
        }

    @Test fun minimumMtuDeliversBothClockCommandsIncludingTimezonePrefix() {
        for (offset in listOf(0.0, 2.0, -12.0, 5.5, 5.75, -9.5)) {
            assertEquals(listOf("seconds" to 1700000000.0, "timezone" to offset), clockEvents(offset, 20))
        }
    }

    @Test fun negotiatedMtuDeliversLongFractionalTimezoneIntact() {
        for (offset in listOf(12.75, 13.75)) {
            assertEquals(listOf("seconds" to 1700000000.0, "timezone" to offset), clockEvents(offset, 61))
        }
    }

    @Test fun unsupportedClockPayloadRejectsBeforeReturningAnyCommands() {
        rejected { PrototypeClockCommands.packets(1700000000L, 13.75, 20) }
        rejected { PrototypeClockCommands.packets(1700000000L, 2.0, 18) }
    }

    @Test fun ordinaryNusWritesStillReassembleAcrossMinimumMtuPackets() {
        val bytes = "GB({\"t\":\"voice_memo\",\"action\":\"list\"})".toByteArray()
        val write = NusWrite(bytes)
        val packets = mutableListOf<Byte>()
        do {
            val packet = write.packet()
            assertTrue(packet.size in 1..20)
            packets.addAll(packet.toList())
        } while (!write.advance())
        assertArrayEquals(bytes, packets.toByteArray())
    }

    @Test fun closedContainerMatchesUsbFixtureAndRejectsBrokenBoundaries() {
        val files = files(); val bytes = fixture(); val meta = metadata()
        assertTrue(files.valid(bytes, meta))
        assertEquals("effa60b67bee0f4d8da64cc35755a07a1e7535b2ed0ced083ce34bdd7d22ff18", ReceiptFiles.sha(bytes))
        assertFalse(files.valid(bytes.copyOf(bytes.size - 1), meta))
        assertFalse(files.valid(bytes, meta + ("timestamp" to 1700000001L)))
        assertFalse(files.valid(bytes, meta + ("duration_ms" to 1599L)))
        val dirty = bytes.clone(); ByteBuffer.wrap(dirty).order(ByteOrder.LITTLE_ENDIAN).putInt(20, -1)
        assertFalse(files.valid(dirty, meta))
        val broken = bytes.clone(); broken[32] = 0; broken[33] = 0
        assertFalse(files.valid(broken, meta))
        val extra = bytes + byteArrayOf(1)
        assertFalse(files.valid(extra, meta + ("size_bytes" to extra.size)))
    }

    @Test fun publicationBeforeJournalCommitIsRecoverableAfterReopen() {
        val journal = store(); val meta = metadata(); journal.putRecord("memo", meta)
        val receipt = files().publish("memo", meta, fixture()) // crash boundary: no journal receipt commit
        assertEquals("downloading", store().record("memo")!!["state"])
        val recovered = files().recover("memo", store().record("memo")!!)!!
        assertEquals(receipt["sha256"], recovered["sha256"])
        journal.putRecord("memo", recovered)
        assertEquals("downloaded", store().record("memo")!!["state"])
        assertArrayEquals(fixture(), File(recovered["local_path"] as String).readBytes())
    }

    @Test fun completeStageCanBeRecoveredAndPartialStageCannot() {
        val files = files(); val target = files.destination("memo"); val partial = File(target.path + ".partial")
        partial.writeBytes(fixture().copyOf(100)); assertNull(files.recover("memo", metadata()))
        assertTrue(partial.exists()); assertFalse(target.exists())
        partial.writeBytes(fixture()); assertNotNull(files.recover("memo", metadata()))
        assertTrue(target.exists()); assertFalse(partial.exists())
    }

    @Test fun invalidPriorReceiptIsRetainedAndValidReceiptNotOverwritten() {
        val files = files(); val target = files.destination("memo"); target.writeText("invalid prior")
        files.publish("memo", metadata(), fixture())
        assertTrue(target.parentFile!!.listFiles()!!.any { it.name.contains(".invalid-") && it.readText() == "invalid prior" })
        val second = fixture().clone(); second[40] = 99 // structurally valid synthetic content
        files.publish("memo", metadata(), second)
        assertArrayEquals(fixture(), target.readBytes())
        rejected { files.publish("other", metadata(), byteArrayOf(1)) }
        assertFalse(files.destination("other").exists())
    }

    private fun killWorkerAt(boundary: String) {
        val classpath = listOf(PrototypeCrashWorker::class.java, PrototypeStore::class.java,
            org.json.JSONObject::class.java, kotlin.Unit::class.java)
            .map { File(it.protectionDomain.codeSource.location.toURI()).path }.distinct().joinToString(File.pathSeparator)
        val worker = ProcessBuilder(File(System.getProperty("java.home"), "bin/java").path,
            "-cp", classpath, PrototypeCrashWorker::class.java.name, temporary.root.path, boundary)
            .redirectErrorStream(true).redirectOutput(File(temporary.root, "worker.log")).start()
        try {
            val deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(10)
            val ready = File(temporary.root, "ready")
            while (!ready.exists() && worker.isAlive && System.nanoTime() < deadline) Thread.sleep(10)
            assertTrue(File(temporary.root, "worker.log").readText(), ready.exists())
            assertTrue(worker.isAlive)
            worker.destroyForcibly()
            assertTrue(worker.waitFor(5, TimeUnit.SECONDS))
        } finally { if (worker.isAlive) worker.destroyForcibly().waitFor() }
    }

    private fun recoverKilledReceipt(expectedState: String) {
        val journal = store()
        assertEquals(true, journal.control()["desired_running"])
        assertEquals(expectedState, journal.record("memo")!!["state"])
        val recovered = files().recover("memo", journal.record("memo")!!)!!
        assertEquals("downloaded", recovered["state"])
        assertArrayEquals(fixture(), File(recovered["local_path"] as String).readBytes())
        val runtime = PrototypeRuntime(journal, Link())
        assertTrue(runtime.restore())
        assertEquals(2L, runtime.generation)
        assertFalse(runtime.phase(1, "ready"))
        journal.putRecord("memo", recovered)
        assertEquals("downloaded", store().record("memo")!!["state"])
    }

    @Test fun killedNativeWorkerAfterCompleteStageRecoversReceiptAndIntent() {
        killWorkerAt("staged"); recoverKilledReceipt("downloading")
    }

    @Test fun killedNativeWorkerAfterPublicationRecoversUncommittedReceipt() {
        killWorkerAt("published"); recoverKilledReceipt("downloading")
    }

    @Test fun killedNativeWorkerAfterJournalCommitRetainsReceipt() {
        killWorkerAt("committed"); recoverKilledReceipt("downloaded")
    }
}

/** Runs outside Gradle's worker VM and is forcibly killed at an actual IO boundary. */
object PrototypeCrashWorker {
    @JvmStatic fun main(args: Array<String>) {
        val root = File(args[0]); val boundary = args[1]
        val journal = PrototypeStore(root)
        val runtime = PrototypeRuntime(journal, object : PrototypeTransport {
            override fun connect(address: String, generation: Long) {}
            override fun close() {}
        })
        runtime.start("AA:BB:CC:DD:EE:FF")
        val meta = mapOf<String, Any?>("timestamp" to 1700000000L, "duration_ms" to 1600L,
            "size_bytes" to 5472L, "state" to "downloading")
        journal.putRecord("memo", meta)
        val bytes = ByteBuffer.allocate(5472).order(ByteOrder.LITTLE_ENDIAN)
        bytes.put("ZSWO".toByteArray()).putShort(1).putShort(16000).putShort(160).putShort(0)
            .putInt(32000).putInt(1700000000).putInt(160).putInt(1600).putInt(0)
        repeat(160) { frame -> bytes.putShort(32); repeat(32) { bytes.put(((frame + it) % 256).toByte()) } }
        val files = ReceiptFiles(File(root, "recordings"))
        if (boundary == "staged") {
            java.io.FileOutputStream(File(files.destination("memo").path + ".partial")).use {
                it.write(bytes.array()); it.fd.sync()
            }
        } else {
            val receipt = files.publish("memo", meta, bytes.array())
            if (boundary == "committed") journal.putRecord("memo", receipt)
        }
        File(root, "ready").writeText(boundary)
        while (true) Thread.sleep(1000)
    }
}
