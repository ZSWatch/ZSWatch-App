# Existing Android feature parity — reopened 2026-10-08

The earlier local Android checklist passed its listed cases, but omitted existing
features. It did **not** establish full app parity. This inventory supersedes the
claim that no Android implementation work remained. Baseline: the Flutter app
before native shell commit `0a8f430`, plus existing shared features added since.
Remote/hybrid AI and iOS remain outside scope; long endurance is user-owned.

| Existing area | Audit / remaining work |
| --- | --- |
| Dashboard | Restore Health and Analytics tiles, steps/pulse summary, and native-coordinated Restart Watch. |
| Health | Restore existing Today/Week/Month views and heart-rate view; persist incoming `act` steps/HR/activity while Flutter is absent. Keep existing aggregation and retention. Historical `actfetch` was already a placeholder; do not invent a new firmware feature. |
| Analytics | Restore battery history/drain estimates and connection uptime/events/timeline; collect natively rather than requiring the Flutter UI to remain open. |
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
