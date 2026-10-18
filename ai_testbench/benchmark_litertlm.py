#!/usr/bin/env python3
"""
LiteRT-LM benchmark for Gemma 4 — ports the ai_testbench Dart benchmarks to Python.

Runs the same prompts used in the Flutter ai_testbench (chrono_ai_flow)
against a .litertlm model via the litert-lm Python API.

Install:
    pip install litert-lm-api-nightly

Download model:
    litert-lm run \
      --from-huggingface-repo=litert-community/gemma-4-E2B-it-litert-lm \
      gemma-4-E2B-it.litertlm --prompt="hello" --max-tokens=1
    (this downloads and caches the model; find path in ~/.cache/litert_lm/)

    Or manually download from:
    https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm

Usage:
    python benchmark_litertlm.py --model path/to/gemma-4-E2B-it.litertlm
    python benchmark_litertlm.py --model path/to/model.litertlm --bench extraction
    python benchmark_litertlm.py --model path/to/model.litertlm --bench correction
    python benchmark_litertlm.py --model path/to/model.litertlm --bench all
"""

import argparse
import json
import time
import sys
from datetime import datetime, timedelta, timezone
from typing import Any

try:
    import litert_lm
except ImportError:
    print("ERROR: litert-lm not installed. Run: pip install litert-lm-api-nightly")
    sys.exit(1)


# ─── Reference times (same as Dart testbench) ───────────────────────────────

# Model benchmark uses: Wednesday March 11, 2026, 10:15 AM
MODEL_BENCH_NOW = datetime(2026, 3, 11, 10, 15, 0)
# Time extraction uses: Monday March 9, 2026, 10:15 AM
TIME_BENCH_NOW = datetime(2026, 3, 9, 10, 15, 0)

TZ_OFFSET = "+02:00"  # Adjust to your local timezone


# ─── Prompt templates (exact copies from chrono_ai_flow) ────────────────────

DEFAULT_TEMPLATE = """You extract structured information from a voice memo.

A memo may contain ONE or MULTIPLE items. Return a JSON array with one object per item.

The memo may be in ANY language.

Return JSON only. Output MUST start with '[' and end with ']'. No text before or after.

If the memo is noise, gibberish, a silence marker, or contains no meaningful words, return an empty array: []

Your tasks per item:
1. Detect intent: "reminder", "event", or "note".
2. Extract the time/date phrase exactly as it appears in the memo.
3. Translate that time/date phrase into natural English. If already English, copy it.
4. Extract a short title (the task or event, NOT the time part).

IMPORTANT — item splitting:
- ALWAYS return a JSON array, even for a single item.
- NEVER drop items. Every distinct action in the memo MUST appear as a separate object.
- Connectors that introduce a NEW item: "and", "and then", "also", "och", "och sen", "sen", "und", commas between clauses, sentence boundaries.
- A single idea with elaboration/details stays as ONE item.
- Comma-separated lists (shopping items, ingredients, supplies) are ONE item.

IMPORTANT — intent classification:
- "event" = meetings, appointments, social plans, bookings, standups — things you ATTEND with others or at a place (dentist, fika with someone, team standup, conference, lunch with a person)
- "reminder" = personal tasks/actions WITH a specific time — things you DO alone (call someone at 3 pm, pick up package at 5, go to gym at 8, take medicine at 8)
- "note" = NO time/date mentioned — ideas, shopping lists, tasks without a deadline (buy bread, good idea about sensors, prototype a feature)
- A task with NO time appearing alongside timed tasks is still a "note"

Rules:
- Multi-item date context: if a later item only mentions a time (e.g. "at 3 pm"), reuse the most recent date from a previous item. Example: "tomorrow at 8 am ... at 3 pm" → item 2 is "tomorrow at 3 pm".
- Copy title words directly from the memo. Never translate the title. Keep titles short (2-5 words).
- Title must NOT contain time or date words.
- Do not resolve relative dates to absolute dates or ISO timestamps. Keep expressions relative: "tomorrow at 10 am", NOT "2026-03-10T10:00:00".
- Copy the original time phrase exactly. Fill "datetime_expression_english" whenever "datetime_expression_original" is not null.
- If the memo is in English, copy the same phrase to both datetime fields.
- If no time/date for an item, set both datetime fields to null.
- Translate time expressions to natural English. Convert 24-hour to 12-hour. Use PM for afternoon/evening context.
- Do NOT add "next" to weekday translations unless the original explicitly says "next" / "nästa" / "nächsten".
- Deadlines ARE time expressions: "by Friday", "senast fredag", "bis Freitag" → extract them.
- NOT time expressions: locations ("at the store"), vague conditions ("when I get home", "after lunch"), words that look like time but aren't ("boka tid" = book appointment)

Output JSON schema (always an array):
[
  {
    "intent": "reminder" | "event" | "note",
    "title": "short task description in original language",
    "datetime_expression_original": "original time phrase" | null,
    "datetime_expression_english": "english translation of time phrase" | null
  }
]

Examples:

Memo: "Remind me tomorrow at 10 am to buy milk"
[{"intent":"reminder","title":"buy milk","datetime_expression_original":"tomorrow at 10 am","datetime_expression_english":"tomorrow at 10 am"}]

Memo: "Tomorrow at 5 pm pick up the dog and then at 9 turn off all lights"
[{"intent":"reminder","title":"pick up the dog","datetime_expression_original":"tomorrow at 5 pm","datetime_expression_english":"tomorrow at 5 pm"},{"intent":"reminder","title":"turn off all lights","datetime_expression_original":"at 9","datetime_expression_english":"tomorrow at 9 pm"}]

Memo: "påminn mig imorgon klockan 10 att köpa mjölk"
[{"intent":"reminder","title":"köpa mjölk","datetime_expression_original":"imorgon klockan 10","datetime_expression_english":"tomorrow at 10 am"}]

Memo: "tandläkare den 15 mars klockan halv 10 och sen handla mat på vägen hem"
[{"intent":"event","title":"tandläkare","datetime_expression_original":"den 15 mars klockan halv 10","datetime_expression_english":"March 15th at 9:30 am"},{"intent":"note","title":"handla mat","datetime_expression_original":null,"datetime_expression_english":null}]

Memo: "remember to buy milk"
[{"intent":"note","title":"buy milk","datetime_expression_original":null,"datetime_expression_english":null}]

Memo: "köp bröd på vägen hem"
[{"intent":"note","title":"köp bröd","datetime_expression_original":null,"datetime_expression_english":null}]

Memo: "call the plumber this afternoon at 3"
[{"intent":"reminder","title":"call the plumber","datetime_expression_original":"this afternoon at 3","datetime_expression_english":"this afternoon at 3 pm"}]

Memo: "Meeting with Sarah on Monday at 10 am and lunch with the team on Wednesday at noon"
[{"intent":"event","title":"meeting with Sarah","datetime_expression_original":"on Monday at 10 am","datetime_expression_english":"on Monday at 10 am"},{"intent":"event","title":"lunch with the team","datetime_expression_original":"on Wednesday at noon","datetime_expression_english":"on Wednesday at 12 pm"}]

Memo: "Tomorrow at 3 pm call the electrician and also buy new light bulbs"
[{"intent":"reminder","title":"call the electrician","datetime_expression_original":"tomorrow at 3 pm","datetime_expression_english":"tomorrow at 3 pm"},{"intent":"note","title":"buy new light bulbs","datetime_expression_original":null,"datetime_expression_english":null}]

Memo: "Arzttermin am Donnerstag um 9 Uhr und Zahnarzt am Freitag um 14 Uhr"
[{"intent":"event","title":"Arzttermin","datetime_expression_original":"am Donnerstag um 9 Uhr","datetime_expression_english":"Thursday at 9 am"},{"intent":"event","title":"Zahnarzt","datetime_expression_original":"am Freitag um 14 Uhr","datetime_expression_english":"Friday at 2 pm"}]

Memo: "Den Bericht bis Freitag um 17 Uhr an den Chef schicken"
[{"intent":"reminder","title":"Bericht an Chef schicken","datetime_expression_original":"bis Freitag um 17 Uhr","datetime_expression_english":"on Friday at 5 pm"}]

Memo: "Boka tid hos frisören"
[{"intent":"note","title":"boka tid hos frisören","datetime_expression_original":null,"datetime_expression_english":null}]

Memo: "Fika med Anna imorgon klockan 10 och sen lämna in paketet på posten"
[{"intent":"event","title":"fika med Anna","datetime_expression_original":"imorgon klockan 10","datetime_expression_english":"tomorrow at 10 am"},{"intent":"note","title":"lämna in paketet","datetime_expression_original":null,"datetime_expression_english":null}]

Memo: "Vi behöver fixa buggen och sen refaktorera koden"
[{"intent":"note","title":"fixa buggen","datetime_expression_original":null,"datetime_expression_english":null},{"intent":"note","title":"refaktorera koden","datetime_expression_original":null,"datetime_expression_english":null}]

Memo: "Bilservice på tisdag klockan 8"
[{"intent":"event","title":"bilservice","datetime_expression_original":"på tisdag klockan 8","datetime_expression_english":"on Tuesday at 8 am"}]

Memo: "Hämta barnen imorgon klockan halv 5"
[{"intent":"reminder","title":"hämta barnen","datetime_expression_original":"imorgon klockan halv 5","datetime_expression_english":"tomorrow at 4:30 pm"}]

Memo: "Ring tandläkaren imorgon klockan 9, köp presenter till kalaset och möte med chefen på fredag klockan 14"
[{"intent":"reminder","title":"ring tandläkaren","datetime_expression_original":"imorgon klockan 9","datetime_expression_english":"tomorrow at 9 am"},{"intent":"note","title":"köp presenter","datetime_expression_original":null,"datetime_expression_english":null},{"intent":"event","title":"möte med chefen","datetime_expression_original":"på fredag klockan 14","datetime_expression_english":"on Friday at 2 pm"}]

Memo: "Team standup tomorrow at 9:15 and I should prototype the new notification system"
[{"intent":"event","title":"team standup","datetime_expression_original":"tomorrow at 9:15","datetime_expression_english":"tomorrow at 9:15 am"},{"intent":"note","title":"prototype notification system","datetime_expression_original":null,"datetime_expression_english":null}]

WRONG — never translate the title:
Memo: "Bra idé om att lägga till stegräknare i klockan"
WRONG: [{"intent":"note","title":"add step counter to watch",...}]
RIGHT: [{"intent":"note","title":"stegräknare i klockan","datetime_expression_original":null,"datetime_expression_english":null}]

Memo: "[NO SPEECH DETECTED]"
[]

Current datetime: {current_datetime}
Timezone: UTC{tz_offset}

Voice memo:

{transcript}

/no_think
JSON:"""

ROUTER_TEMPLATE = """Classify this voice memo. The memo may be in ANY language.

Output ONLY a JSON object. No other text.

Rules:
- "none" = NOT a real voice memo. Noise, gibberish, silence markers, music symbols, filler sounds, or no meaningful words.
- "timer_alarm" = setting a timer, countdown, alarm, or wake-up. No task or action — just ring after a duration or at a time.
- "voice_memo" = anything with meaningful content: reminders, events, notes, ideas, tasks.
- IMPORTANT: if the memo mentions an ACTION to perform at a time ("remind me to X", "call Y at 3 PM"), that is "voice_memo", NOT "timer_alarm".
- If the memo contains BOTH a timer/alarm AND other items, output "mixed".

{"route": "none" | "timer_alarm" | "voice_memo" | "mixed"}

Examples:

Memo: "<|nospeech|>"
{"route":"none"}

Memo: ", , ,"
{"route":"none"}

Memo: "uh eh um"
{"route":"none"}

Memo: "Set a timer for 5 minutes"
{"route":"timer_alarm"}

Memo: "Remind me to call the dentist at 3 pm"
{"route":"voice_memo"}

Memo: "Buy milk"
{"route":"voice_memo"}

Memo: "{transcript}"

/no_think
JSON:"""

TIMER_ALARM_TEMPLATE = """Extract timer or alarm details from this voice memo. The memo may be in ANY language.

Return a JSON array. Output MUST start with '[' and end with ']'. No text before or after.

If the memo is noise, gibberish, a silence marker, or contains no meaningful words, return an empty array: []

Rules:
- "timer" = countdown for a duration. Extract duration as integer seconds in "duration_seconds". Set datetime fields to null.
- "alarm" = ring at a specific clock time. Extract time into datetime fields. Set duration_seconds to null.
- Keep title in the original language. If no label, set title to empty string.
- Copy the original time phrase exactly into datetime_expression_original.
- Translate to English in datetime_expression_english. Convert 24h to 12h format.
- For timers: convert all durations to total seconds (e.g. "1.5 hours" = 5400).

Output schema:
[{"intent": "timer" | "alarm", "title": "label", "datetime_expression_original": "..." | null, "datetime_expression_english": "..." | null, "duration_seconds": 480 | null}]

Examples:

Memo: "Set a timer for 8 minutes"
[{"intent":"timer","title":"","datetime_expression_original":null,"datetime_expression_english":null,"duration_seconds":480}]

Memo: "Timer for 5 minutes for pasta"
[{"intent":"timer","title":"pasta","datetime_expression_original":null,"datetime_expression_english":null,"duration_seconds":300}]

Memo: "Set an alarm for 7:30 AM"
[{"intent":"alarm","title":"","datetime_expression_original":"7:30 AM","datetime_expression_english":"7:30 AM","duration_seconds":null}]

Memo: "Sätt en timer på 10 minuter"
[{"intent":"timer","title":"","datetime_expression_original":null,"datetime_expression_english":null,"duration_seconds":600}]

Memo: "Ställ ett alarm klockan 7"
[{"intent":"alarm","title":"","datetime_expression_original":"klockan 7","datetime_expression_english":"at 7 AM","duration_seconds":null}]

Memo: "Wecker auf 7 Uhr stellen"
[{"intent":"alarm","title":"","datetime_expression_original":"7 Uhr","datetime_expression_english":"at 7 AM","duration_seconds":null}]

Memo: "Set a timer for one and a half hours"
[{"intent":"timer","title":"","datetime_expression_original":null,"datetime_expression_english":null,"duration_seconds":5400}]

Memo: "{transcript}"

/no_think
JSON:"""

CORRECTION_TEMPLATE = """Fix speech-to-text errors. Output ONLY the corrected text.

IMPORTANT: NEVER translate. The output language MUST be the same as the input language. Swedish input → Swedish output. German input → German output.

Fix these common STT errors:
- Homophones: "there"/"their", "weak"/"week", "by"/"buy"
- Stuttering/repeats: "I I need" → "I need", "och och" → "och"
- Filler words: remove um, uh, eh, like, you know, alltså, liksom, also
- Missing punctuation: add periods, commas, capitalize first word
- Missing diacritics: "mote" → "möte", "fur" → "für", "pa" → "på"
- Split/joined words: "i morgan" → "imorgon", "can not" → "cannot"

If already correct, repeat the input verbatim. Do NOT add explanations. Output only the corrected text.

Input: "remind me to uh call the the dentist and dont forget to by milk"
Output: "Remind me to call the dentist and don't forget to buy milk."

Input: "vi har mote med kunden pa torsdag klockan tva"
Output: "Vi har möte med kunden på torsdag klockan två."

Input: "also ich äh muss muss den Bericht fertig machen"
Output: "Ich muss den Bericht fertig machen."

Input: "{transcript}"
/no_think
Output:"""


# ─── Test cases ──────────────────────────────────────────────────────────────

EXTRACTION_CASES = [
    # English single-item
    {"id": "en_event_precise", "transcript": "Schedule a design review with Erik and Sara on March 14 at 3:30 PM in Lab 3.", "expect_intent": "event", "expect_time": True},
    {"id": "en_reminder_tomorrow", "transcript": "Remind me tomorrow at 7:15 AM to take the prototype battery off the charger.", "expect_intent": "reminder", "expect_time": True},
    {"id": "en_event_next_tuesday", "transcript": "Meeting with John next Tuesday at 2 pm.", "expect_intent": "event", "expect_time": True},
    {"id": "en_reminder_next_friday", "transcript": "I need to finish the PCB layout review and send it to the manufacturer by next Friday at 5 PM.", "expect_intent": "reminder", "expect_time": True},
    {"id": "en_event_dentist", "transcript": "Dentist appointment on April 22nd at 10:30 AM at the clinic downtown.", "expect_intent": "event", "expect_time": True},
    {"id": "en_note_no_time", "transcript": "Had an interesting idea about using a pressure sensor to detect altitude changes for the hiking app.", "expect_intent": "note", "expect_time": False},
    {"id": "en_reminder_afternoon", "transcript": "Call the plumber this afternoon at 3.", "expect_intent": "reminder", "expect_time": True},
    {"id": "en_reminder_specific_date", "transcript": "Submit the expense report by March 20th at 9 AM.", "expect_intent": "reminder", "expect_time": True, "keywords": ["expense", "report"]},
    {"id": "en_event_birthday", "transcript": "Mom's birthday party on April 5th at 6 PM.", "expect_intent": "event", "expect_time": True, "keywords": ["birthday"]},
    {"id": "en_note_idea", "transcript": "Try using Rust for the sensor driver.", "expect_intent": "note", "expect_time": False, "keywords": ["rust", "sensor"]},

    # Swedish single-item
    {"id": "sv_reminder_tomorrow", "transcript": "Påminn mig imorgon klockan 8 att ringa tandläkaren.", "expect_intent": "reminder", "expect_time": True, "keywords": ["ringa", "tandläkare"]},
    {"id": "sv_event_meeting", "transcript": "Möte med projektgruppen på torsdag klockan 14 i stora konferensrummet.", "expect_intent": "event", "expect_time": True, "keywords": ["möte", "projektgrupp"]},
    {"id": "sv_note_no_time", "transcript": "Köp mjölk och bröd på vägen hem.", "expect_intent": "note", "expect_time": False, "keywords": ["köp", "mjölk", "bröd"]},
    {"id": "sv_note_idea", "transcript": "Bra idé om att lägga till stegräknare i klockan, kanske använda BMI270 sensorn.", "expect_intent": "note", "expect_time": False, "keywords": ["stegräknare", "klocka"]},
    {"id": "sv_event_specific_date", "transcript": "Tandläkare den 15 mars klockan halv 10.", "expect_intent": "event", "expect_time": True, "keywords": ["tandläkare"]},
    {"id": "sv_event_fika", "transcript": "Fika med Lisa på fredag klockan 15.", "expect_intent": "event", "expect_time": True, "keywords": ["fika", "lisa"]},
    {"id": "sv_reminder_pickup", "transcript": "Hämta barnen på förskolan imorgon klockan halv 5.", "expect_intent": "reminder", "expect_time": True, "keywords": ["hämta", "barn"]},
    {"id": "sv_event_doctor", "transcript": "Läkartid på vårdcentralen den 18 mars klockan 10.", "expect_intent": "event", "expect_time": True, "keywords": ["läkar"]},
    {"id": "sv_event_dinner", "transcript": "Middag hos mamma och pappa på lördag klockan 18.", "expect_intent": "event", "expect_time": True, "keywords": ["middag", "mamma"]},
    {"id": "sv_event_car", "transcript": "Bilservice på tisdag klockan 8 hos Mekonomen.", "expect_intent": "event", "expect_time": True, "keywords": ["bilservice"]},
    {"id": "sv_note_grocery", "transcript": "Handla potatis, lök och grädde till middagen.", "expect_intent": "note", "expect_time": False, "keywords": ["handla", "potatis"]},
    {"id": "sv_event_parents", "transcript": "Föräldramöte på skolan onsdag klockan 18:30.", "expect_intent": "event", "expect_time": True, "keywords": ["föräldramöte"]},
    {"id": "sv_reminder_deadline", "transcript": "Skicka in rapporten senast fredag klockan 12.", "expect_intent": "reminder", "expect_time": True, "keywords": ["rapport", "skicka"]},

    # German
    {"id": "de_event_appt", "transcript": "Arzttermin am Donnerstag um 9 Uhr in der Praxis am Marktplatz.", "expect_intent": "event", "expect_time": True, "keywords": ["arzt", "termin"]},
    {"id": "de_reminder_deadline", "transcript": "Ich muss den Bericht bis Freitag um 17 Uhr fertig haben und an den Chef schicken.", "expect_intent": "reminder", "expect_time": True, "keywords": ["bericht", "chef"]},

    # Short voice notes
    {"id": "short_en_idea", "transcript": "Maybe add a compass widget to the watch face.", "expect_intent": "note", "expect_time": False, "keywords": ["compass"]},
    {"id": "short_sv_idea", "transcript": "Testa att använda e-paper display till nästa version.", "expect_intent": "note", "expect_time": False},
    {"id": "short_en_reminder", "transcript": "Oh yeah, water the plants at 5.", "expect_intent": "reminder", "expect_time": True, "keywords": ["water", "plant"]},
    {"id": "short_sv_reminder", "transcript": "Ah just det, ring försäkringsbolaget imorgon.", "expect_intent": "reminder", "expect_time": True, "keywords": ["ring", "försäkring"]},
    {"id": "short_en_fragment", "transcript": "Buy batteries.", "expect_intent": "note", "expect_time": False},
    {"id": "short_sv_fragment", "transcript": "Boka tid hos frisören.", "expect_intent": "note", "expect_time": False, "keywords": ["boka", "frisör"]},

    # Long/rambling
    {"id": "long_en_rambling", "transcript": "So I was thinking, um, I really need to remember to pick up the dry cleaning, I think the ticket is in my jacket, anyway I should do it tomorrow before noon because they close early on Thursdays.", "expect_intent": "reminder", "expect_time": True, "keywords": ["dry clean"]},
    {"id": "long_sv_rambling", "transcript": "Öh jag pratade med Johan igår och vi bestämde att vi ska ha ett möte, tror det var på torsdag klockan 10 eller nåt, i alla fall ska vi gå igenom hela budgeten för nästa kvartal.", "expect_intent": "event", "expect_time": True, "keywords": ["möte", "johan", "budget"]},
    {"id": "long_en_idea", "transcript": "Had a really interesting conversation with the hardware team today about, you know, potentially integrating an ambient light sensor so the display brightness adjusts automatically. Could save a lot of battery and the user experience would be much smoother. Should look into the VEML7700 or maybe the BH1750 sensor, both are I2C and pretty cheap.", "expect_intent": "note", "expect_time": False, "keywords": ["light", "sensor", "display"]},
    {"id": "long_sv_idea", "transcript": "Jag tänkte på en grej, vi borde kanske lägga till sömnspårning i appen, alltså använda accelerometern för att mäta rörelser under natten och sen visa statistik på morgonen. Det finns en bra algoritm i den där forskningsartikeln jag läste förra veckan, kolla upp det.", "expect_intent": "note", "expect_time": False, "keywords": ["sömnspårning", "accelerometer"]},

    # Multi-item
    {"id": "sv_multi_fika", "transcript": "Fika med Anna imorgon klockan 10 och sen lämna in paketet på posten.", "expect_items": 2, "items": [
        {"expect_intent": "event", "expect_time": True, "keywords": ["fika", "anna"]},
        {"expect_intent": "note", "expect_time": False, "keywords": ["paket"]},
    ]},
    {"id": "sv_multi_three", "transcript": "Ring tandläkaren imorgon klockan 9, köp presenter till kalaset och möte med chefen på fredag klockan 14.", "expect_items": 3, "items": [
        {"expect_intent": "reminder", "expect_time": True, "keywords": ["tandläkare", "ring"]},
        {"expect_intent": "note", "expect_time": False, "keywords": ["present", "kalas"]},
        {"expect_intent": "event", "expect_time": True, "keywords": ["möte", "chef"]},
    ]},
    {"id": "en_multi_standup", "transcript": "Team standup tomorrow at 9:15 and I should really prototype the new notification system with stacked cards.", "expect_items": 2, "items": [
        {"expect_intent": "event", "expect_time": True, "keywords": ["standup"]},
        {"expect_intent": "note", "expect_time": False, "keywords": ["notification", "prototype"]},
    ]},
    {"id": "en_multi_two_reminders", "transcript": "Tomorrow at 5 pm we have to pick up the dog and then at 9 turn off all lights.", "expect_items": 2, "items": [
        {"expect_intent": "reminder", "expect_time": True, "keywords": ["dog", "pick"]},
        {"expect_intent": "reminder", "expect_time": True, "keywords": ["light"]},
    ]},
    {"id": "en_multi_two_events", "transcript": "Meeting with Sarah on Monday at 10 am and lunch with the team on Wednesday at noon.", "expect_items": 2, "items": [
        {"expect_intent": "event", "expect_time": True, "keywords": ["sarah"]},
        {"expect_intent": "event", "expect_time": True, "keywords": ["lunch"]},
    ]},
    {"id": "en_multi_reminder_note", "transcript": "Call the plumber at 3 pm tomorrow and also buy new light bulbs.", "expect_items": 2, "items": [
        {"expect_intent": "reminder", "expect_time": True, "keywords": ["plumber"]},
        {"expect_intent": "note", "expect_time": False, "keywords": ["light", "bulb"]},
    ]},
    {"id": "en_multi_same_day", "transcript": "Today at 3 pm call the electrician and at 6 pm pick up the kids from school.", "expect_items": 2, "items": [
        {"expect_intent": "reminder", "expect_time": True, "keywords": ["electrician"]},
        {"expect_intent": "reminder", "expect_time": True, "keywords": ["kids"]},
    ]},
    {"id": "de_multi_two_events", "transcript": "Arzttermin am Donnerstag um 9 Uhr und Zahnarzt am Freitag um 14 Uhr.", "expect_items": 2, "items": [
        {"expect_intent": "event", "expect_time": True, "keywords": ["arzt"]},
        {"expect_intent": "event", "expect_time": True, "keywords": ["zahnarzt"]},
    ]},

    # No-speech / garbage → expect empty []
    {"id": "nospeech_blank", "transcript": "[BLANK_AUDIO]", "expect_empty": True},
    {"id": "nospeech_silence", "transcript": "[silence]", "expect_empty": True},
    {"id": "nospeech_music", "transcript": "(music)", "expect_empty": True},
    {"id": "nospeech_punctuation", "transcript": "... . ,", "expect_empty": True},
    {"id": "nospeech_gibberish", "transcript": "hmm uhh", "expect_empty": True},
    {"id": "nospeech_whisper", "transcript": "♪ ♪ ♪", "expect_empty": True},
]

CORRECTION_CASES = [
    # English
    {"id": "en_weak_week", "input": "I need to finish the report by next weak", "must_contain": ["week"], "must_not_contain": ["weak"]},
    {"id": "en_by_buy", "input": "remind me to by milk on the way home", "must_contain": ["buy"], "must_not_contain": ["by milk"]},
    {"id": "en_meat_meet", "input": "let's meat at the café at half passed three", "must_contain": ["meet", "past"], "must_not_contain": ["meat", "passed"]},
    {"id": "en_wood_would", "input": "she said she wood come at for a clock", "must_contain": ["would"], "must_not_contain": ["wood"]},
    {"id": "en_clean_passthrough", "input": "I have a dentist appointment and I need to cancel it because I have a cold and a terrible headache", "must_contain": ["dentist", "cancel", "headache"], "expect_no_change": True},
    {"id": "en_filler_stutter", "input": "I I need to um finish the report and and send it to the the boss", "must_contain": ["finish the report", "send it to the boss"], "must_not_contain": ["I I", "and and", "the the", " um "]},
    {"id": "en_filler_heavy", "input": "so uh you know I was like thinking we should you know maybe like schedule a meeting", "must_contain": ["schedule", "meeting"], "must_not_contain": [" uh "]},
    {"id": "en_word_boundary", "input": "I can not believe they moved the meeting to an other day with out telling us", "must_contain": ["another", "without"], "must_not_contain": ["an other", "with out"]},
    {"id": "en_their_there", "input": "I left my keys over their on the table", "must_contain": ["there"], "must_not_contain": ["their"]},
    {"id": "en_your_youre", "input": "your going to be late if you dont leave now", "must_contain": ["late", "leave"]},
    {"id": "en_clean_long", "input": "I had a great meeting with the design team today and we agreed on the new color scheme for the watch face", "must_contain": ["design team", "color scheme", "watch face"], "expect_no_change": True},
    {"id": "en_weather_whether", "input": "the whether is really nice today so lets go for a walk in the park", "must_contain": ["weather"], "must_not_contain": ["whether"]},
    {"id": "en_multiple_errors", "input": "I need to by some flower for the party its on wendsday at there house", "must_contain": ["buy", "Wednesday"], "must_not_contain": ["by some", "wendsday"]},

    # Swedish
    {"id": "sv_filler_stutter", "input": "jag ska eh köpa köpa mjölk och bröd på på hemvägen", "must_contain": ["köpa mjölk"], "must_not_contain": ["köpa köpa", "på på", " eh "]},
    {"id": "sv_split_imorgon", "input": "påminn mig att skicka rapporten till chefen i morgan", "must_contain": ["imorgon"], "must_not_contain": ["i morgan"]},
    {"id": "sv_missing_umlaut", "input": "vi har mote med kunden pa torsdag klockan tva", "must_contain": ["möte", "på", "två"], "must_not_contain": ["mote", " pa ", "tva"]},
    {"id": "sv_clean_passthrough", "input": "Boka tandläkare på fredag klockan 10.", "must_contain": ["tandläkare", "fredag"], "expect_no_change": True},
    {"id": "sv_clean_vet", "input": "ring veterinären och boka en tid för katten som har ont i ögat", "must_contain": ["veterinären", "katten"], "expect_no_change": True},
    {"id": "sv_filler_liksom", "input": "jag tankte liksom att vi kanske liksom borde traffas imorgon", "must_contain": ["tänkte", "träffas"], "must_not_contain": ["tankte", "traffas"]},
    {"id": "sv_whisper_number", "input": "klockan ar halv atta och jag maste ga nu", "must_contain": ["är", "åtta", "måste", "gå"], "must_not_contain": [" ar ", " atta", "maste", " ga "]},
    {"id": "sv_clean_longer", "input": "Vi ses på kontoret imorgon bitti för att gå igenom rapporten.", "must_contain": ["kontoret", "rapporten"], "expect_no_change": True},

    # German
    {"id": "de_missing_umlaut", "input": "ich muss den Arzt anrufen und einen Termin fur nachste Woche machen", "must_contain": ["für", "nächste"], "must_not_contain": [" fur ", "nachste"]},
    {"id": "de_filler_stutter", "input": "also ich äh muss muss noch die die Präsentation fertig machen", "must_contain": ["Präsentation", "fertig"], "must_not_contain": ["muss muss", "die die", " äh "]},
    {"id": "de_eszett", "input": "ich weiss nicht ob er die strasse finden konnte", "must_contain": ["weiß", "Straße"], "must_not_contain": ["weiss", "strasse"]},
    {"id": "de_clean_passthrough", "input": "Bitte ruf mich morgen früh an.", "must_contain": ["morgen", "früh"], "expect_no_change": True},
]


# ─── Rendering ───────────────────────────────────────────────────────────────

def render_extraction_prompt(transcript: str, ref_time: datetime) -> str:
    dt_str = ref_time.strftime("%Y-%m-%d %H:%M")
    return (DEFAULT_TEMPLATE
            .replace("{current_datetime}", dt_str)
            .replace("{tz_offset}", TZ_OFFSET)
            .replace("{transcript}", transcript))


def render_correction_prompt(transcript: str) -> str:
    return CORRECTION_TEMPLATE.replace("{transcript}", transcript)


def render_router_prompt(transcript: str) -> str:
    return ROUTER_TEMPLATE.replace("{transcript}", transcript)


def render_timer_prompt(transcript: str) -> str:
    return TIMER_ALARM_TEMPLATE.replace("{transcript}", transcript)


# ─── Inference helpers ───────────────────────────────────────────────────────

def run_inference(engine, prompt: str, max_tokens: int = 384) -> tuple[str, float]:
    """Run inference and return (response_text, elapsed_seconds)."""
    start = time.perf_counter()

    with engine.create_conversation() as conv:
        response = conv.send_message(prompt)

    elapsed = time.perf_counter() - start

    # Extract text from response
    text = ""
    if isinstance(response, dict):
        for item in response.get("content", []):
            if isinstance(item, dict) and item.get("type") == "text":
                text += item["text"]
    elif isinstance(response, str):
        text = response
    else:
        text = str(response)

    return text.strip(), elapsed


def run_inference_streaming(engine, prompt: str) -> tuple[str, float]:
    """Run inference with streaming and return (full_text, elapsed_seconds)."""
    start = time.perf_counter()
    full_text = ""

    with engine.create_conversation() as conv:
        stream = conv.send_message_async(prompt)
        for chunk in stream:
            for item in chunk.get("content", []):
                if item.get("type") == "text":
                    full_text = item["text"]  # cumulative

    elapsed = time.perf_counter() - start
    return full_text.strip(), elapsed


# ─── Validation ──────────────────────────────────────────────────────────────

def parse_json_output(text: str) -> Any:
    """Try to extract JSON from LLM output."""
    text = text.strip()
    # Strip thinking tags if present
    if "<|channel>" in text:
        idx = text.rfind("<channel|>")
        if idx != -1:
            text = text[idx + len("<channel|>"):].strip()
    # Find JSON array or object
    for start_char, end_char in [("[", "]"), ("{", "}")]:
        s = text.find(start_char)
        e = text.rfind(end_char)
        if s != -1 and e != -1 and e > s:
            try:
                return json.loads(text[s:e + 1])
            except json.JSONDecodeError:
                continue
    return None


def validate_extraction(case: dict, output: str) -> dict:
    """Validate a single extraction case. Returns result dict."""
    result = {"id": case["id"], "transcript": case["transcript"], "raw_output": output, "errors": []}

    parsed = parse_json_output(output)

    if case.get("expect_empty"):
        if parsed is None or (isinstance(parsed, list) and len(parsed) == 0):
            result["pass"] = True
        else:
            result["errors"].append(f"Expected empty array, got: {parsed}")
            result["pass"] = False
        return result

    if parsed is None:
        result["errors"].append("Failed to parse JSON from output")
        result["pass"] = False
        return result

    if not isinstance(parsed, list):
        result["errors"].append(f"Expected JSON array, got: {type(parsed).__name__}")
        result["pass"] = False
        return result

    # Multi-item case
    if "items" in case:
        expect_count = case.get("expect_items", len(case["items"]))
        if len(parsed) != expect_count:
            result["errors"].append(f"Expected {expect_count} items, got {len(parsed)}")

        for i, item_spec in enumerate(case["items"]):
            if i >= len(parsed):
                result["errors"].append(f"Missing item {i}")
                continue
            item = parsed[i]
            _validate_item(item, item_spec, result, prefix=f"Item {i}: ")
    else:
        # Single-item case
        if len(parsed) != 1:
            result["errors"].append(f"Expected 1 item, got {len(parsed)}")
        if len(parsed) >= 1:
            _validate_item(parsed[0], case, result)

    result["pass"] = len(result["errors"]) == 0
    return result


def _validate_item(item: dict, spec: dict, result: dict, prefix: str = ""):
    intent = item.get("intent", "")
    if "expect_intent" in spec and intent != spec["expect_intent"]:
        result["errors"].append(f"{prefix}Intent: expected '{spec['expect_intent']}', got '{intent}'")

    has_time = item.get("datetime_expression_original") is not None or item.get("datetime_expression_english") is not None
    if "expect_time" in spec:
        if spec["expect_time"] and not has_time:
            result["errors"].append(f"{prefix}Expected time expression but got none")
        elif not spec["expect_time"] and has_time:
            result["errors"].append(f"{prefix}Expected no time expression but got one")

    if "keywords" in spec:
        title = (item.get("title") or "").lower()
        for kw in spec["keywords"]:
            if kw.lower() not in title:
                # Also check in the raw output as a fallback
                pass  # Keywords in title is best-effort


def validate_correction(case: dict, output: str) -> dict:
    """Validate a single correction case."""
    result = {"id": case["id"], "input": case["input"], "raw_output": output, "errors": []}

    # Strip quotes if the model wrapped the output
    clean = output.strip().strip('"').strip("'")

    for phrase in case.get("must_contain", []):
        if phrase.lower() not in clean.lower():
            result["errors"].append(f"Missing expected phrase: '{phrase}'")

    for phrase in case.get("must_not_contain", []):
        if phrase.lower() in clean.lower():
            result["errors"].append(f"Found forbidden phrase: '{phrase}'")

    result["pass"] = len(result["errors"]) == 0
    return result


# ─── Benchmark runners ───────────────────────────────────────────────────────

def run_extraction_benchmark(engine, cases=None):
    """Run the structured extraction benchmark."""
    cases = cases or EXTRACTION_CASES
    results = []
    total_time = 0.0
    passed = 0

    print(f"\n{'='*80}")
    print(f"  STRUCTURED EXTRACTION BENCHMARK ({len(cases)} cases)")
    print(f"{'='*80}\n")

    for i, case in enumerate(cases):
        prompt = render_extraction_prompt(case["transcript"], MODEL_BENCH_NOW)
        output, elapsed = run_inference(engine, prompt)
        total_time += elapsed

        result = validate_extraction(case, output)
        result["elapsed_s"] = elapsed
        results.append(result)

        status = "PASS" if result["pass"] else "FAIL"
        if result["pass"]:
            passed += 1
        print(f"  [{status}] {case['id']:40s} ({elapsed:.2f}s)")
        if not result["pass"]:
            for err in result["errors"]:
                print(f"         ⚠ {err}")
            # Show first 200 chars of output for debugging
            print(f"         → {output[:200]}")

    print(f"\n{'─'*80}")
    print(f"  Results: {passed}/{len(cases)} passed  |  Total: {total_time:.1f}s  |  Avg: {total_time/len(cases):.2f}s/case")
    print(f"{'─'*80}\n")

    return results


def run_correction_benchmark(engine, cases=None):
    """Run the STT correction benchmark."""
    cases = cases or CORRECTION_CASES
    results = []
    total_time = 0.0
    passed = 0

    print(f"\n{'='*80}")
    print(f"  STT CORRECTION BENCHMARK ({len(cases)} cases)")
    print(f"{'='*80}\n")

    for i, case in enumerate(cases):
        prompt = render_correction_prompt(case["input"])
        output, elapsed = run_inference(engine, prompt, max_tokens=256)
        total_time += elapsed

        result = validate_correction(case, output)
        result["elapsed_s"] = elapsed
        results.append(result)

        status = "PASS" if result["pass"] else "FAIL"
        if result["pass"]:
            passed += 1
        print(f"  [{status}] {case['id']:40s} ({elapsed:.2f}s)")
        if not result["pass"]:
            for err in result["errors"]:
                print(f"         ⚠ {err}")
            print(f"         → {output[:200]}")

    print(f"\n{'─'*80}")
    print(f"  Results: {passed}/{len(cases)} passed  |  Total: {total_time:.1f}s  |  Avg: {total_time/len(cases):.2f}s/case")
    print(f"{'─'*80}\n")

    return results


# ─── Main ────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="LiteRT-LM benchmark for Gemma 4")
    parser.add_argument("--model", required=True, help="Path to .litertlm model file")
    parser.add_argument("--bench", default="all", choices=["extraction", "correction", "all"],
                        help="Which benchmark to run (default: all)")
    parser.add_argument("--output", help="Save results to JSON file")
    args = parser.parse_args()

    print(f"\nLoading model: {args.model}")
    print("(This may take a moment...)\n")

    litert_lm.set_min_log_severity(litert_lm.LogSeverity.ERROR)

    all_results = {}

    with litert_lm.Engine(args.model) as engine:
        print("Model loaded successfully.\n")

        if args.bench in ("extraction", "all"):
            all_results["extraction"] = run_extraction_benchmark(engine)

        if args.bench in ("correction", "all"):
            all_results["correction"] = run_correction_benchmark(engine)

    # Summary
    print(f"\n{'='*80}")
    print("  SUMMARY")
    print(f"{'='*80}")
    for bench_name, results in all_results.items():
        passed = sum(1 for r in results if r["pass"])
        total = len(results)
        avg_time = sum(r["elapsed_s"] for r in results) / total if total else 0
        print(f"  {bench_name:20s}: {passed}/{total} passed  ({avg_time:.2f}s avg)")
    print(f"{'='*80}\n")

    if args.output:
        # Serialize results
        with open(args.output, "w") as f:
            json.dump(all_results, f, indent=2, default=str)
        print(f"Results saved to {args.output}")


if __name__ == "__main__":
    main()
