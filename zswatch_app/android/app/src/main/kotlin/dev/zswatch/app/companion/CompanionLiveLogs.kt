package dev.zswatch.app.companion

/** Ephemeral diagnostics only: never persist firmware log payloads in the job
 * journal. All calls run on the companion worker. A write receipt is not a
 * firmware acknowledgement, so expose it as `written` rather than `confirmed`.
 */
class CompanionLiveLogs(private val emit: (Map<String, Any?>) -> Unit) {
    private var revision = 0L
    private var requested = false
    private var written = false
    private var pending = false

    fun state(): Map<String, Any?> = mapOf("version" to 1, "kind" to "state",
        "requested" to requested, "written" to written, "pending" to pending)

    fun request(enabled: Boolean, write: (Boolean, () -> Unit) -> Unit) {
        val request = ++revision
        requested = enabled; pending = true
        emit(state())
        try {
            write(enabled) {
                if (request == revision) {
                    written = enabled; pending = false; emit(state())
                }
            }
        } catch (error: Exception) {
            reset()
            throw error
        }
    }

    fun receive(text: String) {
        if (requested) emit(mapOf("version" to 1, "kind" to "log", "message" to text))
    }

    fun reset() {
        revision++; requested = false; written = false; pending = false; emit(state())
    }
}
