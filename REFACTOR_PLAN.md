# ZSWatchApp Refactoring Plan

**Created:** 2026-03-16
**Status:** Not started
**Scope:** `zswatch_app/` only. `ai_testbench/` must keep working but is not refactored. `packages/chrono_ai_flow` is clean — leave it alone. Do not touch the `mcumgr_flutter` submodule.
**Backwards compatibility:** NOT required. Wipe database, remove all migrations, start at schema v1. No migration code needed.

---

## Progress Overview

| ID | Title | Status |
|----|-------|--------|
| C1 | Add `freezed`, migrate all domain models | ✅ Done |
| C2 | Wipe database, clean schema | ✅ Done |
| C3 | Fix silent error swallowing | ✅ Done |
| C4 | Split `watch_service.dart` + connection state machine | ✅ Done |
| H1 | Repository base class | ✅ Done |
| H2 | Provider consolidation + base notifier | ✅ Done |
| H3 | Demo mode abstraction | ⏭️ Skipped |
| H4 | Break down oversized screens | ✅ Done |
| H5 | Standardize error display | ✅ Done |
| M1 | Typed navigation | ✅ Done |
| M2 | Stream subscription audit | ✅ Done |
| M3 | Extract shared widgets | ✅ Done |
| L1 | Remove `equatable` dependency | ✅ Done |
| L2 | Replace magic numbers with named constants | ✅ Done |
| L3 | Clean up `time_resolver_debug.dart` | ✅ Done |

**Status key:** ⬜ Not started · 🔄 In progress · ✅ Done · ⏭️ Skipped

---

## Suggested Execution Order

1. C1 — freezed migration (unblocks everything, models used everywhere)
2. C2 — database wipe (clean break, do early)
3. C3 — error handling (mechanical, safe alongside C1/C2)
4. C4 — service split + connection state machine (biggest structural change)
5. H1 — repository base class (after models are frozen)
6. H2 — provider consolidation (after services are clean)
7. H3 — demo mode abstraction
8. H4 — screen extraction
9. H5, M1, M2, M3 — in any order
10. L1–L3 — last

---

## Testing Gates

**After every change (no device needed):**
```bash
cd zswatch_app
flutter pub get
flutter analyze        # Must produce 0 errors
flutter test           # Must pass
dart run build_runner build --delete-conflicting-outputs  # After freezed/drift changes
```

**Device verification (required after C4, recommended after C1/C2):**
```bash
flutter run --debug 2>&1 | tee /tmp/zswatch_app.log
```

Healthy connection sequence to look for in logs:
1. `[BleConnectionManager]` scanning started
2. Device found, connecting → bonding
3. `Negotiated MTU: <value ≥ 185>`
4. `[WatchService]` services discovered
5. `[WatchService]` Re-discovery complete
6. Firmware log entries flowing (`<inf>` / `<dbg>` prefixed lines)
7. No `<err>` entries, no `Connection error:`, no `Reconnect attempt ... failed`

| Phase | Gate |
|-------|------|
| C1 | `flutter analyze` clean + `flutter test` passes + `build_runner` no conflicts |
| C2 | App cold-starts without crash, `flutter analyze` clean |
| C3 | `flutter analyze` clean — `cancel_subscriptions` + `unawaited_futures` rules catch regressions |
| C4 | `flutter analyze` + **device test**: full connection sequence in logs, no reconnect loops |
| H1–H2 | `flutter analyze` + `flutter test` |
| H3 | `flutter analyze` + verify no `demoModeProvider` checks remain in screen build methods |
| H4 | `flutter analyze` — no unused imports, no missing widget references |
| H5, M, L | `flutter analyze` |

---

## Detailed Task Specs

---

### 🔴 C1 — Add `freezed`, migrate all domain models

**Goal:** Replace all manual `copyWith`, `==`, `hashCode`, `toString` with `freezed` code generation. Remove `equatable`.

**Add to `zswatch_app/pubspec.yaml`:**
```yaml
dependencies:
  freezed_annotation: ^2.4.4

dev_dependencies:
  freezed: ^2.5.7
  # build_runner already present
  # json_annotation / json_serializable only if JSON serialization is needed
```

**Files to convert** (all in `lib/data/models/`):
- `watch.dart`
- `health_sample.dart`
- `voice_memo.dart`
- `extracted_action.dart`
- `connection_event.dart`
- `notification.dart`
- `http_request.dart`
- `sensor_reading.dart`
- `sensor_fusion_data.dart`
- `firmware_image.dart`
- `filesystem_image.dart`
- `comm_log_entry.dart`
- `log_entry.dart`
- `log_filter.dart`
- `connection_state.dart`
- `dfu_state.dart`

Also apply to Riverpod state classes in `lib/providers/` that have manual `copyWith`.

**Steps:**
1. Add `freezed_annotation` + `freezed` to `pubspec.yaml`, run `flutter pub get`
2. For each model: add `part 'filename.freezed.dart';`, annotate with `@freezed`, convert to freezed factory constructors
3. Run `dart run build_runner build --delete-conflicting-outputs`
4. Delete all hand-written `copyWith`, `==`, `hashCode`, `toString`, `Equatable` extends from converted files
5. Remove `equatable` from `pubspec.yaml` once all files converted (that's task L1, but can be done here)

**Do NOT convert** classes in `packages/chrono_ai_flow` — those are clean and minimal.

---

### 🔴 C2 — Wipe database, clean schema

**Goal:** Drop all migration code. Clean schema. Schema version = 1.

**Files:**
- `lib/data/database/app_database.dart` — main database class
- `lib/data/database/tables/` — all 7 table definitions
- `lib/data/database/app_database.g.dart` — regenerated, do not edit

**Steps:**
1. Set `@DriftDatabase(schemaVersion: 1, ...)`
2. Replace `MigrationStrategy` body with only `onCreate: (m) => m.createAll()`
3. Delete all `onUpgrade` migration lambdas
4. Schema cleanups while rewriting:
   - `voice_memos` table: convert `processing_status` (text) and `action_review_state` (text) to proper Drift-typed enums
   - Verify whether `connection_events` table is used outside analytics — if only for analytics, consider dropping it
   - Document or remove `extracted_actions.platform_target_id` (currently nullable, purpose unclear)
5. Run `dart run build_runner build --delete-conflicting-outputs` to regenerate `app_database.g.dart`
6. Cold-start the app on device — database file will be recreated fresh

---

### 🔴 C3 — Fix silent error swallowing

**Goal:** No `catch` block silently discards errors.

**Search patterns to find all instances:**
```bash
grep -rn "catch (_)" lib/
grep -rn "catch (e)" lib/ | grep -v rethrow | grep -v AsyncValue
```

**Primary files:** `firmware_manager.dart`, `watch_service.dart`, `health_sync_service.dart`, `gps_service.dart`

**Rule for every catch block — must do one of:**
1. Surface via `AsyncValue.error(e, st)` to UI
2. Re-throw (`rethrow`)
3. Log with `debugPrint` AND have an explicit comment explaining why swallowing is intentional

**Also fix:** `debugPrint`-only catches that don't surface the error to any state — these are silent from the user's perspective even if they appear in logs.

---

### 🔴 C4 — Split `watch_service.dart` + connection state machine

**Goal:** Replace 1,504-line god object + 8 boolean flags with focused services and a proper state machine.

**New connection state machine** (use `freezed` sealed class):
```dart
// lib/data/models/connection_phase.dart
@freezed
sealed class ConnectionPhase with _$ConnectionPhase {
  const factory ConnectionPhase.disconnected() = Disconnected;
  const factory ConnectionPhase.scanning() = Scanning;
  const factory ConnectionPhase.connecting() = Connecting;
  const factory ConnectionPhase.settingUp() = SettingUp;
  const factory ConnectionPhase.connected() = Connected;
  const factory ConnectionPhase.reconnecting({required int attempt}) = Reconnecting;
  const factory ConnectionPhase.error({required ConnectionErrorType type}) = PhaseError;
}
```

**New service files:**

| New file | Responsibility |
|----------|----------------|
| `lib/services/ble/ble_connection_service.dart` | Connection lifecycle, reconnect loop. Exposes `Stream<ConnectionPhase>` as single source of truth. |
| `lib/services/protocol/protocol_service.dart` | Absorb all Gadgetbridge protocol logic (partially exists already). |
| `lib/services/watch/battery_monitoring_service.dart` | Periodic battery polling and storage. |
| `lib/services/watch/device_info_service.dart` | Firmware version, hardware version retrieval. |

**Remove boolean flags** from `watch_service.dart`:
- `_isSettingUp`, `_isCancelled`, `_isReconnecting`, `_isWaitingForAutoConnect`, `_isInitialConnection`, `_isScanning`, `_autoReconnect`, `_isSettingUpCompleted` — all replaced by `ConnectionPhase` state.

**Consolidate connection state:** Delete duplicate state variables in `BleConnectionManager` and `BleNotifier`. All providers (`bleConnectionProvider`, `watchConnectionProvider`, `isConnectedProvider`, `currentConnectionProvider`) must derive from `ble_connection_service.dart`'s single stream.

**Device test gate:** After this change, run on device and verify the full connection sequence appears in logs with no reconnect loops.

---

### 🟠 H1 — Repository base class

**Goal:** Remove duplicated query boilerplate across 8 repositories.

**Create:** `lib/data/repositories/base_repository.dart`
```dart
abstract class BaseRepository<Model, Entity> {
  Model fromEntity(Entity entity);
}
```

**Apply to:**
- `watch_repository.dart`
- `health_repository.dart`
- `battery_repository.dart`
- `voice_memo_repository.dart`
- `extracted_action_repository.dart`
- `connection_analytics_repository.dart`
- `comm_log_repository.dart`
- `settings_repository.dart`

Remove duplicated `_entityToModel()` / `_modelToCompanion()` pattern from each. Consolidate shared query helpers (`getById`, `getAll`, `watch`) into base where possible.

---

### 🟠 H2 — Provider consolidation + base notifier

**Goal:** Reduce 42 StateNotifier classes with near-identical boilerplate. Consolidate 19 provider files.

**Create:** `lib/providers/base_async_notifier.dart` with shared `init`, `handleError`, `reset` methods. Apply to all StateNotifier subclasses.

**Consolidate provider files:**

| Old files | New file |
|-----------|----------|
| `ble_providers.dart` + `watch_service_provider.dart` + `auto_reconnect_provider.dart` + `watch_state_provider.dart` | `connection_providers.dart` |
| `foreground_service_providers.dart` + `permission_providers.dart` + `gps_providers.dart` | `platform_providers.dart` |
| `developer_providers.dart` + `analytics_providers.dart` | `developer_providers.dart` |
| `ai_providers.dart` + `voice_memo_providers.dart` | keep separate if either exceeds 200 lines, otherwise merge |

---

### 🟠 H3 — Demo mode abstraction

**Goal:** Screens never check `demoModeProvider` directly in their `build` methods.

**Steps:**
1. Define `WatchServiceInterface` abstract class covering all public methods/streams of `WatchService`
2. `WatchService` implements `WatchServiceInterface`
3. Create `DemoWatchService` implementing `WatchServiceInterface` with static/fake data
4. Provider selects implementation: `demoModeProvider` check lives only in `watch_service_provider.dart`
5. Remove all inline `ref.watch(demoModeProvider)` checks from screen files

---

### 🟠 H4 — Break down oversized screens

**Goal:** No screen file exceeds ~400 lines. Extract named widget classes to `lib/ui/widgets/<feature>/`.

**Files to extract:**

`voice_memos_screen.dart` (2,935 lines) → extract:
- `lib/ui/widgets/voice_memos/memo_list_item.dart`
- `lib/ui/widgets/voice_memos/search_bar.dart`
- `lib/ui/widgets/voice_memos/sync_progress_bar.dart`
- `lib/ui/widgets/voice_memos/transcription_card.dart`
- `lib/ui/widgets/voice_memos/ai_result_card.dart`

`ai_models_settings_screen.dart` (2,403 lines) → extract each settings section as a widget

`firmware_update_screen.dart` (1,883 lines) → extract:
- `lib/ui/widgets/firmware/dfu_progress_card.dart`
- `lib/ui/widgets/firmware/firmware_image_card.dart`
- `lib/ui/widgets/firmware/filesystem_upload_section.dart`

---

### 🟠 H5 — Standardize error display

**Goal:** One error display contract across the entire app.

**Contract:**
- Transient errors (network, BLE timeout) → `ScaffoldMessenger` snackbar
- Blocking/fatal errors → `AppErrorWidget` (already in `app.dart` — use it consistently)
- Action-required errors → dialog

**Steps:**
1. Audit all screens for ad-hoc error display
2. Replace with the above contract
3. Ensure `AppErrorWidget` is exported and usable from all screen files

---

### 🟡 M1 — Typed navigation

**Goal:** No raw route strings in `context.go()` / `context.push()` calls outside `AppRoutes`.

**Steps:**
1. Add static typed methods to `AppRoutes` for every route
2. Replace all `context.go('/settings')` etc. with `AppRoutes.settings(context)` (or similar pattern)
3. Remove or document `_PlaceholderScreen` routes — either implement or add a `// TODO` with reason

---

### 🟡 M2 — Stream subscription audit

**Goal:** Every `StreamSubscription` field is cancelled in `dispose()`. No fire-and-forget subscriptions.

**Steps:**
1. Search: `grep -rn "StreamSubscription" lib/`
2. For each: verify `cancel()` is called in `dispose()` or `ref.onDispose()`
3. Prefer `StreamProvider` / `ref.watch()` over manual subscription management where possible

---

### 🟡 M3 — Extract shared widgets

**Goal:** Common UI patterns live in `lib/ui/widgets/common/` and are reused.

**Create:**
- `lib/ui/widgets/common/battery_indicator.dart` — reused on dashboard, firmware screen, settings
- `lib/ui/widgets/common/connection_status_card.dart` — reused on multiple screens
- `lib/ui/widgets/common/async_value_widget.dart` — standard loading/error/data wrapper

---

### 🟢 L1 — Remove `equatable` dependency

**When:** After C1 is fully complete.

Remove `equatable: ^2.0.7` from `zswatch_app/pubspec.yaml`. Run `flutter pub get`. Fix any remaining compilation errors (there should be none after C1).

---

### 🟢 L2 — Replace magic numbers with named constants

**Create:** `lib/core/constants/app_constants.dart`

Known magic numbers to name:
- `2000` — notification deduplication window (ms) in `notification_providers.dart:82`
- `3` — quick reconnect attempts in `watch_service.dart:54`
- `5000` — comm log entry rotation limit in comm log service
- `1000` — log viewer in-memory buffer size
- `185` — minimum acceptable MTU (iOS)
- `60` — analytics retention days

---

### 🟢 L3 — Clean up `time_resolver_debug.dart`

**File:** `packages/chrono_ai_flow/test/time_resolver_debug.dart`

This is a manual debug script, not a formal test. Either:
- Rename to `time_resolver_debug_manual.dart` and move outside `test/` into a `scripts/` directory, or
- Delete it if it's no longer needed

---

## Notes

- `packages/chrono_ai_flow` — clean, well-structured, do not refactor
- `ai_testbench/` — separate desktop Flutter app, must keep working, not in scope for refactoring
- `mcumgr_flutter` — git submodule, do not touch unless a change there would dramatically simplify code in `zswatch_app/services/dfu/`
- `flutter analyze` has 2 existing warnings before refactoring starts (unused import + unused `_deleteWatch` in `start_page_screen.dart`) — fix these as part of C3
