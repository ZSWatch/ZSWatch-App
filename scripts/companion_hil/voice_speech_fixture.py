#!/usr/bin/env python3
"""Create owned, decodable speech fixtures; these are not microphone recordings.

Uses installed eSpeak NG and libopus, and optionally the existing USB SMP client.
Never replaces or deletes a watch recording. Keep the manifest for later cleanup.
Stop the phone companion before USB upload: a recording can be listed while it
is still being written, causing automatic BLE download to compete with USB SMP.
"""
import argparse
import asyncio
import ctypes as c
import hashlib
import json
from pathlib import Path
import struct
import subprocess
import time
import uuid
import wave

from smpclient.requests.file_management import FileDownload, FileStatus, FileUpload
from watch_file_probe import checked, client, missing, shell
from hil import resource_locks


def generate(output, language, text):
    output.mkdir(parents=True, exist_ok=False)
    speech = c.CDLL('libespeak-ng.so.1')
    speech.espeak_Initialize.argtypes = [c.c_int, c.c_int, c.c_char_p, c.c_int]
    rate = speech.espeak_Initialize(2, 0, None, 0x8000)
    if rate <= 0:
        raise RuntimeError('eSpeak NG initialization failed')
    chunks = []
    callback_type = c.CFUNCTYPE(c.c_int, c.POINTER(c.c_short), c.c_int, c.c_void_p)

    @callback_type
    def receive(samples, count, events):
        if samples and count:
            chunks.append(c.string_at(samples, count * 2))
        return 0

    speech.espeak_SetSynthCallback.argtypes = [callback_type]
    speech.espeak_SetSynthCallback(receive)
    speech.espeak_SetVoiceByName.argtypes = [c.c_char_p]
    if speech.espeak_SetVoiceByName(language.encode()) != 0:
        raise RuntimeError('Requested eSpeak voice unavailable')
    speech.espeak_Synth.argtypes = [c.c_char_p, c.c_size_t, c.c_uint, c.c_int,
                                   c.c_uint, c.c_uint, c.c_void_p, c.c_void_p]
    raw = text.encode('utf-8')
    if speech.espeak_Synth(raw, len(raw) + 1, 0, 1, 0, 1, None, None) != 0:
        raise RuntimeError('Speech synthesis failed')
    speech.espeak_Terminate()
    with wave.open(str(output / 'speech.wav'), 'wb') as wav:
        wav.setparams((1, 2, rate, 0, 'NONE', 'not compressed'))
        wav.writeframes(b''.join(chunks))
    pcm = subprocess.check_output(['ffmpeg', '-v', 'error', '-i', str(output / 'speech.wav'),
                                  '-f', 's16le', '-ar', '16000', '-ac', '1', '-'])
    # A short leading/trailing silence makes fixture boundaries reproducible.
    pcm = bytes(16000) + pcm + bytes(16000)
    pcm += bytes((-len(pcm)) % 320)
    opus = c.CDLL('libopus.so.0')
    opus.opus_encoder_create.argtypes = [c.c_int, c.c_int, c.c_int, c.POINTER(c.c_int)]
    opus.opus_encoder_create.restype = c.c_void_p
    opus.opus_encode.argtypes = [c.c_void_p, c.POINTER(c.c_short), c.c_int,
                                c.POINTER(c.c_ubyte), c.c_int]
    opus.opus_encoder_destroy.argtypes = [c.c_void_p]
    error = c.c_int()
    encoder = opus.opus_encoder_create(16000, 1, 2048, c.byref(error))
    if not encoder or error.value != 0:
        raise RuntimeError('Opus encoder unavailable')
    frames = []
    try:
        for offset in range(0, len(pcm), 320):
            samples = (c.c_short * 160).from_buffer_copy(pcm[offset:offset + 320])
            data = (c.c_ubyte * 1275)()
            length = opus.opus_encode(encoder, samples, 160, data, len(data))
            if length <= 0:
                raise RuntimeError('Opus encoding failed')
            frames.append(struct.pack('<H', length) + bytes(data[:length]))
    finally:
        opus.opus_encoder_destroy(encoder)
    stem = 'hil_ai_' + uuid.uuid4().hex[:12]
    timestamp = int(time.time())
    payload = struct.pack('<4sHHHHIIIII', b'ZSWO', 1, 16000, 160, 0, 32000,
                          timestamp, len(frames), len(frames) * 10, 0) + b''.join(frames)
    (output / 'speech.zsw_opus').write_bytes(payload)
    manifest = dict(kind='synthesized_speech_not_microphone', language=language, text=text,
                    stem=stem, remote_path=f'/user/recordings/{stem}.zsw_opus',
                    timestamp=timestamp, duration_ms=len(frames) * 10,
                    bytes=len(payload), sha256=hashlib.sha256(payload).hexdigest())
    (output / 'manifest.json').write_text(json.dumps(manifest, indent=2))
    return manifest, payload


async def upload(port, output, manifest, payload):
    async with client(port) as connection:
        if 'Recording: no' not in await shell(connection, 'voice_memo', 'status'):
            raise RuntimeError('Watch is recording; fixture upload refused')
        name = manifest['remote_path']
        if not missing(await connection.request(FileStatus(name=name))):
            raise RuntimeError('Fixture path is not confirmed absent')
        for offset in range(0, len(payload), 256):
            part = payload[offset:offset + 256]
            reply = await checked(connection, FileUpload(name=name, off=offset,
                                                        data=part, len=len(payload)))
            if reply.off != offset + len(part):
                raise RuntimeError('Unexpected upload offset')
            # Pace the Mac CDC fixture path; this is separate from measured
            # production BLE transfers through the Nordic SDK.
            await asyncio.sleep(0.02)
        reply = await checked(connection, FileStatus(name=name))
        if reply.len != len(payload):
            raise RuntimeError('Fixture upload size differs')
        readback = bytearray()
        while len(readback) < len(payload):
            reply = await checked(connection, FileDownload(name=name, off=len(readback)))
            if reply.off != len(readback) or not reply.data:
                raise RuntimeError('Fixture readback offset or chunk differs')
            readback.extend(reply.data)
        if bytes(readback) != payload:
            raise RuntimeError('Fixture upload readback differs')
        manifest['usb_upload_verified_size'] = len(readback)
        manifest['usb_upload_verified_sha256'] = hashlib.sha256(readback).hexdigest()
        (output / 'manifest.json').write_text(json.dumps(manifest, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--language', choices=['sv', 'en'], required=True)
    parser.add_argument('--text', required=True)
    parser.add_argument('--watch-smp', type=Path)
    args = parser.parse_args()
    manifest, payload = generate(args.output, args.language, args.text)
    if args.watch_smp:
        with resource_locks(['smp:' + str(args.watch_smp.resolve())]):
            asyncio.run(upload(args.watch_smp, args.output, manifest, payload))
    print(json.dumps(manifest, indent=2))
