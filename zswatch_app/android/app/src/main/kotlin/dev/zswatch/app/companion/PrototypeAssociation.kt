package dev.zswatch.app.companion

import android.app.Activity
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.ScanResult
import android.companion.AssociationInfo
import android.companion.AssociationRequest
import android.companion.BluetoothLeDeviceFilter
import android.companion.BluetoothDeviceFilter
import android.companion.CompanionDeviceManager
import android.content.Intent
import android.content.IntentSender
import android.os.Build
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executor
import java.util.regex.Pattern

/** Explicit Android picker; no Flutter scanner or second GATT connection. */
@Suppress("DEPRECATION")
class PrototypeAssociation(private val activity: Activity) {
    companion object {
        const val REQUEST = 61003

        internal fun connectedWatch(devices: List<BluetoothDevice>): String? = devices
            .filter { it.bondState == BluetoothDevice.BOND_BONDED &&
                it.name?.contains("ZSWatch", ignoreCase = true) == true }
            .map { it.address.uppercase() }.distinct().singleOrNull()
    }
    private class Pending(val result: MethodChannel.Result, val address: String?, val generation: Long?) {
        var completing = false
        var pickerShown = false
    }
    private var pending: Pending? = null
    private var disposed = false

    fun discover(generation: Long, result: MethodChannel.Result) {
        // Android's HID connection can survive app-data clearing. That watch is
        // no longer advertising; CDM can confirm a bonded address without a scan.
        // Never arbitrarily choose between multiple connected watches.
        try {
            val bluetooth = activity.getSystemService(BluetoothManager::class.java)
            val connected = if (bluetooth == null) emptyList() else
                bluetooth.getConnectedDevices(BluetoothProfile.GATT) +
                    bluetooth.getConnectedDevices(BluetoothProfile.GATT_SERVER)
            begin(connectedWatch(connected), generation, result)
        } catch (error: Exception) {
            result.error("ASSOCIATION_FAILED", error.message, null)
        }
    }
    fun associate(selected: String, result: MethodChannel.Result) = begin(selected, null, result)

    private fun begin(selected: String?, generation: Long?, result: MethodChannel.Result) {
        if (disposed) { result.error("DETACHED", "Watch picker view detached", null); return }
        if (pending != null) { result.error("BUSY", "Watch picker already pending", null); return }
        val operation = Pending(result, selected, generation)
        try {
            val manager = PrototypePresence.manager(activity) ?: error("Watch discovery requires Android 12+ and companion device setup support")
            pending = operation
            if (selected != null && PrototypePresence.associated(activity, selected)) {
                finishAssociation(operation, selected); return
            }
            val filter = if (selected != null)
                BluetoothDeviceFilter.Builder().setAddress(selected).build()
            else BluetoothLeDeviceFilter.Builder()
                .setNamePattern(Pattern.compile(".*ZSWatch.*", Pattern.CASE_INSENSITIVE)).build()
            val request = AssociationRequest.Builder().addDeviceFilter(filter).setSingleDevice(selected != null).build()
            if (Build.VERSION.SDK_INT >= 33) {
                manager.associate(request, Executor { action -> PrototypeHub.main.post(action) },
                    object : CompanionDeviceManager.Callback() {
                        override fun onAssociationPending(chooser: IntentSender) = showPicker(operation, chooser)
                        override fun onAssociationCreated(info: AssociationInfo) {
                            if (pending !== operation) return
                            val address = info.deviceMacAddress?.toString()?.uppercase()
                            if (address == null || (selected != null && address != selected)) fail(operation, "Selected watch did not match")
                            else finishAssociation(operation, address)
                        }
                        override fun onFailure(error: CharSequence?) = pickerFailed(operation, error)
                    })
            } else {
                manager.associate(request, object : CompanionDeviceManager.Callback() {
                    override fun onDeviceFound(chooser: IntentSender) = showPicker(operation, chooser)
                    override fun onFailure(error: CharSequence?) = pickerFailed(operation, error)
                }, PrototypeHub.main)
            }
            PrototypeHub.main.postDelayed({ fail(operation, "Watch picker timed out") }, 120000)
        } catch (error: Exception) {
            if (pending === operation) fail(operation, error.message ?: "Watch discovery failed")
            else result.error("ASSOCIATION_FAILED", error.message, null)
        }
    }

    private fun showPicker(operation: Pending, chooser: IntentSender) {
        if (pending !== operation) return
        try {
            activity.startIntentSenderForResult(chooser, REQUEST, null, 0, 0, 0)
            operation.pickerShown = true
        }
        catch (error: Exception) { fail(operation, error.message ?: "Could not open watch picker") }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST) return false
        val operation = pending ?: return true
        if (resultCode != Activity.RESULT_OK) { fail(operation, "Watch selection cancelled", "CANCELLED"); return true }
        // On Android 13+, onAssociationCreated is authoritative, not an Activity result extra.
        if (Build.VERSION.SDK_INT >= 33) return true
        try {
            val selected = operation.address ?: when (val device = data?.getParcelableExtra<android.os.Parcelable>(CompanionDeviceManager.EXTRA_DEVICE)) {
                is ScanResult -> device.device.address
                is BluetoothDevice -> device.address
                else -> error("Missing selected BLE watch")
            }.uppercase()
            finishAssociation(operation, selected)
        } catch (error: Exception) { fail(operation, error.message ?: "Watch selection failed") }
        return true
    }

    private fun finishAssociation(operation: Pending, selected: String) {
        if (pending !== operation || operation.completing) return
        operation.completing = true
        PrototypeHub.worker.post {
            try {
                check(Regex("[0-9A-F]{2}(:[0-9A-F]{2}){5}").matches(selected) && PrototypePresence.associated(activity, selected)) {
                    "Association did not match the selected watch"
                }
                val state = PrototypeHub.journal(activity.applicationContext).control()
                val response = if (operation.generation != null) {
                    check(PrototypeDiscovery.canSelect(state, CompanionPrototypeService.instance?.runtime?.active == true, operation.generation)) {
                        "Watch selection expired; choose again"
                    }
                    mapOf("version" to 1, "address" to selected, "generation" to operation.generation, "associated" to true)
                } else {
                    // A notification Stop may have arrived while the system picker was open.
                    if (state["desired_running"] == true && state["address"] == selected) PrototypePresence.observe(activity, selected)
                    else PrototypePresence.stopObserving(activity, selected)
                    PrototypePresence.status(activity, selected)
                }
                PrototypeHub.main.post {
                    if (pending === operation) { pending = null; operation.result.success(response) }
                }
            } catch (error: Exception) {
                PrototypeHub.main.post { fail(operation, error.message ?: "Watch selection failed") }
            }
        }
    }

    private fun fail(operation: Pending, message: String, code: String = "ASSOCIATION_FAILED") {
        if (pending !== operation) return
        pending = null
        operation.result.error(code, message, null)
    }

    private fun pickerFailed(operation: Pending, error: CharSequence?) {
        val code = PrototypeDiscovery.failureCode(error?.toString())
        val message = error?.toString() ?: "Watch discovery failed"
        // Android 12 reports cancellation as a generic discovery error before
        // delivering RESULT_CANCELED. Give that authoritative result a bounded
        // window; never classify an ambiguous error message as cancellation.
        if (PrototypeDiscovery.awaitPickerResult(Build.VERSION.SDK_INT, operation.pickerShown, code)) {
            PrototypeHub.main.postDelayed({ fail(operation, message, code) }, 1000)
        } else fail(operation, message, code)
    }

    fun dispose() { disposed = true; pending?.let { fail(it, "Watch picker detached; choose again") } }
}
