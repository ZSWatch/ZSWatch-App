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
    @Volatile private var closed = false
    private var engine: FlutterEngine? = null
    private var channel: MethodChannel? = null
    private var ready = false
    private var pending: (() -> Unit)? = null

    // Caller serializes jobs on PrototypeHub.worker. Replies return there too.
    fun execute(claim: PrototypeJobs.Claim, done: (Result<Map<*, *>>) -> Unit) {
        PrototypeHub.main.post {
            if (closed) return@post
            fun reply(value: Result<Map<*, *>>) {
                if (!closed) PrototypeHub.worker.post { if (!closed) done(value) }
            }
            try {
                check(pending == null) { "Dart worker busy" }
                val dispatch = {
                    channel!!.invokeMethod("executeFixture", mapOf("version" to 1, "job_id" to claim.id,
                        "spec" to PrototypeStore.asMap(claim.spec)), object : MethodChannel.Result {
                        override fun success(result: Any?) {
                            if (result is Map<*, *>) reply(Result.success(result))
                            else reply(Result.failure(IllegalArgumentException("Invalid worker response")))
                        }
                        override fun error(code: String, message: String?, details: Any?) =
                            reply(Result.failure(IllegalStateException(code)))
                        override fun notImplemented() = reply(Result.failure(IllegalStateException("Worker method unavailable")))
                    })
                }
                if (engine == null) {
                    val loader = FlutterInjector.instance().flutterLoader()
                    loader.startInitialization(context)
                    loader.ensureInitializationComplete(context, null)
                    // Explicit plugin subset: no BLE, Activity bridges or model initialization.
                    val created = FlutterEngine(context, null, false)
                    engine = created
                    created.plugins.add(PathProviderPlugin())
                    channel = MethodChannel(created.dartExecutor.binaryMessenger, "dev.zswatch.app/companion_worker_v1").also {
                        it.setMethodCallHandler { call, result ->
                            if (call.method == "ready" && (call.arguments as? Map<*, *>)?.get("version") == 1 && !closed) {
                                ready = true
                                result.success(null)
                                LifecycleLogger.log("CompanionDartWorker", "ready activityAttached=false")
                                val waiting = pending; pending = null; waiting?.invoke()
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
        closed = true // Fence posted replies before destroying the engine.
        PrototypeHub.main.post {
            pending = null; ready = false
            channel?.setMethodCallHandler(null); channel = null
            engine?.destroy(); engine = null
            LifecycleLogger.log("CompanionDartWorker", "engine_closed")
        }
    }
}
