# ZSWatch App — agent instructions

Single source of instructions for coding agents (Codex, Claude Code, Copilot).
`CLAUDE.md` and `.github/copilot-instructions.md` only point here.

## Repository

| Path | What it is |
| --- | --- |
| `zswatch_app/` | The Flutter companion app (Android + iOS). Almost all work happens here. |
| `zswatch_app/ios/Runner/` | Swift native companion: owns BLE, SMP, recordings, voice jobs. |
| `zswatch_app/android/app/src/main/kotlin/dev/zswatch/app/companion/` | Kotlin native companion: same role on Android. |
| `packages/chrono_ai_flow/` | Shared prompts/JSON schema for on-device AI (app + `ai_testbench`). |
| `ai_testbench/` | Desktop app for benchmarking LLMs against the production prompts. |
| `Flutter-nRF-Connect-Device-Manager/` | Submodule, ZSWatch fork of `mcumgr_flutter`. Branch `zswatch/ios-companion`. |
| `third_party/fllama/` | Submodule, ZSWatch fork of `fllama` (`main`). |
| `scripts/companion_hil/` | Hardware-in-the-loop tools for watch/phone testing. See its README. |
| `ZSWatch/` | Firmware repo, separately cloned and gitignored. **Do not modify unless asked.** |

The iOS SDK `iOSMcuManagerLibrary` comes from
[ZSWatch/IOS-nRF-Connect-Device-Manager](https://github.com/ZSWatch/IOS-nRF-Connect-Device-Manager)
branch `zswatch/1.10.1` (Nordic 1.10.1 + our fixes), pinned by commit in
`zswatch_app/ios/Podfile`. Change the SDK there, push, then bump the commit.
Do not vendor SDK code or commit formatting-only changes into forks: it buries
real changes in reviews.

Root-level `*.md` planning/progress files are history. Current status lives in
`IOS_COMPANION_DELIVERY.md` and `ANDROID_FEATURE_PARITY.md`.

## Architecture

- **Native owner.** On both platforms a native companion owns the watch
  connection and keeps working without the Flutter engine (background, force
  quit restoration on iOS, foreground service on Android). Flutter attaches to
  it over the `dev.zswatch.app/companion_v1` method channel
  (`lib/services/background/companion_prototype_client.dart`). Do not add
  BLE work in Dart that bypasses the owner.
- **Protocol.** JSON over Nordic UART (Gadgetbridge/BangleJS format:
  outgoing `GB({json})\n`, incoming raw JSON). Use Gadgetbridge messages where
  they exist, standard GATT services where they exist, Extended API otherwise.
  Firmware side: `ZSWatch/app/src/ble/gadgetbridge/ble_gadgetbridge.c`.
- **SMP/MCUmgr** for firmware update, filesystem and shell. DFU uploads
  `dfu_application.zip` images by manifest `image_index` (0 = app internal,
  1 = net core, 2 = app external/XIP). Upload filesystem resources before
  firmware: the firmware reboot would cut a resource upload.
- **iOS pairing.** AccessorySetupKit (`IOSAccessorySetup.swift`) only
  authorizes the accessory; the watch's security request triggers bonding on
  first connect. Do not add `.bluetoothPairingLE`: iOS drops the link as
  ASK-driven pairing completes with this watch ("Cannot Add Accessory").
- **Voice/AI.** Recordings sync natively; transcription/analysis run in a
  shared Dart worker (`companion_dart_worker.dart`) with on-device models.

### Flutter layers (`zswatch_app/lib/`)

`ui/` (screens per feature, `go_router` routes in `AppRoutes`) → `providers/`
(Riverpod, one file per domain) → `services/` (plain Dart classes exposing
streams) → `data/` (Drift DB, models, repositories). `core/` holds constants
(BLE UUIDs in `core/constants/ble_constants.dart`), extensions and theme.

## Conventions

- Riverpod only (`Provider`, `StreamProvider`, `StateNotifierProvider`); no
  `ChangeNotifier` or Bloc. Screens use `ConsumerWidget`/`ConsumerStatefulWidget`.
- Repositories take `AppDatabase`; models use `copyWith`.
- Log with `debugPrint('[ClassName] message')`, never `print()`.
- Lints are strict (`strict-casts`, `strict-inference`, `strict-raw-types`,
  `unawaited_futures`, `cancel_subscriptions`, `prefer_single_quotes`, ...).

## Build and test

CI (`.github/workflows/pr.yml`) runs, in `zswatch_app/`:

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

Run `dart format` on files you touch before committing. Regenerate code after
Drift table or Riverpod changes.

iOS on a Mac:

```sh
cd zswatch_app/ios && LANG=en_US.UTF-8 pod install   # CocoaPods crashes without UTF-8
cd .. && flutter build ios --release
xcrun devicectl device install app --device <id> build/ios/iphoneos/Runner.app
```

Confirm installs by the `App installed:` line; the version number is the same
for every build. `xcrun devicectl list devices` gives the device id.

Python HIL tools: `scripts/companion_hil/requirements-watch.txt` in a venv
(the repo uses `.venv-watch/`). Unit tests need no hardware:
`PYTHONPATH=scripts/companion_hil .venv-watch/bin/python -m unittest discover -s scripts/companion_hil/tests`.

## Hardware testing

- `watch_usb.py`: shell commands over USB SMP (`-- app state`), SMP
  `--reboot`, or debugger `--reset` with an explicit `--probe`.
- `usb_dfu.py`: install a `dfu_application.zip` over USB with hash checks,
  reboot and confirm.
- `ios_syslog.py`: iPhone system log over USB without sudo, filtered to the
  app and Bluetooth/AccessorySetupKit processes. Run once around a repro; never
  in a restart loop (it left the phone unusable).
- `hil.py capture`: timestamped watch UART (+ Android logcat).
- `ios_ui/`: XCUITest driver for the real app on a phone.

Rules: the watch releases USB 20 s after boot unless the host holds the CDC
port, so keep it open 25 s after a reboot. Do not flash, reset or recover the
watch during phone background/reconnection tests. Keep raw evidence in the
gitignored `.companion-hil-runs/`, not in commits or `/tmp`.

## Git

- Work on feature branches; the app PR targets `main`.
- Create pull requests for the user to review and merge; do not merge them.
- Submodule changes: commit and push in the submodule first, then commit the
  new pointer in the app.
- The firmware repo (`ZSWatch/`) has its own review process; leave it alone
  unless explicitly asked.
