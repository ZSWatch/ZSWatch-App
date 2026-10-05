package dev.zswatch.app.companion

import android.content.Context
import dev.zswatch.app.BuildConfig
import dev.zswatch.app.LifecycleLogger
import org.json.JSONObject
import java.io.File

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
            try { service.transport?.deliverVoiceResults() } catch (error: Exception) {
                LifecycleLogger.log("CompanionLocalJobs", "delivery_deferred ${error.javaClass.simpleName}")
            }
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
        check(BuildConfig.DEBUG && running()) { "Running prototype required" }
        val spec = context.assets.open("job-v1.json").bufferedReader().use { JSONObject(it.readText()) }
            .put("backend", "local").put("provider", "dart-fixture").put("upload_authorized", false)
            .put("recording_id", "fixture-recording-local-001")
        val id = jobs.create(spec)
        PrototypeHub.jobJournal(context).update("local_fixture_enabled", mapOf("local_fixture_enabled" to true))
        advance()
        return id
    }
    fun startRecording(identity: String, stt: String, llm: String, correct: Boolean): String {
        check(running()) { "Running companion required" }
        require(stt.matches(Regex("[a-zA-Z0-9_]+")) && llm.isNotBlank() && llm.length <= 256 && !llm.contains('|'))
        val metadata = service.runtime!!.store.record(identity) ?: error("Unknown recording")
        val receipt = ReceiptFiles(File(context.filesDir, "companion-prototype/recordings")).recover(identity, metadata)
            ?: error("Verified recording receipt required")
        require(receipt["sha256"] == metadata["sha256"] && receipt["address"] == service.runtime!!.store.control()["address"])
        val model = "$stt|$llm|$correct"
        val previous = jobs.identities().map { jobs.state(it) }.filter { it.getJSONObject("spec").getString("recording_id") == identity }
        val existing = previous.firstOrNull { it.getJSONObject("spec").getString("model") == model &&
            it.getJSONObject("spec").getString("input_sha256") == receipt["sha256"] &&
            it.getString("state") !in listOf("failed", "cancelled") }
        if (existing != null) return PrototypeJobs.key(existing.getJSONObject("spec"))
        val next = (previous.maxOfOrNull { it.getJSONObject("spec").getLong("generation") } ?: 0) + 1
        val spec = JSONObject().put("version", 1).put("watch_id", receipt["address"]).put("recording_id", identity)
            .put("input_sha256", receipt["sha256"]).put("backend", "local").put("provider", "dart-voice-v1")
            .put("model", model).put("pipeline_revision", "voice-v1").put("generation", next).put("upload_authorized", false)
        val id = jobs.create(spec); advance(); return id
    }

    private fun advance() {
        if (busy || !running()) return
        val now = System.currentTimeMillis() / 1000
        val claim = jobs.identities().asSequence().mapNotNull { id ->
            val spec = jobs.state(id).getJSONObject("spec")
            val real = spec.getString("provider") == "dart-voice-v1"
            val fixture = BuildConfig.DEBUG && spec.getString("provider") == "dart-fixture" &&
                PrototypeHub.jobJournal(context).control()["local_fixture_enabled"] == true
            if (spec.getString("backend") != "local" || (!real && !fixture) || spec.getBoolean("upload_authorized") ||
                spec.getString("watch_id") != (if (real) service.runtime!!.store.control()["address"] else "fixture-watch")) null
            else jobs.claim(id, now, leaseSeconds = if (real) 900 else 60)
        }.firstOrNull() ?: return
        busy = true
        val operation = ++execution
        val currentEngine = engine ?: PrototypeDartWorker(context).also { engine = it }
        // No Dart-owned scheduler, BLE session or job DB. Native owns the claim.
        val real = claim.spec.getString("provider") == "dart-voice-v1"
        if (real) {
            try { dev.zswatch.app.LlmComputeService.start(context) }
            catch (error: Exception) {
                busy = false
                jobs.defer(claim, now, 10, "execution_not_allowed", blocked = true)
                return
            }
        }
        val input = if (real) mapOf("recording" to service.runtime!!.store.record(claim.spec.getString("recording_id")),
            "transcript" to jobs.state(claim.id).optString("transcript").takeIf { it.isNotEmpty() }) else emptyMap()
        currentEngine.execute(claim, input, checkpoint = { text ->
            running() && busy && execution == operation && jobs.checkpointTranscript(claim, System.currentTimeMillis() / 1000, text)
        }) { response ->
            if (!busy || execution != operation || engine !== currentEngine || !running()) return@execute
            busy = false
            if (real) dev.zswatch.app.LlmComputeService.stop(context)
            try {
                val received = System.currentTimeMillis() / 1000
                val validated = response.mapCatching { value ->
                    require(value["version"] == 1 && value["job_id"] == claim.id && value["plugin_ready"] == true) { "worker_envelope" }
                    JSONObject(value["result"] as Map<*, *>).also(PrototypeJobs::validateResult)
                }
                validated.fold({ result ->
                    if (jobs.complete(claim, received, result, null))
                        LifecycleLogger.log("CompanionLocalJobs", "result_committed pluginReady=true activityRequired=false")
                }, {
                    val code = (response.exceptionOrNull() as? PrototypeDartWorker.WorkerFailure)?.code
                    val permanent = code in listOf("NO_SPEECH", "MODEL_MISSING")
                    val label = if (response.isSuccess) "invalid_dart_result" else when (code) {
                        "NO_SPEECH" -> "no_speech"
                        "MODEL_MISSING" -> "model_missing"
                        else -> "dart_worker_failed"
                    }
                    jobs.defer(claim, received, 10, label, maxAttempts = if (response.isSuccess || permanent) 1 else 5)
                    LifecycleLogger.record(context, "CompanionLocalJobs", "result_rejected reason=$label validation=${it.message.takeIf { name -> name?.startsWith("result_") == true || name == "worker_envelope" } ?: it.javaClass.simpleName}")
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
        }, if (real) 900000 else 60000)
    }
    fun close() {
        closed = true; busy = false
        PrototypeHub.worker.removeCallbacks(tick)
        engine?.close(); engine = null
    }
}
