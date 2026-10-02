package dev.zswatch.app.companion

import java.math.BigDecimal

object PrototypeClockCommands {
    /** Firmware parses these before JSON reassembly, separately for each ATT write. */
    fun packets(epochSeconds: Long, offsetHours: Double, payloadSize: Int): List<ByteArray> {
        require(offsetHours.isFinite())
        val offset = BigDecimal.valueOf(offsetHours).stripTrailingZeros().toPlainString()
        val packets = listOf("setTime($epochSeconds)", ";E.setTimeZone($offset)")
            .map { it.toByteArray(Charsets.UTF_8) }
        require(packets.all { it.size <= payloadSize }) {
            "Clock command needs ${packets.maxOf { it.size }} bytes; negotiated ATT payload is $payloadSize"
        }
        return packets
    }
}

/** A fixed packet size keeps completion accounting independent of later MTU callbacks. */
internal class NusWrite(val bytes: ByteArray, val done: () -> Unit = {}, private val packetSize: Int = 20) {
    private var offset = 0
    init { require(bytes.isNotEmpty() && packetSize > 0) }
    fun packet(): ByteArray = bytes.copyOfRange(offset, minOf(offset + packetSize, bytes.size))
    fun advance(): Boolean {
        offset = minOf(offset + packetSize, bytes.size)
        return offset == bytes.size
    }
}
