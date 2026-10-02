"""Recovery conformance using real loopback HTTP, SQLite and process death."""

import copy
import hashlib
import json
import os
import selectors
import subprocess
import sys
import tempfile
import threading
import unittest
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from remote_jobs.contract import Receiver, Store, canonical, job_key
from remote_jobs.recovery import advance
from remote_jobs.run_fixture import run
from remote_jobs.server import Backend, Client, FixtureServer, RemoteError

FIXTURES = Path(__file__).resolve().parents[1] / 'remote_jobs/fixtures'


class RecoveryTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.root = Path(self.directory.name)
        self.spec = json.loads((FIXTURES / 'job-v1.json').read_text())
        self.result = json.loads((FIXTURES / 'result-v1.json').read_text())
        self.store = Store(self.root / 'phone.sqlite')
        self.identity = self.store.create(self.spec)
        self.backend = Backend(self.root / 'server.sqlite', self.result)
        self.server = FixtureServer(('127.0.0.1', 0), self.backend)
        self.thread = threading.Thread(target=self.server.serve_forever, kwargs={'poll_interval': 0.01})
        self.thread.start()
        self.client = Client(f'http://127.0.0.1:{self.server.server_port}')

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=5)
        self.store.close()
        self.directory.cleanup()

    def tick(self, now):
        return advance(self.store, self.identity, self.client, now, 'watch_event')

    def reopen(self):
        self.store.close()
        self.store = Store(self.root / 'phone.sqlite')

    def finish(self, now=110):
        self.tick(100)
        remote_id = self.store.snapshot(self.identity)['remote_id']
        self.client.request('/__fixture__/complete/' + remote_id, {})
        self.assertEqual(self.tick(now), 'result_ready')
        return self.store.pending(self.spec['watch_id'])[0]

    def test_accept_response_lost_resubmits_same_job_after_restart(self):
        self.client.request('/__fixture__/fault', {'fault': 'drop_after_accept'})
        self.assertEqual(self.tick(100), 'ready')
        self.assertIsNone(self.store.snapshot(self.identity)['remote_id'])
        self.reopen()
        self.assertEqual(self.tick(109), 'ready')
        self.assertEqual(self.tick(110), 'waiting_remote')
        remote_id = self.store.snapshot(self.identity)['remote_id']
        with self.backend.connect() as db:
            self.assertEqual(db.execute('SELECT COUNT(*) FROM remote_fixture_jobs').fetchone()[0], 1)
        self.assertEqual(self.client.status(remote_id)['state'], 'running')

    def test_server_complete_while_client_absent_requires_explicit_trigger(self):
        self.tick(100)
        remote_id = self.store.snapshot(self.identity)['remote_id']
        self.reopen()
        self.client.request('/__fixture__/complete/' + remote_id, {})
        # Persisted state cannot spontaneously progress, even though server is done.
        self.assertEqual(self.store.snapshot(self.identity)['state'], 'waiting_remote')
        self.assertEqual(self.store.pending(self.spec['watch_id']), [])
        self.assertEqual(self.tick(110), 'result_ready')
        self.reopen()
        self.assertEqual(len(self.store.pending(self.spec['watch_id'])), 1)

    def test_remote_server_state_survives_backend_reopen(self):
        response = self.client.submit(self.spec)
        self.backend.finish(response['remote_id'], 'succeeded')
        backend = Backend(self.root / 'server.sqlite', self.result)
        self.assertEqual(backend.status(response['remote_id'])['result'], self.result)
        self.assertEqual(backend.submit({'spec': self.spec, 'idempotency_key': self.identity})[0],
                         response['remote_id'])

    def test_rate_limit_persists_retry_after_and_bounds_retry(self):
        for now in (100, 110, 120, 130, 140):
            self.backend.fault('rate_limit')
            expected = 'failed' if now == 140 else 'ready'
            self.assertEqual(self.tick(now), expected)
            self.reopen()
            self.assertEqual(self.store.snapshot(self.identity)['next_attempt'], now + 10)
            self.assertEqual(self.tick(now + 9), expected)
        self.assertIsNone(self.store.claim(self.identity, 10000))
        with self.backend.connect() as db:
            self.assertEqual(db.execute('SELECT COUNT(*) FROM remote_fixture_jobs').fetchone()[0], 0)

    def test_credentials_block_without_poll_or_backend_fallback(self):
        self.backend.fault('auth_expired')
        self.assertEqual(self.tick(100), 'blocked')
        self.reopen()
        self.assertEqual(self.tick(10000), 'blocked')
        self.assertEqual(json.loads(self.store.snapshot(self.identity)['spec'])['backend'], 'remote')
        self.assertEqual(self.store.snapshot(self.identity)['last_error'], 'http_401')
        self.assertTrue(self.store.resume_after_credentials_refreshed(self.identity))
        self.assertFalse(self.store.resume_after_credentials_refreshed(self.identity))
        self.assertEqual(self.tick(10001), 'waiting_remote')

    def test_long_running_server_is_not_a_retry_failure(self):
        for now in range(100, 250, 10):
            self.assertEqual(self.tick(now), 'waiting_remote')
        self.assertEqual(self.store.snapshot(self.identity)['attempts'], 0)

    def test_remote_failed_is_terminal_and_preserves_input_reference(self):
        self.tick(100)
        remote_id = self.store.snapshot(self.identity)['remote_id']
        self.client.request('/__fixture__/fail/' + remote_id, {})
        self.assertEqual(self.tick(110), 'failed')
        self.assertEqual(json.loads(self.store.snapshot(self.identity)['spec']), self.spec)
        self.assertEqual(self.store.pending(self.spec['watch_id']), [])

    def test_expired_lease_and_old_callback_cannot_overwrite_new_worker(self):
        first = self.store.claim(self.identity, 100)
        self.assertIsNone(self.store.claim(self.identity, 129))
        self.reopen()
        second = self.store.claim(self.identity, 130)
        self.assertGreater(second, first)
        self.assertFalse(self.store.accepted(self.identity, first, 131, 'old'))
        self.assertFalse(self.store.cancel(self.identity, first, 131))
        self.assertTrue(self.store.accepted(self.identity, second, 131, 'new'))
        self.assertFalse(self.store.complete(self.identity, first, 131, self.result, 'old'))
        self.assertTrue(self.store.complete(self.identity, second, 131, self.result, 'new'))

    def test_concurrent_workers_cannot_both_claim_the_same_job(self):
        barrier = threading.Barrier(2)
        def worker():
            store = Store(self.root / 'phone.sqlite')
            try:
                barrier.wait(timeout=5)
                return store.claim(self.identity, 100)
            finally:
                store.close()
        with ThreadPoolExecutor(max_workers=2) as pool:
            futures = [pool.submit(worker) for _ in range(2)]
            results = [future.result(timeout=5) for future in futures]
        self.assertCountEqual(results, [1, None])

    def test_completion_rejects_wrong_remote_id_and_expired_lease(self):
        fence = self.store.claim(self.identity, 100)
        self.store.accepted(self.identity, fence, 100, 'correct')
        with self.assertRaises(ValueError):
            self.store.complete(self.identity, fence, 101, self.result, 'wrong')
        self.assertFalse(self.store.complete(self.identity, fence, 130, self.result, 'correct'))
        self.assertEqual(self.store.pending(self.spec['watch_id']), [])

    def test_cancel_rejects_late_response_even_when_remote_finishes(self):
        fence = self.store.claim(self.identity, 100)
        response = self.client.submit(self.spec)
        self.store.accepted(self.identity, fence, 100, response['remote_id'])
        self.store.cancel(self.identity)
        self.backend.finish(response['remote_id'], 'succeeded')
        self.assertFalse(self.store.complete(self.identity, fence, 101, self.result, response['remote_id']))
        self.assertEqual(self.tick(1000), 'cancelled')
        self.assertEqual(self.store.pending(self.spec['watch_id']), [])

    def test_cancel_drops_unsent_outbox_and_does_not_accept_late_ack(self):
        delivery = self.finish()
        self.store.cancel(self.identity)
        self.assertEqual(self.store.pending(self.spec['watch_id']), [])
        self.assertFalse(self.store.acknowledge(self.spec['watch_id'], delivery['result_id']))

    def test_new_generation_invalidates_old_lease_and_outbox(self):
        delivery = self.finish()
        new = dict(self.spec, generation=2, model='replacement-model')
        replacement = self.store.create(new)
        self.assertNotEqual(replacement, self.identity)
        self.assertEqual(self.store.snapshot(self.identity)['state'], 'cancelled')
        self.assertEqual(self.store.pending(self.spec['watch_id']), [])
        self.assertFalse(self.store.acknowledge(self.spec['watch_id'], delivery['result_id']))
        with self.assertRaises(ValueError):
            self.store.create(self.spec)

    def test_changed_backend_requires_new_generation_and_no_upload_of_local_job(self):
        with self.assertRaises(ValueError):
            self.store.create(dict(self.spec, model='changed'))
        local_spec = dict(self.spec, backend='local', provider='device', upload_authorized=False, generation=2)
        local_id = self.store.create(local_spec)
        with self.assertRaises(ValueError):
            advance(self.store, local_id, self.client, 100, 'watch_event')
        fence = self.store.claim(local_id, 100)
        self.assertTrue(self.store.complete(local_id, fence, 100, self.result))
        self.assertIsNone(self.store.snapshot(local_id)['remote_id'])

    def test_atomic_result_and_outbox_on_exception_before_commit(self):
        fence = self.store.claim(self.identity, 100)
        self.store.accepted(self.identity, fence, 100, 'remote')
        def abort():
            raise RuntimeError('Injected failure before commit')
        with self.assertRaises(RuntimeError):
            self.store.complete(self.identity, fence, 101, self.result, 'remote', before_commit=abort)
        self.reopen()
        self.assertEqual(self.store.snapshot(self.identity)['state'], 'waiting_remote')
        self.assertIsNone(self.store.snapshot(self.identity)['result'])
        self.assertEqual(self.store.pending(self.spec['watch_id']), [])

    @unittest.skipIf(os.name == 'nt', 'POSIX kill fault injection')
    def test_real_process_kill_before_commit_releases_lease_after_expiry(self):
        self.kill_at_boundary('before_commit')
        self.assertEqual(self.store.snapshot(self.identity)['state'], 'waiting_remote')
        self.assertEqual(self.store.pending(self.spec['watch_id']), [])
        recovered = self.store.claim(self.identity, 130)
        self.assertTrue(self.store.complete(self.identity, recovered, 131, self.result, 'remote'))
        self.assertEqual(len(self.store.pending(self.spec['watch_id'])), 1)

    @unittest.skipIf(os.name == 'nt', 'POSIX kill fault injection')
    def test_real_process_kill_after_commit_preserves_result_and_outbox(self):
        self.kill_at_boundary('after_commit')
        self.assertEqual(self.store.snapshot(self.identity)['state'], 'result_ready')
        self.assertEqual(json.loads(self.store.snapshot(self.identity)['result']), self.result)
        self.assertEqual(len(self.store.pending(self.spec['watch_id'])), 1)
        self.assertIsNone(self.store.claim(self.identity, 10000))

    def kill_at_boundary(self, boundary):
        fence = self.store.claim(self.identity, 100)
        self.store.accepted(self.identity, fence, 100, 'remote')
        script = '''
import json, sys, time
from remote_jobs.contract import Store
store = Store(sys.argv[1])
def stop():
    print('BOUNDARY', flush=True)
    time.sleep(30)
store.complete(sys.argv[2], int(sys.argv[3]), 101, json.loads(sys.argv[4]),
               'remote', before_commit=stop if sys.argv[5] == 'before_commit' else None)
if sys.argv[5] == 'after_commit':
    stop()
'''
        env = dict(os.environ, PYTHONPATH=str(FIXTURES.parent.parent))
        process = subprocess.Popen([sys.executable, '-c', script, str(self.root / 'phone.sqlite'),
                                    self.identity, str(fence), canonical(self.result), boundary],
                                   env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        try:
            with selectors.DefaultSelector() as selector:
                selector.register(process.stdout, selectors.EVENT_READ)
                self.assertTrue(selector.select(timeout=5), 'Child did not reach transaction boundary')
            self.assertEqual(process.stdout.readline().strip(), b'BOUNDARY')
            process.kill()
            _, errors = process.communicate(timeout=5)
            self.assertEqual(errors, b'')
            self.reopen()
        finally:
            if process.poll() is None:
                process.kill()
            process.communicate(timeout=5)

    def test_ack_lost_replay_is_one_receipt_after_both_processes_reopen(self):
        delivery = self.finish()
        payload = json.loads(delivery['payload'])
        receiver = Receiver(self.root / 'watch.sqlite', self.spec['watch_id'])
        try:
            ack = receiver.receive(payload)  # Lose this first ACK.
        finally:
            receiver.close()
        self.reopen()
        receiver = Receiver(self.root / 'watch.sqlite', self.spec['watch_id'])
        try:
            replay = json.loads(self.store.pending(self.spec['watch_id'])[0]['payload'])
            self.assertEqual(replay, payload)
            self.assertEqual(receiver.receive(replay), ack)
            self.assertEqual(receiver.db.execute('SELECT COUNT(*) FROM receipts').fetchone()[0], 1)
            conflict = copy.deepcopy(payload)
            conflict['result']['summary'] = 'different'
            with self.assertRaises(ValueError):
                receiver.receive(conflict)
        finally:
            receiver.close()
        self.assertFalse(self.store.acknowledge('another-watch', ack['result_id']))
        self.assertFalse(self.store.acknowledge(self.spec['watch_id'], 'unknown-result'))
        self.assertFalse(self.store.acknowledge(ack['watch_id'], ack['result_id'], 'rejected'))
        self.assertEqual(self.store.snapshot(self.identity)['state'], 'result_ready')
        self.assertTrue(self.store.acknowledge(ack['watch_id'], ack['result_id']))
        self.assertTrue(self.store.acknowledge(ack['watch_id'], ack['result_id']))
        self.reopen()
        self.assertEqual(self.store.pending(self.spec['watch_id']), [])
        self.assertEqual(self.store.snapshot(self.identity)['state'], 'delivered')

    def test_receiver_rejects_other_watch_and_old_generation_after_replacement(self):
        old_payload = json.loads(self.finish()['payload'])
        replacement = self.store.create(dict(self.spec, generation=2))
        fence = self.store.claim(replacement, 120)
        self.store.accepted(replacement, fence, 120, 'remote-new')
        self.store.complete(replacement, fence, 120, self.result, 'remote-new')
        new_payload = json.loads(self.store.pending(self.spec['watch_id'])[0]['payload'])
        receiver = Receiver(self.root / 'watch.sqlite', self.spec['watch_id'])
        try:
            receiver.receive(new_payload)
            with self.assertRaises(ValueError):
                receiver.receive(old_payload)
            with self.assertRaises(ValueError):
                receiver.receive(dict(new_payload, watch_id='other-watch'))
            conflicting = dict(new_payload, job_id='conflicting-job')
            conflicting['result_id'] = hashlib.sha256(b'result-v1:conflicting-job').hexdigest()
            with self.assertRaises(ValueError):
                receiver.receive(conflicting)
            self.assertEqual(receiver.db.execute('SELECT COUNT(*) FROM receipts').fetchone()[0], 1)
        finally:
            receiver.close()

    def test_duplicate_completion_does_not_create_second_outbox(self):
        fence = self.store.claim(self.identity, 100)
        self.store.accepted(self.identity, fence, 100, 'remote')
        self.assertTrue(self.store.complete(self.identity, fence, 100, self.result, 'remote'))
        self.assertFalse(self.store.complete(self.identity, fence, 101, self.result, 'remote'))
        self.assertEqual(len(self.store.pending(self.spec['watch_id'])), 1)

    def test_bad_result_does_not_commit_and_unsupported_version_rejected(self):
        fence = self.store.claim(self.identity, 100)
        self.store.accepted(self.identity, fence, 100, 'remote')
        for result in (dict(self.result, version=2), dict(self.result, summary=''),
                       dict(self.result, actions=[{'type': 'execute_shell', 'title': 'bad'}])):
            with self.assertRaises(ValueError):
                self.store.complete(self.identity, fence, 100, result, 'remote')
        self.assertEqual(self.store.snapshot(self.identity)['state'], 'waiting_remote')
        self.assertEqual(self.store.pending(self.spec['watch_id']), [])

    def test_fixture_server_and_client_reject_non_loopback(self):
        with self.assertRaises(ValueError):
            FixtureServer(('0.0.0.0', 0), self.backend)
        with self.assertRaises(ValueError):
            Client('https://real-provider.example')

    def test_no_trigger_or_unauthorized_upload_rejected_before_network(self):
        with self.assertRaises(ValueError):
            advance(self.store, self.identity, self.client, 100, 'timer_assumed_to_wake_ios')
        with self.assertRaises(ValueError):
            self.client.submit(dict(self.spec, upload_authorized=False))
        self.assertEqual(self.store.snapshot(self.identity)['attempts'], 0)

    def test_shared_golden_trace_over_http_survives_reopens_and_lost_ack(self):
        output = self.root / 'golden-replay'
        report = run(output)
        self.assertEqual(report['status'], 'CONTRACT_VERIFIED', report.get('error'))
        self.assertEqual(report['acceptance'], 'NOT_RUN')
        self.assertEqual((report['remote_jobs'], report['watch_receipts']), (1, 1))
        self.assertEqual(len(report['events']), 13)
        with self.assertRaises(FileExistsError):
            run(output)


if __name__ == '__main__':
    unittest.main()
