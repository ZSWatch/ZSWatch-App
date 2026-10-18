@file:Suppress("DEPRECATION", "MissingPermission")
package dev.zswatch.app.companion

import android.bluetooth.*
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Handler
import androidx.core.content.ContextCompat
import dev.zswatch.app.LifecycleLogger
import io.runtime.mcumgr.ble.McuMgrBleTransport
import io.runtime.mcumgr.ble.exception.McuMgrNotSupportedException
import io.runtime.mcumgr.McuMgrCallback
import io.runtime.mcumgr.McuMgrTransport
import io.runtime.mcumgr.managers.ImageManager
import io.runtime.mcumgr.managers.DefaultManager
import io.runtime.mcumgr.response.dflt.McuMgrOsResponse
import io.runtime.mcumgr.response.img.McuMgrImageStateResponse
import io.runtime.mcumgr.managers.FsManager
import io.runtime.mcumgr.response.fs.McuMgrFsStatusResponse
import io.runtime.mcumgr.managers.ShellManager
import io.runtime.mcumgr.response.shell.McuMgrExecResponse
import io.runtime.mcumgr.exception.McuMgrException
import io.runtime.mcumgr.transfer.FileUploader
import io.runtime.mcumgr.transfer.UploadCallback
import io.runtime.mcumgr.transfer.DownloadCallback
import io.runtime.mcumgr.transfer.TransferController
import org.json.JSONObject
import java.util.ArrayDeque
import java.util.TimeZone
import java.util.UUID

/** All state, file IO and GATT operations run on the service's worker handler. */
class NativePrototypeTransport(private val context: Context, private val handler: Handler,
                               private val store: PrototypeStore, private val files: ReceiptFiles) : PrototypeTransport {
    lateinit var runtime: PrototypeRuntime
    var mediaReady: (Long) -> Unit = {}
    var mediaClosed: () -> Unit = {}
    var mediaControl: (JSONObject, Long) -> Unit = { _, _ -> }
    internal var healthReceive: (JSONObject, Long) -> Unit = { _, _ -> }
    var gpsReady: (Long) -> Unit = {}
    var gpsClosed: () -> Unit = {}
    var gpsRequest: (JSONObject, Long) -> Unit = { _, _ -> }
    internal var firmwareBusy: () -> Boolean = { false }
    internal var firmwareReady: (String) -> Unit = {}
    internal var firmwareCheckPreparing = false
        private set
    private var closing = false
    private val smpPreparation: PrototypeSmpPreparation = PrototypeSmpPreparation(
        current = {
            val state = store.control()
            PrototypeSmpSession((state["generation"] as Number).toLong(), state["address"] as? String,
                state["desired_running"] == true,
                runtime.owns(token) && state["phase"] == "ready",
                fileTransport?.isReady == true)
        },
        later = { delay, action -> handler.postDelayed(action, delay) },
        enable = { command("GB({\"t\":\"smp\",\"status\":true})") },
        connect = { generation, done ->
            val transport = mcuTransport(store.control()["address"] as String, generation)
            // Nordic owns SMP discovery/readiness. NUS's service list may be
            // cached even after its own recovery; do not inspect it for SMP.
            transport.connect(object : McuMgrTransport.ConnectionCallback {
                override fun onConnected() { handler.post { done(Result.success(Unit)) } }
                override fun onDeferred() { handler.post {
                    done(Result.failure(IllegalStateException("Nordic connection deferred")))
                } }
                override fun onError(error: Throwable) { handler.post {
                    done(Result.failure(if (error is McuMgrNotSupportedException) PrototypeSmpServicePending()
                        else IllegalStateException(error.javaClass.simpleName)))
                    if (error is McuMgrNotSupportedException) refreshStaleGatt(generation)
                } }
            })
        },
        prepared = { generation ->
            smpRefreshAttempts = 0
            smpIdleLease.hold(generation)
            smpIdleLease.idle(generation)
            // If UI leaves after preparation, queued background recordings must
            // not remain blocked waiting for an executeShell call that never arrives.
            handler.postDelayed({ if (runtime.owns(generation)) safely { downloadNext() } }, 100)
        },
    )
    private val smpIdleLease: PrototypeSmpIdleLease = PrototypeSmpIdleLease(
        { delay, action -> handler.postDelayed(action, delay) },
        { generation ->
            if (!closing && generation == token && runtime.owns(generation) &&
                store.control()["phase"] == "ready" && !restart.busy && !smpPreparation.busy && !shellOperation.busy && !logFiles.busy && !watchface.busy && !firmwareBusy() && !downloading) safely {
                val previous = fileTransport; fileTransport = null
                previous?.release()
                command("GB({\"t\":\"smp\",\"status\":false})")
            }
        })
    private val shellOperation: PrototypeShellOperation = PrototypeShellOperation(
        owns = { generation -> runtime.owns(generation) && token == generation && store.control()["phase"] == "ready" },
        later = { delay, action -> handler.postDelayed(action, delay) },
        enable = { generation, enabled ->
            val warm = smpIdleLease.held(generation)
            smpIdleLease.hold(generation)
            if (warm) enabled() else command("GB({\"t\":\"smp\",\"status\":true})", enabled)
        },
        execute = { text, done ->
            val generation = token
            val parts = text.trim().split(Regex("\\s+"))
            val address = store.control()["address"] as String
            // The same Nordic SDK transport/factory as native recording work.
            // This matches the existing fork's ShellManagerPlugin exec contract.
            ShellManager(mcuTransport(address, generation)).exec(parts.first(),
                parts.drop(1).takeIf { it.isNotEmpty() }?.toTypedArray(),
                object : McuMgrCallback<McuMgrExecResponse> {
                    override fun onResponse(response: McuMgrExecResponse) { handler.post {
                        done(runCatching {
                            val output = response.o ?: ""
                            check(response.isSuccess) { "Shell management request failed" }
                            check(output.length <= 65536) { "Shell output too large" }
                            PrototypeShellReply(output, response.ret.toLong())
                        })
                    } }
                    override fun onError(error: McuMgrException) { handler.post {
                        done(Result.failure(IllegalStateException(error.javaClass.simpleName)))
                    } }
                })
        },
        release = { generation ->
            if (generation == token) {
                if (!closing && runtime.owns(generation) && store.control()["phase"] == "ready") {
                    // Screen attachment does not own this lease. The monitor can
                    // reuse it; inactivity or owner Stop/disconnect releases it.
                    smpIdleLease.idle(generation)
                    handler.postDelayed({ if (runtime.owns(generation)) safely { downloadNext() } }, 100)
                }
            }
        },
    )

    private val restart = PrototypeWatchRestart(
        owns = { generation -> runtime.owns(generation) && token == generation && store.control()["phase"] == "ready" },
        later = { delay, action -> handler.postDelayed(action, delay) },
        prepare = { generation, done -> prepareSmp(generation, done) },
        send = { generation, done ->
            smpIdleLease.hold(generation)
            DefaultManager(mcuTransport(store.control()["address"] as String, generation)).reset(
                object : McuMgrCallback<McuMgrOsResponse> {
                    override fun onResponse(response: McuMgrOsResponse) { handler.post {
                        done(if (response.isSuccess) Result.success(Unit)
                            else Result.failure(IllegalStateException("Restart rejected by watch")))
                    } }
                    override fun onError(error: McuMgrException) { handler.post {
                        done(Result.failure(IllegalStateException(error.javaClass.simpleName + "; reset was not retried")))
                    } }
                })
        },
        release = { generation ->
            if (!closing && runtime.owns(generation) && token == generation && store.control()["phase"] == "ready") {
                smpIdleLease.idle(generation)
                handler.postDelayed({ if (runtime.owns(generation)) safely { downloadNext() } }, 100)
            }
        },
    )

    internal fun restartWatch(generation: Long, done: (Result<Unit>) -> Unit) {
        check(!firmwareBusy() && !downloading && !smpPreparation.busy && !shellOperation.busy && !logFiles.busy && !watchface.busy) { "Another SMP operation is running" }
        restart.start(generation, done)
    }

    internal fun executeShell(generation: Long, text: String, done: (Result<PrototypeShellReply>) -> Unit) {
        check(!restart.busy) { "Restart is running" }
        check(!firmwareBusy()) { "Firmware operation is running" }
        check(!smpPreparation.busy) { "SMP preparation is running" }
        check(!logFiles.busy && !watchface.busy) { "Another SMP operation is running" }
        check(!downloading) { "Recording transfer is running; retry afterward" }
        shellOperation.start(generation, text, done)
    }

    internal fun prepareShell(generation: Long, done: (Result<Long>) -> Unit) {
        check(!restart.busy) { "Restart is running" }
        check(!firmwareBusy()) { "Firmware operation is running" }
        prepareSmp(generation, done)
    }

    private fun prepareSmp(generation: Long, done: (Result<Long>) -> Unit) {
        check(!downloading && !shellOperation.busy && !logFiles.busy && !watchface.busy) { "SMP operation is running" }
        smpPreparation.start(generation) { result ->
            if (result.isFailure && runtime.owns(token) && store.control()["phase"] == "ready") {
                val session = token
                smpIdleLease.hold(session)
                smpIdleLease.idle(session)
                handler.postDelayed({ if (runtime.owns(session)) safely { downloadNext() } }, 100)
            }
            done(result)
        }
    }
    private var logTransfer: TransferController? = null
    private val logFiles = PrototypeLogFiles(
        owns = { generation -> runtime.owns(generation) && token == generation && store.control()["phase"] == "ready" },
        later = { delay, action -> handler.postDelayed(action, delay) },
        status = { path, done ->
            FsManager(mcuTransport(store.control()["address"] as String, token)).status(path,
                object : McuMgrCallback<McuMgrFsStatusResponse> {
                    override fun onResponse(response: McuMgrFsStatusResponse) { handler.post {
                        done(PrototypeLogStatus.response(response))
                    } }
                    override fun onError(error: McuMgrException) { handler.post {
                        done(PrototypeLogStatus.failure(error))
                    } }
                })
        },
        download = { path, size, done ->
            logTransfer = CheckedFsManager(mcuTransport(store.control()["address"] as String, token), size) { _, _, _ -> }
                .fileDownload(path, object : DownloadCallback {
                    override fun onDownloadProgressChanged(current: Int, total: Int, timestamp: Long) {}
                    override fun onDownloadCompleted(bytes: ByteArray) { handler.post { done(Result.success(bytes)) } }
                    override fun onDownloadFailed(error: McuMgrException) { handler.post {
                        done(Result.failure(IllegalStateException(error.javaClass.simpleName)))
                    } }
                    override fun onDownloadCanceled() { handler.post { done(Result.failure(IllegalStateException("Log download cancelled"))) } }
                })
        },
        release = { generation ->
            val previous = logTransfer; logTransfer = null
            runCatching { previous?.cancel() }
            if (!closing && runtime.owns(generation) && token == generation && store.control()["phase"] == "ready") {
                smpIdleLease.idle(generation)
                handler.postDelayed({ if (runtime.owns(generation)) safely { downloadNext() } }, 100)
            }
        },
    )

    internal fun inspectLogs(generation: Long, path: String?, done: (Result<PrototypeLogReply>) -> Unit) {
        require(path == null || path in PrototypeLogFiles.paths) { "Only known log paths are supported" }
        readDiagnosticFile(generation, path, done)
    }

    private fun readDiagnosticFile(generation: Long, path: String?, done: (Result<PrototypeLogReply>) -> Unit) {
        check(!restart.busy) { "Restart is running" }
        check(!firmwareBusy()) { "Firmware operation is running" }
        check(!downloading && !smpPreparation.busy && !shellOperation.busy && !watchface.busy) { "SMP operation is running" }
        check(fileTransport?.isReady == true && smpIdleLease.held(generation)) { "Prepare SMP first" }
        // Validate before taking the lease so invalid requests cannot suppress cleanup.
        require(path == null || path in PrototypeLogFiles.paths || path == PrototypeLogFiles.COREDUMP_PATH)
        check(!logFiles.busy && !watchface.busy) { "Another SMP operation is running" }
        check(runtime.owns(generation) && token == generation && store.control()["phase"] == "ready") { "Current Ready session required" }
        smpIdleLease.hold(generation)
        logFiles.start(generation, path, done)
    }

    internal fun downloadCoredump(generation: Long, done: (Result<PrototypeLogReply>) -> Unit) {
        prepareShell(generation) { prepared -> prepared.fold({ current ->
            try { readDiagnosticFile(current, PrototypeLogFiles.COREDUMP_PATH, done) }
            catch (error: Exception) { done(Result.failure(error)) }
        }, { done(Result.failure(it)) }) }
    }

    internal fun inspectCoredump(generation: Long, erase: Boolean, done: (Result<Unit>) -> Unit) {
        fun summary(current: Long) {
            try { executeShell(current, "coredump summary") { reply ->
                done(reply.mapCatching {
                    val packet = PrototypeCoredumpSummary.packet(it.output, it.returnCode)
                    if (erase) check(!packet.getBoolean("available")) { "Watch still has a coredump" }
                    check(PrototypeWatchInfo(store).receive(packet, current, System.currentTimeMillis())) {
                        "Watch connection changed"
                    }
                    Unit
                })
            } } catch (error: Exception) { done(Result.failure(error)) }
        }
        prepareShell(generation) { prepared -> prepared.fold({ current ->
            if (!erase) summary(current)
            else try { executeShell(current, "coredump erase 0") { reply ->
                reply.fold({
                    if (it.returnCode != 0L) done(Result.failure(IllegalStateException("Coredump erase command failed")))
                    else summary(current)
                }, { done(Result.failure(it)) })
            } } catch (error: Exception) { done(Result.failure(error)) }
        }, { done(Result.failure(it)) }) }
    }

    private var watchfaceTransfer: TransferController? = null
    private val watchface: PrototypeWatchface = PrototypeWatchface(
        owns = { generation -> runtime.owns(generation) && token == generation && store.control()["phase"] == "ready" },
        now = android.os.SystemClock::elapsedRealtime,
        later = { delay, action -> handler.postDelayed(action, delay) },
        upload = { bytes, progress, done ->
            val sdk = mcuTransport(store.control()["address"] as String, token)
            sdk.setLoggingEnabled(false)
            val manager = FsManager(sdk)
            if (sdk.maxPacketLength > 0) manager.setUploadMtu(sdk.maxPacketLength)
            android.util.Log.i("ZSWCompanionBle", "watchface_upload max_packet=${sdk.maxPacketLength} window=3")
            // Preserve the existing user fork's windowed Nordic upload settings.
            // No legacy Flutter-engine transport or raw payload logger is needed.
            watchfaceTransfer = FileUploader(manager, "/user/bg_new.bin", bytes, 3, 4)
                .uploadAsync(object : UploadCallback {
                    override fun onUploadProgressChanged(current: Int, total: Int, timestamp: Long) { handler.post { progress(current, total) } }
                    override fun onUploadCompleted() { handler.post { done(Result.success(Unit)) } }
                    override fun onUploadCanceled() { handler.post { done(Result.failure(IllegalStateException("Cancelled"))) } }
                    override fun onUploadFailed(error: McuMgrException) { handler.post { done(Result.failure(error)) } }
                })
        },
        verify = { expected, current, done ->
            val generation = token
            val sdk = mcuTransport(store.control()["address"] as String, generation)
            sdk.setLoggingEnabled(true)
            FsManager(sdk).status("/user/bg_new.bin", object : McuMgrCallback<McuMgrFsStatusResponse> {
                override fun onResponse(response: McuMgrFsStatusResponse) { handler.post {
                    if (!runtime.owns(generation) || !current()) return@post
                    if (!response.isSuccess || response.len != expected.size) {
                        done(Result.failure(IllegalStateException("Upload size mismatch"))); return@post
                    }
                    try { watchfaceTransfer = CheckedFsManager(sdk, expected.size) { _, _, _ -> }
                        .fileDownload("/user/bg_new.bin", object : DownloadCallback {
                            override fun onDownloadProgressChanged(current: Int, total: Int, timestamp: Long) {}
                            override fun onDownloadCompleted(bytes: ByteArray) { handler.post {
                                done(runCatching { check(bytes.contentEquals(expected)) { "Upload bytes mismatch" } })
                            } }
                            override fun onDownloadCanceled() { handler.post { done(Result.failure(IllegalStateException("Cancelled"))) } }
                            override fun onDownloadFailed(error: McuMgrException) { handler.post { done(Result.failure(error)) } }
                        }) } catch (error: Exception) { done(Result.failure(error)) }
                } }
                override fun onError(error: McuMgrException) { handler.post { done(Result.failure(error)) } }
            })
        },
        send = { generation, action, mayStart ->
            if (runtime.owns(generation) && token == generation && store.control()["phase"] == "ready" && writes.size < 16) {
                writes.add(NusWrite("GB({\"t\":\"watchface_bg\",\"action\":\"$action\"})".toByteArray(Charsets.UTF_8), {}, payloadSize, mayStart))
                safely { pump() }; true
            } else false
        },
        observe = { state -> store.update("watchface_" + state.phase, mapOf("watchface_operation" to mapOf(
            "id" to state.id, "address" to store.control()["address"], "generation" to state.generation,
            "action" to state.action, "phase" to state.phase, "current" to state.current,
            "total" to state.total, "name" to state.name, "error" to state.error,
            "application_uncertain" to state.applicationUncertain))) },
        release = { generation ->
            val previous = watchfaceTransfer; watchfaceTransfer = null
            runCatching { previous?.cancel() }
            if (!closing && runtime.owns(generation) && token == generation && store.control()["phase"] == "ready") {
                fileTransport?.setLoggingEnabled(true)
                smpIdleLease.idle(generation)
                handler.postDelayed({ if (runtime.owns(generation)) safely { downloadNext() } }, 100)
            }
        },
    )

    internal fun startWatchface(generation: Long, bytes: ByteArray, name: String): String {
        check(!restart.busy) { "Restart is running" }
        check(!firmwareBusy()) { "Firmware operation is running" }
        PrototypeWatchface.validateImage(bytes)
        require(name.isNotBlank() && name.length <= 64 && name.none { it.isISOControl() })
        check(!downloading && !smpPreparation.busy && !shellOperation.busy && !logFiles.busy && !watchface.busy) { "Another SMP operation is running" }
        check(runtime.owns(generation) && token == generation && store.control()["phase"] == "ready") { "Current Ready session required" }
        check(fileTransport?.isReady == true && smpIdleLease.held(generation)) { "Prepare SMP first" }
        watchface.requireStart(generation, "apply")
        smpIdleLease.hold(generation)
        return watchface.startUpload(generation, bytes, name)
    }
    internal fun resetWatchface(generation: Long): String {
        check(!restart.busy) { "Restart is running" }
        check(!firmwareBusy()) { "Firmware operation is running" }
        check(!downloading && !smpPreparation.busy && !shellOperation.busy && !logFiles.busy && !watchface.busy) { "Another operation is running" }
        watchface.requireStart(generation, "reset")
        if (smpIdleLease.held(generation)) smpIdleLease.hold(generation)
        return watchface.reset(generation)
    }

    /** Transfer the existing prepared SDK connection without a physical disconnect gap. */
    internal fun takeFirmwareTransport(generation: Long): McuMgrBleTransport {
        check(!restart.busy) { "Restart is running" }
        check(!firmwareBusy() && !downloading && !smpPreparation.busy && !shellOperation.busy && !logFiles.busy && !watchface.busy) { "Another SDK operation is running" }
        check(runtime.owns(generation) && token == generation && store.control()["phase"] == "ready") { "Current Ready session required" }
        check(fileTransport?.isReady == true && smpIdleLease.held(generation)) { "Prepare SMP first" }
        val sdk = fileTransport!!
        fileTransport = null
        smpIdleLease.close()
        return sdk
    }

    /** After Nordic's reset, enable SMP through fresh NUS and read actual active image hashes. */
    internal fun verifyFirmwareTargets(targets: List<FirmwareTarget>, current: () -> Boolean, done: (Result<Unit>) -> Unit, resource: ResourceTarget? = null) {
        check(firmwareBusy() && current()) { "Current firmware verification required" }
        firmwareCheckPreparing = true
        try { prepareSmp(token) { prepared ->
            if (!current()) return@prepareSmp
            firmwareCheckPreparing = false
            prepared.fold({ generation ->
                try {
                    smpIdleLease.hold(generation)
                    val sdk = mcuTransport(store.control()["address"] as String, generation)
                    fun resources(result: Result<Unit>) {
                        if (!runtime.owns(generation) || !current()) return
                        if (result.isFailure || resource == null) { done(result); return }
                        // Full SHA-256/layout readback already passed before reset.
                        // Firmware mounts full_fs only with a valid header/trailer;
                        // check the fresh mounted length without downloading it twice.
                        FsManager(sdk).status(ResourceSdkContract.PATH, object : McuMgrCallback<McuMgrFsStatusResponse> {
                            override fun onResponse(response: McuMgrFsStatusResponse) { handler.post {
                                if (!runtime.owns(generation) || fileTransport !== sdk || !current()) return@post
                                safely { done(runCatching {
                                    check(response.isSuccess && response.len == resource.bytes) { "Resource mount after reboot differs from selection" }
                                }) }
                            } }
                            override fun onError(error: McuMgrException) { handler.post {
                                if (runtime.owns(generation) && fileTransport === sdk && current()) safely { done(Result.failure(error)) }
                            } }
                        })
                    }
                    if (targets.isEmpty()) resources(Result.success(Unit))
                    else ImageManager(sdk).list(object : McuMgrCallback<McuMgrImageStateResponse> {
                        override fun onResponse(response: McuMgrImageStateResponse) { handler.post {
                            if (!runtime.owns(generation) || !current()) return@post
                            safely { resources(runCatching { FirmwareSdkContract.checkActive(targets, response) }) }
                        } }
                        override fun onError(error: McuMgrException) { handler.post {
                            if (runtime.owns(generation) && current()) safely { done(Result.failure(error)) }
                        } }
                    })
                } catch (error: Exception) { done(Result.failure(error)) }
            }, { done(Result.failure(it)) })
        } } catch (error: Exception) { firmwareCheckPreparing = false; throw error }
    }

    internal fun finishFirmwareCheck() {
        firmwareCheckPreparing = false
        if (runtime.owns(token) && store.control()["phase"] == "ready") {
            if (smpIdleLease.held(token)) smpIdleLease.idle(token)
            handler.postDelayed({ safely { downloadNext() } }, 100)
        }
    }

    private val findWatch = PrototypeFindWatch(android.os.SystemClock::elapsedRealtime,
        { delay, action -> handler.postDelayed(action, delay) }, ::sendFindWatch,
        { generation, state ->
            if (runtime.owns(generation) && store.control()["phase"] == "ready") {
                store.update("find_watch_$state", mapOf("last_find_watch" to mapOf(
                    "address" to store.control()["address"], "generation" to generation,
                    "state" to state, "utc_ms" to System.currentTimeMillis())))
            }
        })

    fun findWatch(generation: Long) {
        check(runtime.owns(generation) && store.control()["phase"] == "ready") { "Current Ready session required" }
        findWatch.start(generation)
    }

    private fun sendFindWatch(generation: Long, enabled: Boolean, mayStart: () -> Boolean, done: () -> Unit): Boolean {
        if (generation != token || !runtime.owns(generation) || store.control()["phase"] != "ready") return false
        if (enabled && writes.size >= 14) return false
        val item = NusWrite("GB({\"t\":\"find\",\"n\":$enabled})".toByteArray(Charsets.UTF_8), done, payloadSize, mayStart)
        if (enabled) writes.add(item)
        else {
            // One bounded stop/reset may exceed the normal cap by one. Never
            // preempt an in-flight packet: its remaining fragments must finish.
            enqueueFindStop(writes, writing, item)
        }
        safely { pump() }
        return runtime.owns(generation) && store.control()["phase"] == "ready"
    }
    private var gatt: BluetoothGatt? = null
    private var tx: BluetoothGattCharacteristic? = null
    private var token = 0L
    private var operation = 0L
    private var retryDelay = 5000L
    val liveLogs = CompanionLiveLogs(PrototypeHub::publishLiveLog)
    internal val sensors = PrototypeSensors(PrototypeHub::publishSensor)
    private var sensorDescriptor: BluetoothGattDescriptor? = null
    internal fun setSensor(generation: Long, name: String, enabled: Boolean, done: (Result<Unit>) -> Unit) {
        check(generation == token && runtime.owns(generation) && store.control()["phase"] == "ready") { "Current Ready session required" }
        if (enabled) check(PrototypeHub.sensorObservers.isNotEmpty()) { "Open the sensor view first" }
        sensors.request(name, enabled, done)
        pump()
    }
    internal fun stopSensors() { sensors.stopAll(); safely { pump() } }
    private val framer = NusJsonFramer(log = liveLogs::receive)
    private val writes = ArrayDeque<NusWrite>()
    private var payloadSize = 20
    private var awaitingMtu = false
    private var linkConnected = false
    private var servicesHandled = false
    private var bonding: PrototypeBonding? = null
    private var bondReceiver: BroadcastReceiver? = null
    private val recordingInbox = PrototypeRecordingInbox(store) {
        // Subscription completion always requests a list, including for early hints.
        if (store.control()["phase"] == "ready") requestRecordings(deferIfFull = true)
    }
    // Watch- and system-initiated requests wait for queue room instead of
    // treating a full queue as a lost link. Sent from writeFinished().
    private var timeSyncDeferred = false
    private var recordingListDeferred = false
    private var writing = false
    private var noResponse = false
    private var fileTransport: McuMgrBleTransport? = null
    private var transfer: TransferController? = null
    private var downloading = false
    private var fileOperation = 0L
    private var notificationWriting = false
    private var readingBattery = false
    private val httpExecutor = HttpUrlRelayExecutor { action -> handler.post(action) }
    private val httpRelay: PrototypeHttpRelay = PrototypeHttpRelay(
        now = { android.os.SystemClock.elapsedRealtime() },
        later = { delay, action -> handler.postDelayed(action, delay) },
        execute = httpExecutor::execute,
        enabled = { PrototypeHttpRelay.enabled(store) },
        send = { packet, deadline, done ->
            if (!runtime.owns(token) || store.control()["phase"] != "ready" || writes.size >= 16) false
            else {
                val bytes = packet.toByteArray(Charsets.UTF_8)
                val reserve = maxOf(500L, ((bytes.size + payloadSize - 1) / payloadSize) * 40L)
                writes.add(NusWrite(bytes, done, payloadSize) {
                    android.os.SystemClock.elapsedRealtime() + reserve < deadline
                })
                pump(); true
            }
        },
        observe = { kind, generation, outcome ->
            store.update("http_$kind", mapOf("http_pending_count" to httpRelay.pendingCount,
                "last_http" to mapOf("generation" to generation, "outcome" to outcome,
                    "utc_ms" to System.currentTimeMillis())))
        },
    )

    override fun connect(address: String, generation: Long) {
        close()
        token = generation
        runtime.phase(token, "connecting")
        val adapter = context.getSystemService(BluetoothManager::class.java).adapter
            ?: throw IllegalStateException("Bluetooth unavailable")
        check(adapter.isEnabled) { "Bluetooth is disabled" }
        val session = generation
        val callback = object : BluetoothGattCallback() {
            private fun accept(client: BluetoothGatt, action: () -> Unit) {
                handler.post { if (runtime.owns(session) && gatt === client) safely(action) }
            }
            override fun onConnectionStateChange(client: BluetoothGatt, status: Int, state: Int) = accept(client) {
                if (status == BluetoothGatt.GATT_SUCCESS && state == BluetoothProfile.STATE_CONNECTED) {
                    // Some Android stacks repeat CONNECTED during bonding.
                    if (linkConnected) return@accept
                    linkConnected = true
                    beginBonding(client, session)
                } else if (state == BluetoothProfile.STATE_DISCONNECTED || status != BluetoothGatt.GATT_SUCCESS) {
                    lost(session, "GATT disconnect status=$status")
                }
            }
            override fun onMtuChanged(client: BluetoothGatt, mtu: Int, status: Int) = accept(client) {
                if (status == BluetoothGatt.GATT_SUCCESS && mtu >= 23) payloadSize = mtu - 3
                if (awaitingMtu) subscribe(client, session)
            }
            override fun onServiceChanged(client: BluetoothGatt) = accept(client) {
                if (bonding != null) return@accept // No cached ATT handles have been used yet.
                // Enabling/disabling the firmware's SMP service changes ATT handles.
                // Fence the old NUS/SDK objects and rediscover on a fresh session.
                lost(session, "GATT services changed")
            }
            override fun onServicesDiscovered(client: BluetoothGatt, status: Int) = accept(client) {
                if (bonding != null) return@accept
                check(status == BluetoothGatt.GATT_SUCCESS) { "GATT discovery failed: $status" }
                if (servicesHandled) return@accept
                servicesHandled = true
                val service = client.getService(NUS) ?: error("NUS service unavailable")
                tx = service.getCharacteristic(TX) ?: error("NUS write characteristic unavailable")
                // The watch initiates MTU exchange too. Reuse that result instead
                // of issuing another request that overlaps discovery/CCCD writes.
                if (payloadSize >= 61) subscribe(client, session)
                else {
                    awaitingMtu = true
                    if (client.requestMtu(517)) {
                        val expected = ++operation
                        handler.postDelayed({
                            if (runtime.owns(session) && gatt === client && operation == expected && awaitingMtu)
                                safely { subscribe(client, session) }
                        }, 5000)
                    } else subscribe(client, session)
                }
            }
            override fun onDescriptorWrite(client: BluetoothGatt, descriptor: BluetoothGattDescriptor, status: Int) = accept(client) {
                if (descriptor.uuid != CCCD) return@accept
                if (descriptor === sensorDescriptor) {
                    sensorDescriptor = null
                    val change = sensors.current ?: return@accept
                    if (status != BluetoothGatt.GATT_SUCCESS) client.setCharacteristicNotification(descriptor.characteristic, !change.enabled)
                    sensors.complete(change, status == BluetoothGatt.GATT_SUCCESS)
                    pump()
                    return@accept
                }
                if (descriptor.characteristic.uuid != RX || store.control()["phase"] != "subscribing") return@accept
                check(status == BluetoothGatt.GATT_SUCCESS) { "CCCD write failed: $status" }
                operation++
                runtime.phase(session, "ready")
                sensors.reset(session, PrototypeSensors.specs.filter { spec ->
                    client.getService(spec.service)?.getCharacteristic(spec.characteristic)?.let {
                        it.properties and BluetoothGattCharacteristic.PROPERTY_NOTIFY != 0 && it.getDescriptor(CCCD) != null
                    } == true
                }.map { it.name }.toSet())
                retryDelay = 5000
                timeSyncDeferred = false; recordingListDeferred = false
                readInitialBattery(client, session)
                command("GB({\"t\":\"log\",\"status\":false})")
                syncTime()
                requestDeviceInfo()
                flushNotifications()
                requestRecordings()
                recoverReceipts()
                downloadNext()
                mediaReady(session)
                gpsReady(session)
                firmwareReady(address)
                val previousFind = store.control()["last_find_watch"] as? Map<*, *>
                findWatch.ready(session, previousFind?.get("address") == store.control()["address"] &&
                    previousFind?.get("state") in listOf("accepted", "start_written"))
            }
            override fun onCharacteristicChanged(client: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
                val copy = characteristic.value?.clone() ?: return
                accept(client) { if (characteristic.uuid == RX) incoming(copy) else incomingSensor(characteristic.uuid, copy) }
            }
            override fun onCharacteristicChanged(client: BluetoothGatt, characteristic: BluetoothGattCharacteristic, value: ByteArray) {
                val copy = value.clone()
                accept(client) { if (characteristic.uuid == RX) incoming(copy) else incomingSensor(characteristic.uuid, copy) }
            }
            override fun onCharacteristicWrite(client: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) = accept(client) {
                if (characteristic.uuid != TX || noResponse || !writing) return@accept
                check(status == BluetoothGatt.GATT_SUCCESS) { "NUS write failed: $status" }
                writeFinished()
            }
            override fun onCharacteristicRead(client: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) = accept(client) {
                if (characteristic.uuid == BATTERY_LEVEL) finishBatteryRead(characteristic.value ?: byteArrayOf(), status)
            }
            override fun onCharacteristicRead(client: BluetoothGatt, characteristic: BluetoothGattCharacteristic, value: ByteArray, status: Int) {
                val copy = value.clone()
                if (characteristic.uuid == BATTERY_LEVEL) accept(client) { finishBatteryRead(copy, status) }
            }
        }
        gatt = adapter.getRemoteDevice(address).connectGatt(context, false, callback, BluetoothDevice.TRANSPORT_LE)
            ?: error("GATT connection rejected")
        deadline(session, 30000, "Connection timed out")
    }

    private fun discover(client: BluetoothGatt, session: Long) {
        runtime.phase(session, "discovering")
        check(client.discoverServices()) { "GATT discovery rejected" }
        deadline(session, 15000, "Service discovery timed out")
    }

    private fun beginBonding(client: BluetoothGatt, session: Long) {
        // The previous Flutter owner bonded before discovery. Keep that order;
        // encrypted NUS CCCDs must not race the Android confirmation dialog.
        operation++ // End the connection deadline before waiting for the user.
        fun state(value: Int) = when (value) {
            BluetoothDevice.BOND_BONDED -> PrototypeBonding.State.BONDED
            BluetoothDevice.BOND_BONDING -> PrototypeBonding.State.BONDING
            else -> PrototypeBonding.State.NONE
        }
        val gate = PrototypeBonding(
            current = { runtime.owns(session) && gatt === client },
            later = { delay, action -> handler.postDelayed({ safely(action) }, delay) },
            request = {
                // The watch can initiate security between our state read and
                // createBond(). An already-started bond is not a rejection.
                client.device.createBond() || client.device.bondState != BluetoothDevice.BOND_NONE
            },
            done = { error ->
                clearBonding()
                if (error == null) discover(client, session) else lost(session, error)
            },
        )
        bonding = gate
        if (client.device.bondState != BluetoothDevice.BOND_BONDED) {
            runtime.phase(session, "bonding")
            val receiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    if (intent?.action != BluetoothDevice.ACTION_BOND_STATE_CHANGED) return
                    val device = intent.getParcelableExtra<BluetoothDevice>(BluetoothDevice.EXTRA_DEVICE) ?: return
                    if (device.address != client.device.address) return
                    val next = state(intent.getIntExtra(BluetoothDevice.EXTRA_BOND_STATE, BluetoothDevice.ERROR))
                    handler.post { if (bonding === gate && runtime.owns(session) && gatt === client) safely { gate.changed(next) } }
                }
            }
            ContextCompat.registerReceiver(context, receiver,
                IntentFilter(BluetoothDevice.ACTION_BOND_STATE_CHANGED), ContextCompat.RECEIVER_EXPORTED)
            bondReceiver = receiver
        }
        // Re-read after registration so a completion during registration is not lost.
        gate.start(state(client.device.bondState))
        if (bonding === gate && client.device.bondState == BluetoothDevice.BOND_BONDED)
            gate.changed(PrototypeBonding.State.BONDED)
    }

    private fun clearBonding() {
        bonding?.close(); bonding = null
        val receiver = bondReceiver; bondReceiver = null
        if (receiver != null) runCatching { context.unregisterReceiver(receiver) }
    }

    private fun subscribe(client: BluetoothGatt, session: Long) {
        awaitingMtu = false
        val rx = client.getService(NUS)?.getCharacteristic(RX) ?: error("NUS notify characteristic unavailable")
        check(client.setCharacteristicNotification(rx, true)) { "Notify registration failed" }
        val descriptor = rx.getDescriptor(CCCD) ?: error("NUS CCCD unavailable")
        runtime.phase(session, "subscribing")
        store.update("mtu_observed", mapOf("att_payload_bytes" to payloadSize))
        descriptor.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
        check(client.writeDescriptor(descriptor)) { "CCCD write rejected" }
        deadline(session, 15000, "CCCD subscription timed out")
    }

    private fun deadline(session: Long, delay: Long, reason: String) {
        val expected = ++operation
        handler.postDelayed({
            if (runtime.owns(session) && operation == expected) safely { lost(session, reason) }
        }, delay)
    }

    // The watch registers its SMP service on demand. Android learns about that
    // only through Service Changed, which a peer without that subscription (for
    // example after bond state drifted) never receives, so its cached GATT table
    // keeps lacking SMP. Clear the cache and reconnect like a service change.
    private var smpRefreshAttempts = 0
    private fun refreshStaleGatt(session: Long) {
        if (!runtime.owns(session) || smpRefreshAttempts >= 2) return
        smpRefreshAttempts++
        val client = gatt ?: return
        val refreshed = runCatching {
            client.javaClass.getMethod("refresh").invoke(client) as Boolean
        }.getOrDefault(false)
        android.util.Log.i("ZSWCompanionBle", "smp_gatt_refresh session=$session attempt=$smpRefreshAttempts refreshed=$refreshed")
        // Reconnect promptly so a waiting SMP preparation can still use the fresh session.
        retryDelay = 500
        lost(session, "SMP service missing from cached GATT")
    }

    private fun lost(session: Long, reason: String) {
        if (!runtime.owns(session)) return
        runtime.phase(session, "disconnected", reason)
        close()
        handler.postDelayed({
            if (runtime.owns(session)) safely { runtime.reconnect() }
        }, retryDelay)
        retryDelay = minOf(60000, retryDelay * 2)
    }

    fun syncTime(deferIfFull: Boolean = false) {
        check(store.control()["phase"] == "ready") { "NUS not ready" }
        val now = System.currentTimeMillis()
        val offset = PrototypeClockCommands.offsetHours(now, TimeZone.getDefault())
        val packets = try { PrototypeClockCommands.packets(now / 1000, offset, payloadSize) }
        catch (error: IllegalArgumentException) {
            // Keep recordings usable if this link cannot carry a complete clock command.
            store.update("time_write_failed", mapOf("last_time_error" to error.message))
            return
        }
        if (deferIfFull && runtime.owns(token) && writes.size + packets.size > 16) { timeSyncDeferred = true; return }
        check(runtime.owns(token) && writes.size + packets.size <= 16) { "NUS write queue unavailable" }
        packets.forEachIndexed { index, bytes ->
            writes.add(NusWrite(bytes, {
                if (index == packets.lastIndex) store.update("time_write_completed",
                    mapOf("last_time_write_utc_ms" to now, "last_time_error" to null,
                        "last_time_zone_offset_hours" to offset))
            }, bytes.size))
        }
        pump()
    }

    fun syncTimeIfTimezoneChanged() {
        if (!runtime.owns(token) || store.control()["phase"] != "ready" || writes.size > 14) return
        if (PrototypeClockCommands.timezoneChanged(store.control()["last_time_zone_offset_hours"],
                System.currentTimeMillis(), TimeZone.getDefault())) syncTime(deferIfFull = true)
    }

    fun requestRecordings(deferIfFull: Boolean = false) {
        if (deferIfFull && runtime.owns(token) && writes.size >= 16) { recordingListDeferred = true; return }
        command("GB({\"t\":\"voice_memo\",\"action\":\"list\"})")
    }
    private val resultSentAt = mutableMapOf<String, Long>()

    private fun voiceResultsNegotiated(): Boolean {
        val list = store.control()["recording_list"] as? Map<*, *> ?: return false
        return runtime.owns(token) && store.control()["phase"] == "ready" &&
            (list["generation"] as? Number)?.toLong() == token && list["address"] == store.control()["address"] &&
            list["result_ack_version"] == 1
    }

    fun deliverVoiceResults() {
        if (!voiceResultsNegotiated() || firmwareBusy() || writes.size >= 14) return
        val jobs = PrototypeJobs(PrototypeHub.jobJournal(context))
        val watch = store.control()["address"] as String
        val now = android.os.SystemClock.elapsedRealtime()
        for (pending in jobs.pending(watch)) {
            val envelope = JSONObject(pending.getString("payload"))
            // Metadata fixtures never leave the test harness.
            if (jobs.state(envelope.getString("job_id")).getJSONObject("spec").getString("provider") != "dart-voice-v1") continue
            val id = envelope.getString("result_id")
            if (now - (resultSentAt[id] ?: -10000L) < 10000) continue
            val recording = store.record(envelope.getString("recording_id")) ?: continue
            // Skip a result the watch cannot receive instead of blocking later ones.
            val packet = runCatching { PrototypeVoiceResult.packet(envelope, recording["filename"] as String) }
                .getOrNull() ?: continue
            val generation = token
            writes.add(NusWrite("GB($packet)".toByteArray(Charsets.UTF_8), {}, payloadSize) {
                runtime.owns(generation) && jobs.pending(watch).any { JSONObject(it.getString("payload")).getString("result_id") == id }
            })
            resultSentAt[id] = now
            pump()
            break
        }
    }

    private fun receiveVoiceResultAck(message: JSONObject) {
        if (!voiceResultsNegotiated() || message.optString("action") != "result_ack") return
        val watch = store.control()["address"] as String
        val jobs = PrototypeJobs(PrototypeHub.jobJournal(context))
        for (pending in jobs.pending(watch)) {
            val envelope = JSONObject(pending.getString("payload"))
            val recording = store.record(envelope.getString("recording_id")) ?: continue
            // An undeliverable result never matches an ACK; it must not drop the link.
            val packet = runCatching { PrototypeVoiceResult.packet(envelope, recording["filename"] as String) }
                .getOrNull() ?: continue
            if (PrototypeVoiceResult.matches(packet, message)) {
                jobs.acknowledge(watch, envelope.getString("result_id"), "accepted")
                store.update("voice_result_accepted")
                break
            }
        }
    }
    fun requestDeviceInfo() { command("GB({\"t\":\"ver\"})") }
    fun setLogStreaming(enabled: Boolean) {
        liveLogs.request(enabled) { value, done -> command("GB({\"t\":\"log\",\"status\":$value})", done) }
    }

    fun configureHttp(enabled: Boolean) {
        PrototypeHttpRelay.configure(store, enabled)
        if (!enabled) httpRelay.disable()
    }

    fun sendMedia(generation: Long, packet: String): Boolean {
        if (generation != token || !runtime.owns(generation) || store.control()["phase"] != "ready" || writes.size >= 14) return false
        if (packet.toByteArray(Charsets.UTF_8).size > 1024) return false
        command(packet) {
            store.update("media_write_completed", mapOf("last_media_write" to mapOf(
                "generation" to generation, "utc_ms" to System.currentTimeMillis())))
        }
        return true
    }

    fun sendGps(generation: Long, packet: String, mayStart: () -> Boolean, done: () -> Unit): Boolean {
        if (generation != token || !runtime.owns(generation) || store.control()["phase"] != "ready" || writes.size >= 14) return false
        val bytes = packet.toByteArray(Charsets.UTF_8)
        if (bytes.size > 1024) return false
        writes.add(NusWrite(bytes, done, payloadSize, mayStart))
        safely { pump() }
        return runtime.owns(generation) && store.control()["phase"] == "ready"
    }

    private fun readInitialBattery(client: BluetoothGatt, session: Long) {
        val battery = client.getService(BATTERY_SERVICE)?.getCharacteristic(BATTERY_LEVEL) ?: return
        readingBattery = true
        if (!client.readCharacteristic(battery)) { readingBattery = false; return }
        // NUS writes remain queued while this optional GATT operation is active.
        handler.postDelayed({
            if (runtime.owns(session) && gatt === client && readingBattery) safely {
                readingBattery = false
                store.update("battery_read_unavailable")
                pump()
            }
        }, 5000)
    }

    private fun finishBatteryRead(value: ByteArray, status: Int) {
        if (!readingBattery) return
        readingBattery = false
        if (status == BluetoothGatt.GATT_SUCCESS && value.size == 1) {
            PrototypeWatchInfo(store).receive(JSONObject().put("t", "status").put("bat", value[0].toInt() and 255),
                token, System.currentTimeMillis())
        } else store.update("battery_read_unavailable")
        pump()
    }

    private fun command(text: String, done: () -> Unit = {}) {
        check(runtime.owns(token) && store.control()["phase"] == "ready") { "NUS not ready" }
        check(writes.size < 16) { "NUS write queue full" }
        writes.add(NusWrite(text.toByteArray(Charsets.UTF_8), done, payloadSize))
        pump()
    }

    private fun pump() {
        if (writing || readingBattery || sensors.busy) return
        val client = gatt ?: return
        if (store.control()["phase"] != "ready") return
        if (pumpSensor(client)) return
        if (writes.isEmpty()) return
        val characteristic = tx ?: return
        val item = writes.first
        if (!item.mayStart()) { writes.remove(); pump(); return }
        characteristic.value = item.packet()
        noResponse = characteristic.properties and BluetoothGattCharacteristic.PROPERTY_WRITE == 0
        characteristic.writeType = if (noResponse) BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE
                                   else BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
        writing = true
        check(client.writeCharacteristic(characteristic)) { "NUS write rejected" }
        deadline(token, 10000, "NUS write timed out")
        if (noResponse) {
            val expected = operation
            val session = token
            handler.postDelayed({
                if (runtime.owns(session) && operation == expected && writing) safely { writeFinished() }
            }, 40)
        }
    }

    private fun incomingSensor(uuid: UUID, value: ByteArray) {
        if (PrototypeHub.sensorObservers.isEmpty()) return
        PrototypeSensors.specs.firstOrNull { it.characteristic == uuid }?.let { sensors.receive(it.name, value) }
    }

    private fun pumpSensor(client: BluetoothGatt): Boolean {
        val change = sensors.next() ?: return false
        val spec = PrototypeSensors.specs.first { it.name == change.name }
        val characteristic = client.getService(spec.service)?.getCharacteristic(spec.characteristic)
        val descriptor = characteristic?.getDescriptor(CCCD)
        if (descriptor == null || !client.setCharacteristicNotification(characteristic, change.enabled)) {
            sensors.complete(change, false); pump(); return true
        }
        sensorDescriptor = descriptor
        descriptor.value = if (change.enabled) BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
            else BluetoothGattDescriptor.DISABLE_NOTIFICATION_VALUE
        if (!client.writeDescriptor(descriptor)) {
            sensorDescriptor = null
            client.setCharacteristicNotification(characteristic, !change.enabled)
            sensors.complete(change, false); pump(); return true
        }
        val session = token
        handler.postDelayed({
            if (runtime.owns(session) && gatt === client && sensors.current === change)
                safely { lost(session, "Sensor CCCD write timed out") }
        }, 5000)
        return true
    }

    private fun writeFinished() {
        operation++
        writing = false
        val item = writes.peek() ?: return
        if (item.advance()) {
            writes.remove()
            // Observe completed NUS writes, never queued or failed attempts.
            if (PrototypeHub.trafficObservers.isNotEmpty()) PrototypeHub.publishTraffic("tx",
                item.bytes.toString(Charsets.UTF_8), item.bytes.size, item.chunkCount, token)
            item.done()
        }
        pump()
        if (store.control()["phase"] == "ready") {
            if (timeSyncDeferred) { timeSyncDeferred = false; syncTime(deferIfFull = true) }
            if (recordingListDeferred) { recordingListDeferred = false; requestRecordings(deferIfFull = true) }
        }
        flushNotifications()
    }

    fun flushNotifications() {
        if (notificationWriting || !runtime.owns(token) || store.control()["phase"] != "ready" || writes.size >= 14) return
        if (!dev.zswatch.app.NotificationListenerServiceImpl.isNotificationAccessEnabled(context)) return
        val inbox = PrototypeNotifications(store)
        val delivery = inbox.next(token, System.currentTimeMillis()) ?: return
        notificationWriting = true
        val session = token
        if (delivery.replace) command("GB(${JSONObject().put("t", "notify-").put("id", delivery.id)})")
        command(delivery.packet) {
            if (runtime.owns(session)) {
                inbox.written(delivery, session)
                notificationWriting = false
                flushNotifications()
            }
        }
    }

    fun setRecordingSync(enabled: Boolean) {
        store.update("recording_sync_configuration", mapOf("recording_sync_enabled" to enabled))
        if (enabled) { downloadNext(); return }
        // Disabling recording sync owns only an active recording transfer.
        // It must not release an SDK lease used by Shell or log inspection.
        if (!downloading) return
        // Fence the SDK callback before cancellation/release. Resume reconciles
        // retained pending entries and never deletes a watch recording.
        fileOperation++; downloading = false
        runCatching { transfer?.cancel() }; transfer = null
        runCatching { fileTransport?.release() }; fileTransport = null
        for ((key, metadata) in records()) if (metadata["state"] == "downloading")
            store.putRecord(key, metadata + mapOf("state" to "pending", "error" to null))
        if (runtime.owns(token) && store.control()["phase"] == "ready") command("GB({\"t\":\"smp\",\"status\":false})")
    }

    private fun incoming(bytes: ByteArray) {
        val droppedBefore = framer.droppedFrames
        val frames = framer.feed(bytes)
        if (framer.droppedFrames > droppedBefore)
            store.update("nus_incomplete_frame_discarded", detail = mapOf("count" to framer.droppedFrames - droppedBefore))
        for (text in frames) {
            // The existing framer has already removed firmware logs and joined
            // split UTF-8/JSON. Diagnostic capture does not participate in parsing.
            if (PrototypeHub.trafficObservers.isNotEmpty()) PrototypeHub.publishTraffic("rx",
                text, text.toByteArray(Charsets.UTF_8).size, 1, token)
            val message = JSONObject(text)
            // A notification may precede the CCCD completion callback. Readiness
            // sends time anyway; do not disconnect a valid subscribing link.
            if (message.optString("t") == "time" && store.control()["phase"] == "ready") syncTime(deferIfFull = true)
            PrototypeWatchInfo(store).receive(message, token, System.currentTimeMillis())
            if (message.optString("t") == "act") healthReceive(message, token)
            val dismissals = PrototypeNotifications(store).dismissalKeys(message, token, System.currentTimeMillis())
            if (dismissals.isNotEmpty()) {
                try {
                    val cancelled = dev.zswatch.app.NotificationListenerServiceImpl.dismissPrototypeNotifications(dismissals)
                    store.update("watch_notification_dismiss_requested", detail = mapOf("count" to cancelled))
                } catch (error: Exception) {
                    LifecycleLogger.log("CompanionNotifications", "dismiss_failed ${error.javaClass.simpleName}")
                }
            }
            if (store.control()["phase"] == "ready") httpRelay.receive(message, token)
            if (store.control()["phase"] == "ready") mediaControl(message, token)
            if (store.control()["phase"] == "ready") gpsRequest(message, token)
            if (message.optString("t") == "watchface_bg" && message.opt("ok") is Boolean) {
                watchface.receive(token, message.optString("action"), message.getBoolean("ok"))
            }
            recordingInbox.receive(message)
            receiveVoiceResultAck(message)
        }
        downloadNext()
    }

    private fun records(): Map<String, Map<String, Any?>> {
        @Suppress("UNCHECKED_CAST")
        return store.control()["recordings"] as Map<String, Map<String, Any?>>
    }

    private fun recoverReceipts() {
        for ((key, metadata) in records()) {
            val recovered = files.recover(key, metadata)
            if (recovered != null) {
                if (metadata["state"] != "downloaded" || metadata["sha256"] != recovered["sha256"]) store.putRecord(key, recovered)
            } else if (metadata["state"] == "downloaded" || metadata["state"] == "downloading") {
                store.putRecord(key, metadata + mapOf("state" to "pending"))
            }
        }
    }

    private fun mcuTransport(address: String, session: Long): McuMgrBleTransport {
        fileTransport?.let { return it }
        val adapter = context.getSystemService(BluetoothManager::class.java).adapter
        return object : McuMgrBleTransport(context, adapter.getRemoteDevice(address), handler) {
            private var packet = 0L
            init {
                setConnectionParametersListener { _, interval, latency, timeout ->
                    android.util.Log.i("ZSWCompanionBle", "sdk_parameters session=$session interval_units=$interval latency=$latency timeout_units=$timeout")
                }
            }
            override fun onDeviceReady() {
                super.onDeviceReady()
                android.util.Log.i("ZSWCompanionBle", "sdk_ready session=$session mtu=${getMtu()} max_packet=$maxPacketLength")
            }
            override fun getMinLogPriority() = if (traceMcuPackets) android.util.Log.INFO else android.util.Log.WARN
            override fun log(priority: Int, message: String) {
                if (!traceMcuPackets) return
                if ((message.startsWith("Sending (") || message.startsWith("Received Header (")) && message.contains(" CBOR ")) {
                    android.util.Log.d("ZSWPrototypePacket", "session=$session ${message.substringBefore(" CBOR ")}")
                    return
                }
                // The SDK supplies a hex dump here. Never forward that dump to logcat.
                // This opt-in diagnostic observes notifications before reassembly.
                if (!message.startsWith("Notification received from ") || !message.contains(", value: (0x)")) return
                val hex = message.substringAfter(", value: (0x)").trim().split('-')
                val bytes = runCatching { hex.map { it.trim().toInt(16).toByte() }.toByteArray() }.getOrNull() ?: return
                android.util.Log.d("ZSWPrototypePacket", "session=$session packet=${++packet} bytes=${bytes.size} sha256=${ReceiptFiles.sha(bytes)}")
            }
        }.also {
            fileTransport = it
            // The watch's SMP controller requests 7.5-11.25 ms. Android HIGH
            // can arrive later and replace that with 15 ms (observed on Nokia).
            // Keep the same peripheral-owned policy as the existing DFU path.
        }
    }

    private fun downloadNext() {
        if (restart.busy) return
        if (firmwareBusy() || downloading || shellOperation.busy || logFiles.busy || watchface.busy || smpPreparation.busy || !runtime.owns(token) || store.control()["phase"] != "ready") return
        if (store.control()["recording_sync_enabled"] == false) return
        val address = store.control()["address"] as String
        val pending = records().entries.firstOrNull { it.value["address"] == address && it.value["state"] == "pending" } ?: return
        val key = pending.key
        val metadata = pending.value
        files.recover(key, metadata)?.let { store.putRecord(key, it); downloadNext(); return }
        downloading = true
        smpIdleLease.hold(token)
        val session = token
        val transferId = ++fileOperation
        store.putRecord(key, metadata + mapOf("state" to "downloading"))
        command("GB({\"t\":\"smp\",\"status\":true})") {
            handler.postDelayed({
                if (runtime.owns(session) && downloading && fileOperation == transferId) safely {
                    val transport = mcuTransport(address, session)
                    val manager = CheckedFsManager(transport, (metadata["size_bytes"] as Number).toInt()) { requested, returned, data ->
                        // Hashes/offsets allow independent USB comparison without logging audio.
                        android.util.Log.d("ZSWPrototypeTransfer", "session=$session transfer=$transferId file=${metadata["filename"]} requested=$requested returned=$returned bytes=${data.size} sha256=${ReceiptFiles.sha(data)}")
                    }
                    transfer = manager.fileDownload("/user/recordings/${metadata["filename"]}.zsw_opus",
                        object : DownloadCallback {
                            private fun deliver(action: () -> Unit) { handler.post {
                                if (runtime.owns(session) && downloading && fileOperation == transferId) safely(action)
                            } }
                            override fun onDownloadProgressChanged(current: Int, total: Int, timestamp: Long) {}
                            override fun onDownloadFailed(error: McuMgrException) = deliver {
                                if (error is McuMgrNotSupportedException && smpRefreshAttempts < 2) {
                                    // SMP is missing from a stale GATT cache, not from this file:
                                    // keep the recording pending and rediscover services.
                                    fileOperation++; downloading = false; transfer = null
                                    store.putRecord(key, metadata + mapOf("state" to "pending"))
                                    refreshStaleGatt(session)
                                    return@deliver
                                }
                                val reason = if (error is FileChunkMismatchException) "${error.javaClass.simpleName}: ${error.message}" else error.javaClass.simpleName
                                finishFile(key, metadata, reason)
                            }
                            override fun onDownloadCanceled() = deliver { finishFile(key, metadata, "cancelled") }
                            override fun onDownloadCompleted(bytes: ByteArray) = deliver {
                                val receipt = try { files.publish(key, metadata, bytes) }
                                    catch (error: Exception) {
                                        finishFile(key, metadata + mapOf("received_size_bytes" to bytes.size,
                                            "received_sha256" to ReceiptFiles.sha(bytes),
                                            "received_header_hex" to bytes.take(32).joinToString("") { "%02x".format(it.toInt() and 255) }),
                                            "${error.javaClass.simpleName}: ${error.message}")
                                        return@deliver
                                    }
                                store.putRecord(key, receipt)
                                finishFile(key, receipt, null)
                                downloadNext()
                            }
                        })
                    handler.postDelayed({
                        if (runtime.owns(session) && downloading && fileOperation == transferId) safely {
                            finishFile(key, metadata, "transfer_timeout")
                        }
                    }, 300000)
                }
            }, 2000)
        }
    }

    private fun finishFile(key: String, metadata: Map<String, Any?>, error: String?) {
        fileOperation++
        downloading = false
        if (error != null) transfer?.cancel()
        transfer = null
        if (error != null) store.putRecord(key, metadata + mapOf("state" to "failed", "error" to error))
        // Keep one SDK connection/SMP lease for the pending batch. Releasing it
        // and toggling SMP between files can disconnect NUS or invalidate the
        // next transfer's handles while that transfer is already starting.
        val more = error == null && records().values.any {
            it["address"] == store.control()["address"] && it["state"] == "pending"
        }
        if (!more) {
            smpIdleLease.close()
            fileTransport?.release(); fileTransport = null
            if (runtime.owns(token) && store.control()["phase"] == "ready") command("GB({\"t\":\"smp\",\"status\":false})")
        }
        val session = token
        handler.postDelayed({ if (runtime.owns(session)) safely { downloadNext() } }, 100)
    }

    fun retryRecordings() {
        for ((key, metadata) in records()) if (metadata["state"] == "failed") {
            store.putRecord(key, metadata + mapOf("state" to "pending", "error" to null))
        }
        recoverReceipts(); requestRecordings(); downloadNext()
    }

    private fun safely(action: () -> Unit) {
        try { action() }
        catch (error: Exception) {
            LifecycleLogger.log("CompanionPrototype", "operation failed ${error.javaClass.simpleName}")
            if (runtime.owns(token)) runCatching { lost(token, "${error.javaClass.simpleName}: ${error.message}") }
                .onFailure { runtime.destroy(); LifecycleLogger.log("CompanionPrototype", "journal_failure connection_closed") }
        }
    }

    override fun close() {
        closing = true
        restart.disconnected(store.control()["desired_running"] != true)
        clearBonding()
        // Preparation can wait for one service-change reconnect, but it never
        // executes/replays a command. Persisted Stop cancels it immediately.
        if (store.control()["desired_running"] != true) smpPreparation.close()
        smpIdleLease.close()
        shellOperation.close()
        logFiles.close()
        watchface.close()
        mediaClosed()
        gpsClosed()
        findWatch.close()
        operation++; fileOperation++
        httpRelay.reset()
        writing = false; writes.clear(); downloading = false
        notificationWriting = false
        readingBattery = false
        sensorDescriptor = null
        sensors.reset(token, emptySet())
        awaitingMtu = false; payloadSize = 20
        linkConnected = false; servicesHandled = false
        runCatching { transfer?.cancel() }; transfer = null
        runCatching { fileTransport?.release() }; fileTransport = null
        val previous = gatt; gatt = null; tx = null
        runCatching { previous?.disconnect() }; runCatching { previous?.close() }
        framer.reset()
        liveLogs.reset()
        closing = false
    }

    fun dispose() { smpPreparation.close(); close(); httpExecutor.close() }

    companion object {
        @Volatile var traceMcuPackets = false
        private val NUS = UUID.fromString("6e400001-b5a3-f393-e0a9-e50e24dcca9e")
        private val TX = UUID.fromString("6e400002-b5a3-f393-e0a9-e50e24dcca9e")
        private val RX = UUID.fromString("6e400003-b5a3-f393-e0a9-e50e24dcca9e")
        private val CCCD = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
        private val BATTERY_SERVICE = UUID.fromString("0000180f-0000-1000-8000-00805f9b34fb")
        private val BATTERY_LEVEL = UUID.fromString("00002a19-0000-1000-8000-00805f9b34fb")
    }
}
