package dev.zswatch.app.companion

import java.math.BigDecimal
import java.util.TimeZone

object PrototypeClockCommands {
    fun offsetHours(nowMs: Long, zone: TimeZone): Double = zone.getOffset(nowMs) / 3600000.0

    /** DST can change the effective offset without changing the timezone ID. */
    fun timezoneChanged(savedOffset: Any?, nowMs: Long, zone: TimeZone): Boolean =
        (savedOffset as? Number)?.toDouble() != offsetHours(nowMs, zone)

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
internal class NusWrite(val bytes: ByteArray, val done: () -> Unit = {}, private val packetSize: Int = 20,
                        private val canStart: () -> Boolean = { true }) {
    private var offset = 0
    init { require(bytes.isNotEmpty() && packetSize > 0) }
    fun mayStart(): Boolean = offset > 0 || canStart()
    fun packet(): ByteArray = bytes.copyOfRange(offset, minOf(offset + packetSize, bytes.size))
    fun advance(): Boolean {
        offset = minOf(offset + packetSize, bytes.size)
        return offset == bytes.size
    }
}
