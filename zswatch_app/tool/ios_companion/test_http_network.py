"""Run native HTTP delegate tests against a local deterministic HTTP server."""
from pathlib import Path
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from collections import Counter
import subprocess
import tempfile
import threading
import time

counts = Counter()
class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        counts[self.path] += 1
        if self.path == '/late-unavailable': time.sleep(5.2)
        status = 200 if self.path == '/recover' and counts[self.path] == 2 else 429 if self.path == '/rate-limited' else 503
        data = b'recovered' if status == 200 else b'transient'
        self.send_response(status)
        self.send_header('Content-Length', str(len(data)))
        self.end_headers()
        try: self.wfile.write(data)
        except (BrokenPipeError, ConnectionResetError): pass
    def log_message(self, *args): pass

app = Path(__file__).resolve().parents[2]
server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
threading.Thread(target=server.serve_forever, daemon=True).start()
try:
    with tempfile.TemporaryDirectory() as directory:
        sdk = subprocess.check_output(['xcrun', '--show-sdk-path'], text=True).strip()
        binary = str(Path(directory) / 'http-network-tests')
        subprocess.run(['swiftc', '-I', sdk + '/usr/include/libxml2', '-lxml2',
            str(app / 'ios/Runner/CompanionJournal.swift'), str(app / 'ios/Runner/CompanionHttpRelay.swift'),
            str(Path(__file__).with_name('HttpNetworkTests.swift')), '-o', binary], check=True)
        subprocess.run([binary, 'http://127.0.0.1:' + str(server.server_port)], check=True)
        assert counts['/recover'] == 2 and counts['/unavailable'] == 2 and counts['/rate-limited'] == 1 and counts['/late-unavailable'] == 1 and counts['/cancel'] <= 1, counts
        print('PASS: independent server request counts confirm retry bounds')
finally:
    server.shutdown(); server.server_close()
