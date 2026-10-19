package dev.zswatch.app.companion

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PrototypeRangeRepairTest {
    private val chunk = 100
    private val truth = ByteArray(1050) { (it * 7 + 3).toByte() }

    private fun watchSha(offset: Int, length: Int) = ReceiptFiles.sha(truth.copyOfRange(offset, offset + length))
    private fun read(offset: Int) = truth.copyOfRange(offset, minOf(truth.size, offset + chunk))

    @Test fun repairsOnlyCorruptedChunks() {
        val received = truth.copyOf().also { for (i in 230..260) it[i] = 0; for (i in 990..1049) it[i] = 1 }
        val reads = mutableListOf<Int>()
        val ok = PrototypeRangeRepair(::watchSha, { reads += it; read(it) }, chunk).repair(received)
        assertTrue(ok)
        assertArrayEquals(truth, received)
        assertEquals(listOf(200, 900, 1000), reads.sorted())
    }

    @Test fun intactFileNeedsNoReads() {
        val received = truth.copyOf()
        assertTrue(PrototypeRangeRepair(::watchSha, { error("No read expected") }, chunk).repair(received))
    }

    @Test fun persistentCorruptionFailsAfterBoundedRereads() {
        val received = truth.copyOf().also { it[500] = (it[500] + 1).toByte() }
        var reads = 0
        val ok = PrototypeRangeRepair(::watchSha, { reads++; read(it).also { d -> if (it == 500) d[0] = 9 } }, chunk, rereads = 3)
            .repair(received)
        assertFalse(ok)
        assertEquals(3, reads)
    }
}
