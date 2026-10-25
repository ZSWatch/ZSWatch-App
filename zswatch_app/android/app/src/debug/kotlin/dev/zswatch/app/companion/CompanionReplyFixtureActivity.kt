package dev.zswatch.app.companion

import android.app.Activity
import android.os.Bundle
import androidx.core.app.RemoteInput
import org.json.JSONObject
import java.io.File

/** Gmail-like reply target. Writes locally and immediately closes; no email or account access. */
class CompanionReplyFixtureActivity : Activity() {
    override fun onCreate(state: Bundle?) {
        super.onCreate(state)
        val text = RemoteInput.getResultsFromIntent(intent)?.getCharSequence("reply_text")?.toString()
        if (text != null) {
            val root = File(filesDir, "companion-reply-fixture").apply { mkdirs() }
            File(root, "replies.jsonl").appendText(JSONObject(mapOf("utc_ms" to System.currentTimeMillis(),
                "activity" to true, "text" to text)).toString() + "\n")
        }
        finish()
    }
}
