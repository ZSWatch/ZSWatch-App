package dev.zswatch.app.companion

import android.content.Context
import android.util.Log
import dev.zswatch.app.ActionFailure
import dev.zswatch.app.ProductivityActions
import org.json.JSONArray
import org.json.JSONObject
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.ZonedDateTime

/** Creates, dismisses and removes voice result actions. Call on [PrototypeHub.worker]. */
object CompanionVoiceActions {
    private const val TAG = "ZSWVoiceActions"

    fun token(id: String, index: Int) = "zswatch://voice-action/$id/$index"

    fun create(context: Context, id: String, index: Int, input: JSONObject): Map<String, Any?> {
        val jobs = PrototypeJobs(PrototypeHub.jobJournal(context))
        val type = input.getString("actionType")
        require(input.getString("title").isNotBlank() && input.getString("title").length <= 1024)
        if (type == "timer") require(input.getLong("durationSeconds") in 1..Int.MAX_VALUE.toLong())
        else require(input.getLong("scheduledAtMillis") > 0)
        if (type == "alarm") {
            val zone = ZoneId.systemDefault()
            val target = java.time.Instant.ofEpochMilli(input.getLong("scheduledAtMillis")).atZone(zone)
            val now = ZonedDateTime.now(zone)
            var next = now.toLocalDate().atTime(target.hour, target.minute).atZone(zone)
            if (!next.isAfter(now)) next = next.toLocalDate().plusDays(1).atTime(target.hour, target.minute).atZone(zone)
            require(target.toLocalDate() == next.toLocalDate()) { "Clock only supports the next occurrence of this time" }
        }
        require(input.isNull("reminderMinutes") || input.getLong("reminderMinutes") in 0..Int.MAX_VALUE.toLong())
        if (type == "calendar_event" && !input.isNull("endAtMillis"))
            require(input.getLong("endAtMillis") > input.getLong("scheduledAtMillis"))
        val alreadyConfirmed = jobs.state(id).optJSONObject("action_states")?.has(index.toString()) == true
        val action = jobs.beginAction(id, index, input)
        val response = try {
            ProductivityActions(context).create(PrototypeStore.asMap(action.getJSONObject("draft")), token(id, index))
        } catch (failure: ActionFailure) {
            // Provider failures can follow insertion. Keep their confirmation for token-based recovery.
            if (!alreadyConfirmed && (failure.code in listOf("PERMISSION_DENIED", "NO_CALENDAR", "SELECTED_CALENDAR_UNAVAILABLE") ||
                    (type in listOf("timer", "alarm") && failure.code == "CREATE_ACTION_FAILED"))) jobs.releaseAction(id, index)
            throw failure
        }
        jobs.finishAction(id, index, JSONObject(response))
        return response
    }

    /**
     * Adds a shopping action's items to ICA. The network runs on the ICA
     * executor; journal changes and [done] run on [PrototypeHub.worker].
     */
    fun createShopping(context: Context, id: String, index: Int, input: JSONObject, done: (Result<Map<String, Any?>>) -> Unit) {
        val jobs = PrototypeJobs(PrototypeHub.jobJournal(context))
        require(input.getString("actionType") == "shopping")
        require(shoppingItems(input) != null) { "Invalid shopping items" }
        val key = busy(id, index)
        val alreadyConfirmed = jobs.state(id).optJSONObject("action_states")?.has(index.toString()) == true
        // A retry recovers the confirmed items, never a changed draft.
        val items = try { shoppingItems(jobs.beginAction(id, index, input).getJSONObject("draft"))!! }
        catch (error: Exception) { shoppingBusy.remove(key); throw error }
        IcaShoppingList.executor.execute {
            val outcome = runCatching { IcaShoppingList(context).add(token(id, index), items) }
            PrototypeHub.worker.post {
                shoppingBusy.remove(key)
                val result = outcome.mapCatching { response ->
                    jobs.finishAction(id, index, response)
                    PrototypeStore.asMap(response)
                }
                val failure = result.exceptionOrNull()
                if (failure is IcaShoppingList.IcaFailure && failure.noEffect && !alreadyConfirmed)
                    runCatching { jobs.releaseAction(id, index) }
                if (failure != null) Log.w(TAG, "Shopping $id/$index not added: ${(failure as? IcaShoppingList.IcaFailure)?.code}")
                done(result)
            }
        }
    }

    fun undoShopping(context: Context, id: String, index: Int, done: (Result<Unit>) -> Unit) {
        val jobs = PrototypeJobs(PrototypeHub.jobJournal(context))
        val key = busy(id, index)
        val response = try { jobs.beginUndoAction(id, index).getJSONObject("response") }
        catch (error: Exception) { shoppingBusy.remove(key); throw error }
        val rows = response.getJSONArray("rowIds").let { ids -> (0 until ids.length()).map { ids.getString(it) } }
        IcaShoppingList.executor.execute {
            val outcome = runCatching { IcaShoppingList(context).remove(response.getString("platformId"), rows) }
            PrototypeHub.worker.post {
                shoppingBusy.remove(key)
                done(outcome.mapCatching { jobs.finishUndoAction(id, index) })
            }
        }
    }

    // Worker-owned. An auto-add and a tap on the same action must not overlap:
    // the first one's release could drop the rows the second one wrote.
    private val shoppingBusy = mutableSetOf<String>()

    private fun busy(id: String, index: Int): String {
        val key = "$id.$index"
        if (!shoppingBusy.add(key)) throw ActionFailure("BUSY", "Action already in progress")
        return key
    }

    private fun shoppingItems(draft: JSONObject) = IcaShoppingList.validItems(draft.optJSONArray("items"))

    fun undoCreated(context: Context, id: String, index: Int) {
        val jobs = PrototypeJobs(PrototypeHub.jobJournal(context))
        val action = jobs.beginUndoAction(id, index)
        ProductivityActions(context).deleteOwnedEvent(
            action.getJSONObject("response").getString("platformId").toLong(), token(id, index))
        jobs.finishUndoAction(id, index)
    }

    /** Undo for the result the watch showed for [filename]. */
    fun undoRecording(context: Context, watchId: String, filename: String): Boolean {
        val store = PrototypeHub.journal(context)
        val jobs = PrototypeJobs(PrototypeHub.jobJournal(context))
        val id = jobs.identities().firstOrNull { id ->
            val item = jobs.state(id); val spec = item.getJSONObject("spec")
            item.optBoolean("selected") && spec.getString("watch_id") == watchId &&
                store.record(spec.getString("recording_id"))?.get("filename") == filename
        } ?: return false
        return undo(context, id)
    }

    fun undo(context: Context, id: String): Boolean {
        val undone = PrototypeJobs(PrototypeHub.jobJournal(context)).undo(id)
        if (undone) VoiceUndoNotification.cancel(context, id)
        Log.i(TAG, "Undo $id: $undone")
        return undone
    }

    private val SCHEDULE = Any()

    /** The watch is connected and acknowledges results, so it shows them itself. */
    private fun watchTakesResults(control: Map<String, Any?>): Boolean {
        val list = control["recording_list"] as? Map<*, *> ?: return false
        return control["phase"] == "ready" && (list["generation"] as? Number)?.toLong() == (control["generation"] as? Number)?.toLong() &&
            list["address"] == control["address"] && list["result_ack_version"] == 1
    }

    /** A result is ready or the watch received it: (re)start the phone Undo and the creation timer.
     *  The phone Undo is only for a watch that cannot show its own popup. */
    fun resultReady(context: Context, id: String) {
        val item = PrototypeJobs(PrototypeHub.jobJournal(context)).state(id)
        val control = PrototypeHub.journal(context).control()
        val settings = control["voice_actions"] as? Map<*, *>
        val actions = item.optJSONObject("result")?.optJSONArray("actions")
        val creates = settings?.get("auto_create") != false && actions != null &&
            (0 until actions.length()).any { draft(actions.getJSONObject(it), null) != null }
        if (item.optString("state") == "delivered") {
            VoiceUndoNotification.cancel(context, id)
        } else if (creates && !watchTakesResults(control) && item.has("undo_until") && item.optBoolean("selected") &&
            !item.optBoolean("undone") && !item.optBoolean("auto_created")) {
            VoiceUndoNotification.show(context, id, item.getJSONObject("result"), item.getLong("undo_until"))
        }
        schedule(context)
    }

    /** Runs [createExpired] when the next undo window ends. Handler time pauses in deep sleep; BLE traffic wakes it. */
    fun schedule(context: Context) {
        val app = context.applicationContext
        PrototypeHub.worker.removeCallbacksAndMessages(SCHEDULE)
        val next = PrototypeJobs(PrototypeHub.jobJournal(app)).nextUndoDeadline() ?: return
        PrototypeHub.worker.postAtTime({
            try { createExpired(app) } catch (error: Exception) { Log.w(TAG, "Auto-create failed", error) }
            schedule(app)
        }, SCHEDULE, android.os.SystemClock.uptimeMillis() + maxOf(0L, next - System.currentTimeMillis()))
    }

    /** Creates every schedulable action of results whose undo window ended. */
    fun createExpired(context: Context) {
        val jobs = PrototypeJobs(PrototypeHub.jobJournal(context))
        val settings = PrototypeHub.journal(context).control()["voice_actions"] as? Map<*, *>
        val autoCreate = settings?.get("auto_create") != false
        val calendarId = (settings?.get("calendar_id") as? Number)?.toLong()
        for (id in jobs.undoExpired(System.currentTimeMillis())) {
            VoiceUndoNotification.cancel(context, id)
            // Off: the result stays for Review & create in the app.
            if (!autoCreate) { jobs.markAutoCreated(id); continue }
            val item = jobs.state(id)
            val actions = item.getJSONObject("result").getJSONArray("actions")
            val handled = item.optJSONObject("action_states")
            for (index in 0 until actions.length()) {
                if (handled?.has(index.toString()) == true) continue
                val draft = draft(actions.getJSONObject(index), calendarId) ?: continue
                try {
                    if (draft.getString("actionType") == "shopping") createShopping(context, id, index, draft) {}
                    else create(context, id, index, draft)
                } catch (error: Exception) {
                    Log.w(TAG, "Auto-create $id/$index failed", error)
                }
            }
            jobs.markAutoCreated(id)
        }
    }

    /**
     * Same defaults as the app's Review & create. Null for notes (tasks without
     * a time) and for timed types without one; those stay in the app.
     */
    fun draft(action: JSONObject, calendarId: Long?): JSONObject? {
        val type = action.getString("type")
        if (type == "shopping") return JSONObject().put("actionType", type).put("title", action.getString("title"))
            .put("items", JSONArray(action.getJSONArray("items").toString())).put("skipUi", true)
        val scheduled = (action.optString("start_time").ifEmpty { action.optString("due_date") }).ifEmpty { null }
            ?.let(::parseLocal)
        val draft = JSONObject().put("actionType", type).put("title", action.getString("title"))
            .put("notes", action.opt("notes") ?: JSONObject.NULL).put("location", action.opt("location") ?: JSONObject.NULL)
            .put("skipUi", true).put("calendarId", calendarId ?: JSONObject.NULL)
            .put("reminderMinutes", if (type == "reminder") 0 else JSONObject.NULL)
        if (type == "timer") {
            val seconds = action.optLong("duration_seconds")
            return if (seconds > 0) draft.put("durationSeconds", seconds) else null
        }
        scheduled ?: return null
        draft.put("scheduledAtMillis", scheduled)
        if (type == "calendar_event") draft.put("endAtMillis", scheduled + 30 * 60 * 1000L)
        return draft
    }

    private fun parseLocal(value: String): Long? = runCatching { OffsetDateTime.parse(value).toInstant().toEpochMilli() }
        .recoverCatching { LocalDateTime.parse(value).atZone(ZoneId.systemDefault()).toInstant().toEpochMilli() }
        .recoverCatching { LocalDate.parse(value).atStartOfDay(ZoneId.systemDefault()).toInstant().toEpochMilli() }
        .getOrNull()
}
