package dev.zswatch.app.companion

import org.junit.Assert.*
import org.junit.Test

class PrototypeCoredumpSummaryTest {
    private val response = "\r\nStored coredumps: 1\r\n  Timestamp: 2026-10-06 22:00:00\r\n  File: src/main.c\r\n  Line: 321\r\n"
    @Test fun existingFirmwareShellResponseIsDecoded() {
        val packet = PrototypeCoredumpSummary.packet(response)
        assertTrue(packet.getBoolean("available"))
        assertEquals("src/main.c", packet.getString("file"))
        assertEquals(321, packet.getInt("line"))
        assertEquals("2026-10-06 22:00:00", packet.getString("time"))
        assertFalse(PrototypeCoredumpSummary.packet("\r\nNo stored coredumps\r\n").getBoolean("available"))
    }
    @Test fun actualFirmwareDumpWithoutAssertLocationIsValid() {
        val packet = PrototypeCoredumpSummary.packet("\r\nStored coredumps: 1\r\n  Timestamp: 19:27 06/09\r\n  File: \r\n  Line: 0\r\n")
        assertTrue(packet.getBoolean("available"))
        assertEquals("", packet.getString("file"))
        assertEquals(0, packet.getInt("line"))
        assertThrows(IllegalArgumentException::class.java) { PrototypeCoredumpSummary.packet("Stored coredumps: 1\n  Timestamp: x\n  Line: 0\n") }
    }
    @Test fun FailureMalformedAndAmbiguousOutputCannotClearOrInventAReport() {
        for (output in listOf("Failed to read summary (-5)", response.replace("Line: 321", "Line: -1"),
            response.replace("Stored coredumps: 1", "Stored coredumps: 0"), response + "  File: other.c\n",
            response.replace("src/main.c", "x".repeat(513)), "x".repeat(8193)))
            assertThrows(IllegalArgumentException::class.java) { PrototypeCoredumpSummary.packet(output) }
    }
    @Test fun OnlyExactExistingMissingFileErrorCountsAsAbsent() {
        assertFalse(PrototypeCoredumpSummary.packet("\r\nFailed to read summary (-2)\r\n", -2).getBoolean("available"))
        for ((output, code) in listOf("Failed to read summary (-2)" to 0L,
            "Failed to read summary (-5)" to -5L, "No stored coredumps" to -5L,
            response to -2L))
            assertThrows(IllegalArgumentException::class.java) { PrototypeCoredumpSummary.packet(output, code) }
    }
}
