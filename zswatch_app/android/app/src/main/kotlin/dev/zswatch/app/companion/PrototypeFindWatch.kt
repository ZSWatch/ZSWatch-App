package dev.zswatch.app.companion

import java.util.ArrayDeque

/** Native worker owns the burst; UI disposal does not cancel its stop timer. */
internal class PrototypeFindWatch(
    private val now: () -> Long,
    private val later: (Long, () -> Unit) -> Unit,
    private val send: (Long, Boolean, () -> Boolean, () -> Unit) -> Boolean,
    private val observe: (Long, String) -> Unit,
) {
    private class Burst(val generation: Long, val deadline: Long) {
        var stopping = false
    }
    private var generation: Long? = null
    private var burst: Burst? = null

    fun ready(token: Long, resetRequired: Boolean = false) {
        close(); generation = token
        // The previous process/session may have lost its final false packet.
        if (resetRequired) {
            send(token, false, { generation == token && burst == null }, {
                if (generation == token) observe(token, "reset_written")
            })
        }
    }

    fun start(token: Long) {
        check(generation == token) { "Current Ready session required" }
        check(burst == null) { "Watch finding already in progress" }
        val next = Burst(token, now() + 10000)
        burst = next
        val accepted = send(token, true, {
            burst === next && !next.stopping && now() < next.deadline
        }, {
            if (burst === next && !next.stopping) {
                observe(token, "start_written")
                later(2000) { stop(next) }
            }
        })
        if (!accepted) { burst = null; error("Watch command queue unavailable") }
        observe(token, "accepted")
        // If start sits in the queue too long, cancel it and clean up any partial write.
        later(10000) { if (burst === next) stop(next) }
    }

    private fun stop(expected: Burst) {
        if (burst !== expected || expected.stopping) return
        expected.stopping = true
        sendStop(expected)
    }

    private fun sendStop(expected: Burst) {
        if (burst !== expected) return
        val accepted = send(expected.generation, false, { burst === expected }, {
            if (burst === expected) {
                burst = null
                observe(expected.generation, "stop_written")
            }
        })
        if (!accepted && burst === expected) later(250) { sendStop(expected) }
    }

    /** A closed BLE link cannot deliver false; firmware needs its own failsafe. */
    fun close() { burst = null; generation = null }
}


/** Preserve ATT fragmentation while giving one stop precedence over pending work. */
internal fun enqueueFindStop(queue: ArrayDeque<NusWrite>, writing: Boolean, stop: NusWrite) {
    val current = if (writing) queue.pollFirst() else null
    queue.addFirst(stop)
    if (current != null) queue.addFirst(current)
}
