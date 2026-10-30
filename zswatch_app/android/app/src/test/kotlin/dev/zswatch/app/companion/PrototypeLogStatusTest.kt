package dev.zswatch.app.companion

import io.runtime.mcumgr.McuMgrErrorCode
import io.runtime.mcumgr.exception.McuMgrException
import io.runtime.mcumgr.exception.McuMgrErrorException
import io.runtime.mcumgr.exception.McuMgrTimeoutException
import io.runtime.mcumgr.response.HasReturnCode.GroupReturnCode
import io.runtime.mcumgr.response.fs.McuMgrFsStatusResponse
import io.runtime.mcumgr.response.fs.McuMgrFsDownloadResponse
import io.runtime.mcumgr.util.CBOR
import java.io.IOException
import org.junit.Assert.*
import org.junit.Test

class PrototypeLogStatusTest {
    private fun group(id: Int, code: Int) = GroupReturnCode().also { it.group = id; it.rc = code }
    @Test fun nordicErrorCallbacksSkipOnlyKnownMissingFileErrors() {
        assertNull(PrototypeLogStatus.failure(McuMgrErrorException(McuMgrErrorCode.NO_ENTRY)).getOrThrow())
        assertNull(PrototypeLogStatus.failure(McuMgrErrorException(group(8,3))).getOrThrow())
        for (error in listOf(McuMgrErrorException(McuMgrErrorCode.ACCESS_DENIED),
            McuMgrErrorException(McuMgrErrorCode.BUSY), McuMgrErrorException(group(7,3)),
            McuMgrErrorException(group(8,5)), McuMgrException("connection lost")))
            assertTrue(PrototypeLogStatus.failure(error).isFailure)
    }
    @Test fun responsesPreserveSizeAndSkipMissingButRejectOtherErrors() {
        val response = McuMgrFsStatusResponse().also { it.len = 12 }
        assertEquals(12, PrototypeLogStatus.response(response).getOrThrow())
        response.rc = McuMgrErrorCode.NO_ENTRY.value()
        assertNull(PrototypeLogStatus.response(response).getOrThrow())
        response.rc = McuMgrErrorCode.ACCESS_DENIED.value()
        assertTrue(PrototypeLogStatus.response(response).isFailure)
        response.rc = 0; response.groupReturnCode = group(8,3)
        assertNull(PrototypeLogStatus.response(response).getOrThrow())
    }
    @Test fun negativeSuccessfulSizeIsRejected() {
        assertTrue(PrototypeLogStatus.response(McuMgrFsStatusResponse().also { it.len = -1 }).isFailure)
    }
    @Test fun errorsKeepTheirMessageAndCauseInsteadOfAnObfuscatedClassName() {
        for (error in listOf(McuMgrTimeoutException(), McuMgrException("connection lost"))) {
            val failure = PrototypeLogStatus.failure(error).exceptionOrNull()!!
            assertSame(error, failure.cause)
            assertTrue(failure.message!!.startsWith("Watch file status failed: "))
            assertTrue(failure.message!!.contains(error.message ?: "No response from watch"))
        }
    }

    @Test fun malformedFileDataCannotLeakThroughDecoderFailureMessages() {
        val contents = "private coredump contents!"
        // Exercise the SDK's actual CBOR/Jackson decoder: text in place of the
        // file byte array produces an exception containing that text.
        val payload = CBOR.toBytes(mapOf("off" to 0, "len" to 24, "data" to contents))
        val decoder = assertThrows(IOException::class.java) {
            CBOR.toObject(payload, McuMgrFsDownloadResponse::class.java)
        }
        assertTrue(decoder.message!!.contains(contents))
        val error = McuMgrException(decoder)
        assertEquals("Invalid file response from watch", PrototypeLogStatus.failureMessage(error))
        val failure = PrototypeLogStatus.failure(error).exceptionOrNull()!!
        assertFalse(failure.message!!.contains(contents))
        assertSame(error, failure.cause)
        // Preserve protection when the SDK adds another wrapper.
        assertEquals("Invalid file response from watch", PrototypeLogStatus.failureMessage(McuMgrException(error)))
    }
}
