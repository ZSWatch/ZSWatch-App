"""Loopback-only asynchronous job fixture. Synthetic metadata/results, no AI."""

import argparse
import json
import socket
import sqlite3
from contextlib import contextmanager
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.error import HTTPError
from urllib.parse import urlsplit
from urllib.request import Request, urlopen

from .contract import canonical, job_key, validate_result


class Backend:
    def __init__(self, database, result):
        self.database = str(database)
        validate_result(result)
        self.result = result
        with self.connect() as db:
            db.executescript('''
                CREATE TABLE IF NOT EXISTS remote_fixture_jobs (
                  remote_id TEXT PRIMARY KEY, job_key TEXT UNIQUE NOT NULL,
                  spec TEXT NOT NULL, state TEXT NOT NULL, result TEXT);
                CREATE TABLE IF NOT EXISTS remote_fixture_control (
                  name TEXT PRIMARY KEY, value TEXT NOT NULL);
            ''')

    @contextmanager
    def connect(self):
        db = sqlite3.connect(self.database, timeout=5)
        db.row_factory = sqlite3.Row
        db.execute('PRAGMA synchronous=FULL')
        try:
            with db:
                yield db
        finally:
            db.close()

    def fault(self, value):
        if value not in ('drop_after_accept', 'rate_limit', 'auth_expired', 'none'):
            raise ValueError('Unknown one-shot fault')
        with self.connect() as db:
            db.execute('INSERT OR REPLACE INTO remote_fixture_control VALUES (?,?)', ('fault', value))

    def submit(self, body):
        if not isinstance(body, dict) or set(body) != {'spec', 'idempotency_key'}:
            raise ValueError('Invalid submit envelope')
        spec = body['spec']
        identity = job_key(spec)
        if body['idempotency_key'] != identity or spec['backend'] != 'remote':
            raise ValueError('Wrong idempotency key or backend')
        remote_id = 'fixture-' + identity
        with self.connect() as db:
            db.execute('BEGIN IMMEDIATE')
            row = db.execute("SELECT value FROM remote_fixture_control WHERE name='fault'").fetchone()
            fault = row[0] if row else 'none'
            db.execute("DELETE FROM remote_fixture_control WHERE name='fault'")
            if fault not in ('rate_limit', 'auth_expired'):
                db.execute('INSERT OR IGNORE INTO remote_fixture_jobs VALUES (?,?,?,?,NULL)',
                           (remote_id, identity, canonical(spec), 'running'))
        return remote_id, fault

    def status(self, remote_id):
        with self.connect() as db:
            row = db.execute('SELECT * FROM remote_fixture_jobs WHERE remote_id=?', (remote_id,)).fetchone()
        if row is None:
            raise KeyError(remote_id)
        return {'version': 1, 'remote_id': remote_id, 'state': row['state'],
                'result': json.loads(row['result']) if row['result'] else None}

    def finish(self, remote_id, state):
        with self.connect() as db:
            db.execute('BEGIN IMMEDIATE')
            row = db.execute('SELECT state FROM remote_fixture_jobs WHERE remote_id=?', (remote_id,)).fetchone()
            if row is None:
                raise KeyError(remote_id)
            if row[0] != 'running':
                if row[0] != state:
                    raise ValueError('Terminal remote job cannot change state')
                return
            db.execute('UPDATE remote_fixture_jobs SET state=?,result=? WHERE remote_id=?',
                       (state, canonical(self.result) if state == 'succeeded' else None, remote_id))


class FixtureServer(ThreadingHTTPServer):
    daemon_threads = True

    def __init__(self, address, backend):
        if address[0] != '127.0.0.1':
            raise ValueError('Fixture controls must bind to loopback')
        self.backend = backend
        super().__init__(address, Handler)


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass  # Do not log request bodies, headers or credentials.

    def reply(self, code, value, **headers):
        body = canonical(value).encode('utf-8')
        self.send_response(code)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(body)))
        for name, value in headers.items():
            self.send_header(name.replace('_', '-'), str(value))
        self.end_headers()
        self.wfile.write(body)

    def dispatch(self, method):
        try:
            path = urlsplit(self.path).path
            body = None
            if method == 'POST':
                size = int(self.headers.get('Content-Length', '0'))
                if size < 1 or size > 65536:
                    raise ValueError('Expected a JSON body of at most 64 KiB')
                self.connection.settimeout(3)
                body = json.loads(self.rfile.read(size))
            if method == 'POST' and path == '/v1/jobs':
                remote_id, fault = self.server.backend.submit(body)
                if fault == 'drop_after_accept':
                    self.connection.shutdown(socket.SHUT_RDWR)
                    self.connection.close()
                    self.close_connection = True
                    return
                if fault == 'rate_limit':
                    self.reply(429, {'error': 'rate_limit'}, Retry_After=10)
                elif fault == 'auth_expired':
                    self.reply(401, {'error': 'auth_expired'})
                else:
                    self.reply(202, self.server.backend.status(remote_id))
            elif method == 'GET' and path.startswith('/v1/jobs/'):
                self.reply(200, self.server.backend.status(path.removeprefix('/v1/jobs/')))
            elif method == 'POST' and path == '/__fixture__/fault':
                self.server.backend.fault(body['fault'])
                self.reply(200, {'configured': body['fault']})
            elif method == 'POST' and path.startswith('/__fixture__/'):
                _, _, operation, remote_id = path.split('/')
                states = {'complete': 'succeeded', 'fail': 'failed', 'cancel': 'cancelled'}
                self.server.backend.finish(remote_id, states[operation])
                self.reply(200, self.server.backend.status(remote_id))
            else:
                self.reply(404, {'error': 'not_found'})
        except KeyError:
            self.reply(404, {'error': 'not_found'})
        except (ValueError, TypeError, AttributeError):
            self.reply(400, {'error': 'invalid_request'})

    def do_GET(self):
        self.dispatch('GET')

    def do_POST(self):
        self.dispatch('POST')


class RemoteError(Exception):
    def __init__(self, status, retry_after=None):
        super().__init__(f'Remote HTTP {status}')
        self.status = status
        self.retry_after = retry_after


class Client:
    def __init__(self, base_url):
        parsed = urlsplit(base_url)
        if (parsed.scheme != 'http' or parsed.hostname not in ('127.0.0.1', 'localhost') or
                parsed.username is not None or parsed.path not in ('', '/')):
            raise ValueError('Fixture client only supports HTTP loopback')
        self.base_url = base_url.rstrip('/')

    def request(self, path, body=None):
        request = Request(self.base_url + path, method='GET' if body is None else 'POST',
                          data=None if body is None else canonical(body).encode('utf-8'),
                          headers={'Content-Type': 'application/json'})
        try:
            with urlopen(request, timeout=3) as response:
                return json.load(response)
        except HTTPError as exc:
            retry = exc.headers.get('Retry-After')
            raise RemoteError(exc.code, int(retry) if retry is not None else None) from exc

    def submit(self, spec):
        return self.request('/v1/jobs', {'spec': spec, 'idempotency_key': job_key(spec)})

    def status(self, remote_id):
        return self.request('/v1/jobs/' + remote_id)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--state-dir', required=True, type=Path)
    parser.add_argument('--resume-existing', action='store_true')
    parser.add_argument('--port', type=int, default=8765)
    args = parser.parse_args()
    marker = args.state_dir / 'remote-fixture-v1.json'
    if args.resume_existing:
        if not marker.is_file() or json.loads(marker.read_text()) != {'version': 1, 'fixture': True}:
            parser.error('Cannot resume a directory without the matching fixture marker')
    else:
        args.state_dir.mkdir(parents=True, exist_ok=False, mode=0o700)
        marker.write_text(canonical({'version': 1, 'fixture': True}))
    result = json.loads((Path(__file__).parent / 'fixtures/result-v1.json').read_text())
    backend = Backend(args.state_dir / 'server.sqlite', result)
    with FixtureServer(('127.0.0.1', args.port), backend) as server:
        print(canonical({'status': 'FIXTURE_LISTENING', 'url': f'http://127.0.0.1:{server.server_port}',
                         'acceptance': 'NOT_RUN'}), flush=True)
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            pass


if __name__ == '__main__':
    main()
