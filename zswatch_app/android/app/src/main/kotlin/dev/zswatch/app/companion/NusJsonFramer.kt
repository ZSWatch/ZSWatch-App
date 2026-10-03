package dev.zswatch.app.companion

import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.nio.charset.CodingErrorAction

/** Compact watch messages: preserve split UTF-8 and escaped braces. A newline
 * ends a wire message, so an incomplete frame cannot swallow subsequent traffic.
 */
class NusJsonFramer(private val maximum: Int = 32768) {
    private val bytes = ByteArrayOutputStream()
    private var depth = 0
    private var quoted = false
    private var escaped = false
    var droppedFrames = 0L
        private set

    fun reset() { bytes.reset(); depth = 0; quoted = false; escaped = false }

    fun feed(chunk: ByteArray): List<String> {
        val messages = mutableListOf<String>()
        for (byte in chunk) {
            val value = byte.toInt() and 255
            if (value == 10 && depth > 0) { droppedFrames++; reset(); continue }
            if (depth == 0 && value != 123) continue
            bytes.write(value)
            if (bytes.size() > maximum) { reset(); throw IllegalArgumentException("NUS frame limit exceeded") }
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
                reset()
                messages.add(Charsets.UTF_8.newDecoder().onMalformedInput(CodingErrorAction.REPORT)
                    .decode(ByteBuffer.wrap(assembled)).toString())
            }
        }
        return messages
    }
}
