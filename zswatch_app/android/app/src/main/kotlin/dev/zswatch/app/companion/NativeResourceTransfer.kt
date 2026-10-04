package dev.zswatch.app.companion

import android.os.Handler
import io.runtime.mcumgr.McuMgrCallback
import io.runtime.mcumgr.ble.McuMgrBleTransport
import io.runtime.mcumgr.exception.McuMgrException
import io.runtime.mcumgr.managers.FsManager
import io.runtime.mcumgr.response.fs.McuMgrFsStatusResponse
import io.runtime.mcumgr.transfer.DownloadCallback
import io.runtime.mcumgr.transfer.FileUploader
import io.runtime.mcumgr.transfer.TransferController
import io.runtime.mcumgr.transfer.UploadCallback

/** Borrowed Nordic transport; release belongs to the service's package lifetime. */
internal class NativeResourceTransfer(private val handler: Handler, private val sdk: McuMgrBleTransport,
    private val target: ResourceTarget, private val current: () -> Boolean,
    private val progress: (Int, Int) -> Unit, private val uploaded: () -> Unit,
    private val done: (Result<Unit>) -> Unit) {
    private var stage = "new"
    private var transfer: TransferController? = null
    private fun deliver(expected: String, action: () -> Unit) { handler.post {
        if (stage == expected && current()) {
            try { action() } catch (error: Exception) { finish(Result.failure(error)) }
        }
    } }
    private fun finish(result: Result<Unit>) {
        if (stage == "done") return
        stage = "done"; done(result)
    }
    fun upload(bytes: ByteArray) {
        check(stage == "new" && current())
        ResourceSdkContract.check(target, bytes)
        stage = "upload"
        sdk.setLoggingEnabled(false)
        val manager = FsManager(sdk)
        if (sdk.maxPacketLength > 0) manager.setUploadMtu(sdk.maxPacketLength)
        // Existing resolved FsManagerPlugin uses window 3/alignment 4.
        transfer = FileUploader(manager, ResourceSdkContract.PATH, bytes, 3, 4).uploadAsync(object : UploadCallback {
            override fun onUploadProgressChanged(current: Int, total: Int, timestamp: Long) = deliver("upload") { progress(current, total) }
            override fun onUploadCompleted() = deliver("upload") { stage = "new"; uploaded(); verify() }
            override fun onUploadCanceled() = deliver("upload") { finish(Result.failure(IllegalStateException("Resource upload cancelled"))) }
            override fun onUploadFailed(error: McuMgrException) = deliver("upload") { finish(Result.failure(error)) }
        })
    }
    fun verify() {
        check(stage == "new" && current())
        stage = "verify"; sdk.setLoggingEnabled(true)
        FsManager(sdk).status(ResourceSdkContract.PATH, object : McuMgrCallback<McuMgrFsStatusResponse> {
            override fun onResponse(response: McuMgrFsStatusResponse) = deliver("verify") {
                check(response.isSuccess && response.len == target.bytes) { "Resource size mismatch" }
                transfer = CheckedFsManager(sdk, target.bytes) { _, _, _ -> }.fileDownload(ResourceSdkContract.PATH, object : DownloadCallback {
                    override fun onDownloadProgressChanged(current: Int, total: Int, timestamp: Long) = deliver("verify") { progress(current, total) }
                    override fun onDownloadCompleted(bytes: ByteArray) = deliver("verify") { finish(runCatching { ResourceSdkContract.check(target, bytes) }) }
                    override fun onDownloadCanceled() = deliver("verify") { finish(Result.failure(IllegalStateException("Resource check cancelled"))) }
                    override fun onDownloadFailed(error: McuMgrException) = deliver("verify") { finish(Result.failure(error)) }
                })
            }
            override fun onError(error: McuMgrException) = deliver("verify") { finish(Result.failure(error)) }
        })
    }
    fun close() {
        stage = "done"
        val old = transfer; transfer = null
        runCatching { old?.cancel() }
    }
}
