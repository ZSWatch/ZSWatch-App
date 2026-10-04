package dev.zswatch.app.companion

internal data class PrototypeSmpSession(val generation: Long, val address: String?,
    val desired: Boolean, val ready: Boolean, val available: Boolean)

/** Preparation never executes a shell command. A service-change reconnect may
 * advance once; Stop, another watch or further generations cancel the request.
 */
internal class PrototypeSmpPreparation(
    private val current: () -> PrototypeSmpSession,
    private val later: (Long, () -> Unit) -> Unit,
    private val enable: () -> Unit,
    private val connect: (Long, (Result<Unit>) -> Unit) -> Unit,
    private val prepared: (Long) -> Unit,
) {
    private class Request(val generation: Long, val address: String,
        val done: (Result<Long>) -> Unit) {
        var connectingGeneration: Long? = null
    }
    private var request: Request? = null
    val busy get() = request != null

    fun start(generation: Long, done: (Result<Long>) -> Unit) {
        val state = current()
        check(state.generation == generation && state.desired && state.ready && state.address != null) {
            "Current Ready session required"
        }
        check(request == null) { "SMP preparation is running" }
        val entry = Request(generation, state.address!!, done)
        request = entry
        try {
            later(15000) { finish(entry, Result.failure(IllegalStateException("SMP preparation timed out"))) }
            if (state.available) poll(entry)
            else {
                enable()
                later(2000) { poll(entry) }
            }
        } catch (error: Exception) { finish(entry, Result.failure(error)) }
    }

    private fun poll(entry: Request) {
        if (request !== entry) return
        try {
            val state = current()
            check(state.desired && state.address == entry.address &&
                state.generation in entry.generation..entry.generation + 1) { "Watch connection changed" }
            if (state.ready && state.available) {
                prepared(state.generation)
                finish(entry, Result.success(state.generation))
            } else {
                if (state.ready && entry.connectingGeneration != state.generation) {
                    entry.connectingGeneration = state.generation
                    connect(state.generation) { result ->
                        val latest = current()
                        if (request === entry && latest.generation == state.generation && latest.ready && result.isFailure)
                            finish(entry, Result.failure(result.exceptionOrNull()!!))
                    }
                }
                later(200) { poll(entry) }
            }
        } catch (error: Exception) { finish(entry, Result.failure(error)) }
    }

    private fun finish(entry: Request, result: Result<Long>) {
        if (request !== entry) return
        request = null
        entry.done(result)
    }

    fun close() {
        request?.let { finish(it, Result.failure(IllegalStateException("SMP preparation cancelled"))) }
    }
}
