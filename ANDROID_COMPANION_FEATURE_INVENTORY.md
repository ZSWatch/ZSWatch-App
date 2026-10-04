# Android companion feature inventory — 2026-10-04

Inventory baseline: `2f6f422`; GPS migration added later on `codex/companion-background-foundation`.
Flutter remains the UI; the native owner remains an opt-in debug boundary.
This targeted inventory checks handlers and consumers. A protocol enum or a
dormant provider does not establish end-to-end support.

## Coverage and gaps

| Function | Current implementation and evidence | Next requirement |
| --- | --- | --- |
| BLE/status/time | Native session and shared queue feed existing Flutter providers; Nokia tests cover Ready, Stop, time, radio/process/boot/update/presence recovery. | Current Android hardware, recovery latency and longer unplugged acceptance. |
| Notifications | Native listener/policy/queue forwards selected notifications and handles DISMISS/DISMISS_ALL independently of Flutter; existing settings configure the owner. | Legacy OPEN/MUTE/REPLY branches are placeholders, not working actions to port. Decide their required product behavior before adding them. ATT completion remains distinct from watch acceptance. |
| HTTP | Native relay/policy/deadlines and shared BLE queue; active Trivia and disabled-policy Nokia checks pass. | The completed loopback comparison passed after fifteen minutes of forced deep idle with Flutter absent. Remote network/deadline acceptance remains open: offline errors, a late watch callback with native delivery expiry, and an idle timeout were retained. Watch error-callback handling also remains. |
| Media | Native service reuses MediaSessionBridge; real synthetic session verifies watch controls and metadata with Flutter absent. | Third-party players, volume and multiple-player selection. |
| Discovery/saved watches/Forget | System picker and fenced native handoff; existing tiles/dashboard/rename. Native-first Forget removes the OS association before exact Drift-key/history deletion and fences late metadata saves. | Fresh bonding, physical destructive Forget/re-pair, newer-Android association behavior. Bluetooth-bond preservation is explicit. |
| GPS → Weather | Native service now handles existing `gps_power`/`gps` with explicit Flutter opt-in, Android background access and location FGS acquisition. Nokia approximate/all-time permission flow, timeout cleanup and BLE/UI independence pass. | Real fresh fix → watch Weather → HTTP remains unverified. No location write occurred in the bounded Nokia observation; explicit location-transmission approval is pending. Current Android hardware and longer unplugged operation remain. |
| Find watch from phone | Native dashboard action, service-owned stop timer and priority queue. Firmware now bounds each activation to ten seconds and stops Find on BLE disconnect without cancelling unrelated patterns. Nokia/watch logs verify normal bursts, an app suspended before false, disconnect mid-burst and a fresh burst after reconnect. | Physical motor effects and modern-phone/endurance acceptance remain. Suspension isolates the watch deadline; it is not Android process-death recovery. |
| Find phone from watch | Dart parser recognizes `findPhone` but no consumer was found. Gadgetbridge maps it to START/STOP. The explicit firmware find-phone helper found belongs to the separate Chronos protocol. | Verify the actual watch→phone JSON emitter before implementing or claiming an existing feature migration. |
| Calendar/call/activity/navigation | Some typed protocol definitions exist; native receive dispatch has no equivalent handlers. | Identify initialized provider/UI handlers and real firmware consumers per function before choosing migration order. |
| Voice notes/jobs | Durable native receipts, explicit existing Flutter import/playback and separate recoverable job/outbox contracts exist. | Downloads/integrity and AI/model/backend acceptance remain separate. Downloads stay paused for current core tests; AI is deferred by the user. |
| SMP/DFU/files/debug/watchfaces | Existing Nordic wrapper/fork retained. Service-owned Shell integration uses Nordic ShellManager and the existing Flutter Shell screen; deterministic tests and both debug builds pass. Nokia cold Power Status, CPU Frequency, a same-generation command burst/Home observation and idle/Stop cleanup are verified on the SDK checkpoint. Other competing-owner routes remain withheld. | Physical Shell engine destruction, failed SDK cleanup, monitor output and transfer/DFU arbitration remain. Continue native-backed controls with the user's Nordic fork; keep corruption diagnosis separate. |

## Source evidence

- [`NativePrototypeTransport.kt`](zswatch_app/android/app/src/main/kotlin/dev/zswatch/app/companion/NativePrototypeTransport.kt)
  dispatches time, watch information, notification dismissals, HTTP, media and
  recording and `gps_power` messages. Find-phone/call/calendar handlers remain absent.
- [`gps_providers.dart`](zswatch_app/lib/providers/gps_providers.dart) and
  [`gps_service.dart`](zswatch_app/lib/services/location/gps_service.dart)
  implement the Dart GPS path.
  [`app.dart`](zswatch_app/lib/app.dart) initializes `gpsNotifierProvider` in the
  ordinary `_initializeBle` path; native mode bypasses that legacy startup.
  This is source evidence, not a fresh physical test of legacy GPS.
- [`notification_providers.dart`](zswatch_app/lib/providers/notification_providers.dart),
  [`watch_service.dart`](zswatch_app/lib/services/watch_service.dart),
  [`gadgetbridge_protocol.dart`](zswatch_app/lib/services/protocol/gadgetbridge_protocol.dart),
  [`developer_screen.dart`](zswatch_app/lib/ui/screens/developer/developer_screen.dart)
  and native router boundaries distinguish initialized consumers from typed
  protocol support and legacy actions.
- Firmware [`weather_app.c`](../ZSWatch/app/src/applications/weather/weather_app.c)
  requests fresh GPS on entry when its stored position is old and for periodic
  background weather, then cancels GPS after a fix and on close. Firmware
  [`ble_comm.c`](../ZSWatch/app/src/ble/ble_comm.c) emits `gps_power` and
  [`ble_gadgetbridge.c`](../ZSWatch/app/src/ble/gadgetbridge/ble_gadgetbridge.c)
  consumes `gps`/`find`. The explicit find-phone helper in
  [`ble_chronos.c`](../ZSWatch/app/src/ble/chronos/ble_chronos.c) belongs to Chronos.
- Gadgetbridge's existing checkout
  [`BangleJSDeviceSupport.java`](Gadgetbridge/app/src/main/java/nodomain/freeyourgadget/gadgetbridge/service/devices/banglejs/BangleJSDeviceSupport.java)
  maps `findPhone` to START/STOP and sends reverse `find` commands. No
  Gadgetbridge implementation was copied into the app by this inventory.

## Next work

1. Finish physical GPS/Weather acceptance after explicit approval for real
   location transmission. Implementation and deterministic lifecycle/queue tests
   are complete; real Nokia fix/network availability remains separate. Verify a
   fresh position reaches the watch consumer and Weather completes with Flutter
   absent. Do not treat acquisition, ATT completion or synthetic fixes as that pass.
2. Retain watch-side Find Watch disconnect/maximum-duration protection and its
   bounded physical software evidence. Motor effects still require independent
   observation. Do not invent a watch→phone protocol to make a test pass.
3. Retain the completed HTTP comparison in the Nokia runbook. Local relay works
   in the bounded idle case; remote network/deadline and watch error handling
   remain distinct follow-ups. Do not repeat idle trials without a new question.
4. Continue remaining notification actions and ordinary feature migration from
   actual initialized consumers. Preserve Flutter/Nordic and defer iOS/AI.
