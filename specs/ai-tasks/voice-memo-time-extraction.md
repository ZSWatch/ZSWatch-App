# Voice Memo → Reminder/Calendar Time Extraction Pipeline

**Status**: Draft  
**Date**: 2026-03-09  
**Depends on**: ai-enhanced-voice-notes.md (existing AI pipeline)

---

## 1. Problem Statement

The current AI pipeline (`LlmService._buildClassifyPrompt`) asks the LLM to **compute absolute ISO-8601 datetimes** from relative expressions like "tomorrow at 10" or "nästa tisdag kl 14". Small local models (Qwen 2B class) frequently get date math wrong — producing incorrect dates, wrong days-of-week, or hallucinated timestamps.

Additionally, `VoiceNoteAiPipeline._tryParseDate()` simply calls `DateTime.parse()` and returns `null` for anything that isn't already ISO-8601. Natural language dates are silently lost.

## 2. Solution: Split Responsibilities

| Component | Responsibility |
|-----------|---------------|
| **LLM** | Intent detection, title extraction, time phrase extraction, translation to English |
| **chrono_dart** | Deterministic parsing of English natural-language time → `DateTime` |
| **Fallback regex** | Simple patterns (`in X minutes`, `tomorrow`) if chrono fails |

**Key rule**: The LLM must **never** compute absolute datetimes. It only extracts and translates the natural-language time expression. All date math is performed deterministically by `chrono_dart`.

## 3. Pipeline Overview

```
Transcript (any language)
       ↓
[Existing] Transcription correction (LLM pass 1, optional)
       ↓
[Existing] Classification + summarization (LLM pass 2 — MODIFIED prompt)
       ↓
New fields: datetime_expression_original, datetime_expression_english
       ↓
chrono_dart.parse(english_expression, referenceDate: DateTime.now())
       ↓
Resolved DateTime (or null)
       ↓
Populate existing ExtractedAction fields (startTime, dueDate, etc.)
```

## 4. What Changes vs. Current Pipeline

### 4.1 LLM Prompt Changes

The existing `_buildClassifyPrompt()` tells the LLM to:
> "If a relative date/time is mentioned, resolve it to an absolute ISO-8601 datetime"

**New approach**: Instead of asking the LLM to resolve dates, we ask it to:
1. **Extract** the time phrase exactly as spoken (any language)
2. **Translate** the time phrase to English
3. Output these as two new JSON fields

The prompt still produces `summary`, `category`, and `actions` — the schema gains two fields per action:
- `datetime_expression_original` — the raw phrase from the transcript
- `datetime_expression_english` — English translation of that phrase

The existing `due_date`, `start_time`, `end_time` fields become **null** in LLM output (chrono fills them).

### 4.2 Post-LLM Processing

After parsing the LLM JSON, a new `TimeExpressionResolver` class:
1. Takes the `datetime_expression_english` string
2. Passes it to `chrono_dart` with `DateTime.now()` as reference
3. If chrono succeeds → populates `startTime`/`dueDate` on the `ExtractedAction`
4. If chrono fails → tries simple regex fallbacks
5. If all fails → leaves time as `null` (user can set manually)

### 4.3 No Schema Changes Needed

The existing `ExtractedAction` model and database table already have:
- `startTime`, `endTime`, `dueDate` (nullable `DateTime`)
- `reminderMinutes` (nullable `int`)

We add no new DB columns. The time expression strings are intermediate — only the resolved `DateTime` gets persisted.

## 5. Detailed Design

### 5.1 Modified LLM JSON Schema (per action)

```json
{
  "type": "reminder",
  "title": "köpa mjölk",
  "notes": null,
  "datetime_expression_original": "imorgon klockan 10",
  "datetime_expression_english": "tomorrow at 10 am",
  "location": null,
  "priority": null,
  "reminder_minutes": null
}
```

Removed from LLM output: `due_date`, `start_time`, `end_time` (chrono fills these).

### 5.2 Modified LLM Prompt (extraction section)

```
For each action:
- Extract the time/date phrase EXACTLY as spoken in the original transcript.
- Translate that phrase to English, preserving relative meaning.
- Do NOT compute or resolve dates. Do NOT output ISO timestamps.
- If no time is mentioned, use null for both datetime fields.
```

### 5.3 TimeExpressionResolver

```dart
class TimeExpressionResolver {
  /// Parse an English time expression into a DateTime.
  /// Returns null if unparseable.
  DateTime? resolve(String englishExpression, {DateTime? referenceDate});
  
  /// Regex fallback for common patterns chrono might miss.
  DateTime? _regexFallback(String expression, DateTime reference);
}
```

Chrono usage:
```dart
final results = Chrono.parse(englishExpression, referenceDate ?? DateTime.now());
if (results.isNotEmpty) {
  return results.first.start.date();
}
```

### 5.4 Text Normalization (Pre-LLM, Optional)

Convert number words to digits in the transcript before sending to LLM. This helps both the LLM and chrono:
- "tomorrow at ten" → "tomorrow at 10"
- "in five minutes" → "in 5 minutes"

Scope: English number words only (the LLM handles other languages via translation).

### 5.5 Integration Point

In `LlmService._parseTranscriptResult()`, after extracting actions from JSON:
1. Read `datetime_expression_english` from each action
2. Call `TimeExpressionResolver.resolve()`
3. Map result to the action's `startTime` or `dueDate` based on action type:
   - `reminder` → `dueDate`
   - `calendar_event` → `startTime`
   - `task` → `dueDate`

## 6. CLI Testbench Spec

### Purpose
Iterate on LLM prompt + chrono parsing on desktop without needing the full Flutter app, BLE, or a phone. Run test cases, evaluate accuracy, tune prompts.

### Location
`ai_testbench/bin/test_time_extraction.dart` — a new CLI script in the existing testbench project.

### Architecture  
Reuses:
- `ai_testbench/native_libs/libllama.so` — existing native library
- `ai_testbench/models/` — existing downloaded models (especially `Qwen3.5-2B-Q4_K_M.gguf`)
- `llama_cpp_dart` package — for direct CLI inference (no Flutter dependency)

New:
- `ai_testbench/lib/services/time_extraction_service.dart` — `TimeExpressionResolver` implementation
- `ai_testbench/lib/prompts/time_extraction_prompts.dart` — the new LLM prompt
- `ai_testbench/bin/test_time_extraction.dart` — CLI test runner
- `chrono_dart` dependency in `ai_testbench/pubspec.yaml`

### Test Cases

| # | Input (transcript) | Language | Expected intent | Expected title | Expected time phrase (EN) | Expected resolved DateTime |
|---|-------------------|----------|----------------|---------------|--------------------------|---------------------------|
| 1 | "Remind me tomorrow at 10 am to buy milk" | EN | reminder | buy milk | tomorrow at 10 am | 2026-03-10T10:00 |
| 2 | "påminn mig imorgon klockan 10 att köpa mjölk" | SV | reminder | köpa mjölk | tomorrow at 10 | 2026-03-10T10:00 |
| 3 | "erinnere mich morgen um 10 milch zu kaufen" | DE | reminder | milch kaufen | tomorrow at 10 | 2026-03-10T10:00 |
| 4 | "meeting with John next Tuesday at 2 pm" | EN | event | meeting with John | next Tuesday at 2 pm | 2026-03-10T14:00 (or 2026-03-17) |
| 5 | "remember to buy milk" | EN | note | buy milk | null | null |
| 6 | "ring tandläkaren om 30 minuter" | SV | reminder | ring tandläkaren | in 30 minutes | ~now+30m |
| 7 | "rappelle-moi vendredi à 15h d'appeler le médecin" | FR | reminder | appeler le médecin | Friday at 3 pm | next Friday 15:00 |
| 8 | "dentist appointment on March 15th at 9:30" | EN | event | dentist appointment | March 15th at 9:30 | 2026-03-15T09:30 |
| 9 | "köp bröd på vägen hem" | SV | task | köp bröd | null | null |
| 10 | "team standup every weekday at 9 AM" | EN | event | team standup | every weekday at 9 AM | (recurring — chrono may only get next occurrence) |

### CLI Output Format

```
╔══════════════════════════════════════════════════════════╗
║   ZSWatch Time Extraction Testbench — CLI               ║
╚══════════════════════════════════════════════════════════╝

[1/3] Loading model: Qwen3.5-2B-Q4_K_M.gguf
      Model loaded in 1234ms ✓

─── Test 1: English reminder ─────────────────────────────
  Input:    "Remind me tomorrow at 10 am to buy milk"
  LLM time: 2.3s (45.2 tok/s)
  
  LLM output:
    intent:     reminder
    title:      buy milk
    time (orig): tomorrow at 10 am
    time (EN):   tomorrow at 10 am
  
  Chrono parse: 2026-03-10T10:00:00 ✓
  Expected:     2026-03-10T10:00:00
  Status: ✅ PASS

─── Test 2: Swedish reminder ─────────────────────────────
  ...

╔══════════════════════════════════════════════════════════╗
║  Results: 8 passed, 2 failed out of 10 tests            ║
║  Total LLM time: 23.4s                                  ║
╚══════════════════════════════════════════════════════════╝
```

### Evaluation Criteria per Test Case

1. **Intent correct** — does `intent` match expected?
2. **Title reasonable** — does `title` capture the task? (fuzzy, logged but not auto-scored)
3. **Time phrase extracted** — is `datetime_expression_english` non-null when expected?
4. **Chrono parse succeeds** — does `chrono_dart` produce a valid DateTime?
5. **DateTime correct** — does the resolved DateTime match expected (within ±1 minute tolerance for relative times)?

A test PASSES if criteria 1, 3, 4, and 5 all succeed (or 3-5 are all null when no time expected).

## 7. Implementation Plan

### Phase 1: CLI Testbench (this task)
1. Add `chrono_dart` to `ai_testbench/pubspec.yaml`
2. Create `TimeExpressionResolver` in `ai_testbench/lib/services/`
3. Create time extraction prompt in `ai_testbench/lib/prompts/`
4. Create CLI test runner in `ai_testbench/bin/test_time_extraction.dart`
5. Run and iterate until ≥80% pass rate on test cases

### Phase 2: Integrate into companion app (future task)
1. Add `chrono_dart` to `zswatch_app/pubspec.yaml`
2. Copy finalized `TimeExpressionResolver` to `zswatch_app/lib/services/ai/`
3. Modify `LlmService._buildClassifyPrompt()` with new prompt
4. Modify `LlmService._parseTranscriptResult()` to use chrono resolution
5. Update `VoiceNoteAiPipeline` to handle new fields

## 8. Model Selection

The testbench will default to `Qwen3.5-2B-Q4_K_M.gguf` (already present in `ai_testbench/models/`). The prompt is designed to work with any model in the models directory — the CLI can accept a `--model` flag to test different models.

## 9. Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| LLM fails to extract time phrase in non-English | Prompt includes explicit examples in multiple languages |
| LLM translates time phrase incorrectly | Test with multilingual corpus; fallback to original phrase |
| chrono_dart doesn't parse some English expressions | Regex fallback for common patterns; log failures for prompt tuning |
| Small model hallucinates time phrases not in transcript | Prompt instructs to copy exact phrase; validation step compares to input |
| chrono_dart doesn't support all relative expressions | Acceptable — leave as null, user can set manually |

## 10. Out of Scope

- Recurring events (chrono may parse "every Tuesday" as next Tuesday only — acceptable for v1)
- Duration extraction (e.g., "30 minute meeting") — future enhancement
- Timezone conversion — we use device local time throughout
- Calendar/reminder OS integration — already handled by existing `ExtractedAction` flow
- UI changes — the existing action review UI works with resolved DateTimes
