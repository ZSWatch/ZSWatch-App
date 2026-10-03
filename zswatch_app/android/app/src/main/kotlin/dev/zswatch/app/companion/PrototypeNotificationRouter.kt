package dev.zswatch.app.companion

import android.content.Context
import dev.zswatch.app.BuildConfig
import dev.zswatch.app.LifecycleLogger

/** Debug runtime selection consumes events without requiring a Flutter callback. */
object PrototypeNotificationRouter {
    fun posted(context: Context, data: Map<String, Any?>): Boolean {
        if (!BuildConfig.COMPANION_RUNTIME_PROTOTYPE) return false
        enqueue(context) { PrototypeNotifications(it).post(data, System.currentTimeMillis()) }
        return true
    }

    fun removed(context: Context, key: String): Boolean {
        if (!BuildConfig.COMPANION_RUNTIME_PROTOTYPE) return false
        enqueue(context) { PrototypeNotifications(it).remove(key) }
        return true
    }

    fun reconcile(context: Context, keys: Set<String>) {
        if (BuildConfig.COMPANION_RUNTIME_PROTOTYPE) enqueue(context) { PrototypeNotifications(it).reconcile(keys) }
    }

    private fun enqueue(context: Context, action: (PrototypeStore) -> Unit) {
        val application = context.applicationContext
        PrototypeHub.worker.post {
            try {
                action(PrototypeHub.journal(application))
                CompanionPrototypeService.instance?.transport?.flushNotifications()
            } catch (error: Exception) {
                // Never log notification content or Android keys here.
                LifecycleLogger.log("CompanionNotifications", "route_failed ${error.javaClass.simpleName}")
            }
        }
    }
}
