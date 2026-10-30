package dev.zswatch.app.companion

import io.runtime.mcumgr.McuMgrCallback
import io.runtime.mcumgr.McuMgrTransport
import io.runtime.mcumgr.managers.FsManager
import io.runtime.mcumgr.response.fs.McuMgrFsStatusResponse

/** The first file request may include a transition from the watch's slow BLE interval. */
internal class DiagnosticFsManager(transport: McuMgrTransport) : FsManager(transport) {
    override fun status(name: String, callback: McuMgrCallback<McuMgrFsStatusResponse>) {
        // The SDK uses 2.5 s here, unlike our bounded 10 s file reads. A cold
        // coredump download can time out before the connection interval changes.
        send(OP_READ, 1, mapOf<String, Any>("name" to name), 10000L,
            McuMgrFsStatusResponse::class.java, callback)
    }
}
