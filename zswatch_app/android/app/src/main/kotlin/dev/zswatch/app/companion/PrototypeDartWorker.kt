package dev.zswatch.app.companion

import android.content.Context
import dev.zswatch.app.LifecycleLogger
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.pathprovider.PathProviderPlugin

/** Owns a headless engine on Android's main thread. Never attaches an Activity. */
class PrototypeDartWorker(private val context: Context) {
    class WorkerFailure(val code: String) : IllegalStateException(code)
    @Volatile private var closed = false
    private var engine: FlutterEngine? = null
    private var liteRtBridge: dev.zswatch.app.LiteRtLmBridge? = null
    private var channel: MethodChannel? = null
    private var ready = false
    private var pending: (() -> Unit)? = null
    private var currentJob: String? = null
    private var executing = false
    private var saveTranscript: ((String) -> Boolean)? = null

    // Caller serializes jobs on PrototypeHub.worker. Replies return there too.
    fun execute(claim: PrototypeJobs.Claim, input: Map<String, Any?> = emptyMap(),
                checkpoint: ((String) -> Boolean)? = null, done: (Result<Map<*, *>>) -> Unit) {
        PrototypeHub.main.post {
            if (closed) return@post
            fun reply(value: Result<Map<*, *>>) {
                executing = false
                currentJob = null; saveTranscript = null
                if (closed) {
                    // Native inference has returned. Retain the isolate briefly for
                    // the existing libraries' post-completion logger callbacks.
                    PrototypeHub.main.postDelayed({ destroy() }, 500)
                    return
                }
                if (!closed) PrototypeHub.worker.post { if (!closed) done(value) }
            }
            try {
                check(pending == null) { "Dart worker busy" }
                currentJob = claim.id; saveTranscript = checkpoint
                val dispatch = {
                    executing = true
                    channel!!.invokeMethod(if (claim.spec.getString("provider") == "dart-voice-v1") "executeRecording" else "executeFixture",
                        mapOf("version" to 1, "job_id" to claim.id, "spec" to PrototypeStore.asMap(claim.spec)) + input, object : MethodChannel.Result {
                        override fun success(result: Any?) {
                            if (result is Map<*, *>) reply(Result.success(result))
                            else reply(Result.failure(IllegalArgumentException("Invalid worker response")))
                        }
                        override fun error(code: String, message: String?, details: Any?) =
                            reply(Result.failure(WorkerFailure(code)))
                        override fun notImplemented() = reply(Result.failure(IllegalStateException("Worker method unavailable")))
                    })
                }
                if (engine == null) {
                    val loader = FlutterInjector.instance().flutterLoader()
                    loader.startInitialization(context)
                    loader.ensureInitializationComplete(context, null)
                    // Processing plugins only. Never register BLE or attach an Activity.
                    val created = FlutterEngine(context, null, false)
                    engine = created
                    created.plugins.add(PathProviderPlugin())
                    created.plugins.add(com.antonkarpenko.ffmpegkit.FFmpegKitFlutterPlugin())
                    liteRtBridge = dev.zswatch.app.LiteRtLmBridge(context).also { it.setup(created) }
                    MethodChannel(created.dartExecutor.binaryMessenger, "dev.zswatch.app/productivity").setMethodCallHandler { call, result ->
                        val am = context.getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
                        val memory = android.app.ActivityManager.MemoryInfo().also { am.getMemoryInfo(it) }
                        when (call.method) {
                            "getDeviceMemoryMB" -> result.success((memory.totalMem / (1024 * 1024)).toInt())
                            "getAvailableMemoryMB" -> result.success((memory.availMem / (1024 * 1024)).toInt())
                            else -> result.notImplemented()
                        }
                    }
                    MethodChannel(created.dartExecutor.binaryMessenger, "dev.zswatch.app/llm_compute").setMethodCallHandler { call, result ->
                        try {
                            when (call.method) {
                                // Native job owns the complete STT + analysis execution window.
                                "start", "stop" -> result.success(true)
                                "isRunning" -> result.success(dev.zswatch.app.LlmComputeService.isRunning())
                                else -> result.notImplemented()
                            }
                        } catch (error: Exception) { result.error("COMPUTE_SERVICE", error.javaClass.simpleName, null) }
                    }
                    channel = MethodChannel(created.dartExecutor.binaryMessenger, "dev.zswatch.app/companion_worker_v1").also {
                        it.setMethodCallHandler { call, result ->
                            if (call.method == "ready" && (call.arguments as? Map<*, *>)?.get("version") == 1 && !closed) {
                                ready = true
                                result.success(null)
                                LifecycleLogger.log("CompanionDartWorker", "ready activityAttached=false")
                                val waiting = pending; pending = null; waiting?.invoke()
                            } else if (call.method == "checkpoint") {
                                val args = call.arguments as? Map<*, *>
                                val job = args?.get("job_id") as? String
                                val text = args?.get("transcript") as? String
                                PrototypeHub.worker.post {
                                    try {
                                        check(!closed && job == currentJob && text != null && saveTranscript?.invoke(text) == true)
                                        PrototypeHub.main.post { result.success(null) }
                                    } catch (error: Exception) { PrototypeHub.main.post { result.error("CHECKPOINT_REJECTED", error.javaClass.simpleName, null) } }
                                }
                            } else result.notImplemented()
                        }
                    }
                    pending = dispatch
                    created.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint(loader.findAppBundlePath(), "companionWorkerMain"))
                    LifecycleLogger.log("CompanionDartWorker", "engine_created activityAttached=false")
                } else if (ready) dispatch() else pending = dispatch
            } catch (error: Exception) {
                pending = null
                reply(Result.failure(error))
            }
        }
    }

    fun close() {
        if (closed) return
        closed = true // Fence posted replies before destroying the engine.
        saveTranscript = null
        runCatching { dev.zswatch.app.LlmComputeService.stop(context) }
        PrototypeHub.main.post {
            pending = null
            if (executing) cancel(currentJob) else destroy()
        }
    }

    /** Keep the engine alive until its FFI computation and callbacks finish. */
    fun cancel(jobId: String?) {
        PrototypeHub.main.post {
            if (!executing || jobId == null || jobId != currentJob) return@post
            channel?.invokeMethod("cancel", mapOf("job_id" to jobId), object : MethodChannel.Result {
                override fun success(result: Any?) {
                    LifecycleLogger.log("CompanionDartWorker", "cancel_signalled accepted=${result == true}")
                }
                override fun error(code: String, message: String?, details: Any?) {
                    LifecycleLogger.log("CompanionDartWorker", "cancel_signal_failed code=$code")
                }
                override fun notImplemented() {
                    LifecycleLogger.log("CompanionDartWorker", "cancel_signal_unavailable")
                }
            })
        }
    }

    private fun destroy() {
        pending = null; ready = false; currentJob = null
        channel?.setMethodCallHandler(null); channel = null
        liteRtBridge?.close(); liteRtBridge = null
        engine?.destroy(); engine = null
        LifecycleLogger.log("CompanionDartWorker", "engine_closed")
    }
}
