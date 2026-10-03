package dev.zswatch.app.companion

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat
import dev.zswatch.app.BuildConfig
import dev.zswatch.app.LifecycleLogger
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/** UI is an observer/controller, never a lifetime owner or a BLE transport. */
class CompanionPrototypeBridge(activity: Activity, messenger: BinaryMessenger) {
    private val context = activity.applicationContext
    private val association = PrototypeAssociation(activity)
    private val methods = MethodChannel(messenger, "dev.zswatch.app/companion_v1")
    private val events = EventChannel(messenger, "dev.zswatch.app/companion_events_v1")
    private var sink: EventChannel.EventSink? = null
    private val changed: () -> Unit = { snapshot(deliver = { sink?.success(it) }) }

    init {
        methods.setMethodCallHandler { call, result ->
            if (!BuildConfig.COMPANION_RUNTIME_PROTOTYPE) {
                result.error("DISABLED", "Prototype requires its debug build flag", null)
            } else if ((call.arguments as? Map<*, *>)?.get("version") != 1) {
                result.error("VERSION", "Unsupported companion bridge version", null)
            } else when (call.method) {
                "snapshot" -> snapshot(result::success) { message -> result.error("SNAPSHOT_FAILED", message, null) }
                "requestNotificationAccess" -> {
                    activity.startActivity(Intent(android.provider.Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                    result.success(mapOf("version" to 1, "accepted" to true))
                }
                "postTestNotification" -> {
                    try {
                        val delay = call.argument<Int>("delaySeconds") ?: 0
                        val closeUi = call.argument<Boolean>("closeUi") ?: false
                        require(delay in 0..60 && (!closeUi || delay > 0)) { "Invalid diagnostic delay" }
                        // This synthetic fixture survives Activity disposal, not process death.
                        // It is not a recovery scheduler or a background acceptance harness.
                        val application = context
                        PrototypeHub.worker.postDelayed({
                            try {
                                dev.zswatch.app.NotificationDebugHelper.postDebugNotification(application,
                                    "Companion background test", "Native forwarding without Flutter BLE ownership")
                                LifecycleLogger.log("CompanionNotifications", "synthetic_notification_posted")
                            } catch (error: Exception) {
                                LifecycleLogger.log("CompanionNotifications", "synthetic_notification_failed ${error.javaClass.simpleName}")
                            }
                        }, delay * 1000L)
                        result.success(mapOf("version" to 1, "accepted" to true))
                        if (closeUi) activity.finishAndRemoveTask()
                    } catch (error: Exception) { result.error("DIAGNOSTIC_FAILED", error.message, null) }
                }
                "presenceStatus", "associatePresence" -> {
                    try {
                        val address = call.argument<String>("address")?.uppercase() ?: error("Address required")
                        require(Regex("[0-9A-F]{2}(:[0-9A-F]{2}){5}").matches(address))
                        if (call.method == "presenceStatus") result.success(PrototypePresence.status(context, address))
                        else PrototypeHub.worker.post {
                            try {
                                val state = PrototypeHub.journal(context).control()
                                check(state["desired_running"] == true && state["address"] == address) {
                                    "Connect the selected watch before enabling presence recovery"
                                }
                                PrototypeHub.main.post { association.associate(address, result) }
                            } catch (error: Exception) {
                                PrototypeHub.main.post { result.error("ASSOCIATION_FAILED", error.message, null) }
                            }
                        }
                    } catch (error: Exception) { result.error("ASSOCIATION_FAILED", error.message, null) }
                }
                "start" -> {
                    try {
                        val address = call.argument<String>("address")?.uppercase() ?: error("Address required")
                        require(Regex("[0-9A-F]{2}(:[0-9A-F]{2}){5}").matches(address))
                        if (Build.VERSION.SDK_INT >= 31) require(ContextCompat.checkSelfPermission(context,
                            Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED) { "Bluetooth permission required" }
                        PrototypeHub.worker.post {
                            try {
                                val owner = CompanionPrototypeService.instance?.runtime
                                check(owner?.active != true || owner.store.control()["address"] == address) { "Stop before changing watch" }
                                PrototypeHub.main.post {
                                    try {
                                        ContextCompat.startForegroundService(context, Intent(context, CompanionPrototypeService::class.java)
                                            .setAction(CompanionPrototypeService.START).putExtra("address", address))
                                        result.success(mapOf("version" to 1, "accepted" to true))
                                    } catch (error: Exception) { result.error("START_FAILED", error.message, null) }
                                }
                            } catch (error: Exception) { PrototypeHub.main.post { result.error("START_FAILED", error.message, null) } }
                        }
                    } catch (error: Exception) { result.error("START_FAILED", error.message, null) }
                }
                "stop", "syncTime", "retryRecordings", "ackEvents", "configureNotifications", "setRecordingSync", "startRemoteFixture" -> {
                    PrototypeHub.worker.post {
                        try {
                            val store = PrototypeHub.journal(context)
                            val service = CompanionPrototypeService.instance
                            when (call.method) {
                                "startRemoteFixture" -> (service?.remoteFixture ?: error("Service not running")).startFixture()
                                "stop" -> {
                                    if (service?.runtime != null) {
                                        service.runtime!!.stop()
                                        service.stopPresenceObservation()
                                    }
                                    else store.update("runtime_stopped", mapOf("desired_running" to false,
                                        "phase" to "stopped", "generation" to (store.control()["generation"] as Number).toLong() + 1,
                                        "notifications" to emptyMap<String, Any>()))
                                    if (service == null) runCatching { PrototypePresence.stopObserving(context, store.control()["address"] as String) }
                                    PrototypeHub.main.post { service?.stopSelf() }
                                }
                                "syncTime" -> (service?.transport ?: error("Service not running")).syncTime()
                                "retryRecordings" -> (service?.transport ?: error("Service not running")).retryRecordings()
                                "setRecordingSync" -> {
                                    val enabled = call.argument<Boolean>("enabled") ?: error("Enabled required")
                                    if (service?.transport != null) service.transport!!.setRecordingSync(enabled)
                                    else store.update("recording_sync_configuration", mapOf("recording_sync_enabled" to enabled))
                                }
                                "configureNotifications" -> {
                                    val enabled = call.argument<Boolean>("enabled") ?: error("Enabled required")
                                    val packages = call.argument<List<String>>("packages") ?: error("Packages required")
                                    if (enabled) check(dev.zswatch.app.NotificationListenerServiceImpl.isNotificationAccessEnabled(context)) {
                                        "Grant notification access before enabling forwarding"
                                    }
                                    PrototypeNotifications(store).configure(enabled, packages)
                                    service?.transport?.flushNotifications()
                                    if (enabled) PrototypeHub.main.post { dev.zswatch.app.NotificationListenerServiceImpl.replayPrototypeNotifications() }
                                }
                                "ackEvents" -> {
                                    val cursor = call.argument<Number>("cursor") ?: error("Cursor required")
                                    require(cursor.toDouble() == cursor.toLong().toDouble()) { "Integer cursor required" }
                                    store.acknowledge(cursor.toLong())
                                }
                            }
                            val state = PrototypeHub.snapshot(context, service?.runtime?.active == true)
                            PrototypeHub.main.post { result.success(state) }
                        } catch (error: Exception) { PrototypeHub.main.post { result.error("COMMAND_FAILED", error.message, null) } }
                    }
                }
                else -> result.notImplemented()
            }
        }
        events.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, eventSink: EventChannel.EventSink) {
                if (!BuildConfig.COMPANION_RUNTIME_PROTOTYPE || (arguments as? Map<*, *>)?.get("version") != 1) {
                    eventSink.error("DISABLED_OR_VERSION", "Unsupported prototype subscription", null); return
                }
                sink = eventSink
                PrototypeHub.observers.add(changed)
                LifecycleLogger.log("CompanionPrototype", "ui_attached transportOwner=service")
                changed()
            }
            override fun onCancel(arguments: Any?) { detach() }
        })
    }

    private fun snapshot(deliver: (Any?) -> Unit, failed: (String?) -> Unit = { sink?.error("SNAPSHOT_FAILED", it, null) }) {
        PrototypeHub.worker.post {
            try {
                val state = PrototypeHub.snapshot(context, CompanionPrototypeService.instance?.runtime?.active == true)
                PrototypeHub.main.post { deliver(state) }
            } catch (error: Exception) { PrototypeHub.main.post { failed(error.message) } }
        }
    }

    private fun detach() {
        sink = null
        PrototypeHub.observers.remove(changed)
        LifecycleLogger.log("CompanionPrototype", "ui_detached transportOwner=service")
    }

    fun onActivityResult(requestCode: Int, resultCode: Int) = association.onActivityResult(requestCode, resultCode)

    fun dispose() { association.dispose(); detach(); methods.setMethodCallHandler(null); events.setStreamHandler(null) }
}
