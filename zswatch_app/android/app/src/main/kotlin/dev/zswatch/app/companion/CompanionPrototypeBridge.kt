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
import java.util.concurrent.atomic.AtomicInteger

/** UI is an observer/controller, never a lifetime owner or a BLE transport. */
class CompanionPrototypeBridge(activity: Activity, messenger: BinaryMessenger) {
    private val context = activity.applicationContext
    private val association = PrototypeAssociation(activity)
    private val methods = MethodChannel(messenger, "dev.zswatch.app/companion_v1")
    private val events = EventChannel(messenger, "dev.zswatch.app/companion_events_v1")
    private val logs = EventChannel(messenger, "dev.zswatch.app/companion_logs_v1")
    private val traffic = EventChannel(messenger, "dev.zswatch.app/companion_traffic_v1")
    private val sensors = EventChannel(messenger, "dev.zswatch.app/companion_sensors_v1")
    @Volatile private var sensorSink: EventChannel.EventSink? = null
    private val pendingSensors = AtomicInteger()
    private val sensorChanged: (Map<String, Any?>) -> Unit = { event ->
        val expected = sensorSink
        if (expected != null) {
            if (pendingSensors.incrementAndGet() <= 64) PrototypeHub.main.post {
                try { if (sensorSink === expected) expected.success(event) }
                finally { pendingSensors.decrementAndGet() }
            } else pendingSensors.decrementAndGet()
        }
    }
    @Volatile private var trafficSink: EventChannel.EventSink? = null
    private val pendingTraffic = AtomicInteger()
    private val trafficChanged: (Map<String, Any?>) -> Unit = { event ->
        val expected = trafficSink
        if (expected != null) {
            // A slow/closing UI must never grow the main queue or stall BLE.
            if (pendingTraffic.incrementAndGet() <= 64) PrototypeHub.main.post {
                try { if (trafficSink === expected) expected.success(event) }
                finally { pendingTraffic.decrementAndGet() }
            } else pendingTraffic.decrementAndGet()
        }
    }
    @Volatile private var logSink: EventChannel.EventSink? = null
    private val logChanged: (Map<String, Any?>) -> Unit = { event ->
        val expected = logSink
        PrototypeHub.main.post { if (expected != null && logSink === expected) expected.success(event) }
    }
    private var sink: EventChannel.EventSink? = null
    private val changed: () -> Unit = { snapshot(deliver = { sink?.success(it) }) }

    init {
        methods.setMethodCallHandler { call, result ->
            if ((call.arguments as? Map<*, *>)?.get("version") != 1) {
                result.error("VERSION", "Unsupported companion bridge version", null)
            } else when (call.method) {
                "sensorState", "setSensor" -> PrototypeHub.worker.post {
                    try {
                        val link = CompanionPrototypeService.instance?.transport ?: error("Native owner required")
                        if (call.method == "sensorState") {
                            val state = link.sensors.state()
                            PrototypeHub.main.post { result.success(state) }
                        } else {
                            val value = call.argument<Any>("generation")
                            require(value is Int || value is Long) { "Integer generation required" }
                            val name = call.argument<String>("sensor") ?: error("Sensor required")
                            val enabled = call.argument<Boolean>("enabled") ?: error("Boolean enabled required")
                            link.setSensor((value as Number).toLong(), name, enabled) { outcome ->
                                PrototypeHub.main.post { outcome.fold({ result.success(mapOf("version" to 1, "completed" to true)) },
                                    { result.error("SENSOR_FAILED", it.message, null) }) }
                            }
                        }
                    } catch (error: Exception) { PrototypeHub.main.post { result.error("SENSOR_FAILED", error.message, null) } }
                }
                "setLogStreaming" -> PrototypeHub.worker.post {
                    try {
                        val enabled = call.argument<Boolean>("enabled") ?: error("Boolean enabled required")
                        if (enabled) check(PrototypeHub.logObservers.contains(logChanged)) { "Open the log viewer first" }
                        val link = CompanionPrototypeService.instance?.transport ?: error("Service not running")
                        link.setLogStreaming(enabled)
                        PrototypeHub.main.post { result.success(mapOf("version" to 1, "accepted" to true)) }
                    } catch (error: Exception) { PrototypeHub.main.post { result.error("LOG_STREAM_FAILED", error.message, null) } }
                }
                "configureVoiceProcessing" -> PrototypeHub.worker.post {
                    try {
                        val args = call.arguments as Map<*, *>
                        val store = PrototypeHub.journal(context)
                        val watch = args["watch_id"] as String
                        require(watch == store.control()["address"] && Regex("[0-9A-F]{2}(:[0-9A-F]{2}){5}").matches(watch))
                        val enabled = args["enabled"] as Boolean
                        if (enabled) check(store.control()["desired_running"] == true) { "Connect the watch first" }
                        val config = PrototypeVoicePolicy.configuration(args["transcription_model"] as String,
                            args["analysis_model"] as String, args["correct_transcription"] as Boolean)
                        store.update("voice_processing_policy_changed", mapOf("voice_processing_policy" to
                            (config + mapOf("watch_id" to watch, "enabled" to enabled))))
                        snapshot(result::success) { result.error("PROCESSING_POLICY_FAILED", it, null) }
                    } catch (error: Exception) { PrototypeHub.main.post { result.error("PROCESSING_POLICY_FAILED", error.message, null) } }
                }
                "voiceJob", "cancelVoiceJob" -> PrototypeHub.worker.post {
                    try {
                        val id = call.argument<String>("job_id") ?: error("Job ID required")
                        require(Regex("[a-f0-9]{64}").matches(id))
                        val jobs = PrototypeJobs(PrototypeHub.jobJournal(context))
                        val item = jobs.state(id)
                        val spec = item.getJSONObject("spec")
                        require(spec.getString("provider") == "dart-voice-v1" &&
                            spec.getString("watch_id") == PrototypeHub.journal(context).control()["address"])
                        if (call.method == "cancelVoiceJob") {
                            // Persist/fence first; a late result can never publish.
                            jobs.cancel(id)
                            CompanionPrototypeService.instance?.localFixture?.cancel(id)
                        }
                        val current = jobs.state(id)
                        val detail = PrototypeStore.asMap(current) + mapOf("processing" to !current.isNull("lease_until"),
                            "transcript_saved" to current.has("transcript"))
                        PrototypeHub.main.post { result.success(mapOf("version" to 1, "job_id" to id,
                            "job" to detail)) }
                    } catch (error: Exception) { PrototypeHub.main.post { result.error("JOB_FAILED", error.message, null) } }
                }
                "processRecording" -> PrototypeHub.worker.post {
                    try {
                        val input = call.arguments as Map<*, *>
                        val id = (CompanionPrototypeService.instance?.localFixture ?: error("Running companion required"))
                            .startRecording(input["identity"] as String, input["transcription_model"] as String,
                                input["analysis_model"] as String, input["correct_transcription"] as Boolean)
                        PrototypeHub.main.post { result.success(mapOf("version" to 1, "job_id" to id)) }
                    } catch (error: Exception) { PrototypeHub.main.post { result.error("PROCESSING_FAILED", error.message, null) } }
                }
                "snapshot" -> snapshot(result::success) { message -> result.error("SNAPSHOT_FAILED", message, null) }
                "discoverWatch" -> PrototypeHub.worker.post {
                    try {
                        val state = PrototypeHub.journal(context).control()
                        val generation = (state["generation"] as Number).toLong()
                        check(PrototypeDiscovery.canSelect(state, CompanionPrototypeService.instance?.runtime?.active == true, generation)) {
                            "Disconnect before choosing another watch"
                        }
                        PrototypeHub.main.post { association.discover(generation, result) }
                    } catch (error: Exception) {
                        PrototypeHub.main.post { result.error("DISCOVERY_FAILED", error.message, null) }
                    }
                }
                "notificationStatus" -> PrototypeHub.worker.post {
                    try {
                        val selected = (PrototypeHub.journal(context).control()["notification_packages"] as? List<*>)
                            ?.filterIsInstance<String>() ?: emptyList()
                        val state = mapOf("version" to 1,
                            "access_granted" to dev.zswatch.app.NotificationListenerServiceImpl.isNotificationAccessEnabled(context),
                            "listener_connected" to dev.zswatch.app.NotificationListenerServiceImpl.isPrototypeConnected,
                            "apps" to dev.zswatch.app.NotificationListenerServiceImpl.getPrototypeNotificationApps(context, selected))
                        PrototypeHub.main.post { result.success(state) }
                    } catch (error: Exception) {
                        PrototypeHub.main.post { result.error("NOTIFICATION_STATUS_FAILED", error.message, null) }
                    }
                }
                "requestNotificationAccess" -> {
                    activity.startActivity(Intent(android.provider.Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                    result.success(mapOf("version" to 1, "accepted" to true))
                }
                "postTestNotification" -> {
                    if (!BuildConfig.DEBUG) { result.notImplemented(); return@setMethodCallHandler }
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
                "start", "startDiscovered" -> {
                    try {
                        val address = call.argument<String>("address")?.uppercase() ?: error("Address required")
                        require(Regex("[0-9A-F]{2}(:[0-9A-F]{2}){5}").matches(address))
                        if (Build.VERSION.SDK_INT >= 31) require(ContextCompat.checkSelfPermission(context,
                            Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED) { "Bluetooth permission required" }
                        val expectedGeneration = if (call.method == "startDiscovered") when (val value = (call.arguments as? Map<*, *>)?.get("generation")) {
                            is Int -> value.toLong()
                            is Long -> value
                            else -> error("Integer generation required")
                        }.also { require(it >= 0) } else null
                        PrototypeHub.worker.post {
                            try {
                                val owner = CompanionPrototypeService.instance?.runtime
                                check(owner?.active != true || owner.store.control()["address"] == address) { "Stop before changing watch" }
                                if (expectedGeneration != null) check(PrototypeDiscovery.canSelect(
                                    PrototypeHub.journal(context).control(), owner?.active == true, expectedGeneration)) {
                                    "Watch selection expired; choose again"
                                }
                                PrototypeHub.main.post {
                                    try {
                                        val start = Intent(context, CompanionPrototypeService::class.java)
                                            .setAction(if (expectedGeneration == null) CompanionPrototypeService.START else CompanionPrototypeService.START_DISCOVERED)
                                            .putExtra("address", address)
                                        if (expectedGeneration != null) start.putExtra("generation", expectedGeneration)
                                        ContextCompat.startForegroundService(context, start)
                                        result.success(mapOf("version" to 1, "accepted" to true))
                                    } catch (error: Exception) { result.error("START_FAILED", error.message, null) }
                                }
                            } catch (error: Exception) { PrototypeHub.main.post { result.error("START_FAILED", error.message, null) } }
                        }
                    } catch (error: Exception) { result.error("START_FAILED", error.message, null) }
                }
                "startFirmware", "cancelFirmware" -> PrototypeHub.worker.post {
                    try {
                        val args = call.arguments as? Map<*, *> ?: error("Arguments required")
                        val owner = CompanionPrototypeService.instance?.firmware ?: error("Native firmware owner required")
                        if (call.method == "cancelFirmware") {
                            owner.cancel(args["id"] as? String ?: error("Operation ID required"))
                            PrototypeHub.main.post { result.success(mapOf("version" to 1, "accepted" to true)) }
                        } else {
                            val generation = when (val value = args["generation"]) {
                                is Int -> value.toLong()
                                is Long -> value
                                else -> error("Integer generation required")
                            }
                            require(generation >= 0)
                            val images = (args["images"] as? List<*>) ?: error("Images required")
                            val resources = args["resources"]?.let { it as? ByteArray ?: error("Resource bytes required") }
                            require(images.size in 0..3 && (images.isNotEmpty() || resources != null))
                            val parsed = images.map { value ->
                                val image = value as? Map<*, *> ?: error("Image map required")
                                val index = image["index"] as? Int ?: error("Integer image index required")
                                index to (image["bytes"] as? ByteArray ?: error("Firmware bytes required"))
                            }
                            val (id, owned) = owner.start(generation, parsed, resources)
                            PrototypeHub.main.post { result.success(mapOf("version" to 1, "accepted" to true, "id" to id, "generation" to owned)) }
                        }
                    } catch (error: Exception) { PrototypeHub.main.post { result.error("FIRMWARE_FAILED", error.message, null) } }
                }
                "startWatchface", "resetWatchface" -> PrototypeHub.worker.post {
                    try {
                        val args = call.arguments as? Map<*, *> ?: error("Arguments required")
                        val generation = when (val value = args["generation"]) {
                            is Int -> value.toLong()
                            is Long -> value
                            else -> error("Integer generation required")
                        }
                        require(generation >= 0)
                        val link = CompanionPrototypeService.instance?.transport ?: error("Native owner required")
                        val id = if (call.method == "resetWatchface") link.resetWatchface(generation)
                            else link.startWatchface(generation, args["bytes"] as? ByteArray ?: error("Image bytes required"),
                                args["name"] as? String ?: error("Image name required"))
                        PrototypeHub.main.post { result.success(mapOf("version" to 1, "generation" to generation, "id" to id, "accepted" to true)) }
                    } catch (error: Exception) { PrototypeHub.main.post { result.error("WATCHFACE_FAILED", error.message, null) } }
                }
                "inspectCoredump", "downloadCoredump" -> PrototypeHub.worker.post {
                    try {
                        val generation = when (val value = call.argument<Any>("generation")) {
                            is Int -> value.toLong()
                            is Long -> value
                            else -> error("Integer generation required")
                        }
                        require(generation >= 0)
                        val link = CompanionPrototypeService.instance?.transport ?: error("Native owner required")
                        if (call.method == "downloadCoredump") link.downloadCoredump(generation) { outcome ->
                            PrototypeHub.main.post { outcome.fold({ reply -> result.success(mapOf(
                                "version" to 1, "bytes" to reply.bytes)) },
                                { error -> result.error("COREDUMP_FAILED", error.message, null) }) }
                        } else {
                            val erase = call.argument<Boolean>("erase") ?: false
                            link.inspectCoredump(generation, erase) { outcome -> PrototypeHub.main.post {
                                outcome.fold({ result.success(mapOf("version" to 1, "completed" to true)) },
                                    { error -> result.error("COREDUMP_FAILED", error.message, null) })
                            } }
                        }
                    } catch (error: Exception) { PrototypeHub.main.post { result.error("COREDUMP_FAILED", error.message, null) } }
                }
                "inspectLogs" -> PrototypeHub.worker.post {
                    try {
                        val args = call.arguments as? Map<*, *> ?: error("Arguments required")
                        val generation = when (val value = args["generation"]) {
                            is Int -> value.toLong()
                            is Long -> value
                            else -> error("Integer generation required")
                        }
                        require(generation >= 0)
                        val path = args["path"]
                        require(path == null || path is String)
                        val link = CompanionPrototypeService.instance?.transport ?: error("Native owner required")
                        link.inspectLogs(generation, path as String?) { outcome -> PrototypeHub.main.post {
                            outcome.fold({ reply -> result.success(mapOf("version" to 1, "generation" to generation,
                                "files" to reply.files.map { mapOf("path" to it.path, "size_bytes" to it.size) },
                                "bytes" to reply.bytes)) }, { error -> result.error("LOG_FILES_FAILED", error.message, null) })
                        } }
                    } catch (error: Exception) { PrototypeHub.main.post { result.error("LOG_FILES_FAILED", error.message, null) } }
                }
                "prepareShell", "executeShell" -> PrototypeHub.worker.post {
                    try {
                        val args = call.arguments as? Map<*, *> ?: error("Arguments required")
                        val generation = when (val value = args["generation"]) {
                            is Int -> value.toLong()
                            is Long -> value
                            else -> error("Integer generation required")
                        }
                        require(generation >= 0)
                        val link = CompanionPrototypeService.instance?.transport ?: error("Native owner required")
                        if (call.method == "prepareShell") {
                            link.prepareShell(generation) { outcome -> PrototypeHub.main.post {
                                outcome.fold({ prepared -> result.success(mapOf("version" to 1,
                                    "generation" to prepared, "prepared_from_generation" to generation)) },
                                    { error -> result.error("SHELL_FAILED", error.message, null) })
                            } }
                        } else {
                            val command = args["command"] as? String ?: error("Command required")
                            link.executeShell(generation, command) { outcome -> PrototypeHub.main.post {
                                outcome.fold({ reply -> result.success(mapOf("version" to 1,
                                    "generation" to generation, "output" to reply.output, "return_code" to reply.returnCode)) },
                                    { error -> result.error("SHELL_FAILED", error.message, null) })
                            } }
                        }
                    } catch (error: Exception) { PrototypeHub.main.post { result.error("SHELL_FAILED", error.message, null) } }
                }
                "stop", "forgetWatch", "findWatch", "syncTime", "requestDeviceInfo", "requestRecordingList", "retryRecordings", "ackEvents", "configureNotifications", "configureGps", "configureHttp", "setRecordingSync", "startRemoteFixture", "startLocalFixture" -> {
                    PrototypeHub.worker.post {
                        try {
                            val store = PrototypeHub.journal(context)
                            val service = CompanionPrototypeService.instance
                            var forgetReceipt: Map<String, Any?>? = null
                            var findReceipt: Map<String, Any?>? = null
                            when (call.method) {
                                "startRemoteFixture" -> (service?.remoteFixture ?: error("Service not running")).startFixture()
                                "startLocalFixture" -> (service?.localFixture ?: error("Service not running")).startFixture()
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
                                "forgetWatch" -> {
                                    val address = call.argument<String>("address") ?: error("Address required")
                                    val selected = store.control()["address"] == PrototypeForget.normalize(address)
                                    try {
                                        forgetReceipt = PrototypeForget(store, service?.runtime,
                                            { PrototypePresence.stopObserving(context, it) },
                                            { PrototypePresence.disassociate(context, it) }).forget(address)
                                    } finally {
                                        // Even OS failure must release a selected owner's stopped service.
                                        if (selected && service?.runtime?.active != true)
                                            PrototypeHub.main.post { service?.stopSelf() }
                                    }
                                }
                                "syncTime" -> (service?.transport ?: error("Service not running")).syncTime()
                                "requestDeviceInfo" -> (service?.transport ?: error("Service not running")).requestDeviceInfo()
                                "requestRecordingList" -> (service?.transport ?: error("Service not running")).requestRecordings()
                                "retryRecordings" -> (service?.transport ?: error("Service not running")).retryRecordings()
                                "setRecordingSync" -> {
                                    val enabled = call.argument<Boolean>("enabled") ?: error("Enabled required")
                                    if (service?.transport != null) service.transport!!.setRecordingSync(enabled)
                                    else store.update("recording_sync_configuration", mapOf("recording_sync_enabled" to enabled))
                                }
                                "configureHttp" -> {
                                    val enabled = (call.arguments as? Map<*, *>)?.get("enabled") as? Boolean
                                        ?: error("Boolean enabled required")
                                    if (service?.transport != null) service.transport!!.configureHttp(enabled)
                                    else PrototypeHttpRelay.configure(store, enabled)
                                }
                                "findWatch" -> {
                                    val generation = when (val value = (call.arguments as? Map<*, *>)?.get("generation")) {
                                        is Int -> value.toLong()
                                        is Long -> value
                                        else -> error("Integer generation required")
                                    }
                                    require(generation >= 0)
                                    val link = service?.transport ?: error("Native owner required")
                                    link.findWatch(generation)
                                    findReceipt = mapOf("generation" to generation, "accepted" to true)
                                }
                                "configureGps" -> {
                                    val enabled = (call.arguments as? Map<*, *>)?.get("enabled") as? Boolean
                                        ?: error("Boolean enabled required")
                                    if (service?.gps != null) service.gps!!.configure(enabled)
                                    else AndroidPrototypeGps.configureStopped(context, store, enabled)
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
                            val state = PrototypeHub.snapshot(context, service?.runtime?.active == true).toMutableMap()
                            if (forgetReceipt != null) state["forget_receipt"] = forgetReceipt
                            if (findReceipt != null) state["find_receipt"] = findReceipt
                            PrototypeHub.main.post { result.success(state) }
                        } catch (error: Exception) { PrototypeHub.main.post { result.error("COMMAND_FAILED", error.message, null) } }
                    }
                }
                else -> result.notImplemented()
            }
        }
        events.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, eventSink: EventChannel.EventSink) {
                if ((arguments as? Map<*, *>)?.get("version") != 1) {
                    eventSink.error("DISABLED_OR_VERSION", "Unsupported prototype subscription", null); return
                }
                sink = eventSink
                PrototypeHub.observers.add(changed)
                LifecycleLogger.log("CompanionPrototype", "ui_attached transportOwner=service")
                changed()
            }
            override fun onCancel(arguments: Any?) { detach() }
        })
        logs.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, eventSink: EventChannel.EventSink) {
                if ((arguments as? Map<*, *>)?.get("version") != 1) {
                    eventSink.error("VERSION", "Unsupported log subscription", null); return
                }
                logSink = eventSink
                PrototypeHub.worker.post {
                    // Activity disposal can race a queued listen.
                    if (logSink !== eventSink) return@post
                    PrototypeHub.logObservers.add(logChanged)
                    logChanged(CompanionPrototypeService.instance?.transport?.liveLogs?.state()
                        ?: mapOf("version" to 1, "kind" to "state", "requested" to false, "written" to false, "pending" to false))
                }
            }
            override fun onCancel(arguments: Any?) { detachLogs() }
        })
        traffic.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, eventSink: EventChannel.EventSink) {
                if ((arguments as? Map<*, *>)?.get("version") != 1) {
                    eventSink.error("VERSION", "Unsupported traffic subscription", null); return
                }
                trafficSink = eventSink
                PrototypeHub.worker.post {
                    if (trafficSink === eventSink) PrototypeHub.trafficObservers.add(trafficChanged)
                }
            }
            override fun onCancel(arguments: Any?) { detachTraffic() }
        })
        sensors.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, eventSink: EventChannel.EventSink) {
                sensorSink = eventSink
                PrototypeHub.worker.post {
                    if (sensorSink === eventSink) {
                        PrototypeHub.sensorObservers.add(sensorChanged)
                        CompanionPrototypeService.instance?.transport?.sensors?.state()?.let(sensorChanged)
                    }
                }
            }
            override fun onCancel(arguments: Any?) { detachSensors() }
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

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) = association.onActivityResult(requestCode, resultCode, data)

    private fun detachLogs() {
        logSink = null
        PrototypeHub.worker.post {
            PrototypeHub.logObservers.remove(logChanged)
            if (PrototypeHub.logObservers.isEmpty()) {
                val link = CompanionPrototypeService.instance?.transport
                if (link?.liveLogs?.state()?.get("requested") == true) {
                    // Detaching diagnostics never stops the companion. If the
                    // link is already gone, reset has fenced the pending write.
                    runCatching { link.setLogStreaming(false) }.onFailure { link.liveLogs.reset() }
                }
            }
        }
    }

    private fun detachTraffic() {
        trafficSink = null
        PrototypeHub.worker.post { PrototypeHub.trafficObservers.remove(trafficChanged) }
    }

    private fun detachSensors() {
        sensorSink = null
        PrototypeHub.worker.post {
            PrototypeHub.sensorObservers.remove(sensorChanged)
            if (PrototypeHub.sensorObservers.isEmpty()) CompanionPrototypeService.instance?.transport?.stopSensors()
        }
    }

    fun dispose() {
        association.dispose(); detach(); detachLogs(); detachTraffic(); detachSensors()
        methods.setMethodCallHandler(null); events.setStreamHandler(null); logs.setStreamHandler(null)
        traffic.setStreamHandler(null)
        sensors.setStreamHandler(null)
    }
}
