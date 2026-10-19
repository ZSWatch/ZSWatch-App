package dev.zswatch.app.companion

/** Wait for Android's pairing result before issuing service discovery/CCCD writes. */
internal class PrototypeBonding(
    private val current: () -> Boolean,
    private val later: (Long, () -> Unit) -> Unit,
    private val request: () -> Boolean,
    private val done: (String?) -> Unit,
) {
    enum class State { NONE, BONDING, BONDED }
    private var started = false
    private var finished = false

    fun start(state: State) {
        check(!started) { "Pairing already started" }
        started = true
        if (state == State.BONDED) { finish(null); return }
        // Pairing can include a system confirmation dialog. The ordinary
        // 15-second discovery/subscription deadlines start only after it ends.
        later(90000) { finish("Pairing timed out; enable pairing on the watch and reconnect") }
        if (state == State.NONE && !request()) finish("Android could not start pairing")
    }

    fun changed(state: State) {
        if (!started || finished || !current()) return
        when (state) {
            State.BONDED -> finish(null)
            State.NONE -> finish("Pairing failed; enable pairing on the watch and reconnect")
            State.BONDING -> Unit
        }
    }

    private fun finish(error: String?) {
        if (!started || finished || !current()) return
        finished = true
        done(error)
    }

    fun close() { finished = true }
}
