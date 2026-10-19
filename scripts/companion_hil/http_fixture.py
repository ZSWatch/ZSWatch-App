#!/usr/bin/env python3
"""Fixed localhost HTTP fixture; receipt counts are not companion acceptance."""

import argparse
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import signal
import threading
import time


BODY = b'{"probe":"companion-hil","ok":true}'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--port', type=int, default=18879)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if not 1024 <= args.port <= 65535:
        parser.error('Select an unprivileged TCP port')
    args.output.parent.mkdir(parents=True, exist_ok=True)
    stop = threading.Event()
    lock = threading.Lock()
    signal.signal(signal.SIGTERM, lambda *_: stop.set())
    signal.signal(signal.SIGINT, lambda *_: stop.set())
    with args.output.open('x', buffering=1) as log:
        def record(event, **fields):
            with lock:
                log.write(json.dumps({'event': event, 'monotonic': time.monotonic(),
                                      'utc': datetime.now(timezone.utc).isoformat(), **fields}) + '\n')

        class Handler(BaseHTTPRequestHandler):
            def do_GET(self):
                if self.path != '/companion-hil/ok':
                    self.send_error(404)
                    record('rejected')
                    return
                self.send_response(200)
                self.send_header('Content-Type', 'application/json; charset=utf-8')
                self.send_header('Content-Length', str(len(BODY)))
                self.end_headers()
                self.wfile.write(BODY)
                record('response', bytes=len(BODY), status=200)

            def log_message(self, *_):
                pass  # No URL, address, headers or contents in diagnostic logs.

        with ThreadingHTTPServer(('127.0.0.1', args.port), Handler) as server:
            server.timeout = 0.5
            record('listening', port=args.port, fixture_bytes=len(BODY))
            print(f'Fixed companion fixture listening on loopback port {args.port}', flush=True)
            while not stop.is_set():
                server.handle_request()
            record('stopped')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
