package dev.zswatch.app.companion

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.media.MediaMetadata
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.os.IBinder
import androidx.core.app.NotificationCompat
import dev.zswatch.app.BuildConfig
import org.json.JSONObject
import java.io.File

/** Explicit private debug fixture: a real Android MediaSession, no audio player. */
class CompanionMediaFixtureService : Service() {
    private var session: MediaSession? = null
    private var playing = false
    private var track = 1
    private var album = 1
    private var sequence = 0
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!BuildConfig.DEBUG || intent?.action !in setOf("START", "PLAY", "PAUSE", "NEXT", "PREVIOUS", "METADATA", "STOP")) {
            stopSelf(); return START_NOT_STICKY
        }
        if (intent?.action == "STOP") { stopSelf(); return START_NOT_STICKY }
        if (session == null) {
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(NotificationChannel("companion_media_fixture", "Companion media fixture", NotificationManager.IMPORTANCE_LOW))
            startForeground(1004, NotificationCompat.Builder(this, "companion_media_fixture")
                .setSmallIcon(android.R.drawable.ic_media_play).setContentTitle("ZSWatch synthetic media fixture")
                .setContentText("No audio playback").setOngoing(true).build())
            session = MediaSession(this, "ZSWatchSyntheticMediaFixture").apply {
                setCallback(object : MediaSession.Callback() {
                    override fun onPlay() { playing = true; update("watch_play") }
                    override fun onPause() { playing = false; update("watch_pause") }
                    override fun onSkipToNext() { track++; update("watch_next") }
                    override fun onSkipToPrevious() { track = maxOf(1, track - 1); update("watch_previous") }
                })
                isActive = true
            }
        }
        when (intent?.action) {
            "PLAY" -> playing = true
            "PAUSE" -> playing = false
            "NEXT" -> track++
            "PREVIOUS" -> track = maxOf(1, track - 1)
            "METADATA" -> album++
        }
        update("fixture_${intent?.action?.lowercase()}")
        return START_NOT_STICKY
    }

    private fun update(event: String) {
        sequence++
        session?.setMetadata(MediaMetadata.Builder().putString(MediaMetadata.METADATA_KEY_TITLE, "Fixture Track $track")
            .putString(MediaMetadata.METADATA_KEY_ARTIST, "Fixture Artist").putString(MediaMetadata.METADATA_KEY_ALBUM, "Fixture Album $album")
            .putLong(MediaMetadata.METADATA_KEY_DURATION, 120000).build())
        session?.setPlaybackState(PlaybackState.Builder().setActions(PlaybackState.ACTION_PLAY or PlaybackState.ACTION_PAUSE or
            PlaybackState.ACTION_SKIP_TO_NEXT or PlaybackState.ACTION_SKIP_TO_PREVIOUS)
            .setState(if (playing) PlaybackState.STATE_PLAYING else PlaybackState.STATE_PAUSED, 0, if (playing) 1f else 0f).build())
        val root = File(filesDir, "companion-media-fixture").apply { mkdirs() }
        File(root, "state-v1.json").writeText(JSONObject(mapOf("version" to 1, "fixture" to true, "sequence" to sequence,
            "event" to event, "active" to (session != null), "track" to track, "album" to album, "playing" to playing, "utc_ms" to System.currentTimeMillis())).toString())
    }

    override fun onDestroy() {
        session?.isActive = false; session?.release(); session = null
        playing = false; update("fixture_stopped")
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }
}
