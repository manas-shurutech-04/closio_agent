"""A fake HTTP server for closio-agent's tests (D92): GitLab, WS1, WS2, anything answered from a list of routes.

python3 -I tests/fakes/http.py <port file> <request log> <routes file>

Binds a free port on 127.0.0.1 and writes it to <port file>. The routes file (JSON, read again at every request, so a
test can change it between calls) is a list of {"method": "GET" or "*", "path": "<regex on the path>", optional
"query": "<regex on the query>", optional "need_header": ["<name>", "<value>"] (else 401), "status": 200, "json": …
or "text": "…", optional "headers": {…}, optional "times": n (used n times, then skipped), optional "delay": seconds}.
The first route that fits answers; none: 404 {"message": "no route"}. Every request is logged as one JSON line:
{"m": method, "p": path, "q": query, "h": headers, "b": the body (JSON when it parses, else text)}.
"""
import json
import re
import sys
import time
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse

PORT_FILE, LOG, ROUTES = sys.argv[1], sys.argv[2], sys.argv[3]
used = {}


class H(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *a):
        pass

    def handle_any(self):
        u = urlparse(self.path)
        n = int(self.headers.get("Content-Length") or 0)
        raw = self.rfile.read(n) if n else b""
        try:
            body = json.loads(raw) if raw else None
        except ValueError:
            body = raw.decode("utf-8", "replace")
        with open(LOG, "a") as f:
            f.write(json.dumps({"m": self.command, "p": u.path, "q": u.query, "h": dict(self.headers), "b": body}) + "\n")
        try:
            routes = json.load(open(ROUTES))
        except (OSError, ValueError):
            routes = []
        for i, r in enumerate(routes):
            if r.get("method", "*") not in ("*", self.command):
                continue
            if not re.search(r.get("path", ".*"), u.path):
                continue
            if "query" in r and not re.search(r["query"], u.query):
                continue
            if "times" in r and used.get(i, 0) >= r["times"]:
                continue
            used[i] = used.get(i, 0) + 1
            if "need_header" in r and self.headers.get(r["need_header"][0]) != r["need_header"][1]:
                return self.answer(401, {"message": "401 Unauthorized"}, None, {})
            if r.get("delay"):
                time.sleep(r["delay"])
            return self.answer(r.get("status", 200), r.get("json"), r.get("text"), r.get("headers", {}))
        self.answer(404, {"message": "no route for %s %s" % (self.command, u.path)}, None, {})

    def answer(self, status, js, text, headers):
        data = (json.dumps(js) if js is not None else (text or "")).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json" if js is not None else "text/plain")
        for k, v in headers.items():
            self.send_header(k, v)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    do_GET = do_POST = do_PUT = do_PATCH = do_DELETE = do_HEAD = handle_any


srv = HTTPServer(("127.0.0.1", 0), H)
with open(PORT_FILE + ".tmp", "w") as f:
    f.write(str(srv.server_address[1]))
import os
os.rename(PORT_FILE + ".tmp", PORT_FILE)
srv.serve_forever()
