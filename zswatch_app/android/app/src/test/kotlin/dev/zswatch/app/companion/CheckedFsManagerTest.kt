package dev.zswatch.app.companion

import io.runtime.mcumgr.McuMgrCallback
import io.runtime.mcumgr.McuMgrScheme
import io.runtime.mcumgr.McuMgrTransport
import io.runtime.mcumgr.exception.McuMgrException
import io.runtime.mcumgr.managers.FsManager
import io.runtime.mcumgr.response.McuMgrResponse
import io.runtime.mcumgr.response.fs.McuMgrFsDownloadResponse
import io.runtime.mcumgr.transfer.Download
import io.runtime.mcumgr.response.DownloadResponse
import org.junit.Assert.*
import org.junit.Test
import java.util.ArrayDeque

/** Exercise the actual SDK downloader with injected wire responses, not a copy of its assembler. */
class CheckedFsManagerTest {
    private fun chunk(offset: Int, total: Int, vararg bytes: Int) = McuMgrFsDownloadResponse().apply {
        off = offset; len = total; data = bytes.map { it.toByte() }.toByteArray()
    }

    private class Responses(vararg values: McuMgrFsDownloadResponse) : McuMgrTransport {
        private val responses = ArrayDeque(values.toList())
        val timeouts = mutableListOf<Long>()
        override fun getScheme() = McuMgrScheme.BLE
        override fun <T : McuMgrResponse> send(payload: ByteArray, timeout: Long, responseType: Class<T>): T {
            timeouts.add(timeout)
            return responseType.cast(responses.removeFirst())!!
        }
        override fun <T : McuMgrResponse> send(payload: ByteArray, timeout: Long, responseType: Class<T>, callback: McuMgrCallback<T>) {
            callback.onResponse(send(payload, timeout, responseType))
        }
        override fun connect(callback: McuMgrTransport.ConnectionCallback?) { callback?.onConnected() }
        override fun release() {}
        override fun addObserver(observer: McuMgrTransport.ConnectionObserver) {}
        override fun removeObserver(observer: McuMgrTransport.ConnectionObserver) {}
    }

    private fun run(manager: FsManager): Pair<ByteArray?, McuMgrException?> {
        val download = object : Download() {
            override fun read(offset: Int): DownloadResponse = manager.download("/memo", offset)
        }
        // Run the SDK assembler synchronously; its Android ConditionVariable
        // scheduler is exercised on the phone, not replaced by a no-op JVM stub.
        return try {
            var count = 0
            do {
                assertTrue("Download did not converge", ++count <= 10)
                download.sendNext()
            } while (!download.isFinished)
            download.data!!.clone() to null
        } catch (error: McuMgrException) {
            null to error
        }
    }

    @Test fun sdkGapWouldProduceZeroFilledReceiptButCheckedDownloaderRejectsIt() {
        fun responses() = Responses(chunk(0, 8, 1, 2, 3, 4), chunk(6, 0, 7, 8))
        val unsafe = run(FsManager(responses()))
        assertNull(unsafe.second)
        assertArrayEquals(byteArrayOf(1, 2, 3, 4, 0, 0, 7, 8), unsafe.first)
        val checked = run(CheckedFsManager(responses(), 8) { _, _, _ -> })
        assertNull(checked.first)
        assertTrue(checked.second!!.message!!.contains("requested=4 returned=6"))
    }

    @Test fun contiguousChunksUseTheSdkAssemblerAndPreserveAllBytes() {
        val trace = mutableListOf<Pair<Int, Int>>()
        val result = run(CheckedFsManager(Responses(chunk(0, 8, 1, 2, 3, 4), chunk(4, 0, 5, 6, 7, 8)), 8) {
            requested, returned, _ -> trace.add(requested to returned)
        })
        assertNull(result.second)
        assertArrayEquals(byteArrayOf(1, 2, 3, 4, 5, 6, 7, 8), result.first)
        assertEquals(listOf(0 to 0, 4 to 4), trace)
    }

    @Test fun slowBleChunksHaveABoundedTenSecondTimeout() {
        val transport = Responses(chunk(0, 4, 1, 2, 3, 4))
        assertNull(run(CheckedFsManager(transport, 4) { _, _, _ -> }).second)
        assertEquals(listOf(10000L), transport.timeouts)
    }

    @Test fun overlapOrRepeatedFirstChunkCannotResetTheDownloadBuffer() {
        for (offset in listOf(0, 2)) {
            val result = run(CheckedFsManager(Responses(chunk(0, 8, 1, 2, 3, 4), chunk(offset, 8, 5, 6, 7, 8)), 8) { _, _, _ -> })
            assertNull(result.first)
            assertTrue(result.second!!.message!!.contains("requested=4 returned=$offset"))
        }
    }

    @Test fun oversizedFinalChunkCannotBeSilentlyTruncated() {
        val result = run(CheckedFsManager(Responses(chunk(0, 8, 1, 2, 3, 4), chunk(4, 0, 5, 6, 7, 8, 9)), 8) { _, _, _ -> })
        assertNull(result.first)
        assertTrue(result.second!!.message!!.contains("bounds mismatch"))
    }

    @Test fun changedFileSizeAndEmptyChunksFailBeforePublication() {
        for (response in listOf(chunk(0, 9, 1), chunk(0, 8))) {
            val result = run(CheckedFsManager(Responses(response), 8) { _, _, _ -> })
            assertNull(result.first)
            assertNotNull(result.second)
        }
    }
}
