"""Read-only native prototype observations; never a background acceptance PASS."""

import argparse
import hashlib
import json
import re
import subprocess
from datetime import datetime, timezone
from pathlib import Path


COMPONENT = 'dev.zswatch.app.companion.CompanionPrototypeService'


def summarize(state, services, pid, expected=None):
    """Reject malformed Android JSON values and stale persisted readiness."""
    if state.get('version') != 1 or type(state.get('desired_running')) is not bool:
        raise ValueError('Unsupported native state')
    if type(state.get('generation')) is not int or state['generation'] < 0:
        raise ValueError('Invalid generation')
    packages = state.get('notification_packages', [])
    notices = state.get('notifications', {})
    if not isinstance(packages, list) or not all(isinstance(x, str) for x in packages):
        raise ValueError('Notification packages must be a JSON array, not a string')
    if not isinstance(notices, dict) or len(notices) > 64:
        raise ValueError('Invalid bounded notification journal')
    active = bool(re.search(r'ServiceRecord\{[^\n]*' + re.escape(COMPONENT), services))
    ready = active and bool(pid.strip()) and state.get('desired_running') is True and state.get('phase') == 'ready'
    stopped = not active and state.get('desired_running') is False and state.get('phase') == 'stopped' and not notices
    if expected == 'ready' and not ready:
        raise ValueError('Live native service is not protocol-ready')
    if expected == 'stopped' and not stopped:
        raise ValueError('Stop is not persisted, released, and cleared')
    return {
        'schema_version': 1, 'scope': 'READ_ONLY_NATIVE_STATE', 'acceptance': 'NOT_RUN',
        'observed_utc': datetime.now(timezone.utc).isoformat(),
        'pid': pid.strip(), 'service_present': active, 'protocol_ready': ready,
        'generation': state['generation'], 'phase': state.get('phase'),
        'desired_running': state['desired_running'], 'notification_count': len(notices),
        'notification_packages': packages, 'recording_sync_enabled': state.get('recording_sync_enabled'),
        'last_time_write_utc_ms': state.get('last_time_write_utc_ms'),
        'last_notification_write_utc_ms': state.get('last_notification_write_utc_ms'),
        # Do not emit Android keys, notification text, recordings or job content.
        'notifications': [{k: item.get(k) for k in ('id', 'revision', 'removed', 'delivered_generation', 'delivered_revision')}
                          for item in notices.values()],
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--adb', default='adb')
    parser.add_argument('--android-serial', required=True)
    parser.add_argument('--expect', choices=['ready', 'stopped'])
    parser.add_argument('--apk', type=Path, help='Optional frozen APK to verify against the installed hash')
    parser.add_argument('--output', type=Path, required=True, help='New JSON output file')
    args = parser.parse_args()
    if args.android_serial.startswith('emulator-'):
        parser.error('Select an explicit physical phone')
    def adb(*command):
        return subprocess.run([args.adb, '-s', args.android_serial, *command],
                              text=True, capture_output=True, check=True, timeout=20).stdout
    state = json.loads(adb('shell', 'run-as', 'com.zswatch.app', 'cat', 'files/companion-prototype/state-v1.json'))
    # pidof returns nonzero for a stopped process; listener may keep it alive.
    processes = adb('shell', 'ps', '-A')
    pid = next((line.split()[1] for line in processes.splitlines() if line.split()[-1:] == ['com.zswatch.app']), '')
    result = summarize(state, adb('shell', 'dumpsys', 'activity', 'services', 'com.zswatch.app'), pid, args.expect)
    result['android_serial'] = args.android_serial
    result['resumed_activity'] = next((line.strip() for line in adb('shell', 'dumpsys', 'activity', 'activities').splitlines()
                                       if 'mResumedActivity:' in line), None)
    if args.apk:
        installed = adb('shell', 'pm', 'path', 'com.zswatch.app').strip().removeprefix('package:')
        if not installed.startswith('/data/app/') or '\n' in installed:
            raise ValueError('Expected one installed base APK')
        remote_hash = adb('shell', 'sha256sum', installed).split()[0]
        with args.apk.open('rb') as apk:
            local_hash = hashlib.file_digest(apk, 'sha256').hexdigest()
        if remote_hash != local_hash:
            raise ValueError('Installed APK differs from frozen artifact')
        result['installed_apk_sha256'] = remote_hash
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open('x') as output:
        json.dump(result, output, indent=2)
        output.write('\n')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
