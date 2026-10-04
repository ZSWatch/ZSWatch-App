package dev.zswatch.app.companion

interface PrototypeTransport {
    fun connect(address: String, generation: Long)
    fun close()
}

/** Service owns this controller; UI attachment never acquires/releases transport. */
class PrototypeRuntime(val store: PrototypeStore, private val transport: PrototypeTransport,
                       private val fenced: (String) -> Unit = {}) {
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

    /** User chose this watch in an explicit picker; a newer Stop wins. */
    fun startDiscovered(address: String, expectedGeneration: Long): Boolean {
        if (!PrototypeDiscovery.canSelect(store.control(), active, expectedGeneration)) return false
        start(address)
        return true
    }

    /** A delayed OS presence event cannot undo Stop or switch the selected watch. */
    fun restoreForPresence(address: String, expectedGeneration: Long): Boolean {
        return restoreForEvent(address, expectedGeneration)
    }

    /** Boot/update events are fenced again when the service handles them. */
    fun restoreForSystem(address: String, expectedGeneration: Long): Boolean {
        return restoreForEvent(address, expectedGeneration)
    }

    private fun restoreForEvent(address: String, expectedGeneration: Long): Boolean {
        val state = store.control()
        if (state["desired_running"] != true || state["address"] != address ||
            generation != expectedGeneration) return false
        if (active) {
            if (state["phase"] in listOf("error", "disconnected")) reconnect()
            return true
        }
        return restore()
    }

    fun owns(token: Long): Boolean = active && token == generation

    /** Fence pending callbacks without changing the user's running intent. */
    fun suspendTransport(reason: String) {
        if (!active) return
        store.update("transport_suspended", mapOf("generation" to generation + 1,
            "phase" to "disconnected", "last_error" to reason))
        try { fenced("suspend") } finally { transport.close() }
    }

    fun recoverForSystem(): Boolean {
        if (store.control()["desired_running"] != true) return false
        if (!active) return restore()
        if (store.control()["phase"] in listOf("disconnected", "error")) reconnect()
        return true
    }

    fun reconnect() {
        reconnect(false)
    }

    private fun reconnect(preserveUpgrade: Boolean) {
        if (!active) return
        val address = store.control()["address"] as String
        active = false
        try { if (!preserveUpgrade) fenced("reconnect") } finally { transport.close() }
        start(address, restoring = true)
    }

    /** Nordic takes over the prepared SDK connection; old NUS callbacks lose their generation. */
    fun beginFirmware(expectedGeneration: Long): Long {
        check(owns(expectedGeneration) && store.control()["phase"] == "ready") { "Current Ready session required" }
        val next = generation + 1
        store.update("firmware_owner_acquired", mapOf("generation" to next, "phase" to "upgrading", "last_error" to null))
        transport.close()
        return next
    }

    /** The SDK has released its connection. Preserve the operation while acquiring fresh NUS. */
    fun resumeAfterFirmware(upgradeGeneration: Long) {
        if (owns(upgradeGeneration) && store.control()["phase"] == "upgrading") reconnect(true)
    }

    fun phase(token: Long, phase: String, error: String? = null): Boolean {
        if (!owns(token)) return false
        require(phase in setOf("connecting", "discovering", "subscribing", "ready", "disconnected", "error"))
        val fields = mutableMapOf<String, Any?>("phase" to phase, "last_error" to error)
        // Durable metadata projection may happen after Flutter has detached or Stop.
        // This receipt records readiness, not pairing or application delivery.
        val previousReady = store.control()["last_ready"] as? Map<*, *>
        if (phase == "ready" && ((previousReady?.get("generation") as? Number)?.toLong() != token ||
                previousReady?.get("address") != store.control()["address"])) {
            fields["last_ready"] = mapOf("address" to store.control()["address"],
                "generation" to token, "utc_ms" to System.currentTimeMillis())
        }
        store.update("connection_state", fields)
        return true
    }

    fun stop() {
        store.update("runtime_stopped", mapOf("desired_running" to false,
            "generation" to generation + 1, "phase" to "stopped", "notifications" to emptyMap<String, Any>()))
        active = false
        try { fenced("stop") } finally { transport.close() }
    }

    /** Framework destruction releases handles but preserves the saved user intent. */
    fun destroy() { active = false; try { fenced("destroy") } finally { transport.close() } }
}
