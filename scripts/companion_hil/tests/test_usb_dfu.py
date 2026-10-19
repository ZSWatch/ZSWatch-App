"""No hardware access: image hash verification and manifest selection."""
import contextlib
import hashlib
import io
import json
import struct
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
try:
    import usb_dfu
except ModuleNotFoundError as error:
    if error.name not in ('smpclient', 'smp'):
        raise
    raise unittest.SkipTest('Install requirements-watch.txt for USB tool tests') from error


def image(body=b'firmware', digest=None):
    header = struct.pack('<IIHHI', usb_dfu.IMAGE_MAGIC, 0, 32, 0, len(body)).ljust(32, b'\0')
    signed = header + body
    digest = digest or hashlib.sha256(signed).digest()
    tlv = struct.pack('<BBH', usb_dfu.TLV_SHA256, 0, 32) + digest
    return signed + struct.pack('<HH', usb_dfu.TLV_INFO_MAGIC, 4 + len(tlv)) + tlv


class UsbDfuTests(unittest.TestCase):
    def test_hash_matches_image_contents(self):
        data = image()
        self.assertEqual(usb_dfu.image_hash(data), hashlib.sha256(data[:40]).digest())

    def test_rejects_tampered_or_truncated_images(self):
        for data in [image(digest=b'\1' * 32), image()[:36], b'not an image' * 4]:
            with self.assertRaises(ValueError):
                usb_dfu.image_hash(data)

    def test_loads_only_selected_manifest_images(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'dfu_application.zip'
            with zipfile.ZipFile(path, 'w') as archive:
                files = [{'image_index': str(i), 'file': f'{i}.bin'} for i in (0, 1, 2)]
                archive.writestr('manifest.json', json.dumps({'files': files}))
                for i in (0, 1, 2):
                    archive.writestr(f'{i}.bin', bytes([i]))
            self.assertEqual(usb_dfu.load_images(path, [0, 2]), {0: b'\0', 2: b'\2'})
            with self.assertRaisesRegex(ValueError, r'\[3\]'):
                usb_dfu.load_images(path, [0, 3])

    def test_image_selection_parsing(self):
        args = usb_dfu.arguments(['--port', '/dev/x', '--zip', 'a.zip', '--images', '2, 0,2'])
        self.assertEqual(args.images, [0, 2])
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
            usb_dfu.arguments(['--port', '/dev/x', '--zip', 'a.zip', '--images', ','])


if __name__ == '__main__':
    unittest.main()
