package dev.zswatch.app.companion

import android.companion.CompanionDeviceService
import android.content.Intent
import androidx.core.content.ContextCompat
import dev.zswatch.app.LifecycleLogger

/** Bound by Android; never starts Flutter or implements an MCUmgr transport. */
@Suppress("DEPRECATION")
class PrototypePresenceService : CompanionDeviceService() {
    override fun onDeviceAppeared(address: String) {
        LifecycleLogger.log("CompanionPresence", "device_appeared")
        PrototypeHub.worker.post {
            try {
                val state = PrototypeHub.journal(applicationContext).control()
                if (state["desired_running"] != true || state["address"] != address ||
                    !PrototypePresence.associated(applicationContext, address)) return@post
                val generation = (state["generation"] as Number).toLong()
                PrototypeHub.main.post {
                    try {
                        ContextCompat.startForegroundService(applicationContext,
                            Intent(applicationContext, CompanionPrototypeService::class.java)
                                .setAction(CompanionPrototypeService.RESTORE_PRESENCE)
                                .putExtra("address", address).putExtra("generation", generation))
                    } catch (error: Exception) {
                        LifecycleLogger.log("CompanionPresence", "start_failed ${error.javaClass.simpleName}")
                    }
                }
            } catch (error: Exception) {
                LifecycleLogger.log("CompanionPresence", "presence_failed ${error.javaClass.simpleName}")
            }
        }
    }

    override fun onDeviceDisappeared(address: String) {
        LifecycleLogger.log("CompanionPresence", "device_disappeared")
        // Radio/link recovery stays with the existing service; never change user intent.
    }
}
