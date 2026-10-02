"""Explicit-trigger reference driver; no background scheduler or production API."""

import json
from http.client import HTTPException

from .server import RemoteError


TRIGGERS = {'foreground_start', 'watch_event', 'os_transfer_callback', 'scheduled_worker'}


def advance(store, identity, client, now, trigger):
    if trigger not in TRIGGERS:
        raise ValueError('An explicit execution trigger is required')
    row = store.snapshot(identity)
    spec = json.loads(row['spec'])
    if spec['backend'] != 'remote':
        raise ValueError('Remote driver cannot upload a local job')
    fence = store.claim(identity, now)
    if fence is None:
        return store.snapshot(identity)['state']
    row = store.snapshot(identity)
    try:
        if row['remote_id'] is None:
            response = client.submit(spec)
            if not store.accepted(identity, fence, now, response['remote_id']):
                return store.snapshot(identity)['state']
        else:
            response = client.status(row['remote_id'])
        if response['state'] == 'succeeded':
            store.complete(identity, fence, now, response['result'], response['remote_id'])
        elif response['state'] == 'running':
            store.defer(identity, fence, now, 10, 'server_pending')
        elif response['state'] == 'cancelled':
            store.cancel(identity, fence, now)
        elif response['state'] == 'failed':
            store.defer(identity, fence, now, 0, 'remote_failed', max_attempts=1)
        else:
            raise ValueError('Unsupported remote state')
    except RemoteError as exc:
        blocked = exc.status in (401, 403)
        permanent = 400 <= exc.status < 500 and exc.status not in (401, 403, 408, 429)
        store.defer(identity, fence, now, max(10, exc.retry_after or 0),
                    f'http_{exc.status}', blocked=blocked, max_attempts=1 if permanent else 5)
    except (OSError, HTTPException):
        store.defer(identity, fence, now, min(300, 10 * 2 ** min(row['attempts'] - 1, 5)),
                    'transport_error')
    return store.snapshot(identity)['state']
