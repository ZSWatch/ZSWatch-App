package dev.zswatch.app.companion

import org.json.JSONObject

internal data class RelayRequest(val id: String, val url: String, val xpath: String?, val insecure: Boolean)
internal data class RelayResult(val body: String? = null, val error: String? = null)

/** Worker-owned transient requests. No replay after reconnect/death: the watch
 * owns its existing ten-second request timeout and must issue a fresh request.
 * Network completion, timeout and ATT completion can each arrive only once.
 */
internal class PrototypeHttpRelay(
    private val now: () -> Long,
    private val later: (Long, () -> Unit) -> Unit,
    private val execute: (RelayRequest, (RelayResult) -> Unit) -> (() -> Unit),
    private val send: (String, Long, () -> Unit) -> Boolean,
    private val observe: (String, Long, String) -> Unit,
    private val enabled: () -> Boolean = { true },
) {
    private class Pending(val generation: Long, val deadline: Long) {
        var cancel: () -> Unit = {}
        var replying = false
    }
    private val pending = linkedMapOf<String, Pending>()
    private val finished = linkedSetOf<String>()
    val pendingCount get() = pending.size

    fun receive(message: JSONObject, generation: Long): Boolean {
        if (message.optString("t") != "http" || !message.has("url")) return false
        val id = when (val value = message.opt("id")) {
            is String -> value
            is Int, is Long -> value.toString()
            else -> ""
        }
        if (!Regex("[A-Za-z0-9_.:-]{1,64}").matches(id)) {
            observe("rejected", generation, "invalid_id"); return true
        }
        if (pending.containsKey(id) || finished.contains(id)) return true
        if (pending.size >= 4) {
            send(packet(id, RelayResult(error = "Relay busy")), now() + 1000) {}
            observe("rejected", generation, "busy"); return true
        }
        val entry = Pending(generation, now() + 8000)
        pending[id] = entry
        observe("started", generation, "pending")
        later(6500) { complete(id, entry, RelayResult(error = "Request timed out")) }
        later(8000) {
            if (pending[id] === entry) finish(id, entry, "delivery_expired")
        }
        if (!enabled()) {
            complete(id, entry, RelayResult(error = "HTTP relay disabled")); return true
        }
        val url = message.opt("url") as? String
        val xpath = if (message.has("xpath") && !message.isNull("xpath")) message.opt("xpath") as? String else null
        if (url == null || url.length !in 1..2048 ||
            (message.has("xpath") && !message.isNull("xpath") && xpath == null) ||
            (message.has("insecure") && message.opt("insecure") !is Boolean)) {
            complete(id, entry, RelayResult(error = "Invalid request")); return true
        }
        try {
            val cancel = execute(RelayRequest(id, url, xpath, message.optBoolean("insecure", false))) {
                result -> complete(id, entry, result)
            }
            if (pending[id] === entry && !entry.replying) entry.cancel = cancel else cancel()
        } catch (_: Exception) { complete(id, entry, RelayResult(error = "Relay unavailable")) }
        return true
    }

    private fun complete(id: String, entry: Pending, result: RelayResult) {
        if (pending[id] !== entry || entry.replying) return
        entry.cancel(); entry.replying = true
        if (now() >= entry.deadline) { finish(id, entry, "delivery_expired"); return }
        val response = packet(id, result)
        val successful = JSONObject(response.removePrefix("GB(").substringBeforeLast(")")).has("resp")
        val sent = send(response, entry.deadline) {
            if (pending[id] === entry) finish(id, entry, if (successful) "written" else "error_written")
        }
        if (!sent && pending[id] === entry) finish(id, entry, "delivery_unavailable")
    }

    private fun finish(id: String, entry: Pending, outcome: String) {
        if (pending[id] !== entry) return
        pending.remove(id); entry.cancel()
        finished.add(id)
        while (finished.size > 16) finished.remove(finished.first())
        observe("completed", entry.generation, outcome)
    }

    fun reset() {
        val interrupted = pending.values.toList()
        pending.clear(); finished.clear()
        interrupted.forEach { it.cancel(); observe("cancelled", it.generation, "connection_closed") }
    }

    /** Stop network work. Replies already prepared remain whole on the wire. */
    fun disable() {
        pending.toList().forEach { (id, entry) ->
            if (!entry.replying) complete(id, entry, RelayResult(error = "HTTP relay disabled"))
        }
    }

    companion object {
        fun enabled(store: PrototypeStore): Boolean = when (val value = store.control()["http_enabled"]) {
            null -> true // Older journals retain the existing enabled default.
            is Boolean -> value
            else -> false
        }
        fun configure(store: PrototypeStore, enabled: Boolean) {
            if (store.control()["http_enabled"] != enabled)
                store.update("http_configuration", mapOf("http_enabled" to enabled))
        }
        /** Only diagnostic counts survive death; requests themselves are never replayed. */
        fun markProcessInterrupted(store: PrototypeStore, utcMs: Long) {
            val state = store.control()
            if ((state["http_pending_count"] as? Number)?.toInt()?.let { it > 0 } != true) return
            store.update("http_process_interrupted", mapOf("http_pending_count" to 0,
                "last_http" to mapOf("generation" to (state["generation"] as Number).toLong(),
                    "outcome" to "process_interrupted", "utc_ms" to utcMs)))
        }

        /** Firmware's entire GB receive buffer is 2000 bytes, including escapes. */
        fun packet(id: String, result: RelayResult): String {
            val value = JSONObject().put("t", "http").put("id", id)
            if (result.error != null) value.put("err", result.error)
            else if (result.body != null) value.put("resp", result.body)
            else value.put("err", "Empty relay result")
            val packet = "GB($value)\n"
            return if (packet.toByteArray(Charsets.UTF_8).size < 1900) packet
            else "GB(${JSONObject().put("t", "http").put("id", id).put("err", "Response too large")})\n"
        }
    }
}
