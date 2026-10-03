package dev.zswatch.app.companion

import android.companion.CompanionDeviceManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import dev.zswatch.app.BuildConfig
import dev.zswatch.app.LifecycleLogger

/** OS association is separate from the Bluetooth bond and the transport owner. */
@Suppress("DEPRECATION") // Address APIs support the Android 12 test rig and API 31+.
object PrototypePresence {
    fun manager(context: Context): CompanionDeviceManager? =
        if (BuildConfig.COMPANION_RUNTIME_PROTOTYPE && Build.VERSION.SDK_INT >= 31 &&
            context.packageManager.hasSystemFeature(PackageManager.FEATURE_COMPANION_DEVICE_SETUP))
            context.getSystemService(CompanionDeviceManager::class.java) else null

    fun associated(context: Context, address: String): Boolean {
        val manager = manager(context) ?: return false
        return if (Build.VERSION.SDK_INT >= 33)
            manager.myAssociations.any { it.deviceMacAddress?.toString().equals(address, true) }
        else manager.associations.any { it.equals(address, true) }
    }

    fun observe(context: Context, address: String): Boolean {
        if (!associated(context, address)) return false
        manager(context)!!.startObservingDevicePresence(address)
        LifecycleLogger.log("CompanionPresence", "observation_registered")
        return true
    }

    fun stopObserving(context: Context, address: String) {
        if (associated(context, address)) manager(context)!!.stopObservingDevicePresence(address)
    }

    /** Removes only the public OS companion association; the Bluetooth bond is separate. */
    fun disassociate(context: Context, address: String): Boolean {
        val manager = manager(context) ?: return false
        if (Build.VERSION.SDK_INT >= 33) {
            manager.myAssociations.filter { it.deviceMacAddress?.toString().equals(address, true) }
                .forEach { manager.disassociate(it.id) }
        } else {
            // Legacy address APIs are case-sensitive: use the OS's spelling.
            manager.associations.filter { it.equals(address, true) }.forEach { manager.disassociate(it) }
        }
        return !associated(context, address)
    }

    fun status(context: Context, address: String): Map<String, Any?> = mapOf(
        "version" to 1, "supported" to (manager(context) != null),
        "associated" to associated(context, address), "address" to address,
    )
}
