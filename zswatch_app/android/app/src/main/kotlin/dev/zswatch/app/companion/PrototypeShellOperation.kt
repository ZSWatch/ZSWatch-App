package dev.zswatch.app.companion

internal data class PrototypeShellReply(val output: String, val returnCode: Long)

/** One transient service-owned Nordic shell operation. No replay after reconnect.
 * All callbacks, resource changes and timers are serialized on the owner worker.
 */
internal class PrototypeShellOperation(
    private val owns: (Long) -> Boolean,
    private val later: (Long, () -> Unit) -> Unit,
    private val enable: (Long, () -> Unit) -> Unit,
    private val execute: (String, (Result<PrototypeShellReply>) -> Unit) -> Unit,
    private val release: (Long) -> Unit,
) {
    private class Request(val generation: Long, val command: String,
                          val done: (Result<PrototypeShellReply>) -> Unit) {
        var started = false
    }
    private var request: Request? = null
    val busy get() = request != null

    fun start(generation: Long, command: String, done: (Result<PrototypeShellReply>) -> Unit) {
        require(command.isNotBlank() && command.length <= 512 && '\u0000' !in command) { "Invalid shell command" }
        check(owns(generation)) { "Current Ready session required" }
        check(request == null) { "Another shell command is running" }
        val entry = Request(generation, command, done)
        request = entry
        // Schedule cleanup before the enable write or SDK can throw/callback.
        try {
            later(30000) { finish(entry, Result.failure(IllegalStateException("Shell command timed out"))) }
            enable(generation) {
                if (current(entry)) later(2000) {
                    if (current(entry) && !entry.started) {
                        entry.started = true
                        try { execute(entry.command) { finish(entry, it) } }
                        catch (error: Exception) { finish(entry, Result.failure(error)) }
                    }
                }
            }
        } catch (error: Exception) { finish(entry, Result.failure(error)) }
    }

    private fun current(entry: Request): Boolean = request === entry && owns(entry.generation)

    private fun finish(entry: Request, outcome: Result<PrototypeShellReply>) {
        if (request !== entry) return
        request = null
        val result = if (owns(entry.generation)) outcome
                     else Result.failure(IllegalStateException("Watch connection changed"))
        val cleanup = runCatching { release(entry.generation) }
        entry.done(if (cleanup.isFailure) Result.failure(cleanup.exceptionOrNull()!!) else result)
    }

    fun close() {
        request?.let { finish(it, Result.failure(IllegalStateException("Watch connection closed"))) }
    }
}
