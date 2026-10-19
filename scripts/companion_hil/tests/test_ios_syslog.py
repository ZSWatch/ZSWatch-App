"""No device access: process filtering of pymobiledevice3 syslog lines."""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import ios_syslog


class IosSyslogTests(unittest.TestCase):
    def test_keeps_selected_processes_only(self):
        processes = set(ios_syslog.DEFAULT_PROCESSES)
        cases = [
            ('2026-10-19 18:45:54.645 bluetoothd{bluetoothd}[98] <NOTICE>: x', True),
            ('2026-10-19 18:45:57.337 Runner{Flutter}[5586] <NOTICE>: f', True),
            ('2026-10-19 18:45:54.645 backboardd{IOKit}[71] <DEBUG>: x', False),
            ('    en0 = "name=en0"', None),  # continuation: follows its entry
        ]
        for line, expected in cases:
            self.assertEqual(ios_syslog.keep(line, processes), expected, line)

    def test_all_keeps_everything(self):
        self.assertTrue(ios_syslog.keep('anything', None))

    def test_defaults_and_exclusive_options(self):
        self.assertEqual(ios_syslog.arguments(['--output', 'x.log']).processes,
                         ios_syslog.DEFAULT_PROCESSES)
        with self.assertRaises(SystemExit):
            ios_syslog.arguments(['--output', 'x.log', '--all', '--process', 'Runner'])


if __name__ == '__main__':
    unittest.main()
