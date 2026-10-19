package dev.zswatch.app.companion

import io.runtime.mcumgr.exception.McuMgrException
import io.runtime.mcumgr.transfer.DownloadCallback
import io.runtime.mcumgr.transfer.TransferController

/**
 * Sequential file download that retries a single chunk instead of failing the file.
 *
 * The SDK's downloader gives up on the first lost response. On some Android stacks a
 * damaged notification makes one response unmatchable (it then times out), so a large
 * recording rarely completed. Calls block; run off the main thread.
 */
internal class PrototypeChunkedDownload(
    private val size: Int,
    private val read: (offset: Int) -> ByteArray,
    private val attempts: Int = 3,
) : TransferController {
    @Volatile private var cancelled = false

    override fun pause() {}
    override fun resume() {}
    override fun cancel() { cancelled = true }

    fun run(callback: DownloadCallback) {
        val bytes = ByteArray(size)
        var offset = 0
        while (offset < size) {
            var data: ByteArray? = null
            var failure: McuMgrException? = null
            for (attempt in 1..attempts) {
                if (cancelled) return callback.onDownloadCanceled()
                try {
                    data = read(offset).takeIf { it.isNotEmpty() && it.size <= size - offset }
                    if (data != null) break
                } catch (error: McuMgrException) {
                    failure = error
                }
            }
            val chunk = data ?: return callback.onDownloadFailed(failure ?: McuMgrException("Empty chunk at $offset"))
            chunk.copyInto(bytes, offset)
            offset += chunk.size
            callback.onDownloadProgressChanged(offset, size, System.currentTimeMillis())
        }
        if (cancelled) callback.onDownloadCanceled() else callback.onDownloadCompleted(bytes)
    }
}
