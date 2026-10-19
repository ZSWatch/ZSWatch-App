package dev.zswatch.app.companion

import java.util.UUID

internal data class PrototypeWatchfaceState(val id: String, val generation: Long, val action: String,
    val phase: String, val current: Int, val total: Int, val name: String,
    val error: String? = null, val applicationUncertain: Boolean = false)

/** A native worker owns upload -> full readback verification -> existing NUS apply.
 * Accepted work never replays after disconnect or process loss. No image is journaled.
 */
internal class PrototypeWatchface(
    private val owns: (Long) -> Boolean,
    private val now: () -> Long,
    private val later: (Long, () -> Unit) -> Unit,
    private val upload: (ByteArray, (Int, Int) -> Unit, (Result<Unit>) -> Unit) -> Unit,
    private val verify: (ByteArray, () -> Boolean, (Result<Unit>) -> Unit) -> Unit,
    private val send: (Long, String, () -> Boolean) -> Boolean,
    private val observe: (PrototypeWatchfaceState) -> Unit,
    private val release: (Long) -> Unit,
) {
    companion object {
        const val IMAGE_BYTES = 12 + 240 * 240 * 2
        val activePhases = setOf("uploading", "verifying", "applying", "resetting")
        fun validateImage(bytes: ByteArray) {
            require(bytes.size == IMAGE_BYTES) { "Expected 240x240 RGB565 image" }
            val header = byteArrayOf(0x19, 0x12, 0, 0, 0xf0.toByte(), 0, 0xf0.toByte(), 0, 0xe0.toByte(), 1, 0, 0)
            require(bytes.copyOfRange(0, 12).contentEquals(header)) { "Unsupported image header" }
        }
        fun markInterrupted(store: PrototypeStore) {
            val previous = store.control()["watchface_operation"] as? Map<*, *> ?: return
            if (previous["phase"] !in activePhases) return
            val state = previous.entries.associate { it.key as String to it.value }.toMutableMap()
            state["phase"] = "failed"; state["error"] = "interrupted"
            state["application_uncertain"] = previous["phase"] in setOf("applying", "resetting")
            store.update("watchface_interrupted", mapOf("watchface_operation" to state))
        }
    }
    private class Request(var state: PrototypeWatchfaceState, val bytes: ByteArray?) {
        var startedWriting = false
        var lastProgressAt = Long.MIN_VALUE
        var lastPublishedCount = 0
    }
    private var request: Request? = null
    // Existing firmware has no result ID. An uncertain action cannot be repeated
    // on this generation, so its late response cannot acknowledge a new operation.
    private val uncertain = mutableMapOf<String, Long>()
    val busy get() = request != null

    fun startUpload(generation: Long, bytes: ByteArray, name: String): String {
        validateImage(bytes)
        require(name.isNotBlank() && name.length <= 64 && name.none { it.isISOControl() }) { "Invalid image name" }
        return start(generation, "apply", bytes.copyOf(), name)
    }
    fun reset(generation: Long): String = start(generation, "reset", null, "Default")

    fun requireStart(generation: Long, action: String) {
        check(owns(generation)) { "Current Ready session required" }
        check(!busy) { "Watchface operation is running" }
        check(uncertain[action] != generation) { "Previous result is unknown; reconnect before retrying" }
    }
    private fun start(generation: Long, action: String, bytes: ByteArray?, name: String): String {
        requireStart(generation, action)
        val entry = Request(PrototypeWatchfaceState(UUID.randomUUID().toString(), generation, action,
            if (bytes == null) "resetting" else "uploading", 0, bytes?.size ?: 0, name), bytes)
        request = entry
        try {
            later(if (bytes == null) 15000 else 300000) { fail(entry, "deadline") }
            observe(entry.state) // Commit acceptance before any SDK/watch mutation.
            if (bytes == null) sendAction(entry) else upload(bytes,
                { current, total -> progress(entry, current, total) },
                { result -> if (current(entry) && entry.state.phase == "uploading") {
                    result.fold({ verify(entry) }, { fail(entry, "upload_failed") })
                } })
        } catch (error: Exception) { fail(entry, "start_failed") }
        return entry.state.id
    }
    private fun current(entry: Request) = request === entry && owns(entry.state.generation)
    private fun progress(entry: Request, count: Int, total: Int) {
        if (!current(entry) || entry.state.phase != "uploading") return
        if (total != entry.state.total || count < entry.state.current || count > total || count < 0) {
            fail(entry, "invalid_progress"); return
        }
        entry.state = entry.state.copy(current = count)
        val time = now()
        if (count == total || entry.lastProgressAt == Long.MIN_VALUE || time - entry.lastProgressAt >= 500 || count - entry.lastPublishedCount >= total / 20) {
            entry.lastProgressAt = time; entry.lastPublishedCount = count; observe(entry.state)
        }
    }
    private fun verify(entry: Request) {
        entry.state = entry.state.copy(phase = "verifying", current = entry.state.total)
        try {
            observe(entry.state)
            verify(entry.bytes!!, { current(entry) && entry.state.phase == "verifying" }) { result ->
                if (current(entry) && entry.state.phase == "verifying")
                    result.fold({ sendAction(entry) }, { fail(entry, "verify_failed") })
            }
        } catch (error: Exception) { fail(entry, "verify_failed") }
    }
    private fun sendAction(entry: Request) {
        if (!current(entry)) return
        entry.state = entry.state.copy(phase = if (entry.state.action == "apply") "applying" else "resetting")
        try {
            observe(entry.state)
            later(10000) { if (request === entry && entry.state.phase in setOf("applying", "resetting")) fail(entry, "result_timeout") }
            val queued = send(entry.state.generation, entry.state.action) {
                if (current(entry)) { entry.startedWriting = true; true } else false
            }
            if (!queued) fail(entry, "write_unavailable")
        } catch (error: Exception) { fail(entry, "write_unavailable") }
    }
    fun receive(generation: Long, action: String, ok: Boolean) {
        val entry = request ?: return
        if (!current(entry) || entry.state.generation != generation || !entry.startedWriting ||
            action != entry.state.action + "_result" || entry.state.phase !in setOf("applying", "resetting")) return
        finish(entry, if (ok) null else "watch_rejected")
    }
    private fun fail(entry: Request, error: String) = finish(entry, error)
    private fun finish(entry: Request, error: String?) {
        if (request !== entry) return
        request = null
        val reason = if (owns(entry.state.generation)) error else "connection_closed"
        val unknown = reason != null && reason != "watch_rejected" && entry.startedWriting
        if (unknown) uncertain[entry.state.action] = entry.state.generation
        entry.state = entry.state.copy(phase = if (reason == null) "completed" else "failed", error = reason, applicationUncertain = unknown)
        // Always release a transfer even if journal publication fails.
        try { observe(entry.state) } finally { release(entry.state.generation) }
    }
    fun close() { request?.let { fail(it, "connection_closed") } }
}
