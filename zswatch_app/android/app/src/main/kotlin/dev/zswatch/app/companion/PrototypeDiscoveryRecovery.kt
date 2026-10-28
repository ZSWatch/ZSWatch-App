package dev.zswatch.app.companion

/** Keep the client alive while Android invalidates its stale service database. */
internal class PrototypeDiscoveryRecovery<C>(
    private val current: (Long, C) -> Boolean,
    private val refresh: (C) -> Boolean,
    private val later: (Long, () -> Unit) -> Unit,
    private val retry: (Long, C) -> Unit,
    private val failed: (Long, String) -> Unit,
) {
    private var attempts = 0
    private var epoch = 0
    private var pending = false

    fun reset() { attempts = 0; pending = false; epoch++ }

    fun timedOut(session: Long, client: C) {
        if (!current(session, client) || pending) return
        if (attempts >= 2) {
            failed(session, "Service discovery timed out after cache recovery.")
            return
        }
        attempts++
        val refreshed = runCatching { refresh(client) }.getOrDefault(false)
        if (!refreshed) {
            failed(session, "Service discovery timed out; Android could not refresh the service cache.")
            return
        }
        pending = true
        val expected = epoch
        later(1000) {
            if (epoch != expected) return@later
            pending = false
            if (current(session, client)) retry(session, client)
        }
    }
}
