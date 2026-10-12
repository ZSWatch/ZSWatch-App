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

## Fresh repository and tool recheck

On 2026-10-12 all four origins were fetched again. The latest handoff refs are
still app `d7a51f1`, firmware `0f56aec7`, Nordic `f67c186` and fllama `115e799`.
The app remains on `codex/ios-companion`, preserving local baseline commit
`baaabfa`; detached library HEADs match both the handoff gitlinks and their
latest handoff branches. The firmware branch also has local tool-only commit
`e9fcd5b5`; its runtime firmware source was not changed.

The fresh **signed Release** build passed (79.8 MB), and `codesign --verify
--deep --strict` verified the app and its nested libraries. It was installed on
the same iPhone without uninstalling or clearing app data. The exact build
source was `baaabfa` plus its pinned submodule trees. Generated app and binary
hashes are kept in ignored `.companion-hil-runs/20261012-mac-tools-check/`.
It also launched successfully. A deliberately bounded 12-second `devicectl
--console` capture received real Flutter/plugin output, including Bluetooth
powered-on and reconnect requests. The console command timed out as expected
while the app was running; a separate ordinary launch leaves the app available.
This establishes app launch and console access, not BLE connection acceptance.

The first in-place Release attempt stalled in `dsymutil` while macOS requested
Documents-folder access and the desktop was locked. That build was stopped.
The successful build used Git archives of the exact app/library trees in
`/tmp/zswatch-ios-release-check-20261012`, with ordinary `flutter pub get` and
`flutter build ios --release --no-pub`. It generated symbols normally; no
privacy settings, Xcode binaries or Flutter SDK code were changed. No Mac
unlock or extra filesystem grant was needed for that isolated build.

| Tool/check | Actual result |
| --- | --- |
| Timestamped `hil.py capture --watch-only` | Now supports macOS; captured 318 bytes of actual display/IMU/app-picker logs at 115200 baud. Saved raw bytes, readable text, timeline and capture manifest. |
| Firmware `serial_capture.py` | Captured another 183 bytes of actual UART logs. An earlier passive sample was empty, honestly retained as no data. |
| USB/SMP shell | `app state`, `power status`, `kernel uptime`, `voice_memo status` and `ble_fota status` succeeded; a 25-second open-port check also succeeded. |
| USB filesystem fixture | 5,472 bytes; upload interrupted at 256 and download at 2,425; resumed bytes and SHA-256 matched. Only the uniquely owned fixture was deleted; recording count stayed 26. This is USB transport evidence, not BLE throughput. |
| SEGGER Commander | Official signed/notarized V9.24a package installed; `ShowEmuList` detects USB probe `51022722` without connecting/resetting the target. |
| Nordic `nrfutil` | Existing 8.1.1 binary, device module 2.22.0 installed; explicit `--jlink-dll` inventory finds J-Link, FTDI and watch CDC. Default DLL discovery remains unavailable; use the command below. |
| Apple Metal compiler | Installed official Metal Toolchain 17B54; `xcrun metal --version` succeeds (32023.830). |
| Host test suite | 59 tests: 58 pass, one Linux-only hardware-capture test skipped on Darwin. Correct invocation includes `PYTHONPATH=scripts/companion_hil`. |
| Firmware flash-helper guards | Four tests pass. `--help`, missing action/probe, and an absent image cannot trigger hardware access; every mutating command selects the probe explicitly. |

SEGGER files are available in `/Applications/SEGGER/JLink_V924a` and
`~/.local/opt/segger-jlink/JLink_V924a`. The watch virtual environment links
`JLinkExe` and `nrfutil`, so activate it for their PATH-based use:

```sh
source .venv-watch/bin/activate
JLinkExe -AutoConnect 0 -CommandFile /tmp/zswatch-jlink-inventory.jlink
nrfutil device --jlink-dll /Applications/SEGGER/JLink_V924a/libjlinkarm.9.24.1.dylib list
python scripts/companion_hil/hil.py capture --watch-only \
  --watch-uart /dev/cu.usbserial-BG00RS5E --duration 20 --output /tmp/NEW-uart-capture
```

The inventory command file contains only `ShowEmuList` and `exit`. Keep using
explicit probe selection for any later target operation. `watch_usb.py` no
longer mistakes macOS's Java launcher `/usr/bin/JLink` for a SEGGER executable.
The legacy firmware flash helper was also corrected: formerly `--help` was
treated as a firmware filename; the failed old invocation never flashed
anything because `nrfjprog` is absent. The updated helper requires `--port`,
`--probe` and an explicit `--flash EXISTING.hex` or `--reset`, and verifies its
UART port before an action.

This recheck did not reset, halt, flash or erase the watch. UI wake/close actions
generated logs; Update was restored and BLE FOTA remains enabled. A Weather
launch attempt was rejected while the app picker was still closing, so no
Weather/HTTP acceptance is claimed.

Firmware **compilation and flashing remain unverified**. The Mac has NCS
v3.2.0 installed, while this firmware's `app/west.yml` requires
v3.3.0-preview1. A matching SDK workspace and ELF are still needed for firmware
compilation and symbolic GDB inspection. No full SDK migration was performed
merely to test app builds or logging. BLE, restoration and local-AI acceptance
remain implementation-stage work, separate from this build/tool preflight.
