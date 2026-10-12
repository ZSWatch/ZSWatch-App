# Existing Android feature parity — reopened 2026-10-08

The earlier local Android checklist passed its listed cases, but omitted existing
features. It did **not** establish full app parity. This inventory supersedes the
claim that no Android implementation work remained. Baseline: the Flutter app
before native shell commit `0a8f430`, plus existing shared features added since.
Remote/hybrid AI and iOS remain outside scope; long endurance is user-owned.

| Existing area | Audit / remaining work |
| --- | --- |
| Dashboard | Six feature tiles and steps/pulse summary restored. Restart Watch restored through the service-owned Nordic `DefaultManager`, including SMP preparation and no automatic reset replay. Ordinary Cancel/restart/reconnect passed on OnePlus. |
| Health | Today/Week/Month and heart-rate views restored, using native-persisted `act` steps/HR/activity and existing aggregation/60-day retention. Physical OnePlus/watch test passed with Flutter activity absent. Historical `actfetch` was already a placeholder; manual standard-HRS streaming was not used by these screens. Neither is claimed as a new feature. |
| Analytics | Existing battery history/drain estimates and connection uptime/events/timeline restored. Collection runs in the native service. Headless battery/activity and ordinary Disconnect→Connect checks passed; native lifecycle events are visible in the existing diagnostics. Long drain estimates still require enough real history. |
| Experimental watch voice chat | Not a product feature and unsupported by the watch, as confirmed by the user. App prototype, TTS dependency, chat preferences and history schema removed. Normal voice memos and their transcription/analysis remain. No native chat backend is required. |
| Voice notes / AI controls | The native receipt view is missing existing search/filter/archive, local deletion, transcript editing/copy, standalone transcription, explicit re-transcription/re-analysis and bulk processing. These are actual product gaps, not the excluded voice-chat prototype. Restore them through the existing journal/shared Dart worker, including existing automatic transcription versus optional analysis settings. Model import/download/delete, manual calendar/Clock actions and previously accepted local processing are retained. Existing shared model benchmark restored and its visibility checked on OnePlus; no new inference result is claimed. |
| Permissions / demo | Consolidated Bluetooth/notification access/location/background location/battery exemption summary and explicit settings navigation restored; native read-only status does not initialize Flutter BLE or prompt automatically. Physical overview and app-shell behavior passed. Existing Google Play reviewer demo mode still needs restoration without accidental real-watch operations. |
| Developer controls | Audit hidden Debug Tools actions against old functionality; restore useful commands through native coordination. Existing six developer tools have prior scoped acceptance. |
| HTTP diagnostics | Audited: `httpRelayRecentRequestsProvider` has no product UI consumer in the app (only a provider test); its former history was in-memory debugging state. No removed history screen was found. Existing native HTTP on/off/last-outcome status and communication log remain. Do not invent a history UI to satisfy an unused provider. |
| Other existing areas | Audit notification settings/actions, media, GPS/weather, saved-watch rename/forget/selection, firmware/resources, watchface/crop, crash history/files/upload, filesystem, shell, sensors, settings/deep links against their earlier controls. Record equivalents and actual gaps explicitly. |

Do not finish by revealing links to legacy services. Preserve existing Flutter
views/repositories, single native transport ownership, user-modified Nordic and
AI libraries, watch originals and unrelated work. For each implementation change,
run relevant tests/builds and targeted physical acceptance; reuse unchanged prior
passes. Mark a row complete only when its existing functionality is accounted for.

Prototype cleanup validation (2026-10-08): 45 affected app-shell, saved-watch/DB,
voice-memo processor and recovery tests passed; static analysis reported no
issues; Android release APK compiled. The v6→v7 migration removes only
`chat_history` and a test verifies existing watches/voice memos survive. These
results cover prototype removal, not the outstanding product-feature parity.
Evidence: `.companion-hil-runs/20261008-remove-voice-chat/validation.json`.

## Health / Analytics restoration evidence

### Handoff update, 2026-10-12

Commit `67976ef` records previously pending standalone transcription,
re-transcription/re-analysis, batch queue controls and automatic-transcription
versus optional-analysis settings. The three affected Flutter test files passed
28 tests; native `PrototypeJobsTest` and `PrototypeVoicePolicyTest`, Flutter
analysis and the Android release build passed. This is code/build validation,
not fresh physical acceptance. Search/filter/archive, local deletion,
transcript editing/copy, offline processing after explicit companion Stop,
demo/developer parity and the remaining inventory still require closure.
Do not interpret the publication of the handoff branch as full feature parity.

### Previously accepted Health / Analytics implementation

The existing Dart screens and database remain. Native collection writes their
existing health/battery/connection tables before publishing snapshots; Flutter
invalidates the corresponding queries and projects live activity without writing
duplicate samples or starting the old Dart collectors. Android opens the app
database through the maintained Drift sqflite adapter, with WAL enabled for both
readers and writers. Other platforms retain their original database executor.
Watch upsert uses a portable select/insert/update transaction so older Android
SQLite versions do not require newer UPSERT syntax.

An initial candidate using Flutter's bundled SQLite plus Android's framework
SQLite collected headless samples, but reopened Flutter views stopped seeing
new history until a full process restart. That candidate failed acceptance.
Sharing the framework SQLite implementation resolved the observed failure.
The exact internal cause was not established; no database corruption is claimed.
SQLite [documents risks from multiple linked SQLite copies opening the same file](https://www.sqlite.org/howtocorrupt.html#multiple_copies_of_sqlite_linked_into_the_same_application).
Drift [maintains the platform-channel sqflite adapter](https://drift.simonbinder.eu/platforms/).

Accepted scoped release evidence:
`.companion-hil-runs/20261008-health-analytics-sqlite/`.
Production APK SHA-256:
`6a7238bbea3752106be298a8c16d4e07e64f11932a09a0d870f26df5ab385fba`;
the non-debuggable physical-test copy differs only in signing entries, as recorded
in `artifact.json`. The OnePlus displayed all six dashboard tiles, Health ranges,
live pulse and both Analytics tabs. With its Flutter activity removed, the native
foreground service retained PID 30339, and the reopened Health sample count grew
204→209. An actual watch battery event was delivered over BLE while the UI was
absent; the temporary test status was restored to 87%, not charging. Ordinary
Disconnect then Connect grew the stored disconnection count 2→3. Physical steps
were zero; nonzero steps/malformed/stale event mapping is covered by tests.
No watch reset, firmware flash, recording deletion or endurance run was involved.
These results establish this scope, not completion of the remaining inventory.

## Additional restored controls

Scoped evidence: `.companion-hil-runs/20261008-parity-controls/`.
Twenty app-shell tests pass (including restart confirmation/cancellation,
read-only permissions and lifecycle/owner isolation), static analysis is clean,
and 25 native restart/shell/SMP preparation tests pass. Android release compiles.
Production SHA-256:
`97f367f52f7f48493db8c5acc288158a76998b9acecde1c69b7b8dd856cfef29`.
The installed non-debuggable lab-signed copy has identical runtime ZIP entries.
Ordinary OnePlus UI showed all six feature tiles plus Restart Watch. Cancel
left it connected; one confirmed restart showed Reconnecting then Connected
with MTU 247, without manual reset or unpairing. Permissions showed all six
statuses, and the existing Model Benchmark was visible. No model inference,
permission change, firmware flash or long test was performed for this check.
The developer companion connection action also reuses the ordinary permission
and database-initialization callback. This closes its former schema-init bypass.
