package dev.zswatch.app.companion

import org.junit.Assert.*
import org.junit.Test

class PrototypeWatchRestartTest {
    private class Rig {
        var generation = 1L
        val timers = mutableListOf<() -> Unit>()
        val preparations = mutableListOf<(Result<Long>) -> Unit>()
        val sent = mutableListOf<Pair<Long, (Result<Unit>) -> Unit>>()
        val releases = mutableListOf<Long>()
        val results = mutableListOf<Result<Unit>>()
        val operation = PrototypeWatchRestart({ it == generation },
            { _, action -> timers.add(action) }, { _, done -> preparations.add(done) },
            { session, done -> sent.add(session to done) }, { releases.add(it) })
        fun start() = operation.start(generation) { results.add(it) }
    }
    @Test fun onePreparationReconnectCanAdvanceButResetIsSentOnlyOnce() {
        val r = Rig(); r.start(); r.generation = 2
        r.operation.disconnected(false)
        r.preparations.single()(Result.success(2)); r.preparations.single()(Result.success(2))
        assertEquals(2L, r.sent.single().first)
        r.sent.single().second(Result.success(Unit)); r.timers.single()()
        assertTrue(r.results.single().isSuccess); assertEquals(listOf(2L), r.releases)
    }
    @Test fun stopDuringPreparationPreventsResetEvenIfItsCallbackIsLate() {
        val r = Rig(); r.start(); r.operation.disconnected(true)
        r.preparations.single()(Result.success(1)); r.timers.single()()
        assertTrue(r.results.single().isFailure); assertTrue(r.sent.isEmpty())
        assertFalse(r.operation.busy)
    }
    @Test fun disconnectAfterSendingDoesNotReplayOrAcceptLateAck() {
        val r = Rig(); r.start(); r.preparations.single()(Result.success(1))
        r.operation.disconnected(false); r.generation = 2
        r.sent.single().second(Result.success(Unit)); r.timers.single()()
        assertTrue(r.results.single().isFailure); assertEquals(1, r.sent.size)
        assertFalse(r.operation.busy)
    }
    @Test fun deadlineDoesNotRetryAndOldAckCannotCompleteNewRequest() {
        val r = Rig(); r.start(); r.preparations.single()(Result.success(1))
        val oldAck = r.sent.single().second
        r.timers.single()(); assertTrue(r.results.single().isFailure)
        r.start(); r.preparations.last()(Result.success(1))
        oldAck(Result.success(Unit)); assertTrue(r.operation.busy)
        r.sent.last().second(Result.success(Unit))
        assertTrue(r.results.last().isSuccess); assertEquals(2, r.sent.size)
    }
    @Test fun nonOwnerAndConcurrentRestartsAreRejectedBeforeSdkReset() {
        val r = Rig()
        assertThrows(IllegalStateException::class.java) { r.operation.start(0) {} }
        r.start(); assertThrows(IllegalStateException::class.java) { r.start() }
        assertTrue(r.sent.isEmpty()); assertEquals(1, r.preparations.size)
    }
    @Test fun preparationFailureAndSynchronousSdkFailureRelease() {
        val r = Rig(); r.start(); r.preparations.single()(Result.failure(IllegalStateException("prepare")))
        assertTrue(r.results.single().isFailure); assertEquals(listOf(1L), r.releases)
        val releases = mutableListOf<Long>(); val results = mutableListOf<Result<Unit>>()
        val operation = PrototypeWatchRestart({ true }, { _, _ -> },
            { g, done -> done(Result.success(g)) }, { _, _ -> error("SDK unavailable") }, { releases.add(it) })
        operation.start(1) { results.add(it) }
        assertFalse(operation.busy); assertTrue(results.single().isFailure)
        assertEquals(listOf(1L), releases)
    }
}
