import unittest
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from native_runtime_probe import COMPONENT, summarize, summarize_jobs
import json
import hashlib


class NativeRuntimeProbeTests(unittest.TestCase):
    def state(self):
        return {'version': 1, 'generation': 1, 'desired_running': True, 'phase': 'ready',
                'notification_packages': ['com.zswatch.app'], 'notifications': {}}

    def test_ready_requires_live_service_and_running_intent(self):
        services = 'ServiceRecord{abc u0 com.zswatch.app/' + COMPONENT + '}'
        self.assertTrue(summarize(self.state(), services, '123', 'ready')['protocol_ready'])
        for service, pid in [('', '123'), (services, '')]:
            with self.assertRaises(ValueError):
                summarize(self.state(), service, pid, 'ready')
        state = self.state(); state['desired_running'] = False
        with self.assertRaises(ValueError):
            summarize(state, services, '123', 'ready')

    def test_android_stringified_allowlist_is_rejected(self):
        state = self.state(); state['notification_packages'] = '[com.zswatch.app]'
        with self.assertRaises(ValueError):
            summarize(state, '', '')

    def test_stop_requires_released_service_and_cleared_content(self):
        state = self.state(); state.update(desired_running=False, phase='stopped')
        self.assertFalse(summarize(state, '', '123', 'stopped')['protocol_ready'])
        state['notifications'] = {'private-key': {'packet': 'private text'}}
        with self.assertRaises(ValueError):
            summarize(state, '', '123', 'stopped')

    def test_report_redacts_notification_keys_and_content(self):
        state = self.state()
        state['notifications'] = {'private-key': {'packet': 'private text', 'id': 1000000}}
        report = str(summarize(state, '', ''))
        self.assertNotIn('private-key', report); self.assertNotIn('private text', report)
        self.assertIn('NOT_RUN', report)

    def test_committed_result_requires_a_matching_outbox_and_redacts_text(self):
        spec = {'watch_id': 'test'}
        identity = hashlib.sha256(json.dumps(spec, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
        result_id = hashlib.sha256(('result-v1:' + identity).encode()).hexdigest()
        job = {'spec': spec, 'state': 'result_ready', 'result': {'summary': 'private text'}}
        state = {'version': 1, 'jobs': {identity: job}, 'outbox': {}}
        with self.assertRaises(ValueError):
            summarize_jobs(state)
        payload = {'result_id': result_id, 'job_id': identity, 'watch_id': 'test', 'result': job['result']}
        state['outbox'][result_id] = {'job_id': identity, 'payload': json.dumps(payload), 'state': 'pending'}
        report = summarize_jobs(state)
        self.assertEqual(report['pending_result_count'], 1)
        self.assertNotIn('private text', str(report))
        job['state'] = 'delivered'
        with self.assertRaises(ValueError):
            summarize_jobs(state)
