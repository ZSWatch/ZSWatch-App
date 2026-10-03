package dev.zswatch.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.Manifest
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat
import dev.zswatch.app.companion.CompanionPrototypeService
import dev.zswatch.app.companion.PrototypeHub
import dev.zswatch.app.companion.PrototypeSystemRecovery

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        LifecycleLogger.initialize(context)
        LifecycleLogger.recordHistoricalExitReasons(context)
        val action = intent?.action
        if (BuildConfig.COMPANION_RUNTIME_PROTOTYPE) {
            restoreNative(context, action)
            return
        }
        LifecycleLogger.recordStartupCause(
            source = "boot_receiver",
            detail = "action=$action",
        )
        if (action != Intent.ACTION_BOOT_COMPLETED && action != Intent.ACTION_MY_PACKAGE_REPLACED) {
            LifecycleLogger.log("BootReceiver", "ignored action=$action")
            return
        }

        val snapshot = NativeBackgroundPreferences.getSnapshot(context)
        LifecycleLogger.log(
            "BootReceiver",
            "received action=$action background=${snapshot.backgroundConnectionEnabled} " +
                "autoReconnect=${snapshot.autoReconnectEnabled} watchId=${snapshot.lastWatchId}",
        )

        if (!snapshot.backgroundConnectionEnabled || !snapshot.autoReconnectEnabled || !snapshot.hasKnownWatch) {
            LifecycleLogger.log("BootReceiver", "skipping foreground recovery: recovery is disabled or no known watch")
            return
        }

        val watchName = snapshot.lastWatchName ?: "ZSWatch"
        val started = BleConnectionForegroundService.start(
            context,
            watchName,
            BleConnectionForegroundService.STATE_RECONNECTING,
        )
        LifecycleLogger.log(
            "BootReceiver",
            "foreground recovery notification start attempted started=$started sdk=${Build.VERSION.SDK_INT}",
        )
    }

    private fun restoreNative(context: Context, action: String?) {
        if (action != Intent.ACTION_BOOT_COMPLETED && action != Intent.ACTION_MY_PACKAGE_REPLACED) return
        // BOOT_COMPLETED uses credential-encrypted storage after first unlock.
        // Never attempt a direct-boot Flutter/model/database startup.
        val application = context.applicationContext
        val pending = goAsync()
        PrototypeHub.worker.post {
            try {
                val allowed = Build.VERSION.SDK_INT < 31 || ContextCompat.checkSelfPermission(application,
                    Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED
                val request = PrototypeSystemRecovery.request(PrototypeHub.journal(application).control(), action, allowed)
                if (request == null) {
                    LifecycleLogger.log("CompanionPrototype", "system_restore_skipped action=$action")
                    pending.finish()
                    return@post
                }
                PrototypeHub.main.post {
                    try {
                        ContextCompat.startForegroundService(application,
                            Intent(application, CompanionPrototypeService::class.java)
                                .setAction(CompanionPrototypeService.RESTORE_SYSTEM)
                                .putExtra("address", request.address).putExtra("generation", request.generation))
                        LifecycleLogger.log("CompanionPrototype", "system_restore_requested action=$action")
                    } catch (error: Exception) {
                        LifecycleLogger.log("CompanionPrototype", "system_restore_failed ${error.javaClass.simpleName}")
                    } finally { pending.finish() }
                }
            } catch (error: Exception) {
                LifecycleLogger.log("CompanionPrototype", "system_restore_failed ${error.javaClass.simpleName}")
                pending.finish()
            }
        }
    }
}
