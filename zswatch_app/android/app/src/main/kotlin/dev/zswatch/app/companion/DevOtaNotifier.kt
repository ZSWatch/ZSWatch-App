package dev.zswatch.app.companion

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.app.NotificationCompat
import dev.zswatch.app.MainActivity
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder

/**
 * Long-polls the dev OTA server (scripts/dev_ota) while the companion service runs and
 * notifies about a new build when the app is not in the foreground. Installing stays
 * in the app: tapping the notification opens it and Flutter shows the install dialog.
 */
class DevOtaNotifier(private val context: Context) {
    companion object {
        private const val TAG = "DevOtaNotifier"
        private const val CHANNEL_ID = "dev_ota"
        const val NOTIFICATION_ID = 7301
        private const val WAIT_S = 25

        fun cancel(context: Context) =
            context.getSystemService(NotificationManager::class.java)?.cancel(NOTIFICATION_ID)
    }

    @Volatile private var running = false
    private var thread: Thread? = null

    fun start() {
        if (running) return
        running = true
        thread = Thread(::loop, "dev-ota-notifier").apply { isDaemon = true; start() }
    }

    fun stop() {
        running = false
        thread?.interrupt()
        thread = null
    }

    private fun loop() {
        // Flutter's shared_preferences stores keys with a "flutter." prefix here.
        val flutter = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val own = context.getSharedPreferences("dev_ota_native", Context.MODE_PRIVATE)
        var after: String? = null
        while (running) {
            try {
                val url = flutter.getString("flutter.dev_ota_url", "")!!.trimEnd('/')
                val token = flutter.getString("flutter.dev_ota_token", "")!!
                if (url.isEmpty() || token.isEmpty()) { Thread.sleep(60_000); continue }
                val build = latest(url, token, after) ?: run { Thread.sleep(30_000); null } ?: continue
                val id = build.getString("id")
                after = id
                val handled = flutter.getString("flutter.dev_ota_handled_build", null)
                if (id != handled && id != own.getString("notified", null) && !MainActivity.isResumed) {
                    notify(build)
                    own.edit().putString("notified", id).apply()
                }
            } catch (_: InterruptedException) {
                return
            } catch (error: Exception) {
                Log.w(TAG, "poll failed: ${error.message}")
                try { Thread.sleep(30_000) } catch (_: InterruptedException) { return }
            }
        }
    }

    private fun latest(base: String, token: String, after: String?): JSONObject? {
        val query = if (after == null) "" else "?after=${URLEncoder.encode(after, "UTF-8")}&wait=$WAIT_S"
        val connection = URL("$base/api/latest$query").openConnection() as HttpURLConnection
        try {
            connection.connectTimeout = 15_000
            connection.readTimeout = (WAIT_S + 15) * 1000
            connection.setRequestProperty("Authorization", "Bearer $token")
            if (connection.responseCode != 200) throw IllegalStateException("HTTP ${connection.responseCode}")
            val body = connection.inputStream.bufferedReader().use { it.readText() }
            return JSONObject(body).optJSONObject("build")
        } finally {
            connection.disconnect()
        }
    }

    private fun notify(build: JSONObject) {
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL_ID, "Dev firmware", NotificationManager.IMPORTANCE_HIGH))
        val open = PendingIntent.getActivity(context, NOTIFICATION_ID,
            Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val title = listOf(build.optString("branch"), build.optString("commit").take(8))
            .filter { it.isNotEmpty() }.joinToString(" · ")
        val note = build.optString("note")
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_download_done)
            .setContentTitle("New dev firmware")
            .setContentText(if (note.isNotEmpty()) note else title)
            .setStyle(NotificationCompat.BigTextStyle().bigText(listOf(title, note).filter { it.isNotEmpty() }.joinToString("\n")))
            .setContentIntent(open)
            .setAutoCancel(true)
            .build()
        try {
            manager.notify(NOTIFICATION_ID, notification)
        } catch (error: SecurityException) {
            Log.w(TAG, "notification permission missing")
        }
    }
}
