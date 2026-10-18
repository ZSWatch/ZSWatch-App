package dev.zswatch.app.companion

import org.json.JSONArray
import org.json.JSONObject
import java.security.MessageDigest

/** Portable recovery contract. Caller serializes access; no BLE, network or AI here. */
class PrototypeJobs(private val store: PrototypeStore) {
    data class Claim(val id: String, val fence: Long, val spec: JSONObject, val remoteId: String?, val attempts: Int)
    private fun objectField(name: String): JSONObject {
        val value = store.control()[name]
        require(value == null || value is Map<*, *>) { "Invalid job journal field" }
        return JSONObject(value as? Map<*, *> ?: emptyMap<String, Any>())
    }
    private fun jobs() = objectField("jobs")
    private fun outbox() = objectField("outbox")
    private fun commit(kind: String, jobs: JSONObject, outbox: JSONObject = outbox()) =
        store.update(kind, mapOf("jobs" to jobs, "outbox" to outbox))

    fun create(spec: JSONObject, transcript: String? = null): String {
        if (transcript != null) require(transcript.isNotBlank() && transcript.toByteArray(Charsets.UTF_8).size <= 65536)
        val id = key(spec)
        val jobs = jobs(); val outbox = outbox()
        if (!jobs.has(id)) {
            pruneSuperseded(jobs, outbox, spec)
            // Finished jobs hold the user's transcripts and results; only
            // pending work is bounded, plus a generous total journal bound.
            require(jobs.keys().asSequence().count { jobs.getJSONObject(it).getString("state") in ACTIVE } < ACTIVE_LIMIT &&
                jobs.length() < TOTAL_LIMIT) { "Job capacity reached" }
        }
        for (oldId in jobs.keys()) {
            val old = jobs.getJSONObject(oldId); val previous = old.getJSONObject("spec")
            if (previous.getString("watch_id") != spec.getString("watch_id") ||
                previous.getString("recording_id") != spec.getString("recording_id")) continue
            val generation = spec.getLong("generation"); val oldGeneration = previous.getLong("generation")
            require(oldGeneration <= generation && (oldGeneration != generation || oldId == id)) {
                "Changed input/backend requires a new generation; obsolete generations cannot return"
            }
            if (oldGeneration < generation && old.getString("state") != "delivered") cancelItem(oldId, old, outbox)
        }
        if (!jobs.has(id)) {
            val item = JSONObject().put("spec", JSONObject(spec.toString())).put("state", "ready")
                .put("remote_id", JSONObject.NULL).put("fence", 0L).put("lease_until", JSONObject.NULL)
                .put("attempts", 0).put("next_attempt", 0L).put("last_error", JSONObject.NULL)
            if (transcript != null) item.put("transcript", transcript)
            jobs.put(id, item)
        }
        if (spec.getString("provider") == "dart-voice-v1") selectItem(jobs, id)
        commit("job_created", jobs, outbox)
        return id
    }

    /** Drop failed/cancelled jobs that a newer generation of the same recording replaced. */
    private fun pruneSuperseded(jobs: JSONObject, outbox: JSONObject, incoming: JSONObject) {
        fun recording(spec: JSONObject) = spec.getString("watch_id") + "\u0000" + spec.getString("recording_id")
        val latest = mutableMapOf(recording(incoming) to incoming.getLong("generation"))
        for (id in jobs.keys()) {
            val spec = jobs.getJSONObject(id).getJSONObject("spec")
            latest[recording(spec)] = maxOf(latest[recording(spec)] ?: 0L, spec.getLong("generation"))
        }
        val obsolete = jobs.keys().asSequence().filter { id ->
            val item = jobs.getJSONObject(id); val spec = item.getJSONObject("spec")
            // The incoming voice job takes over selection for its own recording.
            val reselected = recording(spec) == recording(incoming) && incoming.getString("provider") == "dart-voice-v1"
            item.getString("state") in listOf("failed", "cancelled") && (!item.optBoolean("selected") || reselected) &&
                spec.getLong("generation") < latest.getValue(recording(spec))
        }.toSet()
        for (id in obsolete) jobs.remove(id)
        for (resultId in outbox.keys().asSequence().toList()) {
            val delivery = outbox.getJSONObject(resultId)
            if (delivery.getString("job_id") in obsolete && delivery.getString("state") != "pending") outbox.remove(resultId)
        }
    }

    fun state(id: String): JSONObject = jobs().getJSONObject(id)
    fun identities(): List<String> = jobs().keys().asSequence().toList()

    /** Choose the requested result for the UI without rerunning or republishing it. */
    fun select(id: String) {
        val jobs = jobs()
        require(jobs.getJSONObject(id).getJSONObject("spec").getString("provider") == "dart-voice-v1")
        if (selectItem(jobs, id)) commit("voice_job_selected", jobs)
    }

    private fun selectItem(jobs: JSONObject, id: String): Boolean {
        val selected = jobs.getJSONObject(id).getJSONObject("spec")
        var changed = false
        for (otherId in jobs.keys()) {
            val item = jobs.getJSONObject(otherId); val spec = item.getJSONObject("spec")
            if (spec.getString("watch_id") != selected.getString("watch_id") ||
                spec.getString("recording_id") != selected.getString("recording_id")) continue
            val wanted = otherId == id
            if (item.optBoolean("selected") != wanted) {
                item.put("selected", wanted); changed = true
            }
        }
        return changed
    }

    private fun actionItem(jobs: JSONObject, id: String, index: Int): JSONObject {
        val item = jobs.getJSONObject(id)
        require(item.getJSONObject("spec").getString("provider") == "dart-voice-v1")
        require(index >= 0 && index < item.getJSONObject("result").getJSONArray("actions").length())
        return item
    }

    private fun actionStates(item: JSONObject): JSONObject = item.optJSONObject("action_states")
        ?: JSONObject().also { item.put("action_states", it) }

    private fun commitAction(kind: String, jobs: JSONObject, item: JSONObject) {
        item.put("action_revision", item.optLong("action_revision") + 1)
        commit(kind, jobs)
    }

    /** Durable user confirmation, independent of watch delivery. Clock intents have no receipt. */
    fun beginAction(id: String, index: Int, draft: JSONObject): JSONObject {
        val jobs = jobs(); val item = actionItem(jobs, id, index)
        require(item.getString("state") in listOf("result_ready", "delivered")) { "No accepted action draft" }
        val type = item.getJSONObject("result").getJSONArray("actions").getJSONObject(index).getString("type")
        require(draft.getString("actionType") == type) { "Action type changed" }
        val states = actionStates(item)
        val previous = states.optJSONObject(index.toString())
        if (previous != null) {
            require(previous.getString("state") == "creating" && type !in listOf("timer", "alarm")) {
                "Action already handled; check Clock for an interrupted timer/alarm"
            }
            // A retry recovers the original confirmed input, never a changed draft.
            return JSONObject(previous.toString())
        }
        val action = JSONObject().put("state", "creating").put("draft", JSONObject(draft.toString()))
        states.put(index.toString(), action)
        commitAction("action_confirmed", jobs, item)
        return JSONObject(action.toString())
    }

    fun finishAction(id: String, index: Int, response: JSONObject) {
        val jobs = jobs(); val item = actionItem(jobs, id, index)
        val action = actionStates(item).getJSONObject(index.toString())
        if (action.getString("state") == "created") return
        require(action.getString("state") == "creating")
        action.put("response", JSONObject(response.toString())).put("state",
            if (action.getJSONObject("draft").getString("actionType") in listOf("timer", "alarm")) "dispatched" else "created")
        commitAction("action_created", jobs, item)
    }

    /** Use only when failure proves no side effect occurred (e.g. missing permission/handler). */
    fun releaseAction(id: String, index: Int) {
        val jobs = jobs(); val item = actionItem(jobs, id, index)
        val states = actionStates(item)
        require(states.getJSONObject(index.toString()).getString("state") == "creating")
        states.remove(index.toString()); commitAction("action_not_created", jobs, item)
    }

    fun dismissAction(id: String, index: Int) {
        val jobs = jobs(); val item = actionItem(jobs, id, index); val states = actionStates(item)
        require(item.getString("state") in listOf("result_ready", "delivered"))
        require(!states.has(index.toString())) { "Action already handled" }
        states.put(index.toString(), JSONObject().put("state", "dismissed"))
        commitAction("action_dismissed", jobs, item)
    }

    fun beginUndoAction(id: String, index: Int): JSONObject {
        val jobs = jobs(); val item = actionItem(jobs, id, index)
        val action = actionStates(item).getJSONObject(index.toString())
        require(action.getString("state") in listOf("created", "undoing")) { "Only calendar entries can be undone here" }
        action.put("state", "undoing"); commitAction("action_undo_started", jobs, item)
        return JSONObject(action.toString())
    }

    fun finishUndoAction(id: String, index: Int) {
        val jobs = jobs(); val item = actionItem(jobs, id, index)
        val action = actionStates(item).getJSONObject(index.toString())
        require(action.getString("state") == "undoing")
        action.put("state", "undone"); commitAction("action_undone", jobs, item)
    }

    /** Called once in a new Android process. No local worker survived its predecessor. */
    fun recoverLocalClaims() {
        val jobs = jobs()
        var changed = false
        for (id in jobs.keys()) {
            val item = jobs.getJSONObject(id)
            // Earlier builds blocked a job when its foreground service could not
            // start or was stopped. That is transient; queue it again.
            if (item.getString("state") == "blocked" && item.optString("last_error") in TRANSIENT_EXECUTION_ERRORS) {
                item.put("state", "ready").put("fence", item.getLong("fence") + 1).put("lease_until", JSONObject.NULL)
                    .put("next_attempt", 0L).put("attempts", 0)
                changed = true
                continue
            }
            if (item.getJSONObject("spec").getString("backend") != "local" || item.isNull("lease_until") ||
                item.getString("state") != "ready") continue
            item.put("fence", item.getLong("fence") + 1).put("lease_until", JSONObject.NULL)
                .put("next_attempt", 0L).put("last_error", "execution_interrupted")
            changed = true
        }
        if (changed) commit("local_process_recovered", jobs)
    }

    fun claim(id: String, now: Long, leaseSeconds: Long = 30, maxAttempts: Int? = null): Claim? {
        require(leaseSeconds > 0 && (maxAttempts == null || maxAttempts > 0))
        val jobs = jobs(); val item = jobs.getJSONObject(id)
        if (item.getString("state") !in listOf("ready", "waiting_remote") || item.getLong("next_attempt") > now ||
            (!item.isNull("lease_until") && item.getLong("lease_until") > now)) return null
        if (maxAttempts != null && item.getInt("attempts") >= maxAttempts) {
            item.put("state", "failed").put("lease_until", JSONObject.NULL).put("last_error", "execution_attempt_limit")
            commit("job_attempt_limit", jobs)
            return null
        }
        item.put("fence", item.getLong("fence") + 1).put("lease_until", now + leaseSeconds)
            .put("attempts", item.getInt("attempts") + 1)
        commit("job_claimed", jobs)
        return Claim(id, item.getLong("fence"), item.getJSONObject("spec"),
            if (item.isNull("remote_id")) null else item.getString("remote_id"), item.getInt("attempts"))
    }

    private fun owned(jobs: JSONObject, claim: Claim, now: Long): JSONObject? {
        val item = jobs.optJSONObject(claim.id) ?: return null
        return item.takeIf { it.getLong("fence") == claim.fence && !it.isNull("lease_until") &&
            it.getLong("lease_until") > now && it.getString("state") in listOf("ready", "waiting_remote") }
    }

    /** Android durability adapter for a checkpoint produced by shared Dart logic. */
    fun checkpointTranscript(claim: Claim, now: Long, transcript: String): Boolean {
        require(transcript.isNotBlank() && transcript.toByteArray(Charsets.UTF_8).size <= 65536)
        val jobs = jobs(); val item = owned(jobs, claim, now) ?: return false
        require(item.getJSONObject("spec").getString("provider") == "dart-voice-v1")
        if (item.has("transcript")) require(item.getString("transcript") == transcript)
        item.put("transcript", transcript)
        commit("job_transcript_committed", jobs); return true
    }

    fun accepted(claim: Claim, now: Long, remoteId: String): Boolean {
        require(remoteId.isNotBlank() && remoteId.length <= 256)
        val jobs = jobs(); val item = owned(jobs, claim, now) ?: return false
        require(item.getJSONObject("spec").getString("backend") == "remote")
        require(item.isNull("remote_id") || item.getString("remote_id") == remoteId) { "Remote identity changed" }
        item.put("remote_id", remoteId).put("state", "waiting_remote")
        commit("job_remote_accepted", jobs); return true
    }

    fun defer(claim: Claim, now: Long, delay: Long, error: String, blocked: Boolean = false, maxAttempts: Int = 5,
              countAttempt: Boolean = true): Boolean {
        require(delay >= 0 && maxAttempts > 0)
        val jobs = jobs(); val item = owned(jobs, claim, now) ?: return false
        val attempts = item.getInt("attempts") - if (error == "server_pending" || !countAttempt) 1 else 0
        item.put("attempts", attempts).put("lease_until", JSONObject.NULL).put("next_attempt", now + delay)
            .put("last_error", error).put("state", if (blocked) "blocked" else if (attempts >= maxAttempts) "failed" else item.getString("state"))
        commit("job_deferred", jobs); return true
    }

    fun complete(claim: Claim, now: Long, result: JSONObject, remoteId: String?): Boolean {
        val transcriptionOnly = claim.spec.optString("pipeline_revision") == "transcribe-v1"
        validateResult(result, transcriptionOnly)
        val jobs = jobs(); val item = owned(jobs, claim, now) ?: return false
        val actualRemote = if (item.isNull("remote_id")) null else item.getString("remote_id")
        require(actualRemote == remoteId)
        val spec = item.getJSONObject("spec")
        require(spec.getString("backend") != "remote" || remoteId != null)
        if (transcriptionOnly) {
            require(spec.getString("provider") == "dart-voice-v1" && spec.getString("backend") == "local")
            item.put("result", result).put("transcript", result.getString("transcript"))
                .put("state", "transcribed").put("lease_until", JSONObject.NULL).put("last_error", JSONObject.NULL)
            // A transcript is phone data, not an AI popup/action for the watch.
            commit("job_transcription_completed", jobs)
            return true
        }
        val resultId = sha("result-v1:" + claim.id)
        val envelope = JSONObject().put("version", 1).put("result_id", resultId).put("job_id", claim.id)
            .put("watch_id", spec.getString("watch_id")).put("recording_id", spec.getString("recording_id"))
            .put("generation", spec.getLong("generation")).put("result", result)
        val outbox = outbox()
        require(!outbox.has(resultId)) { "Result identity already published" }
        outbox.put(resultId, JSONObject().put("job_id", claim.id).put("watch_id", spec.getString("watch_id"))
            .put("payload", canonical(envelope)).put("state", "pending"))
        item.put("result", result).put("state", "result_ready").put("lease_until", JSONObject.NULL).put("last_error", JSONObject.NULL)
        // Result + outbox share one flushed rename. No watch delivery/action is implied.
        commit("job_result_committed", jobs, outbox); return true
    }

    fun cancel(id: String, claim: Claim? = null, now: Long = 0): Boolean {
        val jobs = jobs(); val item = jobs.getJSONObject(id); val outbox = outbox()
        require(claim == null || claim.id == id)
        if (claim != null && owned(jobs, claim, now) == null) return false
        if (item.getString("state") in listOf("cancelled", "delivered")) return false
        cancelItem(id, item, outbox); commit("job_cancelled", jobs, outbox); return true
    }

    private fun cancelItem(id: String, item: JSONObject, outbox: JSONObject) {
        item.put("state", "cancelled").put("fence", item.getLong("fence") + 1).put("lease_until", JSONObject.NULL)
        for (resultId in outbox.keys()) {
            val delivery = outbox.getJSONObject(resultId)
            if (delivery.getString("job_id") == id && delivery.getString("state") == "pending") delivery.put("state", "cancelled")
        }
    }

    fun refreshCredentials(id: String): Boolean {
        val jobs = jobs(); val item = jobs.getJSONObject(id)
        if (item.getString("state") != "blocked") return false
        item.put("state", if (item.isNull("remote_id")) "ready" else "waiting_remote").put("fence", item.getLong("fence") + 1)
            .put("lease_until", JSONObject.NULL).put("next_attempt", 0L).put("attempts", 0).put("last_error", JSONObject.NULL)
        commit("job_credentials_refreshed", jobs); return true
    }

    fun pending(watchId: String): List<JSONObject> = outbox().let { box -> box.keys().asSequence().sorted()
        .map { box.getJSONObject(it) }.filter { it.getString("watch_id") == watchId && it.getString("state") == "pending" }.toList() }

    /** Only call for a negotiated application receipt ACK; never for ATT completion. */
    fun acknowledge(watchId: String, resultId: String, status: String): Boolean {
        if (status != "accepted") return false
        val box = outbox(); val delivery = box.optJSONObject(resultId) ?: return false
        if (delivery.getString("watch_id") != watchId || delivery.getString("state") == "cancelled") return false
        val jobs = jobs(); jobs.getJSONObject(delivery.getString("job_id")).put("state", "delivered")
        delivery.put("state", "acked"); commit("job_delivery_acked", jobs, box); return true
    }

    fun summary(): List<Map<String, Any?>> = identities().map { id ->
        val item = state(id)
        val spec = item.getJSONObject("spec")
        mapOf("job_id" to id, "state" to item.getString("state"), "remote_id" to item.optString("remote_id", ""),
            "selected" to item.optBoolean("selected"),
            "watch_id" to spec.getString("watch_id"), "recording_id" to spec.getString("recording_id"),
            "provider" to spec.getString("provider"), "model" to spec.getString("model"),
            "pipeline_revision" to spec.getString("pipeline_revision"),
            "generation" to spec.getLong("generation"),
            "processing" to !item.isNull("lease_until"), "transcript_saved" to item.has("transcript"),
            "action_revision" to item.optLong("action_revision"),
            "next_attempt" to item.getLong("next_attempt"), "attempts" to item.getInt("attempts"),
            "last_error" to if (item.isNull("last_error")) null else item.getString("last_error"))
    }

    companion object {
        private val ACTIVE = listOf("ready", "waiting_remote", "blocked")
        private const val ACTIVE_LIMIT = 100
        private const val TOTAL_LIMIT = 2000
        val TRANSIENT_EXECUTION_ERRORS = listOf("execution_not_allowed", "execution_interrupted")
        private val fields = setOf("version", "watch_id", "recording_id", "input_sha256", "backend", "provider",
            "model", "pipeline_revision", "generation", "upload_authorized")
        fun sha(text: String): String = MessageDigest.getInstance("SHA-256").digest(text.toByteArray(Charsets.UTF_8))
            .joinToString("") { "%02x".format(it.toInt() and 255) }
        private fun integer(value: Any) = value is Int || value is Long
        fun key(spec: JSONObject): String {
            require(spec.keys().asSequence().toSet() == fields && integer(spec.get("version")) && spec.getLong("version") == 1L)
            for (name in listOf("watch_id", "recording_id", "provider", "model", "pipeline_revision"))
                require(spec.get(name) is String && spec.getString(name).isNotEmpty() && spec.getString(name).length <= 1024)
            require(spec.get("input_sha256") is String && Regex("[a-f0-9]{64}").matches(spec.getString("input_sha256")))
            require(integer(spec.get("generation")) && spec.getLong("generation") >= 1)
            require(spec.get("backend") in listOf("local", "remote") && spec.get("upload_authorized") is Boolean)
            require(spec.getString("backend") != "remote" || spec.getBoolean("upload_authorized"))
            return sha(canonical(spec))
        }
        fun validateResult(result: JSONObject, transcriptionOnly: Boolean = false) {
            require(result.keys().asSequence().toSet() == setOf("version", "transcript", "summary", "category", "actions")) { "result_fields" }
            require(integer(result.get("version")) && result.getLong("version") == 1L) { "result_version" }
            for (name in listOf("transcript", "summary", "category")) require(result.get(name) is String) { "result_text_type" }
            if (transcriptionOnly) {
                require(result.getString("transcript").isNotBlank()) { "result_transcript_empty" }
                require(result.getString("summary").isEmpty() && result.getString("category").isEmpty()) { "result_unexpected_analysis" }
            } else require(result.getString("summary").isNotBlank()) { "result_summary_empty" }
            require(result.get("actions") is JSONArray) { "result_actions_type" }
            if (transcriptionOnly) require(result.getJSONArray("actions").length() == 0) { "result_unexpected_actions" }
            for (i in 0 until result.getJSONArray("actions").length()) {
                val action = result.getJSONArray("actions").getJSONObject(i)
                require(action.get("type") in listOf("task", "calendar_event", "reminder", "timer", "alarm"))
                require(action.get("title") is String && action.getString("title").isNotBlank())
                require(action.keys().asSequence().toSet().all { it in setOf("type", "title", "due_date", "start_time", "notes", "location", "duration_seconds") })
                for (field in listOf("due_date", "start_time", "notes", "location"))
                    require(!action.has(field) || action.get(field) is String)
                require(!action.has("duration_seconds") || (integer(action.get("duration_seconds")) && action.getLong("duration_seconds") > 0))
            }
            require(canonical(result).toByteArray(Charsets.UTF_8).size <= 65536) { "Result exceeds prototype bound" }
        }
        /** Matches Python ensure_ascii=False/sorted keys; deliberately no floats/null. */
        fun canonical(value: Any): String = when (value) {
            is JSONObject -> value.keys().asSequence().sorted().joinToString(",", "{", "}") { canonical(it) + ":" + canonical(value.get(it)) }
            is JSONArray -> (0 until value.length()).joinToString(",", "[", "]") { canonical(value.get(it)) }
            is Boolean, is Int, is Long -> value.toString()
            is String -> buildString {
                append('"'); var i = 0
                while (i < value.length) {
                    val c = value[i]
                    if (Character.isHighSurrogate(c)) { require(i + 1 < value.length && Character.isLowSurrogate(value[i + 1])); append(c); append(value[++i]) }
                    else { require(!Character.isLowSurrogate(c)); append(when (c) {
                        '"' -> "\\\""; '\\' -> "\\\\"; '\b' -> "\\b"; '\u000C' -> "\\f"; '\n' -> "\\n"; '\r' -> "\\r"; '\t' -> "\\t"
                        else -> if (c.code < 32) "\\u%04x".format(c.code) else c.toString()
                    }) }
                    i++
                }; append('"')
            }
            else -> throw IllegalArgumentException("Unsupported canonical value")
        }
    }
}
