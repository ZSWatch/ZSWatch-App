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
        const val START_DISCOVERED = "dev.zswatch.app.companion.START_DISCOVERED"
        const val STOP = "dev.zswatch.app.companion.STOP"
        const val RESTORE_PRESENCE = "dev.zswatch.app.companion.RESTORE_PRESENCE"
        const val RESTORE_SYSTEM = "dev.zswatch.app.companion.RESTORE_SYSTEM"
        const val START_REMOTE_FIXTURE = "dev.zswatch.app.companion.START_REMOTE_FIXTURE"
        const val START_LOCAL_FIXTURE = "dev.zswatch.app.companion.START_LOCAL_FIXTURE"
        const val POST_TEST_NOTIFICATION = "dev.zswatch.app.companion.POST_TEST_NOTIFICATION"
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
    var remoteFixture: PrototypeRemoteFixture? = null
        private set
    var localFixture: PrototypeLocalFixture? = null
        private set
    private var media: AndroidPrototypeMedia? = null
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
                transport?.syncTimeIfTimezoneChanged()
                transport?.flushNotifications()
                runtime?.let { if (it.active && it.store.control()["phase"] == "ready") media?.refresh(it.generation) }
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
        media = AndroidPrototypeMedia(applicationContext,
            send = { generation, packet -> transport?.sendMedia(generation, packet) == true },
            observe = { kind, generation, accepted ->
                val owner = runtime
                if (owner?.owns(generation) == true && owner.store.control()["phase"] == "ready") {
                    owner.store.update("media_$kind", mapOf("last_media_control" to mapOf(
                        "generation" to generation, "accepted" to accepted, "utc_ms" to System.currentTimeMillis())))
                }
            })
        ContextCompat.registerReceiver(this, systemEvents, IntentFilter().apply {
            addAction(BluetoothAdapter.ACTION_STATE_CHANGED)
            addAction(Intent.ACTION_TIME_CHANGED)
            addAction(Intent.ACTION_TIMEZONE_CHANGED)
        }, ContextCompat.RECEIVER_EXPORTED)
        receiverRegistered = true
        PrototypeHub.worker.post {
            safely {
                val store = PrototypeHub.journal(applicationContext)
                PrototypeHttpRelay.markProcessInterrupted(store, System.currentTimeMillis())
                val files = ReceiptFiles(File(filesDir, "companion-prototype/recordings"))
                val link = NativePrototypeTransport(applicationContext, PrototypeHub.worker, store, files)
                transport = link
                runtime = PrototypeRuntime(store, link).also { link.runtime = it }
                link.mediaReady = { media?.ready(it) }
                link.mediaClosed = { media?.close() }
                link.mediaControl = { message, generation -> media?.control(message, generation) }
                remoteFixture = PrototypeRemoteFixture(applicationContext, this).also { it.startMaintenance() }
                localFixture = PrototypeLocalFixture(applicationContext, this).also { it.startMaintenance() }
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
        if (intent != null && intent.action !in listOf(START, START_DISCOVERED, RESTORE_PRESENCE, RESTORE_SYSTEM, START_REMOTE_FIXTURE, START_LOCAL_FIXTURE, POST_TEST_NOTIFICATION)) { stopSelf(); return START_NOT_STICKY }
        try {
            val manager = getSystemService(NotificationManager::class.java)
            if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(
                NotificationChannel(CHANNEL, "Companion prototype", NotificationManager.IMPORTANCE_LOW))
            val open = packageManager.getLaunchIntentForPackage(packageName)
            val stop = Intent(this, CompanionPrototypeService::class.java).setAction(STOP)
            val notification = NotificationCompat.Builder(this, CHANNEL)
                .setSmallIcon(android.R.drawable.stat_sys_data_bluetooth)
                .setContentTitle("ZSWatch companion prototype")
                .setContentText("Native watch companion runtime")
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
                if (intent?.action == START_DISCOVERED) {
                    val started = address != null && owner.startDiscovered(address, intent.getLongExtra("generation", -1))
                    LifecycleLogger.log("CompanionPrototype", "discovered_start_accepted=$started")
                    if (!started && !owner.active) PrototypeHub.main.post { stopSelf() }
                    if (started && address != null) try { PrototypePresence.observe(applicationContext, address) }
                    catch (error: Exception) { LifecycleLogger.log("CompanionPresence", "observe_failed ${error.javaClass.simpleName}") }
                    return@safely
                }
                if (intent?.action == RESTORE_PRESENCE) {
                    val restored = address != null && PrototypePresence.associated(applicationContext, address) &&
                        owner.restoreForPresence(address, intent.getLongExtra("generation", -1))
                    LifecycleLogger.log("CompanionPresence", "restore_accepted=$restored")
                    if (!restored && !owner.active) PrototypeHub.main.post { stopSelf() }
                    return@safely
                }
                if (intent?.action == RESTORE_SYSTEM) {
                    val restored = address != null && owner.restoreForSystem(address, intent.getLongExtra("generation", -1))
                    LifecycleLogger.log("CompanionPrototype", "system_restore_accepted=$restored")
                    if (!restored && !owner.active) PrototypeHub.main.post { stopSelf() }
                    if (restored && address != null) try { PrototypePresence.observe(applicationContext, address) }
                    catch (error: Exception) { LifecycleLogger.log("CompanionPresence", "observe_failed ${error.javaClass.simpleName}") }
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
                    if (!owner.restore()) {
                        PrototypeHub.main.post { stopSelf() }
                        return@safely
                    }
                } else if (owner.active && owner.store.control()["phase"] in listOf("error", "disconnected")) {
                    check(owner.store.control()["address"] == address) { "Stop before changing watch" }
                    owner.reconnect()
                } else owner.start(address)
                if (intent?.action == START_REMOTE_FIXTURE) {
                    try { remoteFixture?.startFixture() }
                    catch (error: Exception) {
                        LifecycleLogger.log("CompanionJobs", "fixture_start_failed ${error.javaClass.simpleName}")
                        owner.store.update("remote_fixture_failed", detail = mapOf("error" to error.javaClass.simpleName))
                    }
                }
                if (intent?.action == START_LOCAL_FIXTURE) {
                    try { localFixture?.startFixture() }
                    catch (error: Exception) {
                        LifecycleLogger.log("CompanionLocalJobs", "fixture_start_failed ${error.javaClass.simpleName}")
                    }
                }
                if (intent?.action == POST_TEST_NOTIFICATION && owner.active) {
                    dev.zswatch.app.NotificationDebugHelper.postDebugNotification(applicationContext,
                        "Companion background test", "Native notification round trip")
                }
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
        media?.close()
        if (receiverRegistered) { unregisterReceiver(systemEvents); receiverRegistered = false }
        PrototypeHub.worker.removeCallbacks(notificationMaintenance)
        PrototypeHub.worker.post { safely {
            remoteFixture?.close(); remoteFixture = null
            localFixture?.close(); localFixture = null
            runtime?.destroy(); transport?.dispose(); runtime = null; transport = null
        } }
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }
}
