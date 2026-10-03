package dev.zswatch.app.companion

/** A picker result is valid only for the stopped intent that opened it. */
internal object PrototypeDiscovery {
    // Android's callback may precede RESULT_CANCELED. Keep its explicit
    // cancellation reasons quiet without treating discovery failures as consent.
    fun failureCode(reason: String?): String = if (reason in setOf("canceled", "user_rejected"))
        "CANCELLED" else "ASSOCIATION_FAILED"

    fun awaitPickerResult(api: Int, pickerShown: Boolean, code: String): Boolean =
        api < 33 && pickerShown && code != "CANCELLED"

    fun canSelect(state: Map<String, Any?>, active: Boolean, generation: Long): Boolean {
        val current = when (val value = state["generation"]) {
            is Int -> value.toLong()
            is Long -> value
            else -> return false
        }
        return generation >= 0 && !active && state["desired_running"] == false && current == generation
    }
}
