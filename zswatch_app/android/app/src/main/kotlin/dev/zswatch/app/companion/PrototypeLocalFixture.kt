package dev.zswatch.app.companion

import android.content.Context
import dev.zswatch.app.BuildConfig
import dev.zswatch.app.LifecycleLogger
import org.json.JSONObject

/** Local execution uses the same native lease/result/outbox contract as remote. */
class PrototypeLocalFixture(private val context: Context, private val service: CompanionPrototypeService) {
    private val jobs get() = PrototypeJobs(PrototypeHub.jobJournal(context))
    private var engine: PrototypeDartWorker? = null
    private var busy = false
    private var execution = 0L
    private var closed = false
    private var failedClosed = false
    private fun running() = !closed && CompanionPrototypeService.instance === service && service.runtime?.active == true &&
        service.runtime?.store?.control()?.get("desired_running") == true
    private val tick = object : Runnable {
        override fun run() {
            if (closed || failedClosed) return
            try { advance() } catch (error: Exception) {
                failedClosed = true
                engine?.close(); engine = null
                LifecycleLogger.log("CompanionLocalJobs", "fixture_disabled ${error.javaClass.simpleName}")
                return
            }
            PrototypeHub.worker.postDelayed(this, 2000)
        }
    }
    fun startMaintenance() { PrototypeHub.worker.post(tick) }
    fun startFixture(): String {
        check(BuildConfig.COMPANION_RUNTIME_PROTOTYPE && running()) { "Running prototype required" }
        val spec = context.assets.open("job-v1.json").bufferedReader().use { JSONObject(it.readText()) }
            .put("backend", "local").put("provider", "dart-fixture").put("upload_authorized", false)
            .put("recording_id", "fixture-recording-local-001")
        val id = jobs.create(spec)
        PrototypeHub.jobJournal(context).update("local_fixture_enabled", mapOf("local_fixture_enabled" to true))
        advance()
        return id
    }
    private fun advance() {
        if (!BuildConfig.COMPANION_RUNTIME_PROTOTYPE || busy || !running() ||
            PrototypeHub.jobJournal(context).control()["local_fixture_enabled"] != true) return
        val now = System.currentTimeMillis() / 1000
        val claim = jobs.identities().asSequence().mapNotNull { id ->
            val spec = jobs.state(id).getJSONObject("spec")
            if (spec.getString("backend") != "local" || spec.getString("provider") != "dart-fixture" ||
                spec.getBoolean("upload_authorized")) null else jobs.claim(id, now, leaseSeconds = 60)
        }.firstOrNull() ?: return
        busy = true
        val operation = ++execution
        val currentEngine = engine ?: PrototypeDartWorker(context).also { engine = it }
        // No Dart-owned scheduler, BLE session or job DB. Native owns the claim.
        currentEngine.execute(claim) { response ->
            if (!busy || execution != operation || engine !== currentEngine || !running()) return@execute
            busy = false
            try {
                val received = System.currentTimeMillis() / 1000
                val validated = response.mapCatching { value ->
                    require(value["version"] == 1 && value["job_id"] == claim.id && value["plugin_ready"] == true)
                    JSONObject(value["result"] as Map<*, *>).also(PrototypeJobs::validateResult)
                }
                validated.fold({ result ->
                    jobs.complete(claim, received, result, null)
                    LifecycleLogger.log("CompanionLocalJobs", "result_callback pluginReady=true activityRequired=false")
                }, {
                    jobs.defer(claim, received, 10, if (response.isSuccess) "invalid_dart_result" else "dart_worker_failed",
                        maxAttempts = if (response.isSuccess) 1 else 5)
                })
            } catch (error: Exception) {
                LifecycleLogger.log("CompanionLocalJobs", "fixture_commit_failed ${error.javaClass.simpleName}")
            }
        }
        PrototypeHub.worker.postDelayed({
            if (busy && execution == operation && engine === currentEngine && !closed) {
                busy = false; currentEngine.close(); engine = null
                // Lease has expired; next claim fences this abandoned computation.
                LifecycleLogger.log("CompanionLocalJobs", "worker_timeout")
            }
        }, 60000)
    }
    fun close() {
        closed = true; busy = false
        PrototypeHub.worker.removeCallbacks(tick)
        engine?.close(); engine = null
    }
}
