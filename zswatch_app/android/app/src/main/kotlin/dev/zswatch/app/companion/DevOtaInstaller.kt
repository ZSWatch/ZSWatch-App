package dev.zswatch.app.companion

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import org.json.JSONObject
import java.io.ByteArrayInputStream
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.zip.ZipInputStream

/**
 * Installs a dev OTA build from the notification without opening the app. Uses the
 * same native firmware owner as the app's update screen and reports to the server.
 */
internal class DevOtaInstaller(private val context: Context, private val notifier: DevOtaNotifier) {
    companion object {
        private const val TAG = "DevOtaInstaller"
        const val ACTION_INSTALL = "dev.zswatch.app.DEV_OTA_INSTALL"
        const val EXTRA_BUILD = "build"
        private val terminal = setOf("completed", "failed", "cancelled")
    }

    class Receiver : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action != ACTION_INSTALL) return
            val build = intent.getStringExtra(EXTRA_BUILD)?.let { JSONObject(it) } ?: return
            val installer = CompanionPrototypeService.instance?.devOtaInstaller
            if (installer == null) {
                DevOtaNotifier.showResult(context, "Dev firmware not installed", "The companion service is not running")
                return
            }
            installer.install(build)
        }
    }

    @Volatile private var running = false

    fun install(build: JSONObject) {
        if (running) return
        running = true
        Thread({
            try { run(build) } catch (error: Exception) {
                Log.w(TAG, "install failed", error)
                DevOtaNotifier.showResult(context, "Dev firmware update failed", error.message ?: "Unknown error")
            } finally { running = false }
        }, "dev-ota-install").start()
    }

    private fun run(build: JSONObject) {
        val flutter = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val base = flutter.getString("flutter.dev_ota_url", "")!!.trimEnd('/')
        val token = flutter.getString("flutter.dev_ota_token", "")!!
        val id = build.getString("id")
        // The app must not offer this build again.
        flutter.edit().putString("flutter.dev_ota_handled_build", id).commit()

        notifier.showProgress("Downloading")
        report(base, token, id, "downloading")
        val zip = download(base, token, build)
        val (images, resources) = unpack(zip)

        notifier.showProgress("Updating the watch")
        report(base, token, id, "uploading")
        val service = CompanionPrototypeService.instance ?: error("Companion service not running")
        val uploadStarted = System.currentTimeMillis()
        val operation = start(service, images, resources)

        val result = awaitFirmware(service, operation)
        val outcome = awaitVersion(service, build, uploadStarted, result)
        report(base, token, id, outcome.first, outcome.second)
        when (outcome.first) {
            "running" -> DevOtaNotifier.showResult(context, "Dev firmware installed", outcome.second)
            "mismatch" -> DevOtaNotifier.showResult(context, "Watch reports a different build", outcome.second)
            else -> DevOtaNotifier.showResult(context, "Dev firmware update failed", outcome.second)
        }
    }

    private fun download(base: String, token: String, build: JSONObject): ByteArray {
        val connection = URL("$base/api/builds/${build.getString("id")}.zip").openConnection() as HttpURLConnection
        try {
            connection.connectTimeout = 15_000
            connection.readTimeout = 60_000
            connection.setRequestProperty("Authorization", "Bearer $token")
            if (connection.responseCode != 200) error("Download failed: HTTP ${connection.responseCode}")
            val bytes = connection.inputStream.use { it.readBytes() }
            val sha = MessageDigest.getInstance("SHA-256").digest(bytes).joinToString("") { "%02x".format(it) }
            check(sha == build.optString("sha256")) { "Download checksum mismatch" }
            return bytes
        } finally {
            connection.disconnect()
        }
    }

    private fun entries(bytes: ByteArray): Map<String, ByteArray> {
        val files = mutableMapOf<String, ByteArray>()
        ZipInputStream(ByteArrayInputStream(bytes)).use { zip ->
            while (true) {
                val entry = zip.nextEntry ?: break
                if (!entry.isDirectory) files[entry.name.substringAfterLast('/')] = zip.readBytes()
            }
        }
        return files
    }

    /** A build is a dfu_application.zip, or a zip of one plus lvgl_resources_raw.bin. */
    private fun unpack(bytes: ByteArray): Pair<List<Pair<Int, ByteArray>>, ByteArray?> {
        val outer = entries(bytes)
        val dfu = outer["dfu_application.zip"]?.let { entries(it) } ?: outer
        val manifest = JSONObject(String(dfu["manifest.json"] ?: error("No manifest in build"), Charsets.UTF_8))
        val files = manifest.getJSONArray("files")
        val images = (0 until files.length()).map { i ->
            val file = files.getJSONObject(i)
            file.getString("image_index").toInt() to (dfu[file.getString("file")] ?: error("Missing ${file.getString("file")}"))
        }
        return images to outer["lvgl_resources_raw.bin"]
    }

    private fun start(service: CompanionPrototypeService, images: List<Pair<Int, ByteArray>>, resources: ByteArray?): String {
        val latch = CountDownLatch(1)
        var outcome: Result<String> = Result.failure(IllegalStateException("Start timed out"))
        PrototypeHub.worker.post {
            outcome = runCatching {
                val owner = service.firmware ?: error("Native firmware owner required")
                val runtime = service.runtime ?: error("Watch not connected")
                owner.start(runtime.generation, images, resources).first
            }
            latch.countDown()
        }
        latch.await(30, TimeUnit.SECONDS)
        return outcome.getOrThrow()
    }

    private fun operation(service: CompanionPrototypeService): Map<*, *>? =
        service.runtime?.store?.control()?.get("firmware_operation") as? Map<*, *>

    /** Returns the native error, null when the native update completed. */
    private fun awaitFirmware(service: CompanionPrototypeService, id: String): String? {
        val deadline = System.currentTimeMillis() + 70 * 60 * 1000L
        var lastPhase: String? = null
        while (System.currentTimeMillis() < deadline) {
            val op = operation(service)?.takeIf { it["id"] == id }
            val phase = op?.get("phase") as? String
            if (phase != null && phase in terminal) return if (phase == "completed") null else (op["error"] as? String ?: phase)
            if (phase != null && phase != lastPhase) {
                lastPhase = phase
                notifier.showProgress(phase.replace('_', ' ').replaceFirstChar { it.uppercase() })
            }
            Thread.sleep(1000)
        }
        return "deadline"
    }

    /** The sha the watch reports after the update decides, as in the app. */
    private fun awaitVersion(service: CompanionPrototypeService, build: JSONObject, since: Long, failure: String?): Pair<String, String> {
        val commit = build.optString("commit").take(12)
        val deadline = System.currentTimeMillis() + if (failure != null) 3 * 60_000L else 60_000L
        var sha: String? = null
        var version: String? = null
        while (System.currentTimeMillis() < deadline) {
            val info = service.runtime?.store?.control()?.get("watch_info") as? Map<*, *>
            val observed = (info?.get("version_observed_ms") as? Number)?.toLong() ?: 0
            if (observed > since) {
                sha = info?.get("firmware_sha") as? String
                version = info?.get("firmware_version") as? String
                if (sha != null) break
            }
            Thread.sleep(1000)
        }
        val detail = listOfNotNull(version?.let { "fw $it" }, sha?.let { "sha $it" }, failure?.let { "(app: $it)" }).joinToString(" ")
        val matches = if (commit.isNotEmpty() && sha != null) sha.startsWith(commit) else failure == null
        return (if (matches) "running" else if (failure != null) "failed" else "mismatch") to detail
    }

    private fun report(base: String, token: String, id: String, state: String, detail: String? = null) {
        val body = JSONObject().put("id", id).put("state", state).apply { if (detail != null) put("detail", detail) }
        repeat(4) { attempt ->
            try {
                val connection = URL("$base/api/status").openConnection() as HttpURLConnection
                try {
                    connection.connectTimeout = 15_000
                    connection.readTimeout = 15_000
                    connection.requestMethod = "POST"
                    connection.doOutput = true
                    connection.setRequestProperty("Authorization", "Bearer $token")
                    connection.setRequestProperty("Content-Type", "application/json")
                    connection.outputStream.use { it.write(body.toString().toByteArray()) }
                    if (connection.responseCode in 200..299) return
                } finally {
                    connection.disconnect()
                }
            } catch (error: Exception) {
                Log.w(TAG, "report $state failed: ${error.message}")
            }
            Thread.sleep(2000L * (attempt + 1))
        }
    }
}
