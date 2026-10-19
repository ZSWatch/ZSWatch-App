package dev.zswatch.app.companion

import io.runtime.mcumgr.McuMgrTransport
import io.runtime.mcumgr.exception.McuMgrException
import io.runtime.mcumgr.managers.FsManager
import io.runtime.mcumgr.response.fs.McuMgrFsDownloadResponse
import io.runtime.mcumgr.response.fs.McuMgrFsSha256Response

class FileChunkMismatchException(message: String) : McuMgrException(message)

/** Check chunks before the SDK copies them into its download buffer. */
class CheckedFsManager(
    transport: McuMgrTransport,
    private val expectedSize: Int,
    private val trace: (requested: Int, returned: Int, data: ByteArray) -> Unit,
) : FsManager(transport) {
    override fun download(name: String, offset: Int): McuMgrFsDownloadResponse {
        // FsManager.download hard-codes SHORT_TIMEOUT (2.5 s). At a 495 ms
        // connection interval, the first 2.4 KB response can outlive that window.
        // Use one bounded request; do not retry a partial SMP response in-place.
        val response = send(OP_READ, 0, mapOf<String, Any>("name" to name, "off" to offset),
            10000L, McuMgrFsDownloadResponse::class.java)
        if (!response.isSuccess) return response
        val data = response.data ?: throw FileChunkMismatchException("File chunk data missing at $offset")
        trace(offset, response.off, data)
        if (response.off != offset) throw FileChunkMismatchException("File chunk offset mismatch: requested=$offset returned=${response.off}")
        if (offset < 0 || offset >= expectedSize || data.isEmpty() || data.size > expectedSize - offset)
            throw FileChunkMismatchException("File chunk bounds mismatch: offset=$offset bytes=${data.size} expected=$expectedSize")
        if (offset == 0 && response.len != expectedSize)
            throw FileChunkMismatchException("File length mismatch: returned=${response.len} expected=$expectedSize")
        return response
    }

    /** SHA-256 of a file range. The SDK's blocking variant uses a 2.5 s timeout,
     * shorter than the watch needs to hash a large part of a recording. */
    fun rangeSha256(name: String, offset: Int, length: Int): McuMgrFsSha256Response =
        send(OP_READ, 2, mapOf<String, Any>("name" to name, "type" to "sha256", "off" to offset, "len" to length),
            30000L, McuMgrFsSha256Response::class.java)
}
