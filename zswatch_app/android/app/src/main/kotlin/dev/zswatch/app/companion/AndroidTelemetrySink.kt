package dev.zswatch.app.companion

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import java.io.File

/** Writes the existing Drift tables; Flutter owns their schema and queries. */
internal class AndroidTelemetrySink(context: Context) : TelemetrySink, AutoCloseable {
    private val file = File(context.getDir("flutter", Context.MODE_PRIVATE), "zswatch_app.db")
    private var database: SQLiteDatabase? = null
    private var cleanupAt = 0L
    private fun db(): SQLiteDatabase = database ?: run {
        check(file.exists()) { "Initialize the app database before connecting" }
        SQLiteDatabase.openDatabase(file.path, null, SQLiteDatabase.OPEN_READWRITE or SQLiteDatabase.ENABLE_WRITE_AHEAD_LOGGING).also {
            if (it.version !in 6..7) {
                it.close()
                error("Unsupported app database version")
            }
            database = it
        }
    }
    private fun write(address: String, timestamp: Long, insert: (SQLiteDatabase) -> Unit) {
        val db = db()
        db.beginTransaction()
        try {
            db.execSQL("INSERT OR IGNORE INTO watches(id,name,created_at) VALUES(?,?,?)",
                arrayOf(address, "ZSWatch", timestamp / 1000))
            insert(db)
            val now = System.currentTimeMillis()
            if (now - cleanupAt >= 3600000) {
                val cutoff = now / 1000 - 60L * 86400
                for (table in listOf("health_samples", "battery_readings", "connection_events"))
                    db.execSQL("DELETE FROM $table WHERE timestamp < ?", arrayOf(cutoff))
                cleanupAt = now
            }
            db.setTransactionSuccessful()
        } finally { db.endTransaction() }
    }
    override fun health(address: String, values: Map<String, Double>, timestamp: Long) = write(address, timestamp) { db ->
        for ((type, value) in values) db.execSQL(
            "INSERT INTO health_samples(watch_id,type,value,timestamp,granularity,synced_at) VALUES(?,?,?,?,?,?)",
            arrayOf(address, type, value, timestamp / 1000, "realtime", System.currentTimeMillis() / 1000))
    }
    override fun battery(address: String, level: Int, charging: Boolean, timestamp: Long) = write(address, timestamp) { db ->
        db.execSQL("INSERT INTO battery_readings(watch_id,level,is_charging,timestamp) VALUES(?,?,?,?)",
            arrayOf(address, level, if (charging) 1 else 0, timestamp / 1000))
    }
    override fun connection(address: String, type: String, reason: String?, session: String?, timestamp: Long) = write(address, timestamp) { db ->
        db.execSQL("INSERT INTO connection_events(watch_id,event_type,reason,session_id,timestamp) VALUES(?,?,?,?,?)",
            arrayOf(address, type, reason, session, timestamp / 1000))
    }
    override fun lastConnection(): Map<String, Any?>? = db().rawQuery(
        "SELECT watch_id,event_type,session_id FROM connection_events WHERE event_type IN ('connected','disconnected') ORDER BY timestamp DESC,id DESC LIMIT 1", null).use {
        if (!it.moveToFirst()) null else mapOf("watch_id" to it.getString(0), "event_type" to it.getString(1), "session_id" to it.getString(2))
    }
    override fun close() { database?.close(); database = null }
}
