package dev.zswatch.app.companion

/** A system wakeup restores saved intent; it cannot create new connection intent. */
internal object PrototypeSystemRecovery {
    data class Request(val address: String, val generation: Long)

    fun request(state: Map<String, Any?>, action: String?, connectAllowed: Boolean): Request? {
        if (action !in setOf("android.intent.action.BOOT_COMPLETED", "android.intent.action.MY_PACKAGE_REPLACED") ||
            !connectAllowed || state["desired_running"] != true) return null
        val address = state["address"] as? String ?: return null
        if (!Regex("[0-9A-F]{2}(:[0-9A-F]{2}){5}").matches(address)) return null
        val generation = when (val value = state["generation"]) {
            is Int -> value.toLong()
            is Long -> value
            else -> return null
        }
        if (generation < 0) return null
        return Request(address, generation)
    }
}
