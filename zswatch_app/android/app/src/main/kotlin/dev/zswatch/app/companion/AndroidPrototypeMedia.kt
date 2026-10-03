package dev.zswatch.app.companion

import android.content.Context
import android.os.SystemClock
import dev.zswatch.app.MediaSessionBridge
import dev.zswatch.app.NotificationListenerServiceImpl
import org.json.JSONObject

/** Service lifecycle, existing Android media bridge; never an Activity/Flutter owner. */
internal class AndroidPrototypeMedia(
    private val context: Context,
    private val send: (Long, String) -> Boolean,
    private val observe: (String, Long, Boolean) -> Unit,
) {
    private val lease = PrototypeMediaLease()
    private val delivery = PrototypeMediaDelivery(lease)
    // Main thread only; no private media payload in journals or EventChannel.
    private var bridge: MediaSessionBridge? = null
    private var session: PrototypeMediaLease.Session? = null

    fun ready(generation: Long) {
        val next = lease.open(generation)
        PrototypeHub.main.post {
            if (!lease.owns(next)) return@post
            releaseBridge()
            session = next
            refreshMain(next)
        }
    }

    fun close() {
        lease.close()
        PrototypeHub.worker.post { delivery.clear() }
        PrototypeHub.main.post { if (session?.let(lease::owns) != true) releaseBridge() }
    }

    fun refresh(generation: Long) {
        val expected = lease.get(generation) ?: return
        PrototypeHub.main.post { if (lease.owns(expected)) refreshMain(expected) }
    }

    fun control(message: JSONObject, generation: Long) {
        val action = PrototypeMedia.action(message) ?: return
        val expected = lease.get(generation) ?: return
        val received = SystemClock.elapsedRealtime()
        PrototypeHub.main.post {
            if (!lease.authorizesControl(expected, received, SystemClock.elapsedRealtime())) return@post
            refreshMain(expected)
            if (!lease.authorizesControl(expected, received, SystemClock.elapsedRealtime())) return@post
            val current = bridge
            val accepted = when (action) {
                "play" -> current?.play()
                "pause" -> current?.pause()
                "next" -> current?.next()
                "previous" -> current?.previous()
                "volumeup" -> current?.volumeUp()
                "volumedown" -> current?.volumeDown()
                else -> false
            } == true
            PrototypeHub.worker.post { if (lease.owns(expected)) observe("control", generation, accepted) }
        }
    }

    private fun refreshMain(expected: PrototypeMediaLease.Session) {
        if (!lease.owns(expected)) return
        if (!NotificationListenerServiceImpl.isNotificationAccessEnabled(context)) {
            releaseBridge()
            session = expected
            publish(expected, null)
            return
        }
        if (bridge == null) {
            val created = MediaSessionBridge(context, logTrackMetadata = false)
            bridge = created
            created.setCallback(object : MediaSessionBridge.MediaCallback {
                override fun onPlaybackStateChanged(state: Map<String, Any?>) = publishFresh(expected)
                override fun onMetadataChanged(metadata: Map<String, Any?>) = publishFresh(expected)
                override fun onSessionChanged(hasSession: Boolean) = publishFresh(expected)
            })
            if (!created.initialize()) {
                releaseBridge(); session = expected
                publish(expected, null)
                return
            }
        }
        publishFresh(expected)
    }

    private fun publishFresh(expected: PrototypeMediaLease.Session) {
        if (!lease.owns(expected)) return
        if (!NotificationListenerServiceImpl.isNotificationAccessEnabled(context)) {
            releaseBridge(); session = expected; publish(expected, null); return
        }
        val current = try { bridge?.getCurrentState() } catch (_: Exception) {
            releaseBridge(); session = expected; null
        }
        publish(expected, current)
    }

    private fun publish(expected: PrototypeMediaLease.Session, current: Map<String, Any?>?) {
        if (!lease.owns(expected)) return
        val packets = PrototypeMedia.packets(current)
        PrototypeHub.worker.post {
            if (!lease.owns(expected)) return@post
            delivery.publish(expected, packets) { send(expected.generation, it) }
        }
    }

    private fun releaseBridge() {
        bridge?.dispose(); bridge = null; session = null
    }
}
