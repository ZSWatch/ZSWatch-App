package dev.zswatch.app.companion

/** Serialized on the native worker; injected OS boundary makes ordering testable. */
class PrototypeForget(
    private val store: PrototypeStore,
    private val owner: PrototypeRuntime?,
    private val stopObserving: (String) -> Unit,
    private val disassociate: (String) -> Boolean,
) {
    fun forget(requestedAddress: String): Map<String, Any?> {
        val address = normalize(requestedAddress) ?: error("Valid Android BLE address required")
        val before = store.control()
        val selected = before["address"] == address
        if (selected) {
            if (owner != null) owner.stop()
            else store.update("runtime_stopped", mapOf(
                "desired_running" to false,
                "generation" to (before["generation"] as Number).toLong() + 1,
                "phase" to "stopped", "notifications" to emptyMap<String, Any>(),
            ))
            check(canFinalize(store.control(), address, owner?.active == true)) {
                "Companion owner did not stop before Forget"
            }
        } else if (before["desired_running"] == false && owner?.active != true) {
            // Fence a pending system picker, including a picker for this old saved watch.
            store.update("forget_selection_fenced", mapOf(
                "generation" to (before["generation"] as Number).toLong() + 1,
            ))
        }
        stopObserving(address)
        check(disassociate(address)) { "Could not remove the OS companion association" }
        val generation = (store.control()["generation"] as Number).toLong()
        val forgotten = (store.control()["forgotten_watches"] as? Map<*, *>)
            ?.entries?.associate { it.key as String to it.value }?.toMutableMap() ?: mutableMapOf()
        forgotten[address] = generation
        val fields = mutableMapOf<String, Any?>("forgotten_watches" to forgotten)
        if (selected) fields.putAll(mapOf(
            "address" to "", "last_ready" to null, "watch_info" to null,
        ))
        store.update("watch_forgotten", fields, mapOf("address" to address))
        return mapOf("address" to address, "generation" to generation, "association_removed" to true)
    }

    companion object {
        private val addressPattern = Regex("[0-9A-F]{2}(:[0-9A-F]{2}){5}")

        fun normalize(address: String): String? {
            val normalized = address.trim().uppercase()
            return normalized.takeIf { addressPattern.matches(it) }
        }

        /** The selected owner must be stopped before its association is removed. */
        fun canFinalize(state: Map<String, Any?>, requestedAddress: String, active: Boolean): Boolean {
            val address = normalize(requestedAddress) ?: return false
            return !active && state["address"] == address &&
                state["desired_running"] == false && state["phase"] == "stopped"
        }
    }
}
