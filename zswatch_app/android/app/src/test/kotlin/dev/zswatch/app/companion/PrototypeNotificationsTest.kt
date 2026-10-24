package dev.zswatch.app.companion

import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class PrototypeNotificationsTest {
    @get:Rule val temporary = TemporaryFolder()
    private val packageName = "com.zswatch.app"
    private fun store() = PrototypeStore(temporary.root).also {
        if (it.control()["desired_running"] != true) it.update("fixture", mapOf("desired_running" to true))
    }
    private fun notification(key: String = "first", body: String = "Fixture text") = mapOf<String, Any?>(
        "key" to key, "packageName" to packageName, "appName" to "ZSWatch", "title" to "Fixture", "body" to body)

    @Test fun disabledAndBlockedPackagesAreNotCollected() {
        val inbox = PrototypeNotifications(store())
        assertFalse(inbox.post(notification(), 0))
        inbox.configure(true, listOf(packageName))
        assertFalse(inbox.post(notification(), 0))
        assertNull(inbox.next(1, 0))
    }

    @Test fun writtenNotificationKeepsIdentityAcrossReopenAndReconnect() {
        val journal = store(); val inbox = PrototypeNotifications(journal)
        inbox.configure(true, emptyList()); assertTrue(inbox.post(notification(), 0))
        val first = inbox.next(1, 0)!!; inbox.written(first, 1)
        assertFalse(first.replace)
        assertNull(inbox.next(1, 0))
        val reopened = PrototypeNotifications(PrototypeStore(temporary.root))
        val replay = reopened.next(2, 0)!!
        assertEquals(first.id, replay.id); assertEquals(first.packet, replay.packet)
        assertFalse(reopened.post(notification(), 0))
        assertFalse(journal.snapshot(false).containsKey("notifications"))
        assertEquals(1, journal.snapshot(false)["notification_count"])
    }

    @Test fun staleWriteCannotClearUpdatedOrRemovedNotification() {
        val inbox = PrototypeNotifications(store()); inbox.configure(true, emptyList())
        inbox.post(notification(), 0); val old = inbox.next(1, 0)!!
        inbox.post(notification(body = "Updated"), 1); inbox.written(old, 1)
        val update = inbox.next(1, 1)!!
        assertTrue(update.replace)
        assertEquals(old.id, update.id); assertTrue(update.packet.contains("Updated"))
        inbox.remove("first"); inbox.written(update, 1)
        val removal = inbox.next(1, 1)!!
        assertFalse(removal.replace)
        assertTrue(removal.packet.contains("notify-")); assertEquals(old.id, removal.id)
        inbox.written(removal, 1); assertNull(inbox.next(1, 1))
    }

    @Test fun activeSetReconciliationSurvivesListenerProcessDeath() {
        val inbox = PrototypeNotifications(store()); inbox.configure(true, emptyList())
        inbox.post(notification(), 0); inbox.written(inbox.next(1, 0)!!, 1)
        val reopened = PrototypeNotifications(PrototypeStore(temporary.root))
        reopened.reconcile(emptySet())
        assertTrue(reopened.next(2, 0)!!.packet.contains("notify-"))
    }

    @Test fun expiryAndDisablingRemoveOldWatchStateWithoutReplayingText() {
        val inbox = PrototypeNotifications(store()); inbox.configure(true, emptyList())
        inbox.post(notification(), 0)
        val expired = inbox.next(1, PrototypeNotifications.RETENTION_MS)!!
        assertTrue(expired.packet.contains("notify-")); assertFalse(expired.packet.contains("Fixture text"))
        inbox.written(expired, 1)
        inbox.post(notification(), 1); inbox.configure(false, emptyList())
        assertTrue(inbox.next(1, 2)!!.packet.contains("notify-"))
    }

    @Test fun unicodeAndJsonEscapesFitFirmwareReceiveBuffer() {
        val inbox = PrototypeNotifications(store()); inbox.configure(true, emptyList())
        inbox.post(notification(body = "🎙️\"\\\n".repeat(1000)), 0)
        val wire = inbox.next(1, 0)!!.packet
        assertTrue(wire.toByteArray(Charsets.UTF_8).size < 2000)
        val parsed = JSONObject(wire.removePrefix("GB(").removeSuffix(")"))
        assertFalse(parsed.getString("body").contains('\uFFFD'))
        assertFalse(parsed.getString("body").contains('\n'))
    }

    @Test fun offlineMaintenancePurgesTextWithoutATransport() {
        val journal = store(); val inbox = PrototypeNotifications(journal)
        inbox.configure(true, emptyList()); inbox.post(notification(), 0)
        inbox.expire(PrototypeNotifications.RETENTION_MS)
        val saved = journal.control()["notifications"] as Map<*, *>
        val item = saved.values.single() as Map<*, *>
        assertEquals(true, item["removed"])
        assertFalse(item.containsKey("packet"))
        assertTrue(PrototypeNotifications(PrototypeStore(temporary.root)).next(2, 0)!!.packet.contains("notify-"))
    }

    @Test fun listenerRestartCannotResurrectExpiredAndroidNotificationText() {
        val journal = store(); val inbox = PrototypeNotifications(journal)
        inbox.configure(true, emptyList())
        val notice = notification() + mapOf("postedAt" to 0L)
        assertTrue(inbox.post(notice, 0))
        val expired = inbox.next(1, PrototypeNotifications.RETENTION_MS)!!
        inbox.written(expired, 1)
        val reopened = PrototypeNotifications(PrototypeStore(temporary.root))
        assertFalse(reopened.post(notice, PrototypeNotifications.RETENTION_MS + 1))
        assertNull(reopened.next(2, PrototypeNotifications.RETENTION_MS + 1))
        assertTrue(reopened.post(notification(body = "New update") + mapOf("postedAt" to PrototypeNotifications.RETENTION_MS),
            PrototypeNotifications.RETENTION_MS + 1))
    }

    @Test fun capacityIsBoundedAndUnknownRemovalsDoNotCreateEntries() {
        val inbox = PrototypeNotifications(store()); inbox.configure(true, emptyList())
        repeat(PrototypeNotifications.CAPACITY) { assertTrue(inbox.post(notification("key$it"), 0)) }
        assertFalse(inbox.post(notification("overflow"), 0))
        assertFalse(inbox.remove("unknown"))
    }

    @Test fun stopClearsPendingContentAndLaterEventsCannotUndoStop() {
        val journal = store(); val inbox = PrototypeNotifications(journal)
        inbox.configure(true, emptyList()); inbox.post(notification(), 0)
        val runtime = PrototypeRuntime(journal, object : PrototypeTransport {
            override fun connect(address: String, generation: Long) {}
            override fun close() {}
        })
        runtime.stop()
        assertFalse(inbox.post(notification(), 1)); assertNull(inbox.next(2, 1))
    }

    @Test fun watchDismissalUsesPersistedIdentityOnlyForItsActiveDeliverySession() {
        val journal = store(); journal.update("session", mapOf("generation" to 1L))
        val inbox = PrototypeNotifications(journal); inbox.configure(true, emptyList())
        inbox.post(notification(), 0); val delivery = inbox.next(1, 0)!!
        val action = JSONObject().put("t", "notify").put("n", "DISMISS").put("id", delivery.id)
        assertTrue(inbox.dismissalKeys(action, 1, 0).isEmpty())
        inbox.written(delivery, 1)
        val reopened = PrototypeNotifications(PrototypeStore(temporary.root))
        assertEquals(listOf("first"), reopened.dismissalKeys(action, 1, 0))
        journal.update("reconnect", mapOf("generation" to 2L))
        assertTrue(inbox.dismissalKeys(action, 2, 0).isEmpty())
        assertTrue(inbox.dismissalKeys(action, 1, 0).isEmpty())
        inbox.written(inbox.next(2, 0)!!, 2)
        assertEquals(listOf("first"), inbox.dismissalKeys(action, 2, 0))
    }

    @Test fun dismissAllIsScopedToAllowedUnexpiredForwardedNoticesAndStopDisablesActions() {
        val journal = store(); journal.update("session", mapOf("generation" to 1L))
        val inbox = PrototypeNotifications(journal); inbox.configure(true, emptyList())
        inbox.post(notification("first"), 0); inbox.written(inbox.next(1, 0)!!, 1)
        inbox.post(notification("second"), 0)
        val all = JSONObject("""{"t":"notify","n":"DISMISS_ALL"}""")
        assertEquals(listOf("first"), inbox.dismissalKeys(all, 1, 0))
        assertTrue(inbox.dismissalKeys(all, 1, PrototypeNotifications.RETENTION_MS).isEmpty())
        inbox.configure(false, emptyList())
        assertTrue(inbox.dismissalKeys(all, 1, 0).isEmpty())
        journal.update("stop", mapOf("desired_running" to false))
        assertTrue(inbox.dismissalKeys(all, 1, 0).isEmpty())
    }

    @Test fun unknownActionAndInvalidIdCannotDismissOtherAndroidNotifications() {
        val journal = store(); journal.update("session", mapOf("generation" to 1L))
        val inbox = PrototypeNotifications(journal); inbox.configure(true, emptyList())
        inbox.post(notification(), 0); inbox.written(inbox.next(1, 0)!!, 1)
        for (wire in listOf(
            """{"t":"notify","n":"OPEN","id":1000000}""",
            """{"t":"notify","n":"DISMISS","id":1000000.5}""",
            """{"t":"notify","n":"DISMISS","id":"1000000"}""",
            """{"t":"notify","n":"DISMISS","id":999}""",
            """{"t":"other","n":"DISMISS_ALL"}"""))
            assertTrue(inbox.dismissalKeys(JSONObject(wire), 1, 0).isEmpty())
    }
}
