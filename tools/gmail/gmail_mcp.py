"""Gmail for the project's own Google account, as a local MCP server (stdio).

Tools: search, read, labels, label, draft, send. It signs in with the same
Google token as tools/post (python tools/post/post.py auth google), so one
Google Cloud project and one consent cover YouTube uploads and this mail.

Two guards:
- **One account.** If the config names "gmail": {"account": ...}, every call
  checks the signed-in address against it and refuses any other.
- **Sending is off** until the config says "gmail": {"send": true}. Until
  then send refuses, and drafts wait in Gmail's Drafts for a person to read
  and send. Claude Code also asks before each tool call unless allowed.

Register it for one project only (local scope), e.g.
  claude mcp add --scope local gmail-critter -- python C:/path/to/tools/gmail/gmail_mcp.py

The config and tokens are tools/post's (~/critter-post/config.json and
tokens.json, or CRITTER_POST_CONFIG), never in this repo. Stdlib only.
"""

import base64
import email.message
import email.utils
import json
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "post"))
import post  # noqa: E402

API = "https://gmail.googleapis.com/gmail/v1/users/me"
PROTOCOL = "2025-06-18"

TOOLS = [
    {"name": "search", "description": "Search the mailbox with Gmail's search syntax (e.g. 'is:unread', "
     "'from:someone newer_than:7d'). Returns id, thread, date, from, subject and a snippet for each.",
     "inputSchema": {"type": "object", "properties": {
         "query": {"type": "string"}, "max": {"type": "integer", "minimum": 1, "maximum": 50}},
         "required": ["query"]}},
    {"name": "read", "description": "One message in full: headers, labels and its plain-text body.",
     "inputSchema": {"type": "object", "properties": {"id": {"type": "string"}}, "required": ["id"]}},
    {"name": "labels", "description": "Every label, with its id.",
     "inputSchema": {"type": "object", "properties": {}}},
    {"name": "label", "description": "Add or remove labels on a message, by label name (created if new). "
     "Remove UNREAD to mark read, INBOX to archive.",
     "inputSchema": {"type": "object", "properties": {
         "id": {"type": "string"}, "add": {"type": "array", "items": {"type": "string"}},
         "remove": {"type": "array", "items": {"type": "string"}}}, "required": ["id"]}},
    {"name": "draft", "description": "Write a draft (plain text). Give reply_to (a message id) to answer "
     "in its thread. It waits in Drafts; nothing is sent.",
     "inputSchema": {"type": "object", "properties": {
         "to": {"type": "string"}, "subject": {"type": "string"}, "body": {"type": "string"},
         "reply_to": {"type": "string"}}, "required": ["to", "subject", "body"]}},
    {"name": "send", "description": "Send a draft by its id. Refused unless sending is switched on in the "
     "config by the account's owner.",
     "inputSchema": {"type": "object", "properties": {"draft_id": {"type": "string"}}, "required": ["draft_id"]}},
]


def load_config():
    path = Path(os.environ.get("CRITTER_POST_CONFIG", post.DEFAULT_CONFIG))
    cfg = json.loads(path.read_text(encoding="utf-8"))
    cfg["_dir"] = str(path.parent)
    return cfg


def gmail(cfg, method, path, data=None):
    token = post.fresh_token(cfg, "gmail")
    return post.call(method, API + path, data, {"Authorization": f"Bearer {token}"})[1]


def check_account(cfg):
    """The signed-in address, refused if the config names a different one."""
    want = cfg.get("gmail", {}).get("account", "").lower()
    have = post.load_tokens(cfg).get("google", {}).get("account", "")
    if not have:
        have = gmail(cfg, "GET", "/profile").get("emailAddress", "")
    if want and have.lower() != want:
        raise RuntimeError(f"signed in as {have}, not {want}; run post.py auth google with {want}")
    return have


def header(msg, name):
    for h in msg.get("payload", {}).get("headers", []):
        if h["name"].lower() == name.lower():
            return h["value"]
    return ""


def find_body(part, mime):
    data = part.get("body", {}).get("data")
    if part.get("mimeType", "") == mime and data:
        return base64.urlsafe_b64decode(data + "==").decode("utf-8", "replace")
    for sub in part.get("parts", []):
        text = find_body(sub, mime)
        if text:
            return text
    return ""


def plain_text(part):
    """The first text/plain body in a message's parts; failing that, its HTML with the tags taken out."""
    return find_body(part, "text/plain") or re.sub(r"\s+\n", "\n", re.sub(r"<[^>]+>", "", find_body(part, "text/html")))


def label_ids(cfg, names, create=False):
    have = {l["name"].lower(): l["id"] for l in gmail(cfg, "GET", "/labels").get("labels", [])}
    out = []
    for n in names:
        if n.lower() in have:
            out.append(have[n.lower()])
        elif create:
            out.append(gmail(cfg, "POST", "/labels", {"name": n})["id"])
        else:
            raise RuntimeError(f"no label called {n}")
    return out


def run_tool(cfg, name, args):
    account = check_account(cfg)
    if name == "search":
        found = gmail(cfg, "GET", "/messages?" + post.urllib.parse.urlencode(
            {"q": args["query"], "maxResults": min(int(args.get("max", 10)), 50)}))
        rows = []
        for m in found.get("messages", []):
            full = gmail(cfg, "GET", f"/messages/{m['id']}?format=metadata"
                         "&metadataHeaders=From&metadataHeaders=Subject&metadataHeaders=Date")
            rows.append({"id": m["id"], "thread": m["threadId"], "date": header(full, "Date"),
                         "from": header(full, "From"), "subject": header(full, "Subject"),
                         "snippet": full.get("snippet", "")})
        return {"account": account, "messages": rows}
    if name == "read":
        m = gmail(cfg, "GET", f"/messages/{args['id']}?format=full")
        return {"id": m["id"], "thread": m["threadId"], "labels": m.get("labelIds", []),
                "from": header(m, "From"), "to": header(m, "To"), "date": header(m, "Date"),
                "subject": header(m, "Subject"), "body": plain_text(m.get("payload", {}))[:20000]}
    if name == "labels":
        return [{"id": l["id"], "name": l["name"]} for l in gmail(cfg, "GET", "/labels").get("labels", [])]
    if name == "label":
        body = {"addLabelIds": label_ids(cfg, args.get("add", []), create=True),
                "removeLabelIds": label_ids(cfg, args.get("remove", []))}
        m = gmail(cfg, "POST", f"/messages/{args['id']}/modify", body)
        return {"id": m["id"], "labels": m.get("labelIds", [])}
    if name == "draft":
        msg = email.message.EmailMessage()
        msg["To"] = args["to"]
        msg["From"] = account
        msg["Subject"] = args["subject"]
        msg["Date"] = email.utils.formatdate(localtime=True)
        msg.set_content(args["body"])
        message = {}
        if args.get("reply_to"):
            orig = gmail(cfg, "GET", f"/messages/{args['reply_to']}?format=metadata"
                         "&metadataHeaders=Message-ID&metadataHeaders=References")
            mid = header(orig, "Message-ID")
            if mid:
                msg["In-Reply-To"] = mid
                msg["References"] = (header(orig, "References") + " " + mid).strip()
            message["threadId"] = orig["threadId"]
        message["raw"] = base64.urlsafe_b64encode(msg.as_bytes()).decode()
        d = gmail(cfg, "POST", "/drafts", {"message": message})
        return {"draft_id": d["id"], "message_id": d["message"]["id"], "note": "Saved in Drafts; not sent."}
    if name == "send":
        if not cfg.get("gmail", {}).get("send", False):
            return {"sent": False, "note": "Sending is switched off for this account. The draft is in Drafts "
                    "for the owner to read and send, or to switch sending on in the config."}
        r = gmail(cfg, "POST", "/drafts/send", {"id": args["draft_id"]})
        return {"sent": True, "message_id": r["id"]}
    raise RuntimeError(f"no tool called {name}")


def handle(req, cfg_loader=load_config):
    """One JSON-RPC request in, its response out (None for a notification)."""
    rid = req.get("id")
    method = req.get("method", "")
    if rid is None:
        return None   # notifications/initialized and the like
    if method == "initialize":
        result = {"protocolVersion": req.get("params", {}).get("protocolVersion", PROTOCOL),
                  "capabilities": {"tools": {}},
                  "serverInfo": {"name": "gmail-critter", "version": "1.0"}}
    elif method == "ping":
        result = {}
    elif method == "tools/list":
        result = {"tools": TOOLS}
    elif method == "tools/call":
        p = req.get("params", {})
        try:
            out = run_tool(cfg_loader(), p.get("name", ""), p.get("arguments") or {})
            result = {"content": [{"type": "text", "text": json.dumps(out, indent=1, ensure_ascii=False)}]}
        except Exception as e:   # the error goes back to the caller as text, not a crash
            result = {"content": [{"type": "text", "text": f"{type(e).__name__}: {e}"}], "isError": True}
    else:
        return {"jsonrpc": "2.0", "id": rid, "error": {"code": -32601, "message": f"no method {method}"}}
    return {"jsonrpc": "2.0", "id": rid, "result": result}


def main():
    sys.stdin.reconfigure(encoding="utf-8")
    sys.stdout.reconfigure(encoding="utf-8", newline="\n")   # one JSON message per line, no \r
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            req = json.loads(line)
        except json.JSONDecodeError:
            continue
        resp = handle(req)
        if resp is not None:
            sys.stdout.write(json.dumps(resp) + "\n")
            sys.stdout.flush()


if __name__ == "__main__":
    main()
