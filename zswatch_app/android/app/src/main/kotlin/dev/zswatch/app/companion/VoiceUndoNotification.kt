package dev.zswatch.app.companion

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import org.json.JSONObject

/** Phone-side Undo for a voice result, shown for the same window as the watch popup. */
object VoiceUndoNotification {
    private const val CHANNEL = "voice_results"
    private const val UNDO = "dev.zswatch.app.VOICE_UNDO"

    private fun id(jobId: String) = jobId.take(7).toInt(16)

    fun show(context: Context, jobId: String, result: JSONObject, undoUntil: Long) {
        val remaining = undoUntil - System.currentTimeMillis()
        if (remaining <= 0) return
        val manager = context.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(
            NotificationChannel(CHANNEL, "Voice memo results", NotificationManager.IMPORTANCE_HIGH))
        val undo = Intent(context, Receiver::class.java).setAction(UNDO).putExtra("job_id", jobId)
        val open = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val actions = result.getJSONArray("actions")
        val first = actions.optJSONObject(0)
        val text = if (first == null) "Saved" else listOfNotNull(first.optString("type"),
            first.optString("start_time").ifEmpty { first.optString("due_date") }.ifEmpty { null })
            .joinToString(" • ")
        val notification = NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setContentTitle(result.getString("summary"))
            .setContentText(text)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setTimeoutAfter(remaining)
            .setWhen(undoUntil).setUsesChronometer(true).setChronometerCountDown(true)
            .setContentIntent(open?.let {
                PendingIntent.getActivity(context, 22, it, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
            })
            .addAction(0, "Undo", PendingIntent.getBroadcast(context, id(jobId), undo,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT))
            .build()
        try { manager.notify(id(jobId), notification) } catch (_: SecurityException) { /* notifications denied */ }
    }

    fun cancel(context: Context, jobId: String) {
        context.getSystemService(NotificationManager::class.java).cancel(id(jobId))
    }

    class Receiver : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val jobId = intent.getStringExtra("job_id") ?: return
            if (intent.action != UNDO || !Regex("[a-f0-9]{64}").matches(jobId)) return
            val pending = goAsync()
            val app = context.applicationContext
            PrototypeHub.worker.post {
                try { CompanionVoiceActions.undo(app, jobId) } finally { pending.finish() }
            }
        }
    }
}
