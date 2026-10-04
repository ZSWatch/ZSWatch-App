package dev.zswatch.app.companion

internal data class PrototypeLogFile(val path: String, val size: Int)
internal data class PrototypeLogReply(val files: List<PrototypeLogFile>, val bytes: ByteArray? = null)

/** Fixed, read-only log paths. Serialized on the owner worker; no replay. */
internal class PrototypeLogFiles(
    private val owns: (Long) -> Boolean,
    private val later: (Long, () -> Unit) -> Unit,
    private val status: (String, (Result<Int?>) -> Unit) -> Unit,
    private val download: (String, Int, (Result<ByteArray>) -> Unit) -> Unit,
    private val release: (Long) -> Unit,
) {
    companion object {
        val paths = (0 until 8).map { "/user/logs/log" + it.toString().padStart(4, '0') }
        const val MAX_BYTES = 4 * 1024 * 1024
    }
    private class Request(val generation: Long, val path: String?, val done: (Result<PrototypeLogReply>) -> Unit) {
        val files = mutableListOf<PrototypeLogFile>()
        var sequence = 0
    }
    private var request: Request? = null
    val busy get() = request != null

    fun start(generation: Long, path: String?, done: (Result<PrototypeLogReply>) -> Unit) {
        require(path == null || path in paths) { "Only known log paths are supported" }
        check(owns(generation)) { "Current Ready session required" }
        check(!busy) { "Log operation is running" }
        val entry = Request(generation, path, done)
        request = entry
        try {
            later(if (path == null) 60000 else 300000) {
                finish(entry, Result.failure(IllegalStateException("Log operation timed out")))
            }
            probe(entry, 0)
        } catch (error: Exception) { finish(entry, Result.failure(error)) }
    }

    private fun current(entry: Request) = request === entry && owns(entry.generation)
    private fun probe(entry: Request, index: Int) {
        if (!current(entry)) { finish(entry, Result.failure(IllegalStateException("Watch connection changed"))); return }
        if (entry.path == null && index == paths.size) {
            finish(entry, Result.success(PrototypeLogReply(entry.files.toList()))); return
        }
        val path = entry.path ?: paths[index]
        val sequence = ++entry.sequence
        try { status(path) { result ->
            if (request !== entry || entry.sequence != sequence) return@status
            // Consume each callback exactly once, including duplicate synchronous callbacks.
            entry.sequence++
            if (!current(entry)) { finish(entry, Result.failure(IllegalStateException("Watch connection changed"))); return@status }
            result.fold({ size ->
                if (size != null && size < 0) { finish(entry, Result.failure(IllegalStateException("Invalid log size"))); return@fold }
                if (entry.path == null) {
                    if (size != null) entry.files.add(PrototypeLogFile(path, size))
                    probe(entry, index + 1)
                } else if (size == null) {
                    finish(entry, Result.failure(IllegalStateException("Log file no longer exists")))
                } else if (size > MAX_BYTES) {
                    finish(entry, Result.failure(IllegalStateException("Log file exceeds download limit")))
                } else if (size == 0) {
                    finish(entry, Result.success(PrototypeLogReply(listOf(PrototypeLogFile(path, 0)), byteArrayOf())))
                } else {
                    try { download(path, size) { bytes ->
                        if (request === entry) finish(entry, bytes.mapCatching {
                            check(it.size == size) { "Log size changed during download" }
                            PrototypeLogReply(listOf(PrototypeLogFile(path, size)), it)
                        })
                    } } catch (error: Exception) { finish(entry, Result.failure(error)) }
                }
            }, { finish(entry, Result.failure(it)) })
        } } catch (error: Exception) { finish(entry, Result.failure(error)) }
    }
    private fun finish(entry: Request, outcome: Result<PrototypeLogReply>) {
        if (request !== entry) return
        request = null
        val result = if (owns(entry.generation)) outcome else Result.failure(IllegalStateException("Watch connection changed"))
        val cleanup = runCatching { release(entry.generation) }
        entry.done(if (cleanup.isFailure) Result.failure(cleanup.exceptionOrNull()!!) else result)
    }
    fun close() { request?.let { finish(it, Result.failure(IllegalStateException("Watch connection closed"))) } }
}
