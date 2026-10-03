package dev.zswatch.app.companion

import org.json.JSONObject

/** Bounded desired notification state. Write completion is not a watch ACK. */
class PrototypeNotifications(private val store: PrototypeStore) {
    data class Delivery(val key: String, val id: Long, val revision: Long, val packet: String, val replace: Boolean = false)

    @Suppress("UNCHECKED_CAST")
    private fun entries() = JSONObject(store.control()["notifications"] as? Map<String, Any?> ?: emptyMap<String, Any?>())

    fun configure(enabled: Boolean, packages: List<String>) {
        require(packages.size <= 64 && packages.all { Regex("[A-Za-z0-9_]+(\\.[A-Za-z0-9_]+)+").matches(it) })
        val notices = entries()
        notices.keys().asSequence().toList().forEach { key ->
            val item = notices.getJSONObject(key)
            if (!enabled || item.getString("package") !in packages) removeItem(item)
        }
        store.update("notification_configuration", mapOf("notifications_enabled" to enabled,
            "notification_packages" to packages.distinct(), "notifications" to notices))
    }

    fun post(data: Map<String, Any?>, now: Long): Boolean {
        val state = store.control()
        if (state["desired_running"] != true || state["notifications_enabled"] != true) return false
        val source = data["packageName"] as? String ?: return false
        if (source !in (state["notification_packages"] as? List<*> ?: emptyList<Any>())) return false
        val key = data["key"] as? String ?: return false
        if (key.length > 512) return false
        // Listener reconnect replays active Android notifications. Their original
        // post time must not grant stale content a fresh retention window.
        val postedAt = minOf(now, (data["postedAt"] as? Number)?.toLong() ?: now)
        if (postedAt + RETENTION_MS <= now) return false
        val notices = entries()
        val old = notices.optJSONObject(key)
        if (old == null && notices.length() >= CAPACITY) {
            store.update("notification_capacity_reached")
            return false
        }
        val id = old?.getLong("id") ?: ((state["notification_next_id"] as? Number)?.toLong() ?: 1000000L)
        check(id in 1 until Int.MAX_VALUE.toLong()) { "Notification identity exhausted" }
        val packet = JSONObject().put("t", "notify").put("id", id)
            .put("src", bounded(data["appName"] as? String ?: source, 80))
            .put("title", bounded(data["title"] as? String ?: "", 160))
            .put("body", bounded(data["body"] as? String ?: "", 450))
        (data["sender"] as? String)?.let { packet.put("sender", bounded(it, 160)) }
        val wire = "GB($packet)"
        require(wire.toByteArray(Charsets.UTF_8).size <= 2000)
        if (old != null && !old.optBoolean("removed") && old.getString("packet") == wire) return false
        notices.put(key, JSONObject().put("id", id).put("package", source).put("packet", wire)
            .put("revision", (old?.optLong("revision") ?: 0) + 1).put("removed", false)
            .put("expires_ms", postedAt + RETENTION_MS))
        store.update("notification_queued", mapOf("notifications" to notices,
            "notification_next_id" to if (old == null) id + 1 else state["notification_next_id"]),
            mapOf("notification_id" to id))
        return true
    }

    fun remove(key: String): Boolean {
        val notices = entries()
        val item = notices.optJSONObject(key) ?: return false
        if (item.optBoolean("removed")) return false
        removeItem(item)
        store.update("notification_removed", mapOf("notifications" to notices), mapOf("notification_id" to item.getLong("id")))
        return true
    }

    /** The listener's active set is authoritative after its process is recreated. */
    fun reconcile(activeKeys: Set<String>) {
        val notices = entries()
        var changed = false
        notices.keys().asSequence().toList().forEach { key ->
            val item = notices.getJSONObject(key)
            if (key !in activeKeys && !item.optBoolean("removed")) { removeItem(item); changed = true }
        }
        if (changed) store.update("notifications_reconciled", mapOf("notifications" to notices))
    }

    /** Purge private text even while BLE is disconnected. Keep only removal IDs. */
    fun expire(now: Long) {
        val notices = entries()
        var expired = false
        notices.keys().asSequence().toList().forEach { key ->
            val item = notices.getJSONObject(key)
            if (!item.optBoolean("removed") && item.getLong("expires_ms") <= now) {
                removeItem(item); expired = true
            }
        }
        if (expired) store.update("notifications_expired", mapOf("notifications" to notices))
    }

    fun next(generation: Long, now: Long): Delivery? {
        expire(now)
        val notices = entries()
        for (key in notices.keys()) {
            val item = notices.getJSONObject(key)
            if (item.optLong("delivered_generation", -1) != generation ||
                item.optLong("delivered_revision", -1) != item.getLong("revision")) {
                val id = item.getLong("id")
                val wire = if (item.optBoolean("removed")) "GB(${JSONObject().put("t", "notify-").put("id", id)})"
                    else item.getString("packet")
                // Existing firmware ignores repeated IDs and has no notify~.
                // A changed body needs the supported remove/add sequence.
                return Delivery(key, id, item.getLong("revision"), wire,
                    !item.optBoolean("removed") && item.getLong("revision") > 1)
            }
        }
        return null
    }

    fun written(delivery: Delivery, generation: Long) {
        val notices = entries()
        val item = notices.optJSONObject(delivery.key) ?: return
        if (item.getLong("id") != delivery.id || item.getLong("revision") != delivery.revision) return
        if (item.optBoolean("removed")) notices.remove(delivery.key)
        else item.put("delivered_generation", generation).put("delivered_revision", delivery.revision)
        store.update("notification_write_completed", mapOf("notifications" to notices,
            "last_notification_write_utc_ms" to System.currentTimeMillis()), mapOf("notification_id" to delivery.id))
    }

    private fun removeItem(item: JSONObject) {
        item.put("removed", true).put("revision", item.getLong("revision") + 1)
        item.remove("packet")
    }

    companion object {
        const val CAPACITY = 64
        const val RETENTION_MS = 10 * 60 * 1000L
        /** Limit UTF-8 bytes without splitting a code point; JSON controls become spaces. */
        private fun bounded(value: String, budget: Int): String {
            val text = StringBuilder()
            var bytes = 0
            var offset = 0
            while (offset < value.length) {
                val point = value.codePointAt(offset)
                val part = if (point < 32) " " else String(Character.toChars(point))
                val size = part.toByteArray(Charsets.UTF_8).size
                if (bytes + size > budget) break
                text.append(part); bytes += size; offset += Character.charCount(point)
            }
            return text.toString()
        }
    }
}
