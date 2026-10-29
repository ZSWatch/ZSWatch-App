package dev.zswatch.app.companion

/** The native owner retains capture policy across reconnects and a bounded
 * in-memory history across UI detachment. Never journal firmware log payloads.
 * A write receipt is not a firmware acknowledgement: expose it as `written`.
 * All calls run on the companion worker.
 */
class CompanionLiveLogs(
    initiallyRequested: Boolean = false,
    private val persist: (Boolean) -> Unit = {},
    private val emit: (Map<String, Any?>) -> Unit,
) {
    private var revision = 0L
    private var requested = initiallyRequested
    private var written = false
    private var pending = false
    private var inferWatchState = true
    private val history = ArrayDeque<Map<String, Any?>>()

    fun state(): Map<String, Any?> = mapOf("version" to 1, "kind" to "state",
        "requested" to requested, "written" to written, "pending" to pending)

    fun replay(): List<Map<String, Any?>> = listOf(state()) + history.toList()

    fun request(enabled: Boolean, write: (Boolean, () -> Unit) -> Unit) {
        val previous = requested
        persist(enabled)
        val request = ++revision
        requested = enabled; pending = true; inferWatchState = enabled
        emit(state())
        try {
            write(enabled) {
                if (request == revision) {
                    written = enabled; pending = false; emit(state())
                }
            }
        } catch (error: Exception) {
            revision++; requested = previous; pending = false
            persist(previous)
            emit(state())
            throw error
        }
    }

    fun receive(text: String) {
        // A watch can still have logging enabled before we restore our policy.
        // Do not lose those messages, or reinterpret a trailing disable packet.
        if (!pending && inferWatchState && !requested) {
            persist(true); requested = true; written = true; emit(state())
        }
        val event = mapOf("version" to 1, "kind" to "log", "message" to text,
            "utc_ms" to System.currentTimeMillis())
        history.addLast(event)
        while (history.size > 1000) history.removeFirst()
        emit(event)
    }

    fun reset() {
        revision++; written = false; pending = false; inferWatchState = true; emit(state())
    }
}
