# Existing Android feature parity — reopened 2026-10-08

The earlier local Android checklist passed its listed cases, but omitted existing
features. It did **not** establish full app parity. This inventory supersedes the
claim that no Android implementation work remained. Baseline: the Flutter app
before native shell commit `0a8f430`, plus existing shared features added since.
Remote/hybrid AI and iOS remain outside scope; long endurance is user-owned.

| Existing area | Audit / remaining work |
| --- | --- |
| Dashboard | Six feature tiles and steps/pulse summary restored. Native-coordinated Restart Watch still remains. |
| Health | Today/Week/Month and heart-rate views restored, using native-persisted `act` steps/HR/activity and existing aggregation/60-day retention. Physical OnePlus/watch test passed with Flutter activity absent. Historical `actfetch` was already a placeholder; manual standard-HRS streaming was not used by these screens. Neither is claimed as a new feature. |
| Analytics | Existing battery history/drain estimates and connection uptime/events/timeline restored. Collection runs in the native service. Headless battery/activity and ordinary Disconnect→Connect checks passed; native lifecycle events are visible in the existing diagnostics. Long drain estimates still require enough real history. |
| Experimental watch voice chat | Not a product feature and unsupported by the watch, as confirmed by the user. App prototype, TTS dependency, chat preferences and history schema removed. Normal voice memos and their transcription/analysis remain. No native chat backend is required. |
| Voice AI controls | Audit/reconnect retranscribe, bulk processing, transcription/analysis switches, model benchmark, import/download/delete and calendar/Clock controls. Already accepted local voice-note processing is retained. |
| Permissions / demo | Restore useful consolidated permission navigation and existing reviewer demo mode without starting a second BLE owner or accidental real-watch operations. |
| Developer controls | Audit hidden Debug Tools actions against old functionality; restore useful commands through native coordination. Existing six developer tools have prior scoped acceptance. |
| HTTP diagnostics | Native relay works, but recent-request provider currently returns an empty list; restore any existing user-visible history/control rather than silently dropping it. |
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
