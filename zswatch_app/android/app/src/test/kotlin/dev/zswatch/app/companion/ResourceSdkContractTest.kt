package dev.zswatch.app.companion

import org.junit.Assert.*
import org.junit.Test
import java.nio.ByteBuffer
import java.nio.ByteOrder

class ResourceSdkContractTest {
    companion object {
        /** Existing generator layout, never used as a physical flash artifact. */
        fun image(): ByteArray = ByteArray(64).also { bytes ->
            val b=ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
            b.putInt(0,ResourceSdkContract.MAGIC);b.putInt(4,56);b.putInt(8,64);b.putInt(12,1)
            "font.bin".toByteArray().copyInto(bytes,16);b.putInt(48,0);b.putInt(52,4)
            b.putInt(56,0x12345678);b.putInt(60,ResourceSdkContract.MAGIC)
        }
    }
    @Test fun existingLayoutAndKnownBoardsKeepAnImmutablePayload() {
        for(board in listOf("watchdk@1/nrf5340/cpuapp","zswatch@1","zswatch@4","zswatch@5/nrf5340/cpuapp")) {
            val bytes=image();val prepared=ResourceSdkContract.prepare(bytes,board)
            assertEquals(bytes.size,prepared.target.bytes);assertEquals(64,prepared.target.hash.length)
            bytes[56]=0;assertNotEquals(bytes[56],prepared.data[56]);ResourceSdkContract.check(prepared.target,prepared.data)
        }
    }
    @Test fun unknownPartitionsAndMalformedTablesRejectBeforeTransportHandoff() {
        assertThrows(IllegalArgumentException::class.java){ResourceSdkContract.prepare(image(),"native_sim")}
        for(change in listOf<(ByteArray)->Unit>({it[0]=0},{it[60]=0},
            {ByteBuffer.wrap(it).order(ByteOrder.LITTLE_ENDIAN).putInt(8,65)},
            {ByteBuffer.wrap(it).order(ByteOrder.LITTLE_ENDIAN).putInt(4,16)},
            {ByteBuffer.wrap(it).order(ByteOrder.LITTLE_ENDIAN).putInt(12,-1)},
            {ByteBuffer.wrap(it).order(ByteOrder.LITTLE_ENDIAN).putInt(48,-1)},
            {ByteBuffer.wrap(it).order(ByteOrder.LITTLE_ENDIAN).putInt(52,5)},
            {it[16]='/'.code.toByte()}, {for(i in 16 until 48)it[i]=0})) {
            val bytes=image();change(bytes)
            assertThrows(IllegalArgumentException::class.java){ResourceSdkContract.validate(bytes)}
        }
        for(bytes in listOf(ByteArray(16),ByteArray(63),ByteArray(ResourceSdkContract.MAX_BYTES+4))) {
            assertThrows(IllegalArgumentException::class.java){ResourceSdkContract.validate(bytes)}
        }
    }
    @Test fun fullHashReadbackCannotBeSatisfiedBySizeOnly() {
        val prepared=ResourceSdkContract.prepare(image(),"watchdk@1")
        val other=prepared.data.copyOf();other[56]=0
        assertThrows(IllegalStateException::class.java){ResourceSdkContract.check(prepared.target,other)}
        assertThrows(IllegalStateException::class.java){ResourceSdkContract.check(prepared.target,ByteArray(60))}
    }
    @Test fun duplicateNamesAndOverlappingFilesCannotAliasResources() {
        val bytes=ByteArray(108);val b=ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
        b.putInt(0,ResourceSdkContract.MAGIC);b.putInt(4,96);b.putInt(8,108);b.putInt(12,2);b.putInt(104,ResourceSdkContract.MAGIC)
        "a.bin".toByteArray().copyInto(bytes,16);"b.bin".toByteArray().copyInto(bytes,56)
        b.putInt(48,0);b.putInt(52,4);b.putInt(88,4);b.putInt(92,4)
        ResourceSdkContract.validate(bytes)
        b.putInt(88,2);assertThrows(IllegalArgumentException::class.java){ResourceSdkContract.validate(bytes)}
        b.putInt(88,4);bytes[56]='a'.code.toByte()
        assertThrows(IllegalArgumentException::class.java){ResourceSdkContract.validate(bytes)}
    }
}
