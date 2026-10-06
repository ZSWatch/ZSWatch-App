package dev.zswatch.app.companion

import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.nio.charset.CodingErrorAction

/** Compact watch messages: preserve split UTF-8 and escaped braces. A newline
 * ends a wire message, so an incomplete frame cannot swallow subsequent traffic.
 */
class NusJsonFramer(private val maximum: Int = 32768, private val log: (String) -> Unit = {}) {
    private val bytes = ByteArrayOutputStream()
    private var depth = 0
    private var quoted = false
    private var escaped = false
    var droppedFrames = 0L
        private set
    private val prefix = "<BLELOG>".toByteArray()
    private val suffix = "</BLELOG>".toByteArray()
    private val marker = ArrayList<Byte>()
    private val logBytes = ByteArrayOutputStream()
    private var inLog = false
    private var oversizedLog = false
    private var logStartedMs = 0L
    private var receivedMs = 0L
    var droppedLogs = 0L
        private set

    private fun resetJson() { bytes.reset(); depth = 0; quoted = false; escaped = false }
    fun reset() {
        resetJson(); marker.clear(); logBytes.reset(); inLog = false; oversizedLog = false
    }

    // Tags and UTF-8 may be split at any ATT byte boundary. Keep wrapped log
    // content out of the JSON parser, including braces and embedded commands.
    private fun logByte(byte: Byte): Boolean {
        if (!inLog && depth != 0) return false
        marker.add(byte)
        while (marker.isNotEmpty()) {
            val candidate = marker.toByteArray()
            val startsPrefix = candidate.size <= prefix.size && candidate.indices.all { candidate[it] == prefix[it] }
            val startsSuffix = inLog && candidate.size <= suffix.size && candidate.indices.all { candidate[it] == suffix[it] }
            if (startsPrefix || startsSuffix) {
                if (startsPrefix && candidate.size == prefix.size) {
                    if (inLog && !oversizedLog) droppedLogs++
                    inLog = true; logStartedMs = receivedMs; oversizedLog = false; logBytes.reset(); marker.clear()
                } else if (startsSuffix && candidate.size == suffix.size) {
                    if (!oversizedLog) {
                        val content = runCatching { Charsets.UTF_8.newDecoder().onMalformedInput(CodingErrorAction.REPORT)
                            .decode(ByteBuffer.wrap(logBytes.toByteArray())).toString() }
                        content.fold({ if (it.isNotEmpty()) log(it) }, { droppedLogs++ })
                    }
                    inLog = false; oversizedLog = false; logBytes.reset(); marker.clear()
                }
                return true
            }
            val first = marker.removeAt(0)
            if (!inLog) {
                // Outside a tag, the only meaningful first byte is a JSON '{'.
                if (first.toInt() == 123) { marker.clear(); return false }
            } else if (!oversizedLog) {
                logBytes.write(first.toInt())
                if (logBytes.size() > 8192) { logBytes.reset(); oversizedLog = true; droppedLogs++ }
            }
        }
        return true
    }

    fun feed(chunk: ByteArray, nowMs: Long = System.nanoTime() / 1_000_000): List<String> {
        receivedMs = nowMs
        // Lost log tail must not permanently hide subsequent protocol traffic.
        // A complete firmware line is at most 256 bytes; allow a generous five
        // seconds for fragmented delivery before discarding an unfinished tag.
        if (inLog && nowMs - logStartedMs >= 5000) {
            if (!oversizedLog) droppedLogs++
            inLog = false; oversizedLog = false; logBytes.reset(); marker.clear()
        }
        val messages = mutableListOf<String>()
        for (byte in chunk) {
            if (logByte(byte)) continue
            val value = byte.toInt() and 255
            if (value == 10 && depth > 0) { droppedFrames++; resetJson(); continue }
            if (depth == 0 && value != 123) continue
            bytes.write(value)
            if (bytes.size() > maximum) { resetJson(); throw IllegalArgumentException("NUS frame limit exceeded") }
            if (quoted) {
                if (escaped) escaped = false
                else if (value == 92) escaped = true
                else if (value == 34) quoted = false
            } else {
                when (value) {
                    34 -> quoted = true
                    123 -> depth++
                    125 -> depth--
                }
            }
            if (depth == 0) {
                val assembled = bytes.toByteArray()
                resetJson()
                messages.add(Charsets.UTF_8.newDecoder().onMalformedInput(CodingErrorAction.REPORT)
                    .decode(ByteBuffer.wrap(assembled)).toString())
            }
        }
        return messages
    }
}
