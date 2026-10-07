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

### Current OnePlus acceptance matrix (2026-10-07)

Use this matrix to select remaining work. The detailed checkpoints below retain
artifact identities, measured scope and earlier failed attempts.

**User direction, 2026-10-07:** do not run any more eight-hour tests. The user will
perform endurance acceptance later. This supersedes agent-run endurance gates in
this plan and the active goal; continue implementation and short functional/
recovery tests. Record longer endurance as deferred to the user, never as passed.
Do not launch or schedule another long observer as a completion step.

| Requirement | Current authoritative status |
| --- | --- |
| Real microphone → verified bytes → shared Dart local STT/AI → persistent result → watch ACK | **Pass for natural Swedish milk/reminder recording**, plus byte-identical replay. Headless boundaries and matched application ACK verified. |
| Short Swedish/English and longer input | Swedish pass. English Whisper Base + Qwen and a 37.8 s replay of real microphone audio complete real headless processing/persistence/watch ACK in release. English duration is transcribed correctly; brand name and longer Swedish transcript have errors. Timer classification remains an existing AI-quality limitation, explicitly deferred by the user on 2026-10-05; do not tune prompts/models for this refactor. |
| Existing Flutter UI / single native owner | Real transcript/summary/action review, ordinary Process dedup and actual audio playback pass. Original audio retained. Release missing-model retry and reuse of an older successful result after a newer failed model pass; selected transcript/summary persist across Flutter task removal/reopen without compute service. Common Settings (DFU screen preference, About/licenses and coredump server URL) and calendar/Clock controls are restored; ordinary downloaded-model metadata and calendar picker pass physically. Explicit settings persistence/permission navigation pass in host tests. Ordinary import, persistence after Flutter teardown/reopen and deletion pass for an owned 128-byte metadata-only GGUF fixture. Original Qwen selection and real downloaded models remain; this does not establish imported-weight inference. |
| Action confirmation / side effects | Real release local-calendar Create/Undo passes for owned entry ZSWatch_HIL_release_20261005; Calendar independently shows tomorrow 09:00–09:30 and app confirms removal. Original transcript/audio retained. Existing explicit Clock test controls physically create a real 30 s timer and +5 min alarm at 17:40 in Google Clock; owned posts are removed and other entries retained. This is actual OS dispatch from the shared productivity bridge, not a real inferred voice timer/alarm or native action-receipt physical pass. Offset-preserving draft tests pass. Ordinary Sync Time now passes independent hardware-RTC readback at the phone’s UTC+02:00 offset, with Flutter subsequently absent; other timezone/DST transitions and voice timer/alarm receipt coverage remain separate pending cases. Existing model misclassification does not authorize AI-quality work. |
| Durable result / dedup / interrupted work | Real watch application ACK, job reuse and process-loss recovery with saved transcript pass. A fresh result exposed a firmware sysworkq stack overflow; c8f05d09 fixes it. The already committed phone result then delivers with Flutter absent and the same PID, without rerunning AI. Deliberately lost ACK now passes on fixed firmware: one durable-new ACK omitted, native retry receives duplicate ACK after 10.544 s, normal UI Accepted by watch, same PID and Flutter absent. The earlier failed debugger attempts remain recorded separately. Receipt capacity and independent reset/replay scenarios remain separate pending coverage. |
| Cancellation and invalid/unavailable inputs | Real GGUF cancel and Stop pass. LiteRT channel cancellation: four controlled-callback regressions pass, actual model unavailable. Release real Whisper Base STT cancellation on the owned 37.8 s fixture passes before transcript/result persistence: native abort log, Cancelled UI, compute service gone at the first 2.425 s observation, same PID and 22 watch originals retained. Existing Retry processing control and missing-model case pass in release: selecting undownloaded Whisper Small English gives Processing failed / Reason: model_missing without a new transcript or result; 23 phone receipts remain. Owned truncated-container physical acceptance passes: Download failed before processing/playback, no compute service, watch source retained until explicit owned cleanup, same PID. A subsequent remote HTTP request times out (status 1), so the overall observer remains failed while this file-validation scope passes separately. Real headless Whisper Base English no-speech handling now passes for an owned 3-second silent Opus fixture; storage-failure physical coverage remains pending. |
| BLE under AI load / resources | Actual prompt-time watch HTTP and notification pass (observed bounds 1.511/1.363 s); same process/generation and Flutter absent. New release English inference completes in about 72 s with same PID, Flutter absent and real remote HTTP callback during work. Prompt prefill and RSS/thermal snapshot recorded. Ordinary Sync Time is submitted with the compute service active; actual local HTTP also succeeds in 1.287 s while computing/logging. This is command-path concurrency, not an independent RTC or time-write completion readback. Battery/endurance remain pending. |
| Explicit local / hybrid / remote choices | Local-only flow is implemented and passes. Real remote audio/STT and hybrid local-STT/remote-text voice adapters are not implemented yet; the native remote fixtures prove job contracts only. Implementation and real acceptance await selected provider, credentials and upload consent. Existing ordinary policy explicitly uses local models; unsupported remote/hybrid or upload-authorized requests reject before local processing, so no automatic upload/fallback is claimed. |
| Live firmware log viewer | Existing Flutter Log Viewer now uses the single native NUS owner and the firmware's existing log toggle/tags. 59 affected native framing/HTTP/contract tests and 34 Flutter app-shell/client tests pass; release APK builds. Logs are ephemeral, bounded, excluded from protocol parsing and the durable journal; view disposal cancels observation and requests logging off without stopping BLE. The non-debuggable release is now installed on OnePlus. Physical enable/actual firmware logs/filter/clear/disable/disposal/reopen pass, with real HTTP success while logging and after view/Flutter teardown; same PID 4832 and foreground native owner. Physical log capture resets on radio disconnection, stays disabled afterward and can be re-enabled for actual traffic; a fresh real voice-result receipt is visible during logging and compute-time local HTTP succeeds. Comm Log now passes physical release acceptance. Crash Reports physical summary/refresh/history pass in the latest release. Sensors physical accelerometer/quaternion streaming, HTTP while streaming and disposal/reopen pass; ordinary gyroscope streaming and bonded radio reconnect now pass after firmware fix 098977c4; magnetometer and scalar pressure notification decoding also pass in ordinary UI; pressure units/calibration and remaining types are separate scope. |
| OnePlus core features | Baseline time, owned notifications, HTTP and GPS/Weather pass. Release ordinary Shell app state and restored dashboard Watchface → existing gallery pass. Real Chrome MediaSession metadata and watch next/pause/play pass with both apps' UI in background, Flutter task absent and same PID; owned quiet tone/page, not commercial-player coverage. October 7 release acceptance also passes previous-track and a consolidated next/previous/pause/play sequence at verified watch button centers; callback bounds are 0.427–0.565 s with 1.5 s pauses between commands, Flutter absent and the same native PID. Rapid successive playback toggles are not covered. No log files available: ordinary UI and independent USB FileStatus agree. The installed firmware build has CONFIG_LOG_BACKEND_FS disabled, so nonempty file-log acceptance is physically unavailable on this build; live NUS logs are covered separately. Refresh now invalidates cached native downloads even for unchanged file sizes, local copies are scoped per watch, and a replaced watch discards late downloads before local file access (two new regressions pass). Release Shell command completes after Flutter task destruction (independent watch-state transition, same PID). Owned Android notification body replacement and phone-side removal pass with Flutter absent and same PID; independent UART shows remove/add with watch ID 1000004. Watch-originated dismissal of an actual UTF-8 Shell notification passes with Flutter absent and PID 4832 unchanged; the original forwarding policy is restored. Shell/DFU arbitration and the remaining ordinary connection/settings cases remain pending. Cache invalidation and cross-watch isolation pass the stated host regressions; a physical nonempty log download is unavailable on this firmware build. Accepted native watchface upload survives Flutter task removal: Verifying background observed before teardown, Fume Guilloche full hash matches afterward, same PID. Original Retro Sunburst restored with its exact prior hash. Early UI disposal during preparation correctly leaves the original image unchanged. October 7 radio loss during native verification passes: original unchanged, failed state retained after Flutter teardown/reopen, explicit gallery retry applies the exact candidate, and original is restored. October 7 injected release Java crash now proves service restart with Flutter absent, retained original image and an Interrupted banner without automatic replay. Explicit post-crash retry stalled at 0%; a watchface upload-packet setting mismatch is corrected in source. The corrected release now physically applies a distinct whole-hash-verified Fume image and restores the original Retro image. The first candidate observer stops at 70 s/0%; later full readback proves application, with intervening progress and completion time unmeasured. The prior injected-crash observer remains partial in its historical artifacts. A separate corrected-release verification-phase crash now passes native restart, original retention, Interrupted banner, explicit distinct-image retry and exact original restoration; see the fixed-release checkpoint below. |
| Firmware/resource updates | New fixed application and combined operations pass, acknowledged firmware ~41 KB/s with Flutter removed; active image/resource/original checks pass. Earlier failed combined operation stays failed; SDK network-core index 1 remains unavailable. |
| Modern lifecycle / endurance | Radio/watch-reset/SIGKILL recovery and explicit Stop persistence pass in tested USB setup. Release headless execution and a real HTTP callback with phone noninteractive pass. Release five-minute screen-off pass: 310.1 s with the same PID, Flutter absent, foreground connected-device service and both remote/local HTTP callbacks. Earlier observer waking at 64 s remains failed. Physical phone reboot/first unlock passes: native foreground service and real watch HTTP (229 bytes) return with Flutter absent. Android broadcast queue records boot receiver delivery after 80.277 s; this is delayed system delivery, not immediate availability after unlock. Watch USB/UART transient disappearance and failed first observer remain recorded. First eight-hour observer stops on ADB disappearance after 46.3 minutes of good sampled operation. October 6 same native PID is present, but Flutter/screen are active; the gap is unverified. Second eight-hour observer ends after 26.2 minutes of good sampled operation and then 14 ADB-gap rows; the ADB-dependent loopback receives a real error callback. Subsequent fresh remote HTTP succeeds (283 bytes) with no reset/app start while USB/ADB remains absent. Phone PID/screen/battery cannot be observed in that later test. Long endurance is **deferred to the user by the October 7 instruction**; these observations do not prove clean unplugged endurance. Do not run another agent endurance observer. |
| Final candidate / goal completion | 225 Android tests pass for LiteRT fix; 18 affected Flutter tests and release build pass for restored dashboard Watchface route. Retry-selection fix passes 17 native job tests, 8 Flutter recording tests, release build and physical reuse/reattachment. Latest ordinary connection/Developer wiring passes 16 affected Flutter tests, release build and the stated physical UI/Shell pass. Non-debuggable release code is installed and physically exercised, lab re-signed only to retain existing data. Latest installed release: production SHA-256 767802aec09bca2e5118f4833427f1cce6c6bb761e1925a3ed6dc9391c1eb93d; installed lab SHA-256 87588d0cbd7677067f8dba5e1320e9926280bcbf9cdb940947e9ae2433db0372; runtime source commit 9b9eef4. This release differs from pairing runtime a0ffc0d only in watchface upload packet-size selection and its metadata log. Its 243 selected native companion tests and exact-source release build pass. The unchanged Flutter code retains its prior 31 client/Shell test pass and clean analysis. The latest Settings/app-shell/action/policy suite (23 tests) and Files/app-shell suite (24 tests) pass; the unchanged native code retains its earlier 241-test pass. Exact-source release build and scoped physical acceptance are recorded below. Prior Comm Log physical acceptance remains valid for its stated earlier runtime. Pairing setup fix `a0ffc0d` passes host tests and is installed in release. Ordinary saved-watch Disconnect/Connect and a real headless watch HTTP callback pass; Fresh pairing now passes on October 7 through ordinary Android confirmation and the normal watch Pairable control, followed by actual headless watch HTTP. Clean empty-app onboarding is a separate scope. **Goal active and unfinished; the OnePlus has returned and physical acceptance has resumed. Remote provider/credentials/upload consent remain an independent external dependency.** |

October 7 voice observer resolution:
`.companion-hil-runs/20261007-oneplus-voice-watch-reset/`.
The owned byte-identical microphone replay `hil_ack_reset_230119` automatically
starts real local transcription. The observer sees a transitional Saved on phone
row, opens its active-job dialog, then fails because it expects a Process button
while the dialog says Transcribing. It detaches the debugger without omitting an
ACK or resetting the watch. That observer remains failed; this is **not** a
reset/replay acceptance result.

The separate `resolution/observation.json` and fresh ordinary UI prove that the
same job subsequently reaches Processed / Accepted by watch, with the original
Swedish transcript and an unconfirmed Review & create action. No second job,
processing submission or external action is created to replace the failed
observer. Scoped cleanup deletes only this owned watch copy, returns the entire
recording listing to its captured 26-recording baseline, and independently
verifies the original microphone and background SHA-256 values. A real watch
HTTP callback succeeds with Flutter absent, no compute service, and the same
native foreground process. Independent watch-reset receipt replay remains
pending; do not reopen a delivered job to manufacture that evidence.

Shell/DFU ownership has also been checked in the current source: Shell refuses
firmware-busy work; firmware handoff refuses active Shell, recording, preparation,
log and watchface operations before taking the prepared Nordic transport. Existing
host coverage remains valid. No new physical concurrent Shell/DFU test or firmware
transfer is claimed by this source review. The larger remote/hybrid implementation
dependency remains provider, credentials and explicit upload consent; incidental
observer failures do not justify repeatedly re-running local inference.

October 7 corrected-release watchface crash recovery:
`.companion-hil-runs/20261007-oneplus-watchface-process-loss-fixed/observation.json`.
On app runtime `9b9eef4` and fixed firmware `098977c4`, ordinary Fume upload
reaches Verifying background. One `adb am crash` then injects Java process death;
Android exit-info records APP CRASH(EXCEPTION) for PID 30734. Without starting
Flutter, the native foreground service returns as PID 15899 at the first
11.249-second restart observation. Independent whole-file readback retains the
original Retro image and all 26 recordings. Ordinary Activity/gallery reopen
shows the Interrupted banner, with no automatic image replay.

An explicit ordinary Fume retry subsequently matches the entire shipped candidate
SHA-256, and explicit ordinary Retro restoration matches the entire original
SHA-256. Both SDK uploads use packet size 2475/window 3; observed transfer-time
connection parameters are 11.25 ms, latency 0, timeout 4 s. PID 15899 remains
unchanged during both retries. This closes the injected verification-phase crash
and explicit retry case on this release; it is not natural memory reclamation,
force-stop, a crash during apply/ACK or a speed measurement. The older partial
observer and the unrelated 70-second normal-gallery observation retain their
limits and are not relabelled. No new APK, firmware change or long test is used
for this recovery check.

October 7 sensor reconnect fix and physical acceptance:
`.companion-hil-runs/20261007-oneplus-sensors-reconnect/`.
The existing ordinary Flutter Sensor Debug screen receives actual gyroscope
samples on release runtime `9b9eef4`: the initial screenshot shows 100 samples
at about 4.9 Hz. After Bluetooth off/on, the sensor controls correctly clear
and remain disabled. Fresh manual Gyroscope enable reports streaming but receives
zero samples for 15 seconds on the previous firmware. Read-only debugger flags
show `notif_enabled=false` and `ignore_restored_ccc=false`; the optional CCC-value
read fails because the helper used an older Zephyr type name, so no CCC value is
claimed. The failed pre-fix observation remains failed.

Firmware `098977c4` fixes the explicit enabled CCCD rewrite: the bonded value can
already be restored, so Zephyr skips its changed callback even after the explicit
write clears the ignore flag. The write callback now starts the existing sensor
notification path when Notify is requested and its worker is stopped. The usual
changed callback remains idempotent. There is no new protocol or Android workaround.
The full WatchDK build passes. Application-only debugger programming/verification
covers internal 0x10000–0xdcd68 and external 0x10120000–0x101959e8, preserving
bootloader, network core, settings and user filesystem. USB SMP is opened within
the startup window. The full recording listing is identical before/after (26
recordings); original Retro background full hash remains unchanged.

The same ordinary radio-off/on sequence on fixed firmware passes: switches are
all off after reconnect; Clear history establishes zero samples; manual Gyroscope
then receives 73 fresh samples, displayed rate about 5.2 Hz after a 15-second
observation. Ordinary disposal/reopen shows zero streaming sensors and no retained
sample history. Native PID 30734 stays unchanged and its connected-device foreground
service remains present. Screenshot inspection establishes live data because
UIAutomator cannot acquire idle during the continuous stream; stale XML is not
used as live evidence. The stationary watch reports zero angular values, so this
is notification/reconnect coverage, not movement or sensor calibration acceptance.

Installed firmware image 0 SHA-256:
`53ed46f583e0c455bc620b33d1fa4bd92bb53eaadf00be07dc1bdac200ac032f`;
image 2: `7f6462c4690f4333bf52edc8abe36240e515a6ebaa3f6a5d080da9b8459c8380`.
The flashed artifact is identified by its exact ELF/HEX and the `098977c4` code
diff over `c8f05d09`; it was built before the commit and its embedded commit
metadata therefore is not claimed to name `098977c4`. Unrelated dirty work is
retained. No long observer, AI-quality work or remote audio upload is performed.

Fixed-firmware follow-up: ordinary Magnetometer receives 12 actual samples
(displayed rate about 3.8 Hz, zero XYZ); Pressure displays an actual decoded scalar
value 100869.31. Each stream is disposed through ordinary navigation. These are
real notification/decoding checks, not sensor calibration; the pressure label is
hPa and its existing firmware/parser unit handling needs separate accuracy review.
No unrelated sensor-quality fix is included. After all sensor views are closed
and Flutter is removed, actual watch HTTP succeeds (status 0, 35 bytes, observed
in 1.827 s) with unchanged PID 30734 and the connected-device foreground owner.
All 26 recordings and the original background full hash remain; watch UI returns
to watchface. Evidence: `other-sensors/observation.json` and
`headless-fixed-firmware/observation.json` under the same sensor run root.

October 7 corrected watchface release acceptance:
`.companion-hil-runs/20261007-oneplus-watchface-mtu/`.
Runtime `9b9eef4` is installed as a non-debuggable release; nonsignature APK
entries match the production build. All 243 selected native companion tests pass.
The ordinary gallery submits Fume Guilloche once. Its 70-second observer ends
at Uploading / 0%; subsequent independent whole-file readback matches the shipped
Fume SHA-256 `4bbca3cba66ab88f4ce16b0cd172426b4f0e2e968dd0430c008904cb5d263b0d`.
No second Fume upload is submitted: later navigation observers stop before any
transfer when their assumed Back control is absent. The existing ordinary Shell
successfully returns `app state`. Candidate completion time and intervening UI
progress are unmeasured, so neither a permanent stall nor a speed claim is made.

Ordinary Retro Sunburst restoration then reaches Verifying at the 13.222-second
UI observation, including preparation and observer overhead. Passive UART records
FS write start/finish about 2.811 seconds apart; that is the watch's FS write
window, not end-to-end verified throughput. SDK metadata records MTU 247,
upload packet size 2475, window 3, interval 11.25 ms, latency 0 and timeout 4 s.
Whole-file restored SHA-256 is exactly
`979df7661e05c5a9caa4ac04c46c8147f1a909571c0b7b04370bcb594f547842`.
All 26 recordings remain, native PID 30734 is unchanged and its connected-device
foreground service remains present. This closes normal distinct-image application
and original restoration on the corrected release; it does not repeat the prior
injected-crash recovery case or establish the cause of its observed delay.

The same exact installed release also receives an actual headless watch HTTP
reply (status 0, 35 bytes, observed in 2.079 s), with Flutter absent and the same
PID/foreground owner. The earlier observer called this secure-locked incorrectly:
the user reports unlocked, and subsequent Android policy reads show showing=false
and inputRestricted=false. The notification shade had covered the app. Saved
evidence is corrected and makes no secure-lock claim. No long test, new firmware,
remote audio upload or model change is used.

October 7 watchface process-interruption checkpoint (partial):
`.companion-hil-runs/20261007-oneplus-watchface-process-loss/observation.json`.
On release runtime `a0ffc0d`, an accepted ordinary Fume Guilloche upload is
interrupted using `adb am crash` for only the app package. Android exit-info
records APP CRASH(EXCEPTION) for PID 24785. Native foreground ownership returns
as PID 18649 with Flutter absent before explicit Activity reopen. The first
resumed observation is 66.791 s after the crash; there is an observation gap,
so this is an upper observation bound, not a measured restart latency.
Independent full readback retains original Retro SHA-256
`979df7661e05c5a9caa4ac04c46c8147f1a909571c0b7b04370bcb594f547842`, all 26
recordings remain and the ordinary gallery shows the Interrupted retry banner.
No automatic image replay occurs. This is injected Java crash recovery, not OS
memory reclamation, force-stop or unplugged endurance.
Explicit ordinary Retro retry then stays at 0%; a later Service Changed event
occurs at the firmware's 180-second idle boundary. Original-image equality and
missing progress UI alone do not prove completion, so the overall observer
remains unpassed. The source comparison finds watchface upload missing the
resolved user fork's `setUploadMtu(maxPacketLength)` used by FsManagerPlugin and
NativeResourceTransfer. That setting is now restored without changing Nordic
SDK, window 3/alignment 4, protocol or BLE interval policy. Its relationship to
the stall remains unproven until physical retest.
Earlier observer errors were expected missing-PID handling, a stale failed-versus
interrupted label and a fixed 20-second wait; no second crash was performed to
hide them. Recovery original-image readbacks and crash exit evidence are valid
within their stated scope. No new firmware or long observer is used.

October 7 silent-input acceptance:
`.companion-hil-runs/20261007-oneplus-silence-2/observation.json`.
A uniquely owned 3-second zero-source-PCM Opus fixture is uploaded and its whole
watch copy read back byte-for-byte (2,433 bytes, SHA-256
`eef954e1371c1ca999dc2054af260d03f3acc153ef106ca5668e35e0e29ddb9a`).
Independent Opus decode measures peak amplitude 2 from lossy quantization; this
is synthetic silence, not a microphone recording. Ordinary Process selects the
already downloaded Whisper Base English/Qwen models. With Flutter absent,
actual `LlmComputeService` activity is observed until release; the native BLE
foreground owner and PID 24785 remain unchanged. After reopening, the owned
row durably shows No speech detected and no Accepted by watch result. The watch
source is retained on this outcome, then only the owned test copy is explicitly
deleted; the watch count returns to 26. The phone's owned no-speech receipt is
retained. This is no-speech terminal handling, not AI semantic-quality work.
The first observer checked Flutter removal synchronously and stopped too early;
it remains a failed observer. The subsequent explicit manual run uses bounded
absence polling and observes real headless compute activation and teardown.
No automatic-policy change, remote upload, new model or long observer is used.

October 7 fresh-pairing acceptance:
`.companion-hil-runs/20261007-oneplus-fresh-pairing/observation.json`.
Ordinary app Disconnect stops the native owner. Android device details verify
CF:4B:3D:A1:C5:E2 before removing only that watch bond; other devices/bonds and
app data are retained. The normal watch Settings → Bluetooth → Pairable button
is enabled through existing USB Nordic Shell touch. Read-only live LVGL bounds
identify the correct button, and independent debugger read confirms the ordinary
`pairing_enabled` flag becomes 1; no memory write, direct pairing function call,
reset or firmware patch is used. The watch's Delete all bonded peers control is
not touched. Ordinary saved-watch Connect shows an actual Android ZSWatch pairing
dialog, confirmed through its Pair control, and reaches Connected in 16.445 s
from Connect (including UI-observer overhead). PID 24785 is unchanged.
With Flutter absent afterward, actual watch HTTP succeeds (status 0, 35 bytes,
observed in 1.810 s); the native connected-device foreground service remains and
all 26 recordings are retained. This is a successful new phone bond with the
existing app/saved watch and existing watch-side settings, not clean empty-app
onboarding, all stale-bond combinations or a physical 90-second timeout test.
No remote audio upload or long observer is performed.

Verified watch-control recipe for this firmware build: Settings main-page
Bluetooth row bounds are x=20–239/y=62–98; its Pairable Enable button is
x=146–231/y=33–64. The neighboring Delete all bonded peers button is a different
row, x=184–231/y=81–112. Use centers within verified live bounds; source layout
and debugger reads can verify ordinary UI controls even without a hardware
screenshot. The toolchain's GDB lacks Python scripting; use ordinary supported
GDB print commands, then detach/resume. Do not reuse fixed RAM addresses or
assume these coordinates apply to other firmware layouts. Pairable lasts 60 s.

October 7 media-control acceptance:
`.companion-hil-runs/20261007-oneplus-media-controls-4/observation.json`.
On runtime `a0ffc0d`, actual watch touches produce real Chrome MediaSession
callbacks for next/previous/pause/play with Flutter absent and PID 24785
unchanged. Observed host callback bounds are 427/565/530/482 ms. Commands have
1.5-second settling intervals. The owned local tone is paused afterward and its
server/reverse port removed; the native foreground owner remains present.
Independent debugger reads of live LVGL bounds show previous at x=46–77,
y=104–135. Earlier test coordinate x=78 was outside the button; center x=61
works. The debugger performs reads only, then resumes/detaches without reset,
flash or function calls. Earlier page-readiness and misplaced-touch observers
remain failed. The immediate pause/play sequence in attempt 3 did not receive a
play callback; the ordinary settled sequence passes in attempt 4, so no rapid
playback-toggle or general commercial-player claim is made. No app or firmware
change was required for this acceptance.

October 7 model file-control acceptance:
`.companion-hil-runs/20261007-oneplus-model-controls/physical/observation.json`.
On installed release runtime `a0ffc0d`, the ordinary Android document picker
imports an owned 128-byte GGUF metadata fixture with zero tensors. It remains
selected and locally available after Flutter task removal/reopen. Ordinary
Delete removes it from the model catalog; the exact owned public source is
removed afterward. Qwen3.5 2B Q4_K_M is selected again, and its 1.19 GB local
model plus Whisper Base English's 141 MB local model remain visible. Automatic
processing policy is not applied or changed. With Flutter absent afterward,
actual watch HTTP succeeds (status 0, 35 bytes, observed in 1.837 seconds),
PID 24785 remains unchanged and the connected-device foreground service remains
present. The actual compute component `dev.zswatch.app.LlmComputeService` is
absent. This proves file controls and BLE continuity; the fixture is not an
inference model and no imported-weight loading or private-cache wipe is claimed.
No model download, remote audio upload or long observer was started.

October 7 pairing fix and installed-release reconnect evidence:
Native runtime source `a0ffc0d` restores the previous Flutter owner's bonding
before service discovery. An existing bond goes directly to discovery; an
ongoing/new bond waits for Android's selected-device result, with a separate
90-second user-confirmation limit. Stop/closed GATT fences late events and
unregisters the receiver. The existing Flutter setup/bonding UI is reused. This
closes a concrete missing setup step; it is not yet proof of the root cause of
the user's initial OnePlus pairing failures.
All 243 selected native companion tests pass (including six pairing regressions),
31 Flutter client/Shell tests pass, analysis is clean and exact-source release
build passes. Evidence: `.companion-hil-runs/20261007-oneplus-bonding/`.
Production APK SHA-256: `1e46e4a6c2b6838a20a0d716a883c8433126c2d3c47de30e720831a6bc375ac7`.
The non-debuggable lab-signed copy has identical runtime entries and is prepared
for later installation at the temporary phone handoff. The user subsequently
returned the OnePlus and the exact lab APK was installed successfully. Physical
evidence: `physical/observation.json` under the same run root. Ordinary saved-watch
Disconnect removes the native service; Connect reaches Ready at the first
2.988-second UI observation. With Flutter removed, the watch receives an actual
35-byte loopback HTTP reply, status 0, observed in 1.542 seconds. PID 24785 is
unchanged across this short reconnect test; the connected-device foreground
service is present and all 26 watch recordings remain. Existing pairing and app
data are retained. This proves the already-bonded path, **not fresh pairing**;
That separate case subsequently passes in the fresh-pairing checkpoint below. No long observer was launched.

October 7 independent time acceptance:
`.companion-hil-runs/20261007-oneplus-time-readback/physical/observation.json`.
The existing Developer → Sync Time control on release runtime `630ab2e` updates
the watch’s RV-8263 RTC. Independent USB Nordic Shell `rtc get rv-8263-c8@51`
reads local wall time; comparison uses the actual phone epoch and `+0200` offset.
Before sync the RTC is two seconds behind; after sync and again with Flutter
absent it matches the phone to the one-second output resolution. PID 13495
is unchanged. No direct RTC write, debugger, new firmware command, timezone
change or long observer is used. This covers the actual current offset, not DST
or all timezone transitions. Shell/DFU source review confirms exclusive Nordic
transport handoff, worker-serialized ownership and rejection of Shell while
firmware is busy; no new physical concurrent Shell/DFU acceptance is claimed.

October 7 short watchface recovery evidence:
`.companion-hil-runs/20261007-oneplus-watchface-recovery/physical/radio-observation.json`.
On runtime `630ab2e`, Bluetooth is disabled after ordinary gallery UI shows native
Verifying background. The original full SHA-256 remains unchanged; reopening
Flutter shows the previous failed update without an automatic replay. Explicit
Fume Guilloche retry matches the whole shipped image, and ordinary Retro Sunburst
restore matches the exact original hash `979df7661e05c5a9caa4ac04c46c8147f1a909571c0b7b04370bcb594f547842`.
PID 13495 is unchanged, all 26 current recordings remain, and watch UI is watchface.
Flutter task removal is asynchronous: the immediate observation is false, then
its absence is independently confirmed before reopening. The first observer
missed submission under a floating phone overlay; it performed no radio toggle
and is not a passed interruption. No debugger, firmware edits or long observer
are used. Installed build `app/build_companion_find/app/zephyr/.config` explicitly
has `CONFIG_LOG_BACKEND_FS` unset, agreeing with the watch-tools documentation;
nonempty filesystem log acceptance is unavailable on that build.

Release evidence: `.companion-hil-runs/20261005-oneplus-final-release/` and
`.companion-hil-runs/20261005-oneplus-release-acceptance/` (calendar UI,
release-route artifact identity, English inference/ACK, quiet-2 and quiet-3 observations).
The longer input repeats the same 7.56 s real microphone recording five times;
it proves longer workload handling, not naturally spoken longer-audio quality.
Android exit-info attributes the earlier PID change to PACKAGE UPDATED, not an
inference crash. Private audio/transcripts remain outside Git. User direction:
leave pre-existing LLM semantic errors alone; prioritize refactor functionality.
Chrome evidence is in `release-acceptance/chrome-media/` under the same run root:
`control-observation-awake.json` proves next/pause/play; its overall script fails
at previous-track and is not a complete media-controls pass. The earlier
foreground-page play ambiguity and sleeping-watch launch failure remain recorded.
Android independently reports com.android.chrome metadata for the owned track;
the test tone was paused and localhost server/reverse port removed afterward.
The quiet-3 observer proves 310.1 s noninteractive release operation with two
watch-confirmed HTTP replies (remote 209 bytes, owned local 35 bytes), USB attached,
no forced idle. Shell-detach-2 passes: watchface + absent Flutter task precede Music launch;
PID remains 32006. The first observer failed because it required synchronous
task removal, and remains recorded separately.
Notifications-3 proves body revision v5 → v6 and phone removal for the same owned
watch ID with Flutter absent and PID 32006. Earlier observers failed on unchanged
content suppression and host shell quoting; those are not claimed app defects.
The temporary Shell forwarding selection was restored through ordinary settings
to the original 1/64 selected apps. The owned notification is absent from the
active Android list; shade cancellation was not established.
Phone-reboot observation records the real reboot and ADB returning while user 0
is RUNNING_LOCKED. Watch USB and UART disappear together; no watch reset or
second phone reboot was used to hide that observation failure. The ports subsequently return and the observer resumes without another reboot.
The resumed observer passes after first unlock: native PID 8525, foreground
connected-device service, Flutter absent and watch-confirmed remote HTTP 229 bytes.
Android broadcast queue independently marks BootReceiver DELIVERED at +80.277 s
after enqueue. The service is absent during the delay; no immediate availability
after unlock is claimed. Evidence: `phone-reboot/` and `phone-reboot-resume/`.
STT-cancel-2 physically exercises the existing shared Whisper abort while
Transcribing the owned 37.8 s replay using Base English. Its native log records
transcription aborted by user; the existing Flutter result view observes Cancelled
without a transcript/summary, native compute service is absent at 2.425 s after
the host cancellation submission, PID 8525 is unchanged and the independent
watch reports all 22 recordings retained. That bound includes UI/dumpsys overhead.
The first observer used an incorrect expected UI label and missed the cancellation
window; it remains failed separately, and no app bug is inferred from it.
The ordinary Retry processing control opens the model choice dialog after
cancellation. Choosing undownloaded Whisper Small English for the same owned
fixture produces Processing failed / Reason: model_missing with Retry still
available and no transcript/summary. No model download or audio upload was
requested; phone list still contains 23 saved receipts. Evidence:
`modelmissing-evidence.json` and its named UI observations.
Watchface-accepted observes native Verifying background before removing Flutter,
then keeps the task absent through independent full SHA-256 readback matching
Fume Guilloche (115,212 bytes), with PID 8525 unchanged. The earlier watchface
observer closed Flutter before image acceptance: preparation completed, but the
provider correctly declined the unaccepted upload and the original hash remained.
Its additional expectation of an unavailable DEBUG apply log stays a failed
observer, not an app failure. Ordinary gallery restoration of Retro Sunburst
matches original SHA-256 979df7661e05c5a9caa4ac04c46c8147f1a909571c0b7b04370bcb594f547842;
all 22 watch recordings remain. Evidence: `watchface/`, `watchface-accepted/` and
`watchface-restore-final.json`.


Retrying with an already completed model exposed a refactor integration defect:
the native owner correctly reused the saved job, but Flutter chose the highest
generation and continued showing the newer model_missing failure. The journal
now selects the requested job per watch/recording, and the existing Dart view
prefers that selection. Selection changes neither computation, result delivery
nor confirmed actions; journals without selection retain latest-job display.
The native regression verifies selection across reopen, unchanged accepted
outbox/result/action state and no repeated work. All 17 native job tests and
8 affected Flutter recording tests pass. Physical baseline evidence is in
`retry-existing-before/`. Installed non-debuggable release physically passes:
choosing the original KB-Whisper Base Swedish + Qwen model displays the saved
Accepted by watch result, with no compute service. Flutter task removal/reopen
retains identical transcript/summary and the same native PID 30812. The actual
compute service class was independently checked as dev.zswatch.app.LlmComputeService;
the first observer's generic class name alone was insufficient evidence.
Evidence: `retry-existing-after/`, especially `reopen-observation.json`, and
`retry-selection-release/artifact.json`. The first bounded eight-hour observer stopped after the ADB device disappeared.
47 sampled observations through 2,777.8 s (46.3 minutes) all show the same PID,
Flutter absent, screen off and the foreground connected-device service; both
remote and loopback watch HTTP succeeded. The eight-hour acceptance remains
unproven. On October 6 ADB is available again and PID 30812 still exists, but
Flutter is now present and the screen is on. This later point cannot fill the
unobserved interval. Evidence: `endurance-8h/quiet-result.json` and
`.companion-hil-runs/20261006-oneplus-current/observation.json`.

The watch's CDC port was inactive at the next setup. The documented, explicitly
authorized lab reset/DTR sequence captured it at 5.743 s, received a real SMP
app-state reply at 5.845 s and again at 30.876 s, and left the port enumerated
after close. No firmware change was needed to keep USB enabled. This is setup,
not a seamless lifecycle pass. Evidence: `.companion-hil-runs/20261006-usb-bootstrap/`.

October 6 ordinary connection UI completion: Settings → Watch connection still
opened CompanionPrototypeApp, exposing development controls in the normal flow.
It now opens the existing start/saved-watch view through the existing saved-watches route. The ordinary Connection setup link into the prototype is removed too.
An already Ready connection shows Disconnect without a connecting indicator;
connecting states retain Cancel connection. The regression covers actual Settings
navigation, passive open/back/reopen, explicit native Stop and its stopped view,
with no legacy BLE/AI/DB startup. All 15 affected app-shell/saved-watch tests pass;
release build passes. Installed release physically passes Settings/back/reopen,
Disconnect (native service disappears), Connect (Ready observed at 2.956 s)
and return to Connected dashboard, same PID 24082. This is an observation bound,
not wire latency. The first observer required an exact accessibility label;
Flutter actually merges Watch connection with Connected. No reset/install was
used to retry that UI observation. Evidence:
`.companion-hil-runs/20261006-oneplus-connection-ui/connection-flow-2/`.

Ordinary Developer entry also still targeted the prototype. The existing Flutter
Developer Tools view is now registered for the native app and the dashboard
opens it. Find reuses the existing native timed button; Sync Time and Device Info
use already implemented native commands. Shell and File System retain their
migrated routes. At this checkpoint live Log Viewer/Comm Log, Crash Reports, sensor GATT and
synthetic debug panels remain unavailable rather than starting a second BLE
owner; their parity is not claimed. These diagnostics remain separate incomplete
coverage, not evidence that all pre-refactor developer features are restored.
The regression exercises the actual existing route/actions with legacy BLE
providers set to throw. All 16 affected app-shell/saved-watch tests and release
build pass. Physical release opens ordinary Developer Tools; Find/time/info
controls are exercised, and its ordinary Shell receives a real watchface app-state
reply, same PID 30345 and foreground native service. This proves the UI/native
command path, not independent haptic or RTC measurement. A one-second time-sync
snackbar expired before the first observer captured it; the observer remains
failed, and verification resumed without a reset or repeated Find/Sync.
Evidence: `.companion-hil-runs/20261006-oneplus-developer-ui/`, particularly
`ui-flow/resume-observation.json`. A second bounded eight-hour observer was started
on this artifact in `.companion-hil-runs/20261006-oneplus-endurance-8h/`. It has now
ended after phone USB/ADB disappearance and a failed ADB-dependent loopback probe.
Temporary ADB failures are recorded without restarting the app; any missing
screen/owner observations remain gaps and prevent a clean screen-off pass.
A host observation failure is distinct from an observed native service failure.

October 6 live-log implementation, source `1923062`: restored the existing
Flutter Log Viewer route and toggle through a dedicated ephemeral native event
channel. No new BLE connection, SMP implementation or firmware change. Native
write completion drives streaming state; it is not an application acknowledgement.
The receive framer separates `<BLELOG>` bodies from real JSON, including split
tags/UTF-8, embedded JSON, adjacent control messages, invalid/oversized bodies,
connection reset and an expired missing tail. Capture is off by default, resets
on disconnection, and late write callbacks cannot re-enable it after disable or
reset. Closing the view cancels its event subscription and requests the existing
firmware disable command; the companion service remains running. The view keeps
its existing filters, clear/copy controls and a 1,000-entry in-memory buffer,
discarded when the native log view closes. Deferred iOS provider lifetime is
retained. Six new log regressions plus 39 existing contracts and 14 HTTP tests
pass; all 34 affected Flutter app-shell/client tests pass. Dart analysis reports
no errors or warnings (one pre-existing test-only unawaited route-push info).
Actual watch log delivery, disable/disconnect behavior and simultaneous native
HTTP/time/status/voice receipts still require physical acceptance. The
eight-hour observer retained its installed `e5ccaa9` artifact during this work;
host source/build changes do not count as testing the new APK on OnePlus.
Release build passes (49.8 s); prepared non-debuggable production SHA-256
`1d3e51edae4314587d2d461ebccc36544e5db226ccf2fb47121f271bcc248ea6`,
lab re-signed SHA-256
`8143cb8d8e760c71f796ccbbde914cd12ca30b8031ff15ee442124940ef8833a`.
Non-signature APK entries are identical. Artifact:
`.companion-hil-runs/20261006-oneplus-live-logs/artifact.json`.
At the time of preparation it had not replaced the installed endurance artifact.
The following physical procedure is now exercised in the resumed checkpoint below:
ordinary
Developer Tools → Log Viewer: enable after the firmware's initial three-second
log suppression, obtain actual watch log lines, and check a real time/status/HTTP
round trip while logging. Clear/filter the existing view, disable and reopen it,
then remove Flutter and verify the same companion owner plus core traffic.
Record actual received logs and write completion separately; do not label host
fixtures or command acceptance as watch confirmation. Bundle this with the
remaining main recovery/action checks rather than repeatedly reinstalling for
each diagnostic control. Pre-existing LLM classification errors remain deferred.

October 6 second endurance outcome: 27 samples through 1,570.0 s show PID
30345, Flutter absent, screen off and the foreground connected-device service.
The remote probe returns status 0 / 264 bytes. Phone ADB disappears at 1,630.2 s;
14 explicit gap rows follow through 1,825.5 s. Independent USB inventory also has
no phone, while watch/FTDI/J-Link remain present. The loopback callback returns
status 3 / zero bytes at the next scheduled probe, and the observer exits 1.
That probe depends on the now-unavailable ADB reverse. No app restart or second
endurance restart was used. This is incomplete host-dependent endurance evidence,
not an established companion crash. A separate fresh remote probe, with no reset,
app start or Flutter interaction, returns status 0 / 283 bytes at a host-observed
4.194 s. BLE HTTP handling still works after host phone USB/ADB loss, but that
later test cannot prove the phone PID, screen, battery or eight-hour continuity.
Evidence: `20261006-oneplus-endurance-8h/quiet-result.json` and
`20261006-oneplus-adb-loss-remote/observation.json` under `.companion-hil-runs/`.
OnePlus has since returned with the same PID 30345 before the package update;
this later point does not fill the missing interval. Avoid another long observation until
that lab dependency is stable, and prioritize the consolidated functional pass.

October 6 resumed physical acceptance: user reconnects OnePlus; PID 30345 and
native foreground service are observed before installing the prepared `1923062`
release. Package update succeeds without clearing app data; normal Flutter UI
shows Connected / MTU 247 and new PID 4832. Existing Developer → Log Viewer
starts Disabled/empty. Its normal switch enables actual firmware logging; the
view receives the firmware enable message and real HTTP callback. Error filter
shows 0 / 2 entries / ERROR; All levels restores both INFO entries. Clear gives
0 entries. Disabling suppresses new log entries while actual HTTP still succeeds.
Closing an enabled log view and reopening produces Disabled / 0 entries; native
HTTP continues. Ordinary Sync Time is submitted separately, then Flutter task
is removed and a further real HTTP callback succeeds. Same PID and foreground
connected-device service persist. Remote HTTP callbacks are status 0 with
269/250/247/234 bytes; host-observed bounds 3.394/4.919/3.546/3.082 s.
The time command submission is not claimed as a new independent clock readback;
logging-through-disconnect and simultaneous voice-result receipt remain pending.
Evidence: `20261006-oneplus-live-logs/physical/` under `.companion-hil-runs/`,
including private XML/UART, `phone-return.json` and `observation.json`. No product
or firmware change was needed for this physical pass.

October 6 fresh-result firmware blocker and recovery: the owned 7.56 s
byte-identical microphone replay `hil_ack_1006_191241` is fully read back and
verified over USB (31,051 bytes, original SHA-256
752adbf221bec1e7c7a1398b797993085325529bd2b40a19bab5dc99470de862).
Several USB upload timeouts are preserved; the bounded SDK retry completes the
same owned upload. Ordinary Refresh queues automatic local processing. The
first UI observer incorrectly expected a manual Process dialog after automatic
processing had already entered Transcribing; no duplicate submission was made.
Flutter is removed, and the real pipeline persists a result waiting for watch
acceptance. The watch then repeatedly faults in sysworkq while accepting the
fresh receipt: Usage Fault / Stack overflow, not an established phone crash.
The debugger reports invalid registers as the target resets; no owned ACK file
is emitted and no ACK is omitted. Treat that attempt as failed, not a lost-ACK
pass. Stop the boot loop by temporarily disabling phone Bluetooth.

Firmware `c8f05d09` moves the 2,000-byte legacy encoding conversion scratch off
the NUS workqueue stack, allocating/freeing it only when conversion is needed.
Already valid UTF-8 goes straight to the dispatcher. No system stack increase,
new protocol, model/prompt change or new service. The previous compiled common
parser frame is 6,312 bytes; the rebuilt dispatcher is 32 bytes and voice parser
2,488 bytes. Receipt/CRC/fault/capacity host regression and full WatchDK build
pass. Only signed application internal flash and low-QSPI XIP spans are flashed:
0x10000–0xdcd58 and 0x10120000–0x101959e8; userdata is absent from the HEX.
Active app image hash is
118bbaf56141bc7890b453e2fb7e29ed43790b21108214988edc3cbc3ac138a9.
The external image hash also changes with this application/XIP deployment;
no claim of a byte-identical whole resource image is made.

Physical fixed-firmware acceptance passes: restore Bluetooth, keep Flutter
absent, and the existing committed result receives a real durable-new / ACK=0
at the first 10.504 s observation after radio enable, same phone PID 4832.
Real watch HTTP subsequently returns status 0 / 231 bytes at an observed
3.557 s. Independent USB verifies all 22 prior watch recordings plus original
Retro Sunburst background and this owned replay (24 full file hashes); 23 watch
recordings remain. No further fatal/reset appears throughout that verification.
This proves outbox recovery after the actual watch failure and application fix,
not deliberate ACK loss, full endurance or naturally spoken new audio.
Evidence: `20261006-oneplus-lost-ack-2/` and `20261006-receipt-stack-fix/` under
`.companion-hil-runs/`. The debugger preparation script now removes its pending
breakpoint, detaches and exits with failure if the target stops without a matched
owned ACK; all four existing safety/identity regressions pass.

October 6 deliberate lost-ACK physical acceptance passes on firmware
`c8f05d09` and installed app runtime `1923062`. An owned byte-identical 7.56 s
microphone replay is fully verified before ordinary automatic local processing;
Flutter task is removed after the recording-list refresh. The temporary hardware
breakpoint matches the exact owned key and generation 1, saves the real ACK,
skips only its send with -EIO and immediately detaches. Actual UART records one
`durable result new, ACK=-5`, then `durable result duplicate, ACK=0` 10.544 s
later. Captured ACK identifiers/key/generation/digest are retained privately;
GDB exits 0. Same phone PID 4832 and absent Flutter task are verified during
retry. Independent USB readback confirms the owned audio still equals its source;
normal Flutter Voice Notes then shows Processed / Accepted by watch. The watch
contains all 22 prior originals plus three clearly owned replay fixtures (25
recordings). No transcript, result or external action is injected by the test.
This is real application-ACK retry and duplicate acceptance on a live link,
not an additional radio/reset recovery, receipt-capacity or eight-hour pass.
Evidence: `20261006-oneplus-lost-ack-fixed-3/` under `.companion-hil-runs/`.

The first fixed-firmware setup fails on a USB read before fixture/debugger work.
The second reaches the exact ACK but GDB treats the quoted dump path as a literal
filename; it fails before register modification, so no ACK is omitted. Both
failed attempts remain separate. The generator now uses an unquoted filename
and rejects paths containing whitespace/quotes/backslashes. A new regression
executes that exact generated dump command with real host GDB over static ELF
bytes, without running a process or touching hardware. All five affected
regressions pass. SDK USB fragment retries are bounded and captured separately;
no custom SMP or app-library change is introduced for this test.

October 6 malformed-container physical acceptance: create a confirmed-absent
owned synthetic `.zsw_opus` with finalized header declaring 160 frames, but only
two frames in its 100-byte body. USB readback verifies the test bytes. Ordinary
Voice Notes Refresh uses the real native SDK download and shows Download failed;
the row exposes neither Process nor playback preparation. No compute service
exists. Independent USB proves the watch file remains after rejection. Only
then delete that newly created synthetic file through the existing voice_memo
command and verify absence; count returns from 26 to the preceding 25 and PID
4832 is unchanged. All seven malformed-scope checks pass. The overall observer
fails on its additional remote HTTP callback (status 1 / zero bytes, observed
11.147 s); do not silently count that request as successful or infer an app
crash from it. Evidence: `20261006-oneplus-malformed-recording/` under
`.companion-hil-runs/`, including the unmodified failed `observation.json` and
separate `malformed-scope-evidence.json`. No product change was needed.

October 6 watch-originated notification dismissal passes in the installed
non-debuggable release. Temporarily select only the additional Android Shell app
in ordinary Notifications settings (1/64 → 2/64), then post one owned synthetic
notification with Swedish UTF-8 characters. Independent UART observes its actual
body on the watch. Remove Flutter and wait for task absence; launch the watch's
registered `Notification` app, verify that it is running, and long-press the card
using the existing `touchdown 120 120` / `touchup` commands. The matching owned
Android notification key disappears while Flutter remains absent and PID 4832
is unchanged. Return the watch to its watchface and restore the original 1/64
forwarding selection through ordinary app settings. No product change is needed.
The initial observer asserted task removal before Android finished; the first
resume used an incorrect application name and release-command argument count.
Those failed observers remain separate and are not app/firmware defects.
Evidence: `20261006-oneplus-watch-dismissal/resume-2-observation.json` under
`.companion-hil-runs/`, plus private UI/UART and original failed observations.

October 6 consolidated compute/log/radio scope passes with the installed release
and fixed firmware. One additional owned byte-identical 7.56 s microphone replay
is fully verified before ordinary Refresh. Its row and the real compute service
show processing; ordinary Developer Sync Time is submitted while that service
is still active. The Log Viewer is enabled, and an owned localhost HTTP request
returns status 0 / 35 bytes in 1.287 s while compute and logs are active. Actual
UART records durable-new / ACK=0; the existing log view displays that real
receipt. Turning Bluetooth off resets capture to Disabled before view disposal.
Bluetooth is restored. The first HTTP probe after enable is submitted before
reconnection and is rejected at admission (rc=-22); the original overall observer
remains failed. A separate resume observes Connected, capture still Disabled,
real local HTTP success, explicit log re-enable and actual fresh callback logs.
The ordinary voice row shows Accepted by watch; full USB readback preserves the
owned source. Same PID 4832, native HTTP after Flutter removal and all 22 prior
originals plus four owned replays (26 recordings) remain. No compute restart or
second replay was needed. The later recovery point does not establish continuity
through the observation gap or reconnection latency. Sync Time submission does
not establish independent RTC accuracy or completion of the GATT write.
Evidence: `20261006-oneplus-concurrent-recovery/` (original failed observer and
`consolidated-scope-evidence.json`) and its `-resume/` root under
`.companion-hil-runs/`. This independently proves local BLE/HTTP operation after
the earlier malformed test's remote timeout; that remote timeout remains failed.
No model, prompt, app-library or firmware change is introduced for this pass.

October 6 Comm Log implementation restores the existing Flutter tile/view through
a dedicated ephemeral event channel from the same native NUS owner. TX entries
are emitted only after the complete queued write finishes; RX entries are
reassembled protocol JSON from the existing framer, with firmware log bodies
excluded. It observes NUS protocol traffic, not the Nordic SDK's SMP byte stream.
Entries retain completion/receive timestamps, UTF-8 byte counts and actual TX
chunk counts. Capture is attached only while the view observes it, never written
to the durable journal, and uses the existing 5,000-entry/5 MiB UI rotation plus
a 64-event native-to-main-thread queue bound. Detach drops late callbacks without
changing the companion lifetime, BLE connection or firmware-log toggle. Native
capture does no payload conversion when no observer is attached. The route test
keeps legacy BLE/WatchService/DB providers set to throw and verifies traffic,
byte counts, timestamps, clear, actual cancellation and empty reopen without BLE
commands. All 35 affected Flutter app-shell/client tests and 59 native NUS/HTTP/
live-log tests pass. Static analysis has no errors or warnings (one existing
test-only unawaited route-push info). Release build and physical acceptance are
pending at this implementation checkpoint. Crash Reports and sensor diagnostics
remain separate incomplete parity.

October 6 physical Comm Log release acceptance passes. Production release build
completes in 58.2 s; the non-debuggable APK is re-signed with the existing lab
certificate, with all nonsignature entries byte-identical, and installed without
clearing models/settings/receipts. The normal Developer → Comm Log route starts
empty and displays the actual owned local HTTP request and completed response.
RX filtering hides the written response. Clear removes the owned HTTP entries;
new real status/activity packets may arrive while the view stays open. The first
observer incorrectly required a permanently empty live view and remains failed.
The corrected observer verifies removal of the owned entries. Bluetooth off/on
then produces completed native setTime and timezone TX packets in the still-open
view, followed by actual local HTTP success. Closing the view leaves HTTP working;
reopening does not replay the traffic received while it was closed. Flutter task
removal still leaves the foreground native companion and actual HTTP working,
PID 19620 unchanged throughout this test. Local callbacks return 35 bytes in
1.867/1.148/1.879/2.061 s. These are host observation bounds, not pure air latency.
Clock packets establish native write completion during reconnect, not independent
RTC accuracy or the earlier compute-time write's completion. No additional
firmware, SMP-library or model change was needed.
Evidence: `20261006-oneplus-comm-log/artifact.json` and `physical-2/` under
`.companion-hil-runs/`; `physical/` retains the original failed observer.

October 6 longer release observation has started in
`20261006-oneplus-comm-release-endurance-8h/` under `.companion-hil-runs/`, against
the physically accepted `354c806` runtime above. Initial samples through 124.6 s
show PID 19620 unchanged, Flutter absent, screen off and the foreground
connected-device owner; real remote HTTP returns status 0 / 194 bytes at 3.852 s.
This is setup/early evidence, **not an eight-hour pass**. The observer records
ADB gaps explicitly and does not submit reverse-dependent loopback requests
while ADB is absent. Remote endpoint errors remain explicit separately from
native-owner continuity; real local-probe failures stop the observer. No forced
idle or battery/permission reset is used, and USB remains physically attached.
Secure wireless ADB has not been activated: automatic approval review rejected
that security-setting change pending explicit user authorization. Continue via
USB while that optional request is unanswered.

The above attempt stops after 787.7 s on its foreground-type assertion. Its
observer incorrectly requires exactly `0x10`; the service legitimately adds the
location bit during GPS work. The failing sample has no saved raw service dump,
so that explanation is possible rather than proven. A subsequent independent
dump shows PID 19620 unchanged, Flutter absent, screen off and the actual
companion foreground record with connected-device type. Preserve the original
failed outcome; it establishes neither an app crash nor uninterrupted endurance.
`native_runtime_probe.connected_device_foreground` now checks the actual owner's
record and the connected-device bit, allowing additional types. Three regression
tests cover combined types, unhealthy owners and misleading other-service records.
The corrected observation runs in `20261006-oneplus-comm-release-endurance-8h-2/`
with raw service dumps saved per sample, on the same unchanged installed release.
It remains **running, not passed**; USB reattachment sees the same PID.

October 6 Crash Reports implementation/build checkpoint: the existing Developer
tile, Current/History view, summary persistence, analysis and export now use the
native Android owner. Opening or explicitly refreshing the view queries the
existing Nordic SMP shell `coredump summary`; erase uses `coredump erase 0` and
then verifies absence. Download uses the existing SDK file manager and fixed
`/user/coredump.txt` path, with the shared diagnostic reader's bounds, generation
fences and firmware/SMP arbitration. No additional connection or custom protocol
is introduced. Current firmware returns `-ENOENT` with `Failed to read summary
(-2)` when no file exists, including after erase; only that exact error/output
pair counts as absence. Other errors cannot clear a cached report. The existing
optional version field is `dbg: 0/1`, rather than a new boolean field. This
firmware's version response currently omits SHA/debug metadata; missing SHA stays
empty and raw export uses `unknown` rather than throwing on substring. Automatic
background crash discovery is not claimed: current firmware does not send the
Gadgetbridge crash-summary message, and normal dashboard observation does not
poll SMP. Existing shared Dart analysis and SQLite history remain; controlled
tests use a fake backend, and no real crash payload is uploaded automatically.

Validation: 38 affected Flutter tests and 56 affected native tests pass; targeted
analysis has no errors/warnings and one pre-existing unawaited route-push info.
Host widget SQLite uses the temporary test-only library symlink, without changing
project dependencies. Release builds in 50.3 s, production APK SHA-256
`38b368c783ce1b4cd80866bc5d1920b17068d792d243ae338dfb45ac3ba2f59e`.
This APK is **not installed or physically accepted yet** because the independent
endurance observer owns the watch and phone session. Physical Current/Refresh,
download and erase acceptance remain pending; analysis upload requires the
existing explicit user action. Sensors remain separate incomplete parity.

October 6 Sensors implementation/build checkpoint restores the existing Developer
tile, Sensor Debug cards/charts, individual toggles and quaternion/orientation
controls. All eight existing sensor UUIDs and float decoders are reused. Android
subscribes through the existing companion GATT connection; sensor CCCD writes,
initial battery reads and NUS writes are serialized by that owner's pump. Only
the NUS CCCD can establish protocol Ready; a sensor CCCD completion cannot rerun
connection setup. Failed sensor operations return an error; an uncertain timed-out
ATT operation fences/reconnects the owner. The sensor request queue and UI event
queue are bounded. Samples are ephemeral, size-checked and generation-fenced, with
no durable journal writes, extra BLE connection, UI or SMP implementation. Closing
or destroying the view cancels observation and queues subscription cleanup;
closing during enable waits for that actual CCCD transaction before disable.
Disconnect clears availability/enabled state; reconnect exposes current
capabilities with sensors off, requiring explicit user toggles again.

Validation: all 240 native unit tests pass, including three new serialization,
cleanup and reconnect tests. All 39 affected Flutter tests pass, including real
route/toggle/value/disposal coverage and controlled samples through all eight
existing Dart decoders. Targeted analysis has no errors/warnings and the same
pre-existing route-push info. The first view observers incorrectly counted
offscreen lazy children and waited for an indeterminate first-sample spinner;
corrected tests scroll to the actual control and supply the first controlled
sample. Release builds in 50.5 s, production APK SHA-256
`ba07196cbd2384ebf7f3651d99bfdcd27b9e2776f8419ce3eb7053b5200fc408`.
It includes the Crash Reports restoration but remains **uninstalled and physically
unaccepted** while the independent endurance session owns the hardware. Real
sensor values, toggles/disposal/reconnect and HTTP during streaming remain pending.

Prepared installation artifact: `20261006-oneplus-crash-sensors/artifact.json`
records runtime source `2c99ecd`, the production hash above and lab APK hash
`721de9f4a3c0187258563d0fcaa077f76ade7379ddede8ff3edea96bd8aa9a56`.
Existing lab certificate matches; the APK remains non-debuggable and every
nonsignature ZIP entry is byte-identical to the production release. No install,
data reset or phone restart occurred. The older compiled-owner helper cannot
inspect this minified release because it requires the removed BuildConfig class;
its failed/unsupported result is retained rather than marked passed. Native
source/unit/build evidence and physical acceptance remain distinct. The active
endurance observer still exercises the installed `354c806` runtime, not this APK.

October 7 authoritative endurance outcome: session 34457 is now terminal (exit 1),
not a live wait. `20261006-oneplus-comm-release-endurance-8h-2/quiet-result.json`
contains 31 good sampled observations through 1812.5 s: PID 19620 unchanged,
Flutter absent, screen off and connected-device foreground owner. Its first real
remote HTTP callback succeeds in 3.782 s. The next probe loses the watch's USB SMP
transport (`SMPTransportDisconnected`); no later continuity is established.
Captured UART contains no USB/fault/assert/reset diagnostic. Current USB boot
guard checks host DTR once; this evidence does not identify the cause of the later
port loss. Preserve this failed observer outcome. It is a roughly 30-minute
partial observation, **not an eight-hour pass or demonstrated Android app crash**.

October 7 pending UI work: the existing Alarms & Timers collection route is now
connected in the working tree to saved native results and the same shared Dart
action cards used by individual recordings. The adapter scopes reads to the
selected watch, excludes unfinished jobs and unrelated action types, and retains
receipts from replaced results while hiding their unreviewed suggestions. It
preserves the original action indexes and invokes no model or OS side effect on
opening. Added coverage exercises ordinary Voice Notes navigation, filtering and
unchanged reads on unrelated battery updates. **This change remains uncommitted,
unverified and absent from the prepared APK.** Automatic approval review could
not run the requested SDK command because account usage was exhausted; this is
a review failure, not a determination that the change is unsafe. Do not bypass
that check. Resume format/analyze, affected Flutter tests, release build and
commit only after approval review is available. Last test/build-verified prepared
runtime remains `2c99ecd`. Hardware acceptance of Crash Reports/Sensors, timer
dispatch, remaining recovery cases and the endurance gate remain pending.

October 7 validation resumed after account status again allowed ordinary usage and
the same approval path succeeded. The Alarms & Timers adapter now passes all 43
affected Flutter tests, including preserved prior Clock receipts when the source
job is cancelled/replaced; new creation remains gated to committed active results.
Targeted analysis has no errors/warnings and one pre-existing route-push info.
Its release build passes in 48.8 s. The previously unverified working-tree
checkpoint above is historical; this validation supersedes it. No AI semantic,
prompt/model or native producer change was needed. USB inspection confirms the
watch, FTDI UART and J-Link are present; OnePlus is unlocked and still has PID
19620, the foreground native owner, and a real Connected/MTU 247 dashboard.
These later observations do not fill the endurance observation gap.

Independent current watch `coredump summary` returns a real stored dump with an
empty File and Line 0. That is a valid locationless crash, not missing data. Native
parser/store validation now accepts a present empty File while still rejecting
a missing File field and invalid line/size; native regression and all unit tests
pass. The same existing SDK/shell/file path is reused, with no firmware change.
Physical UI acceptance follows on the next installed release.

October 7 short physical diagnostics acceptance: installed the non-debuggable
`874a8cc` release, lab re-signed with identical runtime entries, on OnePlus.
Package replacement starts PID 28073; it remains unchanged through this pass.
Ordinary Developer → Crash Reports reads the existing locationless dump (empty
File, Line 0), shows History, and successfully refreshes the same summary. No
new dump was generated, erased, analyzed or uploaded. The first refresh observer
captured loading and the subsequent transient reconnect before returning to the
dashboard; it did not prove refresh completion. A later bounded observation
captures completed summary and refresh, then Connected/MTU 247 dashboard.

Ordinary Sensor Debug displays actual accelerometer values (0/0/9, about 4.9 Hz,
100 retained samples) and fusion quaternion/Euler values. Real owned loopback
HTTP succeeds while streaming (35 bytes, 1.321 s) and after view disposal (35
bytes, 1.783 s); PID stays 28073. Android GATT logs record both sensor notification
disables on the same GATT object at disposal; reopening shows zero streams and
all switches off. Continuous chart updates make UIAutomator's idle-based dump
fail and reuse an old XML file; that observer output is not current sensor-state
evidence. Actual screenshots and the later settled reopening prove the stated
scope. Other sensor types and radio-recovery acceptance remain pending.
Ordinary Voice Notes → Alarms & Timers opens the expected empty collection;
no saved current timer/alarm suggestion exists. This proves navigation/empty
state only, not actual Clock dispatch, which remains pending. No inference or
pre-existing semantic behavior was changed to manufacture an action.
Evidence: `.companion-hil-runs/20261007-oneplus-diagnostics/artifact.json` and
`physical/` (observation.json, sensor screenshots, notification callbacks,
crash summary/refresh/history and clock-collection XML). Phone is left on the
Connected dashboard. No long observer is running or newly scheduled; endurance
acceptance is deferred to the user.

October 7 Settings/Clock completion: `150000e` restores the common existing
Flutter Settings screen instead of returning the reduced Android-only scaffold.
Native connection/HTTP/GPS controls remain attached to the same owner. Existing
DFU screen preference, About/licenses and editable coredump server URL return;
App Permissions explicitly opens Android app settings without constructing the
legacy onboarding/foreground/notification observers. Legacy persistence/demo
controls are not offered for the mandatory native owner. Existing calendar
permission/default-picker and explicit Timer & Alarm Test controls are restored
in Voice Memo AI; no native AI implementation, model tuning or extra job system.
All 23 affected app-shell/action-card/policy tests pass, including persisted DFU
and server preferences, no automatic permission prompt and one snapshot observer.
The first test run omitted the documented SQLite library path and failed its
crash-history host case; the corrected run passes. Product analysis is clean.

Installed non-debuggable `150000e` release physically opens the ordinary model
page with the existing downloaded Whisper Base English and Qwen3.5 2B metadata,
shows granted calendar access and opens/dismisses the default-calendar picker
without changing selection. Its explicit 30 s test timer reaches Google Clock's
actual countdown; the first UIAutomator idle wait fails during that countdown
and its reused old XML is not timer evidence. The actual screenshot proves the
owned Test timer, and settled Clock UI after deletion proves cleanup while the
pre-existing 15-minute timer remains. Alarm +5min creates Test alarm at 17:40;
Clock independently shows it enabled, then disabled and deleted. Other existing
alarm rows remain. These tests use the shipped explicit controls and real shared
productivity bridge, not a synthetic AI result or a journaled voice action; actual
voice timer/alarm receipt coverage and independent watch timezone/RTC readback
remain pending. No prompts or existing classification behavior were changed.
Evidence: `.companion-hil-runs/20261007-oneplus-settings/` (artifact.json and
physical model/calendar/Clock screenshots/XML, cleaned system views).

`630ab2e` fixes the relevant native log-cache seam: fresh listings invalidate
in-memory download paths because firmware exposes no file revision; saved copies
use watch-specific directories, and switching the selected watch disposes old
UI state. Late results cannot save into the next watch's state, and a closed log
view does not access its disposed WidgetRef after transfer. The two new host
regressions exercise changed contents with identical size, stable state over
same-watch generation changes, separate local copies across two watches, and
watch replacement while a download callback is pending. All 24 affected Files/
app-shell tests pass, analysis of the six changed product/test files is clean,
and the final exact-source release build passes in 50.7 s.

Installed `630ab2e` release, re-signed with identical runtime entries, physically
opens ordinary Files; its empty list agrees with independent USB FileStatus for
all eight known log paths. USB fs shell is absent (`fs: command not found`), so no
log fixture was created without a supported cleanup path. Nonempty physical log
download remains unverified; no firmware instrumentation was added to manufacture
it. The watch reports 26 recordings, unchanged. After Files disposal and Flutter
task removal, the same native PID 13495 and connected-device foreground owner
complete actual watch loopback HTTP (35 bytes, 1.183 s). This is a short functional
pass, not an endurance observation or physical cross-watch/cache-download pass.
Evidence: `.companion-hil-runs/20261007-oneplus-logcache/` (artifact.json and
physical/observation.json); read-only watch inventory is in the Settings run.
Remote configuration, other remaining recovery/feature cases and the user-run
endurance gate stay separate. Goal remains active and unfinished.

Physical dropped-ACK preparation: `scripts/companion_hil/prepare_lost_voice_ack.py`
generates, but never runs, a temporary hardware breakpoint at the real durable
result ACK send. The breakpoint checks the owned key/exact generation and
`accepted == 1`, saves the ACK envelope, skips one ARM call with `-EIO` and detaches.
It neither patches firmware nor injects an AI result or external action. Four
host safety/identity regressions pass. Preparation against the real current ELF
finds call 0x160a2 / next instruction 0x160a6 and usable acceptance debug symbols.
The preparation smoke uses a dummy recording key and performs no hardware access;
it is **not** physical acceptance. Follow the scoped physical procedure in
`scripts/companion_hil/README.md`; require actual duplicate receipt handling,
same-result retry/application ACK and unchanged originals/actions. Evidence:
`.companion-hil-runs/20261006-lost-ack-preparation-smoke-2/`. At that preparation
checkpoint actual ACK omission was pending; it now passes in the fixed-firmware
checkpoint above. Independent reset/replay and receipt-capacity physical
coverage remain pending.

October 6 remote-scope audit: the real headless processor accepts only
`dart-voice-v1` / `backend=local` / `upload_authorized=false`; its native producer
and ordinary automatic-processing tile agree. No existing remote voice adapter
was found in the shared AI implementation. The remote-job fixtures must not be
presented as implemented remote transcription or text analysis. Once the selected
provider/credentials/data consent arrive, add that adapter in shared Dart using
the existing native job/checkpoint/outbox lifecycle. Local STT + remote text does
not accelerate transcription; remote audio/STT needs audio-upload consent, while
remote text needs consent for the transcript. The pending dependency question
remains open. A focused regression rejects remote, hybrid, mismatched-provider
and upload-authorized requests before recording decode/file/model access or a
transcript checkpoint. All five affected voice-processor tests pass; no product
code, provider choice, upload or local model behavior changed in this audit.

October 6 blocked audit: OnePlus remains absent from both real host USB
inventory and ADB across three consecutive goal turns. Watch CDC/FTDI/J-Link
remain present, so resetting the watch cannot restore phone access. The previous
eight-hour observer is terminal, not a live wait; its incomplete outcome and
subsequent successful external HTTP remain recorded above. Phone-free live-log
implementation/release build, scoped ACK-test preparation and shared local-only
voice boundary verification are committed. Remaining consolidated UI, delivery/
action/recovery and endurance evidence require OnePlus access; further fixtures
or repeated host checks cannot establish that acceptance. Resume by connecting
OnePlus with USB debugging approved, installing the prepared `1923062` live-log
release artifact once, and completing the consolidated pass before another long
endurance attempt. Prepare supported wireless ADB first if available. Remote
implementation remains a separate pending provider/credentials/consent dependency.
No goal scope or success gate is removed, and no unavailable check is marked passed.

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
   queued AI work. The user will run the long endurance window later; do not launch
   or schedule an agent eight-hour test (October 7 direction). Record physical
   power and OnePlus battery settings; USB or
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
receipt capacity is 50 recording identities. Firmware c050202a reclaims validated
receipts only when their watch audio no longer exists, and only at capacity.
Retained audio, corrupt receipts and uncertain I/O retain their deduplication
record; explicit source deletion ends draft-receipt retention. Phone-side external
actions keep their own deduplication. Host quota/I/O/corruption tests and WatchDK
build pass. Application-only debugger flash and independent SHA-256 checks pass
for 24 existing files (22 recordings, background and stored coredump); the same
OnePlus process reconnects Ready generation 266. Physical cleanup-at-capacity
remains pending. Evidence: `.companion-hil-runs/20261005-receipt-cleanup/`.

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

### 2026-10-05 cancellation, Stop and explicit resume checkpoint

Cancel now fences the durable job first and signals the existing Dart Whisper/
GGUF/LiteRT cancellation APIs. A per-execution check prevents another processing
phase or publication after cancellation. Native teardown retains the headless
engine until its FFI work returns, then allows the existing post-completion logger
callbacks to finish before destroying it. Explicit companion Stop retains the
transcript and releases the active lease; explicit restart can immediately claim
the same job rather than waiting for the 15-minute lease.

| Area | Result and limits |
| --- | --- |
| Cancel job | **Pass on OnePlus for real GGUF prompt processing.** Cancelled state, no result publication, unchanged 20 recording receipts and the same native PID/Ready generation. Native cancellation signal to compute-service destruction is 4.119 seconds. The current library finishes its active prompt batch before honoring cancellation; this is not instant prefill abort. |
| Disconnect/Stop during analysis | **Pass, debug.** Both services are absent afterward, all model threads are idle, Stopped/desired-running=false persist during the observation, and the saved transcript/lease release are independently read. Signal to engine teardown is 10.664 seconds in this case, again including completion of the active prompt batch. |
| Explicit restart | **Pass for recovery.** Flutter Connect starts attempt 2 of the same job/spec/input/transcript without waiting for lease expiry. The subsequent LLM router rejects this synthesized English fixture as no-speech; this is not timer semantics or successful delivery acceptance. |
| HTTP while processing | **Partial.** The native owner writes the Weather HTTP reply in generation 120 about 2.767 seconds after launch while Flutter is absent and real LLM model initialization is active. The observer initially stopped at Pending; Written is verified from the persisted later observation before the Stop timestamp. UART watch receipt and HTTP latency during steady prompt/token generation are not established. Standalone OnePlus Weather evidence remains separate. |
| Checks | Ten focused Flutter tests, 16 native job tests, focused Dart analysis and debug/release builds pass. Tests include cancellation before work, phase fencing, detached completion and Stop lease/checkpoint recovery with stale callback rejection. Latest physical Stop candidate has build coverage for release; these cancellation/Stop tests use debug. |

Private evidence: `.companion-hil-runs/20261005-oneplus-cancellation-third/`
and `.companion-hil-runs/20261005-oneplus-http-stop/acceptance-evidence.json`.
The earlier two cancellation attempts did not tap the button because the test
locator omitted Flutter accessibility descriptions; neither is counted as a pass.
Tested cancellation APK SHA-256:
`66f4ac8445672bf3cad04e5d17540ca8c9c65634f0080d4fc7299ee194a2d2fe`;
tested final Stop/lease-recovery candidate:
`47bd2d70aff0f181a6aa4184ca2685e941391cd1261dda73f9ec29fb6f47b07f`.
The correction preference is restored to false, and the captured automatic
Swedish processing policy is unchanged. STT/LiteRT and long-input cancellation,
speech/action quality, real remote configuration, lost ACK, the full OnePlus
feature/update/release matrix and controlled endurance remain pending.

### 2026-10-05 OnePlus updates and flash-addressing gate

ADB on `ae49cb83` works. The current app remains the ordinary Flutter UI with
native ownership; this checkpoint uses debug APK SHA-256
`47bd2d70aff0f181a6aa4184ca2685e941391cd1261dda73f9ec29fb6f47b07f`.
No AI provider or architecture change was introduced.

| Area | Result and limits |
| --- | --- |
| Application-only OTA | **Pass.** A distinct 838,316-byte application image uploads at 39.43 KB/s acknowledged active rate, with Flutter's task destroyed at 24,436 bytes and the same native PID. Automatic reboot, active-image verification and Ready complete. A later independent USB check after a documented lab reset verifies the new active image, unchanged external image and all 22 backed-up files. |
| Connection settings | **Pass for measured throughput.** MTU 247 / ATT payload 244, Nordic merged packet 2,475, window 3, latency zero and 4-second supervision timeout. The watch-requested interval settles at 11.25 ms. One temporary 30 ms interval during the combined resource upload returns to 11.25 ms. Both application rates exceed the accepted 17.6 KB/s floor; further throughput tuning is unnecessary. |
| Combined transfer/integrity | **Transfer passes; overall acceptance fails.** Resources: 5,932,208 bytes, 37.88 KB/s upload and 32.12 KB/s full SHA-256 readback. Firmware: 838,316 bytes at 43.84 KB/s. Flutter is destroyed during resources and remains absent. Independent USB inspection after the package's own reset verifies application `0.8.1.2`, unchanged external image and freshly mounted resource length. It does not replace the failed native postflight. |
| Combined automatic recovery | **Failed.** Native discovery repeatedly times out and the 90-second postflight correctly records `boot_check_timeout`, `result_unknown=true`. One manual Bluetooth off/on recovers fresh Ready generation 143 in about 2.24 seconds, with Flutter absent. This is manual recovery, not automatic OTA acceptance. The old Nokia is not the connected peer; the watch's observed address matches the OnePlus. |
| Preservation after combined | **Failed for later lab files.** The original nine recordings, background and crash file independently match their backups. Five later short watch microphone triggers and six owned speech fixtures are absent; all eleven have verified independent byte backups. No intentional deletion was requested. Source-audio preservation remains a gate. |
| Firmware addressing | **Confirmed configuration defect, source fix built.** The 64 MiB flash uses 24-bit addressing while user storage spans `0xe20000..0x1820000`. Runtime QSPI IFCONFIG0 is `0x0003001c` (32-bit bit clear); non-erased mapped windows 16 MiB apart match exactly. Wrapped high user addresses overlap resource/code partitions. This explains an actual cross-partition risk; do not attribute the observed loss to Flutter or the old phone. |
| Addressing fix | **Build pass; physical acceptance pending.** Firmware commit `7d2a6b21` configures WatchDK/ZSWatch for 32-bit addressing and EN4B, aligns their nrfjprog initialization/size, and adds a user-partition addressing build guard. The guard rejects the old configuration. Corrected WatchDK sysbuild passes; generated application and MCUboot DTs both contain 32-bit/EN4B settings. The source fix has not been flashed. |
| Recovery backups | **Verified.** Full currently addressable 16 MiB snapshot, plus a separate 1.875 MiB low user snapshot, match over their shared range. The reconstructed 10 MiB old logical user image preserves the observed wrapped layout, including its known damage; it is not a pristine filesystem. All 22 pre-update file backups remain available. The first oversized debugger read timed out and produced an empty file; only the completed second read is counted. |

Immediate work order is now data-safe activation of the addressing fix, then
automatic reconnect acceptance and the consolidated feature pass. This is an
actual firmware gate within the existing goal, not a new backend or migration
framework. Keep all unrelated work and original files intact:

1. Use the snapshots and exact file copies already available; the user explicitly
   requested no further backup work. The physical high range has now been checked
   with 32-bit programmer addressing and is entirely erased. Continue directly
   with activation and functional verification.
2. Install matching fixed MCUboot and application/XIP images through the debugger,
   retaining network-core firmware and avoiding whole-chip erase. An app-only OTA
   is insufficient here: the bootloader and programmer must use the same flash
   address mode. Restore the old logical user filesystem into its real partition
   as needed to retain surviving metadata, then restore only confirmed-missing
   files from their exact verified backups. Do not erase/format user data to make
   the test pass or overwrite a changed surviving file.
3. Independently verify runtime 32-bit addressing, distinct high/low flash access,
   all 22 file hashes, recording inventory and fresh mounted resources. Repeat a
   bounded reset/recovery check before another combined package. The native
   postflight failure remains failed until a new operation actually passes.
4. Resume notification/time/HTTP/media/Find/Shell/log/watchface and lifecycle
   acceptance, remaining shared Dart speech/action/backend checks and endurance.
   Meaningful microphone/English quality, LiteRT, real remote configuration,
   physical lost ACK and full release/endurance acceptance remain pending.

Private evidence: `.companion-hil-runs/20261005-oneplus-ota/`,
`.companion-hil-runs/20261005-oneplus-combined/` and passive watch UART under
`.companion-hil-runs/20261005-oneplus-core/`. This turn prepared the core/recovery
helpers but did not run the consolidated consumers or claim that pass. Indices
0/2 are reported; network-core index 1 remains unverified. Phone/watch are USB
connected. EN4B behavior follows the
[Macronix MX25U51245G datasheet](https://www.macronix.com/Lists/Datasheet/Attachments/9126/MX25U51245G%2C%201.8V%2C%20512Mb%2C%20v1.3.pdf)
and the repository's Zephyr QSPI binding/driver. The goal remains active.


### 2026-10-05 physical addressing activation and OnePlus core acceptance

The user requested no further backups. Existing images/file copies were reused.
The corrected matching MCUboot/application/XIP images and logical user partition
were programmed with targeted sector erase and verified successfully before reset;
network-core firmware and settings were not selected. Running firmware QSPI
IFCONFIG0 is `0x0003005c`, with the 32-bit address-mode bit set. Eleven missing lab
files were restored, and all 22 source-file hashes match both before and after a
subsequent reset. The watch and native inventory both contain 20 recordings;
freshly mounted resources report 5,932,208 bytes. No filesystem format was used.

| Area | Result and limits |
| --- | --- |
| Fixed firmware boot/recovery | **Pass.** A bounded debugger reset recovers fresh native Ready/status/inventory in 13.08 seconds with the same PID, Flutter absent and no Bluetooth toggle. This is a reset test, separate from OTA acceptance. |
| Addressing activation | **Pass for programmer verification, runtime mode and filesystem round trips.** MCUboot and app use the fixed build. Small memory-mapped debug reads alone did not establish distinct physical high/low access and are not counted as that proof. |
| Notification | **Pass for a newly posted owned debug notification.** Actual body is observed at the watch, with a new native write in the current generation and Flutter absent. Forwarding and the app's own source were enabled in the existing Flutter UI; other phone sources remain unselected. Update/dismiss behavior and real third-party sources remain pending on OnePlus. |
| HTTP/time/inventory | **Pass within this scope.** One actual loopback consumer receives exactly one successful 35-byte callback; native records Written. Time is written for the fresh Ready session, and both inventories report 20 recordings. Earlier real GPS/Weather acceptance is separate; timezone changes and broader HTTP error policy remain pending. |
| Media | **Pass for synthetic MediaSession with actual watch BLE next/play controls.** The fixture advances to track 2 and playing=true, native accepts controls, PID/generation remain stable. Real third-party player acceptance remains pending. |
| Native lifecycle | **Pass.** Bluetooth off/on recovers automatically with the same PID. Injected SIGKILL recovers with a new PID and fresh watch status/time without Flutter. Stop removes the service and remains stopped through radio changes; explicit native restart reaches Ready without Flutter. This is injected death and USB-connected behavior, not natural reclamation or unplugged endurance. |

Private evidence: `.companion-hil-runs/20261005-address-activation/` and
`.companion-hil-runs/20261005-oneplus-core-32/`. The restoration's first two USB
attempts dropped UART fragments; the final smaller paced library transfers pass.
The interrupted file's exact prefix was checked before replacing the owned
partial upload. No custom SMP implementation or production transport workaround
was introduced. Initial core observers failed on unset optional metadata and
host/phone clock skew; only the final new watch receipt plus phone-clock journal
comparison is counted. Passive UART capture ended at its bounded deadline.

The fixed application-only OTA also **passes**, using the identical fixed code
payload with a distinct MCUboot version `0.8.1+3`. Operation
`1901cd44-24e5-45d5-a4f8-4f1f715e2ff2` uploads 838,392 bytes at 41.50 KB/s
acknowledged active rate (early sample 43.47 KB/s). Flutter's task is destroyed at
29,332 acknowledged bytes, and native PID 4839 remains unchanged. The initial
30-second reconnect attempt times out; the existing retry and SMP service-change
recovery then reach Completed/Ready within the bounded postflight. Independent
USB inspection on the package's actual boot, without a lab reset or radio toggle,
verifies active application `0.8.1.3` with hash
`30dd342ef9cee6aa91ccc17c2b4f4bb3dc15a0198d97aae2555f215021391d5f`, unchanged
external image and all 22 file hashes. Network-core index 1 is not reported by this
SDK response and is not claimed verified. Evidence:
`.companion-hil-runs/20261005-oneplus-ota-32/`.

The earlier combined update remains **failed**. No result here silently changes
that operation. Remaining work includes a new fixed-firmware combined result,
Find/Shell/log/watchface and the rest of the OnePlus matrix, meaningful speech and
Clock semantics, LiteRT/remote configuration, physical lost ACK and release/quiet/
endurance acceptance. The shared Flutter/Dart UI and AI backend remain unchanged;
iOS remains deferred and the goal remains active.


### 2026-10-05 fixed combined update acceptance

A new, distinct fixed application (`0.8.1+4`, 838,392 bytes) plus the existing
board-matching 5,932,208-byte resource image passes the ordinary Flutter updater
and native owner. Operation `390e131c-a088-4424-8356-17172027fda3` uploads resources
at 41.16 KB/s, verifies their complete SHA-256 by readback at 32.44 KB/s, then
uploads firmware at 41.50 KB/s. Flutter is destroyed at 218,876 resource bytes;
the same native PID 4839 completes the whole operation with Flutter absent.

The package performs its own reset. Its first native reconnect attempt times out
at 30 seconds, then the existing retries/service-change recovery reach Completed/
Ready about 61.3 seconds after the Rebooting observation, within the bounded
postflight. There is no lab reset or manual Bluetooth toggle. Independent USB
checks on this boot verify application `0.8.1.4`, target hash
`c0b841040f2921c79e1b356b9a16937bbc460825c178d808dd5c22ce50b9af1a`, unchanged
external image, freshly mounted resource length and **all 22 existing file
hashes**. Resource SHA-256 is
`ed5878418ca4552eb7f0bcbd7b8934089301a68e95b62636ed1cc7cf6de0255c`.
Network-core index 1 remains unavailable in the SDK response.

This is a new passing operation; the earlier combined operation remains failed.
The intermittent initial reconnect timeout remains an observed rough edge. This
pass does not establish that the flash fix alone corrected native reconnect
behavior. No new native transport workaround or custom SMP was added. Existing
file copies were reused; no new backup work or filesystem format was performed.
The first independent verification helper stopped on local variable shadowing;
correcting that read-only helper allowed the complete checks above without
restarting the update. Private evidence:
`.companion-hil-runs/20261005-oneplus-combined-32/`.

The offered natural microphone recording completed successfully; see the
acceptance checkpoint below. No computer-speaker fixture was substituted.


### 2026-10-05 actual Swedish microphone roundtrip

The user recorded the suggested sentence with their own voice on the watch,
`20261005_170916` (7.56 seconds, 31,051 bytes). Ordinary automatic processing used
shared Dart with `kbWhisperBase|qwen35_2b_q4_k_m|false`, local-only, upload disabled.
No model-policy or application installation change was made for this recording.

| Acceptance | Evidence / result |
| --- | --- |
| Original → phone integrity and decoding | **Pass.** Independent existing USB SMP SDK download exactly matches the native phone copy and journal SHA-256 `752adbf221bec1e7c7a1398b797993085325529bd2b40a19bab5dc99470de862`. Existing Dart parser accepts a clean container with 756 Opus frames; ffmpeg decodes mono 16 kHz audio. Original remains on the watch. |
| Real local transcription and interpretation | **Pass for this Swedish sentence.** Transcript: “Påminn mig att köpa mjölk imorgon klockan nio.” Result category reminder, title “köpa mjölk”, due `2026-10-06T09:00:00.000` local time. One real processing attempt, no fixture transcript. |
| Persistence and application ACK | **Pass.** Job `12e3de6f5a53ce3da4c5a8af997a87e1d5b0f12bc89bc0f22834254d279055de` is Delivered; matching result `4dc91023ba8e3b49844ec31f9fb1f863ab5c1d9678e2a400dce0b459f5e0dfdd` is Acked in the flushed native outbox. The receiver marks these only after matching version, IDs, generation, result hash and accepted application ACK. This is a draft, not confirmation of calendar/Clock creation. |
| Headless execution observation | **Pass at observed boundaries.** Flutter activity absent before and after; same native PID 4839. USB ADB disappeared during capture and was restored by the user; continuous UI absence and mid-inference BLE latency were not observed. Native owner recovered to Ready generation 177. |
| BLE during inference / performance | **Pending.** The concurrent observer stopped on ADB loss before measuring prompt-time notification/HTTP latency. This recording does not close that gate or provide elapsed-time/thermal numbers. |
| Audio quality limits | Watch UART captured PCM overflow warnings. Correct Swedish transcription is established for this sentence; longer/English/silence tests and broader microphone fidelity remain pending. |

Read-only independent receipt-file verification was attempted, but SMP rejected
its long path and this firmware has no `fs` shell command. No new transport,
firmware, reset or receipt mutation was introduced for that optional check;
the matched persisted application ACK is the delivery evidence above.
Private artifacts: `.companion-hil-runs/20261005-oneplus-real-microphone-user/`,
including `verified-roundtrip.json`, independent original/phone bytes, decoded
Ogg/WAV, terminal native job and Acked outbox. The interrupted observer artifacts
remain interrupted and are not relabelled as passing continuous observations.

Next: English/longer audio with an appropriate STT model, physical cancellation
and action execution, concurrent BLE acceptance, remaining consolidated features
and quiet/endurance. LiteRT model and real remote configuration remain separate
pending inputs. The overall goal remains active.


### 2026-10-05 ordinary voice UI and concurrent BLE acceptance

The ordinary Flutter Voice Notes view displays the user's real recording as
Processed / Accepted by watch, with its actual transcript, summary and Review &
create action. Pressing the ordinary Process dialog again with the same models
leaves the entire native jobs and outbox unchanged: no new generation or duplicate
result. The UI was not replaced with a native screen.

A uniquely named owned watch file, `hil_ble_user_170916.zsw_opus`, replays the
byte-identical real microphone audio to produce a fresh real local STT/LLM run.
The native service downloads it, saves the correct transcript and processes the
actual 1,253-token prompt. Flutter's task is removed before prompt processing.

| Area | Result and limits |
| --- | --- |
| BLE during real prompt processing | **Pass, debug OnePlus.** Marker `[CACHE] Processing full prompt` and a CPU-thread snapshot establish actual prompt processing. Watch UART receives one successful 35-byte HTTP callback and the owned notification body while the job retains its active lease. Host-observed receipt bounds are 1.511 s for HTTP and 1.363 s from notification posting, including admission/polling; these are not wire-level timings. Native PID 4839 and Ready generation 179 stay unchanged across both probes; Flutter is absent throughout the sampled prompt window. |
| Completed replay | **Pass.** Phone bytes match the real original and native SHA; one processing attempt reaches Delivered/Acked. Watch UART independently logs `durable result new, ACK=0`. Transcript and milk/tomorrow 09:00 interpretation match the original run. |
| Measured processing / resource snapshot | Actual prompt prefill: 1,253 tokens in 26.558 s, 47.18 tokens/s; this is not output-generation throughput. During prompt processing `top -H` shows approximately 1.7 GiB process RSS, including the whole app rather than only the model. Post-run Android thermal status is 2; no peak/continuous temperature or battery-drain claim. |
| Time/status and endurance limits | Fresh status continues after completion, but no time write was measured during this prompt window. USB remains attached and the previously known battery optimization exemption is retained. This is a short functional workload, not unplugged/OEM/endurance acceptance. |

Private evidence: `.companion-hil-runs/20261005-oneplus-ble-inference-real/`
(`acceptance.json`, `ble-during-inference.json`, CPU/thermal snapshots, terminal
job/outbox and passive watch UART) and the original microphone directory's
`ordinary-ui-dedup.json`. The owned replay file was deleted afterward; the actual
original remains on the watch at 31,051 bytes (`cleanup.json`). No production
transport or scheduling code was changed
for this test. English/longer input, STT/LiteRT cancellation, lost ACK, remaining
core features and release/quiet/endurance still require their stated coverage.


### 2026-10-05 LiteRT MethodChannel cancellation contract

The existing LiteRT bridge had an unresolved Dart-future path: cancelling its IO
coroutine prevented the normal Main dispatcher switch in its exception handler.
Cancellation before IO dispatch or while waiting for the generation mutex could
also bypass that handler. The bridge now enters its handler on early cancellation,
returns cancellation through a non-cancellable Main reply and suppresses a second
reply if cancellation arrives after success. It retains the SDK conversation's
pending terminal callback after cancellation, so the existing headless owner's
FFI-return wait is not mistaken for native completion. No native AI business
logic or second job owner was added.

Four tests exercise the actual bridge and real coroutine dispatch queues with
controlled SDK callbacks: cancellation before dispatch, active cancellation with
delayed native completion, queued generation cancellation and cancellation after
successful reply. These are channel/lifetime-contract regressions, **not actual
LiteRT model execution**. The full Android suite passes 225 tests (zero failures,
errors or skips); debug and release APK builds pass. Default production dispatchers
remain IO and Main; the optional constructor dispatchers only make those races
controllable in tests. Mockito is a test-only dependency.

No `.litertlm` file is installed on OnePlus. Actual LiteRT load/inference/cancel
therefore remains pending. The installed phone APK was left unchanged during the
real microphone and concurrent BLE tests. Compiled candidates:

- Debug SHA-256: `677dac9abb322a208eb3260905c2a65b1a10eaaac26484d09ff59c491f7ce41d`.
- Release SHA-256: `f7c95671a40c699cdff89d866b6c514aed32dbbf82e3489f1eb9bf50a794fc73`.

Evidence: `.companion-hil-runs/20261005-litert-cancellation-contract/` and
`LiteRtLmBridgeTest.kt`. Release physical acceptance still requires execution of
the compiled final candidate; a successful build does not close that gate.


Ordinary playback follow-up: the real recording is prepared by the existing
Flutter control. A Play → pause check advances the player to `0:01 / 0:07`
(20%), then closes the player. The first observation only captured Play/0:00
and did not prove active playback; it is not counted as a pass. The controlled
pause provides actual player execution evidence in
`ordinary-playback-paused-private.json` under the microphone run directory.
