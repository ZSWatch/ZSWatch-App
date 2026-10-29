package dev.zswatch.app.companion

import android.content.Context
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import java.io.File
import java.util.concurrent.CopyOnWriteArraySet
import java.util.concurrent.atomic.AtomicBoolean

/** Serialized journal access shared by service commands and UI snapshot reads. */
object PrototypeHub {
    private val thread = HandlerThread("ZSWatchCompanionPrototype").apply { start() }
    val worker = Handler(thread.looper)
    val main = Handler(Looper.getMainLooper())
    val observers = CopyOnWriteArraySet<() -> Unit>()
    val logObservers = CopyOnWriteArraySet<(Map<String, Any?>) -> Unit>()
    fun publishLiveLog(event: Map<String, Any?>) { logObservers.forEach { it(event) } }
    val trafficObservers = CopyOnWriteArraySet<(Map<String, Any?>) -> Unit>()
    val traffic = CompanionTraffic { event -> trafficObservers.forEach { it(event) } }
    val sensorObservers = CopyOnWriteArraySet<(Map<String, Any?>) -> Unit>()
    fun publishSensor(event: Map<String, Any?>) { sensorObservers.forEach { it(event) } }
    fun publishTraffic(direction: String, text: String, bytes: Int, chunks: Int, generation: Long) {
        traffic.publish(direction, text, bytes, chunks, generation)
    }
    private val notifyPending = AtomicBoolean(false)
    /** Coalesce commit bursts (one BLE message commits many times) into one UI snapshot. */
    private fun changed() {
        if (!notifyPending.compareAndSet(false, true)) return
        main.postDelayed({ notifyPending.set(false); observers.forEach { it() } }, 50)
    }
    private var store: PrototypeStore? = null
    private var jobStore: PrototypeStore? = null

    fun jobJournal(context: Context): PrototypeStore {
        check(Looper.myLooper() == worker.looper)
        return jobStore ?: PrototypeStore(File(context.filesDir, "companion-prototype/jobs"), 64).also { created ->
            PrototypeJobs(created).recoverLocalClaims()
            created.onChanged = ::changed
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

    fun library(context: Context) = PrototypeRecordingLibrary(journal(context),
        ReceiptFiles(File(context.filesDir, "companion-prototype/recordings"))) { PrototypeJobs(jobJournal(context)) }

    fun journal(context: Context): PrototypeStore {
        check(Looper.myLooper() == worker.looper)
        return store ?: PrototypeStore(File(context.filesDir, "companion-prototype")).also { created ->
            created.onChanged = ::changed
            store = created
        }
    }
}
