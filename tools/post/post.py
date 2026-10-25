"""The posting queue: staged clips, captions and a schedule, with a review gate.

Each post is one Markdown file in the queue folder: the clip, the time, the
platforms and the hashtags at the top, the caption below, and two tick boxes.
Nothing is published until "- [x] approve" is ticked by a person, the post's
time has come, and the run is live; a run is a dry run (it prints and logs
exactly what it would send) unless --live is given AND the platform is listed
in the config's "live". So the review step can be done from any editor or
phone that syncs the folder, and a dry run can never post.

Platforms, all through their official APIs on accounts the owner authorised:
  youtube    Data API resumable upload (a Short: vertical, under 3 minutes).
             Uploads from an unaudited Google Cloud project stay private.
  instagram  Instagram API with Instagram Login, resumable Reels upload.
  tiktok     Content Posting API, upload to the inbox (drafts): the owner
             finishes the post in the TikTok app, pasting the caption. Direct
             posting is forced private until TikTok audits the app.

Usage:
  python tools/post/post.py stage CLIP --title T --caption C [--hashtags "#a #b"]
      [--when "2026-10-27 18:00" | --when auto] [--platforms youtube,instagram]
  python tools/post/post.py list          the schedule
  python tools/post/post.py check         every queued clip against the limits
  python tools/post/post.py publish [--live] [--now]
  python tools/post/post.py auth google|tiktok|instagram

One Google sign-in covers YouTube uploads and Gmail (tools/gmail/), from one
Google Cloud project: its Desktop OAuth client's JSON is named in the config
as "google": {"client_file": ...}; "auth youtube" is the same as "auth google".

The config (default ~/critter-post/config.json, or --config) names the queue
folder and the API apps; tokens live beside it in tokens.json. Neither belongs
in this repo. Stdlib only; ffprobe on PATH for the clip checks.
"""

import argparse
import base64
import datetime as dt
import getpass
import hashlib
import http.server
import json
import re
import secrets
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import webbrowser
from pathlib import Path

PLATFORMS = ("tiktok", "instagram", "youtube")
GOOGLE = ("google", "youtube", "gmail")     # one sign-in, one token, kept as "google"
GOOGLE_SCOPES = ("https://www.googleapis.com/auth/youtube.upload",
                 "https://www.googleapis.com/auth/gmail.modify")
DEFAULT_CONFIG = Path.home() / "critter-post" / "config.json"
FIELDS = ("when", "title", "clip", "platforms", "hashtags", "posted")
APPROVE, BIN = "- [x] approve", "- [x] bin"

# What each platform takes (checked before anything is sent).
LIMITS = {
    "youtube": {"seconds": 180, "caption": 5000, "title": 100},
    "instagram": {"seconds": 900, "caption": 2200, "hashtags": 30},
    "tiktok": {"seconds": 600, "caption": 2200},
}


# ---------------------------------------------------------------- the queue

class Post:
    """One queue file. Front-matter keys the tool does not know are kept."""

    def __init__(self, path):
        self.path = Path(path)
        text = self.path.read_text(encoding="utf-8")
        m = re.match(r"---\n(.*?)\n---\n?(.*)", text, re.S)
        if not m:
            raise ValueError(f"{self.path.name}: no front matter")
        self.front = {}
        for line in m.group(1).splitlines():
            if ": " in line or line.endswith(":"):
                k, _, v = line.partition(":")
                v = v.strip()
                self.front[k.strip()] = json.loads(v) if v.startswith('"') else v
        self.body = m.group(2)

    def get(self, key):
        return self.front.get(key, "")

    @property
    def when(self):
        return dt.datetime.strptime(self.get("when"), "%Y-%m-%d %H:%M")

    @property
    def platforms(self):
        return [p.strip() for p in self.get("platforms").split(",") if p.strip()]

    @property
    def posted(self):
        """{platform: id} from 'posted: youtube=abc, tiktok=draft:123'."""
        return dict(p.strip().split("=", 1) for p in self.get("posted").split(",") if "=" in p)

    @property
    def caption(self):
        m = re.search(r"## Caption\n(.*?)(?=\n## |\Z)", self.body, re.S)
        return m.group(1).strip() if m else ""

    @property
    def approved(self):
        return APPROVE in self.body and not self.binned

    @property
    def binned(self):
        return BIN in self.body

    def full_caption(self):
        return f"{self.caption}\n\n{self.get('hashtags')}".strip()

    def mark_posted(self, platform, ident):
        done = self.posted
        done[platform] = ident
        self.front["posted"] = ", ".join(f"{k}={v}" for k, v in done.items())
        self.save()

    def log(self, line):
        stamp = dt.datetime.now().strftime("%Y-%m-%d %H:%M")
        if "\n## Log\n" not in self.body:
            self.body = self.body.rstrip() + "\n\n## Log\n"
        self.body = self.body.rstrip() + f"\n- {stamp} {line}\n"
        self.save()

    def save(self):
        write(self.path, self.front, self.body)


def write(path, front, body):
    """Front matter as key: value lines, quoting what YAML would misread (# is a comment)."""
    quote = lambda v: json.dumps(v) if re.search(r"#|: |\\|^[\"'\[{&*!|>%@`]", v) else v
    lines = "\n".join(f"{k}: {quote(str(v))}" for k, v in front.items())
    path.write_text(f"---\n{lines}\n---\n{body}", encoding="utf-8")


def load_queue(cfg):
    folder = Path(cfg["queue"])
    posts = []
    for f in sorted(folder.glob("*.md")):
        try:
            posts.append(Post(f))
        except ValueError:
            pass  # a README or note in the same folder
    return sorted((p for p in posts if p.get("when")), key=lambda p: p.when)


def next_slot(cfg, posts):
    """The next free time: every_days after the last post, at the slot time."""
    hh, mm = map(int, cfg.get("slot", "18:00").split(":"))
    now = dt.datetime.now()
    day = max([p.when for p in posts if not p.binned] + [now - dt.timedelta(days=99)])
    day = (day + dt.timedelta(days=cfg.get("every_days", 2))).replace(hour=hh, minute=mm)
    while day <= now:
        day += dt.timedelta(days=1)
    return day


def stage(cfg, args):
    clip = Path(args.clip).resolve()
    if not clip.exists():
        sys.exit(f"no clip at {clip}")
    posts = load_queue(cfg)
    when = next_slot(cfg, posts) if args.when == "auto" else \
        dt.datetime.strptime(args.when, "%Y-%m-%d %H:%M")
    slug = re.sub(r"[^a-z0-9]+", "-", args.title.lower()).strip("-")
    path = Path(cfg["queue"]) / f"{when:%Y-%m-%d} {slug}.md"
    if path.exists():
        sys.exit(f"already queued: {path}")
    front = dict(cfg.get("front", {}))
    if cfg.get("summary_key"):
        front[cfg["summary_key"]] = (f"{args.title}, due {when:%a %d %b %H:%M} on "
                                     f"{', '.join(args.platforms.split(','))}; waiting for review.")
    front.update(when=f"{when:%Y-%m-%d %H:%M}", title=args.title, clip=str(clip),
                 platforms=args.platforms, hashtags=args.hashtags, posted="")
    body = (f"\n# {args.title}\n\n## Caption\n{args.caption}\n\n## Review\n"
            "Tick approve to let it go out at the time above; tick bin to drop it.\n\n"
            "- [ ] approve\n- [ ] bin\n")
    path.parent.mkdir(parents=True, exist_ok=True)
    write(path, front, body)
    print(f"staged {path}")
    for problem in check_post(Post(path)):
        print(f"  ! {problem}")


def show(cfg, _args):
    for p in load_queue(cfg):
        state = "binned" if p.binned else "approved" if p.approved else "waiting"
        done = p.posted
        plats = " ".join(f"{x}{'+' if x in done else ''}" for x in p.platforms)
        print(f"{p.when:%a %d %b %H:%M}  {state:8}  {p.get('title')}  [{plats}]")


# ---------------------------------------------------------------- checks

def probe(clip):
    if not shutil.which("ffprobe"):
        return None
    out = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries",
                          "stream=width,height:format=duration", "-of", "json", str(clip)],
                         capture_output=True, text=True)
    if out.returncode:
        return None
    info = json.loads(out.stdout)
    s = info["streams"][0]
    return s["width"], s["height"], float(info["format"]["duration"])


def check_post(p):
    problems = []
    clip = Path(p.get("clip"))
    if not clip.exists():
        return [f"clip missing: {clip}"]
    if not p.caption:
        problems.append("no caption")
    for plat in p.platforms:
        if plat not in PLATFORMS:
            problems.append(f"unknown platform {plat}")
    size = probe(clip)
    if size:
        w, h, secs = size
        if abs(w / h - 9 / 16) > 0.01:
            problems.append(f"not 9:16 ({w}x{h})")
        for plat in p.platforms:
            lim = LIMITS.get(plat, {})
            if secs > lim.get("seconds", 1e9):
                problems.append(f"{plat}: {secs:.0f} s is over {lim['seconds']} s")
    for plat in p.platforms:
        lim = LIMITS.get(plat, {})
        if len(p.full_caption()) > lim.get("caption", 1e9):
            problems.append(f"{plat}: caption over {lim['caption']} characters")
        if len(p.get("hashtags").split()) > lim.get("hashtags", 1e9):
            problems.append(f"{plat}: over {lim['hashtags']} hashtags")
    if "youtube" in p.platforms and len(p.get("title")) + len(" #Shorts") > LIMITS["youtube"]["title"]:
        problems.append("youtube: title too long")
    return problems


def check(cfg, _args):
    bad = 0
    for p in load_queue(cfg):
        problems = check_post(p)
        bad += bool(problems)
        print(f"{'FIX ' if problems else 'ok  '} {p.path.name}")
        for problem in problems:
            print(f"     {problem}")
    sys.exit(1 if bad else 0)


# ---------------------------------------------------------------- publishing

def publish(cfg, args):
    if args.live and args.now:
        sys.exit("--now is for dry runs only")
    live_ok = set(cfg.get("live", [])) if args.live else set()
    now = dt.datetime.now()
    for p in load_queue(cfg):
        if p.binned or (p.when > now and not args.now):
            continue
        todo = [x for x in p.platforms if x not in p.posted]
        if not todo:
            continue
        if not p.approved:
            print(f"skip {p.path.name}: due but not approved")
            continue
        problems = check_post(p)
        if problems:
            p.log("not sent: " + "; ".join(problems))
            print(f"skip {p.path.name}: {'; '.join(problems)}")
            continue
        for plat in todo:
            if plat not in live_ok:
                plan = PLANS[plat](p)
                p.log(f"dry run {plat}: {plan}")
                print(f"dry run {plat}  {p.path.name}\n    {plan}")
                continue
            try:
                ident = SENDERS[plat](cfg, p)
            except Exception as e:  # one platform failing must not stop the rest
                p.log(f"{plat} failed: {e}")
                print(f"{plat} failed {p.path.name}: {e}")
                continue
            p.mark_posted(plat, ident)
            p.log(f"{plat} sent: {ident}")
            print(f"{plat} sent {p.path.name}: {ident}")


def youtube_meta(p):
    return {"snippet": {"title": f"{p.get('title')} #Shorts", "description": p.full_caption(),
                        "tags": [t.lstrip("#") for t in p.get("hashtags").split()],
                        "categoryId": "20"},
            "status": {"privacyStatus": "public", "selfDeclaredMadeForKids": False}}


PLANS = {
    "youtube": lambda p: f"upload {Path(p.get('clip')).name} as {json.dumps(youtube_meta(p)['snippet']['title'])}, public",
    "instagram": lambda p: f"Reel {Path(p.get('clip')).name} with a {len(p.full_caption())}-character caption, published",
    "tiktok": lambda p: f"upload {Path(p.get('clip')).name} to TikTok drafts; caption to paste: {json.dumps(p.full_caption())}",
}


def call(method, url, data=None, headers=None, form=False):
    headers = dict(headers or {})
    if isinstance(data, (dict, list)):
        if form:
            data = urllib.parse.urlencode(data).encode()
            headers.setdefault("Content-Type", "application/x-www-form-urlencoded")
        else:
            data = json.dumps(data).encode()
            headers.setdefault("Content-Type", "application/json; charset=UTF-8")
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=300) as r:
            body = r.read()
            return r.headers, (json.loads(body) if body.strip() else {})
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"{method} {url.split('?')[0]}: {e.code} {e.read()[:300]!r}") from None


def tokens_path(cfg):
    return Path(cfg["_dir"]) / "tokens.json"


def load_tokens(cfg):
    path = tokens_path(cfg)
    return json.loads(path.read_text()) if path.exists() else {}


def save_token(cfg, plat, tok):
    all_tokens = load_tokens(cfg)
    tok["saved"] = time.time()
    all_tokens[plat] = tok
    tokens_path(cfg).write_text(json.dumps(all_tokens, indent=1))


def google_app(cfg):
    """(client id, secret) from the downloaded client JSON, or the config's youtube entry."""
    path = cfg.get("google", {}).get("client_file")
    if path:
        d = json.loads(Path(path).read_text(encoding="utf-8"))
        d = d.get("installed") or d.get("web") or d
        return d["client_id"], d["client_secret"]
    app = cfg.get("youtube", {})
    return app["client_id"], app["client_secret"]


def fresh_token(cfg, plat):
    """An access token, refreshed when it is near its expiry."""
    plat = "google" if plat in GOOGLE else plat
    tok = load_tokens(cfg).get(plat)
    if not tok:
        raise RuntimeError(f"no {plat} token; run: post.py auth {plat}")
    if time.time() < tok["saved"] + tok.get("expires_in", 3600) - 300:
        return tok["access_token"]
    app = cfg.get(plat, {})
    if plat == "google":
        cid, secret = google_app(cfg)
        _, new = call("POST", "https://oauth2.googleapis.com/token", form=True, data={
            "client_id": cid, "client_secret": secret,
            "refresh_token": tok["refresh_token"], "grant_type": "refresh_token"})
        new.setdefault("refresh_token", tok["refresh_token"])
        new["account"] = tok.get("account", "")
    elif plat == "tiktok":
        _, new = call("POST", "https://open.tiktokapis.com/v2/oauth/token/", form=True, data={
            "client_key": app["client_key"], "client_secret": app["client_secret"],
            "refresh_token": tok["refresh_token"], "grant_type": "refresh_token"})
    else:  # instagram long-lived tokens last 60 days; renewed after 50
        _, new = call("GET", "https://graph.instagram.com/refresh_access_token?" + urllib.parse.urlencode(
            {"grant_type": "ig_refresh_token", "access_token": tok["access_token"]}))
        new.update(user_id=tok["user_id"], expires_in=50 * 86400)
    save_token(cfg, plat, new)
    return new["access_token"]


def send_youtube(cfg, p):
    clip = Path(p.get("clip"))
    data = clip.read_bytes()
    auth = {"Authorization": f"Bearer {fresh_token(cfg, 'youtube')}"}
    hdrs, _ = call("POST", "https://www.googleapis.com/upload/youtube/v3/videos"
                   "?uploadType=resumable&part=snippet,status", youtube_meta(p),
                   {**auth, "X-Upload-Content-Type": "video/mp4",
                    "X-Upload-Content-Length": str(len(data))})
    _, video = call("PUT", hdrs["Location"], data, {**auth, "Content-Type": "video/mp4"})
    return video["id"]


def send_instagram(cfg, p):
    token = fresh_token(cfg, "instagram")
    user = load_tokens(cfg)["instagram"]["user_id"]
    graph = f"https://graph.instagram.com/{cfg.get('graph_version', 'v23.0')}"
    data = Path(p.get("clip")).read_bytes()
    _, box = call("POST", f"{graph}/{user}/media", form=True, data={
        "media_type": "REELS", "upload_type": "resumable", "caption": p.full_caption(),
        "access_token": token})
    call("POST", box["uri"], data, {"Authorization": f"OAuth {token}", "offset": "0",
                                    "file_size": str(len(data))})
    for _ in range(60):  # Instagram processes the video before it can publish
        _, st = call("GET", f"{graph}/{box['id']}?fields=status_code&access_token={token}")
        if st.get("status_code") == "FINISHED":
            break
        if st.get("status_code") == "ERROR":
            raise RuntimeError("Instagram could not process the video")
        time.sleep(10)
    else:
        raise RuntimeError("Instagram still processing after 10 minutes")
    _, done = call("POST", f"{graph}/{user}/media_publish", form=True,
                   data={"creation_id": box["id"], "access_token": token})
    return done["id"]


def send_tiktok(cfg, p):
    data = Path(p.get("clip")).read_bytes()
    if len(data) > 64 * 1024 * 1024:
        raise RuntimeError("over 64 MB; TikTok needs it in chunks")
    auth = {"Authorization": f"Bearer {fresh_token(cfg, 'tiktok')}"}
    _, init = call("POST", "https://open.tiktokapis.com/v2/post/publish/inbox/video/init/",
                   {"source_info": {"source": "FILE_UPLOAD", "video_size": len(data),
                                    "chunk_size": len(data), "total_chunk_count": 1}}, auth)
    call("PUT", init["data"]["upload_url"], data,
         {"Content-Type": "video/mp4", "Content-Range": f"bytes 0-{len(data) - 1}/{len(data)}"})
    print(f"    in TikTok drafts; paste this caption there:\n    {p.full_caption()}")
    return "draft:" + init["data"]["publish_id"]


SENDERS = {"youtube": send_youtube, "instagram": send_instagram, "tiktok": send_tiktok}


# ---------------------------------------------------------------- sign-in

def loopback_code(auth_url, port):
    """Open the sign-in page and wait for the redirect to 127.0.0.1:port."""
    got = {}

    class Handler(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            got.update(urllib.parse.parse_qsl(urllib.parse.urlparse(self.path).query))
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"Signed in. You can close this tab.")

        def log_message(self, *a):
            pass

    server = http.server.HTTPServer(("127.0.0.1", port), Handler)
    print(f"Opening the sign-in page. If it does not open, visit:\n{auth_url}")
    webbrowser.open(auth_url)
    while "code" not in got and "error" not in got:
        server.handle_request()
    if "error" in got:
        sys.exit(f"sign-in refused: {got['error']}")
    return got


def auth(cfg, args):
    if args.platform in GOOGLE:
        args.platform = "google"
    app = cfg.get(args.platform, {})
    port = app.get("port", cfg.get("youtube", {}).get("port", 8765))
    redirect = f"http://127.0.0.1:{port}/"
    state = secrets.token_urlsafe(16)
    verifier = secrets.token_urlsafe(48)
    if args.platform == "google":
        cid, secret = google_app(cfg)
        challenge = base64.urlsafe_b64encode(hashlib.sha256(verifier.encode()).digest()).rstrip(b"=").decode()
        got = loopback_code("https://accounts.google.com/o/oauth2/v2/auth?" + urllib.parse.urlencode({
            "client_id": cid, "redirect_uri": redirect, "response_type": "code",
            "scope": " ".join(GOOGLE_SCOPES), "access_type": "offline",
            "prompt": "consent select_account", "state": state, "code_challenge": challenge,
            "code_challenge_method": "S256"}), port)
        url, data = "https://oauth2.googleapis.com/token", {"client_id": cid, "client_secret": secret}
    elif args.platform == "tiktok":
        # TikTok's desktop flow wants the challenge as hex, not base64
        challenge = hashlib.sha256(verifier.encode()).hexdigest()
        got = loopback_code("https://www.tiktok.com/v2/auth/authorize/?" + urllib.parse.urlencode({
            "client_key": app["client_key"], "redirect_uri": redirect, "response_type": "code",
            "scope": "video.upload", "state": state, "code_challenge": challenge,
            "code_challenge_method": "S256"}), port)
        url, data = "https://open.tiktokapis.com/v2/oauth/token/", {
            "client_key": app["client_key"], "client_secret": app["client_secret"]}
    else:
        print("Paste the long-lived token from the Meta app dashboard "
              "(Instagram > API setup with Instagram login > Generate token).")
        token = getpass.getpass("token: ").strip()
        _, me = call("GET", "https://graph.instagram.com/me?fields=user_id,username&access_token=" + token)
        save_token(cfg, "instagram", {"access_token": token, "user_id": me["user_id"],
                                      "expires_in": 50 * 86400})
        print(f"saved for @{me.get('username')}")
        return
    if got.get("state") != state:
        sys.exit("sign-in answer did not match; try again")
    _, tok = call("POST", url, form=True, data={**data, "code": got["code"], "redirect_uri": redirect,
                                                "grant_type": "authorization_code",
                                                "code_verifier": verifier})
    if args.platform == "google":
        # Which account this is, so Gmail can refuse any other (tools/gmail/).
        granted = tok.get("scope", "").split()
        try:
            _, me = call("GET", "https://gmail.googleapis.com/gmail/v1/users/me/profile",
                         headers={"Authorization": f"Bearer {tok['access_token']}"})
            tok["account"] = me.get("emailAddress", "")
        except RuntimeError:
            tok["account"] = ""
        print(f"signed in as {tok['account'] or 'an account Gmail could not read'}; "
              f"allowed: {', '.join(s.rsplit('/', 1)[-1] for s in granted) or 'nothing'}")
        want = cfg.get("gmail", {}).get("account", "")
        if want and tok["account"].lower() != want.lower():
            sys.exit(f"that is not {want}; nothing saved. Run auth again and pick {want}.")
    save_token(cfg, args.platform, tok)
    print(f"saved {args.platform} token to {tokens_path(cfg)}")


# ---------------------------------------------------------------- main

def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--config", default=str(DEFAULT_CONFIG))
    sub = ap.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("stage")
    s.add_argument("clip")
    s.add_argument("--title", required=True)
    s.add_argument("--caption", required=True)
    s.add_argument("--hashtags", default="")
    s.add_argument("--when", default="auto")
    s.add_argument("--platforms", default=",".join(PLATFORMS))
    sub.add_parser("list")
    sub.add_parser("check")
    pub = sub.add_parser("publish")
    pub.add_argument("--live", action="store_true", help="really send, to platforms in the config's live list")
    pub.add_argument("--now", action="store_true", help="treat every approved post as due (testing)")
    a = sub.add_parser("auth")
    a.add_argument("platform", choices=PLATFORMS + ("google", "gmail"))
    args = ap.parse_args(argv)

    cfg_path = Path(args.config)
    if not cfg_path.exists():
        sys.exit(f"no config at {cfg_path}; copy tools/post/config.example.json there")
    cfg = json.loads(cfg_path.read_text(encoding="utf-8"))
    cfg["_dir"] = str(cfg_path.parent)
    {"stage": stage, "list": show, "check": check, "publish": publish, "auth": auth}[args.cmd](cfg, args)


if __name__ == "__main__":
    main()
