package dev.zswatch.app.companion

import android.content.Context
import dev.zswatch.app.BuildConfig
import dev.zswatch.app.LifecycleLogger
import org.json.JSONObject
import java.io.IOException
import java.io.ByteArrayOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

/** Synthetic metadata only. Fixed loopback endpoint; never opens a recording. */
class PrototypeRemoteFixture(private val context: Context, private val service: CompanionPrototypeService) {
    private val executor = Executors.newSingleThreadExecutor { task -> Thread(task, "ZSWatchRemoteFixture").apply { isDaemon = true } }
    private var busy = false
    private var closed = false
    private var failedClosed = false
    @Volatile private var connection: HttpURLConnection? = null
    private val jobs get() = PrototypeJobs(PrototypeHub.jobJournal(context))
    private fun running() = !closed && CompanionPrototypeService.instance === service && service.runtime?.active == true &&
        service.runtime?.store?.control()?.get("desired_running") == true
    private val tick = object : Runnable {
        override fun run() {
            if (closed || failedClosed) return
            try { advance() }
            catch (error: Exception) {
                // A bad job journal must not kill the shared BLE worker or reset data.
                failedClosed = true
                LifecycleLogger.log("CompanionJobs", "fixture_disabled ${error.javaClass.simpleName}")
                return
            }
            PrototypeHub.worker.postDelayed(this, 5000)
        }
    }

    fun startMaintenance() { PrototypeHub.worker.post(tick) }

    fun startFixture(): String {
        check(BuildConfig.COMPANION_RUNTIME_PROTOTYPE && running()) { "Running prototype required" }
        val spec = context.assets.open("job-v1.json").bufferedReader().use { JSONObject(it.readText()) }
        val id = jobs.create(spec)
        PrototypeHub.jobJournal(context).update("remote_fixture_enabled", mapOf("fixture_enabled" to true))
        advance()
        return id
    }

    fun advance() {
        if (!BuildConfig.COMPANION_RUNTIME_PROTOTYPE || failedClosed || busy || !running() ||
            PrototypeHub.jobJournal(context).control()["fixture_enabled"] != true) return
        val now = System.currentTimeMillis() / 1000
        val claim = jobs.identities().asSequence().mapNotNull { id ->
            val spec = jobs.state(id).getJSONObject("spec")
            // A persisted local/provider job cannot silently become a remote upload.
            if (spec.getString("backend") != "remote" || spec.getString("provider") != "loopback-fixture" ||
                !spec.getBoolean("upload_authorized")) null else jobs.claim(id, now)
        }.firstOrNull() ?: return
        busy = true
        executor.execute {
            val response = runCatching { request(claim) }
            PrototypeHub.worker.post {
                busy = false
                if (!running()) return@post // Saved lease permits recovery after its deadline.
                val received = System.currentTimeMillis() / 1000 // Do not reuse request-start lease time.
                try {
                    try {
                        response.fold({ body ->
                            require(body.get("version") == 1 && body.getString("remote_id") == "fixture-" + claim.id)
                            val remoteId = body.getString("remote_id")
                            if (claim.remoteId == null && !jobs.accepted(claim, received, remoteId)) return@fold
                            when (body.getString("state")) {
                                "running" -> jobs.defer(claim, received, 10, "server_pending")
                                "succeeded" -> jobs.complete(claim, received, body.getJSONObject("result"), remoteId)
                                "cancelled" -> jobs.cancel(claim.id, claim, received)
                                "failed" -> jobs.defer(claim, received, 0, "remote_failed", maxAttempts = 1)
                                else -> throw IllegalArgumentException("Unsupported fixture state")
                            }
                        }, { error ->
                            if (error is HttpFailure) {
                                val permanent = error.status in 400..499 && error.status !in listOf(401, 403, 408, 429)
                                jobs.defer(claim, received, maxOf(10L, error.retryAfter), "http_${error.status}",
                                    blocked = error.status in listOf(401, 403), maxAttempts = if (permanent) 1 else 5)
                            } else if (error is IOException)
                                jobs.defer(claim, received, minOf(300L, 10L shl minOf(claim.attempts - 1, 5)), "transport_error")
                            else jobs.defer(claim, received, 0, "invalid_remote_response", maxAttempts = 1)
                        })
                    } catch (_: IllegalArgumentException) {
                        jobs.defer(claim, received, 0, "invalid_remote_response", maxAttempts = 1)
                    } catch (_: org.json.JSONException) {
                        jobs.defer(claim, received, 0, "invalid_remote_response", maxAttempts = 1)
                    }
                } catch (error: Exception) {
                    // No response text, job spec, credentials or audio in logs.
                    LifecycleLogger.log("CompanionJobs", "fixture_commit_failed ${error.javaClass.simpleName}")
                }
            }
        }
    }

    private class HttpFailure(val status: Int, val retryAfter: Long) : IOException()
    private fun request(claim: PrototypeJobs.Claim): JSONObject {
        val path = if (claim.remoteId == null) "/v1/jobs" else "/v1/jobs/fixture-${claim.id}"
        require(claim.remoteId == null || claim.remoteId == "fixture-${claim.id}")
        val client = URL("http://127.0.0.1:8765$path").openConnection() as HttpURLConnection
        connection = client
        try {
            client.connectTimeout = 3000; client.readTimeout = 3000; client.instanceFollowRedirects = false
            client.setRequestProperty("Content-Type", "application/json")
            if (claim.remoteId == null) {
                client.requestMethod = "POST"; client.doOutput = true
                val body = PrototypeJobs.canonical(JSONObject().put("spec", claim.spec).put("idempotency_key", claim.id))
                    .toByteArray(Charsets.UTF_8)
                client.setFixedLengthStreamingMode(body.size)
                client.outputStream.use { it.write(body) }
            }
            val status = client.responseCode
            if (status !in 200..299) throw HttpFailure(status,
                client.getHeaderField("Retry-After")?.toLongOrNull()?.coerceIn(0, 3600) ?: 0)
            val bytes = client.inputStream.use { input ->
                val output = ByteArrayOutputStream(); val buffer = ByteArray(4096)
                while (true) {
                    val count = input.read(buffer)
                    if (count < 0) break
                    require(output.size() + count <= 131072) { "Oversize fixture response" }
                    output.write(buffer, 0, count)
                }
                output.toByteArray()
            }
            return JSONObject(String(bytes, Charsets.UTF_8))
        } finally { connection = null; client.disconnect() }
    }

    fun close() {
        closed = true
        PrototypeHub.worker.removeCallbacks(tick)
        connection?.disconnect()
        executor.shutdownNow()
    }
}
