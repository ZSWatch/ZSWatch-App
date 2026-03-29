# ZSWatch Alarms & Timers — Spec

**Status**: Draft  
**Date**: 2026-03-27  
**Depends on**: `voice-memo-time-extraction.md` (chrono_ai_flow pipeline), `ai-enhanced-voice-notes.md` (AI pipeline)

---

## 1. Scope

Voice or text input → existing LLM pipeline parses intent → confirm on watch → create alarm/timer on phone. No complex recurring logic, no UI alarm manager. Fast path only.

### Multilingual Support

The existing `chrono_ai_flow` prompt and AI testbench already handle **Swedish, German, English, and French** input. The prompt explicitly states "the memo may be in ANY language" and extracts `datetime_expression_original` (original language) + `datetime_expression_english` (translated to English for chrono_dart parsing).

This must carry over to timers and alarms:
- **"Sätt en timer på 10 minuter"** → timer, 600s
- **"Ställ ett alarm klockan 7"** → alarm, 07:00
- **"Stell einen Timer auf 15 Minuten"** → timer, 900s
- **"Wecker auf 7 Uhr stellen"** → alarm, 07:00

The LLM translates duration/time expressions to English internally. The `duration_seconds` field is always an integer (language-agnostic). For alarms, `datetime_expression_english` feeds into `TimeExpressionResolver` as it does today for reminders.

The AI testbench already has Swedish/German test cases for reminders and events — the new timer/alarm cases (Section 6.2) follow the same multilingual coverage pattern.

## 2. Supported Intents

| Intent | Description | Example |
|--------|-------------|--------|
| **Timer** | Bare countdown — no attached task/action. Just a duration. | "Set a timer for 8 minutes", "Timer 5 min for pasta" |
| **Alarm** | Ring at a specific clock time — no attached task/action. | "Set an alarm for 7:30 AM", "Wake me at 6" |

Everything else (e.g. "remind me when I get home") is out of scope for this feature.

### Key Distinction: Timer/Alarm vs Reminder

The defining difference is whether the utterance carries an **action to perform**:

- **"Remind me in 30 minutes to check the oven"** → `reminder`. There's an action ("check the oven") tied to a time.
- **"Set a timer for 30 minutes"** → `timer`. No action — just a countdown that rings.
- **"Set an alarm for 7 AM"** → `alarm`. No action — just ring at that time.
- **"Remind me at 3 PM to call the dentist"** → `reminder`. Action = "call the dentist".
- **"Wake me up at 6"** → `alarm`. "Wake me" is not a task, it's what the alarm does by definition.
- **"In 10 minutes"** → `timer`. No action stated, bare duration.

Rule of thumb: if you can answer "do *what*?" — it's a reminder. If the answer is just "ring" — it's a timer or alarm.

### Relationship to Existing Intents

The current `chrono_ai_flow` prompt (`ChronoPromptTemplate`) classifies into three intents:

- `"reminder"` — personal task WITH a specific time
- `"event"` — meeting/appointment/social plan WITH a time
- `"note"` — no time/date mentioned

Timers and alarms are **new intent types** that extend the existing set to five. They differ from reminders structurally:
- Reminders have a **title** (the action to do) and a **datetime** (when to do it).
- Timers have an optional **label** and a **duration** (seconds). No datetime.
- Alarms have an optional **label** and a **clock time**. No real title/action.

See [Section 6](#6-ai-testbench-extension) for how to validate this in the AI testbench before committing to the prompt change.

---

## 3. LLM Contract

### Current State

The existing `chrono_ai_flow` prompt extracts from free-form text/voice:
```json
[{
  "intent": "reminder" | "event" | "note",
  "title": "short task description in original language",
  "datetime_expression_original": "original time phrase" | null,
  "datetime_expression_english": "english translation of time phrase" | null
}]
```

The `TimeExpressionResolver` then resolves `datetime_expression_english` to an absolute `DateTime` via `chrono_dart` + regex fallbacks.

### What Needs to Change

**Option A — Extend existing prompt with new intents**:

Add `"timer"` and `"alarm"` to the intent classification rules in `ChronoPromptTemplate`. Timer intents would use a `duration_seconds` field instead of datetime expressions. This keeps the pipeline single-pass.

New schema (per item in the array):
```json
{
  "intent": "reminder" | "event" | "note" | "timer" | "alarm",
  "title": "short label in original language",
  "datetime_expression_original": "..." | null,
  "datetime_expression_english": "..." | null,
  "duration_seconds": 480 | null
}
```

New prompt rules to add:
```
- "timer" = a bare countdown with NO task/action attached. The user just wants something to ring
  after a duration. "Set a timer for 8 minutes", "timer 5 min for pasta", "countdown 5 minutes",
  "in 10 minutes" (no action stated).
  Extract duration as integer seconds in "duration_seconds". Set both datetime fields to null.
  IMPORTANT: if the utterance contains an action to perform ("remind me in 30 minutes to check
  the oven"), that is a "reminder", NOT a timer.
- "alarm" = ring at a specific clock time with NO task/action attached. The user wants to be woken
  or alerted at a time. "Set an alarm for 7:30 AM", "wake me up at 6", "alarm at 22:00".
  Extract the time into datetime fields as usual. Set duration_seconds to null.
  IMPORTANT: if the utterance contains an action to perform ("remind me at 3 PM to call the
  dentist"), that is a "reminder", NOT an alarm.
```

**Option B — Two-stage routing (pre-classifier + existing prompt)**:

A lightweight pre-classifier prompt runs first to detect if the input is a timer/alarm vs a voice memo. Then routes to the correct prompt:
- Timer/Alarm → new dedicated prompt (simpler, faster, higher accuracy)
- Everything else → existing `ChronoPromptTemplate`

**Recommendation**: Start with Option A (single prompt), validate in the AI testbench, fallback to Option B only if accuracy suffers. The existing prompt already handles multi-intent extraction and the LLM models handle 5 intent categories about as well as 3.

### Timer Schema (when `intent == "timer"`)

| Field | Type | Example |
|-------|------|---------|
| `intent` | `"timer"` | `"timer"` |
| `duration_seconds` | `int` | `480` (8 minutes) |
| `title` | `string` | `"pasta"` |
| `datetime_expression_original` | `null` | — |
| `datetime_expression_english` | `null` | — |

### Alarm Schema (when `intent == "alarm"`)

| Field | Type | Example |
|-------|------|---------|
| `intent` | `"alarm"` | `"alarm"` |
| `title` | `string` | `"wake up"` |
| `datetime_expression_original` | `string` | `"klockan 7:30"` |
| `datetime_expression_english` | `string` | `"at 7:30 AM"` |
| `duration_seconds` | `null` | — |

Repeat days are **not extracted by the LLM**. All alarms are **one-shot** in V1 — no repeat logic.

### Error Handling

If the LLM returns an unrecognized intent or malformed JSON, the existing `ChronoLlmParser.parse()` fallback applies — the parser already sanitizes output and handles graceful failures.

---

## 4. Existing Codebase — What We Have

### 4.1 Firmware: Timer App (already exists)

`app/src/applications/timer/` has a full timer app with:
- `timer_app_timer_t` struct supporting both `TYPE_ALARM` and `TYPE_TIMER`
- Up to `TIMER_UI_MAX_TIMERS` (10) active timers
- Core alarm API: `zsw_alarm_add_timer(hour, min, sec, callback, user_data)` and `zsw_alarm_add(rtc_time, callback, user_data)`
- Persistence via Zephyr settings subsystem
- Alarm triggered popup: `zsw_popup_show("Timer", buf, NULL, 10, false)` + `zsw_vibration_run_pattern(ZSW_VIBRATION_PATTERN_ALARM)`
- zbus integration: listens to `periodic_event_1s_chan` for countdown updates

**Implication**: The watch firmware already knows how to run timers and alarms natively. The companion app just needs to *create* them via BLE.

### 4.2 Firmware: BLE Protocol

`gadgetbridge_api.txt` defines `t:"alarm"` with `d:[{h, m, rep, on}]` — but this is **not yet parsed** in `ble_gadgetbridge.c`. The firmware only handles: `notify`, `notify-`, `weather`, `musicinfo`, `musicstate`, `http`, `gps`, `log`, `voice_memo`, `smp`, `reset`, `ver`, `coredump_erase`.

**Needs**: Add `parse_alarm()` handler in `ble_gadgetbridge.c` that calls `zsw_alarm_add()` or `zsw_alarm_add_timer()`.

### 4.3 Firmware: Voice Memo Popup (reusable pattern)

`app/src/ui/overlay/zsw_voice_memo_popup.c` shows:
- Type-aware overlay (reminder=purple/bell, event=blue/list, task=orange/check)
- Title + datetime display
- Red "Undo" button → sends `ble_gadgetbridge_send_voice_memo_undo(filename)`
- 20-second auto-dismiss
- Async show via `k_work_submit()` (required from zbus context)
- Input capture via `zsw_ui_controller_set_notification_mode()`

**This is the popup we repurpose** for alarm/timer confirm (with modifications per Section 5.3).

### 4.4 Companion App: Protocol Layer

`GadgetbridgeProtocol.setAlarms(List<WatchAlarm>)` is **already implemented** in `gadgetbridge_protocol.dart`:
```dart
Future<void> setAlarms(List<WatchAlarm> alarms) async {
  final alarmList = alarms.map((a) => {
    'h': a.hour, 'm': a.minute, 'rep': a.repeatDaysMask, 'on': a.enabled ? 1 : 0,
  }).toList();
  await _sendGb({'t': 'alarm', 'd': alarmList});
}
```

`WatchAlarm` model exists in `protocol_service.dart`:
```dart
class WatchAlarm {
  final int hour;
  final int minute;
  final int repeatDaysMask;  // binary mask: bit 0=Mon, ..., bit 6=Sun; 127=every day
  final bool enabled;
}
```

**Implication**: The companion app can already *send* alarms to the watch. The missing piece is:
1. Firmware parsing the `t:"alarm"` message
2. A timer message type (not in Gadgetbridge protocol — needs new `t:"timer"` or extend `t:"alarm"`)
3. Integration with the AI pipeline

### 4.5 Companion App: AI Pipeline

The existing flow is:
```
Voice recording on watch → MCUmgr FS sync → Whisper STT → (optional) correction LLM →
classification LLM (chrono_ai_flow) → parse JSON → resolve time → create calendar/reminder
via ExtractedActionCreationService (MethodChannel to native Android/iOS APIs)
```

`ExtractedActionCreationService` uses `MethodChannel('dev.zswatch.app/productivity')` to create calendar events and reminders on Android via native APIs.

### 4.6 Companion App: Platform Bridges

Android: native Kotlin code behind `MethodChannel` for calendar/reminder creation, notification listener, media control.

iOS: uses ANCS/AMS natively on the watch for notifications/media (app is no-op for those).

---

## 5. Design

### 5.1 End-to-End Flow

```
User speaks on watch
  ↓
Voice recording → MCUmgr sync → Phone app receives audio
  ↓
Whisper STT → transcript text
  ↓
(Optional) Correction LLM pass
  ↓
Classification LLM (extended chrono_ai_flow prompt)
  ↓
Parse JSON → detect intent: "timer" | "alarm" | "reminder" | "event" | "note"
  ↓
If timer/alarm:
  ↓
  Resolve time (for alarm: chrono_dart → absolute DateTime → extract hour:minute)
  Resolve duration (for timer: duration_seconds from LLM output)
  ↓
  Send confirmation to watch via BLE:
    voice_memo command with action="confirm_alarm" or "confirm_timer"
  ↓
Watch shows confirm popup (repurposed voice memo popup)
  ↓ (timeout auto-confirms OR user confirms)
Phone receives confirmation → sets alarm/timer
  ↓ (user taps undo within window)
Phone receives undo → cancels alarm/timer
```

### 5.2 Platform Strategy for Setting Alarms/Timers

**V1: Set on Phone** — the user may not always wear the watch. Phone alarms are the reliable baseline.

| | Android | iOS |
|---|---------|-----|
| **Alarm** | System intent → native Clock app | `alarm` package — rings through killed app |
| **Timer** | System intent → native Clock app | Local notification — sufficient for timers |

**Why this split**: Android system intents create real alarms that survive app uninstall and use the user's own alarm sound. iOS exposes no such API. The `alarm` package on iOS is the closest behavioral equivalent — it uses a background audio trick to ring even when the app is dead. Local notifications are good enough for timers since missing a timer by a few seconds is acceptable; missing an alarm is not.

**New dependencies needed**:
- `android_intent_plus` (or direct MethodChannel) for Android system alarm/timer intents
- `alarm` package for iOS alarm functionality
- `flutter_local_notifications` for iOS timers

**V2 (future): Also set on Watch**

The firmware already has `zsw_alarm_add()` / `zsw_alarm_add_timer()` and a full timer app. In V2, set alarms on *both* phone and watch — phone rings with sound, watch vibrates. Belt and suspenders. Requires:
- Add `parse_alarm()` / `parse_timer()` handlers in `ble_gadgetbridge.c`
- Add `BLE_COMM_DATA_TYPE_ALARM` / `BLE_COMM_DATA_TYPE_TIMER` to `ble_comm.h`
- Possibly a watch-side confirm popup (`zsw_alarm_confirm_popup.c`)

### 5.3 Watch Confirm Popup

Reuse the existing voice memo popup pattern (`zsw_voice_memo_popup.c`) on the watch to show what's about to be set.

**Important design reversal**: The existing voice memo popup is undo-after-set (the note is already saved). For alarms/timers, we use **confirm-before-set** — the phone only fires the alarm/timer intent after the timeout expires or user confirms.

```
AI pipeline resolves timer/alarm
    ↓
Phone sends confirm popup data to watch via BLE
    ↓
Watch shows confirm popup (type icon + label + time/duration)
    ↓ (timeout auto-confirms = inaction confirms)
Phone sets alarm/timer on the PHONE (Android intent / iOS alarm package)
    ↓
Explicit dismiss on watch → phone cancels, nothing is set
```

- **Timeout auto-confirms** → alarm/timer is created on the phone
- **Explicit dismiss** (press button / tap cancel) → phone receives cancel, nothing happens
- After set: brief "Set ✓" feedback on watch (same as voice memo "Saved" pattern)

#### Popup Content

| Intent | Watch Display |
|--------|---------------|
| Timer 8min "pasta" | ⏱ **Timer** · pasta — 8:00 |
| Timer 30min (no label) | ⏱ **Timer** · 30:00 |
| Alarm 07:30 one-shot | ⏰ **Alarm** · 07:30 |

All alarms are one-shot in V1 — no repeat day display needed.

#### Cancellation (V1 — phone alarms)

- **Android alarms/timers**: No cancellation API for system intents. The undo window fires *before* the intent is sent — this is why confirm-before-set is critical on Android.
- **iOS alarm** (`alarm` package): Can be cancelled by alarm ID — a short post-set undo window would work, but we don't need it since we confirm-before-set.
- **iOS timer** (local notification): Can be cancelled by notification ID.

**Design implication**: All platform differences are handled by confirming before the intent fires. No post-set undo needed in V1.

### 5.4 Error States

| Situation | Watch Feedback | App Feedback |
|-----------|---------------|--------------|
| LLM returns unknown intent | Short buzz, watch shows ❓ | Snackbar: "Didn't catch that" |
| LLM returns malformed JSON | Same as above | Same as above |
| Timer duration unparseable | Short buzz | Snackbar: "Couldn't parse timer duration" |
| Platform permission missing | Short buzz | Deep link to app permission settings |
| Alarm time already passed today | Silent — app schedules for tomorrow | Snackbar: "Set for tomorrow" |

---

## 6. AI Testbench Extension

### 6.1 Goal

Before writing any production code, extend the AI testbench to answer:

1. **Can the current `ChronoPromptTemplate` handle timer/alarm intents?** — Run the existing prompt with timer/alarm transcripts and see what happens.
2. **Does adding `"timer"` and `"alarm"` intents degrade accuracy for existing cases?** — Run the full benchmark suite with the extended prompt.
3. **Do we need a separate pre-classifier prompt (Option B)?** — Compare accuracy and latency.

### 6.2 New Test Cases to Add

Add these to `model_benchmark_service.dart` alongside the existing 46+ cases:

#### Timer Cases

| Case ID | Transcript | Expected Intent | Expected Duration (s) | Expected Title Keywords |
|---------|-----------|----------------|----------------------|------------------------|
| `en_timer_simple` | "Set a timer for 8 minutes" | timer | 480 | [] |
| `en_timer_labeled` | "Timer for 5 minutes for pasta" | timer | 300 | ["pasta"] |
| `en_timer_seconds` | "Set a 30 second timer" | timer | 30 | [] |
| `en_timer_hour` | "Set a timer for one and a half hours" | timer | 5400 | [] |
| `sv_timer_simple` | "Sätt en timer på 10 minuter" | timer | 600 | [] |
| `sv_timer_labeled` | "Timer på 5 minuter för äggen" | timer | 300 | ["äggen"] |
| `de_timer_simple` | "Stell einen Timer auf 15 Minuten" | timer | 900 | [] |
| `en_timer_vs_reminder` | "Remind me in 30 minutes to check the oven" | reminder | — | ["check", "oven"] |
| `en_timer_bare_duration` | "In 10 minutes" | timer | 600 | [] |
| `en_timer_not_reminder` | "30 minutes" | timer | 1800 | [] |
| `sv_timer_vs_reminder` | "Påminn mig om 10 minuter att stänga av ugnen" | reminder | — | ["stänga", "ugnen"] |

#### Alarm Cases

| Case ID | Transcript | Expected Intent | Expected Time | Expected Title Keywords |
|---------|-----------|----------------|---------------|------------------------|
| `en_alarm_morning` | "Set an alarm for 7:30 AM" | alarm | 07:30 | [] |
| `en_alarm_labeled` | "Alarm at 6 AM, wake up" | alarm | 06:00 | ["wake up"] |
| `en_alarm_weekdays` | "Set an alarm for 7 AM every weekday" | alarm | 07:00 | [] |

**Note**: `en_alarm_weekdays` should still be classified as `alarm` even though repeat is out of scope — the LLM just needs to get the intent and time right. The app ignores the repeat part and creates a one-shot alarm.

| `en_alarm_tomorrow` | "Wake me up tomorrow at 5:30" | alarm | 05:30 | ["wake"] |
| `sv_alarm_simple` | "Ställ ett alarm klockan 7" | alarm | 07:00 | [] |
| `sv_alarm_labeled` | "Alarm klockan halv 8, dags att gå" | alarm | 07:30 | ["dags", "gå"] |
| `de_alarm_simple` | "Wecker auf 7 Uhr stellen" | alarm | 07:00 | [] |
| `en_alarm_vs_reminder` | "Remind me at 3 PM to call the dentist" | reminder | 15:00 | ["call", "dentist"] |
| `en_alarm_no_action` | "7 AM" | alarm | 07:00 | [] |
| `sv_alarm_vs_reminder` | "Påminn mig klockan 15 att ringa tandläkaren" | reminder | 15:00 | ["ringa", "tandläkaren"] |

#### Multi-Item Cases with Timers/Alarms

| Case ID | Transcript | Expected Items |
|---------|-----------|---------------|
| `en_multi_timer_and_alarm` | "Set a timer for 10 minutes and an alarm for 7 AM tomorrow" | [timer 600s, alarm 07:00] |
| `en_multi_alarm_and_note` | "Set an alarm for 6:30 and buy milk" | [alarm 06:30, note] |
| `sv_multi_timer_and_reminder` | "Sätt en timer på 5 minuter och påminn mig klockan 3 att ringa tandläkaren" | [timer 300s, reminder 15:00] |

### 6.3 Benchmark Extensions Needed

#### A. Extend `BenchmarkCaseResult`

Add:
```dart
final bool durationMatch;          // For timer: extracted duration matches expected
final String? durationDetail;       // Why duration match failed
```

#### B. Extend `ExpectedItem`

Add:
```dart
final int? expectedDurationSeconds;  // For timer intent: expected duration in seconds
final int durationToleranceSeconds;  // ±5s default
```

#### C. Extend `BenchmarkCase` evaluation logic

For timer intents:
- Verify `intent == "timer"`
- Verify `duration_seconds` present and within tolerance of expected
- Verify `datetime_expression_*` fields are null
- Verify title keywords

For alarm intents:
- Verify `intent == "alarm"`
- Verify time expression resolves to expected hour:minute
- Verify `duration_seconds` is null

#### D. Extend `ChronoLlmExtraction` model

In `packages/chrono_ai_flow/lib/src/models.dart`:
```dart
class ChronoLlmExtraction {
  final String intent;           // now includes "timer" | "alarm"
  final String title;
  final String? datetimeExpressionOriginal;
  final String? datetimeExpressionEnglish;
  final int? durationSeconds;    // NEW: for timer intent
}
```

#### E. Extend parser

In `packages/chrono_ai_flow/lib/src/parser.dart`, extract `duration_seconds` from JSON and populate the new field.

### 6.4 Prompt Experiments to Run

**Experiment 1 — Baseline**: Run existing prompt (3 intents) with new timer/alarm transcripts. Measure how the LLM classifies them (probably as "reminder" or "note").

**Experiment 2 — Extended prompt (5 intents)**: Add timer/alarm intent rules to the prompt. Run the full suite (existing 46+ cases + new timer/alarm cases). Compare pass rates.

**Experiment 3 — Regression check**: Run *only* the existing 46 cases with the extended prompt. Ensure no regression in reminder/event/note classification.

**Experiment 4 — Pre-classifier (Option B)**: If Experiment 2 shows poor accuracy, implement a lightweight pre-classifier:
```
Input: "set a timer for 5 minutes"
Output: {"route": "timer_alarm"} or {"route": "voice_memo"}
```
Then route to the appropriate full prompt. Measure added latency.

### 6.5 New Headless Mode

Add `--headless-timer` flag to `ai_testbench/lib/main.dart`:
```bash
./ai_testbench --headless-timer --model Qwen3.5-2B-Q4_K_M.gguf
```

This runs only the timer/alarm test cases for fast iteration on the prompt.

### 6.6 Implementation Order

1. Extend `ChronoLlmExtraction` model with `durationSeconds` field
2. Extend `ChronoLlmParser` to extract `duration_seconds`
3. Add timer/alarm test cases to `model_benchmark_service.dart`
4. Run Experiment 1 (baseline — no prompt change)
5. Create extended prompt variant in `ChronoPromptTemplate`
6. Run Experiments 2 + 3 (extended prompt + regression)
7. Decide: single prompt vs. pre-classifier based on results
8. Add `--headless-timer` mode for CI

### 6.7 AI Debug Screen in App — Manual Testing

The companion app's **AI Models settings screen** (`ai_models_settings_screen.dart`) already has a "Model Benchmark" section with:
- A text input field ("Test input text") where you type or paste a transcript
- A microphone button to record and transcribe on-phone
- A "Test AI" button that runs the full AI pipeline (correction → classification → time resolution) and shows results in a debug bottom sheet

**Extend this screen** to also test the timer/alarm flow end-to-end on the phone, without needing the watch:

1. After the AI pipeline runs and detects a `timer` or `alarm` intent, show the result in the debug sheet (same as today for reminders/events/notes)
2. Add a **"Fire Timer/Alarm"** button in the debug sheet result that actually creates the phone alarm/timer via the platform API (Android intent / iOS alarm package) — so you can verify the full chain works
3. Display the resolved timer duration or alarm time prominently in the result card

This is the **last integration step before touching watch firmware**. The full flow you can test from this screen:
```
Type/record input → STT → correction → classification (timer/alarm detected)
  → resolve duration/time → tap "Fire" → phone alarm/timer is set
```

This lets us iterate on the prompt, test multilingual inputs ("Sätt en timer på 10 minuter"), and verify platform integration — all without a watch connected.

---

## 7. Implementation Plan

### Phase 1: AI Testbench Validation (do first)

- [ ] Extend `chrono_ai_flow` models + parser for `durationSeconds`
- [ ] Add timer/alarm benchmark cases to AI testbench
- [ ] Run baseline experiment (existing prompt)
- [ ] Create extended prompt variant
- [ ] Run accuracy experiments, decide on prompt strategy
- [ ] Add `--headless-timer` mode

### Phase 1b: AI Debug Screen in App (test without watch)

- [ ] Extend AI debug screen result sheet to show timer/alarm intent details (duration, resolved time)
- [ ] Add "Fire Timer" / "Fire Alarm" button in debug result sheet → calls platform API directly
- [ ] Verify full E2E on Android: text input → AI → fire system alarm/timer intent
- [ ] Verify full E2E on iOS: text input → AI → fire alarm package / local notification
- [ ] Test multilingual inputs from the debug screen (Swedish, German, etc.)

**This phase completes before any watch firmware changes.** The phone-side feature must work standalone.

### Phase 2: Companion App — Phone-Side Alarms/Timers

- [ ] Update `chrono_ai_flow` prompt (based on testbench results)
- [ ] Update `ChronoLlmExtraction` model with `durationSeconds`
- [ ] Add timer/alarm routing in voice memo AI pipeline
- [ ] **Android**: Add MethodChannel for system alarm/timer intents (extend existing `dev.zswatch.app/productivity` channel or create new `dev.zswatch.app/alarms`)
- [ ] **Android**: Handle `SCHEDULE_EXACT_ALARM` permission (Android 12+)
- [ ] **iOS**: Add `alarm` package for alarm functionality
- [ ] **iOS**: Add `flutter_local_notifications` for timer countdown notifications
- [ ] **iOS**: Handle local notification permission request (contextual, on first use)
- [ ] Add confirmation protocol: send confirm popup data to watch, wait for confirm/cancel response
- [ ] Handle watch confirm/cancel in `WatchService.incomingMessages` stream → fire platform intent

### Phase 3: Watch-Side Confirm Popup

- [ ] Create `zsw_alarm_confirm_popup.c` overlay (or extend voice memo popup with timer/alarm mode)
- [ ] Add BLE message type for confirm popup data (phone → watch)
- [ ] Add BLE message type for confirm/cancel response (watch → phone)
- [ ] Add zbus channel for alarm/timer confirmation events

### Phase 4: Watch-Side Alarms (V2 — future)

- [ ] Add `parse_alarm()` to `ble_gadgetbridge.c` — parse `t:"alarm"` and call `zsw_alarm_add()`
- [ ] Add `parse_timer()` to `ble_gadgetbridge.c` — parse `t:"timer"` and call `zsw_alarm_add_timer()`
- [ ] Add `BLE_COMM_DATA_TYPE_ALARM` and `BLE_COMM_DATA_TYPE_TIMER` to `ble_comm.h`
- [ ] Implement dual-set: phone alarm + watch alarm (belt and suspenders)
- [ ] Add `sendTimer(int durationSeconds, String label)` to `WatchService`

---

## 8. Permissions Required

| Platform | Permission | When |
|----------|-----------|------|
| Android | `SCHEDULE_EXACT_ALARM` | Required for system timer intent on Android 12+ |
| Android | None for alarm intent | System alarm intent doesn't need permissions |
| iOS | Local notification | Request on first timer use, contextual prompt |
| iOS | None for `alarm` package | Uses audio session trick, no special permission |

---

## 9. Out of Scope

- Alarm management UI on the phone (list, edit, delete) — lives in the native Clock app on Android; iOS alarm package has no list UI
- Repeating timers
- Repeating alarms / alarms on specific days (all alarms are one-shot in V1)
- Condition-based reminders ("when I get home")
- Snooze behavior — handled natively by phone platform
- Complex recurrence rules (every 2nd Tuesday)
- Watch-side alarms/timers (V2)

---

## 10. Open Questions

1. **Confirm popup on watch**: New overlay file or extend `zsw_voice_memo_popup.c` with a timer/alarm mode? The voice memo popup already has type-aware icons and auto-dismiss — extending it may be cleanest.
2. **iOS `alarm` package reliability**: The background audio trick is clever but can be killed by iOS in some circumstances. Need to test on real devices. If unreliable, fall back to local notifications for everything on iOS.
3. **Android AlarmManager vs system intent**: System intent opens the Clock app and the user sees the alarm. `AlarmManager` + `BroadcastReceiver` runs silently. Which UX do we want? System intent is simpler but the user might dismiss it. Need to decide.
4. **Watch BLE round-trip latency for confirm**: How fast does the confirm/cancel message travel? If > 1-2 seconds, the UX feels sluggish. May need to optimize or use a shorter timeout.
