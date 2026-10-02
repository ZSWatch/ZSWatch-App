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

## Remaining stage 0 work

USB SMP status/control is now verified on the connected rig. Verify exact watch
revision/installed firmware and preserve that provenance.
Attach a physical phone, establish the normal bond/permissions, implement
foreground notification/time/voice fixtures and reproduce a background failure.
Add scenario assertions and deployment adapters separately. Mac/iPhone control,
native lifecycle instrumentation and actual background acceptance are pending.
