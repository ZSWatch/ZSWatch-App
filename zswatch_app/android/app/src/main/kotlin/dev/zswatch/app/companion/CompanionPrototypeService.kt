package dev.zswatch.app.companion

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.IntentFilter
import android.bluetooth.BluetoothAdapter
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import dev.zswatch.app.BuildConfig
import dev.zswatch.app.LifecycleLogger
import java.io.File

class CompanionPrototypeService : Service() {
    companion object {
        const val START = "dev.zswatch.app.companion.START"
        const val STOP = "dev.zswatch.app.companion.STOP"
        const val RESTORE_PRESENCE = "dev.zswatch.app.companion.RESTORE_PRESENCE"
        const val CHANNEL = "companion_prototype"
        const val NOTIFICATION = 1003
        @Volatile var instance: CompanionPrototypeService? = null
            private set
    }
    var runtime: PrototypeRuntime? = null
        private set
    var transport: NativePrototypeTransport? = null
        private set
    private var receiverRegistered = false
    private val systemEvents = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val action = intent.action
            val radio = intent.getIntExtra(BluetoothAdapter.EXTRA_STATE, -1)
            PrototypeHub.worker.post {
                safely {
                    val owner = runtime ?: return@safely
                    if (action == BluetoothAdapter.ACTION_STATE_CHANGED) {
                        if (radio == BluetoothAdapter.STATE_OFF || radio == BluetoothAdapter.STATE_TURNING_OFF)
                            owner.suspendTransport("Bluetooth disabled")
                        else if (radio == BluetoothAdapter.STATE_ON) owner.recoverForSystem()
                    } else if (action in listOf(Intent.ACTION_TIME_CHANGED, Intent.ACTION_TIMEZONE_CHANGED)) {
                        if (owner.active && owner.store.control()["phase"] == "ready") transport?.syncTime()
                    }
                }
            }
        }
    }

    private val notificationMaintenance = object : Runnable {
        override fun run() {
            if (instance !== this@CompanionPrototypeService) return
            safely {
                runtime?.store?.let { PrototypeNotifications(it).expire(System.currentTimeMillis()) }
                transport?.flushNotifications()
            }
            PrototypeHub.worker.postDelayed(this, 60000)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        LifecycleLogger.initialize(applicationContext)
        LifecycleLogger.recordHistoricalExitReasons(applicationContext)
        LifecycleLogger.log("CompanionPrototype", "service_created pid=${android.os.Process.myPid()}")
        if (!BuildConfig.COMPANION_RUNTIME_PROTOTYPE) { stopSelf(); return }
        instance = this
        ContextCompat.registerReceiver(this, systemEvents, IntentFilter().apply {
            addAction(BluetoothAdapter.ACTION_STATE_CHANGED)
            addAction(Intent.ACTION_TIME_CHANGED)
            addAction(Intent.ACTION_TIMEZONE_CHANGED)
        }, ContextCompat.RECEIVER_EXPORTED)
        receiverRegistered = true
        PrototypeHub.worker.post {
            safely {
                val store = PrototypeHub.journal(applicationContext)
                val files = ReceiptFiles(File(filesDir, "companion-prototype/recordings"))
                val link = NativePrototypeTransport(applicationContext, PrototypeHub.worker, store, files)
                transport = link
                runtime = PrototypeRuntime(store, link).also { link.runtime = it }
                PrototypeHub.worker.post(notificationMaintenance)
            }
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!BuildConfig.COMPANION_RUNTIME_PROTOTYPE) { stopSelf(); return START_NOT_STICKY }
        LifecycleLogger.log("CompanionPrototype", "service_start action=${intent?.action} flags=$flags id=$startId")
        if (intent?.action == STOP) {
            PrototypeHub.worker.post {
                safely { runtime?.stop(); stopPresenceObservation() }
                PrototypeHub.main.post { stopSelf() }
            }
            return START_NOT_STICKY
        }
        if (intent != null && intent.action !in listOf(START, RESTORE_PRESENCE)) { stopSelf(); return START_NOT_STICKY }
        try {
            val manager = getSystemService(NotificationManager::class.java)
            if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(
                NotificationChannel(CHANNEL, "Companion prototype", NotificationManager.IMPORTANCE_LOW))
            val open = packageManager.getLaunchIntentForPackage(packageName)
            val stop = Intent(this, CompanionPrototypeService::class.java).setAction(STOP)
            val notification = NotificationCompat.Builder(this, CHANNEL)
                .setSmallIcon(android.R.drawable.stat_sys_data_bluetooth)
                .setContentTitle("ZSWatch companion prototype")
                .setContentText("Native connection and recording runtime")
                .setOngoing(true)
                .setContentIntent(PendingIntent.getActivity(this, 20, open, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT))
                .addAction(0, "Stop", PendingIntent.getService(this, 21, stop, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT))
                .build()
            if (Build.VERSION.SDK_INT >= 29) startForeground(NOTIFICATION, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE)
            else startForeground(NOTIFICATION, notification)
        } catch (error: Exception) {
            LifecycleLogger.log("CompanionPrototype", "foreground_failed ${error.javaClass.simpleName}")
            stopSelf()
            return START_NOT_STICKY
        }
        val address = intent?.getStringExtra("address")
        PrototypeHub.worker.post {
            safely {
                val owner = runtime ?: error("Prototype owner unavailable")
                if (intent?.action == RESTORE_PRESENCE) {
                    val restored = address != null && PrototypePresence.associated(applicationContext, address) &&
                        owner.restoreForPresence(address, intent.getLongExtra("generation", -1))
                    LifecycleLogger.log("CompanionPresence", "restore_accepted=$restored")
                    if (!restored && !owner.active) PrototypeHub.main.post { stopSelf() }
                    return@safely
                }
                // Two accepted starts may reach the service before the first
                // controller exists. Reject a switch without destroying its link.
                if (address != null && owner.active && owner.store.control()["address"] != address) {
                    owner.store.update("start_rejected", detail = mapOf("reason" to "Stop before changing watch", "requested_address" to address))
                    LifecycleLogger.log("CompanionPrototype", "start_rejected activeWatchUnchanged=true")
                    return@safely
                }
                if (address == null) {
                    if (!owner.restore()) PrototypeHub.main.post { stopSelf() }
                } else if (owner.active && owner.store.control()["phase"] in listOf("error", "disconnected")) {
                    check(owner.store.control()["address"] == address) { "Stop before changing watch" }
                    owner.reconnect()
                } else owner.start(address)
                try { PrototypePresence.observe(applicationContext, owner.store.control()["address"] as String) }
                catch (error: Exception) {
                    LifecycleLogger.log("CompanionPresence", "observe_failed ${error.javaClass.simpleName}")
                }
            }
        }
        return START_STICKY
    }

    fun stopPresenceObservation() {
        try {
            val address = runtime?.store?.control()?.get("address") as? String ?: return
            PrototypePresence.stopObserving(applicationContext, address)
        } catch (error: Exception) {
            LifecycleLogger.log("CompanionPresence", "stop_observation_failed ${error.javaClass.simpleName}")
        }
    }

    private fun safely(action: () -> Unit) {
        try { action() }
        catch (error: Exception) {
            LifecycleLogger.log("CompanionPrototype", "service_operation_failed ${error.javaClass.simpleName}: ${error.message}")
            PrototypeHub.main.post { stopSelf() }
        }
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        LifecycleLogger.log("CompanionPrototype", "task_removed runtimeOwnedByService=true")
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        LifecycleLogger.log("CompanionPrototype", "service_destroyed explicitStop=${runtime?.store?.control()?.get("desired_running") == false}")
        if (instance === this) instance = null
        if (receiverRegistered) { unregisterReceiver(systemEvents); receiverRegistered = false }
        PrototypeHub.worker.removeCallbacks(notificationMaintenance)
        PrototypeHub.worker.post { safely { runtime?.destroy(); runtime = null; transport = null } }
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }
}
