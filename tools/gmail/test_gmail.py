"""The Gmail MCP server against a fake Gmail: nothing here touches the network.

  python -m unittest tools/gmail/test_gmail.py
"""

import base64
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import gmail_mcp  # noqa: E402

post = gmail_mcp.post


def b64(text):
    return base64.urlsafe_b64encode(text.encode()).decode().rstrip("=")


class FakeGmail:
    """Answers the calls the server makes, and remembers them."""

    def __init__(self):
        self.calls = []
        self.labels = [{"id": "INBOX", "name": "INBOX"}, {"id": "UNREAD", "name": "UNREAD"}]

    def __call__(self, method, url, data=None, headers=None, form=False):
        path = url.replace(gmail_mcp.API, "")
        self.calls.append((method, path, data))
        assert headers["Authorization"] == "Bearer tok"
        if path == "/profile":
            return {}, {"emailAddress": "critter@example.com"}
        if path.startswith("/messages?"):
            return {}, {"messages": [{"id": "m1", "threadId": "t1"}]}
        if path.startswith("/messages/m1?format=metadata"):
            return {}, {"id": "m1", "threadId": "t1", "snippet": "hello there",
                        "payload": {"headers": [{"name": "From", "value": "A <a@x.com>"},
                                                {"name": "Subject", "value": "Hi"},
                                                {"name": "Message-ID", "value": "<abc@x.com>"}]}}
        if path == "/messages/m1?format=full":
            return {}, {"id": "m1", "threadId": "t1", "labelIds": ["INBOX"], "payload": {
                "mimeType": "multipart/alternative", "headers": [{"name": "Subject", "value": "Hi"}],
                "parts": [{"mimeType": "text/html", "body": {"data": b64("<p>html</p>")}},
                          {"mimeType": "text/plain", "body": {"data": b64("plain body")}}]}}
        if path == "/labels" and method == "GET":
            return {}, {"labels": self.labels}
        if path == "/labels" and method == "POST":
            self.labels.append({"id": "L9", "name": data["name"]})
            return {}, {"id": "L9"}
        if path == "/messages/m1/modify":
            return {}, {"id": "m1", "labelIds": data["addLabelIds"]}
        if path == "/drafts":
            return {}, {"id": "d1", "message": {"id": "m2"}}
        if path == "/drafts/send":
            return {}, {"id": "m3"}
        raise AssertionError(f"unexpected {method} {path}")


class GmailTest(unittest.TestCase):
    def setUp(self):
        self.dir = Path(tempfile.mkdtemp())
        self.cfg = {"_dir": str(self.dir), "gmail": {"account": "critter@example.com"}}
        (self.dir / "tokens.json").write_text(json.dumps({"google": {
            "access_token": "tok", "refresh_token": "r", "expires_in": 3600, "saved": time.time(),
            "account": "critter@example.com"}}))
        self.fake = FakeGmail()
        self.real_call = post.call
        post.call = self.fake

    def tearDown(self):
        post.call = self.real_call
        shutil.rmtree(self.dir, ignore_errors=True)

    def tool(self, name, args):
        r = gmail_mcp.handle({"jsonrpc": "2.0", "id": 1, "method": "tools/call",
                              "params": {"name": name, "arguments": args}}, lambda: self.cfg)
        res = r["result"]
        text = res["content"][0]["text"]
        return (text if res.get("isError") else json.loads(text)), res.get("isError", False)

    def test_handshake(self):
        init = gmail_mcp.handle({"jsonrpc": "2.0", "id": 0, "method": "initialize",
                                 "params": {"protocolVersion": "2025-06-18"}})
        self.assertEqual(init["result"]["serverInfo"]["name"], "gmail-critter")
        self.assertIsNone(gmail_mcp.handle({"jsonrpc": "2.0", "method": "notifications/initialized"}))
        tools = gmail_mcp.handle({"jsonrpc": "2.0", "id": 2, "method": "tools/list"})["result"]["tools"]
        self.assertEqual([t["name"] for t in tools], ["search", "read", "labels", "label", "draft", "send"])
        self.assertIn("error", gmail_mcp.handle({"jsonrpc": "2.0", "id": 3, "method": "nope"}))

    def test_search_and_read(self):
        out, err = self.tool("search", {"query": "is:unread"})
        self.assertFalse(err)
        self.assertEqual(out["messages"][0]["subject"], "Hi")
        self.assertEqual(out["account"], "critter@example.com")
        out, _ = self.tool("read", {"id": "m1"})
        self.assertEqual(out["body"], "plain body")

    def test_send_is_off_by_default(self):
        out, _ = self.tool("send", {"draft_id": "d1"})
        self.assertFalse(out["sent"])
        self.assertFalse(any(c[1] == "/drafts/send" for c in self.fake.calls))
        self.cfg["gmail"]["send"] = True
        out, _ = self.tool("send", {"draft_id": "d1"})
        self.assertTrue(out["sent"])

    def test_other_account_refused(self):
        self.cfg["gmail"]["account"] = "someone.else@example.com"
        text, err = self.tool("search", {"query": "x"})
        self.assertTrue(err)
        self.assertIn("not someone.else@example.com", text)
        self.assertEqual(self.fake.calls, [])

    def test_draft_reply_threads(self):
        out, _ = self.tool("draft", {"to": "a@x.com", "subject": "Re: Hi", "body": "Thanks!", "reply_to": "m1"})
        self.assertEqual(out["draft_id"], "d1")
        sent = [c for c in self.fake.calls if c[1] == "/drafts"][0][2]["message"]
        self.assertEqual(sent["threadId"], "t1")
        raw = base64.urlsafe_b64decode(sent["raw"]).decode()
        self.assertIn("In-Reply-To: <abc@x.com>", raw)
        self.assertIn("From: critter@example.com", raw)
        self.assertIn("Thanks!", raw)

    def test_label_creates_new(self):
        out, _ = self.tool("label", {"id": "m1", "add": ["Creators"], "remove": ["UNREAD"]})
        self.assertEqual(out["labels"], ["L9"])
        _, err = self.tool("label", {"id": "m1", "remove": ["Nonexistent"]})
        self.assertTrue(err)

    def test_stdio(self):
        cfg = self.dir / "config.json"
        cfg.write_text(json.dumps({"queue": str(self.dir)}))
        lines = "\n".join(json.dumps(x) for x in [
            {"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {}},
            {"jsonrpc": "2.0", "method": "notifications/initialized"},
            {"jsonrpc": "2.0", "id": 2, "method": "tools/list"}]) + "\n"
        out = subprocess.run([sys.executable, str(HERE / "gmail_mcp.py")], input=lines, capture_output=True,
                             text=True, env={**os.environ, "CRITTER_POST_CONFIG": str(cfg)}, timeout=20)
        replies = [json.loads(l) for l in out.stdout.splitlines() if l.strip()]
        self.assertEqual([r["id"] for r in replies], [1, 2])
        self.assertEqual(len(replies[1]["result"]["tools"]), 6)


class SharedSignInTest(unittest.TestCase):
    def test_client_file_and_one_token(self):
        d = Path(tempfile.mkdtemp())
        (d / "client.json").write_text(json.dumps({"installed": {"client_id": "cid", "client_secret": "sec"}}))
        cfg = {"_dir": str(d), "google": {"client_file": str(d / "client.json")}}
        self.assertEqual(post.google_app(cfg), ("cid", "sec"))
        (d / "tokens.json").write_text(json.dumps({"google": {"access_token": "A", "expires_in": 3600, "saved": time.time()}}))
        self.assertEqual(post.fresh_token(cfg, "youtube"), "A")   # YouTube and Gmail share the one token
        self.assertEqual(post.fresh_token(cfg, "gmail"), "A")
        shutil.rmtree(d, ignore_errors=True)


if __name__ == "__main__":
    unittest.main()
