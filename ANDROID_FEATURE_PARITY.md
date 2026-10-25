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


## Integration follow-up, 2026-10-20

App PR [#6](https://github.com/ZSWatch/ZSWatch-App/pull/6) now includes the
Android continuation of the iOS DFU/voice HIL session. A Service Changed event
received during initial GATT discovery now retries discovery on that same
instance; events after adopting handles still fence and reconnect. The previous
early close left Android in discovery indefinitely. The owner requests high
connection priority during setup. Bluetooth-off onboarding opens the system
enable prompt, and the connected-watch shortcut excludes forgotten watches.
Android also supports the pushed-package and phone-speaks developer hooks.
Model download status survives leaving the page, missing-model feedback expires,
and clearing sensor history resets the fusion sample count.

On OnePlus NE2213 / Android 16, a three-image update from the marker build to the
regular fixes build completed and passed the app's image verification without
manual recovery. The early Service Changed rediscovery completed in 236 ms.
Ordinary Restart Watch, automatic Bluetooth off/on recovery, and a 20-second
Home/background return passed at MTU 247. Background return retained the same
app PID. Sensor Fusion produced live quaternion/Euler values and hundreds of
samples; stopping and clearing history passed. The other sensor types were not
retested in this continuation. Eight-second fusion current averaged 1.289 mA;
a later 25-second idle observation averaged 0.145 mA. These short captures do
not establish battery-life or endurance acceptance.

Voice processing is enabled with Whisper Small Q5_1 Multilingual, Qwen2.5 1.5B
Q4_K_M, transcription correction, automatic processing and analysis all on.
The 11.9-second phone-speaks recording synced natively, but Whisper returned
`*BANG*`; Qwen reported `analysis_empty`. This is **not** a successful spoken
reminder flow. The verified source audio contains a clipped microphone startup
transient. The same model reproduces the result locally; removing the first
500 ms recovers the reminder phrase, with inaccuracies. A proposed capture-side
microphone settling fix is prepared separately and has not been applied to the
firmware repository. Firmware modification awaits user authorization under
AGENTS.md. The tested release APK was restored after temporary debug access to
inspect this owned test recording; originals were retained.

Validation: Flutter analyze clean; the earlier full suite passed 357 tests, and
16 affected tests passed after the follow-ups, including four new speech
cleanup/error/timeout cases. The Android app unit suite passed 276 tests; the
release APK built and installed successfully. Tested release SHA-256:
`28cbfa6f57bf1bd15c73d1a11c0f30e3f364a445ff874cd0b0e9519efebb1060`.
Evidence and the proposed microphone patch are under the gitignored
`.companion-hil-runs/2026-10-20-codex-android/` directory. These results are scoped
to this integration session and do not close the remaining parity inventory.

## First-run setup and dictated reply follow-up — 2026-10-25

Dictated replies is rebased on app main `8395a331`, including Voice Notes
management and default-all-app notification forwarding. First-run Android and
iOS now share a native-companion permission/setup page; it opens before watch
selection, makes permission requests only on explicit taps, and links directly
to notification forwarding and voice setup. General automatic memo processing
and LLM analysis remain optional; dictated replies use speech-to-text only.
iOS continues to use ANCS notification sharing, which has no reply action.

The user successfully replied to a real Messenger conversation on the OnePlus.
Its observed Reply action targets an Android service. The Gmail attempt failed:
Android logged `BAL_BLOCK` for Gmail's `AutoSendActivity`. Reply dispatch now
opts into the PendingIntent activity launch on API 34+, including companion
background privileges on API 36+. A real Gmail retest is still required; dispatch
acceptance must not be interpreted as recipient delivery confirmation.

Validation of this follow-up: all 387 Flutter tests pass (including Android/iOS
first-run setup), 24 targeted Kotlin notification/voice-policy/result tests pass,
Flutter analysis is clean, and Android debug build 12 compiles. On the OnePlus,
local broadcast and Gmail-like Activity reply fixtures both received their text
with the app in the background. These fixtures do not send to real contacts.
The iOS UI is covered by shared widget tests; no iOS device build or fresh iPhone
acceptance is claimed. The OnePlus app is then reset for the user's clean
permission-onboarding test.
