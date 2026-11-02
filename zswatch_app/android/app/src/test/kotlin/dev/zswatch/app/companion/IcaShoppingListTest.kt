package dev.zswatch.app.companion

import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test

class IcaShoppingListTest {
    private fun list(offlineId: String, id: Long?, vararg rows: String) = IcaShoppingList.ShoppingList(offlineId, id, offlineId,
        rows.map { IcaShoppingList.Row(it, it, false) })

    private fun result(action: JSONObject) = JSONObject().put("version", 1).put("transcript", "Köp mjölk")
        .put("summary", "mjölk").put("category", "").put("actions", JSONArray().put(action))

    private fun rejected(action: () -> Unit) { try { action(); fail("Expected rejection") } catch (_: IllegalArgumentException) {} }

    @Test fun rowIdsAreStablePerActionAndDistinctAcrossActions() {
        val token = CompanionVoiceActions.token("a".repeat(64), 0)
        // Same value as the iOS test: both platforms derive identical row IDs.
        assertEquals(listOf("D3139376-98E8-37AA-9CDE-67D9AC94D7F9"), IcaShoppingList.rowIds("zswatch://voice-action/job/0", 1))
        assertEquals(IcaShoppingList.rowIds(token, 3), IcaShoppingList.rowIds(token, 3))
        assertEquals(3, IcaShoppingList.rowIds(token, 3).toSet().size)
        assertNotEquals(IcaShoppingList.rowIds(token, 1), IcaShoppingList.rowIds(CompanionVoiceActions.token("a".repeat(64), 1), 1))
    }

    @Test fun newestIsTheHighestServerIdAndAmbiguousListsHaveNone() {
        assertEquals("b", IcaShoppingList.newest(listOf(list("a", 5), list("b", 9), list("c", 7)))!!.id)
        assertNull(IcaShoppingList.newest(listOf(list("a", 5), list("b", null))))
        assertNull(IcaShoppingList.newest(listOf(list("a", 5), list("b", 5))))
        assertNull(IcaShoppingList.newest(emptyList()))
    }

    @Test fun parsesListsAndWritesFreeTextRows() {
        val parsed = IcaShoppingList.parseList(JSONObject().put("offlineId", "L").put("id", 12).put("title", "Veckan")
            .put("rows", JSONArray().put(JSONObject().put("offlineId", "R").put("productName", "mjölk").put("isStrikedOver", true))))
        assertEquals(IcaShoppingList.ShoppingList("L", 12, "Veckan", listOf(IcaShoppingList.Row("R", "mjölk", true))), parsed)
        val rows = IcaShoppingList.createdRows(listOf("1", "2"), listOf("mjölk", "två paket kaffe")).getJSONArray("createdRows")
        assertEquals(2, rows.length())
        assertEquals("två paket kaffe", rows.getJSONObject(1).getString("productName"))
        assertEquals(-1, rows.getJSONObject(1).getInt("sourceId"))
    }

    @Test fun sessionKeepsListChoiceAndRejectsMissingTokens() {
        val input = mapOf("client_id" to "c", "client_secret" to "s", "access_token" to "a", "refresh_token" to "r", "expires_in" to 300)
        val fresh = IcaShoppingList.session(input, null, 1000)
        assertEquals(301_000L, fresh.getLong("expires_at"))
        assertTrue(fresh.getBoolean("newest"))
        val kept = IcaShoppingList.session(input, JSONObject().put("newest", false).put("list_id", "L"), 0)
        assertFalse(kept.getBoolean("newest"))
        assertEquals("L", kept.getString("list_id"))
        rejected { IcaShoppingList.session(input - "refresh_token", null, 0) }
    }

    @Test fun shoppingResultsCarryValidItemsOnly() {
        val shopping = JSONObject().put("type", "shopping").put("title", "mjölk").put("items", JSONArray().put("mjölk"))
        PrototypeJobs.validateResult(result(shopping))
        rejected { PrototypeJobs.validateResult(result(JSONObject(shopping.toString()).put("items", JSONArray()))) }
        rejected { PrototypeJobs.validateResult(result(JSONObject(shopping.toString()).put("items", JSONArray().put(" ")))) }
        rejected { PrototypeJobs.validateResult(result(JSONObject().put("type", "shopping").put("title", "mjölk"))) }
        rejected { PrototypeJobs.validateResult(result(JSONObject().put("type", "task").put("title", "x")
            .put("items", JSONArray().put("mjölk")))) }
        val draft = CompanionVoiceActions.draft(shopping, 7)!!
        assertEquals("shopping", draft.getString("actionType"))
        assertEquals("mjölk", draft.getJSONArray("items").getString(0))
    }
}
