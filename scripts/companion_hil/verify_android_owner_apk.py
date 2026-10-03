#!/usr/bin/env python3
"""Read-only APK owner gate; does not establish Dart flags or hardware acceptance."""
import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path


def verify(apk, analyzer, owner):
    def code(name):
        return subprocess.run([str(analyzer), 'dex', 'code', '--class', name, str(apk)],
                              check=True, capture_output=True, text=True, timeout=30).stdout
    config = code('dev.zswatch.app.BuildConfig')
    activity = code('dev.zswatch.app.MainActivity')
    flag = re.search(r'^\.field public static final COMPANION_RUNTIME_PROTOTYPE:Z = (true|false)$',
                     config, re.MULTILINE)
    if flag is None:
        raise ValueError('Missing or unsupported compiled owner flag')
    method = re.search(r'^\.method public configureFlutterEngine\([^\n]*\n(.*?)^\.end method$',
                       activity, re.MULTILINE | re.DOTALL)
    if method is None:
        raise ValueError('Missing compiled engine setup')
    native = owner == 'native'
    bridge = 'Ldev/zswatch/app/companion/CompanionPrototypeBridge;-><init>' in method.group(1)
    if (flag.group(1) == 'true') != native or bridge != native:
        raise ValueError('Compiled owner flag/bridge differs from the intended APK variant')
    digest = hashlib.sha256()
    with apk.open('rb') as file:
        while chunk := file.read(1024 * 1024):
            digest.update(chunk)
    return {'scope': 'READ_ONLY_COMPILED_ANDROID_OWNER', 'acceptance': 'NOT_RUN',
            'owner': owner, 'apk_sha256': digest.hexdigest(), 'bridge_constructed': bridge}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apk', type=Path, required=True)
    parser.add_argument('--apkanalyzer', type=Path, required=True)
    parser.add_argument('--owner', choices=['native', 'flutter'], required=True)
    args = parser.parse_args()
    try:
        print(json.dumps(verify(args.apk, args.apkanalyzer, args.owner), indent=2))
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        parser.exit(1, f'APK owner verification failed: {type(error).__name__}: {error}\n')


if __name__ == '__main__':
    main()
