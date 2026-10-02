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

    fun journal(context: Context): PrototypeStore {
        check(Looper.myLooper() == worker.looper)
        return store ?: PrototypeStore(File(context.filesDir, "companion-prototype")).also { created ->
            created.onChanged = { observers.forEach { main.post(it) } }
            store = created
        }
    }
}
