#!/usr/bin/env python3
"""Explicit synthetic-file mutation; probes USB SMP offsets/reconnect, not BLE or audio."""

import argparse
import asyncio
import hashlib
import json
from pathlib import Path
import struct
import uuid

from smp.file_management import FS_MGMT_ERR
from smpclient import SMPClient
from smpclient.generics import success
from smpclient.requests.file_management import FileDownload, FileStatus, FileUpload
from smpclient.requests.shell_management import Execute
from smpclient.transport.serial import SMPSerialTransport

from hil import resource_locks, utc_now


def fixture_bytes():
    # Deterministic container framing only. Payload is synthetic, not decodable speech.
    count, frame_size = 160, 32
    header = struct.pack('<4sHHHHIIIII', b'ZSWO', 1, 16000, 160, 0,
                         32000, 1700000000, count, count * 10, 0)
    return header + b''.join(struct.pack('<H', frame_size) +
                             bytes((f + i) % 256 for i in range(frame_size))
                             for f in range(count))


def missing(response):
    return getattr(getattr(response, 'err', None), 'rc', None) == FS_MGMT_ERR.FILE_NOT_FOUND


def client(port):
    return SMPClient(SMPSerialTransport(exclusive=True), str(port), timeout_s=5)


async def checked(connection, request):
    response = await connection.request(request, timeout_s=5)
    if not success(response):
        raise RuntimeError(f'SMP request failed: {response}')
    return response


async def shell(connection, *argv):
    response = await checked(connection, Execute(argv=list(argv)))
    if response.ret != 0:
        raise RuntimeError(f'Shell {argv} failed: {response.o}')
    return response.o


async def probe(port, output):
    output.mkdir(mode=0o700, parents=True, exist_ok=False)
    stem = 'hil_' + uuid.uuid4().hex[:16]
    remote = f'/user/recordings/{stem}.zsw_opus'
    data = fixture_bytes()
    (output / 'fixture.zsw_opus').write_bytes(data)
    result = {'started_utc': utc_now(), 'profile': 'synthetic_usb_file_reconnect',
              'status': 'RUNNING', 'acceptance': 'NOT_RUN', 'remote_path': remote,
              'fixture_kind': 'Container framing; synthetic payload, no real audio',
              'size_bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()}
    created = False
    try:
        async with client(port) as connection:
            result['status_before'] = await shell(connection, 'voice_memo', 'status')
            if 'Recording: no' not in result['status_before']:
                raise RuntimeError('Refusing to interfere with an active recording')
            before = await connection.request(FileStatus(name=remote))
            if not missing(before):
                raise RuntimeError('Could not prove the new fixture path is absent')
            # Ownership is established by the random, confirmed-absent path.
            # Cleanup is attempted even if an upload was applied but its ACK was lost.
            created = True
            partial = await checked(connection, FileUpload(name=remote, off=0,
                                    data=data[:256], len=len(data)))
            if partial.off != 256:
                raise RuntimeError('Unexpected first upload offset')
            result['upload_interrupted_at'] = partial.off
        # Reopen USB with a new transport/client; never reset the watch.
        async with client(port) as connection:
            offset = result['upload_interrupted_at']
            while offset < len(data):
                chunk = data[offset:offset + 256]
                response = await checked(connection, FileUpload(name=remote,
                    off=offset, data=chunk, len=len(data)))
                if response.off != offset + len(chunk):
                    raise RuntimeError('Unexpected resumed upload offset')
                offset = response.off
            status = await checked(connection, FileStatus(name=remote))
            if status.len != len(data):
                raise RuntimeError('Remote file size differs after upload')
            partial = await checked(connection, FileDownload(name=remote, off=0))
            if partial.off != 0 or partial.len != len(data) or not 0 < len(partial.data) < len(data):
                raise RuntimeError('Fixture does not exercise a partial download')
            (output / 'partial.zsw_opus').write_bytes(partial.data)
            result['download_interrupted_at'] = len(partial.data)
        # A restart reads the saved prefix and resumes from its own verified offset.
        resumed = bytearray((output / 'partial.zsw_opus').read_bytes())
        async with client(port) as connection:
            while len(resumed) < len(data):
                response = await checked(connection, FileDownload(name=remote, off=len(resumed)))
                if response.off != len(resumed) or not response.data:
                    raise RuntimeError('Invalid resumed download offset or empty chunk')
                resumed.extend(response.data)
            if bytes(resumed) != data:
                raise RuntimeError('Resumed file bytes differ from original fixture')
            (output / 'resumed.zsw_opus').write_bytes(resumed)
            result['resumed_sha256'] = hashlib.sha256(resumed).hexdigest()
        result['status'] = 'TRANSFER_VERIFIED'
    except Exception as exc:
        result['status'] = 'ERROR'
        result['error'] = str(exc)
    finally:
        if created:
            try:
                async with client(port) as connection:
                    await shell(connection, 'voice_memo', 'delete', stem)
                    result['cleanup_verified'] = missing(await connection.request(FileStatus(name=remote)))
                    result['status_after'] = await shell(connection, 'voice_memo', 'status')
                    if not result['cleanup_verified']:
                        raise RuntimeError('Fixture still exists after cleanup')
                    before = result['status_before'].split('Total recordings:')[1].splitlines()[0]
                    after = result['status_after'].split('Total recordings:')[1].splitlines()[0]
                    if before != after:
                        raise RuntimeError('Recording count changed beyond the owned fixture')
            except Exception as exc:
                result['status'] = 'ERROR'
                result['cleanup_error'] = str(exc)
        result['ended_utc'] = utc_now()
        (output / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
        print(json.dumps(result, indent=2))
    return 0 if result['status'] == 'TRANSFER_VERIFIED' else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--watch-smp', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--create-fixture', action='store_true', required=True,
                        help='Explicitly allow creating and deleting this run\'s unique fixture')
    args = parser.parse_args()
    with resource_locks(['smp:' + str(args.watch_smp.resolve())]):
        return asyncio.run(probe(args.watch_smp, args.output))


if __name__ == '__main__':
    raise SystemExit(main())
