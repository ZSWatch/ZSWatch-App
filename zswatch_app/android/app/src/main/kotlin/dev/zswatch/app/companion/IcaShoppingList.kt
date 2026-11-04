package dev.zswatch.app.companion

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.util.UUID
import java.util.concurrent.Executors

/**
 * ICA's unofficial mobile shopping-list API. The app signs in and hands the
 * OAuth session here; voice actions add rows after the undo window and Undo
 * deletes them. Calls block: run them on [executor], never on the BLE handler.
 */
class IcaShoppingList(private val context: Context) {
    /** [noEffect] failures prove ICA's list was not changed. */
    class IcaFailure(val code: String, message: String, val noEffect: Boolean) : Exception(message)
    data class Row(val id: String, val text: String, val checked: Boolean)
    data class ShoppingList(val id: String, val serverId: Long?, val title: String, val rows: List<Row>)

    companion object {
        private const val FIELD = "ica_session"
        private const val TOKEN_URL = "https://ims.icagruppen.se/oauth/v2/token"
        private const val LISTS_URL = "https://apimgw-pub.ica.se/sverige/digx/mobile/shoppinglistservice/v1/shoppinglists"
        // Same limits as Dart's ShoppingIntent.
        const val MAX_ITEMS = 64
        const val MAX_ITEM_LENGTH = 240

        /** The items of a shopping action, or null when any of them is invalid. */
        fun validItems(items: JSONArray?): List<String>? {
            if (items == null || items.length() !in 1..MAX_ITEMS) return null
            return (0 until items.length()).map { items.opt(it) as? String ?: return null }
                .takeIf { list -> list.all { it.isNotBlank() && it.length <= MAX_ITEM_LENGTH } }
        }

        /** One at a time, so token refreshes never race. */
        val executor = Executors.newSingleThreadExecutor { Thread(it, "ZSWatchIca").apply { isDaemon = true } }

        /** Stable row IDs per action: a retried add finds the rows it already wrote. */
        fun rowIds(token: String, count: Int): List<String> =
            (0 until count).map { UUID.nameUUIDFromBytes("$token/$it".toByteArray()).toString().uppercase() }

        /** ICA's numeric list IDs grow with creation; edits do not reorder them like latestChange does. */
        fun newest(lists: List<ShoppingList>): ShoppingList? {
            val ids = lists.map { it.serverId ?: return null }
            if (ids.toSet().size != ids.size) return null
            return lists.maxByOrNull { it.serverId!! }
        }

        fun parseList(json: JSONObject): ShoppingList {
            val rows = json.optJSONArray("rows") ?: JSONArray()
            return ShoppingList(json.getString("offlineId"), if (json.opt("id") is Number) json.getLong("id") else null,
                json.optString("title"), (0 until rows.length()).map { rows.getJSONObject(it) }.map {
                    Row(it.getString("offlineId"), it.optString("productName"), it.optBoolean("isStrikedOver"))
                })
        }

        fun createdRows(ids: List<String>, items: List<String>): JSONObject = JSONObject().put("createdRows", JSONArray(
            ids.zip(items).map { (id, item) ->
                // ICA's app marks free-text rows with a negative source ID.
                JSONObject().put("offlineId", id).put("productName", item).put("sourceId", -1)
                    .put("isStrikedOver", false).put("recipes", JSONArray())
            }))

        /** A session from the app's sign-in, as stored. [previous] keeps the list choice. */
        fun session(input: Map<*, *>, previous: JSONObject?, now: Long): JSONObject {
            val session = JSONObject()
            for (field in listOf("client_id", "client_secret", "access_token", "refresh_token")) {
                val value = input[field] as? String
                require(!value.isNullOrBlank() && value.length <= 8192) { "Invalid ICA session" }
                session.put(field, value)
            }
            val expiresIn = (input["expires_in"] as? Number)?.toLong() ?: 0
            return session.put("expires_at", now + expiresIn * 1000)
                .put("newest", previous?.optBoolean("newest", true) ?: true)
                .put("list_id", previous?.opt("list_id") ?: JSONObject.NULL)
        }
    }

    fun stored(): JSONObject? = CompanionCloudCredential.read(context, FIELD)?.let { runCatching { JSONObject(it) }.getOrNull() }
    fun store(session: JSONObject) = CompanionCloudCredential.write(context, session.toString(), FIELD)
    fun clear() = CompanionCloudCredential.clear(context, FIELD)

    /** The list voice actions add to: the newest one, or the chosen one. A fixed target without a list adds nothing until one is chosen. */
    fun setTarget(newest: Boolean, listId: String?) {
        val session = stored() ?: throw notConnected()
        store(session.put("newest", newest).put("list_id", listId ?: JSONObject.NULL))
    }

    fun lists(): List<ShoppingList> {
        val body = JSONObject(api("GET", LISTS_URL, null).second)
        val lists = body.getJSONArray("shoppingLists")
        return (0 until lists.length()).map { parseList(lists.getJSONObject(it)) }
    }

    fun target(lists: List<ShoppingList>): ShoppingList? {
        val session = stored() ?: throw notConnected()
        return if (session.optBoolean("newest", true)) newest(lists)
        else lists.firstOrNull { it.id == session.optString("list_id") }
    }

    /** Adds [items] for the action [token] and returns the journal response. */
    fun add(token: String, items: List<String>): JSONObject {
        require(items.isNotEmpty() && items.size <= MAX_ITEMS) { "Invalid shopping items" }
        val ids = rowIds(token, items.size)
        val lists = try { lists() } catch (error: IOException) {
            throw IcaFailure("ICA_OFFLINE", "Could not reach ICA", true)
        }
        // An interrupted earlier attempt may have written some or all rows already.
        val earlier = lists.firstOrNull { list -> list.rows.any { it.id in ids } }
        val present = earlier?.rows?.map { it.id }?.toSet() ?: emptySet()
        if (earlier != null && present.containsAll(ids)) return response(earlier, ids)
        val target = earlier ?: target(lists) ?: throw IcaFailure("ICA_NO_LIST", "No ICA list to add to. Create one or choose a list.", true)
        val missing = ids.zip(items).filter { it.first !in present }
        // Refresh before the write: a refresh that fails cannot have added anything.
        try { accessToken(false) } catch (error: IOException) {
            throw IcaFailure("ICA_OFFLINE", "Could not reach ICA", true)
        }
        val status = try {
            api("POST", "$LISTS_URL/${encode(target.id)}/sync", createdRows(missing.map { it.first }, missing.map { it.second }), check = false).first
        } catch (error: IOException) {
            throw IcaFailure("ICA_OUTCOME_UNKNOWN", "ICA did not answer. The items may have been added.", false)
        }
        if (status in 400..499) throw IcaFailure("ICA_REJECTED", "ICA rejected the items (HTTP $status)", true)
        val written = try { list(target.id) } catch (error: IOException) {
            throw IcaFailure("ICA_OUTCOME_UNKNOWN", "ICA did not answer. The items may have been added.", false)
        }
        if (!written.rows.map { it.id }.containsAll(ids))
            throw IcaFailure("ICA_OUTCOME_UNKNOWN", "ICA did not confirm the items (HTTP $status)", false)
        return response(written, ids)
    }

    /** Removes the rows a voice action added. Rows already gone, or a deleted list (HTTP 404), count as removed. */
    fun remove(listId: String, ids: List<String>) {
        val path = "$LISTS_URL/${encode(listId)}"
        val status = api("POST", "$path/sync", JSONObject().put("deletedRows", JSONArray(ids)), check = false).first
        if (status == 404) return
        if (status !in 200..299) throw IcaFailure("ICA_HTTP", "ICA shopping lists returned HTTP $status", false)
        val (listStatus, text) = api("GET", path, null, check = false)
        if (listStatus == 404) return
        if (listStatus !in 200..299) throw IcaFailure("ICA_HTTP", "ICA shopping lists returned HTTP $listStatus", true)
        if (parseList(JSONObject(text)).rows.any { it.id in ids }) throw IcaFailure("ICA_OUTCOME_UNKNOWN", "ICA did not confirm the removal", false)
    }

    private fun list(id: String) = parseList(JSONObject(api("GET", "$LISTS_URL/${encode(id)}", null).second))

    private fun response(list: ShoppingList, ids: List<String>) = JSONObject().put("platformId", list.id)
        .put("targetType", "ica_list").put("listTitle", list.title).put("rowIds", JSONArray(ids))

    private fun notConnected() = IcaFailure("ICA_NOT_CONNECTED", "Connect ICA in Settings → Integrations", true)

    private fun encode(value: String) = URLEncoder.encode(value, "UTF-8").replace("+", "%20")

    /** A list API call. An expired token is refreshed once on HTTP 401. */
    private fun api(method: String, url: String, body: JSONObject?, check: Boolean = true): Pair<Int, String> {
        var reply = http(method, url, body?.toString(), "application/json", "Bearer ${accessToken(false)}")
        if (reply.first == 401) reply = http(method, url, body?.toString(), "application/json", "Bearer ${accessToken(true)}")
        if (reply.first == 401) throw authFailure()
        if (check && reply.first !in 200..299)
            throw IcaFailure("ICA_HTTP", "ICA shopping lists returned HTTP ${reply.first}", method == "GET")
        return reply
    }

    private fun accessToken(force: Boolean): String {
        val session = stored() ?: throw notConnected()
        if (!force && session.getLong("expires_at") > System.currentTimeMillis() + 60_000) return session.getString("access_token")
        val basic = android.util.Base64.encodeToString(
            "${session.getString("client_id")}:${session.getString("client_secret")}".toByteArray(), android.util.Base64.NO_WRAP)
        val form = "grant_type=refresh_token&refresh_token=" + URLEncoder.encode(session.getString("refresh_token"), "UTF-8")
        val (status, text) = http("POST", TOKEN_URL, form, "application/x-www-form-urlencoded", "Basic $basic")
        if (status in 400..499) throw authFailure()
        if (status !in 200..299) throw IcaFailure("ICA_HTTP", "ICA sign-in returned HTTP $status", true)
        val token = JSONObject(text)
        session.put("access_token", token.getString("access_token"))
            .put("expires_at", System.currentTimeMillis() + token.optLong("expires_in", 300) * 1000)
        token.optString("refresh_token").takeIf { it.isNotEmpty() }?.let { session.put("refresh_token", it) }
        store(session)
        return session.getString("access_token")
    }

    private fun authFailure() = IcaFailure("ICA_AUTH", "ICA signed this phone out. Reconnect ICA in Settings → Integrations.", true)

    private fun http(method: String, url: String, body: String?, contentType: String, authorization: String): Pair<Int, String> {
        val connection = URL(url).openConnection() as HttpURLConnection
        try {
            connection.requestMethod = method
            connection.instanceFollowRedirects = false
            connection.connectTimeout = 15_000
            connection.readTimeout = 30_000
            connection.setRequestProperty("Authorization", authorization)
            connection.setRequestProperty("Accept", "application/json")
            if (body != null) {
                connection.doOutput = true
                connection.setRequestProperty("Content-Type", contentType)
                connection.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
            }
            val status = connection.responseCode
            val stream = if (status >= 400) connection.errorStream else connection.inputStream
            val text = stream?.use { it.readBytes().toString(Charsets.UTF_8) } ?: ""
            return status to text
        } finally {
            connection.disconnect()
        }
    }
}
