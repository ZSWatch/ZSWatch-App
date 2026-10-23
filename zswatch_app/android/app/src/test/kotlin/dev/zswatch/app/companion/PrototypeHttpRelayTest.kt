package dev.zswatch.app.companion

import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import java.net.ServerSocket
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.nio.file.Files

class PrototypeHttpRelayTest {
    private class Fixture {
        var clock = 0L
        val timers = mutableListOf<Pair<Long, () -> Unit>>()
        val callbacks = mutableListOf<(RelayResult) -> Unit>()
        val writes = mutableListOf<Triple<String, Long, () -> Unit>>()
        val observed = mutableListOf<String>()
        var cancels = 0
        var enabled = true
        val relay = PrototypeHttpRelay({ clock }, { delay, action -> timers.add(clock + delay to action) },
            { _, done -> callbacks.add(done); { cancels++ } },
            { packet, deadline, done -> writes.add(Triple(packet, deadline, done)); true },
            { kind, _, result -> observed.add("$kind:$result") }, { enabled })
        fun request(id: String = "1") = JSONObject().put("t", "http").put("id", id).put("url", "https://example.com/")
        fun tick(ms: Long) {
            clock = ms
            val due = timers.filter { it.first <= clock }; timers.removeAll(due.toSet())
            due.forEach { it.second() }
        }
    }
    @Test fun responseAndTimeoutProduceOneTerminalWriteWithOriginalId() {
        val f = Fixture(); f.relay.receive(f.request(), 7)
        f.callbacks.single()(RelayResult(body = "hello")); f.callbacks.single()(RelayResult(error = "late"))
        f.tick(6500); assertEquals(1, f.writes.size)
        val message = JSONObject(f.writes.single().first.removePrefix("GB(").substringBeforeLast(")"))
        assertEquals("1", message.getString("id")); assertEquals("hello", message.getString("resp"))
        f.writes.single().third(); f.tick(8000)
        assertEquals(0, f.relay.pendingCount); assertEquals(1, f.observed.count { it == "completed:written" })
    }
    @Test fun exactFirmwareRequestWithBareIdSurvivesSplitNusNotifications() {
        val raw = "{\"t\":\"http\", \"url\":\"https://example.com/\", id:\"27\"} \n".toByteArray()
        val framer = NusJsonFramer(); val messages = mutableListOf<String>()
        raw.asList().chunked(20).forEach { messages.addAll(framer.feed(it.toByteArray())) }
        val f = Fixture(); assertTrue(f.relay.receive(JSONObject(messages.single()), 3))
        f.callbacks.single()(RelayResult(body = "ok"))
        assertEquals("27", JSONObject(f.writes.single().first.removePrefix("GB(").substringBeforeLast(")")).getString("id"))
    }
    @Test fun disablingCancelsNetworkAndBlocksNewIoWithoutDuplicatingPreparedReplies() {
        val f = Fixture(); f.relay.receive(f.request("1"), 1)
        f.relay.receive(f.request("2"), 1); f.callbacks[1](RelayResult(body = "prepared"))
        f.enabled = false; f.relay.disable()
        assertTrue(f.cancels > 0); assertEquals(2, f.writes.size)
        assertTrue(f.writes[0].first.contains("prepared"))
        assertTrue(f.writes[1].first.contains("HTTP relay disabled"))
        f.callbacks[0](RelayResult(body = "late")); assertEquals(2, f.writes.size)
        f.relay.receive(f.request("3"), 1)
        assertEquals(2, f.callbacks.size); assertEquals(3, f.writes.size)
        f.writes.toList().forEach { it.third() }; assertEquals(0, f.relay.pendingCount)
        f.enabled = true; f.relay.receive(f.request("4"), 1); assertEquals(3, f.callbacks.size)
    }
    @Test fun stoppedPolicySurvivesReopenWithoutChangingOwnerOrOtherWork() {
        val directory = Files.createTempDirectory("http-policy").toFile()
        try {
            val store = PrototypeStore(directory)
            assertTrue(PrototypeHttpRelay.enabled(store))
            store.update("fixture", mapOf("recording_sync_enabled" to false))
            store.putRecord("saved", mapOf("state" to "downloaded"))
            val before = store.control()
            PrototypeHttpRelay.configure(store, false)
            val reopened = PrototypeStore(directory)
            assertFalse(PrototypeHttpRelay.enabled(reopened))
            for (key in listOf("desired_running", "phase", "generation", "recording_sync_enabled", "recordings"))
                assertEquals(before[key], reopened.control()[key])
            val cursor = reopened.control()["event_cursor"]
            PrototypeHttpRelay.configure(reopened, false); assertEquals(cursor, reopened.control()["event_cursor"])
            PrototypeHttpRelay.configure(reopened, true); assertTrue(PrototypeHttpRelay.enabled(PrototypeStore(directory)))
            reopened.update("invalid_fixture", mapOf("http_enabled" to "true"))
            assertFalse(PrototypeHttpRelay.enabled(reopened))
        } finally { directory.deleteRecursively() }
    }
    @Test fun reopeningJournalClearsInterruptedHttpWithoutChangingLifecycleOrReceipts() {
        val directory = Files.createTempDirectory("relay-recovery").toFile()
        try {
            val initial = PrototypeStore(directory)
            initial.update("fixture", mapOf("generation" to 4L, "desired_running" to true,
                "phase" to "ready", "http_pending_count" to 2, "recording_sync_enabled" to false))
            initial.putRecord("existing", mapOf("state" to "downloaded", "sha256" to "fixture"))
            val reopened = PrototypeStore(directory)
            PrototypeHttpRelay.markProcessInterrupted(reopened, 123)
            val state = PrototypeStore(directory).control()
            assertEquals(0, (state["http_pending_count"] as Number).toInt())
            assertEquals("process_interrupted", (state["last_http"] as Map<*, *>)["outcome"])
            for (key in listOf("generation", "desired_running", "phase", "recording_sync_enabled", "recordings"))
                assertEquals(initial.control()[key], state[key])
            val cursor = state["event_cursor"]
            PrototypeHttpRelay.markProcessInterrupted(reopened, 456)
            assertEquals(cursor, reopened.control()["event_cursor"])
        } finally { directory.deleteRecursively() }
    }
    @Test fun timeoutCancelsIoAndLateCompletionCannotReplyAgain() {
        val f = Fixture(); f.relay.receive(f.request(), 1); f.tick(6500)
        assertTrue(f.cancels > 0); assertTrue(f.writes.single().first.contains("Request timed out"))
        f.callbacks.single()(RelayResult(body = "late")); assertEquals(1, f.writes.size)
        f.tick(8000); assertEquals(0, f.relay.pendingCount)
        f.writes.single().third(); assertFalse(f.observed.contains("completed:error_written"))
    }
    @Test fun reconnectCancelsAndFencesOldCompletionEvenWhenIdIsReused() {
        val f = Fixture(); f.relay.receive(f.request(), 1); val old = f.callbacks.single()
        f.relay.reset(); f.relay.receive(f.request(), 2)
        old(RelayResult(body = "old")); assertTrue(f.writes.isEmpty())
        f.callbacks.last()(RelayResult(body = "new")); assertEquals(1, f.writes.size)
    }
    @Test fun duplicatesAndInvalidInputDoNotStartNetworkOrBreakOtherTraffic() {
        val f = Fixture(); f.relay.receive(f.request(), 1); f.relay.receive(f.request(), 1)
        assertEquals(1, f.callbacks.size)
        assertFalse(f.relay.receive(JSONObject().put("t", "status"), 1))
        assertFalse(f.relay.receive(JSONObject().put("t", "http").put("resp", "reply"), 1))
        assertTrue(f.relay.receive(f.request().put("id", JSONObject.NULL), 1))
        f.relay.receive(f.request("2").put("url", 123), 1)
        assertEquals(1, f.callbacks.size); assertTrue(f.writes.single().first.contains("Invalid request"))
        f.writes.single().third(); f.relay.receive(f.request("2"), 1); assertEquals(1, f.callbacks.size)
    }
    @Test fun queueIsBoundedAndFullEscapedUtf8PacketFitsFirmwareBuffer() {
        val f = Fixture(); (1..5).forEach { f.relay.receive(f.request(it.toString()), 1) }
        assertEquals(4, f.callbacks.size); assertTrue(f.writes.single().first.contains("Relay busy"))
        assertTrue(PrototypeHttpRelay.packet("1", RelayResult(body = "\"\\😀".repeat(500))).contains("Response too large"))
        assertTrue(PrototypeHttpRelay.packet("1", RelayResult(body = "\"\\😀".repeat(150))).toByteArray().size < 1900)
    }
    @Test fun expiredQueuedPacketsCanBeSkippedButAnAlreadyStartedFrameMustStayWhole() {
        var allowed = true
        val write = NusWrite(byteArrayOf(1, 2, 3, 4), {}, 2) { allowed }
        assertTrue(write.mayStart()); write.advance(); allowed = false
        assertTrue(write.mayStart())
        assertFalse(NusWrite(byteArrayOf(1), {}, 20) { false }.mayStart())
    }
    private fun requestNetwork(path: String, body: String, headers: String = "", xpath: String? = null): RelayResult {
        ServerSocket(0).use { server ->
            val thread = Thread {
                server.accept().use { client ->
                    val reader = client.getInputStream().bufferedReader()
                    while (!reader.readLine().isNullOrEmpty()) {}
                    val bytes = body.toByteArray()
                    client.getOutputStream().write(("HTTP/1.1 $path\r\nContent-Length: ${bytes.size}\r\n$headers\r\n").toByteArray() + bytes)
                }
            }.apply { isDaemon = true; start() }
            val done = CountDownLatch(1); var result: RelayResult? = null
            val executor = HttpUrlRelayExecutor { it() }
            try {
                executor.execute(RelayRequest("1", "http://127.0.0.1:${server.localPort}/", xpath)) { result = it; done.countDown() }
                assertTrue(done.await(10, TimeUnit.SECONDS)); thread.join(1000)
                return result!!
            } finally { executor.close() }
        }
    }
    @Test fun actualGetHandlesSuccessErrorAndBodyLimit() {
        assertEquals("hello", requestNetwork("200 OK", "hello").body)
        assertEquals("HTTP 503", requestNetwork("503 Unavailable", "fail").error)
        assertEquals("Response too large", requestNetwork("200 OK", "x".repeat(65537)).error)
    }
    @Test fun xpathJoinsNodesAndRejectsExternalEntities() {
        assertEquals("a\nb", requestNetwork("200 OK", "<r><v>a</v><v>b</v></r>", xpath = "/r/v").body)
        assertEquals("XPath returned no results", requestNetwork("200 OK", "<r/>", xpath = "/r/v").error)
        assertEquals("XPath error", requestNetwork("200 OK", "<!DOCTYPE r [<!ENTITY x SYSTEM 'file:///etc/passwd'>]><r>&x;</r>", xpath = "/r").error)
    }
    @Test fun relativeRedirectUsesASecondGetAndPreservesResponse() {
        ServerSocket(0).use { server ->
            val paths = mutableListOf<String>()
            val peer = Thread {
                repeat(2) { index -> server.accept().use { client ->
                    val input = client.getInputStream().bufferedReader()
                    paths.add(input.readLine())
                    while (!input.readLine().isNullOrEmpty()) {}
                    val response = if (index == 0) "HTTP/1.1 302 Found\r\nLocation: /next\r\nContent-Length: 0\r\n\r\n"
                        else "HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok"
                    client.getOutputStream().write(response.toByteArray())
                } }
            }.apply { isDaemon = true; start() }
            val executor = HttpUrlRelayExecutor { it() }; val done = CountDownLatch(1)
            var result: RelayResult? = null
            try {
                executor.execute(RelayRequest("1", "http://127.0.0.1:${server.localPort}/", null)) { result = it; done.countDown() }
                assertTrue(done.await(10, TimeUnit.SECONDS)); peer.join(1000)
                assertEquals("ok", result!!.body)
                assertEquals(listOf("GET / HTTP/1.1", "GET /next HTTP/1.1"), paths)
            } finally { executor.close() }
        }
    }
    @Test fun unsupportedUrlsReturnErrorsWithoutOpeningFilesOrOtherSchemes() {
        val executor = HttpUrlRelayExecutor { it() }
        try {
            for (url in listOf("file:///etc/passwd", "ftp://example.com/", "https://user:pass@example.com/")) {
                val done = CountDownLatch(1); var result: RelayResult? = null
                executor.execute(RelayRequest("1", url, null)) { result = it; done.countDown() }
                assertTrue(done.await(2, TimeUnit.SECONDS)); assertNotNull(result!!.error); assertNull(result!!.body)
            }
        } finally { executor.close() }
    }
}
