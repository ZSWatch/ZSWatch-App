# Finish the Android companion refactor

Authoritative user direction, 2026-10-04. This short checklist supersedes earlier
staging, compatibility and work-order recommendations in the background plan and
progress review. Keep the existing Flutter UI; finish the native Android owner.
Continue on `codex/companion-background-foundation` and commit completed work.

## Next goal: OnePlus voice processing and Android acceptance

User direction, 2026-10-04. The earlier Nokia implementation milestone is
complete. This section defines the next goal and supersedes earlier AI deferral
and pairing-first suggestions for Android. iOS remains deferred. Use the existing
OnePlus NE2213 (Android 16/API 36, ADB `ae49cb83`), watch and current branch.
Keep the existing Flutter UI and the single native companion owner.

### Goal text

Complete the remaining Android voice-note and AI integration in ZSWatchApp and
validate the native companion on the OnePlus, following the OnePlus goal in
ANDROID_COMPANION_FINISH_PLAN.md. Prioritize a real watch recording → verified
phone copy → local transcription → local AI → persisted result → acknowledged
watch delivery flow that runs without an open Flutter UI. Reuse the existing
Whisper/LLM code, user-modified libraries, durable job/outbox contracts and Nordic
SMP SDK. Restore the existing voice/model/result controls through the native
owner. Keep local, hybrid and remote processing choices explicit; integrate and
validate real remote processing when a provider, credentials and upload consent
are available, recording any dependency separately. Verify the existing features
on the newer phone, BLE responsiveness during inference, interrupted-work
recovery, firmware transfer performance and a release-build smoke test. Fix
actual app/firmware blockers, preserve watch originals, and commit completed work.
Pairing cleanup follows the main functional work unless it blocks progress.
Avoid a new native UI, legacy fallback, custom SMP, broad model benchmarks or iOS
work. Finish with one evidence-backed pass/fail/pending matrix and clear limits
for externally blocked or physically unavailable tests.

### What the review found

- The service-owned headless Dart worker is implemented as a deterministic
  fixture. Real Whisper/LLM plugin execution was deliberately never run on Nokia.
- Native recording receipts and Flutter import/playback exist, but recordings
  are not connected to the production processing/job/result chain. Downloads
  were paused in the final Nokia core tests. Earlier audio transfers sometimes
  differed from independent USB hashes; do not assume the OnePlus fixes this.
- The native app currently withholds the old AI-model settings and voice detail/
  action routes. Source/model availability is not working product integration.
- The remote job adapter tested recovery against a synthetic loopback backend;
  it is not a real audio/text provider integration. Current watch result handling
  lacks the job contract's application ACK and durable duplicate suppression.
- GPS/Weather already passed on the OnePlus with Flutter destroyed. Nokia firmware,
  filesystem and core passes remain useful evidence, but do not establish modern
  Android inference, OEM background behavior or unplugged endurance.

### Work order and acceptance

1. **Deliver a small real local flow first.** Check existing model files and actual
   phone RAM/storage; choose one practical existing STT model and one existing
   LLM, initially supporting short Swedish and English samples. Use known-content
   speech fixtures for repeatable assertions plus a real watch-origin recording.
   Verify downloaded bytes against an independent USB reference and decode/play
   them before blaming model output. Bound any integrity diagnosis to what blocks
   this flow; use the user's Nordic fork, not a replacement transport. Preserve
   source audio and originals; use only owned temporary fixtures for deletion
   tests. Run one short headless-engine/plugin check, then connect real inference.
   A precomputed transcript or deterministic fixture is not an inference pass.

2. **Make the flow an ordinary app feature.** Native owns discovery/download,
   committed recording identities, scheduling, job state and result delivery.
   Reuse the existing Dart transcription/LLM/parser code behind a minimal
   headless worker, registering only necessary plugins and no second BLE owner.
   Reconnect existing Flutter model selection/download, transcript/summary,
   playback, processing/retry/cancel and action controls to this state. Do not
   start models just because a dashboard opens or BLE reconnects. Allow explicit
   automatic processing policy, and persist enough input/configuration to retry
   after interruption. Reuse the existing journals rather than building another
   job framework or compatibility layer.

3. **Close the result and action boundary.** Deliver a real result to the watch
   through its existing voice-result UX, adding only the bounded firmware
   capability/receipt/deduplication support actually required. Persist before
   sending; require watch application acceptance before marking Delivered.
   Reconnect or lost ACK must not create duplicate reminders, timers or alarms.
   Restore existing confirmation/undo behavior where implemented. Validate notes,
   reminders/events and timer/alarm interpretation, including Swedish/English
   relative times and timezone handling. Draft/action extraction, watch receipt
   and actual calendar/alarm creation are separate acceptance results. Use owned
   test items and cleanup; record any permission or platform limitation rather
   than calling an unsupported external action complete.

4. **Support remote choices without blocking local progress.** Keep local STT,
   remote STT/audio analysis and local/remote text analysis as separate choices.
   Local STT plus remote text analysis does not accelerate transcription. Use
   existing durable jobs for adapters; start with one selected provider, not a
   new backend server or a catalog of providers. Test upload/submission, real
   result parsing, retry/cancel, offline/credential errors and watch delivery.
   Ask for provider/credentials/upload authorization only when necessary, while
   continuing local and core work. No automatic local-to-cloud fallback. A
   fixture can validate the adapter contract while configuration is missing,
   but real remote inference stays explicitly pending until actually exercised.

5. **Protect BLE while processing.** Initially serialize heavy model work. Measure
   STT elapsed time/real-time factor, LLM elapsed time/tokens per second, memory,
   thermal/battery behavior and response latency of notification/time/status and
   a bounded HTTP request during inference. Unload models when appropriate.
   Test short and one longer recording, silence/malformed input, cancellation,
   missing model/storage and process interruption at meaningful boundaries.
   Completed transcripts/results survive; interrupted inference may restart
   from saved input. Explicit companion Stop remains respected. Choose Android
   execution/scheduling and foreground-service types for the actual processing
   task; a connected-device service alone is not proof of inference lifetime.
   Android 16 long-running WorkManager work can consume job quota even with a
   foreground service ([official documentation](https://developer.android.com/develop/background-work/background-tasks/persistent/how-to/long-running));
   service types have their own prerequisites/budgets
   ([official documentation](https://developer.android.com/develop/background-work/services/fgs/service-types)).
   Choose the smallest supported execution path; introduce a separate process
   only if measured interference or crash isolation requires it.

6. **Run one consolidated OnePlus feature pass.** Cover ordinary Flutter connect/
   saved watches/disconnect, notifications (receive/update/dismiss), fresh time/
   timezone, Internet policy/error recovery, GPS/Weather, media metadata/control,
   Find Watch, recording discovery/download/playback/processing, Shell, log files,
   watchface gallery/custom image and firmware/resource selection/progress.
   Include outstanding Nokia cases: a nonempty log download checked independently,
   relevant changing-file/cache isolation, Shell UI destruction and transfer/DFU
   arbitration, watchface interruption/reattachment, and a real third-party media
   player rather than only a synthetic MediaSession. Exercise what the shipped
   UI actually supports; protocol enums and legacy placeholders for Find Phone,
   calls/activity/navigation are not instructions to invent new products. Record
   each absent/unsupported feature and decide any newly discovered real regression
   against the pre-refactor behavior.

7. **Verify updates and modern lifecycle, then finish.** On OnePlus, measure a
   real board-matching application upload before another large filesystem test.
   Record negotiated connection parameters, MTU/window/buffers, acknowledged
   active upload speed, reboot/image verification and native recovery. The
   accepted 17.6 KB/s remains a practical floor and old-app 20 KB/s+ a comparison;
   investigate only a material regression, with one same-phone comparison if
   needed. Then run one resource/combined path with deliberate integrity checking
   and Flutter closed; reuse Nokia evidence and backups, avoiding repeated huge
   downloads. Keep unavailable network-core image 1 verification explicit.
   Run bounded radio/out-of-range/watch-reset recovery, process interruption,
   Stop persistence, UI reattachment and one phone-reboot case where unlock is
   available. Test one screen-off quiet period with real network requests and
   queued AI work, followed by one approximately eight-hour endurance window after
   functional fixes. Record physical power and OnePlus battery settings; USB or
   forced idle does not prove unplugged operation. Prepare wireless ADB before
   physical phone disconnection if available; save evidence locally during a
   cable-free interval rather than requiring continuous polling. Do not disable
   battery optimization silently. Intentional Android force-stop is reported
   separately from recoverable process interruption and ordinary task dismissal.

### Completion and iteration rules

The main deliverable is a working real local voice/AI round trip in the ordinary
app with Flutter absent, durable results and no observed loss of core BLE service
under the tested workloads. Restore the existing UI features needed to use it.
Run affected tests/builds after meaningful changes and verify the headless entry,
plugins and one physical AI/core smoke in release, since debug fixture execution
alone does not establish a shipping build. Record model/artifact versions and
latency, without spending this goal optimizing every model or chasing maximum
throughput. Keep one short pass/fail/pending matrix in this plan.

After main functionality and the consolidated pass, address the pairing/recovery
rough edge with one reproducible scenario and a focused fix. Do not require
repeated unpair/reset rituals for normal use; if it blocks the main flow, move
only that blocking correction earlier. Do not repeatedly rerun unrelated suites
or extend tiny diagnostics while larger deliverables remain.

Report remote-provider configuration, unavailable image targets or physically
unavailable unplugged/reboot tests as specific pending acceptance, never as
passed. A local milestone may be complete with those explicitly separated; do
not describe all remote or endurance behavior as complete. iOS is outside this
goal. Preserve unrelated changes and all original watch audio/background/crash
files; use targeted firmware flashing and existing test tools.

## Earlier Nokia goal wording (completed milestone)

Finish the Android native companion refactor in the existing Flutter app. Make
native ownership the normal Android path in all build modes and remove the
legacy Android owner/selection flag. Choose the next work by actual dependencies
and remaining functional gaps. When completing updates, first make real Nordic
firmware uploads reliable and measure their active upload speed before attempting
larger filesystem and combined updates. The user accepts 17.6 KB/s on the Nokia
after the final 7.5 ms test; the old app's 20 KB/s+ remains a reference. A one-time app database/settings reset and
fresh permission setup are allowed instead of compatibility migration. Finish
the existing non-AI features and a practical consolidated background/recovery
check. Preserve the user's library fixes, unrelated work and watch originals.
Use the existing Nordic SDK, fix encountered watch-firmware bugs and verify them
with the available debugger/flash tools, defer iOS/AI, and avoid peripheral
investigations.

## Decisions already made

- This is one direct refactor for a small private user base. No staged rollout,
  legacy Android runtime fallback, dual-owner feature flag or backward-compatible
  database migration is required. Do not build those systems.
- Existing phone databases/settings may be reset on upgrade if that simplifies
  the implementation. Use a one-time reset only where needed, not a reset on each
  launch. A fresh permission/association setup is acceptable. Runtime durability
  after the refactor still matters; this does not authorize deleting watch audio
  or flashing over unrelated watch storage.
- Retain shared code still needed by Flutter UI or the deferred iOS path. Remove
  obsolete Android ownership paths; avoid unrelated mass renames or cleanup.
- The user's old-app firmware upload baseline is about 20 KB/s or better. This
  is an upload baseline, not a claimed filesystem download/readback speed. The
  user subsequently accepted 17.6 KB/s on the Nokia after one final 7.5 ms test.
  Do not keep throughput as a blocker or repeat speed experiments once that
  test is recorded.
- Fix encountered watch-firmware bugs as normal implementation work. The user
  authorizes building, flashing and debugging the connected watch; the known HTTP
  callback bug should be fixed, not merely documented. Use the verified board and
  existing targeted flashing tools, preserving unrelated watch storage. Firmware
  update throughput is a requirement for that feature, not a command to work on
  that feature next.
- No development freeze. Record the APK/firmware revision used for each relevant
  hardware result; continue editing and building normally.

## Earlier Nokia work order (historical)

Use this order as a practical default; finish prerequisites and active changes
where that is more efficient. Firmware upload validation precedes large resource
tests, but firmware updates are not required to be the immediate next task.

1. **Complete the direct Android cutover.** Enable the native owner in normal
   debug/profile/release builds; remove `COMPANION_RUNTIME_PROTOTYPE` as a runtime
   choice and remove obsolete Android BLE/service startup paths. Move required
   permissions, receivers and service declarations into normal Android builds;
   keep lab instrumentation and synthetic fixture triggers out of normal release
   execution. Retain the existing Flutter screens and connect remaining real
   consumers. Use clean app storage/setup where needed instead of migration,
   shadow-storage compatibility or rollback machinery.

2. **Close the core functional work.** Notifications, time, HTTP, reconnect,
   saved-watch setup, media, location/weather policy and voice-note acquisition
   must use the native owner. Preserve already working implementations. Fix the
   small known HTTP error/empty/late-response callback contract in watch firmware,
   build and flash the matching target, and verify the real consumer. Apply the
   same approach to other firmware bugs encountered during the refactor. Keep recording
   integrity visible as a non-AI check; do not resume an open-ended corruption
   investigation on the Nokia. Actual local AI and iOS remain deferred. Retain
   local/remote processing integration points without building new AI features.

3. **Firmware updates and throughput.** Use the existing Flutter firmware
   screen, the user's Nordic fork settings/fixes and the native service owner.
   Select a valid, board-matching firmware artifact and verify that Nordic actually
   uploads it; an already-active-image shortcut is not a throughput result.
   Measure acknowledged payload bytes over the active upload interval, separately
   from preparation, reboot and reconnect. Check representative sustained speed
   against the accepted Nokia rate of 17.6 KB/s before large resource updates.
   The 20 KB/s old-app figure remains a reference, not a Nokia acceptance gate.
   If below the accepted rate, compare the
   actual SDK MTU, upload window, connection priority, logging and handoff with
   the working old path. Reuse an existing baseline artifact or a separate old
   checkout if a same-phone comparison is necessary; do not retain a fallback
   owner in the refactored product. Confirm reboot and normal companion recovery,
   using the SDK's existing image evidence. Keep any unavailable image-index
   verification explicit. Do not write a new SMP implementation or hide slow
   transfer by increasing deadlines.

4. **Filesystem images and combined updates.** Preserve the already-written
   resource code; review/commit it without claiming a physical pass. Run the larger
   real resource test only after firmware upload performance is established.
   Check resource upload and verification rates separately. Simplify redundant
   full-image readbacks where justified: a normal update need not automatically
   download the entire multi-megabyte image twice. Keep a deliberate integrity
   check and the original resource backup for the lab test. Size alone is not
   an integrity check. Use measured rates for sensible deadlines. Combined
   resource-first/firmware-second work must remain service-owned when Flutter
   closes. Test the required reset/reconnect using the existing Nordic library.

5. **Validate the finished app, then stop expanding scope.** Run affected tests
   while implementing and one consolidated physical smoke/recovery pass covering
   core features with Flutter absent, UI reattachment, radio/process recovery,
   Stop intent and ordinary reconnects. Include a longer background/quiet-period
   run once the implementation works; it is not a gate before every feature or
   a reason to stop implementation now. Record real power/network conditions and
   device limitations. No repeating whole suites or rebuilding both legacy/native
   variants after the legacy owner is removed. Fix actual blockers, commit the
   result, and report any hardware-dependent acceptance still outstanding.

## Completion and working discipline

Done means the normal Android app uses one native companion owner with the
existing Flutter UI, real firmware/filesystem workflows have appropriate evidence,
firmware upload speed meets the agreed baseline or has a concrete documented
hardware limitation, and the consolidated core checks pass. Do not silently count
unverified transfers or deferred hardware tests as passed. Longer release-scale
soaks and newer-phone/iOS/AI validation are reported separately, not used to invent
new implementation work indefinitely.

Use targeted source reads and one short pass/fail/pending list. Preserve existing
evidence; stop duplicating checkpoint narratives into multiple long documents.
Ask for input only when required information or authorization actually blocks the
next useful step. Do not ask again about accepting a clean phone database/setup.

## Current checks (2026-10-04)

- Direct cutover implemented: normal debug/profile/release builds compile; 205 native
  and 158 companion Flutter tests pass. Ordinary debug APK on Nokia reaches Ready,
  remains connected with launcher visible, reattaches the same generation, and
  Flutter Disconnect settles Stop with the service absent. Evidence:
  `.companion-hil-runs/20261004-direct-native-cutover/`.
- HTTP firmware callback fix committed as `d634b4cb`: sanitized host controller/parser
  regression and WatchDK build pass. Normal native APK with Flutter absent passes
  real success, empty and relay-error replies exactly once, observed beyond timeout.
  All nine recordings, crash file and original background verified/restored exactly.
  Evidence: `.companion-hil-runs/20261004-http-callback-contract/`.
- Firmware update passes on the Nokia: acknowledged active upload is 17.75 KB/s
  (836,352 bytes uploaded), followed by reboot, fresh active-image verification and
  normal native Ready recovery. The requested 7.5 ms settles at 11.25 ms during
  the sustained transfer; it provides no meaningful gain over 17.6 KB/s. Accepted
  by the user; stop investigating throughput and continue resource work. Fixed
  the watch's idle downgrade during SMP (`f49acb08`), boot connection retry and
  cold SMP discovery recovery (`fe61d1c`, `c4e22b2`). Nordic window 3, MTU 247,
  merged packet 2,475; no competing Android HIGH request. Firmware `0517911f`
  requests 7.5 ms with a 4-second supervision timeout. All 11 original files
  match after targeted flashing and after the completed OTA update.
  Evidence: `.companion-hil-runs/20261004-ble-7p5/`. Native tests: 208 pass.
- Resource postflight now checks the freshly mounted image length after reboot,
  following one complete SHA-256/layout readback before reboot. This avoids a
  second multi-megabyte download; native regressions still require full integrity
  verification before reset/firmware starts. Debug build and 208 native tests pass.
- Physical resource-only update passes: all 5,932,208 bytes uploaded and fully
  hash-verified (14.8 KB/s upload, 14.3 KB/s readback), then acknowledged reset,
  fresh mount check and native Ready. Flutter's task was destroyed during upload;
  all 11 original files still match. Evidence:
  `.companion-hil-runs/20261004-resource-physical/`.
- The next package selection exposed an undismissed filesystem result in Flutter.
  Fixed the shared result dismissal; the focused firmware Flutter suite passes
  19 tests, including terminal dismissal and visibility of subsequent active work.
- Combined resource-first/firmware-second update passes with Flutter destroyed:
  5,932,208 resource bytes uploaded and fully hash-verified, then a distinct
  836,352-byte application image uploaded, rebooted and verified active. Fresh
  resource mount and normal Ready recover. Measured stages: 14.6 KB/s resource
  upload, 14.4 KB/s readback, 16.2 KB/s firmware in this combined run. Evidence:
  `.companion-hil-runs/20261004-combined-physical/`.
- Postflight now has the same 90-second bound for firmware/resource packages;
  the full resource readback finishes before reboot. Final debug/release builds
  compile and 208 native tests pass. The physical combined postflight recovered
  within that bound.
- Final normal-debug core pass with Flutter absent: real notification body reaches
  the watch, HTTP completes exactly once beyond its timeout, watch Next/Play
  controls affect a real Android MediaSession, current time is written and the
  fresh recording inventory matches all nine watch files. All originals retain
  their verified hashes. Radio recovery, injected Android app-crash recovery
  (`adb am crash`, not OS memory reclamation), persisted Stop through radio
  changes and explicit restart pass on the final APK. Evidence:
  `.companion-hil-runs/20261004-final-core/`.
- Final quiet/UI pass: the same native PID/session remains Ready for 20 minutes
  in Android forced deep idle with Flutter absent, and a subsequent notification
  is observed at the watch. The existing Flutter dashboard then reattaches to
  that session and shows Connected / MTU 247. Phone and watch are USB connected;
  forced idle is restored afterward. This is bounded lab acceptance, not a claim
  of unplugged endurance or natural OS memory reclamation. The checkpoint is
  `.companion-hil-runs/20261004-final-core/final-checkpoint.json` (tested debug APK
  SHA-256 starts `db4bae16`; compiled release starts `6adf2495`).
- The finish checklist is complete for the available Android rig. Remaining
  hardware acceptance is separate below; do not reopen throughput or add legacy
  compatibility machinery.
- GPS/Weather follow-up: the user authorized real location transmission. Opening
  Weather with Flutter absent produced a real Nokia position observed at the
  watch, then stopped location acquisition. Wi-Fi was disabled; enabling it
  restored Internet. The subsequent real forecast exposed a firmware JSON
  allocation problem. `3c8ba743` releases the HTTP envelope before synchronous
  consumer parsing; the bounded-memory regression fails before/passes after,
  sanitized controller/parser tests and WatchDK build pass, and the application
  fix is flashed without increasing RAM. A new post-flash GPS fix did not arrive
  within the existing 10-second acquisition deadline in bounded Nokia retries.
  The OnePlus follow-up below resolves full post-fix Weather acceptance. Evidence:
  `.companion-hil-runs/20261004-gps-weather-real/`.
- OnePlus NE2213 / Android 16 (API 36): the same normal debug APK (`db4bae16`)
  reaches fresh native Ready, MTU 247 and current status/time. With Flutter's
  task destroyed, opening Weather requests a fresh phone position; watch UART
  confirms its receipt, the real HTTP reply completes, and the watch's parsed
  weather structure reports 13°C / Overcast. Acquisition stops afterward;
  the native PID and generation remain unchanged. No parser error recurs with
  firmware `3c8ba743`. Coordinates are redacted from saved logs. This is a real
  Internet/phone-location test, with phone/watch connected by USB, not unplugged
  endurance. Initial phone handoff timed out repeatedly and the user reports
  unpair/re-pair, reopening connection controls and resetting the watch before
  pairing succeeded; clean onboarding/recovery from stale bonds is unresolved,
  and the successful runtime test does not establish that onboarding passes.
  Evidence: `.companion-hil-runs/20261004-oneplus-weather/`.
- Separate hardware acceptance: clean modern-phone pairing/recovery, unplugged
  endurance, iOS and AI execution. This rig
  reports image indices 0/2; selected network-core index 1 remains explicitly
  unverified rather than being silently counted as a full-package pass.
