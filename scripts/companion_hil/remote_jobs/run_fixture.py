"""Replay the shared JSON trace over real loopback HTTP and persistent stores."""

import argparse
import hashlib
import json
import threading
import time
from datetime import datetime, timezone
from pathlib import Path

from .contract import Receiver, Store, canonical
from .recovery import advance
from .server import Backend, Client, FixtureServer


FIXTURES = Path(__file__).parent / 'fixtures'


def run(output):
    output = Path(output)
    output.mkdir(parents=True, exist_ok=False, mode=0o700)
    trace = json.loads((FIXTURES / 'recovery-v1.json').read_text())
    spec = json.loads((FIXTURES / 'job-v1.json').read_text())
    result = json.loads((FIXTURES / 'result-v1.json').read_text())
    store = Store(output / 'phone.sqlite')
    server = FixtureServer(('127.0.0.1', 0), Backend(output / 'server.sqlite', result))
    thread = threading.Thread(target=server.serve_forever, kwargs={'poll_interval': 0.01})
    thread.start()
    client = Client(f'http://127.0.0.1:{server.server_port}')
    report = {'version': 1, 'scenario': trace['scenario'], 'status': 'ERROR',
              'acceptance': 'NOT_RUN', 'clock': 'injected UTC epoch seconds, not elapsed time',
              'events': [], 'fixture_sha256': {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                                             for p in sorted(FIXTURES.glob('*.json'))}}
    try:
        identity = store.create(spec)
        if identity != trace['job_key']:
            raise ValueError('Golden job identity mismatch')
        for step in trace['steps']:
            operation = step['op']
            if operation == 'fault':
                client.request('/__fixture__/fault', {'fault': step['fault']})
            elif operation == 'advance':
                advance(store, identity, client, step['now'], step['trigger'])
            elif operation == 'reopen':
                store.close()
                store = Store(output / 'phone.sqlite')
            elif operation == 'reopen_server':
                server.backend = Backend(output / 'server.sqlite', result)
            elif operation == 'complete_server':
                remote_id = store.snapshot(identity)['remote_id']
                client.request('/__fixture__/complete/' + remote_id, {})
            elif operation in ('deliver_drop_ack', 'deliver_ack'):
                delivery = store.pending(spec['watch_id'])[0]
                if delivery['result_id'] != trace['result_id']:
                    raise ValueError('Golden result identity mismatch')
                receiver = Receiver(output / 'watch.sqlite', spec['watch_id'])
                try:
                    ack = receiver.receive(json.loads(delivery['payload']))
                finally:
                    receiver.close()
                if operation == 'deliver_ack':
                    if not store.acknowledge(ack['watch_id'], ack['result_id'], ack['status']):
                        raise ValueError('Matching ACK rejected')
            else:
                raise ValueError('Unknown trace operation')
            state = store.snapshot(identity)['state']
            pending = len(store.pending(spec['watch_id']))
            event = {'step': step, 'observed_state': state, 'observed_pending': pending,
                     'host_utc': datetime.now(timezone.utc).isoformat(),
                     'host_monotonic_ns': time.monotonic_ns()}
            report['events'].append(event)
            with (output / 'timeline.jsonl').open('a') as log:
                log.write(canonical(event) + '\n')
            if (state, pending) != (step['state'], step['pending']):
                raise ValueError(f'Trace mismatch at {operation}: {state}, {pending}')
        with server.backend.connect() as db:
            report['remote_jobs'] = db.execute('SELECT COUNT(*) FROM remote_fixture_jobs').fetchone()[0]
        receiver = Receiver(output / 'watch.sqlite', spec['watch_id'])
        try:
            report['watch_receipts'] = receiver.db.execute('SELECT COUNT(*) FROM receipts').fetchone()[0]
        finally:
            receiver.close()
        if (report['remote_jobs'], report['watch_receipts']) != (
                trace['expected_remote_jobs'], trace['expected_watch_receipts']):
            raise ValueError('Deduplication count mismatch')
        report['status'] = 'CONTRACT_VERIFIED'
    except Exception as exc:
        report['error'] = f'{type(exc).__name__}: {exc}'
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=5)
        store.close()
        report['database_sha256'] = {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                                     for p in sorted(output.glob('*.sqlite'))}
        (output / 'result.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    report = run(args.output)
    print(canonical({k: report[k] for k in ('scenario', 'status', 'acceptance')}))
    return 0 if report['status'] == 'CONTRACT_VERIFIED' else 1


if __name__ == '__main__':
    raise SystemExit(main())
