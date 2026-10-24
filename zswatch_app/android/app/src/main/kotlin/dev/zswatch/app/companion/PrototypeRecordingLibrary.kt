package dev.zswatch.app.companion

import org.json.JSONObject

/** Phone-side recording edits. Never sends a watch command; watch originals remain. */
class PrototypeRecordingLibrary(
    private val store: PrototypeStore,
    private val files: ReceiptFiles,
    private val jobs: () -> PrototypeJobs,
) {
    @Suppress("UNCHECKED_CAST")
    private fun records(): Map<String, Map<String, Any?>> =
        store.control()["recordings"] as? Map<String, Map<String, Any?>> ?: emptyMap()

    private fun publish(kind: String, records: Map<String, Map<String, Any?>>) =
        store.update(kind, mapOf("recordings" to JSONObject(records)))

    /** Finish a delete or purge that a lost process left half done. */
    fun recover() {
        for ((key, metadata) in records()) {
            if (metadata["state"] != "deleted") continue
            try {
                if (metadata["purged"] == true) { finishPurge(key); continue }
                jobs().cancelRecordings(setOf(key))
                files.removeLocal(key, metadata)
            } catch (error: Exception) {
                val failed = metadata.toMutableMap()
                if (metadata["purged"] == true) failed["purge_pending"] = true
                failed["error"] = "receipt_unavailable"
                store.putRecord(key, failed)
            }
        }
    }

    fun update(identity: String, title: String?, archived: Boolean?) {
        val record = records()[identity]
        require(record != null && record["purged"] != true && (title != null || archived != null) &&
            (title == null || (title.toByteArray(Charsets.UTF_8).size <= 256 && title.none { it.isISOControl() }))) {
            "Recording title/archive change required"
        }
        val next = record.toMutableMap()
        if (title != null) next["title"] = title.trim()
        if (archived != null) next["archived"] = archived
        store.putRecord(identity, next)
    }

    fun remove(identities: List<String>) {
        val selected = identities.toSet()
        val records = records()
        require(selected.isNotEmpty() && selected.size == identities.size && selected.size <= BATCH_LIMIT &&
            selected.all { records[it]?.get("purged") != true && records[it]?.get("state") in listOf("downloaded", "deleted") }) {
            "Select up to $BATCH_LIMIT saved recordings"
        }
        jobs().cancelRecordings(selected)
        val now = System.currentTimeMillis()
        val next = records.toMutableMap()
        for (key in selected) next[key] = next.getValue(key) + mapOf("state" to "deleted", "deleted_at" to now) - "processing_request"
        publish("recordings_removed_locally", next)
        // A lost process after the durable tombstone is repaired by recover().
        for (key in selected) files.removeLocal(key, next.getValue(key))
    }

    fun purge(identities: List<String>) {
        val selected = identities.toSet()
        val records = records()
        require(selected.isNotEmpty() && selected.size == identities.size && selected.size <= BATCH_LIMIT &&
            selected.all { records[it]?.get("state") == "deleted" }) {
            "Select up to $BATCH_LIMIT Recently deleted recordings"
        }
        // Durable intent first: after this the recording can never be restored,
        // imported or downloaded again. Startup retries the cleanup.
        val next = records.toMutableMap()
        for (key in selected) next[key] = next.getValue(key) + mapOf("purged" to true, "purge_pending" to true) -
            setOf("title", "processing_request", "local_path")
        publish("recordings_purge_requested", next)
        for (key in selected) finishPurge(key)
    }

    private fun finishPurge(identity: String) {
        val record = records()[identity] ?: return
        jobs().purgeRecordings(setOf(identity))
        files.purgeLocal(identity, record)
        if (record["purge_pending"] == true || record["error"] != null) {
            store.putRecord(identity, record + mapOf("purge_pending" to false) - "error")
        }
    }

    fun restore(identity: String) {
        val record = records()[identity]
        require(record != null && record["state"] == "deleted" && record["purged"] != true) { "Deleted recording required" }
        store.putRecord(identity, files.restoreLocal(identity, record) - "deleted_at")
    }

    fun search(query: String): Set<String> {
        val records = records()
        val matches = jobs().search(query).toMutableSet()
        for ((key, record) in records) {
            if (listOf(record["title"], record["filename"]).any { (it as? String)?.contains(query, ignoreCase = true) == true }) matches += key
        }
        return matches.intersect(records.keys)
    }

    companion object { const val BATCH_LIMIT = 100 }
}
