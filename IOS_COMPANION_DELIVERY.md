# Native iOS companion delivery checkpoint

2026-10-16. The normal Flutter app uses the Swift-owned iOS companion and the
shared Dart voice processor. Implementation and the physical resource recovery
are committed locally on `codex/ios-companion`. First-install Bluetooth denial, Settings recovery and new watch selection now
pass on the phone. The existing watch is now migrated through AccessorySetupKit;
a real app-switcher force-quit automatically restored the app and Weather worked
after a watch reboot without reopening the phone app. Untested variants remain explicit below; this checkpoint is
not a claim that every physical acceptance case has passed.

## Source and installable artifact

| Component | Revision / location |
| --- | --- |
| Signed app executable | App `95df44f` (voice-model readiness and clear blocked-job recovery; includes `a6f5314` ASK/SMP fixes); includes `d2e0ba7` Weather HTTP diagnostics and bounded transient retry |
| Nordic fork | `06644b17bec8202605afba2065ba8b5f7ef00fcb` |
| fllama fork | `115e7991e78de446ed44858ebe0a8dbc82769d8e` |
| Installed WatchDK firmware | `ecd78bfc`, nested `ZSWatch/`, branch `codex/ios-companion` |
| Signed development app | `.companion-hil-runs/20261016-ios-companion/voice-model-readiness/Runner.app` |
| Local evidence | `.companion-hil-runs/20261015-ios-companion/` and `.companion-hil-runs/20261016-ios-companion/` |

The app is signed for team `28L8XH4G9T` and the connected iPhone 11, iOS 26.1.
It is a development-signed installation, not an App Store package. Raw evidence,
recordings, model weights and build artifacts are intentionally ignored by Git.
No PR, push or publication is included.

## What is verified

- Native BLE ownership, encrypted Ready, ordinary reconnect/watch reboot,
  Bluetooth off/on recovery, durable Stop and actual OS background relaunch after
  an injected process kill plus a new watch recording. The last method is not
  evidence for a user force-quit or spontaneous jetsam.
- All six normal routes; native GPS/weather/HTTP including offline error and
  recovery; ANCS receipt; CTS timestamps/timezone; AMS metadata and remote media
  controls; sensor subscriptions and cleanup; shell/filesystem/log tools;
  watchface selection, Photos/crop/upload and original restoration; isolated Demo.
- Verified BLE recording publication, playback/seek/export, search/edit/copy,
  archive/delete/restore, offline batch controls and selected-only permanent phone
  purge. A real background-expired download retained a verified 421,950-byte prefix
  and resumed to the exact 620,412-byte source.
- Real local transcription and analysis with saved results/watch ACK, automatic
  transcription without analysis, model import/delete/selection, calendar/reminder
  Create/Undo and local-notification timer behavior. Background AI deferral and a
  fresh fenced retry preserve the saved transcript.
- Firmware upload/retry/cancel, acknowledged throughput 33.5166 KiB/s for the
  measured 836,204-byte image, short Home pause/resume, real boot and active hashes.
- Resource upload after a ten-second Home pause and server-requested restart:
  all 5,919,608 bytes compared before and after reboot, Ready 182, UI test 861.387 s.
  A 26-second Home interval correctly expires to unknown outcome, requiring explicit
  Reset/reselection. The SDK repairs cover paused ACKs and server offset rewind.
- Final independent USB checks: 33 original recordings / 673,009 bytes, every hash
  unchanged; original 115,212-byte watchface hash unchanged; full resource image
  SHA256 `5b060daa49707f1f621a4d6ba1817d6f1032fd1def2fb18e38c5abade388d1a0`.
  The previous complete feature checkpoint was Ready 189 on app cea2517, with
  all 33 recordings downloaded, no error and automatic processing off. The newer
  Weather repair and its physical evidence are recorded below.

Firmware 26c59c8a fixes the shared system-workqueue/ATT buffer deadlock using a
separate RX queue and measured stack budgets. Read-only captures show RX 4936/9504
and system work 4848/6144 bytes used, with CPU not halted before/after. The failed
4 KiB RX candidate is explicitly rejected. WatchDK heart-rate values are existing
firmware simulation; chart acceptance does not establish physiological accuracy.

## Weather failure and repair — 2026-10-15

The user's reported "Failed" reopened Weather acceptance. A real UART capture
caught an LVGL rendering assertion in the Bluetooth RX workqueue. Weather was
updating LVGL directly from its HTTP callback after BLE RX moved off the system
queue. Successful retries also left the old "Failed" label visible. Firmware
`fe958aa0` copies borrowed HTTP responses and GPS fixes into bounded queues, then
parses and updates Weather on the same system workqueue as rendering and app
start/stop. It clears the error label on success, validates response fields and
forecast array bounds, and reads GPS age without modifying its timestamp.

A separate reboot check caught an input-thread assertion before the power manager
was initialized. Firmware `ae9a28d1` ignores hardware input until UI initialization
has completed. Both failures have tests against the actual production functions;
ASan/UBSan checks cover response ownership, malformed/missing/oversized forecasts,
timeouts, queue/allocation failure, closed UI and input before/after startup.

App `d2e0ba7` records payload-free HTTP status/timing diagnostics and retries one
HTTP 502/503/504 within the original six-second fetch budget. Real local URLSession
server tests independently verify request counts, successful 503 recovery,
terminal 503, late response without budget extension, no 429 retry and cancellation.
The physical phone also returned HTTP 503 intermittently; this remains a real
upstream failure and must not be reported as a successful forecast.

Physical display readback on the watch shows 13.2 degrees, visible forecast
content and an empty error label in both foreground and normal Home background
checks. SWD captures verify the CPU remained running before and after every read.
The complete app d2e0ba7 / firmware ae9a28d1 background case passed after an
explicit cold watch reboot: fresh GPS, two four-day UI updates and Ready209 with
zero pending HTTP/no error (324ms, 1,141 response bytes). The phone had remained
in Home background for 568.183 seconds; a separate XCTest assertion subsequently
confirmed background/suspended state without activating it. All 33 original
sources / 673,009 bytes matched their full hashes and the original 115,212-byte
watchface hash was unchanged.

Reopening Weather with cached GPS exposed system-stack high-water 5840/6144,
versus 5216/6144 after the fresh-GPS path. Firmware `ecd78bfc` also queues the
cached-GPS request outside LVGL app startup, avoiding its 512-byte URL buffer on
the rendering call stack. Both final image hashes are active/confirmed; the
signed app and firmware/ELF are retained under
`.companion-hil-runs/20261015-ios-companion/weather-repair/`.

2026-10-16 final ecd78bfc acceptance is complete. Matching-ELF SWD reads show
15.0 degrees, visible forecast content and an empty error label. The CPU remained
running before/after every read, with no connect-under-reset fallback. After an
explicit clean boot, GPS arrived at32.796s and Weather opened with that cached
location at157.665s. System work high-water is5216/6144 (928 unused), BT RX5012/9504
(4492 unused), main1360/2048 (688 unused). The earlier running-session system
high-water was5840/6144 (304 unused); that is retained as a separate overall
observation, not replaced by the lower clean-Weather measurement.

Native Ready218 independently records HTTP success161ms/1138 bytes, no pending
requests and no error. All33 phone source files were copied and independently
SHA256 checked again:673009 bytes, every original hash unchanged. The last full
watch-source and watchface byte/hash readbacks above remain retained. The watch's
separate USB data cable is absent on Oct16; the final check used phone BLE shell,
UART and SWD. The generic Bluetooth `kernel thread stacks` report is limited to
1024 bytes and truncates before the system thread; it is not used as complete
stack evidence. The temporary phone authentication and disconnected-debug-lead
blockers are resolved. No additional firmware change was needed after ecd78bfc.

## Validation and reproducibility

All 347 Flutter tests pass and full Flutter analysis is clean. Native core,
recording purge, voice-job and firmware-contract host checks pass. Actual Nordic
SDK fake-transport tests pass encoded ACK pause/drain/resume, offset rewind,
parameter cancellation/reuse, late replies and terminal self-retention.
The signed Release build and deep/strict signature verification pass. Android
native compilation is unverified on this Mac because Android SDK/JDK are absent;
shared Dart changes are covered by the Flutter suite.

See `IOS_MAC_BASELINE.md` for the isolated build workspace used to avoid the Mac's
Documents-folder tooling restriction. From its `zswatch_app/`, run ordinary
`flutter pub get` and `flutter build ios --release --no-pub`. Keep the exact
submodule pins, CocoaPods path-vendored Nordic SDK and signing team. For a signed
build use `build/ios/Release-iphoneos/Runner.app`; the generic output directory can
retain a previous Debug build. `HANDOFF_TO_MAC.md` and the HIL README document
USB/DTR bootstrap, explicit probe selection and one reader per serial port.

## Remaining physical acceptance and iOS limits

The first-launch installation used separate app storage and the same release
executable. After XCTest accepted the phone authentication, normal UI passed:
Connect your watch → Add watch → Find watch, explicit OS Bluetooth denial and
Settings recovery (9.257s), grant and native scan (19.617s), then first selection
and encrypted Ready (24.620s). Independent receipts prove no scan/Start on denial,
scan/discovery/stop after the grant, and fresh Ready generation 2. The existing iOS
system bond was retained; no new system pairing/unpair is claimed. The owned test
installation was stopped and removed. Original Ready 186 and all 33 saved recording
hash/size receipts are unchanged.

Actual user force-quit also passed through the app switcher: the focused card
was swiped away, an independent process snapshot found the app absent, twelve
seconds stayed notRunning, and explicit reopening recovered fresh Ready 189 with
all33 original downloaded receipts unchanged. The whole UI check passed in 27.890 seconds.
This is separate evidence from the injected-kill OS restoration check.

Other unverified variants stay explicit in `IOS_FEATURE_PARITY.md`: first unlock
after phone reboot, independently timed out-of-range recovery, denied
location/EventKit permissions, manual DST changes, interruption inside STT, and
system-scheduled AI execution. These must not be inferred from ordinary relaunch,
a short Home interval or host tests. Long endurance testing is left to the user.

CoreBluetooth restoration needs an eligible BLE event; it is not a periodic
restart service. On iOS 18 and later, the app now uses AccessorySetupKit
for per-accessory authorization and a one-time migration of an existing bond,
before creating CBCentralManager. On iOS 26 and later this enables the
force-quit restoration path documented by Apple. The original CoreBluetooth-only
force-quit result above describes the earlier build, not the current one. See
[Apple TN3115](https://developer.apple.com/documentation/technotes/tn3115-bluetooth-state-restoration-app-relaunch-rules)
and [Apple's clarification](https://developer.apple.com/forums/thread/806013).

### 2026-10-16 — user force-quit, automatic relaunch and Weather PASS

The existing bonded watch was migrated using ASMigrationDisplayItem without
unpairing or changing its identifier. iOS displayed “Ready to Use”; dismissing
it returned protocol Ready. The process-owned ASK session supplies authorized
identifiers; startup waits for activation and never shows setup UI during
background restoration. New discovery uses the system picker; iOS 14–17 retain
the previous CoreBluetooth path. Authorization removal fences running intent.
Stop and Forget continue to prevent automatic connection; Forget retains the
system association/bond as described in the UI.

A real app-switcher card swipe produced XCTest `notRunning` (32.766-second
check). No test activated the companion afterward. iOS automatically relaunched
PID 3217, recorded a fresh CoreBluetooth restore callback at
2026-10-16T10:49:07.122Z and reached Ready 223. A subsequent physical SWD watch
reset recovered Ready 225 while the app stayed in the background; an independent
XCTest observed background state 3 without activating it. The user opened Weather
on the watch and reported a temperature. UART records fresh GPS and four forecast
updates; native HTTP receipts show a 1,452ms/1,137-byte response written with no
pending requests. Read-only SWD confirmed 15.0°, an empty status label and visible
content, with the CPU running before and after every read.

Explicit Disconnect remained stopped at generation 226 across another watch
reset; explicit Connect recovered Ready (3.279-second UI check). All 33 original
phone sources were recopied and SHA-256/size checked: 673,009 bytes unchanged.
All 348 Flutter tests and analysis passed; signed Release build and signature
verification passed. Evidence is in the ignored `accessory-setup` directory above.

The Weather measurement above used the first signed ASK build. The final
`a6f5314` build additionally preserves intent on ASK session invalidation and
retains cancellation of stale OS-restored handles. A repeat caught a transient
SDK central-poweredOff error during cold SMP service-change preparation; this
was not counted as acceptance. The final code retries only the idempotent
preparation echo once after 250ms, within the original deadline. Seven tests of
the actual method cover transient success, the retry cap, terminal errors,
Stop, changed generation and deadline fences. The final physical repeat passed
cold SMP preparation/Recording:no and real force-quit (32.331s), autonomous
PID3228/Ready234, fresh restore callback at 2026-10-16T11:00:01.077Z and an
independent background-state3 observer. The retry branch itself was exercised
by the deterministic test, not observed in the final successful phone trace.
All33 source files were recopied and rechecked after the final installation.

This verifies the existing-watch migration on iPhone 11/iOS 26.1. A fresh unbonded
ASK pairing, OS authorization revocation, and iOS 18/older-device behavior have
not been physically exercised. HID discovery support starts at iOS 18.4. iOS
14–17 have no ASK force-quit relaunch exception. iOS still decides when an eligible
BLE event relaunches the app; this is not a perpetual background execution claim.

AI waits when iOS
has not granted execution; no permanent background process or immediate locked
phone inference is promised. Phone Clock alarms are not created: actions use
local notifications. The existing firmware has local notification dismissal,
not ANCS phone-action dispatch. Earlier-app recordings remain readable/exportable;
editing or processing those separate legacy rows has no migration path. New
native recordings have the full editing and processing controls.

App storage, the original stash and the Mac handoff backup are preserved. Owned
watch fixtures and native fixture receipts have been removed; cleanup journal
maintenance is distinguished from normal product acceptance in the progress log.
Some explicitly owned test downloads may remain in Files/Safari until UI access
is available. No user files are scheduled for deletion.


## 2026-10-16 — missing speech model and automatic-job recovery

The user's latest recording did capture the enabled automatic policy and create
and claim a job, but failed before transcription with `model_missing`: selected
Whisper Small English was absent, while Qwen was present. Restoring a model
selection in earlier acceptance did not establish that model's local availability.
The generic blocked label incorrectly suggested processing permission was needed.

App `95df44f` checks downloaded speech/analysis models before automatic opt-in
or applying a running policy, skips the analysis-model requirement for
transcription-only use, and leaves disabling unrestricted. A blocked missing-model
job now shows the cause and a Download models route alongside Retry processing.
The selected 487,614,201-byte speech model was downloaded through normal phone UI.
Only the affected job was retried, retaining its original spec/identity: transcript
saved after32.483s, analysis after another38.279s, watch ACK after900ms, final
state delivered. The entire UI check passed in82.056s. Other19 jobs and the user's
automatic policy are unchanged; all35 audio source sizes/SHA256 were checked.
An earlier recording was discovered before opt-in and intentionally remains manual.

All349 Flutter tests and analysis pass; signed Release build, strict signature
verification and build-input comparison pass. Evidence and final Runner.app are
in ignored `voice-model-readiness/` alongside the previous ASK artifacts. This
is foreground recovery of the already-created automatic job, not evidence of a
system-scheduled background AI grant or a new post-download automatic recording.

## 2026-10-18 — review fixes on the Mac (`HANDOFF_REVIEW_FIXES.md`)

App `7fad5de` (contains the Linux-written Swift fixes `f857ec1`). WatchDK firmware
reports `result_ack_version: 1` (no reflash). WatchDK without debugger or UART;
the watch was driven through the USB shell (`voice_memo start/stop`, `app launch`).

**Build.** `flutter build ios --debug --no-codesign` and the signed Release build
compiled the four Swift files without changes. Strict signature verification passes;
installed with `devicectl device install app` (data retained). `flutter test`
356/356, `flutter analyze` clean.

**iOS regressions and new behaviour (passed).**

| Check | Result |
| --- | --- |
| Connect after durable Stop | Ready in about 1 s (generation 272), 41/41 recordings retained, telemetry projected every 10 s with 0 pending |
| Recording sync + voice | Manual 10 s recording: list immediately → download → transcript after 31 s → result and watch ACK at 10:28:02 |
| 300 s recording (1.2 MB) | Uninterrupted download about 58 s (about 20 KB/s), job created |
| Resume after SIGKILL | Killed at 303 KB (313 KB on disk); after relaunch (CoreBluetooth restore, generation 277) growth resumed from 313 KB within about 3 s; a full prefix re-read would take about 15 s. Phone SHA-256 = USB readback from the watch (585 373 B) |
| Background deferral | `voice_execution_deferred` / `background_deferred` 1 s after the app was sent to the background |
| Background GPS, stationary | App in background from 10:42 (same PID, never foregrounded); the Weather periodic GPS request produced a fix and HTTP fetch at 11:01 and 11:31 |

**Not done yet (needs the user):** Control Center/Face ID during transcription,
Demo Mode + kill/relaunch, scan/selection, a watch that never reaches Ready.

**Observations, not attributed to the review fixes.**
- Firmware caps a recording at 300 s (`ZSW_RECORDING_MAX_DURATION_S`), about 1.2 MB, so
  a "several MB" recording cannot be produced.
- `devicectl process terminate` without `--kill` (SIGTERM) does not end the app.
- The watch disables SMP after a few idle minutes; iOS sees `services_fenced`
  and reconnects in about 3–5 s. Expected, but visible as a short reconnect.
- Once, the new-recording notification after a 300 s auto-stop was not seen: the
  list only arrived after the next reconnect 5 minutes later. A second auto-stop
  arrived immediately; not reproduced.
- Mac speaker → watch microphone gives poor input: a 5 min recording became
  `[bouncy music]` (`analysis_empty`, permanent), and an English sentence was
  transcribed as Swedish gibberish with `whisperSmallMultilingualQ5` auto-detection.

**Android on the Mac.** Installed Homebrew `openjdk@17`, `openjdk@21` and
`android-commandlinetools`, SDK platforms 35/36, build-tools 36.0.0 and NDK
29.0.13113456 in `~/Library/Android/sdk`. `flutter build apk --debug` passes.
`./gradlew :app:testDebugUnitTest` needs **JDK 21** (LiteRT-LM `Engine` is class
version 65); with JDK 17 `LiteRtLmBridgeTest` fails to load. With JDK 21: 267/267.
The Nokia G100 had an app signed with a different debug key; with the user's OK it was
uninstalled and the new debug APK installed (starts without a crash).

**Android BLE on the Nokia G100 (Android 12), 2026-10-18.** Paired after the iPhone
Bluetooth was turned off (iOS Stop does not drop the physical link; see below).

| Check | Result |
| --- | --- |
| Connect / Ready | Ready 12:22:06, time, media and device info synced; list of 45 recordings with `result_ack_version: 1` |
| Long link | Generation 11 stayed up about 1.5 h with health/status every 10 s |
| Bluetooth off/on (`svc bluetooth`) | `transport_suspended`, Ready again about 6 s after enable, time/media/list re-synced |
| Time zone change | London and back: `time_write_completed` within about 3 s each, offset 1 then 2, link unchanged |
| Recording download | **Fails.** All 45 `failed` with `McuMgrNotSupportedException` |
| Restart Watch | **Fails** after about 22 s: `RESTART_FAILED, SMP preparation timed out` |

SMP never becomes available on the Nokia. After `smp status:true` the Nordic transport
reconnects and calls `discoverServices()` about every 1.8 s, but receives Android's
cached GATT database without the SMP service; no Service Changed indication from
the watch is seen in the Bluetooth stack log. iOS sees the same SMP enable as
`services_fenced` and downloads normally. The download path and SMP code were not
changed by the review fixes. Without watch logs it is open whether the watch sends
Service Changed to this bond.

Related Android gaps found:
- `failed` is terminal: a reconnect does not retry, and the normal Voice screen shows
  "Retry failed downloads" only on iOS (`if (ios)`). `retryRecordings` is only reachable
  from the unlinked `/developer/companion-runtime` route.
- A transport error unrelated to the file (SMP not ready) marks every pending
  recording `failed` in sequence instead of stopping the batch.

After the user's approval, all runtime permissions and notification-listener
access were granted with `adb`, location sharing and forwarding for `com.android.shell`
were enabled in the app.

| Check | Result |
| --- | --- |
| Notification updates | 26 revisions of one notification coalesced: revision 26 delivered with 2 writes |
| Burst of 25 distinct notifications (0.3 s apart) | All queued and written, link unchanged (generation 14) |
| GPS | Watch Weather request 14:53:42, `gps_written` 3 s later, watch HTTP fetch completed 14:53:53 |

**Bug: watch eviction deletes phone notifications.** The watch stores at most 10
notifications (`ZSW_NOTIFICATION_MGR_MAX_STORED`); a full list removes the oldest, and
every removal sends `DISMISS` to the phone (`zsw_phone_app_publisher.c`). The Android
companion then cancels that notification on the phone. After the burst only 10 of the
25 test notifications remained on the phone. The watch should only send a dismissal for
a user action, not for capacity eviction.

**SMP on Android, analysis.** `onServiceChanged` never fires on the Nokia (0 log hits,
generation stays 14), while iOS gets `services_fenced` for every SMP enable. Likely
cause: the watch was re-bonded (reset and pairing 12:22) and lost its Service Changed
CCCD for the Nokia, while Android kept its earlier bond state and did not re-subscribe.
Earlier Nokia runs saw Service Changed. Options: re-bond on both sides to confirm, and/or
refresh the GATT cache (`refreshDeviceCache`) when SMP reports not supported.

Manual clock change: with automatic time off, `cmd alarm set-time` +2 h and back each produced
an immediate time write to the watch; link unchanged (generation 37); automatic time restored.

Not run: AI failure handling (no new recording could be made without the USB shell).

**Firmware reflash with RTT, 2026-10-18 16:56.** Built `codex/ios-companion` `5883d716`
with `boards/debug.conf;boards/log_on_rtt.conf` (NCS v3.3.0-preview1, per
`.github/copilot-instructions.md`) and flashed with `west flash --runner nrfjprog`
without `--erase` (sector erase; external flash only `0x10120000-0x10195A07`), so bonds,
recordings and resources were kept. `nrfjprog` 10.24.2 was unpacked without sudo to
`~/.local/opt/nrf-command-line-tools` and wrapped in `~/.local/bin/nrfjprog` with
`--jdll` for the user-local J-Link V9.24a. RTT is read through `JLinkExe` (port 19021).
Boot log: `*** Booting WatchDK v0.8.1-5883d716285f ***`. Both phones reconnected.
The watch releases USB after 20 s without a host (`USB boot guard timed out`), which is
why the USB shell disappeared earlier.

RTT with `CONFIG_BT_GATT_LOG_LEVEL_DBG` confirms both Android findings:
- SMP: the watch logs `SMP enabled` on request, but restores Service Changed
  configuration only for two Apple addresses (`9C:28:B3:E2:4A:2A`, `48:74:12:58:06:5A`),
  not for the Nokia (`74:8A:28:B7:1B:94`). On connect the Nokia writes only the NUS
  CCCD and never subscribes to Service Changed, because Android believes its existing
  bond (`CF:4B:3D:A1:C5:E2`) is already configured. Zephyr therefore sends no Service
  Changed when SMP registers, and Android keeps a cached GATT table without SMP. Bond
  state drift, not a review-fix regression.
- Notifications: with 10 stored, notifications 11 and 12 evict IDs 1000051/1000052
  (`Remove notification on place 0/1`), the watch sends DISMISS, and the phone cancels
  `ev1`/`ev2`.

**Device switching.** iOS Stop only calls `cancelPeripheralConnection`. iOS keeps the
physical link for ANCS/AMS, and the watch allows one connection (`CONFIG_BT_MAX_CONN=1`),
so another phone cannot connect until iPhone Bluetooth is turned off. A real
disconnect needs the watch to drop the link on request (no such message exists) or
an AccessorySetupKit removal on Forget. Android's first pairing attempts were rejected
(`reason=5`) because the watch only bonds in pairing mode; the old Android bond
`CF:4B:3D:A1:C5:E2` remained after the app uninstall. The watch's USB CDC device
disappeared after the user's watch reset, so USB-shell control stopped at 14:05.

**Fixes, 2026-10-18.**
- Firmware, branch `fix/notification-eviction-dismiss` (`2de73aab`, from `origin/main`): `zsw_notification_remove_event` carries a reason
  (user, phone, evicted); `DISMISS` is sent to the phone only for a user dismissal.
  Verified with RTT: notifications 11 and 12 evicted IDs 1000063/1000064 on the watch and
  all 12 stayed on the phone. Also stops echoing phone removals back as dismissals.
- Android (`NativePrototypeTransport.kt`): when the Nordic SMP transport reports
  `McuMgrNotSupportedException`, the app clears Android's GATT cache
  (`BluetoothGatt.refresh()`), reconnects after 0.5 s like a service change (max 2 attempts,
  reset when SMP is ready), and keeps an affected download `pending` instead of `failed`.
  Verified on the Nokia without re-bonding: `smp_gatt_refresh refreshed=true`, full
  discovery (1.4 s instead of a 7 ms cache hit), then Restart Watch succeeded twice.
  Kotlin tests 267/267. The first attempt directly after a refresh is not yet verified
  with the 0.5 s reconnect.
