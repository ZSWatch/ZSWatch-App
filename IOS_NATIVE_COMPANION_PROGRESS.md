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
