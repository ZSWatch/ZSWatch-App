package dev.zswatch.app.companion

import org.junit.Assert.*
import org.junit.Test

class PrototypeSmpPreparationTest {
    private class Rig {
        var state = PrototypeSmpSession(7, "watch", true, true, false)
        var time = 0L
        var enabled = 0
        val timers = mutableListOf<Pair<Long, () -> Unit>>()
        val prepared = mutableListOf<Long>()
        val results = mutableListOf<Result<Long>>()
        val connections = mutableListOf<Pair<Long, (Result<Unit>) -> Unit>>()
        val preparation = PrototypeSmpPreparation({ state },
            { delay, action -> timers.add(time + delay to action) },
            { enabled++ }, { generation, done -> connections.add(generation to done) }, { prepared.add(it) })
        fun start() = preparation.start(7) { results.add(it) }
        fun advance(ms: Long) {
            time += ms
            while (true) {
                val next = timers.filter { it.first <= time }.minByOrNull { it.first } ?: break
                timers.remove(next); next.second()
            }
        }
    }

    @Test fun coldPreparationWaitsForFreshReadyWithSmpHandles() {
        val r = Rig(); r.start(); assertEquals(1, r.enabled)
        r.state = r.state.copy(ready = false); r.advance(2000)
        r.state = r.state.copy(generation = 8, ready = true); r.advance(200)
        assertTrue(r.results.isEmpty()) // Ready without SMP is insufficient.
        r.state = r.state.copy(available = true); r.advance(200)
        assertEquals(8L, r.results.single().getOrThrow()); assertEquals(listOf(8L), r.prepared)
        r.advance(15000); assertEquals(1, r.results.size)
    }

    @Test fun alreadyDiscoveredSmpNeedsNoEnableOrReconnect() {
        val r = Rig(); r.state = r.state.copy(available = true); r.start()
        assertEquals(7L, r.results.single().getOrThrow()); assertEquals(0, r.enabled)
        assertFalse(r.preparation.busy)
    }

    @Test fun stopWatchReplacementAndStopThenStartRejectPreparation() {
        for (changed in listOf(PrototypeSmpSession(8, "watch", false, false, true),
            PrototypeSmpSession(8, "other", true, true, true),
            PrototypeSmpSession(9, "watch", true, true, true))) {
            val r = Rig(); r.start(); r.state = changed; r.advance(2000)
            assertTrue(r.results.single().isFailure); assertTrue(r.prepared.isEmpty())
        }
    }

    @Test fun timeoutAndOwnerDisposalDiscardLateReadyWithoutResourceAcquisition() {
        for (dispose in listOf(false, true)) {
            val r = Rig(); r.start()
            if (dispose) r.preparation.close() else r.advance(15000)
            r.state = r.state.copy(generation = 8, available = true); r.advance(15000)
            assertTrue(r.results.single().isFailure); assertTrue(r.prepared.isEmpty())
        }
    }

    @Test fun staleGenerationAndConcurrentPrepareNeverWriteAnotherEnable() {
        val r = Rig()
        assertThrows(IllegalStateException::class.java) { r.preparation.start(6) {} }
        r.start(); assertThrows(IllegalStateException::class.java) { r.start() }
        assertEquals(1, r.enabled)
    }

    @Test fun oldPollCannotFinishANewerPreparation() {
        val r = Rig(); r.start(); val oldPoll = r.timers.first { it.first == 2000L }.second
        r.preparation.close(); r.start(); oldPoll()
        assertTrue(r.preparation.busy); assertEquals(1, r.results.size)
        r.state = r.state.copy(available = true); r.advance(2000)
        assertEquals(7L, r.results.last().getOrThrow()); assertEquals(listOf(7L), r.prepared)
    }

    @Test fun sdkReadinessComesFromItsOwnConnectionAndOldCallbacksAreFenced() {
        val r = Rig(); r.start(); r.advance(2000)
        assertEquals(7L, r.connections.single().first)
        r.state = r.state.copy(generation = 8); r.advance(200)
        assertEquals(8L, r.connections.last().first)
        r.connections.first().second(Result.failure(IllegalStateException("Old SDK")))
        assertTrue(r.results.isEmpty()); assertTrue(r.preparation.busy)
        r.state = r.state.copy(available = true)
        r.connections.last().second(Result.success(Unit)); r.advance(200)
        assertEquals(8L, r.results.single().getOrThrow())
    }

    @Test fun sdkFailureCannotReturnPreparedOrAcquireItsLease() {
        val r = Rig(); r.start(); r.advance(2000)
        r.connections.single().second(Result.failure(IllegalStateException("SDK discovery failed")))
        r.state = r.state.copy(available = true); r.advance(15000)
        assertTrue(r.results.single().isFailure); assertTrue(r.prepared.isEmpty())
    }

    @Test fun sdkClosedDuringServiceChangeDoesNotCancelUnexecutedPreparation() {
        val r = Rig(); r.start(); r.advance(2000)
        r.state = r.state.copy(ready = false)
        r.connections.single().second(Result.failure(IllegalStateException("SDK closed with old NUS")))
        r.advance(200); assertTrue(r.results.isEmpty())
        r.state = r.state.copy(generation = 8, ready = true); r.advance(200)
        r.state = r.state.copy(available = true)
        r.connections.last().second(Result.success(Unit)); r.advance(200)
        assertEquals(8L, r.results.single().getOrThrow())
    }
}
