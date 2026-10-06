import json
from pathlib import Path
import re
import unittest

from prepare_lost_voice_ack import ack_call, ack_condition, script


def wire(key='b' * 64, generation=12):
    # Wire shape of snprintf in ble_gadgetbridge.c, independent of the generator.
    return json.dumps({'t': 'voice_memo', 'action': 'result_ack', 'version': 1,
                       'result_id': 'a' * 64, 'recording_key': key,
                       'result_sha256': 'c' * 64, 'generation': generation,
                       'status': 'accepted'}, separators=(',', ':')).encode()


def matches(condition, packet, accepted=1):
    # Evaluate the generated comparisons against actual ACK bytes, without GDB
    # or a device. No generic eval and no target-side function calls.
    for term in condition.split(' && '):
        if term == 'accepted == 1':
            if accepted != 1:
                return False
        elif term.startswith('$r1 == '):
            if len(packet) != int(term.removeprefix('$r1 == ')):
                return False
        else:
            match = re.fullmatch(r'\*\(unsigned (int|char) \*\)\(\$r0 \+ (\d+)\) == (0x[0-9a-f]+|\d+)', term)
            if not match:
                raise AssertionError(f'Unsafe/unsupported GDB condition: {term}')
            size = 4 if match[1] == 'int' else 1
            offset = int(match[2])
            if int.from_bytes(packet[offset:offset + size], 'little') != int(match[3], 0):
                return False
    return True


class PrepareLostVoiceAckTest(unittest.TestCase):
    def test_only_owned_new_receipt_and_exact_generation_match_real_ack_shape(self):
        for generation in (1, 9, 10, 12, 0xffffffff):
            condition = ack_condition('b' * 64, generation)
            self.assertTrue(matches(condition, wire(generation=generation)))
            self.assertFalse(matches(condition, wire(generation=generation), accepted=0))
            self.assertFalse(matches(condition, wire(key='d' * 64, generation=generation)))
            self.assertFalse(matches(condition, wire(generation=2 if generation == 1 else 1)))
            self.assertFalse(matches(condition, wire(generation=generation).replace(b'accepted', b'rejected')))
            self.assertFalse(matches(condition, wire(generation=generation).replace(b'voice_memo', b'other_memo')))
            self.assertFalse(matches(condition, wire(generation=generation)[:-1]))

    def test_ambiguous_missing_and_non_thumb_call_sites_fail_closed(self):
        line = '   0x000160a2 <parse_data+3098>:\t0b f0 2b fa\tbl\t0x214fc <ble_comm_send>\n'
        self.assertEqual((0x160a2, bytes.fromhex('0b f0 2b fa')), ack_call(line))
        for invalid in ('', line + line, line.replace('0b f0 2b fa', '0b f0'), line.replace('ble_comm_send', 'other')):
            with self.assertRaises(ValueError):
                ack_call(invalid)

    def test_script_guards_target_code_and_detaches_after_one_skipped_call(self):
        value = script(Path('/tmp/space path/watch.elf'), 0x160a2, bytes.fromhex('0b f0 2b fa'),
                       ack_condition('b' * 64, 12), Path('/tmp/run'), 2331)
        self.assertIn('target remote 127.0.0.1:2331', value)
        self.assertIn('if !(', value)
        self.assertIn('thbreak *0x160a2 if accepted == 1', value)
        self.assertIn('set $pc = 0x160a6', value)
        self.assertIn('set $r0 = -5', value)
        self.assertLess(value.index('dump binary memory'), value.index('set $pc'))
        self.assertIn('set $r0 = -5\n  detach\n  quit', value)
        self.assertNotRegex(value, r'(?m)^\s*(load|restore|call|monitor reset)\b')
        for forbidden in ('strcmp(', 'memcmp('):
            self.assertNotIn(forbidden, value)

    def test_invalid_identity_generation_port_and_control_paths_reject(self):
        for key, generation in [('B' * 64, 1), ('../unsafe', 1), ('b' * 64, 0), ('b' * 64, 0x100000000)]:
            with self.assertRaises(ValueError):
                ack_condition(key, generation)
        with self.assertRaises(ValueError):
            script(Path('/tmp/watch.elf'), 1, b'1234', 'true', Path('/tmp/run'), 80)
        with self.assertRaises(ValueError):
            script(Path('/tmp/watch\nreset.elf'), 1, b'1234', 'true', Path('/tmp/run'), 2331)


if __name__ == '__main__':
    unittest.main()
