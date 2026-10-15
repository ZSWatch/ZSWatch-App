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

### Physical watchface, sensors and dashboard restart (2026-10-14)

The original Retro Sunburst background is restored on normal signed db39ff9.
Native apply operation 381DB7E4-D2AF-49BE-B3F9-DE6FD9394171 completed at generation
65, with all 115,212 bytes verified and firmware apply acknowledged. The normal
resource-only completion label also passed on this build. All 334 Flutter tests
passed. Generic XCTest taps missed some Flutter image/button activation points;
observed within-control coordinate taps admitted the real apply/reset operations.
The missed taps are retained as harness failures, not successful product checks.

The accelerometer delivered real approximately 2 Hz samples through the native
sensor channel. The explicit off toggle returned the UI to zero streaming and the
normal UI test passed in 14.130 seconds. The sensor card expands with sample data,
so its off-toggle test targets the heading's switch rather than the whole card's
center. Other sensor types and physical unsubscribe on view close remain open.

Normal Developer Sync Time passed and the native receipt recorded UTC plus +2
hours for Stockholm. Dashboard Restart Watch and its explicit confirmation caused
a real UART boot and fresh Ready generation 68, with status/version generation 68
and the same watch UUID. A prepared read-only USB client observed fresh boot
enumeration and 28 recordings; no debugger reset was needed. The UI test failed
its transient success-toast assertion, so the whole XCTest is not marked passed.

A new owned two-second microphone recording after that boot had a timestamp
approximately 7,200.9 seconds ahead of the probe's directory creation time. After
explicit app time sync, a second owned recording differed from its measured host
start by -0.390 seconds. Both new sources were downloaded, and originals remain
untouched. This isolates a firmware RTC startup timezone bug; the successful RTC
branch skipped the retained timezone that the software fallback restores. A
focused firmware correction and CTS local-calendar/UTC handling are in progress.

### RTC correction and explicit Stop persistence (2026-10-14)

Firmware e63e86b6 restores the retained timezone before choosing hardware/software
clock and converts CTS local calendar fields using a fresh Local Time Information
read. It publishes UTC and the effective standard/DST offset together; unknown
or unavailable offsets preserve the existing clock. CTS discovery retries now
retain the actual connection and cancel on disconnect. Signed quarter-hour/DST
and unknown/reserved-offset host regressions pass, as does WatchDK@1 full sysbuild
on NCS v3.3.0-preview1. The CTS contract follows the Bluetooth specification linked
in firmware app/tests/clock_timezone/README.md. Subsequent 67bd6ad4 only corrects a
misleading security-error log when discovery is not ready; that source also builds.

Normal file-picker update of matched indices 0/2 passed in 132.204 UI seconds.
Native operation 6FB572A3-1126-486D-8EB3-04D663AB0DD3 completed in 123.567 seconds
with both installed hashes verified and fresh Ready/status/version generation 74.
Installed hashes are 0b09a7a7d4ecee4542d7a322e7bfda9568ea307d075010f1e077f80dc59e41e8
(index 0) and 20a4c70e7f4e66b18bdbb835dd032f0e18fa670b9150d28bc1a4fa34c36eaf11
(index 2). Radio index 1 remains excluded/unverified. This installed functional
candidate predates the logging-only 67bd6ad4; the distinction is retained locally.

All 30 sources then present (28 pre-update plus two owned clock probes) were read
back over USB and SHA256 matched their native receipts: 651,375 bytes. After the
corrected firmware boot, a new two-second microphone probe's header timestamp
was +0.303 seconds from measured host start. A subsequent normal dashboard reboot
and another probe measured -0.329 seconds. Neither followed another app time sync;
last_time_write_utc_ms remained 1791964626495. Sources remain intact. The second
reboot's UI check passed and fresh status/version generation 77 was observed.
Manual phone timezone/DST changes and missing Local Time Information remain
separate acceptance cases.

Explicit Disconnect/Stop, XCTest process termination/relaunch, and explicit
Connect passed. On relaunch, Connect remained available and Disconnect absent;
only the later user-equivalent Connect action returned to connected Home. This
is explicit Stop persistence across an injected test process relaunch, not an
OS restoration or user force-quit claim.

### Native diagnostics, Weather and recording controls (2026-10-14)

Normal File System listing exposed a real null-path bridge bug. Dart now omits an
absent path and Swift also accepts an explicit NSNull optional value. Nine native
file tests, analysis and the full 336-test Flutter suite passed. Signed Release
build and deep/strict verification pass. iOS location error guidance now names
iPhone permissions; seven existing GPS-setting tests and analysis pass.

Real logs reached the phone, but the log switch stayed pending because the iOS
bridge never emitted requested/written/pending completion state. a1d54cb publishes
that state after the CoreBluetooth write finishes, fences old callbacks and
reapplies the retained policy on Ready. Its signed Release build and 24 app-shell
tests pass. Normal enable/receive/disable passed in 20.616 seconds, and persisted
log_streaming is restored false. This write receipt is not a separate watch ACK;
actual firmware log packets demonstrate the enabled path.

Normal crash-summary and filesystem routes passed in 20.802 seconds. An existing
stored crash summary was displayed and preserved. Eight known log paths returned
no files in this UART-debug build. No crash erase or remote analysis was performed.
Find Watch delivered the real firmware command and the UART recorded its bounded
10-second stop. These product checks use the existing UI and command paths.

Normal location opt-in passed. Launching Weather on the watch delivered fresh
phone GPS, completed the native HTTP response and caused the firmware's successful
response branch to release GPS. last_http outcome was written at generation 84,
with no pending HTTP requests afterward; the Weather UART contains no error.
Communication UI showed 12 entries with actual TX/RX counts, and its corrected
normal UI check passed. The watch returned to its original watchface and location
sharing was restored off. A literal watch-screen photograph and background
location permission remain unverified. Firmware 5df4b8ed removes routine raw
coordinates from Weather debug logs; the updated WatchDK sysbuild passes.

Search restricted the normal Voice screen to exactly one owned microphone source.
Archive/unarchive, recoverable Delete from phone, Recently deleted and Restore
passed in 26.177 seconds. Its original active/unarchived state is restored; the
watch original and unrelated user recordings were retained.

### Observed OS BLE relaunch after injected process death (2026-10-14)

The normal signed a1d54cb app was left in the background through the Home action.
Developer DVT then sent SIGKILL to only companion PID 1647. A new owned two-second
watch microphone recording provided a real notification. No app activation or
launch command followed before verification. Read-only DVT found new PID 1676;
CoreBluetooth restoration callback UTC-ms 1791977252395 and restored-peripheral
attachment were persisted. Fresh Ready/status/version generation 88 followed.
The new 7,223-byte source was downloaded in the background and its receipt SHA256
125356c272a9ddc7f1ec140052e8d2db6c4dd8030550f5a3f2cac93b33fa1927
matched independent USB readback before any explicit UI reopen. All 32 preceding
source identities remained present. Local evidence is in
observed-background-restoration.

This is debugger-injected process death followed by an actually observed OS BLE
relaunch and callback. It is not a genuine jetsam/memory-pressure termination,
user app-switcher force-quit or first-unlock-after-phone-reboot test. Apple describes
those as distinct conditions in [QA1962](https://developer.apple.com/library/archive/qa/qa1962/_index.html).
Automatic AI was off; the verified result is securing the recording, not immediate
background inference.

### Physical Demo preview and intent restoration (2026-10-14)

Normal Settings enabled Demo on signed a1d54cb. The native journal independently
showed generation 90, phase stopped and desired_running false while the UI showed
synthetic Demo firmware and placeholder battery/heart-rate data. Health,
Notifications, Analytics, Watchface, Developer and Voice routes all passed.
Exiting preview restored the same saved UUID with fresh Ready generation 91 and
desired_running true. The corrected continuation UI test passed in about 29
seconds. The initial entry test looked for a watch name hidden in the collapsed
information card; the visible Demo firmware label is the actual entry assertion.
No original recordings were imported into or mutated by the preview.

### Owned transcript revision and restoration (2026-10-14)

Normal Copy and Edit controls were exercised only for owned microphone source
20261013_235832. Native storage confirms the exact requested 132-character edited
revision. After a test caret-selection failure, normal UI editing restored all
116 original characters exactly in selected job 7daf54e0fee0cabc86eeb35d68efa36b82fd42ae76b9421605f2a297344e5de9.
The earlier delivered result remains in saved revision history. Audio and unrelated
recordings are unchanged. UI displayed-text assertions failed, so whole-test passes
are not claimed. Export/share and clipboard roundtrip remain separate checks.

Latest firmware 5df4b8ed builds; its logging-only corrections are not installed.
The final owned ZIP remains absent from visible Files after the Safari download
prompt. Failed exact-file guards admitted no update. Physically verified RTC
firmware e63e86b6 remains installed. Short background firmware acceptance is open.

### Default iOS action destination and owned reminder (2026-10-14)

04c7016 fixes a real iOS review blocker: the shared dialog required an Android
calendar ID, although iOS uses EventKit's writable default Calendar/Reminders
list. iOS event and reminder confirmation now proceeds without that ID; Android
still rejects a missing writable calendar. Nine action-review tests, all 339
Flutter tests, targeted analysis and a signed Release build pass. The normal
04c7016 app is installed, with deep/strict signature verification.

Only owned microphone source 20261013_235832 was edited to an explicit dated HIL
reminder instruction and re-analyzed locally. Normal Review requested Reminders
access, created an explicitly named owned entry and persisted its platform ID in
job 7ddbc397a46082213df7854cb9438cfd300a431b4759d348a7bb1da327ad59cb.
The initial test's exact accessibility-label assertion failed after creation;
the screenshot and native created receipt confirm the actual outcome. Corrected
normal Undo/Remove passed, and the persisted action is now undone. No unrelated
Calendar/Reminders entries were changed. Private evidence is in
productivity-actions. Calendar, alerts and restoration of this test transcript
are being completed separately.

A separate owned calendar instruction produced a calendar_event. The first
permission-driver attempt failed while enumerating an OS alert's changing
accessibility children and created no entry. Continuing the observed Calendar
full-access prompt, Create and Undo/Remove passed in 13 seconds. Native job
2f9f62d095635f716308d4c6feaf4e536c0f18bb90d451b3107b2f4d3f1310c2 retains its
calendar_event platform ID and final undone receipt. Original user events were
not modified.

Normal review/scheduling of an owned 20-second timer passed, including the
notification banner while the app was in the background. Job
831d4b89ae2fd9b9e28b6bde1b773ef698c670eb7488280ff2e43750bc766002 retains its
dispatched receipt, stable timer notification ID and fire UTC-ms 1791986777869.
The short UI test passed in 36 seconds (43 seconds including runner overhead).
This verifies an app notification, not a system Clock timer. The INFO-level UART
does not establish watch ANCS delivery; its attribute prints are DEBUG-level.

### ANCS enrollment, dated alerts and remaining UI authentication (2026-10-14)

The phone's connected-watch Bluetooth page shows Share System Notifications
already on, although the app reported unauthorized. Native connections used nil
options and the authorization callback was incorrectly on CBPeripheralDelegate.
7d38255 requests ANCS on normal and restored connections and implements the
CBCentralManager callback documented by [Apple](https://developer.apple.com/documentation/corebluetooth/cbperipheral/ancsauthorized).
Restoration before poweredOn defers its connection request; Stop clears that
pending request. d9c962b removes Android Clock's next-occurrence restriction from
iOS dated app alerts and rejects an expired iOS alert before dispatch.
Ten action-review tests, all 340 Flutter tests, targeted analysis and a signed
Release build pass; deep/strict signature verification passes.

The normal signed 7d38255 app is installed. A supported command-line launch
observed a fresh CoreBluetooth restoration callback UTC-ms 1791994446126 and
fresh Ready/status/version generation 94. All preceding recording identities
remain. This confirms the updated restored-connection path reaches Ready; it
does not establish the ANCS UI status or notification delivery yet.

A fresh iOS Enter iPhone Passcode for XCTest / Enable UI Automation screen is
observed. The attempted transcript restoration/export test never initialized,
so it changed no transcript and is not a pass. The human must enter this device
passcode to resume UI automation. Source/build/native work continues meanwhile.
The owned test transcript still contains the timer fixture; its exact original
text and saved revision history are preserved for restoration through normal UI.

Independent USB readback after the productivity checks verified all 33 watch
sources, 673009 bytes, against their phone receipt hashes. All 28 original
pre-firmware sources additionally match the preserved baseline. Private audio
and receipts are in final-source-integrity.

3b4df83 implements the previously missing iOS Open calendar path for created
calendar events. The native action looks up the saved job/action receipt,
checks its app-owned EventKit marker and presents Apple's event viewer. It
requires a foreground UI and reports an unavailable/deleted event without
recreating it. Reminders retain Create and Undo; their unsupported Open calendar
button is hidden on iOS. Eleven action-review tests, all 341 Flutter tests,
targeted analysis, native journal/framing and native voice-job tests pass.
The signed Release build and deep/strict signature verification pass.

The normal signed 3b4df83 app is installed with fresh Ready/status/version
generation 96 and all 33 sources retained. Calendar viewer, ANCS status/delivery,
owned transcript restoration/export, media, photo/model import and short
background firmware acceptance still need their normal UI checks. Native
accessibility inspection can read the app, but attempted inspector activation
was not verified to change its route and is not UI acceptance. XCTest's fresh
passcode authentication remains required; no passcode was entered or bypassed.
The owned generated two-track media fixture is prepared under the existing local
artifact server for the AMS check; no user media is used. The goal is not complete.

### Resolved device authentication, ANCS, calendar viewer and AMS (2026-10-14)

The human completed the fresh XCTest device authentication. Normal UI automation
runs again; the preceding authentication notes describe earlier failed attempts.
The installed app remains signed 3b4df83, with all 33 watch sources retained.

An explicit normal Stop, process relaunch (still Stopped), and Connect passed.
The ANCS page then reported authorized. An owned twenty-second app alert used
review title `ZSWatch HIL ANCS 20261014_1918`; the title was deliberately changed
after analysis and is absent from the already-delivered voice result packet.
It was absent from a private 512-KiB watch RAM capture before firing and present
in three copies afterward. The exact owned phone banner also passed. This
establishes physical ANCS delivery, without claiming a photograph of its watch
presentation. Both read-only SWD captures reported the CPU not halted before and
after; no reset or halt was requested. Raw RAM remains private and ignored.

Normal Create → Open calendar presented Apple's event viewer for owned job
89d44eaad505bff149ee2463780797d8e3bc90b0a32eac8513786cdf343f9d06. The screenshot
shows the October 16, 16:00–16:30 event and matching app-owned marker. Done and
Undo/Remove succeeded; the final receipt is undone. The whole XCTest failed only
its assumed HIL title: existing local AI normalized that title to “schedule a
meeting.” This is preserved as a failed assertion, not relabeled a whole-test
pass; classification changes are excluded from this task.

Text export opened the native share sheet. A copied 116-byte cache export exactly
matched the preserved original transcript (SHA256
5d070df34a177296e07feda064885e815c663356d18b56d30d3bcef3fce9662e). The sheet was
dismissed without sending externally. Subsequent fixtures were restored again
through Edit/Save after the AMS check; the combined final-state/restore test
passed in 23.6 seconds. Source audio and original recordings were not modified.

AMS used two generated quiet WAV tones in an owned local Safari page. Exact
track-title/artist tokens were absent from baseline watch RAM and present in four
copies after playback. Normal watch Music UI touches at the source-derived button
centers generated phone remote-pause, remote-play, remote-next (track two), and
final remote-pause callbacks. Safari's final track-two paused state was verified
by XCTest, and the watch returned to its original watchface. The initial start
test failed its text assertion because this temporary page lacked UTF-8 metadata;
the actual start receipt and screenshot show playback. The fixture encoding was
corrected; no production media code was changed. Private evidence uses
/tmp/zswatch-AMS-restore-20261014.xcresult and owned HTTP callback receipts.

Source inventory also corrects the notification-actions row: current firmware
has local notification removal but no ANCS positive/negative action dispatch.
Physical safe dismissal of only the owned alert remains a separate check.
The goal remains incomplete: remaining physical checks stay explicit in parity.


Normal Copy transcript → paste into the editor matched all 116 original characters;
Cancel left the saved original unchanged. Export audio opened the native share
sheet. The combined test passed in 24.4 seconds; no external share was sent.
A private copied 30,588-byte export is a complete Opus/Ogg container with
7.6675-second final granule duration. Evidence and exact owned AMS callbacks are
summarized in the ignored ams-acceptance/manifest.json. A reusable standard-library
fixture generator now preserves the owned media check without user audio.


### Normal gallery crop and sensor view cleanup (2026-10-14)

Safari saved only the generated four-color image to Photos. The system private
picker displayed that unique new image; no unrelated photo was selected.
Normal Crop Background → Done → upload/apply passed. Native operation
18C4D6DC-F57E-4D47-827E-C0BDBA266E33 completed 115212 bytes at generation 99.
Independent USB readback of applied /user/bg.bin had SHA256
788324fd05e39f08d1ec1f0048451ca22be81907c8c5e614de769396e2e09e88; decoded RGB565
samples verify the four colors, white center cross and black circular mask.

Retro Sunburst was restored through the normal image control. The first generic
restore tap admitted no native operation and its wait was interrupted; the
observed image-center check passed in 21.5 seconds. Full restored readback is
115212 bytes, SHA256
979df7661e05c5a9caa4ac04c46c8147f1a909571c0b7b04370bcb594f547842, exactly the
preserved original. Private receipts are in photo-crop-acceptance. Initial picker
harness failures involved merged Flutter labels and PHPicker isHittable; they
are not counted as whole passes and required no product change.

Normal accelerometer enable received real samples. Leaving its view without
explicitly disabling it, then reopening after two seconds, showed zero sensors
streaming and its switch off. The whole view-close check passed. All eight
advertised sensor controls were available and off afterward; that inventory does
not establish samples from the other seven sensors. Evidence:
/tmp/zswatch-sensor-view-close-20261014.xcresult.


Normal iPhone Settings Bluetooth off/on passed in 18.4 seconds. The off snapshot
is disconnected at generation 103, reports “Bluetooth is off,” retains desired
Start and has zero telemetry drops. Switching back on recovers without pressing
Connect: Ready/status/version all reach fresh generation 105, all 33 sources
remain, and the error clears. The physical Settings toggle is restored on.
/tmp/zswatch-radio-recovery-20261014.xcresult and ignored radio-recovery-acceptance
contain the short check. This is radio availability, not permission denial.


Normal owned playback seek passed: an observed playback-bar tap moved its
position from 0:00 to 0:05 / 0:07, then Close returned to connected Home. The
first harness queried a native Slider role that Flutter did not expose; it
loaded the correct audio but failed that selector. The corrected observed UI
check passed in /tmp/zswatch-playback-observed-seek-20261014.xcresult. This changes
no source audio or transcript.


The empty-name/default helper in Watch Settings was inconsistent with Save:
blank input disabled it and the save handler rejected blanks. The shared dialog
now maps empty/advertised names to no custom name, enabling Save only when this
changes the saved metadata. Two widget regressions pass (custom reset with the
same UUID, and no-op default reset); targeted analysis is clean. Native BLE and
selection ownership are unchanged. Signed installation/physical rename follows.

The Instruments 100%-loss attempt still returned a successful Weather relay and
is not network-failure acceptance. The induced profile was explicitly cleared.
An initial Airplane Mode harness failed its Wi-Fi selector and restored mode off;
Wi-Fi remained on. iOS exposes that switch with a non-breaking hyphen; the
selector is corrected. Later attempts never started because Xcode's CoreDevice
notification subscription was stale, although the phone was visibly unlocked
and DDI enabled. Restarting the Mac user CoreDevice service restored a normal
XCTest run: location sharing was successfully returned off. No new human
permission or passcode was requested. Network failure remains pending until an
actual error response is observed.


The normal signed 5259194 release is installed. All 343 Flutter tests, targeted
analysis, signed build and strict signature verification pass. Before install,
all 33 sources and the exact restored owned transcript were retained, GPS/logs
off. After installation, the first UI harness encountered empty Flutter
semantics; a temporary read-only accessibility inspection enabled test visibility
without changing VoiceOver or adding a product flag.

Normal saved-watch rename persisted across process relaunch while the native
owner remained Stopped. Clearing the custom name enabled Save and restored
ZSWatch. The Forget confirmation displayed the iOS Settings bond explanation;
Cancel preserved metadata/history/bond. Connect restored the same UUID and fresh
Ready. The whole test passed in 28.2 seconds:
/tmp/zswatch-watch-name-reset-inspected-20261014.xcresult. Installed artifact and
private final-state summary are in signed-watch-name-reset. Additional-watch
selection and actual Forget remain separate unverified cases.


### Physical offline HTTP error and recovery (2026-10-14)

The corrected normal Settings check held Airplane Mode on / Wi-Fi off for thirty
seconds with Bluetooth on and the watch Ready. Reopening normal watch Weather
used its preceding cached location and generated a real HTTP request. Native
relay outcome was error_written at generation 108, UTC-ms 1792002440927, with no
pending requests. This is actual phone offline-error delivery, not the earlier
ineffective Instruments loss profile or a synthetic native callback.

The whole UI check passed in 55.1 seconds, restored Airplane Mode off / Wi-Fi on,
and returned to connected Home. Reopening Weather after network restoration
produced written at the same Ready generation, UTC-ms 1792002523339, again zero
pending. All 33 sources remain and GPS sharing is off. Private snapshots and the
summary are in network-recovery-acceptance; the watch is returned to its original
watchface. No HTTP URL or coordinates are printed into the evidence summary.


### Short background firmware failure under investigation (2026-10-14)

The final logging-only 5df4b8ed package became available in normal Files after a
real Safari page-link download (the earlier external-URL confirmation did not
save it). Exact owned file selection passed. Normal update operation
59A3D486-CDA5-4DFA-BDD6-FDC9B4E5A7DE entered upload, Home/background for ten seconds,
and returned to foreground. Both native background snapshots retained current
2400 / total 839156; the acknowledgement-progress assertion failed. The SDK then
reported upgrade failure; the operation is failed/result_unknown. The whole UI
completion check failed and is not background-continuation acceptance.

Independent USB ImageStatesRead confirms the preceding e63e86b6 application and
reported index-two hashes remain active and confirmed. The CDC never disappeared,
so the bootstrap observer timed out without opening/restarting/resetting anything.
No reboot or activation is claimed. The failed receipt is preserved before retry.

The native delegate previously discarded the SDK Error. It now stores bounded
failure state/domain/code and a known transport-case identifier; localized error
userInfo and payloads are excluded. This diagnostic change leaves update ownership,
replay fencing and user-facing status intact. The normal root-workspace signed
release build passes in 123.5 seconds with strict signature verification, rather
than requiring the staging checkout for this build. Foreground retry will separate
a package/transport problem from the background transition.


Foreground retry of the final 5df4b8ed package passed on f961adc in 174.7 seconds
including the runner. Native C23CD961-7A99-45B2-A683-8C4D79644EB4 completed, verified
both target hashes, and reached Ready/status/version generation 116 with all 33
sources. Targets are index 0: 01ac603c2d20852c32d408a259a6258347392414103688d4269d89c8a6fcb111,
index 2: e237882217b54593b4afdd4dd87d7c885b404f6004b9ba62a2734d6681a073f8.
The old throughput record remains historical; no fresh benchmark is claimed from
this retry of a partially uploaded image.

A separate ten-second background attempt used the previously verified e63e86b6
clock-fix package, rather than the old timezone-buggy firmware. It again failed
at 2400 bytes and the diagnostic identifies iOSMcuManagerLibrary.McuMgrTransportError,
code 5, reason sendFailed, state upload. SDK source shows this is retry exhaustion.
No reset was observed. The final 5df image remains the installed active baseline.

Source review finds the SDK's already-connected branch discovers services without
registering its own central's connection; a globally connected peripheral is not
proof of local ownership. Apple's installed iOS 26.1 CBCentralManager.h documents
that system-connected peripherals require a local connect before use. The pinned
SDK now explicitly connects before discovery when it lacks a local connection;
pending system connections also register locally. Disconnect/failure clears the
local flag. Terminal lifetime fences remain, and the complete pinned SDK plus
real abort proof compile/pass after the change. Background acceptance follows;
this ownership correction is not yet claimed to resolve the physical failure.


### Background retry and independent integrity check (2026-10-15)

The local-connection correction in Nordic 361a0b2 did not resolve background
upload. On app f01c8c0, operation 7D8E21C0-CBA4-427B-8976-1F28FDEC8296 retained
46,392 / 839,288 acknowledged bytes in both background snapshots and terminated
with sendFailed (transport error 5, upload). The UI runner subsequently timed out:
its failure selector omitted the actual “Update Result Unverified” heading. This
is failed continuation acceptance, not a successful background update.

Fresh USB reads confirm both final 5df4b8ed target images are still active and
confirmed with no pending swap. All 33 sources (673,009 bytes), including the 28
pre-firmware sources, match their saved SHA256 receipts. The restored Retro
Sunburst image again matches SHA256
979df7661e05c5a9caa4ac04c46c8147f1a909571c0b7b04370bcb594f547842.
Private evidence is in .companion-hil-runs/20261015-ios-companion.

The next diagnostic build counts only recognized SDK transport control events:
write chunks, complete responses, flow-control pauses/resumes and retry classes.
SDK strings and payloads are never retained or printed. Updating the SDK log
delegate also updates its existing write buffer, so prepared transports report
flow control after ownership moves to the update coordinator. A bounded eight-
receipt execution history records operation identity, background-task admission,
remaining grant and foreground/background transitions. Failure diagnostics now
include operation identity and counter snapshot. These diagnostics do not change
transfer policy or establish a background fix. The complete pinned SDK abort
proof passes; the revised phone test recognizes the actual unverified result.
The phone screenshot/debug service currently reports password protection; an
unlock was requested while source and USB work continue.

Validation for this checkpoint: Nordic 4af72e1 complete-SDK abort proof passes;
Swift firmware boot/hash/resource/recovery tests and voice checkpoint/edit/ACK
fence tests pass. The normal signed release build passes in 24.1 seconds (88.5 MB)
and deep/strict codesign verification passes. The diagnostic app installed over
the existing app successfully; physical background acceptance remains pending.
No Dart product code changed, so the previous 343-test Flutter result is retained.


### Measured short firmware pause/resume (2026-10-15)

Diagnostic operation D2D62DB1-984A-4540-A41F-CA326CA3C960 confirms iOS granted a
background task before the upload stalled. Flow-control retries exhausted:
65 pauses, 55 resumes, seven flow retries, 296 written chunks and 32 responses.
No complete-image progression was observed in either background snapshot. This
is evidence of the failing transport path, not evidence that iOS denied time.

The coordinator now pauses Nordic uploads when UIKit becomes inactive, before
DidEnterBackground, and resumes through the SDK when active again. The narrow
SDK pause API accepts only the actual upload stage; discovery, confirm/reset and
terminal managers are excluded. Native session/terminal fences are retained.
An upload entered while inactive also requests this pause. The existing bounded
20-second background expiration remains; prolonged absence requires explicit
retry, without replaying an admitted reset. Resource transfers retain their
previous bounded behavior and have not gained background acceptance here.

Physical operation 3AE93B36-C389-418D-9C15-67445BCB69B6 passed a ten-second Home
interval with the known e63e86b6 clock-fix package. Background snapshots stayed at
73,276 / 839,288 acknowledged bytes. Foreground resume advanced past 806,476,
finished both uploads, rebooted, verified both active target hashes, and reached
Ready/status/version generation 133, 33 sources, result_unknown false. The whole
UI test passed in 112.561 seconds including runner; the USB observer saw reset,
opened CDC on return and held DTR through startup. This closes the short firmware
pause/resume case, not unattended background transfer or prolonged suspension.

The full SDK abort proof also verifies that lifecycle pause cannot park parameter
discovery or revive a terminal manager. All 23 firmware Dart tests and targeted
two-file analysis pass. iOS UI now describes brief upload pause/resume and asks
users to keep the app open; background-expiration errors explain explicit retry.
Final 5df4b8ed firmware will be restored before subsequent acceptance.
Private evidence: .companion-hil-runs/20261015-ios-companion/upload-pause-resume.


### Final firmware restored; remaining sensor paths (2026-10-15)

Signed normal app 34eecf0 / Nordic 88ad5f2 installed with the iOS pause guidance.
The ordinary final-package foreground update passed in 90.650 seconds including
runner. Native boot/hash proof passed; independent USB reads confirm final
5df4b8ed hashes 01ac603c…cb111 (index 0) and e2378822…a073f8 (index 2), both active
and confirmed. CDC returned, DTR was held through startup, and watchface state
and 33-source status were observed. Fresh full source reads again verify all 33
files (673,009 bytes), including all 28 pre-firmware originals, against saved SHA256.

The normal Sensor Debug UI then passed each remaining path individually: Sensor
Fusion, Gyroscope, Magnetometer, Temperature, Humidity, Pressure and Ambient
Light. Quaternion arrival enabled Reset Orientation for fusion; other paths
produced nonzero sample counts. Closing/reopening each view returned to zero
streaming. The whole seven-path test passed in 171.721 seconds; accelerometer
was already verified separately. Firmware source intentionally returns zero
for temperature/humidity in the existing GATT implementation: these are proven
transport/sample paths, not newly claimed physical climate measurements. No
orientation reset, calibration, persistent stream or new firmware sensor feature
was introduced. Evidence is in final-restoration-and-sensors under today's run.


### Actual voice deferral/recovery and Settings (2026-10-15)

On the normal signed app, reanalysis of the existing owned 20261013_235832
transcript created job 0ac18b07…c41841. Before Home it held fence 1, attempt 1 and
an execution lease. During the ten-second background interval the native policy
released the lease, advanced to fence 2 and saved background_deferred. After UI
return it claimed fence 3/attempt 2, completed local analysis, and reached delivered
with the watch's native ACK. The original 116-byte transcript SHA256
5d070df34a177296e07feda064885e815c663356d18b56d30d3bcef3fce9662e matched every
snapshot. This proves actual claimed-work deferral, resumed local processing and
watch delivery from the saved transcript; exact token-level interruption was not
instrumented. No immediate locked-phone inference or system-scheduled grant is
claimed. The transition UI test passed in 30.624 seconds, and the independent
journal observer confirmed the final ACK afterward.

A normal Settings walkthrough passed in 27.301 seconds: iOS permission summary,
version dialog, open-source licenses, coredump URL dialog with Cancel, then Home.
No Android notification-access/battery-exemption controls appeared. The first
walkthrough missed the version row while the list was still scrolling; the
settled-row test passed without product changes. Settings values were preserved.
The copied phone database passed quick_check with 37,365 health samples, 25,043
battery readings, 212 connection events and one committed telemetry cursor at
sequence 37,710. Dedicated chart refresh is still a separate physical check.
Private evidence is in voice-recovery-and-settings under today's run.


### Automatic transcription-only policy (2026-10-15)

The normal AI Settings UI selected the already installed Tiny English model,
disabled Analyze after transcription and enabled automatic processing. A newly
owned 155,127-byte container copied from the older hil_rel_long fixture produced
no_speech; its complete verified source remained downloaded and no analysis ran.
This is a retained failure receipt, not successful speech acceptance.

A new uniquely named copy of the previously verified 20261013_235832 microphone
fixture then passed. Native discovery captured whisperTinyEn / analysis false,
downloaded all 31,181 bytes with SHA256
1658fe04ce2633b6f33e2a2e99f14e1bfe39528c720ded96e90d73ff3c3d872d,
automatically created a transcribe-v1 job and reached transcribed on attempt one.
The 116-byte transcript matched the previously saved original hash. Summary,
category and actions were empty, proving optional analysis was skipped. The
original microphone file was not edited. This copied fixture is not claimed as
a fresh microphone capture. The UI restored automatic processing off, analysis
on and Small English selection afterward; the restore test passed in 27.589 s.
Owned extra fixture cleanup is still pending. Private evidence: today's
run/automatic-transcription directory.


### Normal model import/delete and selection repair (2026-10-15)

The large owned Qwen-copy download remained a partial .download. The first
picker-only test falsely treated an existing picker Back button as success;
container verification rejected that claim. It is not import acceptance.
A small complete GGUF from ggml-org's upstream test assets was then downloaded
through a normal Safari page link and imported through Files. The 1,185,376-byte
phone readback matches upstream SHA256
270cba1bd5109f42d03350f60406024560464db173c0e387d91f0426d3bd256d.
Source: https://huggingface.co/ggml-org/models-moved/blob/main/tinyllamas/stories260K.gguf.
This is import/delete path evidence, not a replacement recommendation or a
classification/inference-quality claim for the test model.

Physical testing exposed a real selection bug: deleting the selected import left
custom::filename in preferences while the picker displayed the first catalog
model. c52d84b resets a deleted selected import to default Qwen, persists that
selection, preserves later explicit choices and preserves catalog selection when
only its downloaded file is deleted. An unknown model ID now fails rather than
deleting an unrelated catalog file. Filesystem regression covers these cases.
All 344 Flutter tests, targeted three-file analysis, signed release build (62.8 s)
and strict/deep signature verification pass. The corrected normal import/delete
round trip passed physically; saved preferences are qwen25_1_5b_q4_k_m and
whisperSmallEn afterward. The owned imported copy is gone; original model files
were not removed. Evidence: today's run/model-import-delete directory.


### 2026-10-15 — recording retry controls and SMP discovery diagnosis

Commit 6d78cd2 adds normal iOS Pause/Resume downloads and Retry failed downloads,
with native command admission and offline pause-intent widget checks. All 346
Flutter tests passed after these controls; the signed release built and installed.
The normal Retry button was exercised, but this is not download acceptance.
The owned 620,412-byte interrupted-download fixture is still blocked before file
bytes by SMP preparation, including a foreground-only retry.

Payload-free bounded preparation milestones identify discovery reaching the
SMP service and then waiting for its characteristics. The simultaneous watch
UART capture reports ATT response-buffer exhaustion (opcode 0x09) and a
30-second stall. NCS 3.3's att.c returns TX buffers through system work, while
this firmware explicitly selects that same queue for Bluetooth RX. The dedicated
Bluetooth RX queue is being evaluated as a targeted firmware fix. No transfer
completion or background resume is claimed from the successful UI-only retries.


### 2026-10-15 — dedicated Bluetooth RX firmware experiment

Firmware 7d076791 separated Bluetooth RX from the system workqueue, but its
4,096-byte RX stack failed on hardware in CTS publish_time_event. The shared
ble_data_event union is about 4 KiB before callback stack overhead. UART identifies
BT RX WQ and the stack-overflow fault; this candidate is explicitly not accepted.
The paired iOS system connection also reproduced the fault after app Stop, so
Bluetooth was temporarily disabled through iPhone Settings during repair.
No pairing, filesystem, recording or resource erasure was performed.

A read-only J-Link stack capture (CPU running before and after) measured 4,592
bytes already used on the system-work stack. The follow-up therefore retains
6,144 bytes for system work and 9,500 for Bluetooth RX. Firmware 26c59c8a builds
with 449,880 of 450,560 bytes of statically reserved RAM; this includes configured
heap reservations. USB installation and runtime stack validation are in progress.
No successful download/resume claim is made yet.

After the failed candidate, full USB readback independently verified all 33
baseline recordings, including the 28 pre-firmware sources: 673,009 bytes, every
SHA256 unchanged. Evidence is retained under the ignored dedicated-bluetooth-rx
HIL directory. The three owned test-source additions remain separate.


### 2026-10-15 — ordinary offline batch actions

Signed app 224d6ae passed normal multi-select archive, unarchive, Delete from
phone and individual Recently deleted Restore for exactly the two owned
hil_auto_ fixtures, with Bluetooth off and companion Stop. The whole UI test
passed in 57.529 seconds. Copied native receipts independently show both restored
as downloaded/unarchived with their original hashes. Their transcribed/no-speech
job results remain byte-for-byte unchanged, and every other recording receipt
is unchanged. The initial harness attempt expected the connected Home label
Voice; the disconnected Home entry is Voice notes. No product change was needed.
Permanent purge is the next check; no purge acceptance is claimed here.


### 2026-10-15 — permanent phone purge verified

Normal Recently deleted → Delete permanently passed for the same two owned
automatic-processing fixtures (UI 30.921 seconds). Independent phone-container
readback confirms durable purged tombstones, cleanup complete, corresponding
local audio/receipt files absent and both owned jobs removed. Every other native
recording receipt is unchanged. Full phone audio readback verifies all 33 other
downloaded recordings against their committed SHA256 values. Watch source files
were untouched by local purge. The separate large resume fixture remains for the
pending interrupted-download test.
