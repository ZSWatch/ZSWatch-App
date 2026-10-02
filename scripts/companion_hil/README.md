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

## Remaining stage 0 work

Verify watch identity/firmware and a USB SMP or other independent control path.
Attach a physical phone, establish the normal bond/permissions, implement
foreground notification/time/voice fixtures and reproduce a background failure.
Add scenario assertions and deployment adapters separately. Mac/iPhone control,
native lifecycle instrumentation and actual background acceptance are pending.
