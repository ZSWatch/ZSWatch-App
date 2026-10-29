package dev.zswatch.app.companion

/** Bounded process-local NUS history, captured even without a Flutter engine.
 * Only the companion worker accesses it; payloads never enter the journal.
 */
class CompanionTraffic(private val emit: (Map<String, Any?>) -> Unit) {
    private val history = ArrayDeque<Map<String, Any?>>()
    private var totalBytes = 0

    fun replay(): List<Map<String, Any?>> = history.toList()

    fun publish(direction: String, text: String, bytes: Int, chunks: Int, generation: Long) {
        if (bytes !in 1..65536) return
        while (history.isNotEmpty() && (history.size >= 5000 || totalBytes + bytes > 5 * 1024 * 1024)) {
            totalBytes -= history.removeFirst()["size_bytes"] as Int
        }
        val event = mapOf("version" to 1, "direction" to direction, "data" to text,
            "size_bytes" to bytes, "chunk_count" to chunks,
            "utc_ms" to System.currentTimeMillis(), "generation" to generation)
        history.addLast(event); totalBytes += bytes
        emit(event)
    }

    fun clear() { history.clear(); totalBytes = 0 }
}
