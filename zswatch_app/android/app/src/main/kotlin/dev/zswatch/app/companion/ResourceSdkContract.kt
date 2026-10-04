package dev.zswatch.app.companion

import java.nio.ByteBuffer
import java.nio.ByteOrder

internal data class ResourceTarget(val bytes: Int, val hash: String)
internal data class PreparedResources(val data: ByteArray, val target: ResourceTarget)

/** Existing custom resource image layout, not an SMP protocol or MCUboot parser. */
internal object ResourceSdkContract {
    const val PATH = "/S/full_fs"
    const val MAGIC = 0x0a0a0a0a
    const val MAX_BYTES = 8 * 1024 * 1024
    private val knownBoard = Regex("(watchdk@1|zswatch@(1|4|5))(/nrf5340/cpuapp)?")
    fun prepare(bytes: ByteArray, hardware: String): PreparedResources {
        require(knownBoard.matches(hardware)) { "Resource partition size is unknown for this board" }
        require(bytes.size in 20..MAX_BYTES) { "Unsupported resource image size" }
        val copy = bytes.copyOf()
        validate(copy)
        return PreparedResources(copy, ResourceTarget(copy.size, ReceiptFiles.sha(copy)))
    }
    fun validate(bytes: ByteArray) {
        require(bytes.size in 20..MAX_BYTES && bytes.size % 4 == 0) { "Unsupported resource image size" }
        val buffer = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
        fun unsigned(at: Int) = buffer.getInt(at).toLong() and 0xffffffffL
        val header = unsigned(4); val size = unsigned(8); val count = unsigned(12)
        require(buffer.getInt(0) == MAGIC && buffer.getInt(bytes.size - 4) == MAGIC) { "Resource table or trailer is invalid" }
        require(size == bytes.size.toLong() && count in 1..800 && header == 16 + 40 * count && header <= size - 4) { "Resource table bounds are invalid" }
        val names = mutableSetOf<String>()
        val spans = mutableListOf<Pair<Long, Long>>()
        for (index in 0 until count.toInt()) {
            val at = 16 + 40 * index
            val raw = bytes.copyOfRange(at, at + 32)
            val end = raw.indexOf(0).let { if (it < 0) 32 else it }
            val name = raw.copyOfRange(0, end).toString(Charsets.UTF_8)
            require(name.isNotBlank() && !name.contains('/') && !name.contains('\\') && !name.any { it.isISOControl() } && names.add(name)) { "Resource name is invalid or duplicated" }
            val offset = unsigned(at + 32); val length = unsigned(at + 36)
            require(offset <= size - header - 4 && length <= size - header - 4 - offset) { "Resource file bounds are invalid" }
            if (length > 0) spans.add(offset to offset + length)
        }
        val ordered = spans.sortedBy { it.first }
        require(ordered.zipWithNext().all { (first, next) -> first.second <= next.first }) { "Resource files overlap" }
    }
    fun check(target: ResourceTarget, bytes: ByteArray) {
        check(bytes.size == target.bytes && ReceiptFiles.sha(bytes) == target.hash) { "Resource readback differs from selection" }
        validate(bytes)
    }
}
