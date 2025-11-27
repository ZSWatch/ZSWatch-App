package com.example.zswatch_app

import android.content.ComponentName
import android.content.Context
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log

/**
 * Bridge for Android MediaSession API to control media playback.
 * 
 * This class:
 * - Monitors active media sessions
 * - Provides media control actions (play, pause, next, previous, volume)
 * - Reports playback state and metadata changes to Flutter
 * 
 * Note: Requires NotificationListenerService permission to access MediaSessionManager.
 */
class MediaSessionBridge(private val context: Context) {
    
    companion object {
        private const val TAG = "ZSWMediaBridge"
    }
    
    private var mediaSessionManager: MediaSessionManager? = null
    private var activeController: MediaController? = null
    private var mediaCallback: MediaCallback? = null
    private val handler = Handler(Looper.getMainLooper())
    
    interface MediaCallback {
        fun onPlaybackStateChanged(state: Map<String, Any?>)
        fun onMetadataChanged(metadata: Map<String, Any?>)
    }
    
    private val controllerCallback = object : MediaController.Callback() {
        override fun onPlaybackStateChanged(state: PlaybackState?) {
            state?.let {
                val stateMap = mapOf(
                    "state" to playbackStateToString(it.state),
                    "position" to (it.position / 1000).toInt(), // Convert to seconds
                    "playbackSpeed" to it.playbackSpeed
                )
                Log.d(TAG, "Playback state changed: ${stateMap["state"]}")
                mediaCallback?.onPlaybackStateChanged(stateMap)
            }
        }
        
        override fun onMetadataChanged(metadata: MediaMetadata?) {
            metadata?.let {
                val metadataMap = extractMetadata(it)
                Log.d(TAG, "Metadata changed: ${metadataMap["track"]}")
                mediaCallback?.onMetadataChanged(metadataMap)
            }
        }
    }
    
    private val sessionListener = MediaSessionManager.OnActiveSessionsChangedListener { controllers ->
        Log.d(TAG, "Active sessions changed: ${controllers?.size ?: 0} sessions")
        updateActiveController(controllers)
    }
    
    fun setCallback(callback: MediaCallback?) {
        this.mediaCallback = callback
    }
    
    fun initialize(): Boolean {
        return try {
            mediaSessionManager = context.getSystemService(Context.MEDIA_SESSION_SERVICE) as MediaSessionManager
            
            // Get the component name for our NotificationListenerService
            val componentName = ComponentName(context, NotificationListenerServiceImpl::class.java)
            
            // Register for session changes
            mediaSessionManager?.addOnActiveSessionsChangedListener(sessionListener, componentName, handler)
            
            // Get current active sessions
            val controllers = mediaSessionManager?.getActiveSessions(componentName)
            updateActiveController(controllers)
            
            Log.d(TAG, "MediaSessionBridge initialized successfully")
            true
        } catch (e: SecurityException) {
            Log.e(TAG, "SecurityException: Notification access not granted", e)
            false
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize MediaSessionBridge", e)
            false
        }
    }
    
    fun dispose() {
        try {
            mediaSessionManager?.removeOnActiveSessionsChangedListener(sessionListener)
            activeController?.unregisterCallback(controllerCallback)
            activeController = null
            mediaSessionManager = null
            mediaCallback = null
            Log.d(TAG, "MediaSessionBridge disposed")
        } catch (e: Exception) {
            Log.e(TAG, "Error disposing MediaSessionBridge", e)
        }
    }
    
    private fun updateActiveController(controllers: List<MediaController>?) {
        // Unregister from previous controller
        activeController?.unregisterCallback(controllerCallback)
        
        // Find an active controller (prefer one that's playing)
        activeController = controllers?.firstOrNull { controller ->
            controller.playbackState?.state == PlaybackState.STATE_PLAYING
        } ?: controllers?.firstOrNull()
        
        activeController?.let { controller ->
            controller.registerCallback(controllerCallback, handler)
            
            // Send current state
            controller.playbackState?.let { state ->
                val stateMap = mapOf(
                    "state" to playbackStateToString(state.state),
                    "position" to (state.position / 1000).toInt(),
                    "playbackSpeed" to state.playbackSpeed
                )
                mediaCallback?.onPlaybackStateChanged(stateMap)
            }
            
            controller.metadata?.let { metadata ->
                val metadataMap = extractMetadata(metadata)
                mediaCallback?.onMetadataChanged(metadataMap)
            }
            
            Log.d(TAG, "Active controller set: ${controller.packageName}")
        }
    }
    
    private fun extractMetadata(metadata: MediaMetadata): Map<String, Any?> {
        return mapOf(
            "artist" to metadata.getString(MediaMetadata.METADATA_KEY_ARTIST),
            "album" to metadata.getString(MediaMetadata.METADATA_KEY_ALBUM),
            "track" to (metadata.getString(MediaMetadata.METADATA_KEY_TITLE) 
                ?: metadata.getString(MediaMetadata.METADATA_KEY_DISPLAY_TITLE)),
            "duration" to (metadata.getLong(MediaMetadata.METADATA_KEY_DURATION) / 1000).toInt(),
            "trackNumber" to metadata.getLong(MediaMetadata.METADATA_KEY_TRACK_NUMBER).toInt().takeIf { it > 0 },
            "trackCount" to metadata.getLong(MediaMetadata.METADATA_KEY_NUM_TRACKS).toInt().takeIf { it > 0 }
        )
    }
    
    private fun playbackStateToString(state: Int): String {
        return when (state) {
            PlaybackState.STATE_PLAYING -> "play"
            PlaybackState.STATE_PAUSED -> "pause"
            PlaybackState.STATE_STOPPED -> "stop"
            PlaybackState.STATE_BUFFERING -> "buffering"
            PlaybackState.STATE_CONNECTING -> "connecting"
            PlaybackState.STATE_ERROR -> "error"
            PlaybackState.STATE_FAST_FORWARDING -> "fastForward"
            PlaybackState.STATE_REWINDING -> "rewind"
            PlaybackState.STATE_SKIPPING_TO_NEXT -> "skippingNext"
            PlaybackState.STATE_SKIPPING_TO_PREVIOUS -> "skippingPrevious"
            PlaybackState.STATE_SKIPPING_TO_QUEUE_ITEM -> "skippingToItem"
            else -> "unknown"
        }
    }
    
    // Media control actions
    
    fun play(): Boolean {
        return activeController?.let { controller ->
            try {
                controller.transportControls.play()
                Log.d(TAG, "Play command sent")
                true
            } catch (e: Exception) {
                Log.e(TAG, "Failed to send play command", e)
                false
            }
        } ?: false
    }
    
    fun pause(): Boolean {
        return activeController?.let { controller ->
            try {
                controller.transportControls.pause()
                Log.d(TAG, "Pause command sent")
                true
            } catch (e: Exception) {
                Log.e(TAG, "Failed to send pause command", e)
                false
            }
        } ?: false
    }
    
    fun playPause(): Boolean {
        val state = activeController?.playbackState?.state
        return if (state == PlaybackState.STATE_PLAYING) {
            pause()
        } else {
            play()
        }
    }
    
    fun next(): Boolean {
        return activeController?.let { controller ->
            try {
                controller.transportControls.skipToNext()
                Log.d(TAG, "Next command sent")
                true
            } catch (e: Exception) {
                Log.e(TAG, "Failed to send next command", e)
                false
            }
        } ?: false
    }
    
    fun previous(): Boolean {
        return activeController?.let { controller ->
            try {
                controller.transportControls.skipToPrevious()
                Log.d(TAG, "Previous command sent")
                true
            } catch (e: Exception) {
                Log.e(TAG, "Failed to send previous command", e)
                false
            }
        } ?: false
    }
    
    fun volumeUp(): Boolean {
        return activeController?.let { controller ->
            try {
                val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as android.media.AudioManager
                audioManager.adjustStreamVolume(
                    android.media.AudioManager.STREAM_MUSIC,
                    android.media.AudioManager.ADJUST_RAISE,
                    android.media.AudioManager.FLAG_SHOW_UI
                )
                Log.d(TAG, "Volume up command sent")
                true
            } catch (e: Exception) {
                Log.e(TAG, "Failed to increase volume", e)
                false
            }
        } ?: false
    }
    
    fun volumeDown(): Boolean {
        return activeController?.let { controller ->
            try {
                val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as android.media.AudioManager
                audioManager.adjustStreamVolume(
                    android.media.AudioManager.STREAM_MUSIC,
                    android.media.AudioManager.ADJUST_LOWER,
                    android.media.AudioManager.FLAG_SHOW_UI
                )
                Log.d(TAG, "Volume down command sent")
                true
            } catch (e: Exception) {
                Log.e(TAG, "Failed to decrease volume", e)
                false
            }
        } ?: false
    }
    
    fun seekTo(positionSeconds: Int): Boolean {
        return activeController?.let { controller ->
            try {
                controller.transportControls.seekTo(positionSeconds.toLong() * 1000)
                Log.d(TAG, "Seek command sent: ${positionSeconds}s")
                true
            } catch (e: Exception) {
                Log.e(TAG, "Failed to seek", e)
                false
            }
        } ?: false
    }
    
    // Get current state
    
    fun getCurrentState(): Map<String, Any?>? {
        return activeController?.let { controller ->
            val state = controller.playbackState
            val metadata = controller.metadata
            
            mapOf(
                "playback" to state?.let {
                    mapOf(
                        "state" to playbackStateToString(it.state),
                        "position" to (it.position / 1000).toInt(),
                        "playbackSpeed" to it.playbackSpeed
                    )
                },
                "metadata" to metadata?.let { extractMetadata(it) },
                "packageName" to controller.packageName
            )
        }
    }
    
    fun hasActiveSession(): Boolean {
        return activeController != null
    }
}


