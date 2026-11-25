#!/usr/bin/env python3
"""Serve locally built watch firmware to the phone app (dev OTA).

  dev_ota.py serve                         # run the server
  dev_ota.py publish build/dfu_application.zip --note "Fix X"
  dev_ota.py status [--wait ID] [--timeout 900]
  dev_ota.py token                         # print the app token

Only the standard library is used. See README.md next to this file.
"""

from __future__ import annotations

import argparse
import hashlib
import hmac
import json
import os
import re
import secrets
import shutil
import subprocess
import sys
import threading
import time
import zipfile
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

DEFAULT_DIR = Path(os.environ.get('ZSWATCH_DEV_OTA_DIR', Path.home() / '.zswatch_dev_ota'))
DEFAULT_PORT = 8787
KEEP_BUILDS = 10
MAX_WAIT_S = 30
MAX_STATUS_BYTES = 4096
TERMINAL_STATES = {'running', 'failed', 'cancelled', 'declined'}
ID_RE = re.compile(r'^[0-9A-Za-z_-]{1,64}$')


class Store:
    def __init__(self, root: Path):
        self.root = root
        self.builds = root / 'builds'
        self.manifest_path = root / 'manifest.json'
        self.status_path = root / 'status.jsonl'
        self.token_path = root / 'token'
        self.builds.mkdir(parents=True, exist_ok=True)
        self._lock = threading.Lock()

    def token(self) -> str:
        if not self.token_path.exists():
            self.token_path.write_text(secrets.token_urlsafe(24))
            self.token_path.chmod(0o600)
        return self.token_path.read_text().strip()

    def manifest(self) -> dict | None:
        try:
            return json.loads(self.manifest_path.read_text())
        except (FileNotFoundError, json.JSONDecodeError):
            return None

    def publish(self, zip_path: Path, note: str, branch: str, commit: str) -> dict:
        data = zip_path.read_bytes()
        with zipfile.ZipFile(zip_path) as archive:
            if 'manifest.json' not in archive.namelist():
                raise SystemExit(f'{zip_path} has no manifest.json; expected dfu_application.zip')
        digest = hashlib.sha256(data).hexdigest()
        stamp = datetime.now(timezone.utc).strftime('%Y%m%d%H%M%S')
        build_id = f'{stamp}-{(commit or digest)[:10]}'
        (self.builds / f'{build_id}.zip').write_bytes(data)
        manifest = {
            'id': build_id,
            'sha256': digest,
            'size': len(data),
            'note': note,
            'branch': branch,
            'commit': commit,
            'created': datetime.now(timezone.utc).isoformat(timespec='seconds'),
        }
        tmp = self.manifest_path.with_suffix('.tmp')
        tmp.write_text(json.dumps(manifest, indent=2))
        tmp.replace(self.manifest_path)
        self._prune()
        return manifest

    def _prune(self) -> None:
        builds = sorted(self.builds.glob('*.zip'))
        for old in builds[:-KEEP_BUILDS]:
            old.unlink(missing_ok=True)

    def add_status(self, status: dict) -> None:
        status['received'] = datetime.now(timezone.utc).isoformat(timespec='seconds')
        with self._lock, self.status_path.open('a') as out:
            out.write(json.dumps(status) + '\n')

    def statuses(self) -> list[dict]:
        try:
            lines = self.status_path.read_text().splitlines()
        except FileNotFoundError:
            return []
        result = []
        for line in lines:
            try:
                result.append(json.loads(line))
            except json.JSONDecodeError:
                pass
        return result


def make_handler(store: Store, token: str):
    class Handler(BaseHTTPRequestHandler):
        server_version = 'zswatch-dev-ota/1'

        def log_message(self, fmt, *args):
            sys.stderr.write(f'[dev_ota] {self.address_string()} {fmt % args}\n')

        def _path(self) -> tuple[str, dict]:
            parsed = urlparse(self.path)
            path = parsed.path
            # Tolerate a reverse-proxy mount such as `tailscale serve --set-path /zswatch-ota`.
            index = path.find('/api/')
            return (path[index:] if index >= 0 else path), parse_qs(parsed.query)

        def _authorized(self) -> bool:
            header = self.headers.get('Authorization', '')
            supplied = header[7:] if header.startswith('Bearer ') else ''
            if hmac.compare_digest(supplied, token):
                return True
            self._json(401, {'error': 'bad token'})
            return False

        def _json(self, code: int, body: object) -> None:
            data = json.dumps(body).encode()
            self.send_response(code)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(data)))
            self.send_header('Cache-Control', 'no-store')
            self.end_headers()
            self.wfile.write(data)

        def do_GET(self):
            path, query = self._path()
            if not self._authorized():
                return
            if path == '/api/latest':
                after = query.get('after', [''])[0]
                wait = min(float(query.get('wait', ['0'])[0] or 0), MAX_WAIT_S)
                deadline = time.monotonic() + wait
                manifest = store.manifest()
                while (manifest is None or manifest['id'] == after) and time.monotonic() < deadline:
                    time.sleep(0.5)
                    manifest = store.manifest()
                self._json(200, {'build': manifest})
            elif path.startswith('/api/builds/') and path.endswith('.zip'):
                build_id = path[len('/api/builds/'):-4]
                file = store.builds / f'{build_id}.zip'
                if not ID_RE.match(build_id) or not file.is_file():
                    self._json(404, {'error': 'no such build'})
                    return
                self.send_response(200)
                self.send_header('Content-Type', 'application/zip')
                self.send_header('Content-Length', str(file.stat().st_size))
                self.end_headers()
                with file.open('rb') as src:
                    shutil.copyfileobj(src, self.wfile)
            elif path == '/api/status':
                self._json(200, {'statuses': store.statuses()[-20:]})
            else:
                self._json(404, {'error': 'not found'})

        def do_POST(self):
            path, _ = self._path()
            if not self._authorized():
                return
            if path != '/api/status':
                self._json(404, {'error': 'not found'})
                return
            length = int(self.headers.get('Content-Length') or 0)
            if length <= 0 or length > MAX_STATUS_BYTES:
                self._json(400, {'error': 'bad length'})
                return
            try:
                body = json.loads(self.rfile.read(length))
            except json.JSONDecodeError:
                self._json(400, {'error': 'bad json'})
                return
            if not isinstance(body, dict) or not isinstance(body.get('state'), str):
                self._json(400, {'error': 'state required'})
                return
            store.add_status({k: v for k, v in body.items() if isinstance(v, (str, int, float, bool))})
            self._json(200, {'ok': True})

    return Handler


def git(path: Path, *args: str) -> str:
    try:
        return subprocess.check_output(['git', '-C', str(path), *args], text=True, stderr=subprocess.DEVNULL).strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return ''


def cmd_serve(args, store: Store) -> None:
    token = store.token()
    server = ThreadingHTTPServer((args.host, args.port), make_handler(store, token))
    print(f'[dev_ota] serving {store.root} on {args.host}:{args.port}', flush=True)
    server.serve_forever()


def cmd_publish(args, store: Store) -> None:
    zip_path = Path(args.zip).resolve()
    repo = Path(args.repo).resolve() if args.repo else zip_path.parent
    commit = args.commit or git(repo, 'rev-parse', '--short=12', 'HEAD')
    branch = args.branch or git(repo, 'rev-parse', '--abbrev-ref', 'HEAD')
    manifest = store.publish(zip_path, args.note, branch, commit)
    print(json.dumps(manifest, indent=2))


def cmd_status(args, store: Store) -> None:
    if not args.wait:
        for status in store.statuses()[-args.n:]:
            print(json.dumps(status))
        return
    deadline = time.monotonic() + args.timeout
    seen = len(store.statuses())
    for status in store.statuses():
        if status.get('id') == args.wait:
            print(json.dumps(status), flush=True)
            if status.get('state') in TERMINAL_STATES:
                sys.exit(0 if status['state'] == 'running' else 1)
    while time.monotonic() < deadline:
        statuses = store.statuses()
        for status in statuses[seen:]:
            if status.get('id') != args.wait:
                continue
            print(json.dumps(status), flush=True)
            if status.get('state') in TERMINAL_STATES:
                sys.exit(0 if status['state'] == 'running' else 1)
        seen = len(statuses)
        time.sleep(1)
    print(f'timeout waiting for {args.wait}', file=sys.stderr)
    sys.exit(2)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--dir', default=str(DEFAULT_DIR), help='data directory (default: %(default)s)')
    sub = parser.add_subparsers(dest='command', required=True)

    serve = sub.add_parser('serve')
    serve.add_argument('--host', default='127.0.0.1', help='use 0.0.0.0 to serve plain LAN clients')
    serve.add_argument('--port', type=int, default=DEFAULT_PORT)

    publish = sub.add_parser('publish')
    publish.add_argument('zip', help='dfu_application.zip from the firmware build')
    publish.add_argument('--note', default='', help='shown to the user in the app')
    publish.add_argument('--repo', help='firmware repo for branch/commit (default: zip directory)')
    publish.add_argument('--branch', default='')
    publish.add_argument('--commit', default='')

    status = sub.add_parser('status')
    status.add_argument('--wait', metavar='ID', help='follow this build until a final state')
    status.add_argument('--timeout', type=float, default=900)
    status.add_argument('-n', type=int, default=10)

    sub.add_parser('token')

    args = parser.parse_args()
    store = Store(Path(args.dir))
    if args.command == 'serve':
        cmd_serve(args, store)
    elif args.command == 'publish':
        cmd_publish(args, store)
    elif args.command == 'status':
        cmd_status(args, store)
    else:
        print(store.token())


if __name__ == '__main__':
    main()
