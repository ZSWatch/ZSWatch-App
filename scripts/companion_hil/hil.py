#!/usr/bin/env python3
"""Read-only Android lab inventory and bounded UART/logcat capture.

No install, launch, pairing, BLE connection, flash, recover or reset commands.
The manifest describes observations, never companion acceptance results.
"""

import argparse
import contextlib
import datetime as dt
import hashlib
import json
import math
import os
from pathlib import Path
import platform
import selectors
import shutil
import stat
import subprocess
import sys
import tempfile
import threading
import time


def utc_now():
    return dt.datetime.now(dt.timezone.utc).isoformat()


def run(argv, timeout=10):
    result = subprocess.run(argv, capture_output=True, text=True, timeout=timeout)
    if result.returncode:
        raise RuntimeError(f"{argv[0]} exited {result.returncode}: {result.stderr.strip()}")
    return result.stdout


def file_hash(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def repository(path, diff_output=None):
    def git(*args):
        return run(["git", "-C", str(path), *args])
    # Hash both tracked diffs. Untracked content is listed, never recursively read
    # (there are local models, keys and build trees in the development checkouts).
    diff = git("diff", "HEAD", "--binary", "--no-ext-diff")
    if diff_output is not None:
        diff_output.write_text(diff)
    return {
        "path": str(path.resolve()),
        "revision": git("rev-parse", "HEAD").strip(),
        "branch": git("branch", "--show-current").strip(),
        "status": git("status", "--porcelain=v1", "--untracked-files=normal").splitlines(),
        "tracked_diff_sha256": hashlib.sha256(diff.encode()).hexdigest(),
        "tracked_diff_file": str(diff_output) if diff_output is not None else None,
        "submodules": git("submodule", "status").splitlines(),
        "provenance_limit": "Inventory only: untracked/submodule contents and deployed binaries are not attested",
    }


def parse_devices(output):
    devices = []
    for line in output.splitlines():
        columns = line.split()
        if len(columns) < 2 or columns[0] == "List" or line.startswith("*"):
            continue
        metadata = dict(c.split(":", 1) for c in columns[2:] if ":" in c)
        devices.append({"serial": columns[0], "state": columns[1], **metadata})
    return devices


def selected_device(devices, serial):
    if not serial:
        return None
    return next((d for d in devices if d["serial"] == serial), None)


def inspect_lab(args):
    blockers = []
    adb = shutil.which("adb")
    devices = parse_devices(run([adb, "devices", "-l"])) if adb else []
    phone = selected_device(devices, args.android_serial)
    if not adb:
        blockers.append("adb not installed")
    if not args.android_serial:
        blockers.append("No Android phone explicitly selected (--android-serial)")
    elif not phone or phone["state"] != "device":
        blockers.append("Selected phone absent, offline or unauthorized")
    elif phone.get("serial", "").startswith("emulator-"):
        blockers.append("A physical Android phone is required for companion BLE acceptance")
    else:
        phone = dict(phone)
        phone["properties"] = {
            key: run([adb, "-s", args.android_serial, "shell", "getprop", key]).strip()
            for key in ("ro.product.model", "ro.build.version.release", "ro.build.version.sdk")
        }
        phone["package_dump"] = run([
            adb, "-s", args.android_serial, "shell", "dumpsys", "package", "com.zswatch.app"
        ])
        if "versionName=" not in phone["package_dump"]:
            blockers.append("com.zswatch.app is not installed on the selected phone")
    ports = {}
    for name in ("watch_uart", "watch_smp"):
        value = getattr(args, name)
        ports[name] = str(Path(value).resolve()) if value else None
        if not value or not Path(value).exists():
            blockers.append(f"Missing explicit existing {name} port")
        elif not stat.S_ISCHR(Path(value).stat().st_mode):
            blockers.append(f"{name} is not a character device")
        elif not os.access(value, os.R_OK | os.W_OK):
            blockers.append(f"No access to {name} port")
    if ports["watch_uart"] and ports["watch_uart"] == ports["watch_smp"]:
        blockers.append("UART log port and USB SMP control port must be separate")
    artifacts = {}
    for name in ("firmware", "apk"):
        value = getattr(args, name)
        artifacts[name] = {"path": str(Path(value).resolve()), "sha256": file_hash(value)} if value else None
    output = getattr(args, "output", None)
    return {
        "schema_version": 1, "created_utc": utc_now(), "profile": "read_only_inventory",
        "status": "BLOCKED" if blockers else "READY_FOR_PROBE", "blockers": blockers,
        "host": {"system": platform.system(), "python": sys.version.split()[0]},
        "repositories": {
            "app": repository(args.app_repo, output / "app-tracked.patch" if output else None),
            "watch": repository(args.watch_repo, output / "watch-tracked.patch" if output else None),
        },
        "tools": {name: shutil.which(name) for name in ("adb", "flutter", "west", "nrfutil", "JLinkExe")},
        "android_devices": devices, "selected_phone": phone,
        "serial_inventory": sorted(str(p) for p in Path("/dev/serial/by-id").glob("*")),
        "selected_ports": ports, "artifacts": artifacts,
        "unverified": ["Watch identity/revision and running firmware", "Bond/association and app permissions",
                       "USB SMP responsiveness", "BLE connection", "Actual deployed artifact hashes"],
        "scenario_results": [],
        "acceptance": "NOT_RUN",
    }


@contextlib.contextmanager
def resource_locks(resources, directory=None):
    """Cooperative Linux locks; serial exclusivity additionally protects the UART."""
    import fcntl
    root = Path(directory or Path(tempfile.gettempdir()) / f"zswatch-hil-locks-{os.getuid()}")
    root.mkdir(mode=0o700, exist_ok=True)
    handles = []
    try:
        for resource in sorted(set(resources)):
            name = hashlib.sha256(resource.encode()).hexdigest() + ".lock"
            fd = os.open(root / name, os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
            handles.append(fd)
            try:
                fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError as exc:
                raise RuntimeError(f"Resource already in use: {resource}") from exc
        yield
    finally:
        for fd in reversed(handles):
            os.close(fd)


def capture(args):
    if platform.system() != "Linux":
        raise RuntimeError("This capture adapter currently requires Linux")
    import serial
    if not args.watch_uart or not Path(args.watch_uart).exists():
        raise RuntimeError("An existing explicit --watch-uart is required")
    adb = shutil.which("adb")
    if not args.watch_only:
        if not adb or not args.android_serial:
            raise RuntimeError("Select --android-serial or explicitly request --watch-only")
        phone = selected_device(parse_devices(run([adb, "devices", "-l"])), args.android_serial)
        if not phone or phone["state"] != "device" or args.android_serial.startswith("emulator-"):
            raise RuntimeError("Selected physical phone is not accessible")
    resources = ["uart:" + str(Path(args.watch_uart).resolve())]
    if not args.watch_only:
        resources.append("adb:" + args.android_serial)
    with resource_locks(resources):
        args.output.mkdir(mode=0o700, parents=True, exist_ok=False)
        summary = {"schema_version": 1, "profile": "watch_only_capture" if args.watch_only else "phone_watch_capture",
                   "started_utc": utc_now(), "status": "RUNNING", "acceptance": "NOT_RUN",
                   "android_serial": args.android_serial if not args.watch_only else None,
                   "watch_uart": str(Path(args.watch_uart).resolve()), "uart_bytes": 0,
                   "duration_requested_s": args.duration, "timestamp_basis": "Host receipt UTC and monotonic_ns; device clocks are independent"}
        phone_proc = None
        phone_file = None
        threads = []
        stop = threading.Event()
        write_lock = threading.Lock()
        errors = []
        try:
            with (args.output / "timeline.jsonl").open("w") as timeline, \
                    (args.output / "watch-uart.bin").open("wb") as raw, \
                    (args.output / "watch-uart.log").open("w") as uart_log:
                def event(source, data):
                    with write_lock:
                        record = {"utc": utc_now(), "monotonic_ns": time.monotonic_ns(),
                                  "source": source, "text": data.decode(errors="replace")}
                        timeline.write(json.dumps(record, ensure_ascii=False) + "\n")
                        timeline.flush()

                # Set modem lines before opening; never write commands or clear
                # the UART buffers. Physical line wiring still needs lab validation.
                uart = serial.Serial(port=None, baudrate=115200, timeout=0.2, exclusive=True)
                uart.dtr = False
                uart.rts = False
                uart.port = args.watch_uart
                with uart:
                    def read_uart():
                        try:
                            while not stop.is_set():
                                data = uart.read(4096)
                                if data:
                                    raw.write(data)
                                    raw.flush()
                                    uart_log.write(data.decode(errors="replace"))
                                    uart_log.flush()
                                    summary["uart_bytes"] += len(data)
                                    event("watch_uart", data)
                        except Exception as exc:
                            errors.append(str(exc))
                            stop.set()

                    threads.append(threading.Thread(target=read_uart))
                    if not args.watch_only:
                        phone_file = (args.output / "phone.log").open("wb")
                        phone_proc = subprocess.Popen([adb, "-s", args.android_serial, "logcat", "-v", "epoch", "-T", "1"],
                                                      stdout=subprocess.PIPE, stderr=subprocess.STDOUT)

                        def read_phone():
                            try:
                                with selectors.DefaultSelector() as selector:
                                    selector.register(phone_proc.stdout, selectors.EVENT_READ)
                                    while not stop.is_set():
                                        if not selector.select(timeout=0.2):
                                            continue
                                        data = os.read(phone_proc.stdout.fileno(), 4096)
                                        if not data:
                                            if not stop.is_set():
                                                errors.append("logcat ended before capture deadline")
                                                stop.set()
                                            break
                                        phone_file.write(data)
                                        phone_file.flush()
                                        event("phone_logcat", data)
                            except Exception as exc:
                                errors.append(str(exc))
                                stop.set()
                            finally:
                                phone_file.close()

                        threads.append(threading.Thread(target=read_phone))
                    for thread in threads:
                        thread.start()
                    event("collector", b"capture_started")
                    try:
                        stop.wait(args.duration)
                    finally:
                        stop.set()
                        if phone_proc is not None:
                            phone_proc.terminate()
                            try:
                                phone_proc.wait(timeout=3)
                            except subprocess.TimeoutExpired:
                                phone_proc.kill()
                                phone_proc.wait(timeout=3)
                        for thread in threads:
                            thread.join(timeout=3)
                        if any(thread.is_alive() for thread in threads):
                            errors.append("Collector failed to stop")
                        if phone_proc is not None:
                            phone_proc.stdout.close()
                        event("collector", b"capture_stopped")
            summary["status"] = "ERROR" if errors else "COLLECTED"
        except KeyboardInterrupt:
            summary["status"] = "INTERRUPTED"
            raise
        except Exception as exc:
            errors.append(str(exc))
            summary["status"] = "ERROR"
            raise
        finally:
            if phone_file is not None:
                phone_file.close()
            summary["ended_utc"] = utc_now()
            summary["errors"] = errors
            summary["uart_observation"] = "DATA" if summary["uart_bytes"] else "NO_DATA"
            (args.output / "capture.json").write_text(json.dumps(summary, indent=2) + "\n")
        if errors:
            raise RuntimeError("; ".join(errors))
        return summary


def positive_duration(value):
    duration = float(value)
    if not math.isfinite(duration) or duration <= 0:
        raise argparse.ArgumentTypeError("duration must be positive and finite")
    return duration


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    preflight = commands.add_parser("preflight", help="Inventory only; missing equipment returns BLOCKED/exit 2")
    app_repo = Path(__file__).resolve().parents[2]
    preflight.add_argument("--app-repo", type=Path, default=app_repo)
    preflight.add_argument("--watch-repo", type=Path, default=app_repo.parent / "ZSWatch")
    preflight.add_argument("--watch-smp")
    preflight.add_argument("--firmware", type=Path)
    preflight.add_argument("--apk", type=Path)
    collector = commands.add_parser("capture", help="Receive UART/logcat only; no acceptance assertions")
    collector.add_argument("--watch-only", action="store_true")
    collector.add_argument("--duration", type=positive_duration, default=60)
    for command in (preflight, collector):
        command.add_argument("--android-serial")
        command.add_argument("--watch-uart")
        command.add_argument("--output", type=Path, required=True, help="New output directory (never overwrite)")
    args = parser.parse_args()
    created_output = False
    try:
        if args.command == "preflight":
            args.output.mkdir(mode=0o700, parents=True, exist_ok=False)
            created_output = True
            manifest = inspect_lab(args)
            (args.output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
            print(json.dumps({"status": manifest["status"], "blockers": manifest["blockers"], "output": str(args.output)}))
            return 2 if manifest["blockers"] else 0
        summary = capture(args)
        print(json.dumps({"status": summary["status"], "uart_bytes": summary["uart_bytes"], "output": str(args.output)}))
        return 0
    except (OSError, RuntimeError, subprocess.TimeoutExpired, ImportError) as exc:
        if created_output:
            (args.output / "manifest.json").write_text(json.dumps({
                "schema_version": 1, "created_utc": utc_now(), "profile": "read_only_inventory",
                "status": "ERROR", "error": str(exc), "acceptance": "NOT_RUN", "scenario_results": [],
            }, indent=2) + "\n")
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
