package dev.zswatch.app.companion

import org.junit.Assert.*
import org.junit.Test

class PrototypeDiscoveryRecoveryTest {
    private var session = 1L
    private var client = Any()
    private var discovering = true
    private var refreshResult = true
    private var refreshes = 0
    private val timers = mutableListOf<() -> Unit>()
    private val retries = mutableListOf<Long>()
    private val failures = mutableListOf<String>()
    private val recovery = PrototypeDiscoveryRecovery<Any>(
        current = { token, connection -> token == session && connection === client && discovering },
        refresh = { refreshes++; refreshResult },
        later = { delay, action -> assertEquals(1000L, delay); timers += action },
        retry = { token, _ -> retries += token },
        failed = { _, message -> failures += message },
    )

    @Test fun refreshSettlesBeforeRediscoveryAndDuplicateTimeoutsAreCoalesced() {
        recovery.timedOut(session, client)
        recovery.timedOut(session, client)
        assertEquals(1, refreshes)
        assertTrue(retries.isEmpty())
        assertTrue(failures.isEmpty())
        timers.removeAt(0).invoke()
        assertEquals(listOf(1L), retries)
    }

    @Test fun repeatedStallsHaveABoundedRecoveryBudget() {
        repeat(2) {
            recovery.timedOut(session, client)
            timers.removeAt(0).invoke()
        }
        recovery.timedOut(session, client)
        assertEquals(2, refreshes)
        assertEquals(2, retries.size)
        assertTrue(timers.isEmpty())
        assertTrue(failures.single().contains("after cache recovery"))
    }

    @Test fun stoppedReplacedOrReadyConnectionsCannotReceiveDelayedRetry() {
        for (change in listOf<() -> Unit>(
            { session++ }, { client = Any() }, { discovering = false },
        )) {
            discovering = true
            recovery.reset()
            recovery.timedOut(session, client)
            change()
            timers.removeAt(0).invoke()
        }
        assertTrue(retries.isEmpty())
        assertTrue(failures.isEmpty())
    }

    @Test fun resetCancelsOldTimersWithoutCancellingTheNextRecovery() {
        recovery.timedOut(session, client)
        recovery.reset()
        recovery.timedOut(session, client)
        timers.removeAt(0).invoke()
        assertTrue(retries.isEmpty())
        timers.removeAt(0).invoke()
        assertEquals(listOf(1L), retries)
    }

    @Test fun unavailableCacheRefreshFailsWithoutSchedulingAnotherRequest() {
        refreshResult = false
        recovery.timedOut(session, client)
        assertTrue(failures.single().contains("could not refresh"))
        assertTrue(timers.isEmpty())
        assertTrue(retries.isEmpty())
    }

    @Test fun staleTimeoutDoesNotTouchTheCurrentConnection() {
        recovery.timedOut(session - 1, client)
        recovery.timedOut(session, Any())
        assertEquals(0, refreshes)
        assertTrue(failures.isEmpty())
    }
}
