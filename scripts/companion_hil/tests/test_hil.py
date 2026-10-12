import argparse
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import threading
import time
import unittest
from unittest.mock import patch


spec = importlib.util.spec_from_file_location("hil", Path(__file__).parents[1] / "hil.py")
hil = importlib.util.module_from_spec(spec)
spec.loader.exec_module(hil)


class InventoryTests(unittest.TestCase):
    def test_states_remain_distinct_and_nothing_is_auto_selected(self):
        devices = hil.parse_devices("List of devices attached\na unauthorized usb:1\nb offline\nc device model:Pixel\n")
        self.assertEqual([d["state"] for d in devices], ["unauthorized", "offline", "device"])
        self.assertIsNone(hil.selected_device(devices, None))
        self.assertIsNone(hil.selected_device(devices, "other"))

    def test_missing_phone_is_blocked_with_no_acceptance_results(self):
        args = argparse.Namespace(android_serial=None, watch_uart=None, watch_smp=None,
                                  firmware=None, apk=None, app_repo=Path("."), watch_repo=Path("."))
        def readonly(argv, **kwargs):
            self.assertEqual(argv, ["/fake/adb", "devices", "-l"])
            return "List of devices attached\n"
        with patch.object(hil.shutil, "which", return_value="/fake/adb"), \
                patch.object(hil, "run", side_effect=readonly), \
                patch.object(hil, "repository", return_value={}):
            result = hil.inspect_lab(args)
        self.assertEqual(result["status"], "BLOCKED")
        self.assertEqual(result["acceptance"], "NOT_RUN")
        self.assertEqual(result["scenario_results"], [])

    def test_lock_collision_and_release_after_failure(self):
        with tempfile.TemporaryDirectory() as temp:
            with hil.resource_locks(["phone:a", "uart:b"], temp):
                with self.assertRaisesRegex(RuntimeError, "already in use"):
                    with hil.resource_locks(["uart:b"], temp):
                        self.fail("must not enter")
            with hil.resource_locks(["uart:b"], temp):
                pass

    def test_nonfinite_or_negative_capture_duration_rejected(self):
        for value in ("0", "-1", "nan", "inf"):
            with self.assertRaises(argparse.ArgumentTypeError):
                hil.positive_duration(value)


@unittest.skipUnless(os.name == "posix", "PTY collector tests require POSIX")
class CaptureTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.master, self.slave = os.openpty()
        self.addCleanup(os.close, self.master)
        self.addCleanup(os.close, self.slave)
        self.args = argparse.Namespace(output=self.root / "run", watch_uart=os.ttyname(self.slave),
                                       android_serial=None, watch_only=True, duration=0.4)

    def test_passive_uart_capture_preserves_bytes_and_marks_no_acceptance(self):
        payload = b"bootlog UTF8: \xc3\xa5\n\xffbinary\n"
        def send():
            time.sleep(0.15)
            os.write(self.master, payload)
        thread = threading.Thread(target=send)
        thread.start()
        result = hil.capture(self.args)
        thread.join()
        self.assertEqual((self.args.output / "watch-uart.bin").read_bytes(), payload)
        self.assertEqual(result["uart_bytes"], len(payload))
        self.assertEqual(result["status"], "COLLECTED")
        self.assertEqual(result["acceptance"], "NOT_RUN")
        records = [json.loads(line) for line in (self.args.output / "timeline.jsonl").read_text().splitlines()]
        self.assertIn("watch_uart", [r["source"] for r in records])
        self.assertEqual([r["monotonic_ns"] for r in records], sorted(r["monotonic_ns"] for r in records))
        os.set_blocking(self.master, False)
        with self.assertRaises(BlockingIOError):
            os.read(self.master, 4096)  # Collector must never transmit UART commands.

    def test_macos_watch_capture_accepts_serial_port_and_records_host(self):
        with patch.object(hil.platform, "system", return_value="Darwin"):
            result = hil.capture(self.args)
        self.assertEqual(result["host_system"], "Darwin")
        self.assertEqual(result["profile"], "watch_only_capture")
        self.assertEqual(result["acceptance"], "NOT_RUN")

    def test_unsupported_host_rejected_before_opening_uart(self):
        with patch.object(hil.platform, "system", return_value="Windows"):
            with self.assertRaisesRegex(RuntimeError, "Linux or macOS"):
                hil.capture(self.args)
        self.assertFalse(self.args.output.exists())

    def test_silent_uart_is_not_reported_as_functional_success(self):
        result = hil.capture(self.args)
        self.assertEqual(result["uart_observation"], "NO_DATA")
        self.assertEqual(result["acceptance"], "NOT_RUN")

    def test_existing_artifacts_are_never_overwritten(self):
        self.args.output.mkdir()
        sentinel = self.args.output / "watch-uart.log"
        sentinel.write_text("original evidence")
        with self.assertRaises(FileExistsError):
            hil.capture(self.args)
        self.assertEqual(sentinel.read_text(), "original evidence")

    def test_phone_capture_requires_explicit_selection(self):
        self.args.watch_only = False
        with self.assertRaisesRegex(RuntimeError, "Select --android-serial"):
            hil.capture(self.args)
        self.assertFalse(self.args.output.exists())

    def test_uart_cannot_be_opened_by_two_collectors(self):
        import serial
        with serial.Serial(self.args.watch_uart, exclusive=True):
            with self.assertRaises(serial.SerialException):
                hil.capture(self.args)
        manifest = json.loads((self.args.output / "capture.json").read_text())
        self.assertEqual(manifest["status"], "ERROR")

    def test_logcat_disconnect_preserves_failure_and_timeline(self):
        fake_adb = self.root / "adb"
        fake_adb.write_text("#!/usr/bin/env python3\nimport sys\n"
                            "if sys.argv[1:] == ['devices', '-l']:\n"
                            "    print('List of devices attached\\nphysical device model:Fake')\n"
                            "else:\n    print('adb: device disconnected', flush=True)\n    sys.exit(1)\n")
        fake_adb.chmod(0o700)
        self.args.android_serial = "physical"
        self.args.watch_only = False
        with patch.object(hil.shutil, "which", return_value=str(fake_adb)):
            with self.assertRaisesRegex(RuntimeError, "logcat ended"):
                hil.capture(self.args)
        manifest = json.loads((self.args.output / "capture.json").read_text())
        self.assertEqual(manifest["status"], "ERROR")
        self.assertIn("device disconnected", (self.args.output / "phone.log").read_text())
        self.assertTrue((self.args.output / "timeline.jsonl").exists())

    def test_partial_logcat_line_stops_at_deadline(self):
        fake_adb = self.root / "adb"
        fake_adb.write_text("#!/usr/bin/env python3\nimport sys, time\n"
                            "if sys.argv[1:] == ['devices', '-l']:\n"
                            "    print('List of devices attached\\nphysical device model:Fake')\n"
                            "else:\n    sys.stdout.write('partial line'); sys.stdout.flush(); time.sleep(60)\n")
        fake_adb.chmod(0o700)
        self.args.android_serial = "physical"
        self.args.watch_only = False
        start = time.monotonic()
        with patch.object(hil.shutil, "which", return_value=str(fake_adb)):
            result = hil.capture(self.args)
        self.assertLess(time.monotonic() - start, 3)
        self.assertEqual(result["status"], "COLLECTED")
        self.assertEqual((self.args.output / "phone.log").read_text(), "partial line")


if __name__ == "__main__":
    unittest.main()
