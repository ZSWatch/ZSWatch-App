package dev.zswatch.app.companion

import java.io.File
import java.io.FileOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.security.MessageDigest

/** No watch deletion. Publication and the journal commit have a recovery boundary. */
class ReceiptFiles(private val directory: File) {
    init { directory.mkdirs() }

    fun destination(key: String) = File(directory, sha(key.toByteArray()) + ".zsw_opus")

    fun valid(data: ByteArray, metadata: Map<String, Any?>): Boolean {
        if (data.size != (metadata["size_bytes"] as Number).toInt() || data.size < 34) return false
        val buffer = ByteBuffer.wrap(data).order(ByteOrder.LITTLE_ENDIAN)
        if (String(data.copyOfRange(0, 4), Charsets.US_ASCII) != "ZSWO" || buffer.getShort(4).toInt() != 1) return false
        val rate = buffer.getShort(6).toInt() and 65535
        val frameSize = buffer.getShort(8).toInt() and 65535
        val timestamp = buffer.getInt(16).toLong() and 0xffffffffL
        val frames = buffer.getInt(20).toLong() and 0xffffffffL
        val duration = buffer.getInt(24).toLong() and 0xffffffffL
        if (rate == 0 || frameSize == 0 || frames == 0xffffffffL || duration == 0xffffffffL ||
            timestamp != (metadata["timestamp"] as Number).toLong()) return false
        var offset = 32
        var count = 0L
        while (offset + 2 <= data.size) {
            val length = buffer.getShort(offset).toInt() and 65535
            if (length == 0 || offset + 2 + length > data.size) return false
            offset += 2 + length
            count++
        }
        return offset == data.size && count > 0 && count == frames &&
            duration == count * frameSize * 1000 / rate &&
            duration == (metadata["duration_ms"] as Number).toLong()
    }

    fun recover(key: String, metadata: Map<String, Any?>): Map<String, Any?>? {
        val target = destination(key)
        val partial = File(target.path + ".partial")
        val candidate = if (target.isFile) target else if (partial.isFile) partial else return null
        val bytes = candidate.readBytes()
        if (!valid(bytes, metadata)) return null
        if (candidate == partial) check(partial.renameTo(target)) { "Receipt recovery rename failed" }
        return metadata + mapOf("state" to "downloaded", "local_path" to target.path, "sha256" to sha(bytes))
    }

    fun publish(key: String, metadata: Map<String, Any?>, bytes: ByteArray): Map<String, Any?> {
        require(valid(bytes, metadata)) { "Recording container/metadata mismatch" }
        recover(key, metadata)?.let { return it }
        val target = destination(key)
        // Retain an invalid prior file before replacing it with verified bytes.
        if (target.exists()) check(target.renameTo(File(target.path + ".invalid-" + System.nanoTime())))
        val partial = File(target.path + ".partial")
        FileOutputStream(partial).use { it.write(bytes); it.fd.sync() }
        check(partial.renameTo(target)) { "Receipt publication failed" }
        return metadata + mapOf("state" to "downloaded", "local_path" to target.path, "sha256" to sha(bytes))
    }

    companion object {
        fun sha(bytes: ByteArray): String = MessageDigest.getInstance("SHA-256")
            .digest(bytes).joinToString("") { "%02x".format(it.toInt() and 255) }
    }
}
