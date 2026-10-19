package dev.zswatch.app.companion

import io.runtime.mcumgr.McuMgrErrorCode
import io.runtime.mcumgr.exception.McuMgrException
import io.runtime.mcumgr.exception.McuMgrErrorException
import io.runtime.mcumgr.response.HasReturnCode.GroupReturnCode
import io.runtime.mcumgr.response.fs.McuMgrFsStatusResponse
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
}
