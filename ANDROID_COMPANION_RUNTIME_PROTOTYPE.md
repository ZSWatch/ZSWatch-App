# Android service-owned companion prototype

This is an opt-in debug experiment for the native-core option in the
[implementation plan](COMPANION_BACKGROUND_IMPLEMENTATION_PLAN.md). Flutter
remains the UI. A native foreground service owns the connection and receipt
work independently of the Activity and its Flutter observers. It is not the
completed companion migration or a decision to discard the engine-based option.

## Implemented scope

- Known-address BLE connection, MTU negotiation, NUS discovery/subscription,
  serialized writes, fragmented UTF-8 JSON reception, operation deadlines
  and reconnect attempts with 5–60 second delays. No discovery or bonding UI.
- Native notification-listener routing with an explicit package allowlist, persisted
  bounded outbox, stable IDs, updates/removals, reconnect replay and listener reconciliation.
  The development UI currently allows only synthetic ZSWatch notifications.
- Bluetooth-off generation fencing and recovery on Bluetooth-on; native time/timezone
  broadcasts resynchronize a ready link. Recording downloads can be explicitly paused.
- Time/timezone write on readiness and watch time request; explicit UI command.
  `last_time_write_utc_ms` means transport write completion, not watch receipt ACK.
- Watch recording list entries persisted before download; new events trigger a
  fresh list because their stop timestamp differs from the file header's start
  timestamp. Receipt identity/validation use the canonical list metadata. Sequential BLE
  MCUmgr downloads using Nordic's existing 2.7.2 SDK; closed v1 container and
  metadata verification; flushed staging, rename publication and SHA-256 receipt.
- Separate atomic JSON journal, generation fencing, saved running intent,
  bounded diagnostic replay and explicit Stop. Framework destruction releases
  handles while preserving intent; a framework sticky restart can restore it.
- Versioned Flutter observer/control channels, initial snapshot and a standalone
  development view. Reattachment reads native state; UI disposal never stops BLE.
  A second watch requires Stop first. An accepted Start is not connection readiness.

The experimental entry point starts only the native-backed Riverpod subset,
skipping ordinary app/WatchService startup and native app bridges. The legacy
BLE foreground service is stopped on entry,
and the legacy boot recovery path is skipped in experimental builds. No local
model is initialized by this entry point. Normal debug builds and profile/release
builds select the ordinary app. iOS is unchanged.

### Existing Flutter provider boundary

The debug native selection now backs the existing connection/phase, watch-info
and battery providers in `watch_service_provider.dart`, plus the connection
providers in `ble_providers.dart`. `WatchNotifier` routes Connect, Disconnect,
device-info refresh and time sync to native commands. The developer view consumes
these same providers, rather than maintaining another BLE service. All observers
share one versioned EventChannel subscription; container disposal explicitly
cancels that subscription without sending Stop. Loading/error snapshots cannot
retain a connected or live-battery view. Cached watch metadata remains separate
from current-generation battery status.

Direct creation of the legacy `BleConnectionService` fails when native selection
is active. UI SMP actions are withheld until coordinated with the native owner;
this does not replace Nordic transfer support. Native crash-summary routing is
not yet implemented. Normal builds retain the previous provider paths. The native
path does not open or migrate Drift, so saved custom names/ordinary DB-backed
watch lists are not yet merged here.

This is the shared state/command boundary, not activation of the full ordinary
navigation tree. App startup services, auto-reconnect preferences, notification
settings, recordings/DB import, chat/models, DFU/media and screens that directly
read `WatchService` still need migration before that tree can run with native
ownership. The guard exposes those remaining dependencies instead of allowing
a second connection. See the Nokia runbook for bounded provider UI evidence.

The existing `VoiceMemosScreen` now has a native receipt view when the debug
selection is active. Its ordinary auto-sync, repository, model-configuration
and transcription path are bypassed. `CompanionRecording` retains the native
watch/filename/timestamp/size/duration identity rather than inventing a Drift ID;
pending, downloading, downloaded and failed states stay distinct. A downloaded
journal entry needs a local path and SHA-256, but decoding this DTO does not
read or validate audio. Retained hashes on pending/failed entries never imply a
committed receipt. The view filters the selected watch and retains saved status
after Stop; refresh is disabled while disconnected.

`requestRecordingList` queues the existing watch list command without resetting
failed transfers or changing download policy. A fresh, including unchanged/empty,
response persists `recording_list` with watch address, generation, count and
observation time. The UI displays the reported watch count only for its current
ready generation. Old receipt records are retained even if a subsequent watch
list is empty. This is receipt/status viewing, not DB import, playback, Ogg
conversion or AI integration. The phone still needs a separate receipt import
and processing boundary for those features.

`connectedDevice` foreground services are an Android-supported way to maintain
a device connection, subject to permissions and foreground-start rules.
Process death still closes BLE; `START_STICKY` is not a promise of immediate or
universal recovery. See Android's [BLE background guidance](https://developer.android.com/develop/connectivity/bluetooth/ble/background)
and [connected-device service requirements](https://developer.android.com/develop/background-work/services/fgs/service-types#connected-device).

## Storage and replay contract

Files live under the app's private `files/companion-prototype/` directory:

- `state-v1.json`: desired running state, address, generation, phase, last error,
  time-write timestamp, event/ACK cursors, diagnostic events and recording receipts.
- `recordings/<SHA-256 of recording key>.zsw_opus`: published raw receipt;
  deterministic `.partial` staging and retained `.invalid-*` previous files.

Every state/event update flushes a temporary file and renames it before UI
notification. Receipts remain authoritative after diagnostic events are ACKed
or overwritten by the 256-event ring; `event_gap` signals missing diagnostics.
ACK accepts only a committed cursor and does not acknowledge watch delivery.
The store permits 100 receipt identities; overflow raises an error and retains
the watch copy. Unsupported/corrupt journal data fails closed, without resetting
or importing unknown files. This proves process-interruption recovery boundaries,
not complete filesystem durability through power loss.

A recording key combines Android address, filename, timestamp, size and duration.
This is a prototype deduplication key, not a firmware-issued immutable identity.
Validation checks version/magic, exact byte size, timestamp, frame boundaries,
closed frame count and duration; it does not decode or verify Opus audio content.
Identical metadata with replaced content is still ambiguous. A valid existing
receipt is preserved rather than overwritten.

Clock commands are separate, complete ATT writes: `setTime(seconds)` and
`;E.setTimeZone(offset)`. The leading semicolon matters to the firmware parser;
these commands cannot use the JSON fragmentation path. Discovery precedes any
local MTU request. If the watch has already negotiated sufficient capacity, the
connection reuses that value; otherwise it requests MTU 517 after discovery.
Capacity always comes from the successful callback's MTU minus three; rejection,
failure or a five-second callback timeout uses the last observed capacity
(initially 20). Later callbacks update capacity without restarting discovery.
Repeated CONNECTED/discovery callbacks are ignored. The old MTU 64 request
could shrink the watch's independently negotiated 247 and lose recording events
on the Nokia test rig. GATT Service Changed fences the session and reconnects
with fresh handles; this also interrupts an active SMP transfer. The SDK requests
high connection priority for file transfer and retains its connection/SMP lease
across pending files rather than toggling the service between files.
The first physical batch trial timed out/rejected receipts; successful reuse
across multiple completed files remains unverified. These changes still need broader
coexistence and failure testing.
Android may negotiate a different size than requested; see
[BluetoothGatt.requestMtu](https://developer.android.com/reference/android/bluetooth/BluetoothGatt#requestMtu(int)).
JSON commands retain 20-byte chunks. Clock commands are validated together before
queuing. If a timezone command cannot fit (for example UTC+13:45 at minimum MTU),
`last_time_error`/`time_write_failed` records that failure while recording sync
remains available. A later successful time write clears the error.

These changes fix delivery to the existing firmware parser. The installed firmware
separately ignores a zero timezone offset and truncates fractional offsets. A
source fix is now committed in the firmware repository (`e030c5ab`), with explicit
timezone validity, minute-precision POSIX offsets and a real `time_t` conversion.
Its host clock regression and native_sim/WatchDK builds pass; it has not been
flashed. Physical RTC/timezone acceptance still remains. Transport completion
does not establish that the watch applied a correct local time.

On a ready connection, saved `downloading` entries or missing receipts return to
`pending`; complete staged/published files are adopted before a new transfer.
Interrupted SDK transfers restart from the beginning. Failed transfers stay
`failed` until explicit Retry; a session change rejects old completion callbacks.
**No watch recording is deleted.** There is no receipt import into Drift, Ogg
conversion, production AI submission, watch result delivery or external action.
A separate synthetic remote-job adapter now persists metadata-only fixture results
and an outbox; see [its recovery boundary](REMOTE_JOB_ANDROID_PROTOTYPE.md).

## Bridge v1

Method channel: `dev.zswatch.app/companion_v1`.
Event channel: `dev.zswatch.app/companion_events_v1`.
Every request/subscription includes `{version: 1}`.

| Method | Extra fields | Result |
| --- | --- | --- |
| `snapshot` | — | Current state/live readiness plus content-free synthetic job summaries |
| `startRemoteFixture` | — | Creates/resumes the fixed metadata-only loopback job; requires running prototype |
| `startLocalFixture` | — | Explicit headless Dart fixture for later capable-phone testing; no model/audio processing |
| `start` | `address`: uppercase Android BLE MAC | `{version: 1, accepted: true}` or error |
| `stop` | — | Snapshot after saved intent is cleared and transport closed |
| `syncTime` | — | Snapshot after queuing the write; completion arrives separately |
| `requestDeviceInfo` | — | Requests the existing firmware `ver` response over the native NUS queue |
| `requestRecordingList` | — | Snapshot after queuing metadata refresh; actual list receipt follows separately and preserves paused downloads/failures |
| `retryRecordings` | — | Snapshot after retry/list request; asynchronous receipts follow |
| `setRecordingSync` | `enabled`: boolean | Persisted download policy; disabling cancels/releases the existing Nordic transfer |
| `configureNotifications` | `enabled`, `packages`: explicit Android package list | Persisted policy; enabling requires actual notification access |
| `requestNotificationAccess` | — | Opens Android notification-listener settings; accepted does not mean permission granted |
| `postTestNotification` | Optional `delaySeconds` 0–60, `closeUi` | Synthetic fixture; closing UI requires a positive delay; no process-death scheduler |
| `ackEvents` | `cursor`: committed nonnegative integer | Snapshot after cumulative diagnostic ACK |

Events deliver snapshots, not commands. `owner=android_service_native`,
`runtime_active` means a live controller owns the session; use `protocol_ready`
and `phase` to assess the connection. Persisted `phase=ready` with no running
service must have `protocol_ready=false`. Stop increments generation before
closing handles. GATT and SDK callbacks check both session and operation identity.

### Native watch state and notification actions

The service now consumes existing `ver`/`status` messages and persists firmware,
hardware, battery/voltage and charging data for the selected watch. An optional
initial standard Battery Service read runs before queued NUS writes, so the UI
does not need to wait for a periodic status event. Missing/failed battery reads
remain optional. Messages from obsolete connection generations are rejected.
The Flutter snapshot exposes the app's existing `Watch`, `Connection` and
`ConnectionPhase` domain models without creating a Flutter BLE owner. Status from
an older connection remains explicitly cached, and metadata belonging to another
watch is not reused. Normal application providers are not migrated yet.

Watch `notify` dismissal now resolves the persisted native ID to its private
Android notification key. Only allowed, unexpired entries actually written on the
active connection can be dismissed; `DISMISS_ALL` is restricted to that same set.
The listener excludes ongoing/foreground-service notices. Android's removal
callback, rather than the cancellation request, drives removal/reconciliation.
Open/reply/mute actions remain unsupported. No Flutter callback is required.

Physical Nokia/API 31, 2026-10-03: firmware/hardware and initial battery acquisition,
watch touch → BLE dismissal → Android cancellation → native removal, and refreshed
watch data after an injected crash all worked with Flutter absent. A forced-deep-
idle test received a watch-injected battery status while Android reported `IDLE`
both before and after; PID stayed 4243. USB remained attached and charging was
simulated as disconnected for this bounded test. Android battery/idle simulation
and watch battery-event state were restored. This is not unplugged Doze/soak,
low-memory reclaim, iOS or production acceptance. See the updated Nokia report.

A service-owned Dart worker is prepared for later testing on a suitable phone:
see [COMPANION_DART_WORKER_PROTOTYPE.md](COMPANION_DART_WORKER_PROTOTYPE.md).
The Nokia run did not start that worker or any model. Native BLE ownership and
remote-job recovery do not depend on it.

## Build and host verification

From `zswatch_app/`:

```bash
flutter test --no-pub test/companion_prototype_client_test.dart \
  test/voice_memo_recovery_service_test.dart test/voice_memo_sync_service_test.dart \
  test/voice_memo_file_store_test.dart test/zsw_opus_parser_test.dart
dart analyze lib/main.dart lib/services/background/companion_prototype_client.dart \
  lib/ui/screens/developer/companion_prototype_app.dart test/companion_prototype_client_test.dart
cd android
./gradlew :app:testDebugUnitTest
cd ..
flutter build apk --debug --no-pub --dart-define=COMPANION_RUNTIME_PROTOTYPE=true
```

Copy that APK before building the normal app with `flutter build apk --debug --no-pub`.
Both APKs share `com.zswatch.app`; they replace each other and cannot be used
simultaneously. Native Gradle and Dart select the experiment from the same
define, and native profile/release flags are explicitly false.
Both debug APK manifests were inspected: minimum Android SDK 24, target SDK 35.

2026-10-02 host checks after review fixes: 34 JVM tests and 72 selected Flutter tests pass, including
9 new bridge/UI tests and the existing 63 receipt/parser tests. JVM tests exercise
the actual journal and file implementations with fake connection callbacks,
reopened stores and three forcibly killed JVM workers at complete staging,
publication and journal-commit boundaries, not Android services. Existing Flutter recovery tests include
three SIGKILL workers against Drift; those kills do not exercise this native service.
Dart analysis is clean; experimental and ordinary debug APKs compile.
The six additional JVM regressions cover stop/start timestamp disagreement,
duplicate hints/list replay, firmware clock-packet prefixes and boundaries,
minimum/negotiated payloads and ordinary JSON fragmentation. They model the
firmware wire contract; they do not execute the Android Bluetooth stack.

Local build evidence and APKs are retained in
`.companion-hil-runs/20261002-prototype-review-fixes/`. `verification.json`
records hashes and source provenance. These were host-only checks. The subsequent
[Nokia physical smoke test](ANDROID_COMPANION_NOKIA_SMOKE.md) has partial results
and exposed unresolved recovery/transfer failures; mobile acceptance is not met.

The debug build also contains an explicit instrumentation probe for an attached
phone. After building the experimental APK and pairing the watch, it can be run
with:

```bash
adb -s "$ZSW_PHONE_SERIAL" shell am instrument -w \
  -e address "$ZSW_WATCH_MAC" -e seconds 120 \
  -e trace_packets true \
  com.zswatch.app/dev.zswatch.app.companion.CompanionTransferProbe
```

This retries listed recordings and reports protocol state and receipt outcome.
It requires the experimental Gradle/Dart define. Android instrumentation can
change scheduling and kill/restart the target process, so this command is only
for BLE-transfer diagnosis. It is not a locked-phone lifecycle or autonomous
recovery acceptance test. The probe never deletes watch files or exports audio.
Chunk offsets and bounds are checked before the SDK assembles its receipt; the
pinned SDK's 2.5-second file timeout is extended to 10 seconds in this experiment.
See the physical report for the still-failing hash comparisons.

## Physical-phone runbook

Use the existing [watch/USB/lab instructions](scripts/companion_hil/README.md)
for port identities, optional authorized reset, UART collection and read-only
SMP status. Start each scenario with a new evidence directory and record the
phone model/OS, app artifact/hash, watch revision/firmware and bond state.
Use an existing dedicated Android test installation and bond first. A known
stable MAC is required; switching bonded/random addresses is not implemented.

1. Stop the ordinary app's connection and preserve its baseline evidence.
   Install the experimental APK on the explicitly selected phone, launch it,
   enter the known watch MAC and press Connect/recover. Grant Bluetooth Connect
   and notification permission. Record acceptance, service start, CCCD completion,
   `protocol_ready=true`, and observed watch time/timezone.
   Capture MTU negotiation and complete clock packets; test a nonzero whole-hour
   offset, zero offset and a fractional offset separately. Record firmware
   application failures separately from transport completion. Exercise a rejected
   MTU request and a missing/late MTU callback with an instrumented GATT test double.
2. Make a short real watch recording. Confirm `pending → downloading → downloaded`,
   raw file size/hash and that the source recording remains on the watch. Test
   more than one recording. Synthetic USB fixtures verify framing only; use a
   real audio recording to assess contents, with later decoding separately.
   Require the new-event hint to cause a list request, and one receipt using the
   list/header timestamp even when the event reports a later stop timestamp.
3. Press Home, lock the screen, then remove the app task. Make another recording
   while Flutter has no observer. Reopen and require the same service ownership,
   persisted receipt and increasing cursors; check the watch and both log streams.
   A notification alone is insufficient evidence of processing without the UI.
4. Test watch out-of-range and recovery, Bluetooth off/on and permission revocation.
   Capture the first error. The current radio-disabled connect path needs an
   explicit Connect/recover; automatic radio/presence wakeup is deferred.
5. Interrupt a transfer by ending the app process on the test phone. Record the
   exact kill mechanism and PID. A foreground service may resist `am kill`; do
   not report process death if the PID did not change. A diagnostic `run-as`
   self-kill can be used on the debug test installation when intentionally selected.
   Observe whether Android schedules a null-intent restart; if it does, require a
   new generation, no stale completion and file/list reconciliation without UI.
   If it does not, record that result and separately test explicit relaunch/recovery.
6. Verify Stop from both UI and service notification. Require saved
   `desired_running=false`, closed handles, no reconnect and no restored owner
   after relaunch. Separately test force-stop and reboot; this prototype does not
   restart itself after either and must require a user launch/start. Do not treat
   force-stop as equivalent to ordinary framework process reclamation.
7. Run the planned idle/Doze and manufacturer battery tests using the lab scenario
   setup/teardown. Capture BLE receipt/time evidence separately from network jobs.
   Establish latency, reconnect and resource budgets against the normal-app baseline.

Useful commands after explicit phone selection (these collect evidence only):

```bash
adb -s "$ZSW_PHONE_SERIAL" shell dumpsys activity services com.zswatch.app
adb -s "$ZSW_PHONE_SERIAL" shell pidof com.zswatch.app
adb -s "$ZSW_PHONE_SERIAL" shell run-as com.zswatch.app cat files/companion-prototype/state-v1.json
adb -s "$ZSW_PHONE_SERIAL" shell run-as com.zswatch.app cat shared_prefs/zswatch_lifecycle_events.xml
```

`CompanionPrototype` logs include attach/detach, service start (including null
intent), PID/task removal, failures and destruction. They are also retained by
the existing lifecycle logger. The journal captures generation/phase/receipt
changes independently. Collection through `hil.py capture` is read-only and
still does not produce scenario acceptance automatically. Exclude real audio
and personal notification data from committed evidence.

## Remaining before architecture selection or rollout

Real Android GATT and simultaneous NUS/MCUmgr handles, SMP service changes,
bond/encryption, CCCD/write behavior, screen-off progress, background execution,
restart timing, OEM restrictions and battery cost are unverified. There is no
new wake lock, CDM association/presence trigger, boot start, radio receiver or
system time-change receiver. A handler timeout does not guarantee wakeup in Doze.

Notification forwarding, HTTP, playback/conversion, ordinary UI/Drift integration,
local/remote AI scheduling and result/ACK/action contracts remain separate work.
The prototype must not delete audio or run replayed external actions while those
contracts are absent. Test the alternative service-owned Flutter-engine spike
and the iOS lifecycle path before selecting the production architecture. This
prototype supplies a compiled, testable native baseline for that comparison.

## Native notification and recovery milestone (2026-10-03)

The service persists at most 64 notification identities, with a 10-minute text
retention deadline and 60-second maintenance while the process runs. Offline
maintenance removes private text and retains removal IDs. Process suspension/death
can delay maintenance until execution resumes; this is not a secure deletion SLA.
Stop clears pending private notification state before closing BLE. The UI snapshot
contains counts/configuration and IDs in diagnostics, not Android keys or text.
Stop does not guarantee removal of notifications already shown on the watch.

Notifications use the existing firmware `notify` and `notify-` messages. The firmware
ignores duplicate IDs and has no `notify~`; changed content therefore queues remove
then add with the same ID. Unchanged replay preserves IDs. The watch holds only 10
notifications and truncates text fields; a 64-entry phone journal is not a promise
of retaining all 64 on the watch. ATT write completion is not a watch application ACK
or proof that a popup was displayed. A reinstalled app can lose its identity counter;
reset/migration identity handling remains a production requirement.

Physical Nokia/API 31 checks with paused recording downloads observed:

- Synthetic notification write in foreground, then another after Flutter Activity
  and task disposal with the launcher foreground.
- Bluetooth-off kept running intent and fenced generation 92 to 94; Bluetooth-on
  reached ready at generation 95, resynced time and replayed both stable IDs.
- An injected Java process crash from that ready link changed PID 27854 to 28647.
  Notification-listener recreation, sticky service start and CDM callbacks occurred;
  generation 96 reached ready and replayed both notifications without a UI launch.
  This does not isolate which OS mechanism enabled recovery, or prove low-memory
  termination/force-stop recovery.
- A third delayed synthetic notification completed its write with the display
  Dozing and the Flutter Activity absent. USB was attached: unplugged deep Doze,
  long idle and manufacturer restrictions remain unverified.

The first physical build exposed Android `JSONObject.put` serializing a Kotlin
list as a string, unlike the JVM JSON implementation. Store updates now explicitly
wrap collections/maps; the corrected APK persisted a real package array. Final host
checks: 49 native JVM tests, 15 Flutter bridge/UI tests, focused analysis, prototype
and ordinary debug APK builds and release-manifest merging pass. Release has no
prototype presence service, companion presence permissions or probe instrumentation.

Evidence: `.companion-hil-runs/20261003-native-notifications/`. Tested corrected
APK SHA-256: `90bac4f27d71d2c4c133260f28eb6e2220c09e7121d14ea804eb6ecf93e98a2f`.
The later listener ID-bookkeeping cleanup has host verification; it was not installed
in this physical run. No firmware was flashed, no recording deleted, and no audio
was uploaded or passed to a model. SMP still uses Nordic 2.7.2; notifications do not
require BLE SMP. iOS and newer Android device acceptance remain open.

Explicit Stop was sent through the existing non-exported service action as the
debuggable app UID after the phone locked (`am startservice --user 0 ... STOP`).
It persisted generation 101/stopped, cleared all notification content and released
the native service. Bluetooth off/on afterward did not restart it. Association
was retained; Bluetooth was restored. The read-only runtime probe verified the
installed APK hash and the final stopped state without unlocking the phone.

### Existing MCUmgr fork audit

The ordinary Flutter path resolves both Dart and native Android/iOS code from
`Flutter-nRF-Connect-Device-Manager`, at revision
`2aabd598990fb9fb3cba918d15f98084e9ee687c` plus the user's working changes.
The Dart FS-manager working diff is formatting; path/remote-ID callback routing,
one-transfer-per-device and disposal logic already exist in that fork. Android's
`FsManagerPlugin` uses Nordic downloads and adds upload connection priority,
logging control, detected upload MTU and `FileUploader` window 3/alignment 4.
Those upload policies must remain when uploads migrate; the current prototype
does not upload. Native downloads use Nordic 2.7.2 directly, with SDK high
connection priority, cancellation before release and generation/operation fences.
They do not invoke the fork's Dart/Pigeon/Flutter callback layer. The iOS plugin
uses Nordic's separate `iOSMcuManagerLibrary`; shared Dart API does not imply an
Android transport can run on iOS. No fork changes were reverted or committed here.

## Clock and stale-notification follow-up

Native maintenance now compares the effective phone timezone offset once per
minute while executing and ready. DST can change that offset without changing
the zone ID; a changed offset queues time synchronization and saves the offset
only on clock-write completion. Busy queues defer the maintenance write. This
is not an OS wakeup guarantee or a periodic clock-drift correction.

Listener replay now uses Android's original notification post time for retention.
A stale active notification cannot get a new 10-minute lifetime or reappear after
its expired removal was written and the process restarted. A newly posted update
can start a new window. Host regressions cover persisted DST offset comparison
and this stale-replay boundary. The native suite now has 59 passing tests; both
normal and prototype APK builds pass. These two follow-ups are not installed on
the Nokia yet; its last physically tested APK and stopped state are documented
in the remote-job milestone.
