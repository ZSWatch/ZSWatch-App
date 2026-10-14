# Native iOS companion progress

2026-10-12; branch `codex/ios-companion`. This is a development checkpoint,
not completion of IOS_COMPANION_IMPLEMENTATION_PLAN.md.

## Implemented foundation

The ordinary iOS Flutter app now selects the native companion without a build
flag. AppDelegate creates a process-owned Swift coordinator before registering
Flutter observers. UI subscription cancellation does not stop the connection.
The Add Watch route discovers nearby ZSWatch devices; saved watches use
CoreBluetooth UUIDs. Android MAC contracts and its companion picker remain
supported. Saved watch metadata stays in the existing Dart catalogue.

Native intent and monotonically increasing session generations are persisted
atomically under Application Support/ios-companion/state.json. Stable central
restoration identifier: `dev.zswatch.companion.central.v1`. Stop and Forget fence
callbacks before closing handles. Restore callbacks cancel peripherals that do
not match current intent. Service changes invalidate queued writes and old
characteristic callbacks. Reconnect uses bounded backoff; NUS readiness requires
service/characteristic discovery and a successful notification subscription.

NUS JSON and wrapped BLE logs are bounded and reassembled across ATT/UTF-8
boundaries. Incomplete frames expire, and an interrupted log cannot swallow
future protocol messages forever. Writes use actual CoreBluetooth payload sizes
and its without-response flow control. Clock commands stay whole; standalone
firmware timezone commands require the leading semicolon. Firmware CTS remains
the normal iOS system-time path; app sync is explicit or watch-requested.
Diagnostic log/traffic streams observe this owner and do not open a new link.

ANCS authorization is exposed and iOS notification settings explain system
sharing. Forget removes app selection and fences metadata but cannot remove an
iOS Bluetooth bond; the UI explains the separate Settings step. The timer/alarm
Swift functions are named as local notifications rather than Clock-app actions.
The broader voice-action UI and execution path still need iOS integration.

## Storage decision and telemetry

Swift never opens the Flutter SQLite database. Native health, battery and
connection receipts remain in its protected journal until Flutter commits them.
Dart projects them into the existing tables and commits a journal watermark in
the same transaction. A crash between DB commit and native acknowledgement
therefore replays without duplicate samples. Missing watch rows wait for the
verified Ready catalogue; projection does not recreate forgotten watches.

Schema 9 adds `companion_telemetry_cursors`. Schema 8's legacy voice repair is
retained. Android's native telemetry schema allowance now includes version 9;
no Android native build is claimed on this Mac.

Each channel batch contains at most 200 telemetry receipts. Native storage holds
8192 pending receipts and exposes `telemetry_dropped` if it exceeds that bound;
this is a retention limit, not an unlimited collection guarantee. Event replay
holds 128 diagnostic events with an explicit gap indicator. Native file
protection uses first-unlock protection; unreadable/corrupt storage fails closed.

## Validation and device evidence

- Standalone Swift tests cover intent persistence, Stop/Forget fencing, malformed
  storage (including Boolean generation), durable telemetry acknowledgement,
  fragmented UTF-8/nested JSON, log interruption and bounded framing.
- Dart telemetry tests cover replay after lost acknowledgement, transactional
  rollback, a missing catalogue row and Forget tombstones.
- The broad companion regression run passed 199 tests. After the final
  timer/alarm wording changes, the 26 affected action/app-shell tests passed
  again. Targeted analysis of 17 foundation files and 3 action files is clean.
  Retained logs are in the ignored
  `.companion-hil-runs/20261012-ios-native-foundation/` directory.
- Signed normal release builds use the isolated `/tmp` workspace described in
  IOS_MAC_BASELINE.md. Use `build/ios/Release-iphoneos/Runner.app` explicitly:
  after a Debug build, `build/ios/iphoneos/Runner.app` can retain an older Debug
  artifact even when a later Flutter Release command reports that output path.
- Physical probes use the existing native bridge on the connected iPhone 11.
  Debug probe 1 reached discovery and timed out; its app-level Flutter error
  handler also interfered with test reporting. Debug probe 2 could not complete
  the macOS Xcode automation path. Neither is a BLE pass.
- The signed release probe `tool/ios_companion/ble_probe.dart` launches the
  ordinary app and writes a small result file to Application Support. Its actual
  21:44:53–21:45:20 UTC result reports Bluetooth permission false, then
  `PERMISSION: Bluetooth permission is pending`. That is the current device
  blocker. The user has been asked to allow the on-device Bluetooth prompt.
- The 55-second UART capture in `20261012-ios-native-ble-probe` contained zero
  bytes; it predates the successfully launched release probe and proves no BLE
  event. Earlier baseline UART/USB proofs remain valid only for their scope.
- The final USB status still reports 26 original recordings, not recording,
  with 9464 KB free. No firmware reset, flash, recording deletion or system
  unpair was performed.
  No actual watch response, background exchange, throughput or genuine OS
  restoration is claimed by this checkpoint.

## Next required work

1. After iPhone Bluetooth consent, verify discovery, protocol responses, observer
   detach, Stop and reconnect; then separately test background watch exchanges
   and actual CoreBluetooth restoration. An injected kill/cold launch is not
   evidence of OS restoration. Force-quit requires reopening.
2. Complete native GPS/HTTP/weather, Find phone and live/history acceptance;
   verify ANCS/CTS/AMS on the watch. Make the pinned Nordic plugin registration
   lazy so it cannot request Bluetooth before an explicit connection action.
3. Coordinate the modified Nordic SDK for shell, files, firmware/resources and
   watchface operations, measure acknowledged bytes and recovery, and perform
   the plan's real update acceptance without erasing original recordings.
4. Add native recording list/inbox/download and durable processing jobs, then
   connect the existing shared Dart worker/processor under an explicit iOS
   foreground/background/expiration policy. Finish existing model and action
   controls, offline processing, playback/export and legacy recording visibility.
5. Close every parity row with implementation plus physical evidence or a real
   documented platform limitation; verify demo isolation and all ordinary routes.
   Commit the completed changes and supply the signed artifact/instructions.

Relevant platform references remain Apple's
[CoreBluetooth restoration guidance](https://developer.apple.com/library/archive/qa/qa1962/_index.html)
and [Core Location background setting](https://developer.apple.com/documentation/corelocation/cllocationmanager/allowsbackgroundlocationupdates).

## 2026-10-13: native everyday services and coordinated Nordic operations

Bluetooth authorization is now granted on the iPhone. The first release probe
found ZSWatch UUID FE88C737-593F-DB9B-732D-E11FF4C463F5 (RSSI -49), connected,
discovered NUS and began its encrypted notification subscription. Simultaneous
UART evidence shows MTU 244, data PDU 251 and 2M PHY. Pairing timed out after
about 31 seconds (firmware SMP reason 9); this is not protocol Ready evidence.
Firmware requires Settings > Bluetooth > Pairable > Enable, a 60-second window,
then iPhone pairing confirmation. No bond deletion is used to bypass that step.

The discovery deadline now allows an encrypted CCCD subscription to wait for
pairing. Picker results are restricted to ZSWatch and throttled rather than
persisting every nearby advertisement. A second probe exposed a disconnected
restored peripheral being retained in the cancellation set; cancellation now
ignores disconnected handles and observes pending cancellation completion.
The actual CoreBluetooth restoration delegate was called during the explicitly
terminated/relaunched probe, and respected Stop. That does not prove a genuine
system termination/background-triggered restoration case.

Implemented modules, with physical acceptance still pending:
- Native GPS serves only explicit watch requests after sharing opt-in. Cached
  fixes expire after 30 seconds, invalid/coarse fixes are rejected and packet
  units retain the existing firmware contract. When In Use permits foreground
  operation; Always is required for background requests. Watch-off, Stop,
  disconnect, disabled sharing and permission loss fence pending packets.
- Native HTTP has four concurrent requests, bounded streaming response size,
  an eight-second total delivery deadline, duplicate suppression, session-bound
  NUS admission and bounded XML XPath. Request data is not journaled. A short
  UIKit background task expires by cancelling the requests; it is not a
  permanent process guarantee. Explicit per-request insecure TLS remains
  supported without changing other requests' TLS policy.
- One process-owned Nordic adapter coordinates preparation, shell execution,
  known log downloads, coredump summary/download/explicit erase and acknowledged
  Restart Watch. Mutating commands are never automatically replayed. Shell
  results use Zephyr's signed `ret`, distinct from SMP's `rc`.
- Ephemeral sensor subscriptions use the existing NUS peripheral and expose
  only discovered characteristics. Closing the view unsubscribes. Subscription
  timeout fences the session rather than assigning a late CCCD response to a
  newer request. Diagnostic streams do not create BLE connections.

The existing Nordic fork now contains the same upstream iOS SDK 1.10.1 source,
license and original-file SHA256 manifest, with four modified upstream files
and one small admission helper. This makes the fixes reproducible through a
local CocoaPods path while retaining the SDK's SMP/file/DFU implementations.
Fixes include correct service discovery, real without-response flow control,
terminal cancellation of queued work, poweredOn retrieval and signed shell
return values. Flutter plugin registration creates no Bluetooth manager.
Nordic local commit: caa1650, branch codex/ios-companion. No push performed.

Validation: four host Swift executables pass (SDK lifetime, HTTP, GPS and
coredump), 19 affected Flutter tests pass and analysis of the five changed Dart
implementation/probe files is clean. Signed normal and probe Release builds
pass (about 80.6 MB). Evidence is retained under the ignored
.companion-hil-runs/20261013-ios-companion directory; Release-iphoneos/Runner.app
is used explicitly. Tests of sensors, shell, GPS/Weather, reset, and crash files
on BLE remain pending encrypted Ready. Firmware/resources/watchface transfers,
recording receipts/jobs and shared Dart worker integration remain unfinished.

## 2026-10-13: recording receipts and shared Dart execution

Native recording list/new-event handling now captures header/list metadata and
keeps up to 4096 source receipts. New-event stop timestamps never become source
identities. Downloads use the same exclusive Nordic adapter, validate every
returned offset/length and re-read a saved prefix before resuming it. Files are
staged under the existing companion-prototype/recordings contract, validated as
complete supported ZSWO containers and renamed before committing the journal
receipt/hash. Process recovery can adopt a completed source after a lost journal
commit. Original watch files are never deleted by this path.

Stop/disconnect, disabled sync and UIKit expiration invalidate active SDK work.
Interrupted downloads stay pending with their partial file. Background windows
are bounded, with a foreground retry path; no permanent processing claim is
made. Automatic local processing captures the enabled model policy when a
recording first enters the inbox. Failed/cancelled generations are not silently
recreated by automatic maintenance.

Native durable jobs reuse the shared companion_voice_processor.dart entry point.
They preserve transcript checkpoints, selection, attempts and monotonic fences.
Transcribe, retranscribe, process and reanalyze are exposed; reanalysis reuses a
saved transcript. Local processing does not require a live BLE link on iOS.
Matching application result ACKs establish delivered state; ATT completion does
not. Old firmware without negotiated receipt support remains pending.

A single headless processing FlutterEngine registers path-provider, FFmpeg and
a memory channel, with no BLE plugins or Drift writer. Its explicit library URI
works with both ordinary and diagnostic entry points. It stays idle after first
use because the pinned fllama fork retains native logger callbacks until its
next request; destroying the isolate would leave native callback pointers.
The shared processor awaits native Whisper disposal before loading an analysis
model. Private inference prompts/transcripts are not routinely logged by the
iOS worker. This idle engine supplies no extra background execution time.

Execution policy is CPU in foreground or a system-granted BGProcessingTask.
Leaving foreground fences and cancels an ungranted active attempt, retaining its
checkpoint; task expiration does the same. Scheduling failures are visible and
opening the app can continue queued work. BGContinuedProcessingTask/GPU access
is not claimed. Apple's deferred scheduling is described in
[BGProcessingTaskRequest](https://developer.apple.com/documentation/backgroundtasks/bgprocessingtaskrequest).

The existing Mac Whisper wrapper fixes are now retained in NativeSupport and
selected by CocoaPods without editing the pub cache. Its package archive SHA256
matches pubspec.lock; a complete iOS source comparison found only the wrapper
modified and no added cache files. CPU default and disabled CoreML prevent an
implicit accelerator path for these jobs. Underlying Whisper/GGML and fllama
sources remain the existing pinned dependencies.

User-confirmed action receipts now cover creation, recovery, dismissal and undo.
EventKit entries carry an app marker; admission is persisted before mutation.
Recovery never blindly duplicates an admitted action with an unknown outcome.
Timers/alarms use stable app-notification identifiers and retained fire times;
iOS review wording says Schedule alert. Action and calendar/reminder acceptance
on the phone is still pending.

Physical worker proof: the first signed probe failed WORKER_START_TIMEOUT due to
the diagnostic build's entry-point library. The corrected iPhone probe passed
2026-10-13 07:23:48–07:24:03 UTC, returning plugin_ready, path-provider, FFmpeg
version n8.0 and available-memory information. It executed a fixed metadata
fixture, with no audio/model/watch mutation. It proves the headless runtime and
plugin seam, not transcription, analysis or OS-scheduled execution. The two JSON
results and console logs are retained in .companion-hil-runs/20261013-ios-companion.

Source receipt and job host tests pass, including incomplete-file recovery,
metadata/symlink rejection, stale checkpoints/results, reanalysis transcript
reuse, immutable action confirmation and ACK matching. Thirteen affected voice
Flutter tests pass; signed worker builds pass. Normal Release and final targeted
analysis are also recorded with this checkpoint. Real models, background
expiration/restoration, encrypted BLE downloads and original-file comparisons
remain physical acceptance work. Search/archive/local deletion/edit/export and
legacy recording presentation still need integration into the native receipt
view. Firmware/resources/watchface work remains open; the goal is not complete.

## 2026-10-13: watchface operation integration

The existing gallery/crop/upload/reset UI now has a native backend. The exclusive
Nordic owner retains payloads and the upload delegate after UI disposal. SDK
upload progress is bounded and monotonic, then file status and complete byte
readback verify /user/bg_new.bin before sending the existing NUS apply command.
Reset uses the existing NUS-only command. Matching action/result and current
Ready generation establish completion. Lost replies remain uncertain; retry of
the same uncertain action requires reconnect, since this firmware reply has no
operation identifier. Process loss leaves an explicit interrupted status.

iOS UUIDs are accepted by the shared watchface status decoder. Ten affected
Flutter tests pass, including all built-in image headers, native-only gallery
routing, UI disposal and reattachment to terminal/progress snapshots. Signed
Release builds pass. No physical image was applied/reset without encrypted
Ready, so actual appearance and transfer throughput remain pending. Firmware
image/resources transfers are still unfinished.

SDK firmware-input review also found unchecked header/TLV reads that could trap
on a selected truncated file. The same Nordic image parser now checks its bounds
and uses aligned integer copies. Host tests compile that actual parser/read
method and pass valid-envelope, short-header, malformed-table/entry and unaligned
read cases. The signed normal Release build with these SDK changes passes. This
is preparation for the firmware adapter; no firmware transfer/flash is claimed.

## 2026-10-13: offline recording controls and pairing investigation

USB touch injection can enable Pairable on this watch. The Settings layout was
checked using the current firmware Settings source and a headless build of its
LVGL layout before sending the two taps. UART then explicitly reported
`ble_comm: Enable Pairable`. USB status before and after still reported 26
recordings and 9464 KB free, with no recording running. The installed shell has
no `bt` command or dedicated pairing command. No bond clearing, firmware flash
or watch recording deletion was performed. The pairing window expires normally.

A signed standalone Xcode UI-test runner built and reached the iPhone, but
initialization failed with `Timed out while enabling automation mode` before
test methods ran. The phone reported unlocked with an active display; the Mac
computer-use tool separately reported a locked Mac. These observations do not
establish the exact cause of the automation timeout. The user is away from home,
so pairing and physical acceptance remain pending; no further manual action is
required for the implementation work in this checkpoint.

The native receipt view now offers title/transcript/action search, category and
archive filters, rename, archive/unarchive, copy/edit/export text, verified Ogg
audio export, selected-only processing and local deletion with Restore.
Private transcript search runs in the native job store and returns matching
identities, rather than putting full transcripts into observation snapshots.
Archive/title changes are journal-owned and survive transfer completion.

Editing creates a selected immutable transcript revision, fences older attempts
and clears the new revision's analysis/action draft. Reanalysis uses the saved
edit. Previous revisions and their action receipts remain accessible; edits do
not silently change already-created calendar entries or scheduled alerts.

Local deletion first fences selected jobs and persists receipt tombstones, then
moves only generated local audio/cache paths to Recently deleted. Recovery
completes interrupted moves without reviving a deleted receipt as a download
candidate. Restore revalidates the original source/hash and does not recreate
automatic processing requests. UI conversion and deletion share the Dart file
publication lock. A late cache publication is retained inside trash without
overwriting the removed copy. Recently deleted data remains retained until
restored; permanent purge/storage reclamation is not implemented in this
checkpoint. No watch-delete protocol command is sent.

Earlier app database rows have a separate local view with search, existing
archive filtering, transcript copy/text export, verified playback and audio
export. Their filename is never adopted as a native watch identity. Unsupported
or unavailable audio remains retained. Editing/processing earlier rows through
the new owner still requires a verified migration path.

Verification: 39 affected Flutter tests pass; targeted analysis of ten affected
Dart files is clean. Swift host tests pass for actual source-file removal,
interrupted/repeated moves, late cache publication, restore, immutable edits,
stale result rejection, selected-only job fencing and reanalysis. Export tests
check integrity, cleanup after a failed share and original-file retention.
Ordinary signed Release builds pass. Interactive phone controls, actual sharing,
speech playback, native BLE downloads and scheduled background execution remain
physical acceptance work. Firmware/resources/filesystem-browser work remains
open, and the overall goal is not complete.

## 2026-10-13: native firmware/resources update owner

The existing firmware selection/progress UI now routes to a native iOS update
owner. It takes the prepared Nordic transport, fences the NUS generation and
suspends ordinary reconnect/SMP admission during transfer. The retained SDK
manager/delegates survive UI disposal and the expected reboot. Stop, Forget,
radio loss, storage failure and background expiration invalidate the transport
and end the operation with an explicit uncertain result when a write was admitted.
Background continuation is limited to a system grant and a 20-second cap; no
unlimited upload or automatic reset replay is claimed.

Firmware input uses the actual bounds-checked Nordic MCUboot parser and SDK
slot-one Image/Upgrade APIs. The read-only preflight rejects selected indices
that this watch cannot report. Buffer negotiation chooses at most three pending
requests, leaving one of the reported buffers free; unsupported parameter
queries fall back to one. No Android MTU is copied into the iOS transport.
Snapshot progress describes the SDK's current image, not an invented aggregate
index. Progress persistence is throttled to avoid writing the journal for every
BLE packet.

SDK success begins a new boot check: reconnect NUS, obtain current-generation
version/status, prepare a fresh SDK transport, and require every selected image
to be active with its selected hash. Upload progress alone cannot complete the
operation. Only a verified, actually transferred ordinary image-zero update
records an acknowledged-byte throughput measurement; an already-active image
does not unlock the large-resource gate.

Resource inputs validate the existing /S/full_fs format, known board/partition,
UTF-8 names, table/trailer, entry bounds and non-overlap. Transfers receive full
byte readback before reset/firmware application, then another full readback of
the freshly mounted resource image. Resource-only reset requires an actual SDK
ACK. Images larger than 512 KB wait for a measured, verified ordinary firmware
transfer on this phone, following the plan's measurement order.

The vendored SDK retains version 1.10.1 and its normal cancel/DFU behavior. A
separate terminal abort API fences late transitions and releases its update
self-retention even when a cancelled transport never calls back. Its executable
proof compiles the entire actual SDK with the pinned CocoaPods dependencies,
uses no Bluetooth, and passes late-callback, no-restart and deallocation checks,
including teardown before start. Resource/state host tests and 24 affected
Flutter tests pass; targeted analysis is clean and signed Release builds pass.
These are implementation checks, not a physical firmware transfer or throughput
measurement. No watch image/resource was written or flashed.

Inventory clarification: the earlier File System screen exposed log probes and
downloads; its Files tab directed recordings to Voice Memos. A general directory
browser was not an existing product feature. Find Phone appears only in the
separate Chronos protocol/watch application, with no corresponding Gadgetbridge
session handler in this app. These do not justify inventing new protocols or
unrelated UI features for this rewrite. Native log/files, recording downloads,
resource uploads and watchface uploads still need their short physical checks.


### Native demo isolation and phone inspection (2026-10-13)

Settings now exposes Demo Mode on the native app. Entry first persists Stop and
rejects entry during an active firmware operation; a failed Stop keeps real
observers installed. Synthetic snapshots and sensor/log/traffic streams never
open a platform channel. Hardware commands are rejected, telemetry/catalogue
projection is disabled, and the earlier-recordings view stays empty in preview.
All six dashboard entrances remain navigable. Exit resumes only the pre-entry
connection intent; a process restart after demo entry retains native Stop, so a
normal Connect is required. Demo does not manufacture persisted watch/history
rows or grant permissions.

USB debugging can capture the real iPhone screen and enumerate its accessibility
elements while the Mac is locked. Accessibility Activate on the ordinary Connect
button has not caused an observed UI/connection transition. This is inspection
evidence, not successful phone control or pairing. The standalone XCTest runner
also timed out enabling automation mode through an independent USB test-manager
client, before either test method ran. No watch recording
was removed, no firmware was flashed, and physical acceptance remains open.

Large resource admission now requires a measured ordinary firmware transfer on
the selected peripheral UUID; a measurement for a different saved watch cannot
open the gate. Final signed artifacts and acceptance logs are recorded below when
verification completes.

Validation: 64 affected Flutter tests pass (firmware, native app shell, demo,
shared runtime, telemetry, catalogue); 12-file targeted analysis is clean. Actual
Swift firmware/resource state tests and the entire vendored SDK abort proof pass.
The signed release build passes; no physical firmware/resource transfer is claimed.


### Permanent local recording cleanup (2026-10-13)

Recently deleted now includes an explicitly confirmed permanent phone deletion.
Native persists the purge intent before removing selected job revisions, raw/partial
audio, converted Ogg, and recovered copies inside that identity's trash directory.
It retains a minimal source tombstone to prevent automatic watch redownload.
Already-created calendar entries and scheduled alerts are retained. No watch
delete or other BLE command is sent. Cleanup failure remains visible with Retry;
startup repairs the intent, including process loss before file/job cleanup.
Unavailable job storage cannot report cleanup complete or leave retained private
job text hidden behind a completed purge. Unknown files and symlinks are retained,
and the full generated file selection is validated before removal.

Actual Swift Inbox/file/journal/job source checks pass: interruption after durable
intent, unavailable job storage, restart cleanup, unselected data preservation,
refused restore, and rediscovery without download. File checks cover late converter
publication and unknown-trash refusal. Widget checks cover Cancel, selected-only
confirmation, completed/pending visibility and malformed purge flags. Demo now
also avoids opening the private recording import ledger. These are host checks;
permanent deletion has not been exercised on the user's phone data.

Final affected regression: 94 Flutter tests pass; six-file purge/demo analysis is
clean. The actual Inbox/file/voice host executables pass. Signed release compiles
with the permanent phone deletion controls. USB status after the firmware/demo
checkpoint reports 26 recordings, 9464 KB free, and recording=no; the watch is
still in Settings. No phone recording has been purged by these tests.


### Fresh BLE probe and bounded connection waits (2026-10-13)

A fresh signed probe found UUID FE88C737-593F-DB9B-732D-E11FF4C463F5.
The first attempt remained Connecting with a restored pending cancellation and
no pair dialog. Native now bounds the initial connection wait at 30 seconds,
retries a warming-central cancellation twice, and reports a retained cancellation
fence as a visible error. It does not clear that fence on timeout. Polling and
terminal callbacks require the exact tracked peripheral handle. Existing native
Stop remains available; error screens stop animating and show the saved reason.
Apple documents that pending connections have no intrinsic timeout:
[CoreBluetooth connect](https://developer.apple.com/documentation/corebluetooth/cbcentralmanager/connect(_:options:)).
The signed build and 23 native app-shell tests pass, including the new visible
error/Stop case (95 distinct affected Flutter tests across this checkpoint).

A second probe with the bounded native wait reached Discovering, Subscribing and
Bonding. UART confirms Pairable enabled, a BLE connection, LE 2M PHY, data length
251 and MTU 244. USB screenshot/accessibility inspection captured the real iOS
Bluetooth Pairing Request for ZSWatch. The exact Pair accessibility element was
activated once; no verified bond or encrypted Ready followed. UART records SMP
security timeout and Pairing Failed (9). The probe ended protocol_ready timeout
and persisted Stop without a cleanup error. Physical NUS/SMP/firmware/AI acceptance
is still pending. This security SMP failure is Bluetooth pairing, not a firmware
transfer attempt. No image/resource was uploaded or reset-replayed.

Local evidence: `.companion-hil-runs/20261013-ios-companion/fresh-ble-proof/`.
The USB bootstrap now backs out of nested Settings pages with bounded Close/State
checks before applying the previously verified touch coordinates. It never
touches the bond-deletion row. The normal signed app is restored after probes;
XCTest and accessibility control limitations remain as observed above.


### Encrypted Ready and normal phone UI (2026-10-13)

The installed signed normal release is app `8ee84dd`, Nordic `e8f17ee`, fllama
`115e799`; artifact `signed-connection-waits/Runner.app` under the ignored
20261013 evidence directory. iPhone 11 / iOS 26.1 reached encrypted Ready with
watch UUID FE88C737-593F-DB9B-732D-E11FF4C463F5, firmware 0.8.1, board
watchdk@1/nrf5340/cpuapp. Ready preceded the automated pairing test, so successful
pairing is not attributed to XCTest. Native observed ATT payload 244 bytes,
battery 89%, live pulse and matching fresh status/version generations.

All 26 recording receipts downloaded through the native Nordic BLE owner,
578145 source bytes total. The owned 37.8-second HIL speech recording was copied
back from the phone; its 155127 bytes and SHA256 match the native receipt. No
watch recording was deleted. This establishes actual downloads, not a measured
firmware throughput result or an interrupted-download recovery pass.

XCTest on the ordinary app passed Health, Notifications, Analytics, Watchface,
Developer and Voice routes, returning to connected Home each time. Health
Today/Week/Month navigation passed. Actual playback conversion and the iOS
decoder loaded a 7-second recording; Play advanced to 0:02 and Pause worked. The
combined playback/shell test subsequently failed its shell assertion, so it is
not reported as a complete pass. A real shell response was observed in an
accessibility value, but the corrected standalone shell acceptance remains open.
Model settings opened; actual model download/inference is still pending.

Evidence is retained privately in
`.companion-hil-runs/20261013-ios-companion/unlocked-acceptance/`: summary, Ready
snapshot, source hash verification and exported route/playback screenshots. The
UI runner uses Xcode automation and temporary accessibility inspection; it does
not enable a product flag or change the VoiceOver preference.

On the later continuation the native journal contained a persisted Stop
(generation 29, desired_running=false), and the normal Home showed Connect.
Automation now accepts this disconnected Home for offline model tests and does
not silently restart the connection. The origin of that intervening Stop is not
established by this capture. Genuine OS restoration, ANCS/AMS, background
telemetry, firmware/resource acceptance, real AI and the other open parity rows
remain outstanding.


### Exact firmware SDK build and offline model controls (2026-10-13)

Installed NCS v3.3.0-preview1 and its matching toolchain through Nordic
sdk-manager, matching app/west.yml. Full WatchDK@1 sysbuild with UART debug
configuration passes. Firmware local commit `f637ba51` corrects LVGL relocation
paths for an SDK workspace outside the nested checkout; this removed an 80668-byte
internal FLASH overflow. The existing narrow 2048 LVGL-9 compatibility changes
and BMP5 FIFO initialization were reviewed, committed on their own
codex/ios-companion submodule branches and pinned. App internal FLASH uses
838052 / 916992 bytes; executable external FLASH uses 481216 / 1048064 bytes.
See `ZSWatch/.agent_tools/MAC_BUILD.md` for the exact build invocation.

The generated matched DFU bundle contains image 0 (838604 bytes), image 2
(481768 bytes) and image 1 (176012 bytes). It has not been installed. Relinking
internal code can change references into external code, so an isolated internal
image from this build is not accepted as a safe replacement for an unknown
installed external image. BLE firmware throughput remains unmeasured. Private
build logs, bundle manifest and SHA256 are under the firmware-sdk-build evidence
directory. USB still reports 26 recordings and 9464 KB free.

The normal model UI selected and downloaded Whisper Tiny (English) while the
watch was explicitly stopped. The 20-second XCTest passed its downloaded/Delete
controls check. Original selection was Whisper Small (English); the temporary
Tiny preference must be restored after inference acceptance. Automatic processing
remains off. No inference result is claimed by the model download.


### Preserve feature screens through Ready changes (2026-10-13)

Normal phone acceptance exposed a Start-page listener navigating Home when the
native owner became Ready again, even with Voice or a transcription confirmation
open above that page. Reconnect could discard UI input without cancelling the
durable native work. Home already renders from the current snapshot; the
redundant navigation listener is removed. The scan flow keeps its explicit
return after selection. Dashboard Settings also has its accessible tooltip.

The regression reproduces loss of the visible Voice screen on the previous
source, then passes after removing the listener. It covers initial Ready and
a disconnect/Ready cycle with the Voice route still open, without Start/Stop
commands or legacy owners. All 24 app-shell tests and three-file targeted analysis
pass. The signed normal release build and deep/strict codesign verification pass.
Physical acceptance of this new release follows installation; old-image route
failure evidence is retained separately from passing route checks.

A reusable standalone XCTest runner lives in scripts/companion_hil/ios_ui. Its
bundle builds and its 20-second background/return test passed against the previous
normal image. During the verified runningBackground interval, native journal
telemetry advanced 1548 to 1554, then 1557 after return, with the same Ready
generation 32 and zero drops. Dart projection acknowledged these receipts while
backgrounded, so this does not prove an independently suspended Dart engine or
genuine OS relaunch. It establishes the short ordinary background exchange and
connected UI return. It is not a locked-screen test.

A read-only copied phone database passed integrity_check: 1395 health samples,
939 battery readings, 18 connection events and one telemetry cursor at that
capture. These are actual storage counts, not proof of every chart or retention
policy. Private snapshots/results are retained in the ignored evidence directory.

The long cached owned fixture returned No speech detected and retained its source;
no transcript/analysis acceptance is claimed. A fresh 6.88-second, 26850-byte watch
microphone recording of a known Mac speech sentence was created through USB
start/stop and automatically downloaded over BLE after normal saved-watch
reconnect. UART records microphone start/stop/new-file notification and PCM
overflow warnings. The new filename is 20261013_234746; only this new fixture is
owned by this test. The original 26 files are retained. Its AI confirmation was
interrupted by the navigation bug; transcription is pending the corrected image.
The selected analysis model download is still in progress; the original model
selection must be restored after inference acceptance.


### Real local transcript, analysis and watch acceptance (2026-10-14)

On signed normal app 02c7ed6, a watch microphone capture of audible owned Mac
speech (20261013_235832, 7.67 seconds, 31181 bytes) downloaded automatically over
BLE. Transcribe-only with Whisper Tiny English saved a 116-character transcript
in about four seconds after confirmation. The subsequent explicit Re-analyze
used that checkpoint with local Qwen2.5 1.5B Q4_K_M; the 39-second UI test passed
Processed / Accepted by watch. Native selected voice-v1 job is delivered, with
no error, one attempt and a saved transcript. UART reports durable result new,
ACK=0. The older transcription revision remains stored and is retired from
selection; no re-transcription was needed for analysis. One reminder suggestion
was produced; no external reminder/calendar action was created by this test.

The first acoustic attempt, 20261013_234746, ran with the Mac output muted, so it
cannot be attributed to audible speech. A second capture temporarily used volume
55 and unmuted output; volume 71 / muted=true was restored immediately afterward
and verified. There are 26 original watch files plus these two owned captures.
The long cached fixture's earlier No speech result remains separately recorded.

Normal Whisper Tiny and Qwen downloads completed. The original Whisper Small
English selection was restored by a passing 13-second UI test; the Qwen selection
was unchanged. Automatic processing remains off. Private result snapshots, source
hashes, screenshots and UART evidence are under unlocked-acceptance; no transcript
or result payload is included in source-controlled logs.

The reusable read-only shell test also passed end to end on 02c7ed6: actual
app-state response, preserved Shell screen through SDK work, then connected Home.
This closes the earlier incomplete shell UI test, not its historical failure.

### Matched firmware transfer preparation

USB image state reports active confirmed indices 0 and 2, with no reported
network-core index 1. The locally built app internal/external images are kept
together; a two-image bundle excludes the unreported network image. Its external
image hash differs from the installed external image, so isolated internal
replacement would be inappropriate. The owned bundle downloaded through Safari
over the actual shared Wi-Fi LAN for the normal file-picker flow. No firmware
update has been started yet.

Transfer metering now recognizes primary image 0 within a matched bundle only
when its size identifies it unambiguously. It excludes the initial reported
offset, which may be resumed data, and counts subsequent acknowledged deltas.
Monotonic timing is captured at the SDK callback before owner-queue persistence.
Cached completion, equal-sized ambiguous images, regression and invalid/zero
timing cannot establish a measurement. Only the existing fresh NUS/active-image
hash verification publishes the completed measurement and opens the same-watch
large-resource gate. Actual transfer acceptance remains pending.

Actual-source Swift tests pass these cases alongside the existing boot/hash,
resource, cancellation and recovery checks. The 26 affected firmware/voice Flutter
tests and two-file analysis pass. The final normal signed Release build passes,
including deep/strict codesign. Shared STT/LLM diagnostic messages now report
character counts instead of complete transcripts or raw AI responses.


### WatchDK manifest default revision (2026-10-14)

The normal document picker selected the owned matched 0/2 package from iCloud
Drive / Downloads. The first FW Update attempt was rejected in Dart preparation
before native firmware admission or byte transfer: the generated NCS manifest
uses board watchdk, while the device reports watchdk@1. The firmware's board.yml
defines revision 1 as the default. Firmware board comparison now resolves only
that bare WatchDK name to revision 1; explicit other revisions and other board
families remain distinct. The regression reproduces rejection before the fix;
21 firmware tests and three-file targeted analysis pass afterward.

No cancellation, firmware write or reboot is claimed by the rejected attempt.
The watch remains Ready and reports 28 recordings (26 originals and two owned
captures). Before update, all 28 raw sources were copied back to local evidence
and SHA256 matched their native committed receipts. The package contains exactly
the internally/external paired binaries built above; network image 1 is omitted
because the current watch does not report that index.

### Physical firmware upload cancellation (2026-10-14)

The normal FW Update / Cancel flow on 25a59a8 admitted the matched 0/2 bundle,
uploaded 70,832 of 838,604 primary-image bytes, then recorded cancellation during
the safe upload phase. Native state returned to Ready at generation 42, with no
reboot, unknown result, or applied-image claim. The UI test failed on its terminal
label check: the old screen instead showed an idle FW Update button, while the
retained cancellation receipt correctly prevented another admission.

Cancelled updates now display Update Cancelled and an explicit Reset action,
which dismisses the UI receipt and allows fresh selection. A widget regression
checks the terminal view, dismissal, and absence of native commands from Reset.
All 22 firmware tests, targeted analysis, and the normal signed release build
pass, including deep/strict codesign. Physical retry and fresh boot/image-hash
verification remain pending.

### History retention and current authentication gate (2026-10-14)

Native telemetry projection now applies the existing 60-day history cleanup
inside its data/cursor transaction. This removes expired health, battery and
connection rows while preserving the replay watermark and saved watch. The new
regression fails on the previous implementation, then passes for expired/recent
rows and lost-ACK replay after the fix. All five telemetry tests, targeted
analysis and the complete 333-test Flutter suite pass. The normal signed Release
build and deep/strict codesign pass.

The cancellation UI release d07b70c was installed normally and reconnected at
generation 45 with the original cancelled firmware receipt intact. Its physical
UI test could not initialize: iOS displayed Enter iPhone Passcode for XCTest /
Enable UI Automation and timed out. The phone lock-state API reported unlocked,
but that does not satisfy this separate authentication. Desktop control also
reported the Mac locked. No retry or firmware admission occurred in this run;
the user has been asked to enter the on-device XCTest passcode. Source work and
USB probes remain available. USB app state succeeded without a reset or flash.

### Actual watch reboot recovery (2026-10-14)

The normal signed retention release 28eeb0b was installed and reached Ready at
generation 47. Before the targeted reboot, USB image reads showed only active,
confirmed indices 0 and 2, with no pending image. One USB SMP reset was
acknowledged; no image was admitted or flashed. The existing iOS app autonomously
reconnected at generation 48. Fresh version/status receipts matched generation
48, and the fresh 28-file catalogue arrived 7.99 seconds after the reset ACK.
Telemetry continued and was projected/acknowledged with zero journal drops.
The delivered local AI job retained its single attempt and delivered state; the
cancelled firmware receipt remained cancelled and was not replayed.

Both active firmware hashes remain identical to the pre-reboot hashes. All 28
individual watch files exist with unchanged lengths. A read-only USB download
then SHA256 matched all 636,176 bytes against their pre-update committed native
receipts: 26 originals and two owned microphone captures. The shell list itself
was truncated by its response buffer, so individual file checks were used rather
than interpreting the missing tail as deleted recordings. No file was changed.

A read-only copied phone database passed integrity_check with 10,275 health
samples, 6,885 battery readings, 49 connection events and watermark 10,359; all
three history tables had zero rows older than 60 days at that capture. Host
regressions separately establish expiry and replay behavior. The 45-second UART
capture contains 4,679 bytes of real boot/2M PHY/244-byte payload/recording-list
evidence. Private snapshots, hashes, database and UART logs are retained in the
ignored continued-retention-and-cancellation / watch-reboot-recovery folders.

This proves actual watch reboot recovery and source preservation. It does not
prove the dashboard's Restart action, OS restoration, suspended Dart collection,
out-of-range recovery, or completed firmware update. The next normal firmware
UI retry still requires on-device XCTest authentication.

### Physical firmware retry and verification (2026-10-14)

After the user unlocked the devices, phone automation initialized normally.
The real retained cancellation displayed Update Cancelled, and its explicit
Reset passed on the installed normal app. The normal iCloud Drive / Downloads
picker then reselected the owned matched 0/2 package. The actual FW Update retry
passed its complete UI test in 98.167 seconds.

Native operation BE2D0E7C-F058-4CF2-9616-85C74AD39F1A completed without error or
unknown outcome. Both target images were verified active after reboot: index 0
56ed66be93a43cc1ddd9eb66362b2ddee6aa57bc83a106444930e37f947b9fe2 and index 2
1d2e2c8a30ef304fad3746625338064768ac3a908e0f849d0d8306ce6efe13ca.
Fresh NUS version and status receipts matched Ready generation 52. UART confirms
permanent swaps of images 0/2 and boot of the built 0.8.1-e9fcd5b5e231 artifact;
that configured version string predates the later source/build-document commit.
The hashes identify the actual binaries. Unreported network index 1 was excluded
from the bundle and remains untested.

Primary-image metering observed 836,204 acknowledged bytes after initial offset
2,400 in 24.364237042 seconds: 33.5166 KiB/s. It excludes the initial progress
offset and does not represent aggregate two-image throughput. SDK configuration
used pipeline depth 3 and reported reassembly buffer size 2,475. The measurement
was published only after the fresh boot/hash checks and enables the same-watch
large-resource gate. Native operation elapsed time was 89.323 seconds, including
transfer, application, reconnect and verification. The 180-second UART capture
contains 6,771 bytes; complete test logs and native receipts are retained locally.

Preparing the representative resource flow uses a verified backup of the
existing /S/full_fs and an owned image generated from checked-in firmware assets.
No resource upload or watchface acceptance is claimed at this checkpoint.

### Physical large-resource upload and UI corrections (2026-10-14)

The normal file picker selected the owned 5,919,608-byte resource image generated
from the checked-in 690 firmware assets. Its header, trailer, names, spans and
every source asset were validated before admission. SHA256 is
5b060daa49707f1f621a4d6ba1817d6f1032fd1def2fb18e38c5abade388d1a0.
The previous 5,932,208-byte /S/full_fs (696 entries) was backed up and validated
locally. It has six additional stock category icons and 19 differing assets;
the original image remains preserved in resource-preflight.

Native operation E0392B5D-E2BA-4951-BE73-337768527E6E completed in 779.724 seconds,
with full byte-for-byte readback before reset and again after fresh boot. Its
complete normal UI test passed in 789.988 seconds. Ready generation 58 had fresh
version/status and a fresh 28-recording catalogue. This is foreground large-file
acceptance, not background continuation or an endurance test.

The resource-only terminal UI incorrectly used the generic firmware Update
Complete title. It now says Filesystem Upload Complete, based on the receipt's
empty image-target list. The regression fails on the old implementation and all
23 firmware tests pass after the fix. Three-file analysis and the normal signed
Release build/deep-strict signature pass.

Aurora background upload, complete staging readback and firmware apply ACK passed
on the normal app. Reset initially received no native admission when the test
tapped the bottom of the screen; tapping higher within the same button passed
with an actual reset ACK. Bottom padding now includes the iPhone gesture inset.
The existing background was backed up and SHA256 matched the bundled Retro
Sunburst image; restoring that original appearance is still in progress.
