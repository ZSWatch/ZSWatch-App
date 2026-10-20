package dev.zswatch.app

import android.Manifest
import android.accounts.Account
import android.content.ContentProviderOperation
import android.content.ContentResolver
import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.provider.CalendarContract
import android.util.Log
import androidx.core.content.ContextCompat
import java.util.TimeZone

class ActionFailure(val code: String, message: String) : Exception(message)

/** Calendar entries, reminders, timers and alarms. Usable without an activity. */
class ProductivityActions(context: Context) {
    private val context = context.applicationContext

    data class WritableCalendarInfo(
        val id: Long,
        val displayName: String?,
        val accountName: String?,
        val accountType: String?,
        val ownerAccount: String?,
        val isPrimary: Boolean,
    )

    companion object {
        private const val TAG = "ZSWProductivity"
    }

    /** Creates one action from a platform draft map. Throws [ActionFailure]. */
    fun create(args: Map<String, Any?>, actionToken: String? = null): Map<String, Any?> {
        val actionType = args["actionType"] as? String ?: "task"
        val title = (args["title"] as? String)?.trim().orEmpty()
        val notes = (args["notes"] as? String)?.trim()?.takeIf { it.isNotEmpty() }
        val location = (args["location"] as? String)?.trim()?.takeIf { it.isNotEmpty() }
        val scheduledAtMillis = (args["scheduledAtMillis"] as? Number)?.toLong()
        val endAtMillis = (args["endAtMillis"] as? Number)?.toLong()
        val reminderMinutes = (args["reminderMinutes"] as? Number)?.toInt()
        val durationSeconds = (args["durationSeconds"] as? Number)?.toInt()
        val skipUi = args["skipUi"] as? Boolean ?: true
        val requestedCalendarId = (args["calendarId"] as? Number)?.toLong()

        // Timer and alarm use system intents, no calendar permission needed.
        if (actionType == "timer" || actionType == "alarm") {
            try {
                return if (actionType == "timer") createTimerViaIntent(durationSeconds ?: 0, title, skipUi)
                else createAlarmViaIntent(scheduledAtMillis, title, skipUi)
            } catch (e: Exception) {
                Log.e(TAG, "createAction ($actionType) failed", e)
                throw ActionFailure("CREATE_ACTION_FAILED", e.localizedMessage ?: "Failed")
            }
        }
        if (!hasCalendarPermission()) {
            throw ActionFailure("PERMISSION_DENIED", "Calendar permission is required to create events or reminders.")
        }
        if (title.isEmpty()) throw ActionFailure("INVALID_ARGUMENT", "title is required")

        val calendars = getWritableCalendars()
        val calendar = if (requestedCalendarId != null) {
            findCalendarById(calendars, requestedCalendarId) ?: throw ActionFailure("SELECTED_CALENDAR_UNAVAILABLE",
                "The selected default calendar is no longer available. Please choose another calendar in Settings.")
        } else {
            chooseBestCalendar(calendars)
        } ?: throw ActionFailure("NO_CALENDAR", "No writable calendar was found on this device.")

        try {
            return when (actionType) {
                "calendar_event" -> createCalendarEntry(calendar.id, title, notes, location, scheduledAtMillis,
                    endAtMillis, reminderMinutes, "calendar_event", actionToken)
                "reminder", "task" -> createReminderEntry(calendar.id, title, notes, scheduledAtMillis,
                    reminderMinutes, "calendar_reminder", actionToken)
                else -> throw ActionFailure("INVALID_ARGUMENT", "Unsupported action type: $actionType")
            }
        } catch (e: ActionFailure) {
            throw e
        } catch (e: Exception) {
            Log.e(TAG, "createAction failed", e)
            throw ActionFailure("CREATE_ACTION_FAILED", e.localizedMessage ?: "Failed")
        }
    }

    /** Deletes a calendar entry only if [actionToken] still owns it. */
    fun deleteOwnedEvent(eventId: Long, actionToken: String) {
        check(hasCalendarPermission()) { "Calendar permission required" }
        val uri = ContentUris.withAppendedId(CalendarContract.Events.CONTENT_URI, eventId)
        context.contentResolver.query(uri, arrayOf(CalendarContract.Events.CUSTOM_APP_URI,
            CalendarContract.Events.CUSTOM_APP_PACKAGE), null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) check(cursor.getString(0) == actionToken && cursor.getString(1) == context.packageName) {
                "Calendar entry is no longer owned by this action"
            }
        } ?: error("Calendar provider unavailable")
        // Item URIs reject a selection on Android's CalendarProvider.
        // Use the collection URI with both ID and ownership in one predicate.
        context.contentResolver.delete(CalendarContract.Events.CONTENT_URI,
            "${CalendarContract.Events._ID}=? AND ${CalendarContract.Events.CUSTOM_APP_URI}=? AND ${CalendarContract.Events.CUSTOM_APP_PACKAGE}=?",
            arrayOf(eventId.toString(), actionToken, context.packageName))
        context.contentResolver.query(uri, arrayOf(CalendarContract.Events.DELETED), null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) check(cursor.getInt(0) == 1) { "Calendar entry was not removed" }
        } ?: error("Calendar provider unavailable")
    }

    fun hasCalendarPermission(): Boolean {
        return listOf(Manifest.permission.WRITE_CALENDAR, Manifest.permission.READ_CALENDAR).all {
            ContextCompat.checkSelfPermission(context, it) == PackageManager.PERMISSION_GRANTED
        }
    }

    fun getWritableCalendars(): List<WritableCalendarInfo> {
        val preferredCalendars = queryWritableCalendars(requireVisibleAndSynced = true)
        if (preferredCalendars.isNotEmpty()) {
            return preferredCalendars.sortedByDescending { scoreCalendar(it) }
        }

        return queryWritableCalendars(requireVisibleAndSynced = false)
            .sortedByDescending { scoreCalendar(it) }
    }

    private fun queryWritableCalendars(requireVisibleAndSynced: Boolean): List<WritableCalendarInfo> {
        val projection = arrayOf(
            CalendarContract.Calendars._ID,
            CalendarContract.Calendars.CALENDAR_DISPLAY_NAME,
            CalendarContract.Calendars.ACCOUNT_NAME,
            CalendarContract.Calendars.ACCOUNT_TYPE,
            CalendarContract.Calendars.OWNER_ACCOUNT,
            CalendarContract.Calendars.IS_PRIMARY,
            CalendarContract.Calendars.CALENDAR_ACCESS_LEVEL,
        )

        val selectionParts = mutableListOf<String>()
        if (requireVisibleAndSynced) {
            selectionParts += "${CalendarContract.Calendars.VISIBLE}=1"
            selectionParts += "${CalendarContract.Calendars.SYNC_EVENTS}=1"
        }
        selectionParts += "${CalendarContract.Calendars.CALENDAR_ACCESS_LEVEL}>=${CalendarContract.Calendars.CAL_ACCESS_CONTRIBUTOR}"
        val selection = selectionParts.joinToString(" AND ")
        val sortOrder = "${CalendarContract.Calendars.IS_PRIMARY} DESC, ${CalendarContract.Calendars._ID} ASC"
        val calendars = mutableListOf<WritableCalendarInfo>()

        context.contentResolver.query(
            CalendarContract.Calendars.CONTENT_URI,
            projection,
            selection,
            null,
            sortOrder,
        )?.use { cursor ->
            while (cursor.moveToNext()) {
                val calendar = WritableCalendarInfo(
                    id = cursor.getLong(0),
                    displayName = cursor.getString(1),
                    accountName = cursor.getString(2),
                    accountType = cursor.getString(3),
                    ownerAccount = cursor.getString(4),
                    isPrimary = cursor.getInt(5) == 1,
                )
                Log.d(
                    TAG,
                    "Writable calendar candidate id=${calendar.id} name=${calendar.displayName} account=${calendar.accountName} type=${calendar.accountType} owner=${calendar.ownerAccount} primary=${calendar.isPrimary}",
                )
                calendars.add(calendar)
            }
        }

        return calendars
    }

    fun findCalendarById(
        calendars: List<WritableCalendarInfo>,
        calendarId: Long,
    ): WritableCalendarInfo? {
        return calendars.firstOrNull { it.id == calendarId }
    }

    fun chooseBestCalendar(calendars: List<WritableCalendarInfo>): WritableCalendarInfo? {
        return calendars.maxByOrNull { scoreCalendar(it) }
    }

    private fun scoreCalendar(calendar: WritableCalendarInfo): Int {
        var score = 0

        if (calendar.isPrimary) {
            score += 100
        }

        val accountType = calendar.accountType.orEmpty().lowercase()
        val accountName = calendar.accountName.orEmpty().lowercase()
        val ownerAccount = calendar.ownerAccount.orEmpty().lowercase()
        val displayName = calendar.displayName.orEmpty().lowercase()

        if (accountType.contains("google")) {
            score += 80
        }
        if (accountType.contains("exchange") || accountType.contains("outlook")) {
            score += 60
        }
        if (accountType.contains("local") ||
            accountName.contains("local") ||
            ownerAccount.contains("local") ||
            displayName.contains("local")
        ) {
            score -= 40
        }

        return score
    }

    /**
     * Check if the sync adapter for a Google account's calendar authority is working.
     * Checks both isSyncable (sync adapter registered) and getSyncAutomatically (user toggle).
     * On some OEMs (OnePlus/ColorOS), isSyncable can be 0 even when the user has
     * Calendar sync enabled in Settings — so we also check getSyncAutomatically().
     */
    private fun isCalendarSyncWorking(calendar: WritableCalendarInfo?): Boolean {
        if (calendar == null) return false
        val accountName = calendar.accountName ?: return false
        val accountType = calendar.accountType ?: return false
        // Only relevant for cloud-backed calendar accounts (Google, Exchange, etc.)
        if (accountType.equals("LOCAL", ignoreCase = true)) return true
        val account = Account(accountName, accountType)
        return try {
            val isSyncable = ContentResolver.getIsSyncable(account, CalendarContract.AUTHORITY)
            val autoSync = ContentResolver.getSyncAutomatically(account, CalendarContract.AUTHORITY)
            val masterSync = ContentResolver.getMasterSyncAutomatically()
            Log.d(TAG, "isCalendarSyncWorking: account=$accountName isSyncable=$isSyncable autoSync=$autoSync masterSync=$masterSync")
            // Consider sync working if EITHER the sync adapter is registered (isSyncable>=1)
            // OR the user has auto-sync enabled (which means the Settings toggle is ON).
            // On some OEMs, isSyncable stays 0 even when the toggle is ON.
            (isSyncable >= 1) || (autoSync && masterSync)
        } catch (_: Exception) {
            false
        }
    }

    private fun createCalendarEntry(
        calendarId: Long,
        title: String,
        notes: String?,
        location: String?,
        startMillis: Long?,
        endMillis: Long?,
        reminderMinutes: Int?,
        targetType: String,
        actionToken: String? = null,
    ): Map<String, Any?> {
        val start = startMillis
            ?: throw IllegalArgumentException("A start time is required for calendar events.")
        val end = endMillis ?: (start + 30 * 60 * 1000L)
        if (actionToken != null) {
            context.contentResolver.query(CalendarContract.Events.CONTENT_URI,
                arrayOf(CalendarContract.Events._ID, CalendarContract.Events.CALENDAR_ID),
                "${CalendarContract.Events.CUSTOM_APP_PACKAGE}=? AND ${CalendarContract.Events.CUSTOM_APP_URI}=? AND ${CalendarContract.Events.DELETED}=0",
                arrayOf(context.packageName, actionToken), null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val existing = findCalendarById(getWritableCalendars(), cursor.getLong(1))
                    return mapOf("platformId" to cursor.getLong(0).toString(), "targetType" to targetType,
                        "calendarDisplayName" to existing?.displayName, "calendarAccountName" to existing?.accountName,
                        "syncDisabled" to !isCalendarSyncWorking(existing))
                }
            } ?: error("Calendar provider unavailable")
        }

        Log.d(TAG, "createCalendarEntry calendarId=$calendarId title=$title reminderMinutes=$reminderMinutes")

        // Look up calendar info so we can set ORGANIZER (required for Google Calendar sync)
        val calendar = findCalendarById(getWritableCalendars(), calendarId)
        val organizerEmail = calendar?.ownerAccount ?: calendar?.accountName

        val syncWorking = isCalendarSyncWorking(calendar)

        val values = ContentValues().apply {
            put(CalendarContract.Events.CALENDAR_ID, calendarId)
            put(CalendarContract.Events.TITLE, title)
            put(CalendarContract.Events.DESCRIPTION, notes)
            put(CalendarContract.Events.EVENT_LOCATION, location)
            put(CalendarContract.Events.DTSTART, start)
            put(CalendarContract.Events.DTEND, end)
            put(CalendarContract.Events.EVENT_TIMEZONE, TimeZone.getDefault().id)
            put(CalendarContract.Events.STATUS, CalendarContract.Events.STATUS_CONFIRMED)
            put(CalendarContract.Events.ACCESS_LEVEL, CalendarContract.Events.ACCESS_DEFAULT)
            put(CalendarContract.Events.AVAILABILITY, CalendarContract.Events.AVAILABILITY_BUSY)
            put(CalendarContract.Events.HAS_ALARM, if (reminderMinutes != null) 1 else 0)
            if (actionToken != null) {
                put(CalendarContract.Events.CUSTOM_APP_PACKAGE, context.packageName)
                put(CalendarContract.Events.CUSTOM_APP_URI, actionToken)
            }
            if (!organizerEmail.isNullOrEmpty()) {
                put(CalendarContract.Events.ORGANIZER, organizerEmail)
            }
        }

        // Insert as sync adapter for cloud accounts (required on OnePlus/ColorOS)
        val accountName = calendar?.accountName ?: ""
        val accountType = calendar?.accountType ?: ""
        val isCloudAccount = !accountType.equals("LOCAL", ignoreCase = true) && accountName.isNotEmpty()

        val insertUri = if (isCloudAccount) {
            CalendarContract.Events.CONTENT_URI.buildUpon()
                .appendQueryParameter(CalendarContract.CALLER_IS_SYNCADAPTER, "true")
                .appendQueryParameter(CalendarContract.Calendars.ACCOUNT_NAME, accountName)
                .appendQueryParameter(CalendarContract.Calendars.ACCOUNT_TYPE, accountType)
                .build()
        } else {
            CalendarContract.Events.CONTENT_URI
        }

        val operations = arrayListOf(ContentProviderOperation.newInsert(insertUri).withValues(values).build())
        if (reminderMinutes != null) {
            val reminderUri = insertUri.buildUpon().path("reminders").build()
            operations.add(ContentProviderOperation.newInsert(reminderUri)
                .withValueBackReference(CalendarContract.Reminders.EVENT_ID, 0)
                .withValue(CalendarContract.Reminders.MINUTES, reminderMinutes)
                .withValue(CalendarContract.Reminders.METHOD, CalendarContract.Reminders.METHOD_ALERT).build())
        }
        val inserted = context.contentResolver.applyBatch(CalendarContract.AUTHORITY, operations)
        val eventId = ContentUris.parseId(inserted[0].uri ?: error("Failed to insert calendar event"))
        Log.d(TAG, "Calendar event inserted eventId=$eventId syncAdapter=$isCloudAccount")


        requestCalendarSync(calendar)

        return mapOf(
            "platformId" to eventId.toString(),
            "targetType" to targetType,
            "calendarDisplayName" to calendar?.displayName,
            "calendarAccountName" to calendar?.accountName,
            "syncDisabled" to !syncWorking,
        )
    }

    private fun createReminderEntry(
        calendarId: Long,
        title: String,
        notes: String?,
        scheduledAtMillis: Long?,
        reminderMinutes: Int?,
        targetType: String,
        actionToken: String? = null,
    ): Map<String, Any?> {
        val scheduledAt = scheduledAtMillis
            ?: throw IllegalArgumentException("A date/time is required to create reminders on Android.")

        Log.d(
            TAG,
            "createReminderEntry calendarId=$calendarId title=$title scheduledAt=$scheduledAt reminderMinutes=$reminderMinutes",
        )

        val event = createCalendarEntry(
            calendarId = calendarId,
            title = title,
            notes = notes,
            location = null,
            startMillis = scheduledAt,
            endMillis = scheduledAt + 30 * 60 * 1000L,
            reminderMinutes = reminderMinutes ?: 0,
            targetType = targetType,
            actionToken = actionToken,
        )

        return event
    }

    private fun requestCalendarSync(calendar: WritableCalendarInfo?) {
        if (calendar == null) return
        val accountName = calendar.accountName
        val accountType = calendar.accountType
        if (accountName.isNullOrEmpty() || accountType.isNullOrEmpty()) return
        val account = Account(accountName, accountType)

        try {
            // Ensure the sync adapter is marked as syncable
            if (ContentResolver.getIsSyncable(account, CalendarContract.AUTHORITY) <= 0) {
                ContentResolver.setIsSyncable(account, CalendarContract.AUTHORITY, 1)
            }
            if (!ContentResolver.getSyncAutomatically(account, CalendarContract.AUTHORITY)) {
                ContentResolver.setSyncAutomatically(account, CalendarContract.AUTHORITY, true)
            }

            val extras = Bundle().apply {
                putBoolean(ContentResolver.SYNC_EXTRAS_MANUAL, true)
                putBoolean(ContentResolver.SYNC_EXTRAS_EXPEDITED, true)
                putBoolean(ContentResolver.SYNC_EXTRAS_IGNORE_SETTINGS, true)
                putBoolean(ContentResolver.SYNC_EXTRAS_UPLOAD, true)
            }
            ContentResolver.requestSync(account, CalendarContract.AUTHORITY, extras)
            Log.d(TAG, "requestCalendarSync: requested sync for account=$accountName")
        } catch (e: Exception) {
            Log.e(TAG, "requestCalendarSync failed", e)
        }
    }

    private fun createTimerViaIntent(durationSeconds: Int, label: String, skipUi: Boolean = true): Map<String, Any?> {
        val intent = android.content.Intent(android.provider.AlarmClock.ACTION_SET_TIMER).apply {
            putExtra(android.provider.AlarmClock.EXTRA_LENGTH, durationSeconds)
            if (label.isNotEmpty()) {
                putExtra(android.provider.AlarmClock.EXTRA_MESSAGE, label)
            }
            putExtra(android.provider.AlarmClock.EXTRA_SKIP_UI, skipUi)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        try {
            context.startActivity(intent)
        } catch (e: android.content.ActivityNotFoundException) {
            throw IllegalStateException("No app found that can handle timers. Please install a clock app.")
        }
        return mapOf(
            "platformId" to null,
            "targetType" to "timer",
            "syncDisabled" to false,
        )
    }

    private fun createAlarmViaIntent(triggerAtMillis: Long?, label: String, skipUi: Boolean = true): Map<String, Any?> {
        val intent = android.content.Intent(android.provider.AlarmClock.ACTION_SET_ALARM).apply {
            if (triggerAtMillis != null) {
                val cal = java.util.Calendar.getInstance().apply { timeInMillis = triggerAtMillis }
                putExtra(android.provider.AlarmClock.EXTRA_HOUR, cal.get(java.util.Calendar.HOUR_OF_DAY))
                putExtra(android.provider.AlarmClock.EXTRA_MINUTES, cal.get(java.util.Calendar.MINUTE))
            }
            if (label.isNotEmpty()) {
                putExtra(android.provider.AlarmClock.EXTRA_MESSAGE, label)
            }
            putExtra(android.provider.AlarmClock.EXTRA_SKIP_UI, skipUi)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        try {
            context.startActivity(intent)
        } catch (e: android.content.ActivityNotFoundException) {
            throw IllegalStateException("No app found that can handle alarms. Please install a clock app.")
        }
        return mapOf(
            "platformId" to null,
            "targetType" to "alarm",
            "syncDisabled" to false,
        )
    }
}
