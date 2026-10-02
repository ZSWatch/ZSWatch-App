package dev.zswatch.app.companion

import android.app.Activity
import android.app.Instrumentation
import android.content.Intent
import android.os.Bundle
import androidx.core.content.ContextCompat
import dev.zswatch.app.BuildConfig
import org.json.JSONObject
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/** Explicit ADB diagnostic launch, not evidence of autonomous background recovery.
 * Instrumentation changes OS execution policy and may terminate the target process.
 * Only compiled in debug; ordinary debug builds reject it before starting BLE.
 */
class CompanionTransferProbe : Instrumentation() {
    private lateinit var arguments: Bundle

    override fun onCreate(arguments: Bundle?) {
        super.onCreate(arguments)
        this.arguments = arguments ?: Bundle()
        start()
    }

    private fun <T> worker(action: () -> T): T {
        val done = CountDownLatch(1)
        var result: Result<T>? = null
        PrototypeHub.worker.post { result = runCatching(action); done.countDown() }
        check(done.await(10, TimeUnit.SECONDS)) { "Native worker did not respond" }
        return result!!.getOrThrow()
    }

    private fun snapshot() = worker {
        val service = CompanionPrototypeService.instance
        PrototypeHub.journal(targetContext).snapshot(service?.runtime?.active == true)
    }

    override fun onStart() {
        val output = Bundle()
        try {
            check(BuildConfig.COMPANION_RUNTIME_PROTOTYPE) { "Requires experimental debug APK" }
            val address = arguments.getString("address")?.uppercase() ?: error("Explicit watch address required")
            require(Regex("[0-9A-F]{2}(:[0-9A-F]{2}){5}").matches(address))
            val seconds = arguments.getString("seconds", "120").toLong()
            require(seconds in 15..180)
            NativePrototypeTransport.traceMcuPackets = arguments.getString("trace_packets") == "true"
            ContextCompat.startForegroundService(targetContext, Intent(targetContext, CompanionPrototypeService::class.java)
                .setAction(CompanionPrototypeService.START).putExtra("address", address))
            val readyDeadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(40)
            var state = snapshot()
            while (state["protocol_ready"] != true && System.nanoTime() < readyDeadline) {
                Thread.sleep(500); state = snapshot()
            }
            check(state["protocol_ready"] == true) { "Native transport did not reach Ready" }
            worker { (CompanionPrototypeService.instance?.transport ?: error("Native transport unavailable")).retryRecordings() }
            val deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(seconds)
            val earliestFinish = System.nanoTime() + TimeUnit.SECONDS.toNanos(3)
            do {
                Thread.sleep(500); state = snapshot()
                @Suppress("UNCHECKED_CAST")
                val records = state["recordings"] as Map<String, Map<String, Any?>>
                if (System.nanoTime() >= earliestFinish && state["protocol_ready"] == true && records.isNotEmpty() &&
                    records.values.all { it["state"] in listOf("downloaded", "failed") }) break
            } while (System.nanoTime() < deadline)
            @Suppress("UNCHECKED_CAST")
            val records = state["recordings"] as Map<String, Map<String, Any?>>
            val passed = state["protocol_ready"] == true && records.isNotEmpty() && records.values.all { it["state"] == "downloaded" }
            output.putString("probe", JSONObject(mapOf("scope" to "INSTRUMENTED_TRANSFER_DIAGNOSTIC",
                "result" to if (passed) "ALL_RECEIPTS_DOWNLOADED" else "TRANSFER_FAILURE_OR_TIMEOUT", "state" to state)).toString())
            NativePrototypeTransport.traceMcuPackets = false
            finish(if (passed) Activity.RESULT_OK else Activity.RESULT_CANCELED, output)
        } catch (error: Exception) {
            NativePrototypeTransport.traceMcuPackets = false
            output.putString("probe", JSONObject(mapOf("scope" to "INSTRUMENTED_TRANSFER_DIAGNOSTIC",
                "result" to "PROBE_ERROR", "error" to "${error.javaClass.simpleName}: ${error.message}")).toString())
            finish(Activity.RESULT_CANCELED, output)
        }
    }
}
