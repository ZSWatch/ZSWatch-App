package dev.zswatch.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        LifecycleLogger.initialize(context)
        LifecycleLogger.recordHistoricalExitReasons(context)
        val action = intent?.action
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
}