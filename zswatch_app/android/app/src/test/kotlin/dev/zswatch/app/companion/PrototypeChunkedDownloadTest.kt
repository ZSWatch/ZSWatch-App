package dev.zswatch.app.companion

import io.runtime.mcumgr.exception.McuMgrException
import io.runtime.mcumgr.exception.McuMgrTimeoutException
import io.runtime.mcumgr.transfer.DownloadCallback
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class PrototypeChunkedDownloadTest {
    private val truth = ByteArray(1050) { it.toByte() }

    private class Result : DownloadCallback {
        var bytes: ByteArray? = null
        var failure: McuMgrException? = null
        var cancelled = false
        override fun onDownloadProgressChanged(current: Int, total: Int, timestamp: Long) {}
        override fun onDownloadFailed(error: McuMgrException) { failure = error }
        override fun onDownloadCanceled() { cancelled = true }
        override fun onDownloadCompleted(data: ByteArray) { bytes = data }
    }

    @Test fun retriesATimedOutChunkAndCompletes() {
        var timeouts = 2
        val result = Result()
        PrototypeChunkedDownload(truth.size, { offset ->
            if (offset == 500 && timeouts-- > 0) throw McuMgrTimeoutException()
            truth.copyOfRange(offset, minOf(truth.size, offset + 100))
        }).run(result)
        assertArrayEquals(truth, result.bytes)
    }

    @Test fun failsAfterBoundedAttempts() {
        var reads = 0
        val result = Result()
        PrototypeChunkedDownload(truth.size, { offset ->
            reads++
            if (offset == 300) throw McuMgrTimeoutException()
            truth.copyOfRange(offset, minOf(truth.size, offset + 100))
        }, attempts = 3).run(result)
        assertTrue(result.failure is McuMgrTimeoutException)
        assertEquals(3 + 3, reads)
    }

    @Test fun cancelStopsTheDownload() {
        val result = Result()
        lateinit var download: PrototypeChunkedDownload
        download = PrototypeChunkedDownload(truth.size, { offset ->
            if (offset == 200) download.cancel()
            truth.copyOfRange(offset, minOf(truth.size, offset + 100))
        })
        download.run(result)
        assertTrue(result.cancelled)
        assertEquals(null, result.bytes)
    }
}
