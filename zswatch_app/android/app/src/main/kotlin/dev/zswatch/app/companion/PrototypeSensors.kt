package dev.zswatch.app.companion

import java.util.ArrayDeque
import java.util.UUID

/** Ephemeral sensor subscriptions on the companion's existing GATT connection. */
internal class PrototypeSensors(private val emit: (Map<String, Any?>) -> Unit) {
    data class Spec(val name: String, val code: String, val bytes: Int) {
        val service: UUID = UUID.fromString("adaf${code}00-c332-42a8-93bd-25e905756cb8")
        val characteristic: UUID = UUID.fromString("adaf${code}01-c332-42a8-93bd-25e905756cb8")
    }
    class Change(val name: String, val enabled: Boolean, val done: (Result<Unit>) -> Unit)
    companion object {
        val specs = listOf(Spec("temperature", "01", 4), Spec("accelerometer", "02", 12),
            Spec("light", "03", 4), Spec("gyroscope", "04", 12), Spec("magnetometer", "05", 12),
            Spec("humidity", "07", 4), Spec("pressure", "08", 4), Spec("fusion", "0d", 16))
    }
    private var generation = 0L
    private var available = emptySet<String>()
    private val enabled = mutableSetOf<String>()
    private val queued = ArrayDeque<Change>()
    var current: Change? = null
        private set
    val busy get() = current != null
    fun state(): Map<String, Any?> = mapOf("version" to 1, "kind" to "state",
        "generation" to generation, "available" to available.toList(), "enabled" to enabled.toList())
    fun reset(session: Long, names: Set<String>) {
        val pending = listOfNotNull(current) + queued.toList()
        current = null; queued.clear(); enabled.clear()
        generation = session; available = names.intersect(specs.map { it.name }.toSet())
        pending.forEach { it.done(Result.failure(IllegalStateException("Sensor connection changed"))) }
        emit(state())
    }
    fun request(name: String, on: Boolean, done: (Result<Unit>) -> Unit) {
        require(name in available) { "Sensor is unavailable" }
        check(queued.size < 16) { "Sensor request queue full" }
        queued.add(Change(name, on, done))
    }
    fun next(): Change? {
        if (current != null) return null
        while (queued.isNotEmpty()) {
            val change = queued.remove()
            if ((change.name in enabled) == change.enabled) change.done(Result.success(Unit))
            else { current = change; return change }
        }
        return null
    }
    fun complete(change: Change, success: Boolean) {
        if (current !== change) return
        current = null
        if (success) {
            if (change.enabled) enabled.add(change.name) else enabled.remove(change.name)
        }
        emit(state())
        change.done(if (success) Result.success(Unit)
            else Result.failure(IllegalStateException("Sensor subscription failed")))
    }
    fun stopAll() {
        val pending = queued.toList(); queued.clear()
        pending.forEach { it.done(Result.failure(IllegalStateException("Sensor view closed"))) }
        // A submitted CCCD write still owns GATT until its callback. Follow an
        // in-flight enable with disable; never overlap its ATT transaction.
        val toStop = enabled + listOfNotNull(current?.takeIf { it.enabled }?.name)
        toStop.forEach { queued.add(Change(it, false, {})) }
    }
    fun receive(name: String, bytes: ByteArray) {
        val spec = specs.firstOrNull { it.name == name } ?: return
        if (name !in enabled || bytes.size != spec.bytes) return
        emit(mapOf("version" to 1, "kind" to "sample", "generation" to generation,
            "sensor" to name, "bytes" to bytes.clone()))
    }
}
