#!/usr/bin/env python3
"""Capture a USB-connected iPhone's system log, keeping chosen processes.

Wraps `pymobiledevice3 syslog live` (pip install pymobiledevice3; no sudo,
unlike `log collect`). The phone still streams its whole log (~30k lines/s),
so this runs once and never restarts: an automatic restart loop after a dropped
stream left the phone sluggish. Start it right before reproducing, stop it
(Ctrl-C or --seconds) right after.

The default processes cover the app and Bluetooth/AccessorySetupKit pairing.
"""

import argparse
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

DEFAULT_PROCESSES = ['Runner', 'bluetoothd', 'deviceaccessd', 'AccessorySetupUI']
LINE = re.compile(r'^\S+ \S+ ([^\s{\[]+)[{\[]')


def arguments(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True, help='Log file to write (must not exist)')
    parser.add_argument('--process', action='append', dest='processes',
                        help=f'Process to keep; repeatable (default: {", ".join(DEFAULT_PROCESSES)})')
    parser.add_argument('--all', action='store_true', help='Keep every process (large files)')
    parser.add_argument('--seconds', type=float, help='Stop after this long')
    parser.add_argument('--tool', default=shutil.which('pymobiledevice3') or 'pymobiledevice3',
                        help='pymobiledevice3 executable')
    args = parser.parse_args(argv)
    if args.all and args.processes:
        parser.error('--all and --process are alternatives')
    if not args.all and not args.processes:
        args.processes = DEFAULT_PROCESSES
    return args


def keep(line, processes):
    if processes is None:
        return True
    match = LINE.match(line)
    # Continuation lines of multi-line entries have no header; keep them with
    # the entry only when the previous header matched (handled by the caller).
    return match.group(1) in processes if match else None


def run(args):
    if args.output.exists():
        raise SystemExit(f'{args.output} exists; choose a new file')
    processes = None if args.all else set(args.processes)
    deadline = time.monotonic() + args.seconds if args.seconds else None
    process = subprocess.Popen([args.tool, 'syslog', 'live'], stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, text=True, errors='replace')
    kept = total = 0
    previous = False
    try:
        with args.output.open('w') as output:
            for line in process.stdout:
                total += 1
                decision = keep(line, processes)
                previous = previous if decision is None else decision
                if previous or 'pymobiledevice3' in line:
                    output.write(line)
                    kept += 1
                if deadline and time.monotonic() >= deadline:
                    break
    except KeyboardInterrupt:
        pass
    finally:
        process.terminate()
        process.wait()
    print(f'Kept {kept} of {total} lines in {args.output}', file=sys.stderr)
    if process.returncode not in (0, -15) and not deadline:
        print('Stream ended on its own (USB drop?). Not restarting.', file=sys.stderr)


if __name__ == '__main__':
    run(arguments())
