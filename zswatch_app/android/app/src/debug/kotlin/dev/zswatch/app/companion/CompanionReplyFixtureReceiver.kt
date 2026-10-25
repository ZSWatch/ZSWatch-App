package dev.zswatch.app.companion

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Bundle
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.Person
import androidx.core.app.RemoteInput
import dev.zswatch.app.BuildConfig
import dev.zswatch.app.NotificationListenerServiceImpl
import dev.zswatch.app.NotificationDebugHelper
import org.json.JSONObject
import java.io.File

/**
 * Explicit private debug fixture: a chat notification with a reply action, like a
 * messaging app posts. Replies are appended to files/companion-reply-fixture/replies.jsonl.
 *
 *   adb shell am broadcast -n com.zswatch.app/dev.zswatch.app.companion.CompanionReplyFixtureReceiver \
 *     -a dev.zswatch.app.REPLY_FIXTURE_POST --es sender Anna --es text "Fika i eftermiddag"
 */
class CompanionReplyFixtureReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (!BuildConfig.DEBUG) return
        when (intent.action) {
            POST -> post(context, intent.getStringExtra("sender") ?: "Fixture", intent.getStringExtra("text") ?: "Fixture message", null,
                intent.getBooleanExtra("activity_reply", false))
            SEND -> {
                // Only our own fixture is addressable; this cannot reply to real contacts.
                val notice = context.getSystemService(NotificationManager::class.java).activeNotifications
                    .firstOrNull { it.tag == TAG && it.id == ID } ?: return
                val error = NotificationListenerServiceImpl.replyToPrototypeNotification(notice.key, "Fixture reply")
                val root = File(context.filesDir, "companion-reply-fixture").apply { mkdirs() }
                File(root, "dispatch.json").writeText(JSONObject(mapOf("error" to error)).toString())
            }
            REPLY -> {
                val text = RemoteInput.getResultsFromIntent(intent)?.getCharSequence(KEY)?.toString() ?: return
                val root = File(context.filesDir, "companion-reply-fixture").apply { mkdirs() }
                File(root, "replies.jsonl").appendText(JSONObject(mapOf("utc_ms" to System.currentTimeMillis(),
                    "source" to RemoteInput.getResultsSource(intent), "text" to text)).toString() + "\n")
                // Messaging apps add the sent reply to the conversation; do the same.
                post(context, intent.getStringExtra("sender") ?: "Fixture", intent.getStringExtra("text") ?: "", text)
            }
        }
    }

    private fun post(context: Context, sender: String, text: String, reply: String?, activity: Boolean = false) {
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(NotificationChannel(CHANNEL, "Companion reply fixture", NotificationManager.IMPORTANCE_DEFAULT))
        val replyIntent = Intent(context, if (activity) CompanionReplyFixtureActivity::class.java else CompanionReplyFixtureReceiver::class.java)
            .setAction(REPLY).putExtra("sender", sender).putExtra("text", text)
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        val pending = if (activity) PendingIntent.getActivity(context, 0, replyIntent, flags)
            else PendingIntent.getBroadcast(context, 0, replyIntent, flags)
        val action = NotificationCompat.Action.Builder(android.R.drawable.ic_menu_send, "Reply", pending)
            .addRemoteInput(RemoteInput.Builder(KEY).setLabel("Reply").build())
            .setSemanticAction(NotificationCompat.Action.SEMANTIC_ACTION_REPLY)
            .setAllowGeneratedReplies(false).build()
        val person = Person.Builder().setName(sender).build()
        val style = NotificationCompat.MessagingStyle(Person.Builder().setName("Me").build())
            .addMessage(text, System.currentTimeMillis(), person)
        if (reply != null) style.addMessage(reply, System.currentTimeMillis(), null as Person?)
        val notification = NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(android.R.drawable.ic_dialog_email).setContentTitle(sender).setContentText(reply ?: text)
            .setStyle(style).addAction(action).setOnlyAlertOnce(reply != null)
            .setExtras(Bundle().apply { putBoolean(NotificationDebugHelper.EXTRA_DEBUG_NOTIFICATION, true) })
            .build()
        NotificationManagerCompat.from(context).notify(TAG, ID, notification)
    }

    private companion object {
        const val POST = "dev.zswatch.app.REPLY_FIXTURE_POST"
        const val REPLY = "dev.zswatch.app.REPLY_FIXTURE_REPLY"
        const val SEND = "dev.zswatch.app.REPLY_FIXTURE_SEND"
        const val KEY = "reply_text"
        const val CHANNEL = "companion_reply_fixture"
        const val TAG = "companion_reply_fixture"
        const val ID = 1005
    }
}
