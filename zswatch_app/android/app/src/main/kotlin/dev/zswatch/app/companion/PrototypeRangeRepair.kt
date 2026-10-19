package dev.zswatch.app.companion

/**
 * Repairs a downloaded file in place by comparing range hashes with the watch.
 *
 * Some Android Bluetooth stacks occasionally deliver SMP notifications whose
 * tail repeats older bytes (seen on a Nokia G100), so a whole-file retry can
 * fail again and again. Mismatching ranges are split until one chunk remains,
 * which is read again. Calls block; run off the main thread.
 */
internal class PrototypeRangeRepair(
    private val watchSha: (offset: Int, length: Int) -> String?,
    private val read: (offset: Int) -> ByteArray?,
    private val chunk: Int = 2425,
    private val rereads: Int = 3,
) {
    fun repair(bytes: ByteArray): Boolean = repairRange(bytes, 0, bytes.size)

    private fun matches(bytes: ByteArray, offset: Int, length: Int) =
        watchSha(offset, length) == ReceiptFiles.sha(bytes.copyOfRange(offset, offset + length))

    private fun repairRange(bytes: ByteArray, offset: Int, length: Int): Boolean {
        if (length <= 0 || matches(bytes, offset, length)) return true
        if (length <= chunk) {
            repeat(rereads) {
                if (reread(bytes, offset, length) && matches(bytes, offset, length)) return true
            }
            return false
        }
        // Split into up to four chunk-aligned parts so one bad chunk costs few round trips.
        val step = ((length + 3) / 4 + chunk - 1) / chunk * chunk
        var start = offset
        var repaired = true
        while (start < offset + length) {
            val part = minOf(step, offset + length - start)
            repaired = repairRange(bytes, start, part) && repaired
            start += part
        }
        return repaired
    }

    private fun reread(bytes: ByteArray, offset: Int, length: Int): Boolean {
        var position = offset
        while (position < offset + length) {
            val data = read(position) ?: return false
            if (data.isEmpty()) return false
            data.copyInto(bytes, position, 0, minOf(data.size, offset + length - position))
            position += data.size
        }
        return true
    }
}
