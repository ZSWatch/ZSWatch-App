package dev.zswatch.app.companion

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.CancellationSignal
import android.os.SystemClock
import androidx.core.content.ContextCompat
import org.json.JSONObject

/** Android acquisition adapter. The companion service retains the only BLE owner. */
internal class AndroidPrototypeGps(
    context: Context, private val store: PrototypeStore,
    foreground: (Boolean) -> Unit,
    send: (Long, String, () -> Boolean, () -> Unit) -> Boolean,
) {
    private val application = context.applicationContext
    private val controller = PrototypeGps(
        enabled = { store.control()["gps_enabled"] == true },
        blocked = { blocked(application) },
        foreground = foreground,
        source = AndroidGpsSource(application),
        now = SystemClock::elapsedRealtime,
        later = { delay, action -> PrototypeHub.worker.postDelayed(action, delay) },
        send = send,
        observe = { token, state, requested ->
            if ((store.control()["generation"] as Number).toLong() == token) {
                val fields = mutableMapOf<String, Any?>("gps_runtime" to mapOf(
                    "generation" to token, "state" to state, "requested" to requested,
                    "utc_ms" to System.currentTimeMillis()))
                if (state == "written") fields["last_gps_write"] = mapOf(
                    "generation" to token, "utc_ms" to System.currentTimeMillis())
                store.update("gps_$state", fields)
            }
        },
    )

    fun ready(generation: Long) = controller.ready(generation)
    fun receive(message: JSONObject, generation: Long) = controller.receive(message, generation)
    fun refresh() = controller.refresh()
    fun close() = controller.close()
    fun configure(enabled: Boolean) {
        if (enabled) check(blocked(application) == null) { "Grant background location and enable phone location first" }
        store.update("gps_configuration", mapOf("gps_enabled" to enabled))
        controller.configurationChanged()
    }

    companion object {
        fun permissions(context: Context): Map<String, Boolean> {
            fun granted(permission: String) = ContextCompat.checkSelfPermission(context, permission) == PackageManager.PERMISSION_GRANTED
            val manager = context.getSystemService(LocationManager::class.java)
            val services = if (Build.VERSION.SDK_INT >= 28) manager?.isLocationEnabled == true
                else manager?.isProviderEnabled(LocationManager.GPS_PROVIDER) == true ||
                    manager?.isProviderEnabled(LocationManager.NETWORK_PROVIDER) == true
            return mapOf(
                "foreground" to (granted(Manifest.permission.ACCESS_FINE_LOCATION) || granted(Manifest.permission.ACCESS_COARSE_LOCATION)),
                "background" to (Build.VERSION.SDK_INT < 29 || granted(Manifest.permission.ACCESS_BACKGROUND_LOCATION)),
                "services" to services,
            )
        }

        fun blocked(context: Context): String? {
            val access = permissions(context)
            return when {
                access["foreground"] != true || access["background"] != true -> "permission_required"
                access["services"] != true -> "services_disabled"
                else -> null
            }
        }

        fun configureStopped(context: Context, store: PrototypeStore, enabled: Boolean) {
            if (enabled) check(blocked(context) == null) { "Grant background location and enable phone location first" }
            store.update("gps_configuration", mapOf("gps_enabled" to enabled))
        }
    }
}

@Suppress("DEPRECATION", "MissingPermission")
private class AndroidGpsSource(private val context: Context) : PrototypeGpsSource {
    override fun start(fix: (PrototypeGpsFix) -> Unit, failed: (String) -> Unit): () -> Unit {
        val manager = context.getSystemService(LocationManager::class.java) ?: error("Location manager unavailable")
        fun convert(location: Location) = PrototypeGpsFix(
            location.latitude, location.longitude, location.elapsedRealtimeNanos / 1000000,
            location.time,
            location.altitude.takeIf { location.hasAltitude() },
            location.speed.toDouble().takeIf { location.hasSpeed() },
            location.bearing.toDouble().takeIf { location.hasBearing() },
            location.accuracy.toDouble().takeIf { location.hasAccuracy() },
        )
        val listener = object : LocationListener {
            override fun onLocationChanged(location: Location) = fix(convert(location))
            override fun onProviderDisabled(provider: String) {
                if (AndroidPrototypeGps.blocked(context) != null) failed("services_disabled")
            }
            override fun onProviderEnabled(provider: String) = Unit
            override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) = Unit
        }
        val providers = mutableListOf<String>()
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED &&
            manager.isProviderEnabled(LocationManager.GPS_PROVIDER)) providers.add(LocationManager.GPS_PROVIDER)
        if (manager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) providers.add(LocationManager.NETWORK_PROVIDER)
        if (Build.VERSION.SDK_INT >= 31 && manager.hasProvider(LocationManager.FUSED_PROVIDER) &&
            manager.isProviderEnabled(LocationManager.FUSED_PROVIDER)) providers.add(LocationManager.FUSED_PROVIDER)
        check(providers.isNotEmpty()) { "No location provider available" }
        val signal = CancellationSignal()
        val stop = { signal.cancel(); manager.removeUpdates(listener) }
        try {
            providers.forEach { manager.requestLocationUpdates(it, 5000L, 0f, listener, PrototypeHub.worker.looper) }
            // With coarse access only, Android throttles updates to 10 minutes; ask for one fix now.
            if (Build.VERSION.SDK_INT >= 30) providers.forEach { provider ->
                manager.getCurrentLocation(provider, signal, { PrototypeHub.worker.post(it) }) { location ->
                    if (location != null && !signal.isCanceled) fix(convert(location))
                }
            }
            // The controller rejects stale cached locations using monotonic time.
            providers.mapNotNull { manager.getLastKnownLocation(it) }.sortedByDescending { it.elapsedRealtimeNanos }
                .firstOrNull()?.let { fix(convert(it)) }
        } catch (error: Exception) { stop(); throw error }
        return stop
    }
}
