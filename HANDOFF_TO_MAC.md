# Mac / iOS companion handoff

Updated 2026-10-12. Read this together with `IOS_COMPANION_IMPLEMENTATION_PLAN.md`.

## Repositories and branches

| Repository | Branch to fetch | Relevant revision |
| --- | --- | --- |
| [ZSWatch-App](https://github.com/ZSWatch/ZSWatch-App/tree/codex/companion-background-foundation) | `codex/companion-background-foundation` | App changes `67976ef`; dependency pins `4812a77`; subsequent commits contain this handoff and portable tools. |
| [ZSWatch firmware](https://github.com/ZSWatch/ZSWatch/tree/codex/companion-background-foundation) | `codex/companion-background-foundation` | `0f56aec7` includes debugger/UART helpers; runtime firmware source remains `098977c4`. |
| [Nordic Flutter fork](https://github.com/ZSWatch/Flutter-nRF-Connect-Device-Manager/tree/codex/companion-handoff) | `codex/companion-handoff` | `f67c186`, based on `2aabd59`. |
| [fllama fork](https://github.com/ZSWatch/fllama/tree/codex/companion-handoff) | `codex/companion-handoff` | `115e799`, based on `3589948`. |

The app pins the exact library commits through Git submodules. The two new
library commits preserve the locally formatted Dart sources used during this
work; formatting-normalized comparisons of all 40 Nordic and 18 fllama modified
files found no non-format changes. Functional native fork changes were already
in the preceding pinned history. A recursive checkout retrieves both.

These are the handoff branches. Do not start from `main`, an old voice-memo
feature branch, or an unrelated website/hardware branch. No iOS implementation
branch has been created yet. Create `codex/ios-companion` from the fetched app
handoff branch when starting implementation. Do not reset a populated Mac
working tree to these instructions; preserve any existing changes first.

For **new sibling checkouts**:

```bash
git clone --branch codex/companion-background-foundation --recurse-submodules https://github.com/ZSWatch/ZSWatch-App.git ZSWatchApp
git clone --branch codex/companion-background-foundation https://github.com/ZSWatch/ZSWatch.git ZSWatch
cd ZSWatchApp
git switch -c codex/ios-companion
git submodule status
git rev-parse HEAD
```

Firmware submodules and the west/Nordic SDK workspace are only required when
building firmware. A Git clone alone is not a configured firmware build
environment. Follow the firmware repository's current build instructions if a
firmware change becomes necessary.

## Confirmed Mac hardware arrangement

The user will connect **the same debugger and USB rig used on Linux**. Debugger
reset and watch USB communication work on the Mac. The watch firmware development
environment is **not installed**. This is not a blocker for app development,
reset, USB SMP commands or reading logs through the available serial interface.

Reuse the same protocols and tools with Mac executables and device paths. Linux
`/dev/serial/by-id/...`, `/home/jakkra/...`, ADB and the Linux cross-compiler path
are not portable path names. The old rig's J-Link serial was `51022722`; verify
the connected probe before using it. Select the watch's CDC port separately from
the UART/log port. An iPhone uses Xcode/device tools, not ADB.

If a real firmware bug requires source changes, the agent may set up the Nordic/
Zephyr build environment itself, following the repository version/configuration,
or ask the user for help with the specific missing dependency or build step.
Do not spend time installing the full SDK merely to reset the watch. Do not
substitute an arbitrary prebuilt image for the currently working firmware.
Symbolic GDB inspection requires a matching ELF and GDB; reset and SMP do not.

## Portable test tools, including former temporary probes

The reusable portions of `/tmp/zswatch-ble-usb-reopen.py`,
`/tmp/zsw-release-usb-read.py` and the later boot-guard probes are consolidated in
`scripts/companion_hil/watch_usb.py`. It uses **smpclient**, including SMP serial
framing/escape bytes; it does not implement a new SMP protocol. The default
operation is read-only `app state`. Additional shell commands are explicit.

Create a Python 3.12 environment from the app repository root:

```bash
python3.12 -m venv .venv-watch
.venv-watch/bin/python -m pip install -r scripts/companion_hil/requirements-watch.txt
.venv-watch/bin/python -m serial.tools.list_ports -v
.venv-watch/bin/python scripts/companion_hil/watch_usb.py --help
```

First use the **actual CDC path from that inventory**, for example:

```bash
export ZSW_SMP_PORT=/dev/cu.REPLACE_WITH_WATCH_CDC
.venv-watch/bin/python scripts/companion_hil/watch_usb.py --port "$ZSW_SMP_PORT"
.venv-watch/bin/python scripts/companion_hil/watch_usb.py --port "$ZSW_SMP_PORT" -- help
.venv-watch/bin/python scripts/companion_hil/watch_usb.py --port "$ZSW_SMP_PORT" -- voice_memo status
```

If the port is absent because USB timed out, prepare Python and identify the
expected CDC path **before** reset. The current firmware's USB boot guard is
20 seconds (`app/src/managers/zsw_usb_manager.c`). Opening serial with DTR asserted
and keeping it open across the guard retains USB. The tool opens as soon as the
port appears, sends a valid SMP command, holds it for 25 seconds and checks again.
No guessed shell escape sequence or invented keep-enabled command is necessary
for this firmware; the transport handles SMP framing and DTR handles the guard.

```bash
export ZSW_JLINK_SERIAL=51022722
.venv-watch/bin/python scripts/companion_hil/watch_usb.py --port "$ZSW_SMP_PORT" --reset jlink --probe "$ZSW_JLINK_SERIAL"
```

`--reset nrfjprog` and `--reset nrfutil` are alternatives if those tools are
installed. `jlink` searches PATH for SEGGER's `JLinkExe` or `JLink` and explicitly
selects the probe; the default target is `NRF5340_XXAA_APP`. The tool refuses reset
if the USB path already exists: try the ordinary probe first. It never retries
reset automatically and never flashes/erases firmware. This new portable wrapper
has three passing host safeguard tests, but has **not** yet been run on the Mac
rig. The underlying Linux DTR/SMP sequence was previously verified.

Other already committed reusable tools:

| Tool | Purpose and limitation |
| --- | --- |
| `scripts/companion_hil/watch_file_probe.py` | Synthetic USB filesystem/offset/reconnect fixture, cleans only its own file; not real speech or BLE proof. |
| `scripts/companion_hil/voice_speech_fixture.py` | Existing speech fixture preparation; inspect its CLI/dependencies before use. |
| `scripts/companion_hil/http_fixture.py` | Existing local HTTP test fixture; use only if the current test requires it. |
| `scripts/companion_hil/hil.py` | Original Linux/Android inventory and capture; portions need Mac/iPhone adaptation. |
| Firmware `.agent_tools/serial_capture.py` | UART capture with `--port`, `--baud` and `--seconds`; use 115200 for the current UART configuration. |
| Firmware `.agent_tools/flash_and_log.py` | Historical flash/reset plus log helper. It does not select a debugger serial. Use only after adding explicit target selection or establishing a single correct target; prefer `watch_usb.py` for bootstrap reset. |

Mac recheck update: the firmware helper now uses an explicit CLI requiring
`--port`, `--probe` and either `--flash EXISTING.hex` or `--reset`. `--help` and
invalid invocations cannot open ports or execute a debugger. It requires
`nrfjprog` (currently absent on this Mac); use `watch_usb.py` and the installed
SEGGER Commander for Mac bootstrap reset. See `IOS_MAC_BASELINE.md` for the
verified UART/SMP and debugger inventory and remaining firmware-build limits.

Hundreds of one-off Android UI scripts, private recordings, raw logs/screenshots,
model weights, virtual environments and local build outputs are not a portable
source deliverable and are not uploaded. The source-controlled helpers above
replace the temporary scripts needed for watch access. Historical GDB scripts
that hard-code an ELF path or memory address are not reusable on a new firmware
build. Generate a targeted script against the actual matching ELF if needed.

## Source status and verification limits

App voice controls were committed as `67976ef` after 28 affected Flutter tests,
native job/policy tests, static analysis and a release build passed on Linux.
No physical phone test was run during this handoff. See
`ANDROID_FEATURE_PARITY.md` for still-open product parity items; publication
does not establish their completion. The iOS plan intentionally requires an
independent feature inventory rather than copying Android gaps.

Unrelated local app experiments/assets and firmware website/hardware/CI work
remain outside this handoff. They were neither reset nor swept into these
commits. The companion source, dependency revisions, plans and required watch
access tools are the scope being published. The working directories as a whole
are therefore not promised to be clean.

For each of the four repositories, verify publication with:

```bash
git rev-parse HEAD
git ls-remote origin refs/heads/codex/companion-background-foundation
```

Use `refs/heads/codex/companion-handoff` for the two library repositories. In the
Mac app checkout, detached submodule HEADs are normal; compare their hashes with
the app gitlinks rather than switching them to a moving branch. No force push,
merge into main or App Store publication is part of this handoff.
