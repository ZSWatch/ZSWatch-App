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

    def test_http_metadata_is_current_bounded_and_redacted(self):
        state = self.state()
        services = 'ServiceRecord{abc u0 com.zswatch.app/' + COMPONENT + '}'
        state.update(http_enabled=False, http_pending_count=2,
                     last_http={'generation': 1, 'utc_ms': 123, 'outcome': 'written',
                                'url': 'private url', 'body': 'private body'})
        report = summarize(state, services, '123')
        self.assertFalse(report['http_enabled'])
        self.assertEqual(report['http_pending_count'], 2)
        self.assertEqual(report['last_http'], {'generation': 1, 'utc_ms': 123, 'outcome': 'written'})
        self.assertNotIn('private', str(report))
        for service, pid in [('', '123'), (services, '')]:
            absent = summarize(state, service, pid)
            self.assertEqual(absent['http_pending_count'], 0)
            self.assertIsNone(absent['last_http'])
        state['generation'] = 2
        self.assertIsNone(summarize(state, services, '123')['last_http'])
        for key, value in [('http_pending_count', True), ('http_pending_count', 5),
                           ('http_pending_count', -1), ('http_enabled', 'false')]:
            with self.assertRaises(ValueError):
                summarize({**state, key: value}, services, '123')
        state['last_http']['outcome'] = 'private body'
        with self.assertRaises(ValueError):
            summarize(state, services, '123')

    def test_only_current_selected_watch_status_is_reported_as_live(self):
        state = self.state(); state['address'] = 'watch'
        state['watch_info'] = {'address': 'watch', 'status_generation': 1, 'status_observed_ms': 123}
        services = 'ServiceRecord{abc u0 com.zswatch.app/' + COMPONENT + '}'
        self.assertEqual(summarize(state, services, '123')['watch_status_observed_utc_ms'], 123)
        for patch in [{'address': 'other'}, {'status_generation': 0}, {'status_generation': True}]:
            stale = {**state, 'watch_info': {**state['watch_info'], **patch}}
            self.assertIsNone(summarize(stale, services, '123')['watch_status_observed_utc_ms'])
        self.assertIsNone(summarize(state, '', '123')['watch_status_observed_utc_ms'])

    def test_media_receipts_are_current_ready_only_and_never_export_payload(self):
        state = self.state(); services = 'ServiceRecord{abc u0 com.zswatch.app/' + COMPONENT + '}'
        state['last_media_write'] = {'generation': 1, 'utc_ms': 123, 'track': 'private title'}
        state['last_media_control'] = {'generation': 1, 'utc_ms': 124, 'accepted': True, 'album': 'private album'}
        report = summarize(state, services, '123')
        self.assertEqual(report['last_media_write'], {'generation': 1, 'utc_ms': 123})
        self.assertTrue(report['last_media_control']['accepted'])
        self.assertNotIn('private', str(report))
        for patch, service, pid in [({'generation': 2}, services, '123'),
                                    ({'phase': 'disconnected'}, services, '123'),
                                    ({}, '', '123'), ({}, services, '')]:
            report = summarize({**state, **patch}, service, pid)
            self.assertIsNone(report['last_media_write']); self.assertIsNone(report['last_media_control'])

    def test_malformed_media_receipts_cannot_fabricate_completion(self):
        for field, value in [('generation', True), ('generation', '1'), ('utc_ms', -1),
                              ('utc_ms', True), ('accepted', 'true'), ('accepted', 1)]:
            state = self.state()
            state['last_media_control'] = {'generation': 1, 'utc_ms': 123, 'accepted': True, field: value}
            with self.assertRaises(ValueError): summarize(state, '', '')

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
