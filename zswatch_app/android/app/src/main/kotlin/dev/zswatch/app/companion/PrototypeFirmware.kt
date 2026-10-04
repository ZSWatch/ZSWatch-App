package dev.zswatch.app.companion

import java.util.UUID

internal class FirmwareVerificationUnavailable(val missingIndices: List<Int>) : IllegalStateException("Selected image state is unavailable")

internal data class FirmwareTarget(val index: Int, val bytes: Int, val hash: String)
internal data class PrototypeFirmwareState(val id: String, val address: String, val generation: Long,
    val phase: String, val targets: List<FirmwareTarget>, val current: Int = 0, val total: Int = 0,
    val error: String? = null, val resultUnknown: Boolean = false, val cancelRequested: Boolean = false)

/** A service lifetime spans Nordic's reset and fresh active-image verification.
 * No accepted firmware is automatically replayed, and SDK completion is not boot verification.
 */
internal class PrototypeFirmware(
    private val owns: (PrototypeFirmwareState) -> Boolean,
    private val now: () -> Long,
    private val later: (Long, () -> Unit) -> Unit,
    private val launch: (PrototypeFirmwareState) -> Unit,
    private val reconnect: (PrototypeFirmwareState) -> Unit,
    private val verify: (PrototypeFirmwareState, () -> Boolean, (Result<Unit>) -> Unit) -> Unit,
    private val cancel: () -> Unit,
    private val observe: (PrototypeFirmwareState) -> Unit,
    private val release: (PrototypeFirmwareState) -> Unit,
) {
    companion object {
        const val MAX_IMAGE_BYTES = 8 * 1024 * 1024
        val activePhases = setOf("validating", "uploading", "applying", "rebooting", "reconnecting", "verifying")
        fun validate(targets: List<FirmwareTarget>) {
            require(targets.isNotEmpty() && targets.size <= 3) { "One to three firmware images required" }
            require(targets.map { it.index }.distinct().size == targets.size) { "Duplicate image index" }
            require(targets.all { it.index in 0..2 && it.bytes in 1..MAX_IMAGE_BYTES && Regex("[0-9a-f]{64}").matches(it.hash) }) { "Unsupported firmware target" }
        }
        fun markInterrupted(store: PrototypeStore) {
            val old = store.control()["firmware_operation"] as? Map<*, *> ?: return
            if (old["phase"] !in activePhases) return
            val fields = old.entries.associate { it.key as String to it.value }.toMutableMap()
            fields["phase"] = "failed"; fields["error"] = "interrupted"; fields["result_unknown"] = true
            store.update("firmware_interrupted", mapOf("firmware_operation" to fields))
        }
    }
    private var request: PrototypeFirmwareState? = null
    private var lastProgressAt = Long.MIN_VALUE
    private var lastPublished = 0
    val state get() = request
    val busy get() = request != null

    fun start(address: String, generation: Long, targets: List<FirmwareTarget>): String {
        validate(targets)
        check(!busy) { "Firmware operation is running" }
        val entry = PrototypeFirmwareState(UUID.randomUUID().toString(), address, generation, "validating", targets.toList())
        check(owns(entry)) { "Exclusive firmware owner required" }
        request = entry; lastProgressAt = Long.MIN_VALUE; lastPublished = 0
        try {
            observe(entry) // Journal before Nordic sends anything.
            later(20 * 60 * 1000L) { fail(entry.id, "deadline") }
            launch(entry)
        } catch (error: Exception) { fail(entry.id, "start_failed") }
        return entry.id
    }
    private fun current(id: String): PrototypeFirmwareState? = request?.takeIf { it.id == id && owns(it) }
    fun sdkPhase(id: String, phase: String) {
        val old = current(id) ?: return
        if (old.phase in setOf("reconnecting", "verifying")) return
        require(phase in setOf("validating", "uploading", "applying", "rebooting"))
        publish(old.copy(phase = phase))
    }
    fun progress(id: String, current: Int, total: Int) {
        val old = current(id) ?: return
        if (old.phase != "uploading") return
        if (current < 0 || total <= 0 || current > total || total > MAX_IMAGE_BYTES) { fail(id, "invalid_progress"); return }
        val changedImage = total != old.total || current < old.current
        val next = old.copy(current = current, total = total)
        request = next
        val time = now()
        if (changedImage || current == total || lastProgressAt == Long.MIN_VALUE || time - lastProgressAt >= 500 || current - lastPublished >= maxOf(1, total / 20)) {
            lastProgressAt = time; lastPublished = current; observe(next)
        }
    }
    fun sdkCompleted(id: String) {
        val old = current(id) ?: return
        if (old.phase in setOf("reconnecting", "verifying")) return
        val next = old.copy(phase = "reconnecting")
        try {
            publish(next)
            later(90000) { if (request?.id == id && request?.phase in setOf("reconnecting", "verifying")) fail(id, "boot_check_timeout") }
            reconnect(next)
        } catch (error: Exception) { fail(id, "reconnect_failed") }
    }
    fun ready(address: String) {
        val old = request ?: return
        if (old.phase != "reconnecting" || old.address != address || !owns(old)) return
        try {
            publish(old.copy(phase = "verifying"))
            verify(request!!, { current(old.id)?.phase == "verifying" }) { result ->
                if (current(old.id)?.phase == "verifying") result.fold({ finish(old.id, "completed", null) }, { fail(old.id, if (it is FirmwareVerificationUnavailable) "boot_check_unavailable" else "boot_check_failed") })
            }
        } catch (error: Exception) { fail(old.id, "boot_check_failed") }
    }
    fun requestCancel(id: String) {
        val old = current(id) ?: error("Current firmware operation required")
        check(old.phase == "uploading") { "Firmware cannot be cancelled in this phase" }
        if (old.cancelRequested) return
        publish(old.copy(cancelRequested = true))
        try { cancel() } catch (error: Exception) { fail(id, "cancel_failed") }
        // Only Nordic's terminal callback establishes cancellation.
    }
    fun sdkCancelled(id: String) = finish(id, "cancelled", "cancelled")
    fun fail(id: String, error: String) = finish(id, "failed", error)
    private fun publish(state: PrototypeFirmwareState) { request = state; observe(state) }
    private fun finish(id: String, phase: String, error: String?) {
        val old = request?.takeIf { it.id == id } ?: return
        request = null
        val next = old.copy(phase = phase, error = error, resultUnknown = phase != "completed")
        try { observe(next) } finally { release(next) }
    }
    fun close() { request?.let { fail(it.id, "interrupted") } }
}
