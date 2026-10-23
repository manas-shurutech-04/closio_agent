"""A fake Jira REST API for closio-agent's tests (D92): what scripts/jira-api.sh calls.

python3 -I tests/fakes/jira.py <port file> <write log>

Binds a free port on 127.0.0.1 and writes it to <port file>. Logs every write (POST, PUT) as one JSON line. The login
it takes: qa@example.com with the token tok123. Cards SCRUM-1 (To Do, a Story with an ADF description, a closed sprint,
a "relates to" link, a web link, 3 comments over two pages) and SCRUM-2 (Ready for Test); anything else is 404.
"""
import base64, json, sys
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse, parse_qs

PORT_FILE, LOG = sys.argv[1], sys.argv[2]
GOOD = "Basic " + base64.b64encode(b"qa@example.com:tok123").decode()
SF = "customfield_10020"
ADF = {"type": "doc", "version": 1, "content": [
    {"type": "heading", "attrs": {"level": 2}, "content": [{"type": "text", "text": "Acceptance Criteria"}]},
    {"type": "orderedList", "attrs": {"order": 1}, "content": [
        {"type": "listItem", "content": [{"type": "paragraph", "content": [
            {"type": "text", "text": "Given "}, {"type": "text", "text": "a scheme", "marks": [{"type": "strong"}]},
            {"type": "text", "text": " returns "}, {"type": "text", "text": "VALIDATION_ERROR", "marks": [{"type": "code"}]}]}]}]}]}
status = {"SCRUM-1": "To Do", "SCRUM-2": "Ready for Test"}

def comment(i):
    return {"id": str(10000 + i), "author": {"displayName": "QA %d" % i, "accountId": "qa-%d" % i},
            "created": "2026-10-2%dT10:15:30.000+0700" % i,
            "body": {"type": "doc", "content": [{"type": "paragraph", "content": [{"type": "text", "text": "point %d" % i}]}]}}

class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def send(self, code, obj=None):
        data = b"" if obj is None else json.dumps(obj).encode()
        self.send_response(code); self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data))); self.end_headers(); self.wfile.write(data)
    def body(self):
        n = int(self.headers.get("Content-Length") or 0)
        return json.loads(self.rfile.read(n) or b"null")
    def record(self, b):
        with open(LOG, "a") as f: f.write(json.dumps({"m": self.command, "p": urlparse(self.path).path, "b": b}) + "\n")
    def auth(self):
        if self.headers.get("Authorization") != GOOD:
            self.send(401, {"errorMessages": ["Client must be authenticated"]}); return False
        return True
    def do_GET(self):
        if not self.auth(): return
        u = urlparse(self.path); p, q = u.path, parse_qs(u.query)
        if p == "/rest/api/3/myself": return self.send(200, {"accountId": "acc-123", "displayName": "Test User"})
        if p == "/rest/api/3/field": return self.send(200, [{"id": "summary", "schema": {}}, {"id": SF, "schema": {"custom": "com.pyxis.greenhopper.jira:gh-sprint"}}])
        if p == "/rest/api/3/search/jql":
            return self.send(200, {"issues": [{"fields": {SF: [{"id": 7, "name": "Sprint 12", "state": "active"}, {"id": 8, "name": "Sprint 13", "state": "future"}]}},
                                              {"fields": {SF: [{"id": 7, "name": "Sprint 12", "state": "active"}]}}]})
        parts = p.split("/")
        if len(parts) >= 6 and parts[4] == "issue":
            key = parts[5]
            if key not in status: return self.send(404, {"errorMessages": ["Issue does not exist or you do not have permission to see it."]})
            if p.endswith("/remotelink"): return self.send(200, [{"object": {"title": "MR !12", "url": "https://gitlab/x/12"}}])
            if p.endswith("/transitions"):
                return self.send(200, {"transitions": [{"id": "21", "to": {"name": "In Development"}}, {"id": "31", "to": {"name": "Blocked"}}]})
            if p.endswith("/comment"):
                start, mx = int(q.get("startAt", ["0"])[0]), min(int(q.get("maxResults", ["50"])[0]), 2)
                allc = [comment(i) for i in range(1, 4)]
                return self.send(200, {"startAt": start, "total": 3, "comments": allc[start:start + mx]})
            return self.send(200, {"key": key, "fields": {"summary": "Scheme list filter", "issuetype": {"name": "Story"},
                "status": {"name": status[key]}, "assignee": None, "description": ADF,
                SF: [{"id": 5, "name": "Sprint 11", "state": "closed"}],
                "issuelinks": [{"type": {"inward": "is blocked by", "outward": "relates to"}, "outwardIssue": {"key": "SCRUM-2", "fields": {"status": {"name": "Done"}}}}]}})
        self.send(404, {"errorMessages": ["no route " + p]})
    def do_POST(self):
        if not self.auth(): return
        p = urlparse(self.path).path; b = self.body(); self.record(b)
        if p.endswith("/transitions"):
            if b["transition"]["id"] == "21": status["SCRUM-1"] = "In Development"
            return self.send(204)
        if p.endswith("/comment"): return self.send(201, {"id": "10050"})
        if p == "/rest/api/2/issue": return self.send(201, {"key": "SCRUM-99"})
        if p == "/rest/api/3/issueLink": return self.send(201)
        self.send(404, {"errorMessages": ["no route"]})
    def do_PUT(self):
        if not self.auth(): return
        p = urlparse(self.path).path; b = self.body(); self.record(b)
        self.send(204 if not p.endswith("/comment/10050") else 200, None if not p.endswith("/comment/10050") else {"id": "10050"})

srv = HTTPServer(("127.0.0.1", 0), H)
with open(PORT_FILE + ".tmp", "w") as f:
    f.write(str(srv.server_address[1]))
import os
os.rename(PORT_FILE + ".tmp", PORT_FILE)
srv.serve_forever()
