package dev.zswatch.app.companion

import org.junit.Assert.*
import org.junit.Test

class PrototypeShellOperationTest {
    private class Rig {
        var time = 0L
        var generation = 1L
        var synchronous = false
        var enableThrows = false
        val timers = mutableListOf<Pair<Long, () -> Unit>>()
        val enables = mutableListOf<() -> Unit>()
        val executions = mutableListOf<Pair<String, (Result<PrototypeShellReply>) -> Unit>>()
        val releases = mutableListOf<Long>()
        val results = mutableListOf<Result<PrototypeShellReply>>()
        val operation = PrototypeShellOperation({ it == generation },
            { delay, action -> timers.add(time + delay to action) },
            { _, done -> if (enableThrows) error("Enable failed") else enables.add(done) },
            { command, done -> executions.add(command to done)
                if (synchronous) done(Result.success(PrototypeShellReply("ok", 0))) },
            { releases.add(it) })
        fun start(command: String = "power status") = operation.start(generation, command) { results.add(it) }
        fun advance(ms: Long) {
            time += ms
            while (true) {
                val next = timers.filter { it.first <= time }.minByOrNull { it.first } ?: break
                timers.remove(next); next.second()
            }
        }
    }

    @Test fun invalidGenerationAndCommandsNeverEnableSmp() {
        val r = Rig()
        assertThrows(IllegalStateException::class.java) { r.operation.start(0, "power status") {} }
        for (command in listOf(" ", "x".repeat(513), "power\u0000status"))
            assertThrows(IllegalArgumentException::class.java) { r.start(command) }
        assertFalse(r.operation.busy); assertTrue(r.enables.isEmpty())
    }

    @Test fun exclusiveRequestAndDuplicateEnableOnlyExecuteOnce() {
        val r = Rig(); r.start()
        assertThrows(IllegalStateException::class.java) { r.start() }
        r.enables.single()(); r.enables.single()(); r.advance(2000)
        assertEquals(1, r.executions.size)
        r.executions.single().second(Result.success(PrototypeShellReply("status", -2)))
        r.advance(30000)
        assertEquals(-2L, r.results.single().getOrThrow().returnCode)
        assertEquals(listOf(1L), r.releases); assertFalse(r.operation.busy)
    }

    @Test fun synchronousCompletionAndEnableFailureReleaseExactlyOnce() {
        val r = Rig(); r.synchronous = true; r.start(); r.enables.single()(); r.advance(2000)
        assertEquals("ok", r.results.single().getOrThrow().output); r.advance(30000)
        assertEquals(1, r.releases.size)
        val failed = Rig(); failed.enableThrows = true; failed.start(); failed.advance(30000)
        assertTrue(failed.results.single().isFailure); assertEquals(1, failed.releases.size)
    }

    @Test fun closeBeforeEnableDiscardsDelayedWork() {
        val r = Rig(); r.start(); r.operation.close(); r.enables.single()(); r.advance(30000)
        assertTrue(r.results.single().isFailure); assertTrue(r.executions.isEmpty())
        assertEquals(listOf(1L), r.releases)
    }

    @Test fun closeAndReconnectFenceOldSdkReplyAndDeadline() {
        val r = Rig(); r.start(); r.enables.single()(); r.advance(2000)
        val old = r.executions.single().second
        r.operation.close(); r.generation = 2; r.start(); r.enables.last()(); r.advance(2000)
        old(Result.success(PrototypeShellReply("old", 0)))
        assertTrue(r.operation.busy); assertEquals(1, r.results.size)
        r.executions.last().second(Result.success(PrototypeShellReply("new", 0)))
        r.advance(30000)
        assertEquals("new", r.results.last().getOrThrow().output)
        assertEquals(listOf(1L, 2L), r.releases)
    }

    @Test fun watchdogCompletesHungSdkAndDiscardsItsLateReply() {
        val r = Rig(); r.start(); r.enables.single()(); r.advance(2000); r.advance(28000)
        assertTrue(r.results.single().isFailure); assertFalse(r.operation.busy)
        r.executions.single().second(Result.success(PrototypeShellReply("late", 0)))
        assertEquals(1, r.results.size); assertEquals(1, r.releases.size)
    }

    @Test fun generationLossNeverReturnsAStaleSuccess() {
        val r = Rig(); r.start(); r.enables.single()(); r.advance(2000); r.generation = 2
        r.executions.single().second(Result.success(PrototypeShellReply("old", 0)))
        assertTrue(r.results.single().isFailure); assertEquals(listOf(1L), r.releases)
    }

    @Test fun idleLeaseKeepsBurstAndCannotReleaseANewerSession() {
        val timers = mutableListOf<() -> Unit>(); val releases = mutableListOf<Long>()
        val lease = PrototypeSmpIdleLease({ delay, action -> assertEquals(20000L, delay); timers.add(action) }, { releases.add(it) })
        lease.hold(1); lease.idle(1); lease.hold(1); timers[0]()
        assertTrue(lease.held(1)); assertTrue(releases.isEmpty())
        lease.idle(1); lease.hold(2); timers[1]()
        assertTrue(lease.held(2)); assertTrue(releases.isEmpty())
        lease.idle(2); timers[2](); assertFalse(lease.held(2)); assertEquals(listOf(2L), releases)
    }

    @Test fun ownerCloseCancelsIdleCleanupWithoutDisablingANewerOwner() {
        val timers = mutableListOf<() -> Unit>(); val releases = mutableListOf<Long>()
        val lease = PrototypeSmpIdleLease({ _, action -> timers.add(action) }, { releases.add(it) })
        lease.hold(1); lease.idle(1); lease.close(); lease.hold(2); timers.single()()
        assertTrue(lease.held(2)); assertTrue(releases.isEmpty())
    }
}
