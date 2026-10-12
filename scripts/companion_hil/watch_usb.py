#!/usr/bin/env python3
"""Portable version of the Linux /tmp USB bootstrap and shell probes.

Uses smpclient's serial framing, including its SMP escape sequence. No custom SMP.
No reset unless explicitly requested; never flashes or erases firmware.
"""

import argparse
import asyncio
from pathlib import Path
import shutil
import sys
import tempfile
import time

from smpclient import SMPClient
from smpclient.generics import success
from smpclient.requests.shell_management import Execute
from smpclient.transport.serial import SMPSerialTransport


def arguments(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--port', required=True, help='Explicit USB CDC device path')
    parser.add_argument('--reset', choices=['nrfjprog', 'nrfutil', 'jlink'])
    parser.add_argument('--probe', help='Explicit debugger serial number for reset')
    parser.add_argument('--device', default='NRF5340_XXAA_APP', help='J-Link target')
    parser.add_argument('--hold-seconds', type=float, default=None)
    parser.add_argument('command', nargs=argparse.REMAINDER,
                        help='Shell argv after --; default: app state')
    args = parser.parse_args(argv)
    if args.reset and not args.probe:
        parser.error('--reset requires --probe; never reset an arbitrary target')
    if args.hold_seconds is None:
        args.hold_seconds = 25 if args.reset else 0
    if args.hold_seconds < 0:
        parser.error('--hold-seconds must be nonnegative')
    if args.reset and args.hold_seconds < 25:
        parser.error('After reset, hold USB for at least 25 seconds past the boot guard')
    if args.command[:1] == ['--']:
        args.command = args.command[1:]
    return args


def reset_command(args, directory):
    if args.reset == 'nrfjprog':
        return ['nrfjprog', '--reset', '-f', 'NRF53', '--snr', args.probe]
    if args.reset == 'nrfutil':
        return ['nrfutil', 'device', 'reset', '--serial-number', args.probe,
                '--family', 'nrf53']
    executable = shutil.which('JLinkExe')
    if not executable:
        candidate = shutil.which('JLink')
        # macOS ships a Java launcher named /usr/bin/JLink. It is not SEGGER.
        if candidate and not (sys.platform == 'darwin' and
                              Path(candidate).resolve() == Path('/usr/bin/JLink')):
            executable = candidate
    if not executable:
        raise RuntimeError('JLinkExe/JLink not on PATH; install SEGGER tools or choose another backend')
    commands = Path(directory) / 'reset.jlink'
    commands.write_text('r\ng\nexit\n')
    return [executable, '-SelectEmuBySN', args.probe, '-Device', args.device,
            '-If', 'SWD', '-Speed', '4000', '-AutoConnect', '1',
            '-ExitOnError', '1', '-CommandFile', str(commands)]


async def execute(client, command):
    response = await client.request(Execute(argv=command), timeout_s=5)
    if not success(response) or response.ret != 0:
        raise RuntimeError(f'Shell command failed: {response}')
    print(response.o, flush=True)


async def run(args):
    port = Path(args.port)
    if args.reset and port.exists():
        raise RuntimeError('USB already exists. Try without --reset first; reset is only a bootstrap action.')
    process = None
    with tempfile.TemporaryDirectory(prefix='zsw-usb-reset-') as directory:
        try:
            if args.reset:
                process = await asyncio.create_subprocess_exec(*reset_command(args, directory))
                deadline = time.monotonic() + 15
                while not port.exists():
                    if process.returncode not in (None, 0):
                        raise RuntimeError(f'Debugger reset failed: {process.returncode}')
                    if time.monotonic() >= deadline:
                        raise RuntimeError('USB did not enumerate within 15s. Check port/probe; no automatic second reset.')
                    await asyncio.sleep(0.05)
            # SMPSerialTransport opens pyserial with DTR asserted by default.
            # Keep this client open across the firmware's 20s boot guard.
            async with SMPClient(SMPSerialTransport(exclusive=True), str(port), timeout_s=5) as client:
                await execute(client, ['app', 'state'])
                if args.hold_seconds:
                    print(f'Holding USB open for {args.hold_seconds:g}s', flush=True)
                    await asyncio.sleep(args.hold_seconds)
                    await execute(client, ['app', 'state'])
                if args.command and args.command != ['app', 'state']:
                    await execute(client, args.command)
            if process is not None:
                code = await asyncio.wait_for(process.wait(), timeout=10)
                if code != 0:
                    raise RuntimeError(f'Debugger reset failed: {code}')
            print('USB SMP commands succeeded. This is not a BLE acceptance test.', flush=True)
        finally:
            if process is not None and process.returncode is None:
                process.terminate()
                await process.wait()


if __name__ == '__main__':
    asyncio.run(run(arguments()))
