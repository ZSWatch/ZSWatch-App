package dev.zswatch.app.companion

interface PrototypeTransport {
    fun connect(address: String, generation: Long)
    fun close()
}

/** Service owns this controller; UI attachment never acquires/releases transport. */
class PrototypeRuntime(val store: PrototypeStore, private val transport: PrototypeTransport) {
    var active = false
        private set
    val generation: Long get() = (store.control()["generation"] as Number).toLong()

    fun start(address: String, restoring: Boolean = false) {
        require(Regex("[0-9A-F]{2}(:[0-9A-F]{2}){5}").matches(address)) { "Expected Android BLE MAC address" }
        if (active) {
            check(store.control()["address"] == address) { "Stop before changing watch" }
            return
        }
        val next = generation + 1
        store.update(if (restoring) "runtime_restored" else "runtime_started", mapOf(
            "generation" to next, "desired_running" to true, "address" to address,
            "phase" to "connecting", "last_error" to null))
        active = true
        try { transport.connect(address, next) }
        catch (error: Exception) { phase(next, "error", error.javaClass.simpleName); transport.close() }
    }

    fun restore(): Boolean {
        val state = store.control()
        if (state["desired_running"] != true) return false
        start(state["address"] as String, restoring = true)
        return true
    }

    fun owns(token: Long): Boolean = active && token == generation

    fun reconnect() {
        if (!active) return
        val address = store.control()["address"] as String
        active = false
        transport.close()
        start(address, restoring = true)
    }

    fun phase(token: Long, phase: String, error: String? = null): Boolean {
        if (!owns(token)) return false
        require(phase in setOf("connecting", "discovering", "subscribing", "ready", "disconnected", "error"))
        store.update("connection_state", mapOf("phase" to phase, "last_error" to error))
        return true
    }

    fun stop() {
        store.update("runtime_stopped", mapOf("desired_running" to false,
            "generation" to generation + 1, "phase" to "stopped"))
        active = false
        transport.close()
    }

    /** Framework destruction releases handles but preserves the saved user intent. */
    fun destroy() { active = false; transport.close() }
}
