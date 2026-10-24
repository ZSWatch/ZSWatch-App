package dev.zswatch.app.companion

import java.io.File
import java.io.FileOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.security.MessageDigest

/** No watch deletion. Publication and the journal commit have a recovery boundary. */
class ReceiptFiles(
    private val directory: File,
    // Dart's getApplicationSupportDirectory() is filesDir on Android.
    private val playback: File = File(directory.parentFile?.parentFile, "companion-recording-imports-v1"),
) {
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

    private fun trash(key: String) = File(File(directory, "recently-deleted"), sha(key.toByteArray()))

    private fun localCopies(key: String, metadata: Map<String, Any?>): List<File> {
        val hash = metadata["sha256"] as? String
        require(hash != null && Regex("[a-f0-9]{64}").matches(hash)) { "Verified recording required" }
        val target = destination(key)
        return listOf(target, File(target.path + ".partial"),
            File(playback, "${sha(key.toByteArray())}-$hash-ogg-v1.ogg"))
    }

    /** The journal tombstone precedes this idempotent move; no watch command is sent. */
    fun removeLocal(key: String, metadata: Map<String, Any?>) {
        val trash = trash(key)
        trash.mkdirs()
        for (source in localCopies(key, metadata)) {
            if (!source.isFile) continue
            var target = File(trash, source.name)
            // Keep a late playback conversion without overwriting the removed copy.
            if (target.exists()) target = File(trash, source.name + ".recovered-" + System.nanoTime())
            check(source.renameTo(target)) { "Recording move to Recently deleted failed" }
        }
    }

    fun restoreLocal(key: String, metadata: Map<String, Any?>): Map<String, Any?> {
        val trash = trash(key)
        for (target in localCopies(key, metadata)) {
            val source = File(trash, target.name)
            if (!source.isFile) continue
            check(!target.exists()) { "Restored copy already exists; both files retained" }
            check(source.renameTo(target)) { "Recording restore failed" }
        }
        return recover(key, metadata) ?: error("Deleted source cannot be verified")
    }

    /** Removes only this receipt's own copies, including those in Recently deleted. */
    fun purgeLocal(key: String, metadata: Map<String, Any?>) {
        val copies = localCopies(key, metadata)
        val trash = trash(key)
        val candidates = copies.toMutableList()
        trash.listFiles()?.forEach { file ->
            check(file.isFile && copies.any { file.name == it.name || file.name.startsWith(it.name + ".recovered-") }) {
                "Unknown deleted recording file retained"
            }
            candidates += file
        }
        for (file in candidates) if (file.exists()) check(file.delete()) { "Recording deletion failed" }
        if (trash.exists()) trash.delete()
    }

    companion object {
        fun sha(bytes: ByteArray): String = MessageDigest.getInstance("SHA-256")
            .digest(bytes).joinToString("") { "%02x".format(it.toInt() and 255) }
    }
}
