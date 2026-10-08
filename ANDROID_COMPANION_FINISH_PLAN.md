# Finish the Android companion — fixed checklist for Sol

**Completed, 2026-10-08.** The user resumed this checklist; required acceptance
and the concrete onboarding fix are complete. See [the final report](ANDROID_COMPANION_FINAL_REPORT.md).

**User direction, 2026-10-08.** This is the authoritative completion scope.
It supersedes earlier rollout/migration requirements, the stored goal's remote/
hybrid requirements, and exhaustive testing requirements in older plans.
**Remote/hybrid AI and iOS are out of scope.** The user will do long-term testing;
no agent-run eight-hour test, endurance automation or replacement soak is required.

The Android native owner and shared Dart local voice/AI flow are implemented.
Remaining work is bounded acceptance and fixes for concrete blocking regressions,
not another architecture phase. Keep the existing Flutter UI, the user's Nordic
and fllama forks, and one native BLE owner. No compatibility flag, native AI
rewrite, custom SMP, broad cleanup or model/prompt tuning.

## Next goal: OnePlus voice processing and Android acceptance

### Replacement goal text

Finish the Android companion with local voice/AI by following the fixed October 8
checklist in ANDROID_COMPANION_FINISH_PLAN.md. Reuse the accepted physical evidence
and existing release build. Close one fresh-app onboarding/permission check when
the OnePlus is available, fix only demonstrated blocking regressions, and deliver
the identified release APK plus a concise acceptance report. Remote/hybrid AI,
iOS, long endurance and the explicitly deferred test variants are out of scope.
Preserve watch originals and unrelated work; commit completed changes on
codex/companion-background-foundation. Finish when the required checklist is
closed; do not invent additional completion gates from historical test caveats.

### Accepted baseline — do not retest unchanged functionality

The October 8 review inspected code, retained test reports and physical artifacts
from the work through October 7.
Details and earlier failures are in [the acceptance history](ANDROID_COMPANION_ACCEPTANCE_HISTORY.md).

| Area | Accepted evidence and limits |
| --- | --- |
| Android ownership / Flutter UI | Native is the normal Android path, including release. UI and local processing reuse Dart; headless worker has no BLE plugin/Activity. |
| Local voice/AI | Real Swedish microphone recording and English/longer inputs reach persisted result and watch application ACK with Flutter UI absent. Existing classification quality is outside this refactor. |
| Recovery / cancellation | Process interruption, saved-transcript reuse, deliberately lost ACK/duplicate acceptance, user Stop, GGUF/STT cancellation and missing/malformed/silent input have scoped passes. |
| Core companion features | Notifications, time, HTTP, GPS/Weather, media, Find, ordinary Shell and restored diagnostics/settings have recorded passes. |
| Updates | Application/resource operations complete with Flutter absent; acknowledged firmware rate about 41 KB/s and independent integrity checks pass. Network-core image 1 remains an explicit unsupported/unverified case. |
| Pairing / UI recovery | Fresh bonding, saved-watch reconnect, sensor reconnect fix and watchface interruption/retry have physical passes. Clean app data/onboarding is the remaining required phone check. |
| Background lifetime | Short screen-off, injected process death and phone reboot/first-unlock recovery have scoped passes. They do not prove long unplugged/OEM endurance; the user owns that testing. |
| Build/tests | Runtime source 9b9eef4; 243 retained native tests pass, affected Flutter checks and production release build pass. Firmware fix 098977c4 is flashed, identified by exact build/image hashes in the history. |

## Work through these four items in order

### 1. Close the current test loop and identify the deliverable — no phone needed

- [x] Read this checklist and inspect current Git state once. Preserve unrelated
  modifications and the local library forks; do not repeat the broad review.
- [x] Identify the current APK/source and relevant passed reports. Start from
  `.companion-hil-runs/20261007-oneplus-watchface-mtu/artifact.json` (runtime
  9b9eef4). Reuse that release if code has not changed; rebuild only if needed.
- [x] Record the interrupted custom-image test as unverified and deferred. Its
  observer rejected a rendered thumbnail color before selecting/cropping/uploading;
  this is not a demonstrated app defect. No more retries of that observer.

### 2. One fresh-app onboarding and permission pass — phone required

- [x] Wait until the user makes the OnePlus available again. Do not touch the
  phone during the user's absence or substitute more peripheral tests for waiting.
- [x] Use ordinary app UI from clean app data: grant required permissions, select
  the existing watch and reach Connected/Ready without prototype/debug commands
  or repeated manual unpair/reset rituals. The user has already allowed app data
  and permission resets; preserve watch recordings/background and unrelated apps.
  This is app onboarding, not another exhaustive Bluetooth-bond-state matrix.
- [x] Remove the Flutter task, observe the native foreground owner, and deliver
  one real watch data request or notification. Reopen the UI and confirm normal
  attachment. Existing local AI and update passes remain valid for unchanged code;
  do not download models or rerun inference/large transfers just for this check.
- [x] On return, remove only our owned phone image
  `/sdcard/Pictures/ZSWatchLab/hil_custom_red_20261007.png` if still present.
  Clear an abandoned picker through normal navigation. Do not reset the watch.

### 3. Fix only blockers exposed by that pass; run affected checks

- [x] A blocker is a reproducible regression preventing ordinary setup/connect,
  breaking the required background data/local voice flow, losing/corrupting data,
  or causing a crash in these flows. Fix it in the existing app/FW ownership path.
  Cosmetic details, pre-existing AI quality and extra failure combinations are not
  blockers for this milestone. If there is no blocker, close this item directly.
- [x] For an actual code change, run the affected tests and release build, then
  verify the changed phone/watch behavior. Repeat unrelated accepted tests only
  when the change creates a specific regression risk. Documentation-only changes
  do not require rebuilding/reinstalling the app.

### 4. Deliver and stop

- [x] Provide the final APK path/hash, source commit and any required firmware
  commit/artifact. Distinguish production release from lab re-signing. Existing
  signatures/data preservation do not justify another migration project.
- [x] Write one short final result: accepted features, fresh onboarding outcome,
  actual remaining defects (if any), and the deferred limits below. Link existing
  artifacts instead of copying their full history into this checklist.
- [x] Commit only task changes. Leave the watch originals intact and end owned
  test processes/fixtures. When items 1–4 are verified and no blocker remains,
  mark the revised local Android goal complete and stop. A missing phone leaves
  item 2 pending; do not claim completion or fill the gap with new experiments.

## Deferred — not completion gates for this milestone

- Remote/hybrid AI, provider selection/credentials, remote adapters and uploads.
- iOS; additional local AI backends/models such as physical LiteRT acceptance;
  improvements to existing transcription/classification/prompt quality.
- Long endurance, battery optimization/consumption studies and broad OEM testing
  (user-owned). No agent-run long test or reminder/automation.
- Combined reset-between-result-and-ACK injection, receipt-capacity/storage-full
  injection, further Shell/DFU phase combinations, broad timezone/DST matrices,
  rapid media toggles and exhaustive stale-bond scenarios. Existing narrower
  passes remain narrower passes; these unrun variants are not marked successful.
- Custom-background crop/upload variants and imported-weight inference beyond
  the accepted local models. Nonempty file logs on the current build with the
  filesystem log backend disabled, and unreported network-core image 1.

## Execution limits

A test observer failing is not automatically a product failure. Inspect the same
accepted operation before doing anything else; never recreate/restart it solely
because observation timed out. Allow at most one focused observer repair for a
required case. If still unable to observe it, record the exact missing evidence
and request that single manual action when the user is available. Do not build a
new automation framework, debugger protocol or test fixture catalog to finish.

Use fresh UI state and allow route transitions to settle. Do not infer secure
lock from missing accessibility labels. Never rerun a passed scenario merely to
get cleaner logs or a stronger-looking status. Report deferred cases honestly;
they do not reopen the fixed checklist. The user resumed work on October 8;
the completed checklist is retained as evidence, not a new work queue.
