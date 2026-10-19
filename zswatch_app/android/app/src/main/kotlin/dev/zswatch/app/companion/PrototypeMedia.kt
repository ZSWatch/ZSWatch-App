package dev.zswatch.app.companion

import org.json.JSONObject
import java.util.concurrent.atomic.AtomicReference

/** Main/worker handoff fence. Commands and metadata are never replayed. */
internal class PrototypeMediaLease {
    data class Session(val generation: Long)
    private val current = AtomicReference<Session?>(null)
    fun open(generation: Long): Session = Session(generation).also { current.set(it) }
    fun close() { current.set(null) }
    fun get(generation: Long): Session? = current.get()?.takeIf { it.generation == generation }
    fun owns(session: Session): Boolean = current.get() === session
    fun authorizesControl(session: Session, receivedMs: Long, nowMs: Long): Boolean =
        owns(session) && nowMs >= receivedMs && nowMs - receivedMs <= 2000
}

/** Worker-owned coalescing; failed queue admission stays retryable. */
internal class PrototypeMediaDelivery(private val lease: PrototypeMediaLease) {
    private var session: PrototypeMediaLease.Session? = null
    private val delivered = mutableMapOf<Int, String>()
    fun publish(expected: PrototypeMediaLease.Session, packets: List<String>, send: (String) -> Boolean) {
        if (!lease.owns(expected)) return
        if (session !== expected) { session = expected; delivered.clear() }
        packets.forEachIndexed { index, packet ->
            if (delivered[index] != packet && send(packet)) delivered[index] = packet
        }
    }
    fun clear() { session = null; delivered.clear() }
}

/** Existing GB music protocol. No titles, artists or media state are persisted. */
internal object PrototypeMedia {
    fun action(message: JSONObject): String? {
        if (message.opt("t") != "music") return null
        return (message.opt("n") as? String)?.takeIf {
            it in setOf("play", "pause", "next", "previous", "volumeup", "volumedown")
        }
    }

    private fun text(value: Any?): String {
        val source = (value as? String).orEmpty().take(1024)
        val result = StringBuilder()
        // The watch has 100-byte fields, including its raw JSON-string extraction.
        // Bound encoded UTF-8, preserve code points and exclude embedded NUL.
        source.codePoints().toArray().forEach { code ->
            if (code == 0 || code in 0xD800..0xDFFF) return@forEach
            val candidate = result.toString() + String(Character.toChars(code))
            if (JSONObject.quote(candidate).toByteArray(Charsets.UTF_8).size <= 98) result.appendCodePoint(code)
            else return result.toString()
        }
        return result.toString()
    }

    private fun seconds(value: Any?): Long = if (value is Number)
        value.toLong().coerceIn(0, Int.MAX_VALUE.toLong()) else 0

    fun packets(current: Map<String, Any?>?): List<String> {
        val playback = current?.get("playback") as? Map<*, *>
        val metadata = current?.get("metadata") as? Map<*, *>
        val state = when (playback?.get("state")) { "play" -> "play"; "pause" -> "pause"; else -> "stop" }
        val info = JSONObject().put("t", "musicinfo").put("artist", text(metadata?.get("artist")))
            .put("album", text(metadata?.get("album"))).put("track", text(metadata?.get("track")))
            .put("dur", seconds(metadata?.get("duration"))).put("c", -1).put("n", -1)
        val status = JSONObject().put("t", "musicstate").put("state", state)
            .put("position", seconds(playback?.get("position"))).put("shuffle", 0).put("repeat", 0)
        return listOf("GB($info)", "GB($status)")
    }
}
