# AI-Enhanced Voice Notes Specification

## Status

Draft v1

## Summary

Bring local on-device AI to the companion app for synced watch voice memos.

The feature will:

- transcribe voice memos
- summarize them
- categorize them
- extract possible actions
- let the user review and confirm before creating calendar or reminder/task items

The selected local model for v1 is:

- `Qwen2.5-1.5B-Instruct-Q4_K_M`

This model was chosen as the best mobile tradeoff across:

- English
- Swedish
- German
- structured JSON reliability
- action extraction quality
- Android/iOS feasibility

## Product Goals

1. Turn raw voice recordings into useful structured notes.
2. Keep the original transcript and audio always accessible.
3. Build trust by requiring explicit confirmation before any OS action is created.
4. Work safely when the app is backgrounded or the phone is locked.
5. Keep the architecture flexible for future automation once trust is established.

## Non-Goals for v1

- no automatic creation of calendar events or tasks without review
- no Google Tasks integration yet
- no background dialog presentation while phone is locked
- no server-side AI
- no support for arbitrary model selection in v1

## User Experience Overview

The feature evolves voice memos into a capture pipeline:

```text
Record on watch
↓
Sync to phone
↓
Convert audio
↓
Transcribe
↓
LLM summarize
↓
LLM categorize
↓
LLM extract actions
↓
Persist results
↓
User reviews and confirms actions
↓
Create OS calendar/reminder entry
```

## Core UX Rules

1. The original transcript must always be visible.
2. The original audio must always remain playable.
3. AI output is assistive, not authoritative.
4. OS actions must require explicit user confirmation.
5. If the app is backgrounded or locked, AI may continue processing, but confirmation must be deferred until foreground.

## Voice Note Object Model

Each synced memo becomes a voice note with AI-derived fields.

```text
VoiceNote
 ├ audio
 ├ transcript
 ├ summary
 ├ category
 ├ processing_status
 ├ extracted_actions
 │   ├ tasks/reminders
 │   └ calendar_events
 ├ task_created
 ├ calendar_event_created
 └ ai_metadata
```

## Categories

Primary categories for v1:

- `idea`
- `task`
- `reminder`
- `meeting`
- `note`

LLM internals may still use the simpler benchmark categories:

- `TODO`
- `EVENT`
- `NOTE`

UI can map them as:

- `TODO` → task or reminder
- `EVENT` → meeting or calendar event
- `NOTE` → idea or note

## Main Screen

Route:

```text
/voice-notes
```

The screen becomes a summary-first timeline rather than a transcript-first memo list.

### Timeline layout

```text
Today
	[voice note card]
	[voice note card]

Yesterday
	[voice note card]

March 2
	[voice note card]
```

Sorting:

- descending by timestamp

### Voice note card

Each card should show:

- summary as primary text
- timestamp
- category icon/tag
- audio duration
- play button
- processing status if not ready

Example:

```text
🗓 Today · 14:30

Call Erik about PCB panel order

Task detected

00:14  ▶
```

Optional secondary text:

- `Original note available`

### Category icons

| Category | Icon |
|---|---|
| Idea | 💡 |
| Task | ✔ |
| Reminder | ⏰ |
| Meeting | 📅 |
| Note | 📝 |

### Card status indicators

- `⬇ Downloading`
- `🧠 Processing`
- `✓ Ready`
- `⚠ Failed`

## Voice Note Detail Screen

Tapping a card opens the full note.

Section order:

1. Summary
2. Category
3. Transcript
4. Audio playback
5. Detected actions
6. Action status

Example:

```text
Summary
Call Erik about PCB panels

Category
Task

Transcript
Call Erik tomorrow about the PCB panel order.

Audio
▶ Play
00:14

Detected Actions
[ Create Task ]
[ Create Calendar Event ]
```

## Action Review UX

### Important rule

For v1, AI must never write directly to calendar/tasks/reminders without explicit confirmation.

### Detected actions section

Display extracted actions as editable suggestions.

Example:

```text
Detected actions

✔ Call Erik about PCB panels
📅 Meeting with Erik about panels
```

Each detected action can show:

- type
- title
- time/due date
- location
- current status

Available actions:

- `Create Task`
- `Create Calendar Event`
- `Dismiss`

### Task creation flow

When user taps `Create Task`:

1. show preview/edit dialog or sheet
2. allow editing of title and due date
3. confirm with explicit `Create`

Preview example:

```text
Create Task

Title
Call Erik about PCB panels

Due date
Tomorrow

Cancel / Create
```

### Calendar event flow

When user taps `Create Calendar Event`:

1. show preview/edit dialog or sheet
2. allow editing of title, time, duration, location
3. confirm with explicit `Create`

Preview example:

```text
Create Calendar Event

Title
Meeting with Erik

Time
Tomorrow

Duration
30 min

Cancel / Create
```

### Post-creation status

After creation, show status on the note:

- `✔ Task created`
- `📅 Event created`

This is needed to avoid duplicate creation.

## Settings UX

Add a new section under Voice Memo settings for Local AI.

### New settings

- `Enable local AI for voice notes`
- `Selected AI model`
- `Download model`
- `Delete model`
- `Retry download`
- `Auto-process new voice notes`

Optional future settings, not required for v1:

- process only on Wi‑Fi
- process only while charging
- allow background processing toggle

### Settings behavior

When local AI is enabled:

1. app checks whether the required model exists locally
2. if not, the user is prompted to download it
3. download progress is shown clearly
4. state survives navigation and restart

### Required download UI states

- not downloaded
- preparing
- downloading
- paused or interrupted
- failed
- ready
- deleting

The UI must show:

- progress bar
- percentage
- downloaded size / total size
- current state text

## Background and Locked-Phone Behavior

This is a key requirement.

### v1 approach

If a voice memo arrives while the app is backgrounded or the phone is locked:

1. sync may continue if platform/background conditions allow it
2. transcription and AI processing may continue when feasible
3. extracted actions are persisted as pending review
4. no modal dialog is shown immediately
5. when the app returns to foreground, the app surfaces pending AI suggestions for review

### Why

- locked/background state is not safe for dialogs
- calendar/reminder creation requires user trust and context
- this preserves automation benefits while keeping user control

### Foreground re-entry behavior

When app becomes active and there are pending AI actions:

- show a lightweight banner, sheet, or entry point
- allow user to open the review flow
- do not force immediate interruption if the user is doing something else

## Platform Integration Strategy

### iOS

Planned integrations:

- calendar events via EventKit event flow
- reminders/tasks via EventKit reminders flow

### Android

Planned integrations for v1:

- calendar events via calendar provider / insert flow
- TODO/reminder items initially handled as calendar/reminder-style entries

### Future Android support

Design the internal action schema so Google Tasks or similar service integrations can be added later without changing the AI output contract.

## AI Output Contract

The app should define a universal internal action schema, independent of platform.

Suggested fields:

- `category`
- `title`
- `body`
- `startTime`
- `endTime`
- `dueDate`
- `location`
- `actionItems`
- `priority`
- `reminderMinutes`
- `status`

This schema should be persisted and used by the review UI.

## Data Model Changes

The current voice memo persistence must be extended.

### New voice note fields

- `summary`
- `category`
- `processingStatus`
- `aiModel`
- `aiProcessedAt`
- `taskCreated`
- `calendarEventCreated`
- `actionReviewState`

### Structured action storage

Use a normalized approach for actions if practical.

Preferred direction:

- keep `voice_memos` / `voice_notes` as parent records
- store extracted actions in a related table

Each action record should include:

- memo id
- action type
- title
- notes/body
- start time
- end time
- due date
- location
- reminder offset
- created flag
- dismissed flag
- created platform target id if available

## Processing Pipeline States

The UI must update incrementally as processing progresses.

Proposed states:

- `onWatchOnly`
- `downloading`
- `downloaded`
- `converting`
- `transcribing`
- `summarizing`
- `categorizing`
- `extractingActions`
- `ready`
- `failed`

## Search and Filtering

Search should match:

- summary
- transcript
- category

Add quick filters above the timeline:

- `All`
- `Tasks`
- `Ideas`
- `Meetings`
- `Notes`

## Failure and Fallback Behavior

### If AI is disabled

- sync and transcription still work
- no summaries/categories/actions are generated

### If model is missing

- show status in settings
- notes remain accessible without AI enrichment

### If AI processing fails

- transcript/audio remain accessible
- note shows failed status
- allow retry later

### If permissions are denied

- extracted action remains visible
- user can retry action creation later
- no AI output is discarded

## Trust-Building Policy for v1

To build trust gradually:

1. AI suggestions are visible and editable.
2. All task/calendar creation requires confirmation.
3. The app shows what the AI understood before any OS action happens.
4. The user can dismiss AI suggestions.
5. Duplicate prevention is visible.

Future versions may reduce friction once accuracy is trusted, but v1 must stay explicit and review-based.

## Recommended Technical Phases

### Phase 1: Data model and spec foundation

- add DB fields/tables
- add domain models
- add processing states

### Phase 2: Local AI settings and model download

- settings toggle
- model download management
- persistent progress/state

### Phase 3: AI processing pipeline

- add local LLM service
- run summarize/categorize/extract actions after transcription
- persist results

### Phase 4: Voice notes UI refresh

- summary-first timeline
- detail screen with actions
- filters and search updates

### Phase 5: Action review and OS integrations

- review dialogs/sheets
- event/reminder/task creation
- created-status tracking

### Phase 6: Background-safe pending review flow

- persist pending actions
- foreground surfacing UX
- polish

## Acceptance Criteria for v1

1. User can enable Local AI in Settings.
2. User can download the required LLM and see progress.
3. Voice memos continue to work normally if Local AI is disabled.
4. After transcription, each processed memo can show summary and category.
5. If the memo contains actionable content, extracted actions are shown in the detail screen.
6. Creating a task/event always requires explicit confirmation.
7. If a memo is processed while app is backgrounded/locked, actions are deferred for later review.
8. After an action is created, the UI shows created status and prevents duplicate creation.
9. Transcript and audio remain accessible even if AI output is wrong or missing.
10. The system works with the selected local model `Qwen2.5-1.5B-Instruct-Q4_K_M`.

## Open Questions for Later

- whether reminders and tasks should remain unified in UI or split clearly
- whether Android should later support Google Tasks directly
- whether local notifications should be added for pending AI reviews
- whether users should be able to re-run AI processing on old memos in bulk
- whether AI confidence should be surfaced in UI

## Final v1 Decision Summary

- use local on-device AI
- use `Qwen2.5-1.5B-Instruct-Q4_K_M`
- show summaries and categories in the voice notes UI
- extract calendar/task suggestions automatically
- require confirmation before any OS write
- process in background when feasible
- defer confirmations until foreground
- store structured results persistently
