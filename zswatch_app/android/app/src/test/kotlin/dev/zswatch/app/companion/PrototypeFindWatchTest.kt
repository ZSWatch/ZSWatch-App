package dev.zswatch.app.companion

import org.junit.Assert.*
import org.junit.Test
import java.util.ArrayDeque

class PrototypeFindWatchTest {
    private data class Write(val generation: Long, val enabled: Boolean, val guard: () -> Boolean, val done: () -> Unit)
    private class Rig {
        var time = 0L
        var admission = true
        var observationFails = false
        val writes = mutableListOf<Write>()
        val timers = mutableListOf<Pair<Long, () -> Unit>>()
        val states = mutableListOf<String>()
        val controller = PrototypeFindWatch({ time }, { delay, action -> timers.add(time + delay to action) },
            { token, enabled, guard, done ->
                if (admission) writes.add(Write(token, enabled, guard, done))
                admission
            }, { _, state ->
                if (observationFails) error("Journal unavailable")
                states.add(state)
            })
        fun ready() { controller.ready(1); writes.clear(); states.clear() }
        fun advance(ms: Long) {
            time += ms
            while (true) {
                val next = timers.firstOrNull { it.first <= time } ?: break
                timers.remove(next); next.second()
            }
        }
    }

    @Test fun sessionResetIsFalseAndExplicitStartRequiresCurrentReady() {
        val rig = Rig()
        assertThrows(IllegalStateException::class.java) { rig.controller.start(1) }
        rig.controller.ready(1, resetRequired = true)
        assertFalse(rig.writes.single().enabled)
        assertTrue(rig.writes.single().guard())
        assertThrows(IllegalStateException::class.java) { rig.controller.start(0) }
    }

    @Test fun stopTimerStartsAfterTrueCompletionAndRejectsOverlappingBursts() {
        val rig = Rig(); rig.ready(); rig.controller.start(1)
        assertTrue(rig.writes.single().enabled)
        assertThrows(IllegalStateException::class.java) { rig.controller.start(1) }
        rig.advance(3000); assertEquals(1, rig.writes.size)
        rig.writes.single().done()
        rig.advance(1999); assertEquals(1, rig.writes.size)
        rig.advance(1); assertFalse(rig.writes.last().enabled)
        assertThrows(IllegalStateException::class.java) { rig.controller.start(1) }
        rig.writes.last().done()
        rig.controller.start(1); assertTrue(rig.writes.last().enabled)
    }

    @Test fun expiredQueuedTrueCannotStartAndCleanupFalseCanRetry() {
        val rig = Rig(); rig.ready(); rig.controller.start(1)
        val start = rig.writes.single()
        rig.admission = false; rig.advance(10000)
        assertFalse(start.guard())
        start.done(); assertEquals(1, rig.writes.size)
        rig.admission = true; rig.advance(250)
        assertFalse(rig.writes.last().enabled)
        rig.writes.last().done(); assertEquals("stop_written", rig.states.last())
    }

    @Test fun stopDisconnectAndNewSessionFenceQueuedCommandsTimersAndCompletions() {
        val rig = Rig(); rig.ready(); rig.controller.start(1)
        val old = rig.writes.single()
        rig.controller.close()
        assertFalse(old.guard()); old.done(); rig.advance(10000)
        assertEquals(1, rig.writes.size)
        rig.controller.ready(2, resetRequired = true)
        val reset = rig.writes.last()
        assertFalse(reset.enabled); assertEquals(2L, reset.generation)
        rig.controller.start(2)
        assertFalse(reset.guard())
        old.done(); assertEquals("accepted", rig.states.last())
    }

    @Test fun failedStartAdmissionLeavesNoBurstAndNeverCreatesATimer() {
        val rig = Rig(); rig.ready(); rig.admission = false
        assertThrows(IllegalStateException::class.java) { rig.controller.start(1) }
        assertTrue(rig.timers.isEmpty())
        rig.admission = true; rig.controller.start(1)
        assertEquals(1, rig.writes.size)
    }

    @Test fun ordinaryReadyDoesNotSendFindFalseAndInterruptUnrelatedVibration() {
        val rig = Rig(); rig.controller.ready(1)
        assertTrue(rig.writes.isEmpty())
    }

    @Test fun failedDiagnosticCannotPreventSchedulingTheStop() {
        val rig = Rig(); rig.ready(); rig.observationFails = true
        assertThrows(IllegalStateException::class.java) { rig.controller.start(1) }
        assertThrows(IllegalStateException::class.java) { rig.writes.single().done() }
        rig.observationFails = false
        rig.advance(2000)
        assertFalse(rig.writes.last().enabled)
        rig.writes.last().done()
        assertEquals("stop_written", rig.states.last())
    }

    @Test fun priorityStopPreservesInflightFragmentAndPrecedesUnstartedWork() {
        val queue = ArrayDeque<NusWrite>()
        val first = NusWrite("0123456789ABCDEFGHIJ".toByteArray(), packetSize = 10)
        val later = NusWrite("LATER".toByteArray())
        val stop = NusWrite("STOP".toByteArray())
        queue.add(first); queue.add(later)
        assertFalse(first.advance())
        enqueueFindStop(queue, true, stop)
        assertSame(first, queue.peekFirst())
        assertEquals("ABCDEFGHIJ", String(queue.peekFirst().packet()))
        assertTrue(first.advance()); queue.removeFirst()
        assertSame(stop, queue.removeFirst())
        assertSame(later, queue.removeFirst())
    }

    @Test fun idlePriorityStopPrecedesPendingStartWithoutDiscardingIt() {
        val queue = ArrayDeque<NusWrite>()
        val pending = NusWrite("START".toByteArray())
        val stop = NusWrite("STOP".toByteArray())
        queue.add(pending); enqueueFindStop(queue, false, stop)
        assertSame(stop, queue.removeFirst()); assertSame(pending, queue.removeFirst())
    }

}
