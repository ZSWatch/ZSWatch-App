#!/usr/bin/env python3
"""Prepare, never execute, a one-ACK debugger omission for the current watch ELF.

The phone must process/deliver the owned recording normally. This generates a
temporary hardware breakpoint at the ACK's ble_comm_send instruction. It only
matches a new durable receipt for the requested recording key and generation.
No firmware patch, custom SMP, payload injection or external action is involved.
"""

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess


def ack_condition(recording_key, generation):
    if not re.fullmatch(r"[0-9a-f]{64}", recording_key):
        raise ValueError("Recording key must be a lowercase SHA-256")
    if type(generation) is not int or not 1 <= generation <= 0xffffffff:
        raise ValueError("Generation must fit the firmware's uint32_t")
    prefix = b'{"t":"voice_memo","action":"result_ack","version":1,"result_id":"'
    key_offset = len(prefix) + 64 + len(b'","recording_key":"')
    tail = f'","generation":{generation},"status":"accepted"}}'.encode()
    length = key_offset + 64 + len(b'","result_sha256":"') + 64 + len(tail)
    conditions = ["accepted == 1", f"$r1 == {length}"]
    # GDB reads target memory directly: these comparisons never call libc in a
    # halted Zephyr thread. Check the ACK envelope, owned key and exact generation.
    for offset, data in [(0, prefix), (key_offset, recording_key.encode()),
                         (length - len(tail), tail)]:
        for start in range(0, len(data), 4):
            word = data[start:start + 4]
            if len(word) == 4:
                conditions.append(f"*(unsigned int *)($r0 + {offset + start}) == 0x{int.from_bytes(word, 'little'):08x}")
            else:
                conditions.extend(f"*(unsigned char *)($r0 + {offset + start + i}) == {byte}"
                                  for i, byte in enumerate(word))
    return " && ".join(conditions)


def ack_call(disassembly):
    calls = re.findall(r"^\s*(0x[0-9a-f]+)\s+<[^>]+>:\s*((?:[0-9a-f]{2}\s+)+)bl\s+0x[0-9a-f]+\s+<ble_comm_send>\s*$",
                       disassembly, re.MULTILINE)
    if len(calls) != 1:
        raise ValueError("ACK source range must contain exactly one ble_comm_send call")
    address, encoding = calls[0]
    code = bytes.fromhex(encoding)
    if len(code) != 4:
        raise ValueError("Expected a four-byte ARM Thumb BL instruction")
    return int(address, 16), code


def script(elf, call, encoding, condition, output, port):
    if not isinstance(port, int) or not 1024 <= port <= 65535:
        raise ValueError("Invalid local GDB port")
    for path in (elf, output):
        if any(char in str(path) for char in "\r\n\x00"):
            raise ValueError("GDB paths cannot contain control characters")
    next_instruction = call + len(encoding)
    matches_code = " && ".join(f"*(unsigned char *)0x{call + i:x} == {byte}" for i, byte in enumerate(encoding))
    return f'''set pagination off
set confirm off
file {json.dumps(str(elf))}
target remote 127.0.0.1:{port}
if !({matches_code})
  echo ACK call site differs from the prepared ELF; leaving firmware unchanged.\\n
  detach
  quit 2
end
thbreak *0x{call:x} if {condition}
commands
  silent
  if !({condition})
    echo ACK identity could not be verified; leaving firmware unchanged.\\n
    detach
    quit 2
  end
  dump binary memory {json.dumps(str(output / 'omitted-ack.json'))} $r0 ($r0 + $r1)
  printf "ZSW_OWNED_ACK_OMITTED accepted=%d\\n", accepted
  set $pc = 0x{next_instruction:x}
  set $r0 = -5
  detach
  quit
end
echo Owned ACK omission armed; trigger the recording's normal processing now.\\n
continue
'''


def prepare(args):
    elf = args.elf.resolve(strict=True)
    source = args.source.resolve(strict=True)
    source_lines = source.read_text().splitlines()
    candidates = [i + 1 for i, line in enumerate(source_lines)
                  if 'int rc = length' in line and 'ble_comm_send(ack, length)' in line]
    if len(candidates) != 1:
        raise ValueError("Cannot locate the real durable-result ACK send")
    line = candidates[0]

    def gdb(command):
        return subprocess.check_output([str(args.gdb), '-batch', str(elf), '-ex', command],
                                       text=True, timeout=20)

    location = gdb(f'info line {source.name}:{line}')
    start = re.search(r'starts at address (0x[0-9a-f]+)', location)
    if not start:
        raise ValueError("ELF lacks an ACK source location")
    # Optimized LOG_INF line mappings can point back into an earlier branch.
    # Inspect a short bounded range from the ACK expression instead; reject any
    # ambiguous target call rather than inferring from the next source line.
    end = int(start[1], 16) + 64
    disassembly = gdb(f'disassemble /r {start[1]},0x{end:x}')
    call, encoding = ack_call(disassembly)
    scope = re.search(r'Symbol accepted.*?(?=\nSymbol |\Z)',
                      gdb(f'info scope *0x{call:x}'), re.DOTALL)
    if not scope or 'optimized out' in scope[0]:
        raise ValueError("Durable receipt return is unavailable at the ACK breakpoint")
    condition = ack_condition(args.recording_key, args.generation)
    output = args.output.resolve()
    output.mkdir(mode=0o700, parents=True, exist_ok=False)
    prepared = script(elf, call, encoding, condition, output, args.port)
    (output / 'omit-one-ack.gdb').write_text(prepared)
    (output / 'ack-call-disassembly.txt').write_text(disassembly)
    (output / 'accepted-scope.txt').write_text(scope[0] + '\n')
    (output / 'preparation.json').write_text(json.dumps({
        'status': 'PREPARED_NOT_EXECUTED', 'physical_acceptance': 'PENDING',
        'elf': str(elf), 'elf_sha256': hashlib.sha256(elf.read_bytes()).hexdigest(),
        'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
        'generator_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        'gdb_script_sha256': hashlib.sha256(prepared.encode()).hexdigest(),
        'ack_source_line': line, 'call_address': hex(call), 'call_encoding': encoding.hex(),
        'recording_key': args.recording_key, 'generation': args.generation,
        'gdb_port': args.port,
        'scope': 'Omit one new durable watch ACK; require real native retry and subsequent application ACK',
    }, indent=2) + '\n')
    print(f'Prepared {output / "omit-one-ack.gdb"}; no device was opened or modified.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--gdb', type=Path, required=True)
    parser.add_argument('--elf', type=Path, required=True)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--recording-key', required=True)
    parser.add_argument('--generation', type=int, required=True)
    parser.add_argument('--port', type=int, default=2331)
    parser.add_argument('--output', type=Path, required=True)
    prepare(parser.parse_args())


if __name__ == '__main__':
    main()
