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
| Signed app executable | App `a6f5314` (AccessorySetupKit migration/relaunch and bounded SMP initialization recovery); includes `d2e0ba7` Weather HTTP diagnostics and bounded transient retry |
| Nordic fork | `06644b17bec8202605afba2065ba8b5f7ef00fcb` |
| fllama fork | `115e7991e78de446ed44858ebe0a8dbc82769d8e` |
| Installed WatchDK firmware | `ecd78bfc`, nested `ZSWatch/`, branch `codex/ios-companion` |
| Signed development app | `.companion-hil-runs/20261016-ios-companion/accessory-setup/Runner.app` |
| Local evidence | `.companion-hil-runs/20261015-ios-companion/` and `.companion-hil-runs/20261016-ios-companion/accessory-setup/` |

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
