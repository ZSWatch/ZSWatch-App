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
