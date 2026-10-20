package dev.zswatch.app

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

/**
 * Speaks text through the phone speaker for hardware tests (e.g. voice memo
 * recording on the watch). `speak` replies once the utterance has finished.
 * Same channel as the iOS TestSpeech in AppDelegate.swift.
 */
class TestSpeech(private val context: Context, messenger: BinaryMessenger) {
    private val main = Handler(Looper.getMainLooper())
    private val channel = MethodChannel(messenger, "dev.zswatch.app/test_speech")
    private var ready = false
    private var pending: MethodChannel.Result? = null
    private var utterance = 0L
    private val tts: TextToSpeech = TextToSpeech(context.applicationContext) { status ->
        ready = status == TextToSpeech.SUCCESS
    }

    init {
        tts.setAudioAttributes(AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_MEDIA)
            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build())
        tts.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
            override fun onStart(utteranceId: String?) {}
            override fun onDone(utteranceId: String?) { finish(utteranceId, null) }
            @Deprecated("Deprecated in Java")
            override fun onError(utteranceId: String?) { finish(utteranceId, "Speech failed") }
            override fun onError(utteranceId: String?, errorCode: Int) { finish(utteranceId, "Speech failed ($errorCode)") }
        })
        channel.setMethodCallHandler { call, result ->
            val text = call.argument<String>("text")
            when {
                call.method != "speak" || text == null -> result.notImplemented()
                !ready -> result.error("not_ready", "Text-to-speech is not ready", null)
                pending != null -> result.error("busy", "Already speaking", null)
                else -> {
                    val language = tts.setLanguage(Locale.forLanguageTag(call.argument<String>("language") ?: "en-US"))
                    if (language == TextToSpeech.LANG_MISSING_DATA || language == TextToSpeech.LANG_NOT_SUPPORTED) {
                        result.error("language", "The speech engine has no voice for this language", null)
                        return@setMethodCallHandler
                    }
                    pending = result
                    val id = (++utterance).toString()
                    // "volume" is the loudness as a share of the maximum, so scale by the media volume.
                    val audio = context.getSystemService(AudioManager::class.java)
                    val system = audio.getStreamVolume(AudioManager.STREAM_MUSIC).toFloat() /
                        audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                    val target = call.argument<Double>("volume")?.toFloat() ?: 1f
                    val params = Bundle().apply {
                        putFloat(TextToSpeech.Engine.KEY_PARAM_VOLUME, minOf(1f, target / maxOf(system, 0.01f)))
                    }
                    if (tts.speak(text, TextToSpeech.QUEUE_FLUSH, params, id) != TextToSpeech.SUCCESS) {
                        finish(id, "The speech engine rejected playback")
                    } else {
                        // Always let Dart stop the watch recording, even if the
                        // engine never sends a completion/error callback.
                        main.postDelayed({
                            if (pending != null && utterance.toString() == id) {
                                tts.stop()
                                finish(id, "Speech playback timed out")
                            }
                        }, 30000)
                    }
                }
            }
        }
    }

    private fun finish(id: String?, error: String?) {
        main.post {
            if (id != utterance.toString()) return@post
            val done = pending ?: return@post
            pending = null
            if (error == null) done.success(null) else done.error("speech", error, null)
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        finish(utterance.toString(), "Speech playback was cancelled")
        tts.shutdown()
    }
}
