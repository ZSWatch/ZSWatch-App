@file:Suppress("DEPRECATION", "MissingPermission")
package dev.zswatch.app.companion

import android.bluetooth.*
import android.content.Context
import android.os.Handler
import dev.zswatch.app.LifecycleLogger
import io.runtime.mcumgr.ble.McuMgrBleTransport
import io.runtime.mcumgr.exception.McuMgrException
import io.runtime.mcumgr.managers.FsManager
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
    private var gatt: BluetoothGatt? = null
    private var tx: BluetoothGattCharacteristic? = null
    private var token = 0L
    private var operation = 0L
    private var retryDelay = 5000L
    private val framer = NusJsonFramer()
    private val writes = ArrayDeque<NusWrite>()
    private var payloadSize = 20
    private var awaitingMtu = false
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
                    awaitingMtu = true
                    if (client.requestMtu(64)) {
                        val expected = ++operation
                        handler.postDelayed({
                            if (runtime.owns(session) && gatt === client && operation == expected && awaitingMtu)
                                safely { discover(client, session) }
                        }, 5000)
                    } else discover(client, session)
                } else if (state == BluetoothProfile.STATE_DISCONNECTED || status != BluetoothGatt.GATT_SUCCESS) {
                    lost(session, "GATT disconnect status=$status")
                }
            }
            override fun onMtuChanged(client: BluetoothGatt, mtu: Int, status: Int) = accept(client) {
                if (status == BluetoothGatt.GATT_SUCCESS && mtu >= 23) payloadSize = mtu - 3
                if (awaitingMtu) discover(client, session)
            }
            override fun onServicesDiscovered(client: BluetoothGatt, status: Int) = accept(client) {
                check(status == BluetoothGatt.GATT_SUCCESS) { "GATT discovery failed: $status" }
                val service = client.getService(NUS) ?: error("NUS service unavailable")
                tx = service.getCharacteristic(TX) ?: error("NUS write characteristic unavailable")
                val rx = service.getCharacteristic(RX) ?: error("NUS notify characteristic unavailable")
                check(client.setCharacteristicNotification(rx, true)) { "Notify registration failed" }
                val descriptor = rx.getDescriptor(CCCD) ?: error("NUS CCCD unavailable")
                runtime.phase(session, "subscribing")
                descriptor.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                check(client.writeDescriptor(descriptor)) { "CCCD write rejected" }
                deadline(session, 15000, "CCCD subscription timed out")
            }
            override fun onDescriptorWrite(client: BluetoothGatt, descriptor: BluetoothGattDescriptor, status: Int) = accept(client) {
                if (descriptor.uuid != CCCD) return@accept
                check(status == BluetoothGatt.GATT_SUCCESS) { "CCCD write failed: $status" }
                operation++
                runtime.phase(session, "ready")
                retryDelay = 5000
                command("GB({\"t\":\"log\",\"status\":false})")
                syncTime()
                requestRecordings()
                recoverReceipts()
                downloadNext()
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
        }
        gatt = adapter.getRemoteDevice(address).connectGatt(context, false, callback, BluetoothDevice.TRANSPORT_LE)
            ?: error("GATT connection rejected")
        deadline(session, 30000, "Connection timed out")
    }

    private fun discover(client: BluetoothGatt, session: Long) {
        awaitingMtu = false
        runtime.phase(session, "discovering")
        check(client.discoverServices()) { "GATT discovery rejected" }
        deadline(session, 15000, "Service discovery timed out")
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
        val offset = TimeZone.getDefault().getOffset(now) / 3600000.0
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
                    mapOf("last_time_write_utc_ms" to now, "last_time_error" to null))
            }, bytes.size))
        }
        pump()
    }

    fun requestRecordings() { command("GB({\"t\":\"voice_memo\",\"action\":\"list\"})") }

    private fun command(text: String, done: () -> Unit = {}) {
        check(runtime.owns(token) && store.control()["phase"] == "ready") { "NUS not ready" }
        check(writes.size < 16) { "NUS write queue full" }
        writes.add(NusWrite(text.toByteArray(Charsets.UTF_8), done))
        pump()
    }

    private fun pump() {
        if (writing || writes.isEmpty()) return
        val client = gatt ?: return
        val characteristic = tx ?: return
        val item = writes.first
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
    }

    private fun incoming(bytes: ByteArray) {
        for (text in framer.feed(bytes)) {
            val message = JSONObject(text)
            // A notification may precede the CCCD completion callback. Readiness
            // sends time anyway; do not disconnect a valid subscribing link.
            if (message.optString("t") == "time" && store.control()["phase"] == "ready") syncTime()
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

    private fun downloadNext() {
        if (downloading || !runtime.owns(token) || store.control()["phase"] != "ready") return
        val address = store.control()["address"] as String
        val pending = records().entries.firstOrNull { it.value["address"] == address && it.value["state"] == "pending" } ?: return
        val key = pending.key
        val metadata = pending.value
        files.recover(key, metadata)?.let { store.putRecord(key, it); downloadNext(); return }
        downloading = true
        val session = token
        val transferId = ++fileOperation
        store.putRecord(key, metadata + mapOf("state" to "downloading"))
        command("GB({\"t\":\"smp\",\"status\":true})") {
            handler.postDelayed({
                if (runtime.owns(session) && downloading && fileOperation == transferId) safely {
                    val adapter = context.getSystemService(BluetoothManager::class.java).adapter
                    val transport = McuMgrBleTransport(context, adapter.getRemoteDevice(address), handler)
                    fileTransport = transport
                    transfer = FsManager(transport).fileDownload("/user/recordings/${metadata["filename"]}.zsw_opus",
                        object : DownloadCallback {
                            private fun deliver(action: () -> Unit) { handler.post {
                                if (runtime.owns(session) && downloading && fileOperation == transferId) safely(action)
                            } }
                            override fun onDownloadProgressChanged(current: Int, total: Int, timestamp: Long) {}
                            override fun onDownloadFailed(error: McuMgrException) = deliver {
                                finishFile(key, metadata, error.javaClass.simpleName)
                            }
                            override fun onDownloadCanceled() = deliver { finishFile(key, metadata, "cancelled") }
                            override fun onDownloadCompleted(bytes: ByteArray) = deliver {
                                val receipt = try { files.publish(key, metadata, bytes) }
                                    catch (error: Exception) { finishFile(key, metadata, error.javaClass.simpleName); return@deliver }
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
        transfer?.cancel(); transfer = null
        fileTransport?.release(); fileTransport = null
        if (error != null) store.putRecord(key, metadata + mapOf("state" to "failed", "error" to error))
        if (runtime.owns(token) && store.control()["phase"] == "ready") command("GB({\"t\":\"smp\",\"status\":false})")
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
        operation++; fileOperation++
        writing = false; writes.clear(); downloading = false
        awaitingMtu = false; payloadSize = 20
        runCatching { transfer?.cancel() }; transfer = null
        runCatching { fileTransport?.release() }; fileTransport = null
        val previous = gatt; gatt = null; tx = null
        runCatching { previous?.disconnect() }; runCatching { previous?.close() }
        framer.reset()
    }

    companion object {
        private val NUS = UUID.fromString("6e400001-b5a3-f393-e0a9-e50e24dcca9e")
        private val TX = UUID.fromString("6e400002-b5a3-f393-e0a9-e50e24dcca9e")
        private val RX = UUID.fromString("6e400003-b5a3-f393-e0a9-e50e24dcca9e")
        private val CCCD = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
    }
}
