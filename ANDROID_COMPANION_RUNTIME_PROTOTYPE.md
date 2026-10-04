# Android service-owned companion prototype

This is an opt-in debug experiment for the native-core option in the
[implementation plan](COMPANION_BACKGROUND_IMPLEMENTATION_PLAN.md). Flutter
remains the UI. A native foreground service owns the connection and receipt
work independently of the Activity and its Flutter observers. It is not the
completed companion migration or a decision to discard the engine-based option.

## Implemented scope

- Known-address BLE connection, MTU negotiation, NUS discovery/subscription,
  serialized writes, fragmented UTF-8 JSON reception, operation deadlines
  and reconnect attempts with 5–60 second delays. Explicit native discovery uses
  Android CompanionDeviceManager through the existing Flutter Add Watch route.
- Service-owned Android media sessions, current metadata/state and supported watch
  controls using the existing MediaSessionBridge; no Activity/Flutter lifetime dependency.
- Native notification-listener routing with an explicit package allowlist, persisted
  bounded outbox, stable IDs, updates/removals, reconnect replay and listener reconciliation.
  The existing notification settings screen can configure explicit selections;
  physical lab tests retain only synthetic ZSWatch notifications in the allowlist.
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

The experimental entry point now uses `ZSWatchApp`, its theme and a restricted
router containing the migrated UI subset. Native selection skips eager Dart
chat, voice recovery/sync, BLE, notification/media, GPS/HTTP, analytics and
crash-persistence startup, as well as the legacy native app bridges. The legacy
BLE foreground service is stopped on entry,
and the legacy boot path is replaced by native, intent-fenced recovery in experimental builds. No local
model is initialized by this entry point. Normal debug builds and profile/release
builds retain the ordinary startup and full router. iOS is unchanged.

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
path now opens the existing Drift schema for saved-watch metadata. It skips the
legacy before-open voice-processing reset, preserving unfinished legacy rows.
Saved names merge by exact ID or a unique case-insensitive Android MAC;
connection and live battery still come only from native state.

The existing dashboard, start page and settings screen now have native branches.
Home observes saved intent: opening/resuming never sends Start, so deliberate
Stop stays stopped. Explicit Connect requests Bluetooth/notification permission
and sends native Start; command acceptance is not readiness. The existing
dashboard appears only after protocol Ready and uses current-generation battery
status. Reconnect/observer failure removes the connected dashboard. Cancel and
Disconnect go to native Stop without creating Dart auto-reconnect/foreground
services. UI/container disposal never sends Stop.

Only home/dashboard, Add Watch, settings, notification settings, recording status,
the coordinated Shell screen and developer runtime controls are routable in this build. Unsupported deep links
cannot enter AI/model, DB-backed recording detail, DFU, health, analytics,
watchface or other legacy-service screens. Health stats and uncoordinated SMP
actions are withheld. The normal router is unchanged. The developer controls
remain available through Connection setup or Developer for known-address lab
setup. Discovery now uses the system picker; coordinated Forget is implemented
in the native Android boundary, while fresh-bond acceptance remains open.

Native selection bypasses the legacy last-watch/auto-reconnect preferences; its
durable running intent remains authoritative. Migrating those product settings,
legacy filters, recordings/DB import, chat/models, DFU/media and the remaining
services is still required before full rollout.

The saved-watch catalogue reuses the existing Flutter tile and rename dialog.
Selecting a valid Android MAC explicitly requests permission and sends Start;
selection is disabled until an active owner is stopped. Renaming updates only
the saved row’s custom-name column and sends no BLE command. Forget now uses a
native stop/disassociate command before deleting the local row. iOS IDs cannot be selected by
this Android prototype. Schema version 6 and its existing upgrade migrations are
unchanged; no native recording receipt is imported into Drift.

The native journal now retains `last_ready` (address, session generation and UTC
milliseconds) when a fenced connection first reaches Ready. Duplicate Ready
callbacks retain the same record; Stop retains it as historical metadata and
still clears running intent. Old journals without this optional field fabricate
no connection history and perform no automatic save until another verified Ready.
Only the selected address’s latest verified session is projected; this is not a
multi-watch native history or proof of bonding.

An app-lifetime Flutter observer projects that record into the saved catalogue,
including after Stop or UI reattachment. It never requests permission, sends
Start/Stop or uses the legacy watch repository/BLE service. New rows keep default
non-primary selection; existing ID spelling, name/custom name, primary flag and
creation time are preserved. Firmware/hardware and cached battery are copied
only from metadata for that recorded generation. Drift’s second precision is
normalized, and equal values cause no SQL update; newer saved connection times
are not regressed. One serial writer coalesces pending snapshots. Failed saves
remain retryable through further observations or Retry saving watch on the start
screen. UI disposal stops projection while the native journal continues. Saving
does not imply a live connection, run a model or import recordings. The Ready
time is phone wall-clock time; creation time for a new row is its first projected
Ready, not an Android pairing timestamp. See the Nokia runbook for bounded
physical auto-save, rename, relaunch and saved-tile selection evidence.

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
list is empty. The explicit local playback boundary is described below;
processing and AI integration remain separate.

The existing `NotificationSettingsScreen` also has a native branch under the
same debug flag. Opening it reads saved native policy and a versioned
`notificationStatus` response; it does not instantiate Dart notification/BLE
services, start the native BLE owner or enable forwarding. Permission grant and
the listener's actual connected callback state are displayed separately. Resume
and explicit Refresh re-read permission and app metadata. Settings edits remain
available while the BLE owner is stopped and do not change its running intent.

The catalogue includes apps with active notifications, saved selections and
ZSWatch itself, capped at 256 entries. Only package names and bounded labels
cross this bridge; no notice content, keys or icons. Saved packages remain
removable even if Android cannot resolve their labels. This is not a complete
installed-app picker. Users explicitly select up to 64 packages; a fresh journal
selects none. Enable/disable preserves selections, and an accepted command's
committed policy bridges any delay before the shared event stream catches up.
The legacy Flutter blocklist is not automatically converted into this allowlist;
that product migration needs an explicit decision before rollout. No additional
package-visibility permission was added. On Nokia only ZSWatch was selected;
personal notification forwarding was not tested.

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
| `forgetWatch` | `address`: Android BLE MAC | Snapshot plus validated `forget_receipt`; association removal and durable generation marker precede local deletion |
| `syncTime` | — | Snapshot after queuing the write; completion arrives separately |
| `requestDeviceInfo` | — | Requests the existing firmware `ver` response over the native NUS queue |
| `requestRecordingList` | — | Snapshot after queuing metadata refresh; actual list receipt follows separately and preserves paused downloads/failures |
| `retryRecordings` | — | Snapshot after retry/list request; asynchronous receipts follow |
| `setRecordingSync` | `enabled`: boolean | Persisted download policy; disabling cancels/releases the existing Nordic transfer |
| `findWatch` | `generation`: integer for the current Ready owner | Explicit short burst acceptance receipt; service owns the stop timer |
| `prepareShell` | `generation`: current Ready integer | No command executes. Returns a prepared generation after Nordic SDK readiness, allowing at most one native recovery generation; bounded to fifteen seconds. |
| `executeShell` | `generation`: prepared Ready integer, `command`: nonblank string up to 512 characters, no NUL | Existing Nordic ShellManager response (`output`, signed `return_code`) for this transient command; bounded to thirty seconds and never replayed after reconnect. |
| `configureGps` | `enabled`: Boolean; enabling requires foreground/background location access and phone location services | Persisted explicit sharing policy; does not Start BLE or request a fix |
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
   after relaunch. Separately test force-stop and reboot/first unlock. Native boot
   recovery is implemented in the later checkpoint below; force-stop remains a
   distinct OS/user boundary and must not be treated as framework reclamation.
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

The later checkpoints below implement Android GATT with the existing Nordic
MCUmgr SDK, notification forwarding, HTTP, time/status, native recovery, Flutter
control/catalogue integration and explicit recording import/playback. Their Nokia
observations remain bounded. Current-Android restrictions, discovery/unpair,
remaining feature migration, OEM battery cost, overnight endurance and production
acceptance remain open. No wake lock is added. A handler timeout alone does not
guarantee network access or timely wakeup in Doze.

Local/remote AI scheduling and production result/ACK/action integration remain
separate work and are deferred under the current user priority.
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


## Explicit native receipt import and Flutter playback — 2026-10-03

The existing Flutter Voice Notes screen now offers **Prepare playback** for a
committed native recording. Opening the screen only observes receipts and the
import ledger. Pressing the control validates the canonical private raw path,
byte size, SHA-256, closed v1 container, timestamp, exact frame count, duration
and full framing. Pending/failed entries cannot be imported. The initial
converter contract supports the existing 16 kHz mono / 160-sample (10 ms)
profile; other profiles fail explicitly. It reuses `ZswOpusParser`,
`OggOpusWriter` and the flushed `VoiceMemoFileStore` staging helper.

Playback derivatives and `imports.sqlite` live under application support's
`companion-recording-imports-v1/`. This separate Drift schema-1 ledger uses the
full native recording identity and immutable source/playback hashes. The main
schema-6 database and legacy filename-based voice rows are unchanged; identical
filenames on different watches cannot collide. No existing transcription,
action or processing state is adopted by filename.

A flushed Ogg stage is published before its ledger row. Retrying after process
death before publication creates a fresh stage and retains the interrupted one.
Retrying after publication adopts only the exact deterministic bytes. Retrying
after DB commit verifies/reuses the existing row without SQL changes. Missing
playback can be rebuilt from its verified source. Conflicting source identities,
metadata, symlinks or corrupt existing derivatives fail without overwriting or
deleting files. This is process-interruption recovery, not a filesystem
power-loss guarantee. Serialization covers this UI's Dart runtime; a future
headless/native importer needs coordinated ownership before enabling concurrency.
Interrupted stages remain private until a separate retention policy is agreed.

The shared Flutter `AudioPlaybackBar` preserves the existing player appearance.
The playback sheet loads the local derivative but waits for an explicit Play;
position/duration/error updates and disposal are fenced against old loads. File
wrapping and ledger commit do not certify codec decoding, audio quality or AI
readiness. A bounded Nokia check exercised actual Android decoding for one
existing recording; production format/length acceptance remains broader work.

Preparation, playback and reopening perform no BLE, Nordic SMP, watch deletion,
model execution, remote submission or job/outbox mutation. Recording-to-job and
legacy processing migrations remain explicit later work. The native companion
is still opt-in under `COMPANION_RUNTIME_PROTOTYPE=true`; iOS and ordinary Dart
BLE startup are unchanged. See the Nokia runbook for artifacts and test limits.

## Android HTTP relay and shared receive recovery — 2026-10-03

Current priority is Android's shared companion functions: BLE ownership,
notifications, time, HTTP and recovery. AI execution/recording-processing work
and iOS are deferred. The existing Flutter UI remains the UI.

The opt-in native transport now handles the existing watch `t=http` GET requests
without Dart listeners or a Flutter engine. Network IO uses two separate threads
and a bounded queue; the BLE handler owns request state and response writes.
At most four requests are pending. Valid string/integer IDs are echoed, including
the firmware's bare `id` key. Duplicate IDs are suppressed for a bounded recent
window within a connection. Reconnect clears that window and fences old IO/ATT
completions. Requests are transient: process death records interruption but does
not persist URLs/bodies or replay requests. The watch must issue a fresh request.

The HTTP watchdog replies after 6.5 seconds; delivery expires at eight seconds,
before the watch's existing ten-second timeout. An expired queued frame cannot
start. Once an ATT frame has started it is completed to avoid leaving a partial
GB command; this is not a hard end-to-end deadline guarantee under a stalled
radio. Journal `written` means ATT completion, not a watch application ACK.

HTTP/HTTPS GET, bounded redirects, explicit per-request insecure TLS and optional
XML XPath are supported. HTTPS is verified by default, and redirects cannot
downgrade it to HTTP. XML DTD/entities are rejected. Raw bodies are capped at
64 KiB; the complete escaped UTF-8 GB response is limited to less than 1900 bytes
against the firmware's 2000-byte buffer. Failures produce bounded `err` replies.
Only the opt-in debug manifest selects the relay's HTTP network policy. Ordinary
debug retains the loopback-only fixture policy; release/profile are unchanged.

The shared compact-JSON framer now drops an incomplete frame at a newline, with
a metadata-only discard count. Previously one lost/truncated frame could keep
all later messages buffered until reconnect or the size limit. This protects
time, status, notification and HTTP traffic equally. It does not repair the
source packet or establish why the Nokia's observed receive stalls occurred.
The final APK exercised a discard followed by continued status and successful
HTTP. Ordinary commands now use negotiated MTU too: one notification fixture
improved from 7.4 seconds to 1.1 seconds while retaining watch-to-phone dismissal.
The final Nokia build passed real HTTP after process crash, Bluetooth recovery
and verified forced deep idle with Flutter absent. Earlier receive stalls remain
documented; these checks do not establish universal recovery or long-term
integrity. See the runbook for exact artifacts and pending acceptance work.


## Native HTTP policy in existing Flutter Settings — 2026-10-03

The opt-in Android path now includes a **Watch internet requests** switch in the
existing Flutter Settings screen. It sends a version-1 native `configureHttp`
command and observes the shared EventChannel. The acknowledged committed policy
stays visible until the stream catches up; loading/failure cannot pretend that a
change succeeded. Metadata includes current pending count and known terminal
outcomes, never URLs, credentials or response bodies. Old journals default to
enabled. Inactive owners and older-generation results are hidden as live work.

Editing policy while stopped only commits `http_enabled`. It requests no
permissions, starts no BLE service, and creates no Dart HTTP executor/listener.
Turning it off cancels active network work and replies with the existing HTTP
error format to new requests. Replies already prepared are allowed to finish as
whole GB frames. The normal app retains its existing provider behavior.

Nokia verified off/on edits at Stop 153 without starting an owner; Off survived a
force-stop/reopen of the already-stopped app. At Ready 154, a real Trivia request
with Off produced `error_written` and no UART timeout. With policy confirmed On,
a fresh request produced `written` and zero pending. The installed watch's error
callback limitation remains: ATT completion/no timeout is not proof of a terminal
consumer error state. One intervening attempted tap hit Voice Notes after the
connected Settings layout expanded; its request still ran with Off. It is not an
enabled-policy pass. No playback/model execution was triggered.

84 native JVM tests, 41 selected Flutter regressions and 42 companion harness
regressions pass; focused Dart analysis is clean and both debug variants compile.
Harness tests need loopback socket access for synthetic server fixtures. The
read-only native probe now emits bounded, generation-fenced HTTP metadata and the
selected watch's current status observation timestamp. Its acceptance remains
`NOT_RUN`: current metadata alone never establishes a scenario pass.


## Native system recovery — 2026-10-03

The opt-in native path now handles `BOOT_COMPLETED` and `MY_PACKAGE_REPLACED`
through the existing receiver. It reads the private native journal on the serial
worker and starts the connected-device service only for strict saved running
intent, valid address/generation and available Bluetooth permission. It requests
no permission and launches no Flutter, Drift or model worker. The receiver is not
direct-boot aware; credential-encrypted storage/first unlock is the boundary.

A dedicated `RESTORE_SYSTEM` command checks address, generation and running intent
again in the service. A queued event after Stop or watch switch cannot reacquire
BLE. Duplicate events cannot create another active GATT owner. Native policies,
receipts and the separate job/outbox journal are preserved. Ordinary builds retain
the existing boot preferences and handler.

The official Android [foreground-service start exemptions](https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start)
include boot/package replacement, subject to service-type restrictions. This path
uses only `connectedDevice`, with the existing Bluetooth/FGS permissions. That is
an implementation basis, not current-Android hardware acceptance. OS restrictions
or startup exceptions are logged; they do not silently change user intent.

87 native JVM tests pass, covering permission/action/state validation, reopen,
Stop/watch-switch fences, duplicate acquisition, suspended recovery and retained
policy/receipts. Both debug variants compile. Nokia replacement install changed
PID 7962 → 9371 and Ready 154 → 155 with Flutter absent and no explicit Start.
Retained lifecycle events confirm `MY_PACKAGE_REPLACED` requested/accepted system
restoration. Fresh time/status and real HTTP followed (2.887 s, zero pending).
The recent logcat window missed these events; the first evidence assertion failed
and was resolved using the app's retained lifecycle journal, without re-running or
manually triggering recovery. The physical reboot/first-unlock check is recorded
in the runbook, including all failed/extended observation windows.


Physical reboot eventually restored Ready 156 (PID 4369) after first unlock,
without UI/Start, and real HTTP then completed in 3.429 s. The first 120-second
USB boot wait and 60-second recovery window failed; later observation succeeded.
The ordered boot broadcast took 1m41.255s to finish. Do not promise immediate
coverage during reboot/unlock. Stop 157 survived replacement with a logged skip,
owner absent and zero native notifications. Native receipts/jobs and all nine
watch originals remained unchanged. Detailed provenance and failure windows are
in the Nokia runbook. The fifteen-minute idle remote-fetch timeout remains open.


## Native discovery through the existing Flutter UI — 2026-10-03

Home's Add watch opens the existing `/scan` route, selecting a native branch.
Opening it sends no permission, scan or connection command. Find watch explicitly
requests connection permission, then invokes Android CompanionDeviceManager with
a ZSWatch name filter. The Flutter BLE scanner/adapter providers are guarded in
native mode. The normal Flutter route retains its existing implementation.

The native picker returns a strictly versioned address/generation selection,
not a Ready result or proof of Bluetooth bonding. Both picker completion and the
service's START_DISCOVERED recheck the exact stopped generation and absence of an
active owner. Stop/change of running intent invalidates delayed selections; there
is no fallback to unrestricted Start. A successful native handoff returns home,
where the existing dashboard appears only after protocol Ready. Only the existing
Ready projection saves watch metadata. An abandoned Flutter view cannot start a
connection from a later picker completion; UI disposal still never sends Stop.

API 31/32 read the selected BLE ScanResult from the Activity result. API 33+
uses onAssociationPending/onAssociationCreated and the association's MAC.
See [Android's companion pairing documentation](https://developer.android.com/develop/connectivity/bluetooth/companion-device-pairing).
Android 12 reports picker cancellation as a generic failure before returning
RESULT_CANCELED: a bounded one-second wait lets the authoritative cancellation
win. Pre-picker failures remain immediate; unknown errors are not classified as
cancellation. Modern explicit cancellation reasons remain quiet. The entire
picker has a 120-second deadline and pending-operation identity fencing.

93 native JVM tests and 52 selected Flutter regressions pass; focused Dart analysis
is clean and both debug APK variants compile. Physical Nokia evidence covers
quiet cancellation with Stop unchanged, a newer Stop invalidating selection,
and a fresh system selection reaching Ready with scan permission denied. Fresh
time/status and real Trivia HTTP succeeded on the final APK. This phone already
had its Bluetooth bond and OS association: fresh bonding, API 33+ physical
callbacks, different/multiple watches and coordinated Forget/unpair are unverified.
OS associations/bonds are preserved; no private bonding API or second GATT owner
was introduced. Exact artifacts and predecessor failures are in the Nokia runbook.


## Service-owned Android media — 2026-10-03

The native service now reuses MediaSessionBridge independently of Flutter. On
protocol Ready it registers a controller and sends current GB `musicinfo` and
`musicstate`; disconnect/Stop releases it. Main-thread controller work and worker
NUS writes share a session-identity fence. Old callbacks, offline controls and
controls delayed more than two seconds are discarded rather than replayed.
Ready/reconnect reads a fresh Android snapshot, including session removal and
same-track album/duration changes. The minute maintenance pass retries failed
queue admission and discovers newly granted media access. The existing Flutter
media provider is guarded in native mode; normal builds retain their path.

Supported watch commands are the existing exact `play`, `pause`, `next`,
`previous`, `volumeup` and `volumedown` strings. No arbitrary intent or seek command
is accepted. Controller access requires the app's notification-listener grant;
revocation blocks controls and callbacks release the controller/clear watch state.
The bridge reads current state rather than forwarding stale callback payloads.
[Android MediaSessionManager](https://developer.android.com/reference/android/media/session/MediaSessionManager)
documents access through an enabled notification listener.

Metadata is bounded below the watch's 100-byte fields using encoded UTF-8 size,
valid code points and escaped compact JSON. Queue admission uses the shared
serialized negotiated-MTU transport, with coalescing and retry of unadmitted
packets. Titles/artists/albums stay in memory and are not included in native
journals, snapshots or retained metadata logs. Only generation/time and a control
acceptance boolean are retained. `last_media_write` is ATT completion, not a
watch application ACK or verified display update. Native read-only probes expose
these receipts only for a live Ready session of the current generation.

A private debug-only CompanionMediaFixtureService creates a real Android
MediaSession with fixed synthetic metadata and no audio playback. It is not
exported, starts only through an explicit lab action, does not survive process
loss automatically and rejects ordinary debug selection. Its foreground notice
is filtered by normal notification routing. The fixture service and its media
FGS permission are absent from the release manifest. No new production media
playback service/permission is required by the device companion bridge.

102 native tests, 53 selected Flutter regressions and 44 companion-harness tests
pass; Dart analysis is clean and both final debug APK variants compile. The first
sandbox-only harness run failed because localhost sockets were unavailable; the
same 44 tests passed with authorized socket access. Nokia proves watch controls
with Flutter absent, Stop fencing, current media after radio recovery, same-track
metadata updates and permission-loss safety. This fixture does not establish
third-party player interoperability, volume behavior, multi-player selection,
modern-Android or unplugged endurance. See the Nokia runbook for exact artifacts.

## Coordinated Forget boundary — 2026-10-04

The existing Flutter Watch Settings dialog now exposes Forget in native Android
mode. The provider sends `forgetWatch` to the native owner first. For the selected
watch, the owner stops the runtime before stopping presence observation and
removing the public OS association. Forgetting another saved watch leaves the
active owner connected. API 31/32 uses the OS's exact address spelling with
`disassociate(String)`; API 33+ removes matching association IDs. The selected
address and historical Ready/status projections are cleared after successful
disassociation. A per-address `forgotten_watches` generation marker persists
across process loss; old presence/system callbacks and picker selections remain
fenced. Repeated Forget is supported if local deletion failed.

Flutter validates a command-specific native receipt, blocks queued metadata
saves, waits for an in-flight save to finish and deletes the exact original Drift
row key, including a lowercase legacy key and its watch-scoped history. Voice
data and native recordings/jobs are retained. Durable generation markers prevent
stale Ready snapshots from recreating the row after UI reattachment; a new
explicit connection reaching Ready at a later generation can save it again.

This removes the Android companion association. Android's public API does not
provide a supported cross-version Bluetooth-bond deletion operation, so the
Bluetooth bond is intentionally preserved and the UI does not claim otherwise.
108 native JVM tests and all 105 companion Flutter regressions pass; focused
Dart analysis is clean and both debug APK variants compile. Tests cover OS-call
ordering, process-loss/retry, preservation of another active owner, pending picker
fencing, exact legacy-key deletion, voice-data preservation, missing confirmation,
in-flight saves and stale snapshots. The currently paired Nokia was not forgotten
during this pass; fresh pairing, API 33+ physical behavior and destructive Forget
remain to be exercised on a disposable association.


## Service-owned GPS and Weather boundary — 2026-10-04

The native owner now receives the existing exact Boolean `gps_power` request.
Sharing defaults off for old/new journals. The existing Flutter Settings provides
an explicit disclosure and permission flow before `configureGps(true)`. Granting
permission or changing policy never starts BLE or location acquisition. Approximate
location is supported; a watch callback never opens permission UI.

Acquisition requires coarse or fine access, background access on API 29+, and
phone location services. The debug manifest adds background location and the
location FGS type. The service adds that type only during acquisition and returns
to its connected-device notification afterward. Android's companion background
start exemption does not itself grant location access: see official
[location FGS requirements](https://developer.android.com/develop/background-work/services/fgs/service-types#location)
and [background location permission](https://developer.android.com/develop/sensors-and-location/location/permissions/background).
Release declarations and the ordinary Flutter startup are unchanged.

Native LocationManager uses enabled network and, when fine access exists, GPS
providers on the same worker as BLE. Fixes older than thirty seconds, future or
invalid coordinates are rejected. The existing `GB(gps)` schema and speed/accuracy
mapping are preserved. The shared queue coalesces updates, limits admission to
once per five seconds and fences pending writes/late callbacks by both session
and acquisition identity. A packet already being fragmented finishes to preserve
watch framing. No first admission within ten seconds releases acquisition; a
later watch request can retry. This is a bounded first-fix attempt, not a promise
of an indoor GPS fix or continuous tracking after an acquisition timeout.

`gps_power=false`, policy off, Stop/disconnect/new session and detected permission
or services loss release registrations and reject unstarted fixes. Provider
changes and service maintenance recheck access; Android may kill the process on
permission revocation. Process recovery reacquires only after a new watch request.
The journal/Flutter boundary contains policy, permissions and content-free state/
generation/timestamps, never coordinates. Coordinates exist only in native memory
and the watch packet; firmware Weather puts them in its Open-Meteo request.

118 native JVM and 111 companion Flutter tests pass, including ten GPS controller
and six Flutter permission/UI tests. Focused analysis is clean and both debug
variants compile. Nokia verified opt-in cancellation, approximate/all-time
permission grant, no owner Start from policy, explicit Connect, first-fix timeout
cleanup, sharing off and Ready with Flutter closed. No native GPS write occurred.
Real Weather/location transmission awaits explicit approval; fresh-position,
watch consumption, remote weather response and current Android hardware remain
unverified. Private evidence and cleanup are in the Nokia report.


## Native Find Watch burst — 2026-10-04

The existing Flutter dashboard now exposes Find watch for the debug native owner.
The ordinary Developer action and Nordic wrapper are retained. `findWatch` accepts
only the current Ready generation and returns a command-specific acceptance
receipt. It cannot Start the owner, choose another watch or send arbitrary JSON.
Flutter sends one action and owns no stop timer; disposal does not send Stop BLE.

Native sends existing `GB({"t":"find","n":true})`, waits two seconds after its
write completes, then sends false. One burst is active through final stop
completion, so overlapping actions fail with retry feedback. An unstarted start
expires after ten seconds and an already fragmented packet still finishes before
cleanup. Stop gets priority over pending work, retaining the current fragmented
packet. One stop may exceed the ordinary queue cap by one. Its callbacks and
retries are fenced by burst/session identity and disposal of the transport.
An unfinished accepted/start-written receipt for the same selected watch causes
best-effort false on its next Ready. Normal Ready does not send false, which the
current firmware would use to stop unrelated vibration too. This receipt is a
single latest-watch diagnostic, not a multi-watch durable haptic protocol or a
crash-atomic watch ACK. `last_find_watch` records address/generation/state/time;
acceptance and write completion do not prove physical motor actuation.

The existing firmware loops until false and has neither disconnect cleanup nor a
maximum-duration safeguard. A phone crash/link loss during the burst cannot be
fixed solely by an Android timer. Before rollout, add a watch-side failsafe and
test the interrupted burst. No firmware edit/flash or physical interrupted burst
was done in this milestone. Native Stop cancels future commands/closes BLE; it
does not claim delivery of a final false over an already closed connection.

127 native JVM and 115 companion Flutter tests pass; focused analysis is clean
and both APKs build. Nine native Find tests cover timing/admission/expiry/session
fencing and stop priority preserving ATT fragments. Four Flutter tests cover the
explicit receipt, Ready-only control, disposal and sanitized failure feedback.
Nokia/watch UART confirms true then false after the dashboard action with Home
resumed, about 2.97 seconds apart including delivery latency. Flutter's Activity
was backgrounded for that burst, not destroyed; disposal is separately covered by
a widget test. See Nokia evidence for hashes, timing and cleanup.


Find timing follow-up: both the two-second stop and ten-second admission watchdog
are scheduled before diagnostic writes, so a failed journal observation cannot
prevent their scheduling. A separate native test injects those failures. Transport
closure still fences timers and the firmware disconnect safeguard remains required.


Before installation, run `scripts/companion_hil/verify_android_owner_apk.py`
with `--apk <frozen-apk> --owner native` (or `flutter` for the ordinary APK) and
`--apkanalyzer <Android-SDK>/cmdline-tools/latest/bin/apkanalyzer`; set JAVA_HOME
for the installed SDK tool. It inspects the packaged BuildConfig field and
MainActivity bridge construction, then prints the artifact hash. A filename,
successful build or installed hash does not alone prove the native gate. This
check is read-only and separately labels hardware/Dart acceptance NOT_RUN.
The final Find artifact with verified native gate is SHA-256
`f987b6fe4540ca4c5f2cee0f29325c2d2c2f080d06d71e8c1ecc2e724e070977`.

## Service-owned Shell through the existing Flutter UI — 2026-10-04

Native mode now enables the existing Shell screen through the developer runtime
controls and the guarded native router. Its provider first prepares SMP through
the native service, then accepts a command on the prepared generation. Preparation
uses Nordic's `McuMgrBleTransport.connect`/readiness API. It does not query the
NUS GATT service list for SMP readiness or implement another cache/protocol.
The same existing native transport factory serves recordings and Nordic
`ShellManager.exec`; the user's Flutter/Nordic fork remains unchanged.

Preparation executes no command, allows one same-watch recovery generation and
has a fifteen-second deadline. Stop/watch replacement/further generations reject
it. Once accepted, one command runs at a time with a thirty-second watchdog;
late callbacks are fenced and commands do not replay after reconnect. Actual
recording transfers exclude Shell. A twenty-second idle lease keeps the SDK/SMP
available for short bursts. Idle cleanup cannot release it during preparation,
execution or recording work. An abandoned preparation releases its resources
and lets queued background work proceed. UI teardown does not own these leases.

Native Shell retains its tabs while disconnected so a Quick Action does not lose
its pending reply during preparation. The connection banner updates independently;
new commands still require current Ready. Terminal/Quick Actions/Remote/Monitor
reuse their existing service API. Screen teardown stops UI polling; Native mode
never invokes the legacy UI-owned ShellManager or SMP toggles. The ordinary
Flutter implementation remains available in ordinary builds.

145 native JVM and 123 companion Flutter tests pass; focused analysis is clean
and both debug variants compile and pass their compiled-owner checks. The Nokia
report records real cold Power Status, CPU Frequency, a same-generation command
burst/Home observation and idle/Stop cleanup. Physical Flutter engine destruction,
SDK failure during idle cleanup, large monitor output and simultaneous transfer/
DFU arbitration remain acceptance items. No AI ran and no recording was deleted.


## Service-owned log files — 2026-10-04

The existing Flutter File System screen is now available in the native debug
router and the existing developer controls. Its Logs tab retains the eight known
`/user/logs/log0000`…`log0007` probes and local log viewer. The existing Files tab
remains empty; this does not add general filesystem browsing, upload, deletion,
watchface or DFU support.

SMP preparation uses the same existing Nordic connection/readiness path as
Shell. A service-owned operation serializes the log probes/download with Shell,
preparation and background recording downloads. Preparation may cross one
bounded service-change recovery before accepting work. The accepted operation
never replays after disconnect, Stop or process loss. UI disposal does not cancel
an accepted service operation; a disposed notifier ignores its later result.

Only the fixed log paths are accepted at both bridge boundaries. Listing has a
60-second deadline. Download first checks actual size, rejects files above 4 MiB,
then uses the existing Nordic FsManager/CheckedFsManager path to check offsets,
chunk bounds and final length. Empty files complete without starting a transfer.
A log changing size while being read fails; no partial bytes reach the viewer.
The screen uses an indeterminate download spinner, with no progress event stream.
Transient log bytes are not journaled; process loss requires explicit retry.
No watch file is written or removed by this path.

Nordic can report missing status through `McuMgrErrorException`, not just an
unsuccessful status response. Only SMP v1 NO_ENTRY or Zephyr's existing fs group
8/FILE_NOT_FOUND=3 is skipped. Other SDK, permission and connection failures
surface as errors, rather than a misleading empty list. The first bounded Nokia
trial retained the incorrect error-callback mapping; SDK-class regression tests
cover the correction. Recording-sync disable now releases only an active
recording transfer, preserving unrelated Shell/log SDK work.

Deterministic tests cover fixed paths, metadata/byte validation, exclusive work,
duplicate callbacks, Stop/reconnect, deadlines, empty/oversized/changed logs,
actual SDK error variants, existing Files UI and UI disposal without legacy BLE.
Physical nonempty log download, mutable log content, UI-engine destruction,
multi-watch local-cache isolation, modern Android and concurrent DFU acceptance
remain. See the Nokia report for bounded hardware observations and APK hashes.
