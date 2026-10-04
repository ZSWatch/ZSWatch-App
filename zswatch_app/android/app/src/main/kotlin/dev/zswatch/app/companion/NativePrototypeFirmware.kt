package dev.zswatch.app.companion

import android.os.Handler
import android.os.SystemClock
import dev.zswatch.app.LifecycleLogger
import io.runtime.mcumgr.ble.McuMgrBleTransport
import io.runtime.mcumgr.dfu.FirmwareUpgradeCallback
import io.runtime.mcumgr.dfu.FirmwareUpgradeController
import io.runtime.mcumgr.dfu.mcuboot.FirmwareUpgradeManager
import io.runtime.mcumgr.dfu.mcuboot.model.ImageSet
import io.runtime.mcumgr.exception.McuMgrException
import io.runtime.mcumgr.McuMgrCallback
import io.runtime.mcumgr.McuMgrTransport
import io.runtime.mcumgr.managers.DefaultManager
import io.runtime.mcumgr.response.dflt.McuMgrOsResponse
import io.runtime.mcumgr.managers.ImageManager
import io.runtime.mcumgr.response.img.McuMgrImageStateResponse
import java.util.UUID

/** Uses the same installed Nordic manager/settings as the resolved user fork.
 * Manager ownership is independent of the normal NUS transport's reboot/disconnect lifetime.
 */
internal class NativePrototypeFirmware(private val handler: Handler, private val store: PrototypeStore,
    private val runtime: PrototypeRuntime, private val link: NativePrototypeTransport) {
    private var sdk: McuMgrBleTransport? = null
    private var manager: FirmwareUpgradeManager? = null
    private var imageSet: ImageSet? = null
    private var preparationRecoveries = 0
    private var preparedResources: PreparedResources? = null
    private var resourceTransfer: NativeResourceTransfer? = null
    private var resetObserver: McuMgrTransport.ConnectionObserver? = null
    private var resourceResetAcknowledged = false
    private var sdkResetObserved = false
    private var probe: Pair<String, Long>? = null
    val busy get() = probe != null || operation.busy

    private val operation: PrototypeFirmware = PrototypeFirmware(
        owns = { state -> runtime.active && store.control()["desired_running"] == true &&
            store.control()["address"] == state.address &&
            if (state.phase in setOf("reconnecting", "verifying")) runtime.generation >= state.generation
            else runtime.owns(state.generation) && store.control()["phase"] == "upgrading" },
        now = SystemClock::elapsedRealtime,
        later = { delay, action -> handler.postDelayed({ safely(action) }, delay) },
        launch = { state ->
            resourceTransfer?.close(); resourceTransfer = null; preparedResources = null
            val transport = sdk ?: error("Prepared Nordic transport required")
            val callback = object : FirmwareUpgradeCallback<FirmwareUpgradeManager.State> {
                private fun deliver(action: () -> Unit) { handler.post {
                    if (sdk === transport && operation.state?.id == state.id) {
                        safely(action)
                    }
                } }
                override fun onUpgradeStarted(controller: FirmwareUpgradeController?) {}
                override fun onStateChanged(previous: FirmwareUpgradeManager.State?, next: FirmwareUpgradeManager.State?) = deliver {
                    if (next == FirmwareUpgradeManager.State.RESET) sdkResetObserved = true
                    val phase = when (next) {
                        FirmwareUpgradeManager.State.VALIDATE -> "validating"
                        FirmwareUpgradeManager.State.UPLOAD -> "uploading"
                        FirmwareUpgradeManager.State.TEST, FirmwareUpgradeManager.State.CONFIRM -> "applying"
                        FirmwareUpgradeManager.State.RESET -> "rebooting"
                        else -> null
                    }
                    phase?.let { operation.sdkPhase(state.id, it) }
                }
                override fun onUploadProgressChanged(current: Int, total: Int, timestamp: Long) = deliver { operation.progress(state.id, current, total) }
                override fun onUpgradeCompleted() = deliver { operation.sdkCompleted(state.id, sdkResetObserved) }
                override fun onUpgradeFailed(phase: FirmwareUpgradeManager.State?, error: McuMgrException?) = deliver { operation.fail(state.id, "sdk_failed") }
                override fun onUpgradeCanceled(phase: FirmwareUpgradeManager.State?) = deliver { operation.sdkCancelled(state.id) }
            }
            manager = FirmwareUpgradeManager(transport, callback).also {
                it.setCallbackOnUiThread(false)
                it.setMode(FirmwareUpgradeManager.Mode.CONFIRM_ONLY)
                it.start(imageSet ?: error("Parsed image set required"), FirmwareSdkContract.settings())
            }
        },
        reconnect = { state ->
            releaseSdk()
            runtime.resumeAfterFirmware(state.generation)
        },
        verify = { state, current, done ->
            preparationRecoveries = 0
            if (state.resourceResetRequested && !resourceResetAcknowledged) {
                done(Result.failure(IllegalStateException("Resource reset was not acknowledged")))
            } else link.verifyFirmwareTargets(state.targets, current, { result -> safely { done(result) } }, state.resource)
        },
        cancel = { manager?.cancel() ?: error("Active Nordic manager required") },
        observe = { state -> store.update("firmware_" + state.phase, mapOf("firmware_operation" to mapOf(
            "id" to state.id, "address" to state.address, "generation" to state.generation, "phase" to state.phase,
            "targets" to state.targets.map { mapOf("index" to it.index, "bytes" to it.bytes, "hash" to it.hash) },
            "current" to state.current, "total" to state.total, "error" to state.error,
            "result_unknown" to state.resultUnknown, "cancel_requested" to state.cancelRequested,
            "resource" to state.resource?.let { mapOf("bytes" to it.bytes, "hash" to it.hash) },
            "resource_verified" to state.resourceVerified, "resource_reset_requested" to state.resourceResetRequested, "resource_reset_acknowledged" to resourceResetAcknowledged))) },
        release = { state ->
            try { releaseSdk() } finally {
                link.finishFirmwareCheck()
                runtime.resumeAfterFirmware(state.generation)
            }
        },
        resources = { state, current, progress, uploaded, done ->
            val transport = sdk ?: error("Prepared Nordic transport required")
            val payload = preparedResources ?: error("Prepared resource payload required")
            resourceTransfer = NativeResourceTransfer(handler, transport, state.resource!!,
                { sdk === transport && current() }, { sent, total -> safely { progress(sent, total) } },
                { uploaded() }, { result -> safely { done(result) } })
            resourceTransfer!!.upload(payload.data)
        },
        resetResources = { state -> resetResourceWatch(state) },
    )

    private fun resetResourceWatch(state: PrototypeFirmwareState) {
        val transport = sdk ?: error("Prepared Nordic transport required")
        resourceTransfer?.close(); resourceTransfer = null; preparedResources = null
        resourceResetAcknowledged = false
        val observer = object : McuMgrTransport.ConnectionObserver {
            override fun onConnected() {}
            override fun onDisconnected() { handler.post {
                if (sdk === transport && operation.state?.id == state.id && operation.state?.phase == "rebooting") {
                    safely { operation.sdkCompleted(state.id) }
                }
            } }
        }
        resetObserver = observer; transport.addObserver(observer)
        handler.postDelayed({ if (sdk === transport && operation.state?.id == state.id && operation.state?.phase == "rebooting") {
            safely { operation.fail(state.id, "resource_reset_timeout") }
        } }, 15000)
        DefaultManager(transport).reset(object : McuMgrCallback<McuMgrOsResponse> {
            override fun onResponse(response: McuMgrOsResponse) { handler.post {
                if (sdk !== transport || operation.state?.id != state.id || operation.state?.phase != "rebooting") return@post
                safely {
                    if (!response.isSuccess) operation.fail(state.id, "resource_reset_failed")
                    else { resourceResetAcknowledged = true
                        store.update("resource_reset_acknowledged", mapOf("resource_reset_acknowledged" to true)) }
                }
            } }
            override fun onError(error: McuMgrException) { /* Wait for disconnect/deadline; never retry a reset. */ }
        })
    }

    fun start(generation: Long, images: List<Pair<Int, ByteArray>>, resources: ByteArray? = null): Pair<String, Long> {
        check(!busy) { "Firmware operation is running" }
        // Nordic parses MCUboot structure before disturbing the normal companion.
        // The watch bootloader still owns signature/authenticity verification.
        val parsed = if (images.isEmpty() && resources != null) emptyList() else FirmwareSdkContract.parse(images)
        val info = store.control()["watch_info"] as? Map<*, *>
        val resource = resources?.let {
            check(info?.get("address") == store.control()["address"]) { "Current watch information required" }
            ResourceSdkContract.prepare(it, info?.get("hardware_version") as? String ?: error("Known resource board required"))
        }
        val targets = parsed.map { FirmwareTarget(it.imageIndex, it.image.data.size,
            it.image.hash.joinToString("") { byte -> "%02x".format(byte) }) }
        PrototypeFirmware.validateRequest(targets, resource?.target)
        val address = store.control()["address"] as? String ?: error("Selected watch required")
        val prepared = link.takeFirmwareTransport(generation)
        sdk = prepared; imageSet = if (parsed.isEmpty()) null else ImageSet(parsed)
        preparedResources = resource; resourceResetAcknowledged = false; sdkResetObserved = false
        try {
            val ownedGeneration = runtime.beginFirmware(generation)
            return operation.start(address, ownedGeneration, targets, resource?.target) to ownedGeneration
        } catch (error: Exception) {
            try { releaseSdk() } finally { runtime.resumeAfterFirmware(runtime.generation) }
            throw error
        }
    }
    fun ready(address: String) = operation.ready(address)
    fun cancel(id: String) {
        check(manager?.state == FirmwareUpgradeManager.State.UPLOAD) { "Nordic is no longer uploading" }
        operation.requestCancel(id)
    }

    /** Debug-only read-only exercise of the real SDK handoff; never starts an upgrade manager. */
    fun inspectHandoff(generation: Long) {
        check(!busy) { "Firmware operation is running" }
        sdk = link.takeFirmwareTransport(generation)
        try {
            val owned = runtime.beginFirmware(generation)
            val id = UUID.randomUUID().toString(); probe = id to owned
            store.update("firmware_handoff_probe", mapOf("firmware_handoff_probe" to mapOf("id" to id,
                "generation" to owned, "phase" to "reading", "read_only" to true)))
            handler.postDelayed({ if (probe?.first == id) safely { finishProbe("timeout") } }, 15000)
            ImageManager(sdk!!).list(object : McuMgrCallback<McuMgrImageStateResponse> {
                override fun onResponse(response: McuMgrImageStateResponse) { handler.post {
                    if (probe?.first != id || !runtime.owns(owned)) return@post
                    val count = if (response.isSuccess) response.images?.size else null
                    safely { finishProbe(if (count == null || count !in 1..16) "image_state_rejected" else null, count) }
                } }
                override fun onError(error: McuMgrException) { handler.post {
                    if (probe?.first == id) safely { finishProbe("sdk_failed") }
                } }
            })
        } catch (error: Exception) {
            if (probe != null) finishProbe("start_failed")
            else { releaseSdk(); runtime.resumeAfterFirmware(runtime.generation) }
            throw error
        }
    }
    private fun finishProbe(error: String?, imageCount: Int? = null) {
        val old = probe ?: return; probe = null
        try { store.update("firmware_handoff_probe", mapOf("firmware_handoff_probe" to mapOf("id" to old.first,
            "generation" to old.second, "phase" to if (error == null) "completed" else "failed",
            "read_only" to true, "error" to error, "image_count" to imageCount))) }
        finally { try { releaseSdk() } finally { runtime.resumeAfterFirmware(old.second) } }
    }

    /** Only the known single SMP-preparation recovery may retain the postflight operation. */
    fun fenced(reason: String) {
        if (probe != null) { finishProbe("interrupted"); return }
        if (reason == "reconnect" && operation.state?.phase == "verifying" && link.firmwareCheckPreparing && preparationRecoveries++ == 0) return
        operation.close()
    }
    private fun safely(action: () -> Unit) {
        try { action() } catch (error: Exception) {
            // A journal failure must release handles, not terminate the shared worker thread.
            runCatching { operation.close() }
            runCatching { finishProbe("journal_failed") }
            runCatching { runtime.destroy() }
            LifecycleLogger.log("CompanionFirmware", "operation_failed ${error.javaClass.simpleName}")
        }
    }
    private fun releaseSdk() {
        val oldResource = resourceTransfer; resourceTransfer = null; preparedResources = null
        oldResource?.close()
        val observer = resetObserver; resetObserver = null
        if (observer != null) sdk?.removeObserver(observer)
        val oldManager = manager; manager = null
        val oldSdk = sdk; sdk = null; imageSet = null
        try {
            oldManager?.setFirmwareUpgradeCallback(null)
            if (oldManager?.isInProgress == true) runCatching { oldManager.cancel() }
        } finally { oldSdk?.release() }
    }
}
