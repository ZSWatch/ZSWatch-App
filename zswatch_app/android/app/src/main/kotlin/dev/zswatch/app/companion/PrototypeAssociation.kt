package dev.zswatch.app.companion

import android.app.Activity
import android.bluetooth.le.ScanFilter
import android.companion.AssociationRequest
import android.companion.BluetoothLeDeviceFilter
import android.companion.CompanionDeviceManager
import android.content.IntentSender
import io.flutter.plugin.common.MethodChannel

/** Explicit system association picker for the debug prototype's selected watch. */
@Suppress("DEPRECATION")
class PrototypeAssociation(private val activity: Activity) {
    companion object { const val REQUEST = 61003 }
    private var pending: MethodChannel.Result? = null
    private var address: String? = null

    fun associate(selected: String, result: MethodChannel.Result) {
        if (pending != null) { result.error("BUSY", "Association already pending", null); return }
        try {
            val manager = PrototypePresence.manager(activity) ?: error("Presence requires Android 12+ and companion device setup support")
            if (PrototypePresence.associated(activity, selected)) {
                finishAssociation(selected, result); return
            }
            pending = result; address = selected
            val filter = BluetoothLeDeviceFilter.Builder()
                .setScanFilter(ScanFilter.Builder().setDeviceAddress(selected).build()).build()
            manager.associate(AssociationRequest.Builder().addDeviceFilter(filter).setSingleDevice(true).build(),
                object : CompanionDeviceManager.Callback() {
                    override fun onDeviceFound(chooser: IntentSender) {
                        if (pending !== result) return
                        try { activity.startIntentSenderForResult(chooser, REQUEST, null, 0, 0, 0) }
                        catch (error: Exception) { fail(error.message ?: "Could not open association picker") }
                    }
                    override fun onFailure(error: CharSequence?) {
                        if (pending === result) fail(error?.toString() ?: "Association failed")
                    }
                }, PrototypeHub.main)
        } catch (error: Exception) {
            if (pending != null) fail(error.message ?: "Association failed")
            else result.error("ASSOCIATION_FAILED", error.message, null)
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int): Boolean {
        if (requestCode != REQUEST) return false
        val result = pending ?: return true
        val selected = address!!
        pending = null; address = null
        try {
            check(resultCode == Activity.RESULT_OK && PrototypePresence.associated(activity, selected)) {
                "Association was cancelled or did not match the selected watch"
            }
            finishAssociation(selected, result)
        } catch (error: Exception) { result.error("ASSOCIATION_FAILED", error.message, null) }
        return true
    }

    private fun finishAssociation(selected: String, result: MethodChannel.Result) {
        PrototypeHub.worker.post {
            try {
                val state = PrototypeHub.journal(activity.applicationContext).control()
                // A notification Stop may have arrived while the system picker was open.
                if (state["desired_running"] == true && state["address"] == selected)
                    PrototypePresence.observe(activity, selected)
                else PrototypePresence.stopObserving(activity, selected)
                val status = PrototypePresence.status(activity, selected)
                PrototypeHub.main.post { result.success(status) }
            } catch (error: Exception) {
                PrototypeHub.main.post { result.error("ASSOCIATION_FAILED", error.message, null) }
            }
        }
    }

    private fun fail(message: String) {
        val result = pending; pending = null; address = null
        result?.error("ASSOCIATION_FAILED", message, null)
    }

    fun dispose() { fail("Association view detached; reopen to inspect system association") }
}
