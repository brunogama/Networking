#!/usr/bin/env python3
"""Small deterministic HTTP/1.1 origin for the local Caddy protocol proxy."""

import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

REQUEST_BODY = b"r" * 1024
DOWNLOAD_BODY = b"d" * (1024 * 1024)
EVENT_COUNT = 1_000
EVENT_LINE = b"data: 0123456789abcdef0123456789abcdef\n\n"
UPLOAD_CHUNK_SIZE = 128 * 1024
# Throttle only batch uploads so URLSession emits multiple progress updates.
UPLOAD_CHUNK_DELAY_SECONDS = 0.001


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def do_GET(self):
        if self.path == "/health":
            self.respond(b"ok")
        elif self.path == "/request":
            self.respond(REQUEST_BODY)
        elif self.path == "/download":
            self.respond(DOWNLOAD_BODY)
        elif self.path == "/sse":
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream")
            self.send_header("Cache-Control", "no-cache")
            self.send_header("Content-Length", str(len(EVENT_LINE) * EVENT_COUNT))
            self.end_headers()
            try:
                for _ in range(EVENT_COUNT):
                    self.wfile.write(EVENT_LINE)
                    self.wfile.flush()
            except (BrokenPipeError, ConnectionResetError):
                self.close_connection = True
        else:
            self.respond(b"not found", 404)

    def do_POST(self):
        body_size = int(self.headers.get("Content-Length", "0"))
        if self.path == "/batch-upload":
            if not self.consume_slowly(body_size):
                self.respond(b"incomplete upload", 400)
                return
            self.respond(b"ok")
            return
        body = self.rfile.read(body_size)
        self.respond(body)

    def consume_slowly(self, body_size):
        remaining = body_size
        while remaining:
            chunk_size = min(UPLOAD_CHUNK_SIZE, remaining)
            chunk = self.rfile.read(chunk_size)
            if not chunk:
                return False
            remaining -= len(chunk)
            time.sleep(UPLOAD_CHUNK_DELAY_SECONDS)
        return True

    def respond(self, body, status=200):
        self.send_response(status)
        self.send_header("Content-Type", "application/octet-stream")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        return


with ThreadingHTTPServer(("127.0.0.1", 8181), Handler) as server:
    print("benchmark origin listening on 127.0.0.1:8181", flush=True)
    server.serve_forever()
