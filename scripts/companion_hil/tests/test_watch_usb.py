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

    def test_reboot_holds_past_boot_guard_and_excludes_debugger_reset(self):
        args = watch_usb.arguments(['--port', '/dev/cu.example', '--reboot'])
        self.assertTrue(args.reboot)
        self.assertEqual(args.hold_seconds, 25)
        for extra in [['--hold-seconds', '1'], ['--reset', 'nrfjprog', '--probe', '123']]:
            with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
                watch_usb.arguments(['--port', '/dev/cu.example', '--reboot', *extra])

    def test_existing_usb_rejects_reset_before_starting_debugger(self):
        import asyncio
        args = watch_usb.arguments(['--port', __file__, '--reset', 'nrfjprog', '--probe', '123'])
        with patch('watch_usb.asyncio.create_subprocess_exec') as start:
            with self.assertRaisesRegex(RuntimeError, 'USB already exists'):
                asyncio.run(watch_usb.run(args))
            start.assert_not_called()

    def test_macos_java_launcher_is_not_a_debugger(self):
        args = watch_usb.arguments(['--port', '/dev/cu.example', '--reset', 'jlink', '--probe', '123'])
        with patch.object(watch_usb.sys, 'platform', 'darwin'), \
                patch.object(watch_usb.shutil, 'which', side_effect=[None, '/usr/bin/JLink']):
            with self.assertRaisesRegex(RuntimeError, 'SEGGER'):
                watch_usb.reset_command(args, '/tmp')

    def test_segger_commander_selects_probe_and_only_resets(self):
        import tempfile
        args = watch_usb.arguments(['--port', '/dev/cu.example', '--reset', 'jlink', '--probe', '123'])
        with tempfile.TemporaryDirectory() as directory:
            with patch.object(watch_usb.shutil, 'which', return_value='/opt/SEGGER/JLinkExe'):
                command = watch_usb.reset_command(args, directory)
            self.assertEqual(command[:5], ['/opt/SEGGER/JLinkExe', '-SelectEmuBySN', '123', '-Device', 'NRF5340_XXAA_APP'])
            self.assertEqual(Path(command[-1]).read_text(), 'r\ng\nexit\n')


if __name__ == '__main__':
    unittest.main()
