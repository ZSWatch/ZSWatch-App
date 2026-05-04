package dev.zswatch.app

import android.content.Context

object NativeBackgroundPreferences {
    private const val PREFS_NAME = "zswatch_background_connection"

    const val KEY_BACKGROUND_CONNECTION_ENABLED = "background_connection_enabled"
    const val KEY_AUTO_RECONNECT_ENABLED = "auto_reconnect_enabled"
    const val KEY_NOTIFICATION_FORWARDING_ENABLED = "notification_forwarding_enabled"
    const val KEY_LAST_WATCH_ID = "last_watch_id"
    const val KEY_LAST_WATCH_NAME = "last_watch_name"
    const val KEY_BLOCKED_NOTIFICATION_APPS = "blocked_notification_apps"
    const val KEY_LAST_SYNC_UPTIME_MS = "last_sync_uptime_ms"

    data class Snapshot(
        val backgroundConnectionEnabled: Boolean,
        val autoReconnectEnabled: Boolean,
        val notificationForwardingEnabled: Boolean,
        val lastWatchId: String?,
        val lastWatchName: String?,
        val blockedNotificationApps: Set<String>,
        val lastSyncUptimeMs: Long,
    ) {
        val hasKnownWatch: Boolean
            get() = !lastWatchId.isNullOrBlank()

        fun toMap(): Map<String, Any?> = mapOf(
            KEY_BACKGROUND_CONNECTION_ENABLED to backgroundConnectionEnabled,
            KEY_AUTO_RECONNECT_ENABLED to autoReconnectEnabled,
            KEY_NOTIFICATION_FORWARDING_ENABLED to notificationForwardingEnabled,
            KEY_LAST_WATCH_ID to lastWatchId,
            KEY_LAST_WATCH_NAME to lastWatchName,
            KEY_BLOCKED_NOTIFICATION_APPS to blockedNotificationApps.toList(),
            KEY_LAST_SYNC_UPTIME_MS to lastSyncUptimeMs,
        )
    }

    fun sync(context: Context, args: Map<*, *>): Snapshot {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val editor = prefs.edit()

        if (args.containsKey(KEY_BACKGROUND_CONNECTION_ENABLED)) {
            (args[KEY_BACKGROUND_CONNECTION_ENABLED] as? Boolean)?.let {
                editor.putBoolean(KEY_BACKGROUND_CONNECTION_ENABLED, it)
            }
        }
        if (args.containsKey(KEY_AUTO_RECONNECT_ENABLED)) {
            (args[KEY_AUTO_RECONNECT_ENABLED] as? Boolean)?.let {
                editor.putBoolean(KEY_AUTO_RECONNECT_ENABLED, it)
            }
        }
        if (args.containsKey(KEY_NOTIFICATION_FORWARDING_ENABLED)) {
            (args[KEY_NOTIFICATION_FORWARDING_ENABLED] as? Boolean)?.let {
                editor.putBoolean(KEY_NOTIFICATION_FORWARDING_ENABLED, it)
            }
        }
        if (args.containsKey(KEY_LAST_WATCH_ID)) {
            putNullableString(editor, KEY_LAST_WATCH_ID, args[KEY_LAST_WATCH_ID] as? String)
        }
        if (args.containsKey(KEY_LAST_WATCH_NAME)) {
            putNullableString(editor, KEY_LAST_WATCH_NAME, args[KEY_LAST_WATCH_NAME] as? String)
        }
        if (args.containsKey(KEY_BLOCKED_NOTIFICATION_APPS)) {
            stringSetFrom(args[KEY_BLOCKED_NOTIFICATION_APPS])?.let {
                editor.putStringSet(KEY_BLOCKED_NOTIFICATION_APPS, it)
            }
        }

        editor.putLong(KEY_LAST_SYNC_UPTIME_MS, android.os.SystemClock.uptimeMillis())
        editor.apply()

        val snapshot = getSnapshot(context)
        LifecycleLogger.log(
            "NativeBackgroundPreferences",
            "synced background=${snapshot.backgroundConnectionEnabled} autoReconnect=${snapshot.autoReconnectEnabled} " +
                "notifications=${snapshot.notificationForwardingEnabled} watchId=${snapshot.lastWatchId} " +
                "blockedApps=${snapshot.blockedNotificationApps.size}",
        )
        return snapshot
    }

    fun getSnapshot(context: Context): Snapshot {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return Snapshot(
            backgroundConnectionEnabled = prefs.getBoolean(KEY_BACKGROUND_CONNECTION_ENABLED, true),
            autoReconnectEnabled = prefs.getBoolean(KEY_AUTO_RECONNECT_ENABLED, true),
            notificationForwardingEnabled = prefs.getBoolean(KEY_NOTIFICATION_FORWARDING_ENABLED, false),
            lastWatchId = prefs.getString(KEY_LAST_WATCH_ID, null),
            lastWatchName = prefs.getString(KEY_LAST_WATCH_NAME, null),
            blockedNotificationApps = prefs.getStringSet(KEY_BLOCKED_NOTIFICATION_APPS, emptySet()) ?: emptySet(),
            lastSyncUptimeMs = prefs.getLong(KEY_LAST_SYNC_UPTIME_MS, 0L),
        )
    }

    private fun putNullableString(
        editor: android.content.SharedPreferences.Editor,
        key: String,
        value: String?,
    ) {
        if (value.isNullOrBlank()) {
            editor.remove(key)
        } else {
            editor.putString(key, value)
        }
    }

    private fun stringSetFrom(value: Any?): Set<String>? {
        return when (value) {
            is List<*> -> value.filterIsInstance<String>().toSet()
            is Array<*> -> value.filterIsInstance<String>().toSet()
            is Set<*> -> value.filterIsInstance<String>().toSet()
            else -> null
        }
    }
}