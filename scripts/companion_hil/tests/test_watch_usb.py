"""No hardware access: explicit targeting and bootstrap safeguards."""
import contextlib
import io
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
try:
    import watch_usb
except ModuleNotFoundError as error:
    if error.name not in ('smpclient', 'smp'):
        raise
    raise unittest.SkipTest('Install requirements-watch.txt for USB tool tests') from error


class WatchUsbTests(unittest.TestCase):
    def test_normal_probe_does_not_reset_or_wait(self):
        args = watch_usb.arguments(['--port', '/dev/cu.example', '--', 'app', 'state'])
        self.assertIsNone(args.reset)
        self.assertEqual(args.hold_seconds, 0)
        self.assertEqual(args.command, ['app', 'state'])

    def test_reset_requires_explicit_probe_and_boot_guard(self):
        for extra in [[], ['--probe', '123', '--hold-seconds', '1']]:
            with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
                watch_usb.arguments(['--port', '/dev/cu.example', '--reset', 'nrfjprog', *extra])
        args = watch_usb.arguments(['--port', '/dev/cu.example', '--reset', 'nrfjprog', '--probe', '123'])
        self.assertEqual(args.hold_seconds, 25)
        self.assertEqual(watch_usb.reset_command(args, '/tmp'),
                         ['nrfjprog', '--reset', '-f', 'NRF53', '--snr', '123'])

    def test_existing_usb_rejects_reset_before_starting_debugger(self):
        import asyncio
        args = watch_usb.arguments(['--port', __file__, '--reset', 'nrfjprog', '--probe', '123'])
        with patch('watch_usb.asyncio.create_subprocess_exec') as start:
            with self.assertRaisesRegex(RuntimeError, 'USB already exists'):
                asyncio.run(watch_usb.run(args))
            start.assert_not_called()


if __name__ == '__main__':
    unittest.main()
