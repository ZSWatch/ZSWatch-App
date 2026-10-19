package dev.zswatch.app.companion

import org.junit.Assert.*
import org.junit.Test

class PrototypeBondingTest {
    private class Rig {
        var current = true
        var time = 0L
        var requests = 0
        var accepted = true
        val timers = mutableListOf<Pair<Long, () -> Unit>>()
        val results = mutableListOf<String?>()
        val gate = PrototypeBonding({ current },
            { delay, action -> timers.add(time + delay to action) },
            { requests++; accepted }, { results.add(it) })
        fun advance(ms: Long) {
            time += ms
            val due = timers.filter { it.first <= time }
            timers.removeAll(due.toSet()); due.forEach { it.second() }
        }
    }

    @Test fun existingBondStartsDiscoveryWithoutPairingOrAWait() {
        val r = Rig(); r.gate.start(PrototypeBonding.State.BONDED)
        assertEquals(listOf<String?>(null), r.results)
        assertEquals(0, r.requests); assertTrue(r.timers.isEmpty())
    }

    @Test fun slowUserConfirmationDoesNotStartDiscoveryOrExpireAtTheCccdDeadline() {
        val r = Rig(); r.gate.start(PrototypeBonding.State.NONE)
        r.gate.changed(PrototypeBonding.State.BONDING); r.advance(30000)
        assertEquals(1, r.requests); assertTrue(r.results.isEmpty())
        r.gate.changed(PrototypeBonding.State.BONDED)
        r.gate.changed(PrototypeBonding.State.BONDED); r.advance(90000)
        assertEquals(listOf<String?>(null), r.results)
    }

    @Test fun pairingAlreadyStartedByTheWatchIsNotRequestedAgain() {
        val r = Rig(); r.gate.start(PrototypeBonding.State.BONDING)
        assertEquals(0, r.requests); assertTrue(r.results.isEmpty())
        r.gate.changed(PrototypeBonding.State.BONDED)
        assertEquals(listOf<String?>(null), r.results)
    }

    @Test fun rejectionAndTimeoutNeverAuthorizeDiscoveryFromLateSuccess() {
        val rejected = Rig(); rejected.gate.start(PrototypeBonding.State.BONDING)
        rejected.gate.changed(PrototypeBonding.State.NONE)
        rejected.gate.changed(PrototypeBonding.State.BONDED); rejected.advance(90000)
        assertEquals(1, rejected.results.size); assertNotNull(rejected.results.single())
        val timeout = Rig(); timeout.gate.start(PrototypeBonding.State.NONE); timeout.advance(90000)
        timeout.gate.changed(PrototypeBonding.State.BONDED)
        assertEquals(1, timeout.results.size); assertTrue(timeout.results.single()!!.contains("timed out"))
    }

    @Test fun stopAndReplacedGattDiscardLateBroadcastAndTimeout() {
        val stopped = Rig(); stopped.gate.start(PrototypeBonding.State.NONE); stopped.gate.close()
        stopped.gate.changed(PrototypeBonding.State.BONDED); stopped.advance(90000)
        assertTrue(stopped.results.isEmpty())
        val stale = Rig(); stale.gate.start(PrototypeBonding.State.BONDING); stale.current = false
        stale.gate.changed(PrototypeBonding.State.BONDED); stale.advance(90000)
        assertTrue(stale.results.isEmpty())
    }

    @Test fun immediateAndroidFailureEndsOnceWithoutWaitingForTheWatchdog() {
        val r = Rig(); r.accepted = false; r.gate.start(PrototypeBonding.State.NONE)
        r.gate.changed(PrototypeBonding.State.BONDED); r.advance(90000)
        assertEquals(1, r.results.size); assertEquals("Android could not start pairing", r.results.single())
    }
}
