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

The experimental entry point skips the ordinary Riverpod/WatchService startup
and native app bridges. The legacy BLE foreground service is stopped on entry,
and the legacy boot recovery path is skipped in experimental builds. No local
model is initialized by this entry point. Normal debug builds and profile/release
builds select the ordinary app. iOS is unchanged.

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
Batch transfer validation is pending. These changes still need broader
coexistence and failure testing.
Android may negotiate a different size than requested; see
[BluetoothGatt.requestMtu](https://developer.android.com/reference/android/bluetooth/BluetoothGatt#requestMtu(int)).
JSON commands retain 20-byte chunks. Clock commands are validated together before
queuing. If a timezone command cannot fit (for example UTC+13:45 at minimum MTU),
`last_time_error`/`time_write_failed` records that failure while recording sync
remains available. A later successful time write clears the error.

These changes fix delivery to the existing firmware parser. The firmware's
`main.c` time-event handler separately ignores a zero timezone offset and truncates
fractional offsets when setting its timezone; those pre-existing application
limitations still need firmware work and physical validation. Transport completion
does not establish that the watch applied a correct local time.

On a ready connection, saved `downloading` entries or missing receipts return to
`pending`; complete staged/published files are adopted before a new transfer.
Interrupted SDK transfers restart from the beginning. Failed transfers stay
`failed` until explicit Retry; a session change rejects old completion callbacks.
**No watch recording is deleted.** There is no receipt import into Drift, Ogg
conversion, AI submission, result delivery or external action in this prototype.

## Bridge v1

Method channel: `dev.zswatch.app/companion_v1`.
Event channel: `dev.zswatch.app/companion_events_v1`.
Every request/subscription includes `{version: 1}`.

| Method | Extra fields | Result |
| --- | --- | --- |
| `snapshot` | — | Current committed state plus live runtime ownership/readiness |
| `start` | `address`: uppercase Android BLE MAC | `{version: 1, accepted: true}` or error |
| `stop` | — | Snapshot after saved intent is cleared and transport closed |
| `syncTime` | — | Snapshot after queuing the write; completion arrives separately |
| `retryRecordings` | — | Snapshot after retry/list request; asynchronous receipts follow |
| `ackEvents` | `cursor`: committed nonnegative integer | Snapshot after cumulative diagnostic ACK |

Events deliver snapshots, not commands. `owner=android_service_native`,
`runtime_active` means a live controller owns the session; use `protocol_ready`
and `phase` to assess the connection. Persisted `phase=ready` with no running
service must have `protocol_ready=false`. Stop increments generation before
closing handles. GATT and SDK callbacks check both session and operation identity.

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

2026-10-02 host checks after review fixes: 28 JVM tests and 72 selected Flutter tests pass, including
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
