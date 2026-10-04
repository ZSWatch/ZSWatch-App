@file:Suppress("DEPRECATION", "MissingPermission")
package dev.zswatch.app.companion

import android.bluetooth.*
import android.content.Context
import android.os.Handler
import dev.zswatch.app.LifecycleLogger
import io.runtime.mcumgr.ble.McuMgrBleTransport
import io.runtime.mcumgr.McuMgrCallback
import io.runtime.mcumgr.McuMgrTransport
import io.runtime.mcumgr.managers.ShellManager
import io.runtime.mcumgr.response.shell.McuMgrExecResponse
import io.runtime.mcumgr.exception.McuMgrException
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
    var gpsReady: (Long) -> Unit = {}
    var gpsClosed: () -> Unit = {}
    var gpsRequest: (JSONObject, Long) -> Unit = { _, _ -> }
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
                    done(Result.failure(IllegalStateException(error.javaClass.simpleName)))
                } }
            })
        },
        prepared = { generation ->
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
                store.control()["phase"] == "ready" && !smpPreparation.busy && !shellOperation.busy && !downloading) safely {
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

    internal fun executeShell(generation: Long, text: String, done: (Result<PrototypeShellReply>) -> Unit) {
        check(!smpPreparation.busy) { "SMP preparation is running" }
        check(!downloading) { "Recording transfer is running; retry afterward" }
        shellOperation.start(generation, text, done)
    }

    internal fun prepareShell(generation: Long, done: (Result<Long>) -> Unit) {
        check(!downloading && !shellOperation.busy) { "SMP operation is running" }
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
    private val framer = NusJsonFramer()
    private val writes = ArrayDeque<NusWrite>()
    private var payloadSize = 20
    private var awaitingMtu = false
    private var linkConnected = false
    private var servicesHandled = false
    private val recordingInbox = PrototypeRecordingInbox(store) {
        // Subscription completion always requests a list, including for early hints.
        if (store.control()["phase"] == "ready") requestRecordings()
    }
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
                    discover(client, session)
                } else if (state == BluetoothProfile.STATE_DISCONNECTED || status != BluetoothGatt.GATT_SUCCESS) {
                    lost(session, "GATT disconnect status=$status")
                }
            }
            override fun onMtuChanged(client: BluetoothGatt, mtu: Int, status: Int) = accept(client) {
                if (status == BluetoothGatt.GATT_SUCCESS && mtu >= 23) payloadSize = mtu - 3
                if (awaitingMtu) subscribe(client, session)
            }
            override fun onServiceChanged(client: BluetoothGatt) = accept(client) {
                // Enabling/disabling the firmware's SMP service changes ATT handles.
                // Fence the old NUS/SDK objects and rediscover on a fresh session.
                lost(session, "GATT services changed")
            }
            override fun onServicesDiscovered(client: BluetoothGatt, status: Int) = accept(client) {
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
                check(status == BluetoothGatt.GATT_SUCCESS) { "CCCD write failed: $status" }
                operation++
                runtime.phase(session, "ready")
                retryDelay = 5000
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
                val previousFind = store.control()["last_find_watch"] as? Map<*, *>
                findWatch.ready(session, previousFind?.get("address") == store.control()["address"] &&
                    previousFind?.get("state") in listOf("accepted", "start_written"))
            }
            override fun onCharacteristicChanged(client: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
                val copy = characteristic.value?.clone() ?: return
                if (characteristic.uuid == RX) accept(client) { incoming(copy) }
            }
            override fun onCharacteristicChanged(client: BluetoothGatt, characteristic: BluetoothGattCharacteristic, value: ByteArray) {
                val copy = value.clone()
                if (characteristic.uuid == RX) accept(client) { incoming(copy) }
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

    private fun lost(session: Long, reason: String) {
        if (!runtime.owns(session)) return
        runtime.phase(session, "disconnected", reason)
        close()
        handler.postDelayed({
            if (runtime.owns(session)) safely { runtime.reconnect() }
        }, retryDelay)
        retryDelay = minOf(60000, retryDelay * 2)
    }

    fun syncTime() {
        check(store.control()["phase"] == "ready") { "NUS not ready" }
        val now = System.currentTimeMillis()
        val offset = PrototypeClockCommands.offsetHours(now, TimeZone.getDefault())
        val packets = try { PrototypeClockCommands.packets(now / 1000, offset, payloadSize) }
        catch (error: IllegalArgumentException) {
            // Keep recordings usable if this link cannot carry a complete clock command.
            store.update("time_write_failed", mapOf("last_time_error" to error.message))
            return
        }
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
                System.currentTimeMillis(), TimeZone.getDefault())) syncTime()
    }

    fun requestRecordings() { command("GB({\"t\":\"voice_memo\",\"action\":\"list\"})") }
    fun requestDeviceInfo() { command("GB({\"t\":\"ver\"})") }

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
        if (writing || readingBattery || writes.isEmpty()) return
        val client = gatt ?: return
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

    private fun writeFinished() {
        operation++
        writing = false
        val item = writes.peek() ?: return
        if (item.advance()) { writes.remove(); item.done() }
        pump()
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
            val message = JSONObject(text)
            // A notification may precede the CCCD completion callback. Readiness
            // sends time anyway; do not disconnect a valid subscribing link.
            if (message.optString("t") == "time" && store.control()["phase"] == "ready") syncTime()
            PrototypeWatchInfo(store).receive(message, token, System.currentTimeMillis())
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
            recordingInbox.receive(message)
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
            it.requestConnPriority(BluetoothGatt.CONNECTION_PRIORITY_HIGH)
        }
    }

    private fun downloadNext() {
        if (downloading || shellOperation.busy || smpPreparation.busy || !runtime.owns(token) || store.control()["phase"] != "ready") return
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
        // Preparation can wait for one service-change reconnect, but it never
        // executes/replays a command. Persisted Stop cancels it immediately.
        if (store.control()["desired_running"] != true) smpPreparation.close()
        smpIdleLease.close()
        shellOperation.close()
        mediaClosed()
        gpsClosed()
        findWatch.close()
        operation++; fileOperation++
        httpRelay.reset()
        writing = false; writes.clear(); downloading = false
        notificationWriting = false
        readingBattery = false
        awaitingMtu = false; payloadSize = 20
        linkConnected = false; servicesHandled = false
        runCatching { transfer?.cancel() }; transfer = null
        runCatching { fileTransport?.release() }; fileTransport = null
        val previous = gatt; gatt = null; tx = null
        runCatching { previous?.disconnect() }; runCatching { previous?.close() }
        framer.reset()
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
