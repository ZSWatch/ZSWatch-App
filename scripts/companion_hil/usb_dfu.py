#!/usr/bin/env python3
"""Install a dfu_application.zip on a watch over USB SMP and confirm it.

Uploads each selected image, checks the slot hash against the image's own
SHA-256 TLV, marks the images pending, reboots through SMP, waits for USB to
come back past the boot guard, then confirms only the images that booted.
Refuses to start while the watch is recording or already has a pending image.
Never erases flash or touches a debugger.
"""

import argparse
import asyncio
import hashlib
import json
from pathlib import Path
import struct
import time
import zipfile

from smp import packet as smppacket
from smpclient import SMPClient
from smpclient.requests.image_management import ImageStatesRead, ImageStatesWrite
from smpclient.requests.os_management import ResetWrite
from smpclient.requests.shell_management import Execute
from smpclient.transport.serial import SMPSerialTransport
from smpclient.transport.serial.encoded import BufferSize

from watch_file_probe import checked

IMAGE_MAGIC = 0x96F3B83D
TLV_INFO_MAGIC = 0x6907
TLV_SHA256 = 0x10
BOOT_GUARD_SECONDS = 25


class PacedSerial(SMPSerialTransport):
    """Paces encoded USB packets; unpaced bursts overran the watch's CDC RX."""

    def __init__(self, pace_s, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._pace_s = pace_s

    async def send(self, data):
        assert len(data) <= self.max_unencoded_size
        with self._serial_exception_to_disconnected():
            for packet in smppacket.encode(data, line_length=self._line_length):
                self._conn.write(packet)
                await asyncio.sleep(self._pace_s)
            await self._drain_tx()


def arguments(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--port', required=True, help='Explicit USB CDC SMP device path')
    parser.add_argument('--zip', required=True, type=Path, help='dfu_application.zip from the firmware build')
    parser.add_argument('--images', default='0,2',
                        help='Comma-separated manifest image_index values (default: 0,2 = app + XIP)')
    parser.add_argument('--output', type=Path, help='Directory for targets/active-images JSON (must not exist)')
    parser.add_argument('--pace', type=float, default=0.04, help='Seconds between USB packets')
    parser.add_argument('--attempts', type=int, default=5, help='Upload attempts per image')
    args = parser.parse_args(argv)
    args.images = sorted({int(i) for i in args.images.split(',') if i.strip()})
    if not args.images:
        parser.error('--images selected nothing')
    if args.attempts < 1:
        parser.error('--attempts must be at least 1')
    return args


def image_hash(data):
    """Return the MCUboot SHA-256 TLV after verifying it matches the image."""
    if len(data) < 32 or struct.unpack_from('<I', data)[0] != IMAGE_MAGIC:
        raise ValueError('Not an MCUboot image')
    header, protected, size = struct.unpack_from('<HHI', data, 8)
    end = header + size + protected
    if header < 32 or end + 4 > len(data):
        raise ValueError('Image header points outside the file')
    magic, total = struct.unpack_from('<HH', data, end)
    if magic != TLV_INFO_MAGIC or end + total > len(data):
        raise ValueError('Image TLV table missing or truncated')
    at = end + 4
    while at + 4 <= end + total:
        kind, _, length = struct.unpack_from('<BBH', data, at)
        at += 4
        if kind == TLV_SHA256:
            digest = data[at:at + length]
            if length != 32 or hashlib.sha256(data[:end]).digest() != digest:
                raise ValueError('Image SHA-256 TLV does not match its contents')
            return digest
        at += length
    raise ValueError('Image has no SHA-256 TLV')


def load_images(path, indices):
    with zipfile.ZipFile(path) as archive:
        manifest = json.loads(archive.read('manifest.json'))
        files = {int(f['image_index']): archive.read(f['file'])
                 for f in manifest['files'] if int(f['image_index']) in indices}
    if set(files) != set(indices):
        raise ValueError(f'Manifest lacks image indices {sorted(set(indices) - set(files))}')
    return files


def has_image(states, index, digest, **flags):
    return any(s.image == index and s.hash == digest and
               all(getattr(s, k) == v for k, v in flags.items()) for s in states.images)


async def wait_for_port(port, present, timeout):
    deadline = time.monotonic() + timeout
    while port.exists() != present:
        if time.monotonic() >= deadline:
            raise TimeoutError(f'USB {"did not return" if present else "did not drop"} within {timeout}s')
        await asyncio.sleep(0.03)


async def run(args):
    port = Path(args.port)

    def client():
        return SMPClient(PacedSerial(args.pace, BufferSize(buf_size=256), exclusive=True), str(port), timeout_s=8)

    files = load_images(args.zip, args.images)
    hashes = {i: image_hash(b) for i, b in files.items()}
    if args.output:
        args.output.mkdir(parents=True, exist_ok=False)
        (args.output / 'targets.json').write_text(json.dumps(
            {str(i): {'bytes': len(files[i]), 'hash': h.hex()} for i, h in hashes.items()}, indent=2))

    async with client() as c:
        status = await checked(c, Execute(argv=['voice_memo', 'status']))
        if status.ret != 0 or 'Recording: no' not in status.o:
            raise RuntimeError('Watch is recording or status failed; not updating')
        before = await checked(c, ImageStatesRead())
        if any(s.pending for s in before.images):
            raise RuntimeError('An image is already pending; resolve it before installing')

    for index, data in files.items():
        for attempt in range(1, args.attempts + 1):
            try:
                async with client() as c:
                    print(json.dumps({'stage': 'upload', 'index': index, 'bytes': len(data), 'attempt': attempt}), flush=True)
                    last = 0
                    async for offset in c.upload(data, slot=index, upgrade=False, subsequent_timeout_s=12):
                        if offset - last >= 100000 or offset == len(data):
                            print(json.dumps({'index': index, 'ack_bytes': offset}), flush=True)
                            last = offset
                        await asyncio.sleep(args.pace)
                break
            except TimeoutError:
                # Image upload resumes from the watch's offset, so a retry is idempotent.
                print(json.dumps({'stage': 'resume', 'index': index, 'attempt': attempt}), flush=True)
                if attempt == args.attempts:
                    raise

    async with client() as c:
        states = await checked(c, ImageStatesRead())
        for index, digest in hashes.items():
            if not has_image(states, index, digest):
                raise RuntimeError(f'Image {index} hash not found on the watch after upload')
        for digest in hashes.values():
            await checked(c, ImageStatesWrite(hash=digest, confirm=False))
        print('Images pending; rebooting through SMP', flush=True)
        await checked(c, ResetWrite())

    await wait_for_port(port, False, 20)
    await wait_for_port(port, True, 90)

    async with client() as c:
        await checked(c, Execute(argv=['app', 'state']))
        # Keep USB open past the firmware's boot guard before confirming.
        await asyncio.sleep(BOOT_GUARD_SECONDS)
        states = await checked(c, ImageStatesRead())
        for index, digest in hashes.items():
            if not has_image(states, index, digest, active=True):
                raise RuntimeError(f'Image {index} did not boot; MCUboot kept the previous image')
            if not has_image(states, index, digest, active=True, confirmed=True):
                await checked(c, ImageStatesWrite(hash=digest, confirm=True))
        states = await checked(c, ImageStatesRead())
        summary = [{'index': s.image, 'active': s.active, 'confirmed': s.confirmed, 'hash': s.hash.hex()}
                   for s in states.images]
        if args.output:
            (args.output / 'active-images.json').write_text(json.dumps(summary, indent=2))
        print(json.dumps({'stage': 'confirmed', 'images': summary}), flush=True)


if __name__ == '__main__':
    asyncio.run(run(arguments()))
