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

### Shared Dart architecture clarification

User clarification, 2026-10-04: do not build separate Android and iOS AI backends.
Keep transcription, local/remote inference, prompts, interpretation and the
voice-assistant workflow in shared Dart code, reusing the existing services.
Native BLE may start a headless Flutter engine and invoke that shared pipeline.
Platform code owns BLE and OS execution/lifecycle hooks; the existing native job
journal may serve as the Android durability adapter, not as a second copy of AI
business logic. Add only required headless plugin/context bridges. Future iOS
adapters may have different execution windows while calling the same Dart code.

Action review/editing also stays in Dart. Explicitly confirmed OS side effects use
the existing productivity channel, with the native journal recording their status.
Watch result acceptance does not confirm or execute a calendar/Clock action.

### What the review found

The findings below describe the starting point. The 2026-10-05 checkpoint closes
the first local execution/delivery seam; the remaining goal stays active.

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

### OnePlus local voice checkpoint (2026-10-05)

Shared Dart processing now calls the existing transcription engines and LlmService
from a service-owned Flutter engine. Android supplies verified receipts, model
configuration, leases, transcript checkpoints and result/outbox commits. The
existing Flutter Voice Notes view can queue local processing, observe state, open
saved transcript/summary/action drafts, cancel publication and retry. The existing
model selection/download/import screen is reachable again. Opening these screens
does not schedule inference. The automatic-policy checkpoint below supersedes its
initial deferral; action creation remains pending.

The watch advertises `result_ack_version=1` in its recording list. A bounded draft
popup carries the committed result identity/digest/generation; the watch flushes
and atomically replaces a CRC-protected receipt before returning application
acceptance. Identical retries do not republish the popup; conflicting/obsolete
generations fail closed. The new draft popup closes without deleting the original
recording. This receipt does not claim calendar, timer or alarm creation. Current
receipt capacity is 50 recording identities with no silent eviction; capacity
cleanup and rejected-delivery status need completion before final acceptance.

| Requirement | Evidence / state |
| --- | --- |
| Existing audio integrity on OnePlus | Pass: all nine downloaded originals match independent preserved USB SHA-256/size references. |
| Real local inference without Flutter UI | Pass for execution: synthesized Swedish speech uploaded to the watch, downloaded by the native owner, processed by KB-Whisper Base and Qwen3.5 2B Q4_K_M, with transcript/result committed while Flutter's task is absent. |
| Speech quality / real microphone sample | Partial: synthetic speech has milk/tomorrow transcription errors. English sent through the Swedish-only model is not an English acceptance result. Known-content English with an appropriate model and a meaningful microphone recording remain pending. |
| BLE during that inference | Pass for fresh status: same native PID/generation 38, status responses throughout processing. Notification/time/HTTP latency, memory/thermal and longer audio remain pending. |
| Processing time | That 3.88-second synthetic recording commits STT after 4.837 seconds (RTF 1.25); analysis/result commit takes another 71.794 seconds. No tokens/sec or broader model benchmark claim. |
| Watch delivery without Flutter UI | Pass: result survives APK replacement/watch restart; native recovers Ready generation 41 and commits Delivered only after the watch's application ACK. UART records a new durable receipt with successful ACK transmission. |
| Receipt recovery / bounds | Host tests compile the real receipt implementation with Zephyr CRC and POSIX fault injection: partial writes, failed rename, duplicate/reopen, conflict, stale generation, corruption and full capacity. Physical dropped-ACK/reset duplicate test remains pending. |
| Original preservation | Pass: all original 11 files plus both owned speech fixtures match before and after application-only flashing. |
| Product UI | Voice Notes list reattaches and shows Accepted by watch. Detail, model download/import, retry/cancel and action controls need the consolidated UI pass. Cancellation currently fences publication; prompt CPU cancellation is not yet established. |
| Foreground execution | Media-processing service on API 35+, data-sync/local-file processing on API 34; covers STT and LLM. Background admission, OS timeout, Stop/cancel and interrupted inference require further implementation/physical checks. |
| Remaining goal | Automatic watch-triggered processing, action confirmation/undo, other selected inference backends, real remote configuration, release execution, modern feature/recovery pass, transfers and bounded endurance remain pending. |

Evidence: `.companion-hil-runs/20261004-oneplus-voice/`, especially
`local-flow-evidence.json`, `swedish-real-job-observation.json`,
`swedish-delivery-observation.json` and `receipt-fw/`. Private audio/transcript/result
artifacts stay outside Git. Tested normal debug APK SHA-256:
`8f709b75c68aa24a9443cbbd84698d2e9c00328348599e7dfa8ee6fb932976f5`;
flashed signed application HEX SHA-256:
`e73c3fdcab719bfbb2ce148f7f9ef104ec4ebea87bdf0c3c3dd011ded04e8d84`.
This was debugger flashing, not a OnePlus OTA throughput test. Direct USB receipt
file inspection was not completed: its private path exceeds the mcumgr FS path
bound and the filesystem shell is disabled. Do not reopen SMP diagnosis for that
optional probe. Physical ACK/UART evidence and the receipt host tests are separate.
Checks: 47 focused Flutter tests, 12 native job/result tests, receipt host regression,
focused Dart analysis and normal debug/WatchDK builds pass. Release inference and
the full modern-phone acceptance matrix remain pending.


### Automatic processing and firmware list checkpoint (2026-10-05)

The existing Flutter model screen now has an explicit local automatic-processing
switch for the selected watch. New recording metadata captures the selected STT,
LLM and correction setting at discovery. Already known recordings are not enrolled
retroactively; already accepted requests keep their configuration if preferences
change or the switch is disabled. Failed/cancelled automatic jobs are not recreated
on every maintenance tick. Manual retry can unblock OS admission failures. The
legacy batch button reading the old voice database is withheld on Android; native
receipt-backed manual processing remains available in Voice Notes.

Android waits for foreground admission before dispatching Dart execution. Denied
admission blocks the job instead of crashing the BLE owner. The media-processing
OS timeout stops its service and notifies the native owner; stopping no longer
starts an empty service. Expired local claims have a bounded retry count. These
are implementation/host checks, not a physical OS-budget or prompt-cancellation
pass. The existing LiteRT-LM bridge is registered in the headless engine and
closed with it; actual LiteRT inference is still pending a model and physical test.

The physical automatic test exposed a real firmware bug: new-recording events
arrived, but a 14-recording list failed in cJSON_PrintUnformatted on the 6144-byte
libc allocation arena. Recording lists now use a bounded transient kernel-heap
buffer and a portable encoder, retaining the same JSON contract. Host tests cover
all 50 ordinary maximum-length filenames with full uint32 values, escaping, empty
lists and rejection of insufficient capacity/unterminated filenames. The matching
WatchDK build and targeted debugger flash pass; all 16 pre-flash reference files
match independent post-flash SHA-256/size checks. No filesystem or network-core
image was programmed.

| Requirement | New evidence / state |
| --- | --- |
| Explicit automatic local processing | Pass: Flutter switch durably saves KB-Whisper Base + Qwen3.5 2B Q4_K_M, correction off, scoped to the paired watch. |
| Actual start with no recent Flutter Activity | Pass: the owned reminder speech fixture is discovered, verified and claimed about 21 minutes after task dismissal. The OnePlus already ignores battery optimization; CDM association remains absent, so this does not establish admission without that exemption. |
| Complete automatic result roundtrip | Pass for the synthetic reminder fixture: one real STT/LLM attempt, result persisted, watch application ACK and Delivered, with Flutter absent throughout. Synthesized audio is not microphone-quality acceptance. |
| Integrity and timing | Phone receipt matches independently generated/uploaded fixture SHA-256. Observed transcript checkpoint is 2.165 seconds after sampled claim; observed Delivered is 80.098 seconds after claim. Two-second polling gives approximate boundary times, not exact inference benchmarks. |
| Model quality | Partial: reminder summary is köpa mjölk, while transcription still mangles tomorrow/milk. A different note fixture was mistranscribed and rejected by the existing AI no-speech/router policy; do not count it as a semantic success. |
| BLE during automatic processing | Same native PID throughout. SMP preparation causes reconnects (generations 99–101); fresh status continues after Ready 101 during analysis. This does not establish uninterrupted transfer/inference latency for every feature. |
| Original preservation | Pass: all 16 backed-up watch files match after the application-only flash. Later owned fixtures/short microphone triggers are retained and not used as meaningful speech-quality evidence. |
| Checks | 49 focused Flutter/interaction tests, 17 native job/policy/result tests, three real-encoder host tests, focused Dart analysis, debug APK, release APK and WatchDK builds pass. |
| Release / process recovery | Pass for real synthetic speech: non-debuggable release code resumes the same interrupted job, performs STT/LLM and receives watch application acceptance with Flutter absent. Mid-inference recovery remains pending. |
| Remaining acceptance | Meaningful microphone/English audio, prompt CPU cancellation and mid-inference interruption/Stop, action confirmation/undo, physical lost ACK, LiteRT, real remote provider, full feature/OTA/resource matrix and quiet/endurance checks remain pending. |

Evidence: `.companion-hil-runs/20261005-oneplus-auto-voice/`, including
`automatic-flow-evidence.json`, `observation.json` (failed note quality),
`reminder-observation.json` (successful execution/delivery), and `list-fw/`.
Successful installed debug APK SHA-256:
`9ba78dcee80b1c2cec8e07bdd6e570853b012f48ffc103516fc17515a4f19628`;
flashed signed application HEX SHA-256:
`950e012606e1816b744a2ed6c97e95b9bea837ce6b4820842189d3cbb8fcbb97`.
Release testing exposed a real FFmpeg JNI initialization crash. The plugin's
retention rules are library proguardFiles, not consumer rules; the application
now explicitly retains com.antonkarpenko.ffmpegkit classes and members. The fixed
release mapping preserves the JNI surface. Local leases from a dead process are
fenced once when the new Android process opens its job journal, allowing immediate
resume while retaining any saved transcript and the bounded attempt count.

The fixed release-code smoke now creates a headless engine, runs actual processing,
commits a result and receives a new durable watch receipt/ACK with Flutter absent.
The foreground notification/service and wake lock are released afterward, and
the observed native PID stays constant. The non-debuggable APK is a lab-signed
copy used solely to preserve installed data; production release code is unchanged
by that signing operation. After returning to debug, the persisted release job has the same job ID/spec/input
as before the crash, attempt 2 instead of 1, a saved transcript/result and Delivered.
Its phone receipt matches the independent USB speech fixture hash. New-process
recovery thus runs the interrupted job without creating a new generation. This is
a physical interruption before transcription; mid-inference/checkpoint interruption
and prompt cancellation still require their own tests.
The release test is not an OS-budget, unplugged or full modern-feature pass.

Firmware fix commit: 698026e0. Fixed production release APK SHA-256:
87d2a50f081da1b2d633d510b9da0a49b955fa05962938144b6dec9ea468bd84;
physically tested non-debuggable lab copy SHA-256:
53fcc575805f9af91ebb81490ad53bc44d3fa187584b61a620366c927002f828.
Private release crash, recovery and acceptance evidence is retained under
release/ and release-fixed/ in the same run directory. release-flow-evidence.json
contains the post-debug cross-check. The final logcat buffer retained completion
only; startup engine/ready lines were observed in tool output and are recorded
with that provenance in startup-tool-observation.json. Final debug APK SHA-256:
c5f1400dc85e0aa718c4427945f6e5b0c57fb0173221a8b825413f4d06533110.
The phone returns to native Ready generation 108 after restoring debug. A Weather
trigger was attempted during inference, but the retained HTTP success belongs to
generation 108 after restoration; it does not establish HTTP latency during AI.

### 2026-10-05 action review and calendar acceptance checkpoint

The existing Flutter Voice Notes result view now offers shared Dart review/editing,
calendar choice, explicit creation, dismissal and calendar Undo. It reuses
`ActionCreationDraft` and `ExtractedActionCreationService`; no second AI backend
or database was added. The native job journal stores confirmed drafts and action
status separately from processing and watch delivery. Reopened calendar creation
uses the original confirmed input and an event ownership token. Event/reminder
insertion is one provider batch. Clock requests are marked Dispatched, with no
claim of OS acceptance or app-controlled Undo; interrupted dispatch is not retried
automatically. Alarms reject dates beyond the next occurrence supported by Clock.

Physical OnePlus evidence is retained privately under
`.companion-hil-runs/20261005-oneplus-actions/`. The result came from the prior
actual local STT/LLM run of the watch fixture `hil_ai_f2c75842ee02`.

| Area | Result and limits |
| --- | --- |
| Calendar creation | **Pass, local provider.** Edited title, October 6 at 09:00 local time, one event and one zero-minute reminder independently queried from Android. Cloud synchronization remains unverified. |
| Process restart | **Pass after creation.** Force-stop followed by explicit app launch retains Created state and exactly one owned event; BLE recovers to Ready. This does not prove killing between insert and journal commit. |
| Calendar Undo | **Pass.** An initial physical failure required using the collection URI with an ID/ownership predicate. Retrying the saved Undo operation removes both event and reminder; independent queries return no rows. The final view shows Removed. |
| Preservation | **Pass for this action test.** All 18 recording receipts, job input/result/transcript/state and watch delivery outbox compare identically before and after; only action metadata changes. No audio deletion was requested. |
| Checks | 11 focused Flutter tests, 15 native job tests, focused Dart analysis and debug/release builds pass. Tests cover confirmation cancellation, double taps, confirmed edits, dates/timezones, ambiguous Clock dispatch and journal reopen/reprocess recovery. |
| Pending | Real timer/alarm dispatch and interpretation, additional microphone/English/longer audio, inference cancellation/Stop/interruption, LiteRT, real remote configuration, lost ACK, OnePlus feature/transfer matrix and controlled endurance. Latest action code has release build coverage; physical release action execution remains pending. |

Android provider references: [event ownership columns](https://developer.android.com/reference/android/provider/CalendarContract.EventsColumns),
[CalendarProvider deletion handling](https://android.googlesource.com/platform/packages/providers/CalendarProvider/+/master/src/com/android/providers/calendar/CalendarProvider2.java),
and [Clock intent contract](https://developer.android.com/reference/android/provider/AlarmClock).

### 2026-10-05 inference recovery and English engine checkpoint

| Area | Result and limits |
| --- | --- |
| Mid-analysis process loss | **Pass, debug OnePlus.** SIGKILL during real local analysis (Dart worker observed using CPU) restarts the native service without launching Flutter. The same job/spec/input and saved transcript resume as attempt 2, reaching Delivered with application ACK. Observed restart/resume is about 11.5 seconds; Ready generation 116 remains stable during resumed analysis. This is injected process death, not natural OS reclamation or package force-stop. |
| English transcription engine | **Format fix passes.** Built-in Tiny English previously passed Ogg to a WAV-only API, which returned null and was mislabeled no-speech. Both existing Dart Whisper engines now prepare isolated mono 16 kHz PCM WAV files and clean only their own scratch files. Null engine responses raise an execution error. Real Tiny English inference now saves a nonempty transcript after Flutter closes. |
| English semantic acceptance | **Still failed.** The 4.14-second synthesized timer fixture is mistranscribed (including the duration); the existing LLM router returns none. No timer is created. This is not an English timer, microphone-quality or silence-policy acceptance pass. Its 9,759 phone bytes independently match the uploaded fixture SHA-256. |
| Model status UI | **Fixed and physically checked.** Selected-model changes invalidate downloaded/size metadata; the existing Flutter model view now reports the installed Qwen model correctly. A regression test changes selection while retaining the same service instance. |
| HTTP during inference | **Not run successfully.** One attempt missed the inference window; another reached the watch before its asynchronous app-close returned to the watchface. Neither establishes concurrent HTTP latency. Earlier standalone OnePlus Weather evidence remains valid. |
| Checks | Eight focused Flutter tests, focused Dart analysis and debug/release builds pass for the WAV/model-status changes. The corrected English flow is physically tested on debug; release engine execution remains covered only by the earlier Swedish release run. |

Private evidence: `.companion-hil-runs/20261005-oneplus-timer-recovery/`,
including `recovery-evidence.json`, `phone-copy-evidence.json`, `english/`
(WAV-format failure) and `english-fixed/` (saved transcript, model rejection).
Corrected debug APK SHA-256:
`539b576b9fecd81c47460d9c96e074152415dddde4d8aa51d5ee3aebb2441a76`;
compiled release SHA-256:
`c12a1bd872a18d1f5f6690df247eb3c55da23a698bc301d671f67a5b672e434e`.
The automatic policy still selects KB-Whisper Base for Swedish; the English model
was selected only for the explicit fixture retry. Prompt CPU cancellation/Stop,
meaningful microphone and longer audio, timer/alarm semantics, LiteRT/remote,
physical lost ACK and the full OnePlus feature/update/endurance matrix remain
pending. The goal remains active.
