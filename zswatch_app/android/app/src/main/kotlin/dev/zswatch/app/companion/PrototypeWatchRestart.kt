package dev.zswatch.app.companion

/** One explicit restart. Preparation may reconnect, but the reset is never replayed. */
internal class PrototypeWatchRestart(
    private val owns: (Long) -> Boolean,
    private val later: (Long, () -> Unit) -> Unit,
    private val prepare: (Long, (Result<Long>) -> Unit) -> Unit,
    private val send: (Long, (Result<Unit>) -> Unit) -> Unit,
    private val release: (Long) -> Unit,
) {
    private class Request(var generation: Long, val done: (Result<Unit>) -> Unit) {
        var sent = false
    }
    private var request: Request? = null
    val busy get() = request != null

    fun start(generation: Long, done: (Result<Unit>) -> Unit) {
        check(owns(generation)) { "Current Ready session required" }
        check(request == null) { "Restart is running" }
        val entry = Request(generation, done)
        request = entry
        try {
            later(30000) { finish(entry, Result.failure(IllegalStateException("Restart response timed out; reset was not retried"))) }
            prepare(generation) { outcome ->
                if (request === entry) outcome.fold({ prepared ->
                    entry.generation = prepared
                    if (!owns(prepared)) finish(entry, Result.failure(IllegalStateException("Watch connection changed")))
                    else if (!entry.sent) {
                        entry.sent = true
                        try { send(prepared) { finish(entry, it) } }
                        catch (error: Exception) { finish(entry, Result.failure(error)) }
                    }
                }, { finish(entry, Result.failure(it)) })
            }
        } catch (error: Exception) { finish(entry, Result.failure(error)) }
    }

    private fun finish(entry: Request, outcome: Result<Unit>) {
        if (request !== entry) return
        request = null
        val result = if (owns(entry.generation)) outcome
            else Result.failure(IllegalStateException("Watch connection changed; reset was not retried"))
        val cleanup = runCatching { release(entry.generation) }
        entry.done(if (cleanup.isFailure) Result.failure(cleanup.exceptionOrNull()!!) else result)
    }

    fun disconnected(stopped: Boolean) {
        // Only SMP discovery is allowed to survive its one service-change reconnect.
        request?.takeIf { stopped || it.sent }?.let {
            finish(it, Result.failure(IllegalStateException("Watch disconnected; reset was not retried")))
        }
    }
}
