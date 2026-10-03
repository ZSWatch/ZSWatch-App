# Companion background test foundation

This is the first, Linux/Android part of stage 0 in
[`COMPANION_BACKGROUND_IMPLEMENTATION_PLAN.md`](../../COMPANION_BACKGROUND_IMPLEMENTATION_PLAN.md).
It provides inventory, build provenance and log collection. It does not install
or start the app, connect over BLE, change power state, pair, flash or reset.

## Setup and tests without a phone

Run from the ZSWatchApp repository root:

```bash
python3 -m venv /tmp/zswatch-companion-tools
/tmp/zswatch-companion-tools/bin/pip install -r scripts/companion_hil/requirements.txt
/tmp/zswatch-companion-tools/bin/python -m unittest discover -s scripts/companion_hil/tests -v
```

Tests use a PTY as a simulated UART and a fake ADB process. They exercise byte
preservation, resource contention, interrupted logcat, output preservation,
silent UART and missing equipment. They do not establish real BLE reliability.

## Inventory

Without equipment, this is still useful and intentionally returns exit code 2:

```bash
python3 scripts/companion_hil/hil.py preflight --output /tmp/zswatch-preflight-001
```

With equipment, explicitly select the phone and **two separate** watch ports:

A USB cable, FTDI UART adapter or J-Link appearing in the host inventory does
not alone establish the watch's USB CDC/SMP endpoint. In the current firmware
source, `zsw_usb_manager.c` releases USB after a 20-second boot guard when CDC
DTR is not asserted. The Update app's USB toggle enables it again. Therefore
an absent CDC port can mean inactive firmware USB rather than a missing cable.
Inventory does not reset the watch to reopen this boot window. An explicitly
requested reset during lab setup can reopen it; keep this separate from a
session-preserving test or a lifecycle/reconnection scenario.

The connected rig was verified on 2026-10-02: J-Link `51022722`, UART
`usb-FTDI_FT232R_USB_UART_BG00RS5E-if00-port0`, and USB SMP
`usb-ZEPHYR_ZSWatch_6F42BAA5F4D862F3-if00`. A targeted nRF53 reset followed by
opening SMP within 5.45 seconds allowed status commands; another status command
after 25 seconds succeeded, and the USB port remained after the client closed.
Re-inventory these identities if the rig changes. The watch's physical revision
and exact installed firmware artifact still need verification.

When this verified SMP port is absent, the following explicit setup sequence
resets the selected probe's target and opens it as soon as it enumerates. Prepare
the Python environment before reset. Pyserial's default asserted DTR keeps CDC
active during the boot guard; sending a valid SMP request also verifies the path.

```bash
export ZSW_JLINK_SERIAL=51022722
export ZSW_SMP_PORT=/dev/serial/by-id/usb-ZEPHYR_ZSWatch_6F42BAA5F4D862F3-if00
/tmp/zswatch-companion-hil-venv/bin/python - <<'PY'
import asyncio, os, subprocess, time
from pathlib import Path
from smpclient import SMPClient
from smpclient.generics import success
from smpclient.requests.shell_management import Execute
from smpclient.transport.serial import SMPSerialTransport

async def bootstrap():
    port = Path(os.environ['ZSW_SMP_PORT'])
    if port.exists():
        raise RuntimeError('SMP already available; use the status probe without reset')
    process = subprocess.Popen(['nrfutil', 'device', 'reset', '--serial-number',
                                os.environ['ZSW_JLINK_SERIAL'], '--family', 'nrf53'])
    try:
        deadline = time.monotonic() + 15
        while not port.exists():
            if process.poll() not in (None, 0) or time.monotonic() >= deadline:
                raise RuntimeError('Reset failed or SMP did not enumerate in time')
            await asyncio.sleep(0.05)
        async with SMPClient(SMPSerialTransport(exclusive=True), str(port), timeout_s=3) as client:
            for delay in (0, 25):
                await asyncio.sleep(delay)
                response = await client.request(Execute(argv=['app', 'state']), timeout_s=5)
                assert success(response) and response.ret == 0, response
                print(response.o)
        assert process.wait(timeout=5) == 0
        assert port.exists(), 'CDC disappeared after closing the client'
    finally:
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=5)

asyncio.run(bootstrap())
PY
```

Start the UART collector before this explicit action when boot evidence is needed.
Do not automatically repeat reset on errors: save the first failure and logs.

```bash
python3 scripts/companion_hil/hil.py preflight \
  --android-serial "$ZSW_PHONE_SERIAL" \
  --watch-uart "$ZSW_UART_PORT" --watch-smp "$ZSW_SMP_PORT" \
  --apk /absolute/path/app-release.apk --firmware /absolute/path/zephyr.hex \
  --output /tmp/zswatch-preflight-002
```

`--app-repo` and `--watch-repo` override the default sibling repository paths.
`manifest.json` records both revisions, dirty status, tracked diff hashes and
patches, submodule revisions, phone OS/package information, host tools and
artifact hashes. It lists unresolved identity, bonding and firmware checks.
Untracked/submodule working contents are not copied or fully attested. Provided
APK/firmware hashes identify local files; they do not prove what is installed.
Keep a preflight with each actual build/deployment and repeat after commits.

Exit codes: 0 means **READY_FOR_PROBE**, 2 means **BLOCKED**, and 1 means an
execution **ERROR**. READY_FOR_PROBE only means the selected resources were
found; check SMP responsiveness and physical identities before deployment.
Missing/unauthorized/offline phones are never silently replaced with another.
Inventory may start the host ADB daemon, but sends only discovery/property/package
queries. Output directories must be new, preserving prior evidence.

## Capture

```bash
/tmp/zswatch-companion-tools/bin/python scripts/companion_hil/hil.py capture \
  --android-serial "$ZSW_PHONE_SERIAL" --watch-uart "$ZSW_UART_PORT" \
  --duration 60 --output /tmp/zswatch-capture-001
```

For explicitly requested watch-only observation, omit the phone and use
`--watch-only`. The collector receives UART at 115200 baud and logcat with
epoch device timestamps; it never clears either log buffer. It writes
`watch-uart.bin`, readable `watch-uart.log`, `phone.log` when applicable,
`timeline.jsonl` and `capture.json`. The timeline timestamps host receipt with
UTC and monotonic time, not the device event time. Raw UART bytes survive invalid
UTF-8 and fragmentation. An empty UART is recorded as `NO_DATA`.

`COLLECTED` means collection completed; `acceptance` is always `NOT_RUN`.
Collector/port/device failures become ERROR with preserved partial evidence;
Ctrl-C records INTERRUPTED. Start capture before triggering a later scenario.
Keep the preflight and capture folders together in that scenario's artifacts.

Linux cooperative locks prevent two copies from using the same phone/UART;
pyserial additionally opens UART exclusively. Other ADB tools do not honor these
locks. Close existing UART readers first. Opening UART leaves DTR/RTS deasserted;
validate physical wiring before relying on uninterrupted hardware sessions.
Do not run the separate UART capture while pytest's UART fixture owns the port.

## Session-preserving watch probe

The firmware repository now supports `--preserve-session`, requiring an explicit
physical board, local config and tests marked `companion_session`. Ordinary boot,
DFU, PPK2 and PC BLE tests are rejected before fixtures run. Fixture reset,
recover, flash and PPK2 power setup are disabled; deployment failures in ordinary
mode now fail instead of skipping. This guards fixtures and audited tests, not
arbitrary Python code or shell commands added by a future test author.

Create a local YAML with verified ports (never copy old debugger identifiers):

```yaml
devices:
  watchdk@1:
    serial_port: /dev/serial/by-id/VERIFIED_UART
    usb_cdc_port: /dev/serial/by-id/VERIFIED_USB_SMP
```

From the ZSWatch firmware repository:

```bash
python3 -m venv /tmp/zswatch-companion-hil-venv
/tmp/zswatch-companion-hil-venv/bin/pip install \
  'pytest==9.1.1' 'pytest-asyncio==1.4.0' 'PyYAML==6.0.3' \
  'pyserial==3.5' 'smpclient[ble,serial]==7.3.0'
/tmp/zswatch-companion-hil-venv/bin/python -m pytest \
  app/pytest/companion_session_probe.py --board watchdk@1 \
  --device-config /absolute/path/devices_local.yaml --preserve-session -s \
  --basetemp /tmp/zswatch-status-probe-001
```

Use a **new** `--basetemp` directory; pytest clears that directory on startup.
The probe only executes `app state` and `voice_memo status` over USB SMP and
requires expected responses and zero shell return status. It saves those
responses in pytest's per-test temporary artifacts. This proves the separate
control path, not notification/time/voice delivery from a backgrounded phone.
The module name keeps it out of ordinary HIL test discovery.

Safety regression tests run without any probe, serial port or phone:

```bash
python3 -m pytest app/pytest_unit/test_session_safety.py -q
```

## Synthetic file-transfer probe without a phone

This explicitly creates one uniquely named `.zsw_opus` fixture on the watch.
The header/frame structure is deterministic, but payload is synthetic data;
it exercises file transport, not speech capture, decoding, STT or an LLM.

```bash
/tmp/zswatch-companion-hil-venv/bin/python scripts/companion_hil/watch_file_probe.py \
  --watch-smp "$ZSW_SMP_PORT" --create-fixture \
  --output /tmp/zswatch-file-reconnect-001
```

It checks that the watch is not recording and that its new UUID-named path is
absent, uploads a prefix, closes the client, resumes upload, then downloads a
prefix and resumes with a new client from the saved local prefix. It compares
all bytes, saves SHA-256 evidence and deletes only this run's owned fixture.
Errors and cleanup results remain in `result.json`. No reset, pairing, flash,
microphone recording, or changes to existing recordings are performed.

Verified on the physical watch on 2026-10-02: 5,472 bytes, upload interruption
at byte 256 and download interruption at byte 2,425. The resumed file matched
the original SHA-256. Cleanup succeeded and the recording count remained zero.
Artifacts are in `.companion-hil-runs/20261002-usb-file-reconnect/`.
This does not prove BLE resumption on Android/iOS or native plugin behavior.

## Existing Flutter/Nordic transfer baseline

`zswatch_app/tool/companion_flutter_transfer_probe.dart` calls the existing
`WatchService`, `BleConnectionService` and `FileSystemService`, including the
normal SMP enable, two-second wait and service rediscovery. File transfers go
through the unchanged `mcumgr_flutter` wrapper and Nordic's native transport.
It starts no voice-sync/AI provider and deletes no watch recording.

Build from `zswatch_app`, choosing the actual bonded address and one to four
existing filenames (without `.zsw_opus`):

```bash
flutter build apk --debug --no-pub \
  --target tool/companion_flutter_transfer_probe.dart \
  --dart-define=HIL_WATCH_ADDRESS=VERIFIED_MAC \
  --dart-define=HIL_RECORDINGS=EXISTING_FILENAME_1,EXISTING_FILENAME_2
```

Preserve the built APK under a run-specific path before another build. Install
that saved file with targeted `adb -s "$ZSW_PHONE_SERIAL" install -r`; do not
uninstall the app or clear its data. Launch, unlock the phone, and press **Run
foreground transfer diagnostic**. Wait for protocol-ready state, not merely the
return from `connectById`. The diagnostic writes unverified local receipts and
`result.json` under the phone's private `app_flutter/companion-flutter-probe/`
with a unique run directory. A 60-second caller timeout cancels through the
existing wrapper and ends the batch rather than overlapping another transfer.

Hash/read each selected source through USB SMP before the BLE run, with no USB
filesystem traffic during the BLE transfers. Afterwards, compare each received
file's bytes, length and SHA-256 with an independent USB read. Read real audio
into host memory only; save metadata/hashes as evidence. `received_unverified`
is not an integrity pass. Preserve failed trials and all watch originals.
This diagnostic is a foreground SDK baseline, not a background/kill-recovery test.

## Android companion-presence prototype

Build the existing native prototype with
`--dart-define=COMPANION_RUNTIME_PROTOTYPE=true`, launch it, then use **Connect /
recover** and **Enable presence recovery**. The second action opens Android's
system companion-association picker for that exact watch address. An existing
Bluetooth bond is not a companion association. Cancellation reports an error;
unsupported devices keep the explicit foreground connection path.

The prototype supports Android 12/API 31 and later with the companion-device
setup feature. Its permission/service declarations exist in the debug manifest
only. The Android-12-compatible address-based observation callbacks are retained
on newer Android versions; Android 16-specific API migration remains separate.
`PrototypePresenceService` receives OS callbacks without launching Flutter,
checks the saved connect intent and current association, then asks the existing
native runtime to restore. Address/generation checks prevent a delayed event
from undoing Stop or changing watches. Ready links remain owned by the existing
runtime; a matching presence event can retry a failed link. Stop persists the
intent first and unregisters observation without removing the association/bond.

Physical acceptance must establish actual association, OS presence callbacks,
protocol-ready restoration and time writes with UI absent. Repeat after an
injected crash without launching the Activity or using instrumentation; label
that result separately from OS memory reclamation. Then test Stop, cancellation,
watch absence, radio changes and association removal. Address identity after
watch reboot and wakeup reliability on this Nokia are not yet verified, so
presence is not established as the sole recovery path. Do not silently change
battery restrictions to obtain a pass.

API references: [Android background BLE guidance](https://developer.android.com/develop/connectivity/bluetooth/ble/background),
[companion association](https://developer.android.com/develop/connectivity/bluetooth/companion-device-pairing),
[presence observation](https://developer.android.com/reference/android/companion/CompanionDeviceManager#startObservingDevicePresence(java.lang.String)).

## App voice-receipt checks without a phone

From `zswatch_app`:

```bash
flutter test --no-pub test/voice_memo_sync_service_test.dart \
  test/voice_memo_file_store_test.dart test/zsw_opus_parser_test.dart --reporter expanded
dart analyze lib/services/voice_memo/voice_memo_file_store.dart \
  lib/services/voice_memo/voice_memo_sync_service.dart \
  test/voice_memo_sync_service_test.dart test/voice_memo_file_store_test.dart
flutter build apk --debug --no-pub
```

42 tests pass, including 11 new receipt/storage regressions. The service accepts
list/download callbacks before the send/download Future returns, ignores duplicate
and unrelated-file completions, and does not delete a watch copy on transfer,
verification, storage or metadata-commit failure. It publishes flushed raw/Ogg
files via same-filesystem staging and rename before marking receipt in the DB.
A separate Dart process is killed after staging to test preservation and retry.
The idle-reset timer is canceled on disposal.

These original receipt tests use fake transfer/repository adapters with real
local file I/O. They cover receipt races and file publication; the follow-up
below adds actual SQLite recovery. Mobile OS lifecycle and permission/radio
wakeups, durable AI/outbox jobs and acknowledged watch deletion remain in the
implementation plan. Local and remote AI backends are unaffected.

Follow-up: [receipt recovery is now implemented in the app](../../VOICE_MEMO_RECEIPT_RECOVERY.md).
Add `test/voice_memo_recovery_service_test.dart` to the Flutter command above.
The selected suites now cover 63 tests, including 17 new recovery tests using
the actual Drift schema/repository with on-disk SQLite. Three separate Flutter
workers are SIGKILLed after staging, after file publication and after DB receipt
commit. App startup, list/detail and sync use the shared recovery provider.
Closed-container adoption is conservative; unknown/ambiguous data is retained.
Local recovery does not replace delete ACK, AI/outbox or mobile runtime ownership.

Android debug APK compilation also passed with the receipt changes and native
logging that persists BLE service starts with null action (including sticky
restart evidence). Validate that restart path on a physical phone.

## Remote-job fixtures and recovery contracts without a phone

See [the v1 recovery contract](../../REMOTE_JOB_RECOVERY_CONTRACT.md) for the
shared JSON envelopes/trace, local/remote policy, lease fencing, transaction
boundaries, outbox replay and the distinction between delivery ACK and actions.
The Python reference runtime uses separate SQLite files and is not wired into
the Flutter app or firmware. The fixture server accepts metadata only and
returns synthetic text; no audio upload, model or external provider is used.

From the repo root, Python standard library only:

```bash
python3 -m unittest discover -s scripts/companion_hil/tests -p test_remote_jobs.py -v
PYTHONPATH=scripts/companion_hil python3 -m remote_jobs.run_fixture \
  --output /tmp/zswatch-remote-recovery-001
PYTHONPATH=scripts/companion_hil python3 -m remote_jobs.server \
  --state-dir /tmp/zswatch-remote-server-001 --port 8765
```

Use new output directories. A standalone server can explicitly resume a marked
state directory with `--resume-existing`. It binds only to loopback; test controls
can complete/fail/cancel a job or inject one lost acceptance response, 429 or 401.
Replay saves SQLite stores, timeline, fixture/database hashes and `result.json`.
24 new tests include two real subprocess kills around a SQLite commit, competing
claims, stale callbacks, backend policy, cancellation, generation replacement,
server result retention, bounded retry, explicit triggers and fake-watch ACK loss.
The trace yields one remote job and one receipt. `CONTRACT_VERIFIED` is a host
conformance result; mobile/background acceptance remains `NOT_RUN`.

## Native Android runtime experiment without a phone

See [the service-owned prototype/runbook](../../ANDROID_COMPANION_RUNTIME_PROTOTYPE.md)
for its debug build flag, v1 Flutter bridge, separate journal and recording store,
host checks and physical-phone scenarios. The native service owns NUS and BLE
MCUmgr, with persisted running intent, session fencing and receipt recovery.
Flutter detach/reattach only changes observers. The normal startup is skipped
in the experiment; no model starts, no Drift migration occurs, and no watch
recording is deleted.

34 JVM tests include three forcibly killed JVM workers at native staging,
publication and journal-commit boundaries. 72 selected Flutter tests include
9 new bridge/UI tests and the existing 63 receipt/parser checks. Both prototype
and normal debug APKs compile. The JVM workers exercise actual journal/files,
with fake transport, rather than an Android service. Real GATT, SMP coexistence,
screen-off execution, OS restarts and manufacturer power behavior require physical
acceptance. The first [Nokia smoke report](../../ANDROID_COMPANION_NOKIA_SMOKE.md)
records partial successes and failures; it does not satisfy that acceptance.
Existing capture tooling records evidence; it does not automatically assert the
new phone scenarios. Keep baseline, process reclamation and force-stop separate.
Review regressions additionally cover canonical recording timestamps and intact
clock packets. Current APKs/evidence: `.companion-hil-runs/20261002-prototype-review-fixes/`
at the application repository root. Firmware application of zero/fractional
timezone offsets remains a separate known limitation in the prototype runbook.

For the attached Android phone's debug-only transfer diagnostic, see the
[native companion runbook](../../ANDROID_COMPANION_RUNTIME_PROTOTYPE.md). The
instrumentation probe can retry existing files while locked, but its scheduling
effect means it cannot prove ordinary background lifecycle recovery. The latest
timeout trial lengthened Nordic's per-chunk wait from 2.5 to 10 seconds; complete
file reception improved, while invalid file hashes still blocked receipt
publication. Packet/source hash evidence is documented in the
[Nokia smoke report](../../ANDROID_COMPANION_NOKIA_SMOKE.md).

## Remaining stage 0 work

USB SMP status/control is now verified on the connected rig. Verify exact watch
revision/installed firmware and preserve that provenance.
A Nokia G100/Android 12 is now attached and bonded. The first native smoke session
exercised real time writes, recordings and background failures. Complete the
ordinary-app baseline and notification/time/voice scenario assertions; resolve the
transfer and process-recovery failures in the smoke report.
Add scenario assertions and deployment adapters separately. Mac/iPhone control,
instrumented phone scenarios and actual background acceptance are pending.

### Read-only native state probe

`native_runtime_probe.py` reads the prototype journal through `run-as`, observes
the native service/PID/current Activity and optionally verifies a frozen APK
against the installed hash. It rejects stringified package allowlists, persisted
Ready without a live service, and Stop with retained content/service. Reports
redact Android notification keys/text and always keep `acceptance=NOT_RUN`.

```bash
python3 scripts/companion_hil/native_runtime_probe.py \
  --adb /home/jakkra/Android/Sdk/platform-tools/adb \
  --android-serial A00000V791290707484 --expect stopped \
  --apk /absolute/path/to/frozen-prototype.apk \
  --output /tmp/new-native-state-observation.json
python3 -m unittest discover -s scripts/companion_hil/tests -p test_native_runtime_probe.py -v
```

For the prototype's synthetic notification test, grant ZSWatch notification
access in Android Settings, pause recording downloads, open Notification settings,
select only ZSWatch and enable forwarding, then connect. A fresh native journal
has no selected apps; turning forwarding on does not populate its allowlist.
Native builds now open the existing app shell. Use Connection setup on the start
page (or Developer on the connected dashboard) to reach the runtime controls;
downloads/diagnostic fixture controls remain there. The home page's Connect and
Disconnect/Cancel control native intent. Merely opening the app never starts BLE.
`Close UI and test in 15s` schedules a fixed native notification
and finishes/removes the Activity/task. It is an in-process diagnostic timer,
not a process-death scheduler. Correlate `ui_detached`, synthetic post and native
write-completion timestamps. Do not run transfer instrumentation during these
background observations; it changes OS execution conditions.

With the native runtime intentionally running, a non-exported app-UID action
can post that fixed notification without launching Flutter:

```bash
adb -s A00000V791290707484 shell run-as com.zswatch.app /system/bin/am \
  startservice --user 0 -n com.zswatch.app/dev.zswatch.app.companion.CompanionPrototypeService \
  -a dev.zswatch.app.companion.POST_TEST_NOTIFICATION
```

This action is a lab trigger, not automatic background scheduling. For a physical
dismissal test, first verify the new synthetic ID was written. The current
watch's `touch 200 95` command closes its notification popup. Correlate the watch
manager's removal of that exact ID with native `watch_notification_dismiss_requested`
and Android listener removal; a successful touch command alone proves neither.
Keep other notifications out of the test and leave source recordings intact.
The installed watch exposes `input report`, not the older guide's `input button`;
read actual shell help before relying on a control command.

The 2026-10-03 forced-idle scenario is documented in the Nokia report. It used
`dumpsys battery unplug` plus `dumpsys deviceidle force-idle deep`, asserted deep
state `IDLE` before and after a watch-origin BLE status update, and restored
`deviceidle unforce`/`battery reset` in cleanup. USB was physically attached.
It does not satisfy unplugged Doze/soak or network acceptance. Controlled watch
battery events were restored to the measured baseline; do not leave injected
charging/battery values behind. No app/service-start command should be issued
during the receive window of that idle scenario.

Use Nokia for BLE/lifecycle tests only. The prepared headless Dart worker and
actual models are for later testing on a suitable newer phone; do not invoke
`startLocalFixture` or run inference in this Nokia test setup.

After the screen-off test locked the dedicated phone, cleanup used the existing
non-exported Stop action as the debug app UID:

```bash
adb -s A00000V791290707484 shell run-as com.zswatch.app /system/bin/am \
  startservice --user 0 -n com.zswatch.app/dev.zswatch.app.companion.CompanionPrototypeService \
  -a dev.zswatch.app.companion.STOP
```

Observe the stopped state afterward; command acceptance alone does not prove Stop.
Bluetooth off/on after Stop must preserve desired intent=false. Leave Bluetooth on.
This ADB-triggered cleanup is separate from autonomous recovery evidence.

`native_runtime_probe.py --jobs` additionally checks the separate native job
journal: canonical job identity, result/outbox consistency and matching persisted
ACK state. It emits only job IDs/state/counters, never result text or specs.
The Android loopback adapter and physical crash results are documented in
[`REMOTE_JOB_ANDROID_PROTOTYPE.md`](../../REMOTE_JOB_ANDROID_PROTOTYPE.md).
