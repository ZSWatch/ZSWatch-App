# Mac iOS baseline

Established 2026-10-12 for `IOS_COMPANION_IMPLEMENTATION_PLAN.md`, stage 1.

## Source and preservation

- App branch: `codex/ios-companion`, created from handoff `d7a51f1cf31d6ac892ebee49dcaa3febcdeaee93`.
- Nordic gitlink: `f67c1860f57016918dd8b5b550f65d799271af13`.
- fllama gitlink: `115e7991e78de446ed44858ebe0a8dbc82769d8e`.
- Firmware: local `ZSWatch/`, branch `codex/companion-background-foundation`.
  This is a nested separate checkout, excluded from app Git tracking.
- The previous Mac `main` had a database repair, its new test and a changed
  Podfile.lock. Those three paths are preserved in the named stash
  `Mac local database repair and Podfile before iOS companion handoff 2026-10-12`.
  Exact files and a binary patch also remain at
  `/tmp/zswatch-ios-handoff-preserved-20261012/`. They have not been discarded or
  automatically applied over the newer schema-7 handoff database. Review the
  repair against the final iOS storage design before restoring it.
- `flutter pub get` left the pinned pubspec lock unchanged. CocoaPods regenerated
  the iOS lock for dependencies already present in the handoff pubspec.

## Tools and physical inventory

| Item | Observed |
| --- | --- |
| Xcode | 26.1.1, build 17B100 |
| Flutter | 3.38.4, framework `66dd93f9a2` |
| Dart | 3.10.3 |
| CocoaPods | 1.16.2 |
| Deployment target | 14.0 retained |
| iPhone | Connected iPhone 11 (`iPhone12,1`), iOS 26.1 (`23B85`), Developer Mode enabled |
| Signing | Project team `28L8XH4G9T`; one valid Apple Development identity on Mac; signed build status below |
| Watch CDC/SMP | `/dev/cu.usbmodem21301`, USB VID:PID `2FE3:0100`, serial `6F42BAA5F4D862F3` |
| Watch UART | `/dev/cu.usbserial-BG00RS5E`, FTDI serial `BG00RS5E`; do not confuse with SMP |
| Watch tool Python | uv-managed CPython 3.12.12 in ignored `.venv-watch` |
| Installed firmware | Kernel reports Zephyr 4.3.99; exact app firmware commit/artifact not yet established |
| Watch contents | `voice_memo status`: not recording, 26 recordings, 9464 KB free |
| Watch state | `app state`: Update app; `ble_fota status`: enabled |

No reset, erase, flash, recording, deletion, SDK installation or debugger
connection was used. J-Link is installed, but the connected probe identity has
not been verified because no debugger operation was needed.

## Build and checks

Run app commands from `zswatch_app/`:

```sh
flutter pub get
flutter build ios --debug --no-codesign
flutter build ios --debug --no-pub
flutter test --no-pub test/companion_watch_catalogue_test.dart test/companion_prototype_client_test.dart
```

The unsigned device build passed, producing `build/ios/iphoneos/Runner.app`.
The signed Debug device build also passed using team `28L8XH4G9T`.
The selected catalogue/client baseline suites initially found a stale expected
map: the handoff had added `analysis_enabled`, but its older client test omitted
that field. The expectation now includes the existing default analysis policy;
no production processing behavior was changed.
All 31 selected tests pass after that correction. The three USB safeguards also
pass. The signed baseline was installed on the identified iPhone using
`xcrun devicectl device install app`; installation succeeded without clearing
app data. The signed app and build/test logs are preserved locally under ignored
`.companion-hil-runs/20261012-mac-baseline/` for future baseline comparisons.
Temporary host logs: `/tmp/zswatch-ios-baseline-build.log`,
`/tmp/zswatch-ios-baseline-signed-build.log`,
`/tmp/zswatch-ios-baseline-contract-tests.log`.

From the repo root, three `test_watch_usb.py` safeguards passed. Ordinary
read-only `watch_usb.py --port /dev/cu.usbmodem21301 --hold-seconds 0`
operations succeeded for `app state`, `help`, `voice_memo status`,
`kernel version` and `ble_fota status`. This verifies the Mac USB/SMP path,
not BLE performance or restoration. The reset backend has not been tested.

## Architecture observations for the next stage

The current product still selects native companion only on Android. iOS still
uses the legacy Dart connection owner; no iOS cutover or restoration acceptance
is claimed. `IOS_FEATURE_PARITY.md` inventories the UI before that cutover.

The pinned Nordic iOS SDK creates its own central and retrieves a peripheral
by identifier; passing a `CBPeripheral` does not give it the caller's central
or delegate. Coordinator integration must therefore serialize all SMP work and
coordinate SDK transport lifetimes. Do not overwrite the Nordic peripheral
delegate with the NUS delegate or require an unsupported shared-central API.

The productivity bridge is currently registered through the UI controller.
The existing Dart worker has no watch owner or database and can be reused,
with per-engine plugin registration and an explicit iOS execution policy.
The Dart catalogue currently validates Android MAC addresses and the snapshot
decoder currently only accepts `android_service_native`; both require an iOS
contract before the provider is switched.

Swift background collection must establish one durable writer and a controlled
Dart projection. Do not open the existing Drift file using a second, unrelated
native SQLite integration.

Next acceptance: implement the native owner and normal Flutter integration,
then verify NUS events and replies, reconnect, explicit Stop/Forget and actual
CoreBluetooth restoration on the connected iPhone/watch. The presence of
`bluetooth-central` in Info.plist does not prove those behaviors.
