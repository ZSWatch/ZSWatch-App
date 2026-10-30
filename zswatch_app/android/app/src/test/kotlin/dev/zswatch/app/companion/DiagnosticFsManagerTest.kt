package dev.zswatch.app.companion

import io.runtime.mcumgr.McuMgrCallback
import io.runtime.mcumgr.McuMgrScheme
import io.runtime.mcumgr.McuMgrTransport
import io.runtime.mcumgr.exception.McuMgrTimeoutException
import io.runtime.mcumgr.managers.FsManager
import io.runtime.mcumgr.response.McuMgrResponse
import io.runtime.mcumgr.response.fs.McuMgrFsStatusResponse
import org.junit.Assert.*
import org.junit.Test

class DiagnosticFsManagerTest {
    /** Model a response delayed by connection setup, without sleeping in the test. */
    private class DelayedStatus(private val delay: Long) : McuMgrTransport {
        var timeout = 0L
        override fun getScheme() = McuMgrScheme.BLE
        override fun <T : McuMgrResponse> send(payload: ByteArray, timeout: Long, responseType: Class<T>): T {
            this.timeout = timeout
            assertEquals(0, payload[0].toInt() and 7) // Read operation.
            assertEquals(8, payload[5].toInt()) // Filesystem group.
            assertEquals(1, payload[7].toInt()) // File status, not a write.
            if (delay > timeout) throw McuMgrTimeoutException()
            return responseType.cast(McuMgrFsStatusResponse().also { it.len = 1053 })!!
        }
        override fun <T : McuMgrResponse> send(payload: ByteArray, timeout: Long, responseType: Class<T>, callback: McuMgrCallback<T>) {
            try { callback.onResponse(send(payload, timeout, responseType)) }
            catch (error: McuMgrTimeoutException) { callback.onError(error) }
        }
        override fun connect(callback: McuMgrTransport.ConnectionCallback?) { callback?.onConnected() }
        override fun release() {}
        override fun addObserver(observer: McuMgrTransport.ConnectionObserver) {}
        override fun removeObserver(observer: McuMgrTransport.ConnectionObserver) {}
    }

    private fun status(manager: FsManager): Result<Int?>? {
        var result: Result<Int?>? = null
        manager.status(PrototypeLogFiles.COREDUMP_PATH, object : McuMgrCallback<McuMgrFsStatusResponse> {
            override fun onResponse(response: McuMgrFsStatusResponse) { result = PrototypeLogStatus.response(response) }
            override fun onError(error: io.runtime.mcumgr.exception.McuMgrException) { result = PrototypeLogStatus.failure(error) }
        })
        return result
    }

    @Test fun coldStatusCanOutliveTheSdkShortTimeout() {
        assertTrue(status(FsManager(DelayedStatus(3000)))!!.isFailure)
        val transport = DelayedStatus(3000)
        assertEquals(1053, status(DiagnosticFsManager(transport))!!.getOrThrow())
        assertEquals(10000L, transport.timeout)
    }

    @Test fun unresponsiveWatchStillFailsWithinABoundedTimeout() {
        val transport = DelayedStatus(10001)
        assertTrue(status(DiagnosticFsManager(transport))!!.exceptionOrNull()!!.cause is McuMgrTimeoutException)
        assertEquals(10000L, transport.timeout)
    }
}
