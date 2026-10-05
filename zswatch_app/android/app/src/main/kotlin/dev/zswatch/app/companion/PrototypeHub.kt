package dev.zswatch.app.companion

import android.content.Context
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import java.io.File
import java.util.concurrent.CopyOnWriteArraySet

/** Serialized journal access shared by service commands and UI snapshot reads. */
object PrototypeHub {
    private val thread = HandlerThread("ZSWatchCompanionPrototype").apply { start() }
    val worker = Handler(thread.looper)
    val main = Handler(Looper.getMainLooper())
    val observers = CopyOnWriteArraySet<() -> Unit>()
    private var store: PrototypeStore? = null
    private var jobStore: PrototypeStore? = null

    fun jobJournal(context: Context): PrototypeStore {
        check(Looper.myLooper() == worker.looper)
        return jobStore ?: PrototypeStore(File(context.filesDir, "companion-prototype/jobs"), 64).also { created ->
            created.onChanged = { observers.forEach { main.post(it) } }
            jobStore = created
        }
    }

    fun snapshot(context: Context, active: Boolean): Map<String, Any?> {
        val state = journal(context).snapshot(active) + mapOf("gps_permissions" to AndroidPrototypeGps.permissions(context))
        return try {
            val jobs = PrototypeJobs(jobJournal(context)).summary()
            state + mapOf("remote_jobs" to jobs, "voice_jobs" to jobs.filter { it["provider"] == "dart-voice-v1" })
        }
        catch (error: Exception) { state + mapOf("remote_jobs_error" to error.javaClass.simpleName) }
    }

    fun journal(context: Context): PrototypeStore {
        check(Looper.myLooper() == worker.looper)
        return store ?: PrototypeStore(File(context.filesDir, "companion-prototype")).also { created ->
            created.onChanged = { observers.forEach { main.post(it) } }
            store = created
        }
    }
}
