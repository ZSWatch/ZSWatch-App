"""Versioned, deliberately small reference store for recovery conformance tests.

Separate SQLite files only: never open the Flutter/Drift application database.
No timers, network, OS wakeups, BLE, model execution or action execution here.
"""

import hashlib
import json
import sqlite3
from contextlib import contextmanager
from pathlib import Path


def canonical(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(',', ':'),
                      allow_nan=False)


JOB_FIELDS = {
    'version', 'watch_id', 'recording_id', 'input_sha256', 'backend', 'provider',
    'model', 'pipeline_revision', 'generation', 'upload_authorized',
}


def job_key(spec):
    if set(spec) != JOB_FIELDS or type(spec['version']) is not int or spec['version'] != 1:
        raise ValueError('Unsupported job envelope')
    for name in ('watch_id', 'recording_id', 'provider', 'model', 'pipeline_revision'):
        if not isinstance(spec[name], str) or not spec[name]:
            raise ValueError(f'Invalid {name}')
    digest = spec['input_sha256']
    if (not isinstance(digest, str) or len(digest) != 64 or
            any(c not in '0123456789abcdef' for c in digest)):
        raise ValueError('Expected lowercase SHA-256')
    if type(spec['generation']) is not int or spec['generation'] < 1:
        raise ValueError('Invalid generation')
    if spec['backend'] not in ('local', 'remote') or type(spec['upload_authorized']) is not bool:
        raise ValueError('Invalid backend/authorization')
    if spec['backend'] == 'remote' and not spec['upload_authorized']:
        raise ValueError('Remote upload requires explicit authorization')
    return hashlib.sha256(canonical(spec).encode('utf-8')).hexdigest()


def validate_result(result):
    if (not isinstance(result, dict) or set(result) !=
            {'version', 'transcript', 'summary', 'category', 'actions'} or
            type(result['version']) is not int or result['version'] != 1):
        raise ValueError('Unsupported result envelope')
    for name in ('transcript', 'summary', 'category'):
        if not isinstance(result[name], str):
            raise ValueError(f'Invalid {name}')
    if not result['summary'].strip() or not isinstance(result['actions'], list):
        raise ValueError('Result requires a summary and action list')
    for action in result['actions']:
        if (not isinstance(action, dict) or action.get('type') not in
                ('task', 'calendar_event', 'reminder', 'timer', 'alarm') or
                not isinstance(action.get('title'), str) or not action['title'].strip()):
            raise ValueError('Invalid action suggestion')
        if set(action) - {'type', 'title', 'due_date'}:
            raise ValueError('Unsupported action field')
        if 'due_date' in action and not isinstance(action['due_date'], str):
            raise ValueError('Invalid due_date')
    canonical(result)


class Store:
    def __init__(self, path):
        self.db = sqlite3.connect(Path(path), isolation_level=None, timeout=5)
        self.db.row_factory = sqlite3.Row
        self.db.execute('PRAGMA foreign_keys=ON')
        self.db.execute('PRAGMA journal_mode=WAL')
        self.db.execute('PRAGMA synchronous=FULL')
        self.db.executescript('''
            CREATE TABLE IF NOT EXISTS fixture_jobs (
              job_id TEXT PRIMARY KEY, spec TEXT NOT NULL,
              state TEXT NOT NULL DEFAULT 'ready', remote_id TEXT,
              fence INTEGER NOT NULL DEFAULT 0, lease_until INTEGER,
              attempts INTEGER NOT NULL DEFAULT 0, next_attempt INTEGER NOT NULL DEFAULT 0,
              last_error TEXT, result TEXT);
            CREATE TABLE IF NOT EXISTS fixture_outbox (
              result_id TEXT PRIMARY KEY, job_id TEXT UNIQUE NOT NULL
                REFERENCES fixture_jobs(job_id), watch_id TEXT NOT NULL,
              payload TEXT NOT NULL, state TEXT NOT NULL DEFAULT 'pending');
        ''')

    def close(self):
        self.db.close()

    @contextmanager
    def transaction(self):
        self.db.execute('BEGIN IMMEDIATE')
        try:
            yield
            self.db.execute('COMMIT')
        except BaseException:
            self.db.execute('ROLLBACK')
            raise

    def create(self, spec):
        identity = job_key(spec)
        with self.transaction():
            for existing in self.db.execute('SELECT * FROM fixture_jobs').fetchall():
                previous = json.loads(existing['spec'])
                if (previous['watch_id'], previous['recording_id']) != (spec['watch_id'], spec['recording_id']):
                    continue
                if previous['generation'] > spec['generation']:
                    raise ValueError('Cannot restore an obsolete generation')
                if previous['generation'] == spec['generation'] and existing['job_id'] != identity:
                    raise ValueError('Changed input/backend requires a new generation')
                if previous['generation'] < spec['generation'] and existing['state'] != 'delivered':
                    self.db.execute("UPDATE fixture_jobs SET state='cancelled',fence=fence+1,lease_until=NULL WHERE job_id=?",
                                    (existing['job_id'],))
                    self.db.execute("UPDATE fixture_outbox SET state='cancelled' WHERE job_id=? AND state='pending'",
                                    (existing['job_id'],))
            self.db.execute('INSERT OR IGNORE INTO fixture_jobs(job_id,spec) VALUES (?,?)',
                            (identity, canonical(spec)))
        return identity

    def snapshot(self, identity):
        row = self.db.execute('SELECT * FROM fixture_jobs WHERE job_id=?', (identity,)).fetchone()
        if row is None:
            raise KeyError(identity)
        return dict(row)

    def claim(self, identity, now, lease_seconds=30):
        """Caller supplies UTC epoch seconds; no implicit scheduler/clock."""
        if lease_seconds <= 0:
            raise ValueError('Lease must be positive')
        with self.transaction():
            row = self.snapshot(identity)
            if (row['state'] not in ('ready', 'waiting_remote') or
                    row['next_attempt'] > now or
                    (row['lease_until'] is not None and row['lease_until'] > now)):
                return None
            fence = row['fence'] + 1
            self.db.execute('''UPDATE fixture_jobs SET fence=?, lease_until=?,
                            attempts=attempts+1 WHERE job_id=?''',
                            (fence, now + lease_seconds, identity))
            return fence

    def _owned(self, identity, fence, now):
        row = self.snapshot(identity)
        if (row['fence'] != fence or row['lease_until'] is None or
                row['lease_until'] <= now or row['state'] not in ('ready', 'waiting_remote')):
            return None
        return row

    def accepted(self, identity, fence, now, remote_id):
        if not isinstance(remote_id, str) or not remote_id:
            raise ValueError('Missing remote ID')
        with self.transaction():
            row = self._owned(identity, fence, now)
            if row is None:
                return False
            if json.loads(row['spec'])['backend'] != 'remote':
                raise ValueError('Local jobs cannot acquire a remote ID')
            if row['remote_id'] is not None and row['remote_id'] != remote_id:
                raise ValueError('Remote job identity changed')
            self.db.execute("UPDATE fixture_jobs SET remote_id=?,state='waiting_remote' WHERE job_id=?",
                            (remote_id, identity))
            return True

    def defer(self, identity, fence, now, delay, error, blocked=False, max_attempts=5):
        if delay < 0 or max_attempts < 1:
            raise ValueError('Invalid retry policy')
        with self.transaction():
            row = self._owned(identity, fence, now)
            if row is None:
                return False
            # Ordinary server processing is not a failed attempt.
            attempts = row['attempts'] - 1 if error == 'server_pending' else row['attempts']
            state = ('blocked' if blocked else 'failed' if attempts >= max_attempts else row['state'])
            self.db.execute('''UPDATE fixture_jobs SET state=?, attempts=?, lease_until=NULL,
                            next_attempt=?,last_error=? WHERE job_id=?''',
                            (state, attempts, now + delay, error, identity))
            return True

    def complete(self, identity, fence, now, result, remote_id=None, before_commit=None):
        validate_result(result)
        with self.transaction():
            row = self._owned(identity, fence, now)
            if row is None:
                return False
            if row['remote_id'] != remote_id:
                raise ValueError('Result is for a different remote job')
            spec = json.loads(row['spec'])
            if spec['backend'] == 'remote' and remote_id is None:
                raise ValueError('Remote result without accepted job')
            result_id = hashlib.sha256(('result-v1:' + identity).encode()).hexdigest()
            payload = canonical({'version': 1, 'result_id': result_id, 'job_id': identity,
                                 'watch_id': spec['watch_id'], 'recording_id': spec['recording_id'],
                                 'generation': spec['generation'], 'result': result})
            self.db.execute("UPDATE fixture_jobs SET state='result_ready',result=?,lease_until=NULL WHERE job_id=?",
                            (canonical(result), identity))
            self.db.execute('INSERT INTO fixture_outbox(result_id,job_id,watch_id,payload) VALUES (?,?,?,?)',
                            (result_id, identity, spec['watch_id'], payload))
            if before_commit is not None:
                before_commit()  # Fault injection only; test process may die here.
            return True

    def cancel(self, identity, fence=None, now=None):
        with self.transaction():
            if fence is not None:
                if now is None:
                    raise ValueError('Callback cancellation requires its lease time')
                if self._owned(identity, fence, now) is None:
                    return False
            row = self.snapshot(identity)
            if row['state'] in ('cancelled', 'delivered'):
                return False
            self.db.execute("UPDATE fixture_jobs SET state='cancelled',fence=fence+1,lease_until=NULL WHERE job_id=?",
                            (identity,))
            self.db.execute("UPDATE fixture_outbox SET state='cancelled' WHERE job_id=? AND state='pending'",
                            (identity,))
            return True

    def resume_after_credentials_refreshed(self, identity):
        """Explicit caller action; credentials remain outside persisted envelopes."""
        with self.transaction():
            row = self.snapshot(identity)
            if row['state'] != 'blocked':
                return False
            state = 'waiting_remote' if row['remote_id'] is not None else 'ready'
            self.db.execute('''UPDATE fixture_jobs SET state=?,fence=fence+1,
                            lease_until=NULL,next_attempt=0,attempts=0,last_error=NULL WHERE job_id=?''',
                            (state, identity))
            return True

    def pending(self, watch_id):
        return [dict(row) for row in self.db.execute(
            "SELECT * FROM fixture_outbox WHERE watch_id=? AND state='pending' ORDER BY result_id",
            (watch_id,))]

    def acknowledge(self, watch_id, result_id, status='accepted'):
        if status != 'accepted':
            return False
        with self.transaction():
            row = self.db.execute('SELECT * FROM fixture_outbox WHERE result_id=? AND watch_id=?',
                                  (result_id, watch_id)).fetchone()
            if row is None or row['state'] == 'cancelled':
                return False
            self.db.execute("UPDATE fixture_outbox SET state='acked' WHERE result_id=?", (result_id,))
            self.db.execute("UPDATE fixture_jobs SET state='delivered' WHERE job_id=?", (row['job_id'],))
            return True


class Receiver:
    """Fake watch ACK/deduplication contract; not current firmware behavior."""
    def __init__(self, path, watch_id):
        self.watch_id = watch_id
        self.db = sqlite3.connect(path)
        self.db.execute('CREATE TABLE IF NOT EXISTS receipts(result_id TEXT PRIMARY KEY,payload TEXT NOT NULL)')
        self.db.execute('''CREATE TABLE IF NOT EXISTS generations(
                        recording_id TEXT PRIMARY KEY,generation INTEGER NOT NULL,result_id TEXT NOT NULL)''')

    def receive(self, payload):
        if (set(payload) != {'version', 'result_id', 'job_id', 'watch_id', 'recording_id', 'generation', 'result'} or
                type(payload['version']) is not int or payload['version'] != 1 or payload['watch_id'] != self.watch_id or
                type(payload['generation']) is not int or payload['generation'] < 1):
            raise ValueError('Wrong receiver or delivery envelope')
        expected_id = hashlib.sha256(('result-v1:' + payload['job_id']).encode()).hexdigest()
        if payload['result_id'] != expected_id:
            raise ValueError('Wrong result identity')
        validate_result(payload['result'])
        encoded = canonical(payload)
        identity = payload['result_id']
        with self.db:
            self.db.execute('BEGIN IMMEDIATE')
            latest = self.db.execute('SELECT generation,result_id FROM generations WHERE recording_id=?',
                                     (payload['recording_id'],)).fetchone()
            if latest is not None and payload['generation'] < latest[0]:
                raise ValueError('Obsolete generation')
            if latest is not None and payload['generation'] == latest[0] and identity != latest[1]:
                raise ValueError('Conflicting result for the same generation')
            old = self.db.execute('SELECT payload FROM receipts WHERE result_id=?', (identity,)).fetchone()
            if old is not None and old[0] != encoded:
                raise ValueError('Same result ID with conflicting payload')
            self.db.execute('INSERT OR IGNORE INTO receipts VALUES (?,?)', (identity, encoded))
            self.db.execute('INSERT OR REPLACE INTO generations VALUES (?,?,?)',
                            (payload['recording_id'], payload['generation'], identity))
        return {'version': 1, 'watch_id': payload['watch_id'], 'result_id': identity, 'status': 'accepted'}

    def close(self):
        self.db.close()
