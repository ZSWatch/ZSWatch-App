package dev.zswatch.app.companion

/** Bounded process-local NUS history, captured even without a Flutter engine.
 * Only the companion worker accesses it; payloads never enter the journal.
 */
class CompanionTraffic(private val emit: (Map<String, Any?>) -> Unit) {
    private val history = ArrayDeque<Map<String, Any?>>()
    private var totalBytes = 0
    private var sequence = 0L

    /** Replay retained events strictly after the last delivered sequence. */
    fun replay(after: Long = 0): List<Map<String, Any?>> = history.filter { (it["sequence"] as Long) > after }

    /** Assign an identity and retain valid traffic before notifying any UI listeners. */
    fun publish(direction: String, text: String, bytes: Int, chunks: Int, generation: Long) {
        if (bytes !in 1..65536) return
        while (history.isNotEmpty() && (history.size >= 5000 || totalBytes + bytes > 5 * 1024 * 1024)) {
            totalBytes -= history.removeFirst()["size_bytes"] as Int
        }
        val event = mapOf("version" to 1, "sequence" to ++sequence, "direction" to direction, "data" to text,
            "size_bytes" to bytes, "chunk_count" to chunks,
            "utc_ms" to System.currentTimeMillis(), "generation" to generation)
        history.addLast(event); totalBytes += bytes
        emit(event)
    }

    /** Clearing keeps IDs monotonic and returns the cutoff for queued UI events. */
    fun clear(): Long { history.clear(); totalBytes = 0; return sequence }
}

/** Coalesces worker notifications into one in-flight main-thread batch.
 * `enqueue` must acknowledge on the companion worker after main-thread delivery.
 * New traffic stays in the bounded native history until that acknowledgement.
 */
class CompanionTrafficDelivery(
    private val traffic: CompanionTraffic,
    private val enqueue: (List<Map<String, Any?>>, () -> Unit) -> Unit,
) {
    private var deliveredThrough = 0L
    private var pending = false
    private var closed = false

    /** Drain retained events in order, checking again after each delivery acknowledgement. */
    fun changed() {
        if (closed || pending) return
        val batch = traffic.replay(deliveredThrough)
        if (batch.isEmpty()) return
        pending = true
        enqueue(batch) {
            if (!closed) {
                deliveredThrough = batch.last()["sequence"] as Long
                pending = false
                changed()
            }
        }
    }

    fun close() { closed = true }
}
