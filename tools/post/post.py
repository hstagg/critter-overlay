"""Ships a finished post to TikTok, Instagram Reels and YouTube Shorts, scheduled.

A post is a JSON spec: the clip, and per platform the words that go with it
(more keys may be there; ship reads these):

    {"post": "2026-11-27-desk-kittens", "clip": "C:/.../clip.mp4",
     "platforms": {"tiktok": {"caption": "...", "hashtags": ["#desktoppet"]},
                   "instagram": {"caption": "...", "hashtags": []},
                   "youtube": {"title": "...", "description": "...", "tags": []}}}

Nobody reviews a post by hand: an automated QA gate does, and writes its
verdict to <clip>.qa.json beside the clip. `ship` refuses a post unless that
record says "pass": true for the same post and is newer than the clip.

Two locks keep a run from posting by accident. A platform is really sent only
when the run has --live AND the config lists the platform in "live";
everything else is a dry run, which prints what it would send and touches no
network. Emptying "live" stops all posting.

Routes, all official or partner APIs on accounts the owner connected:
  tiktok     Zernio (zernio.com), a TikTok partner. A public video, scheduled
             on Zernio's side.
  instagram  Zernio. A Reel (a single video is one), scheduled on Zernio's side.
  youtube    YouTube Data API resumable upload, private with status.publishAt,
             so YouTube makes it public at the time.

Usage:
  python tools/post/post.py ship SPEC.json [--tiktok WHEN] [--instagram WHEN]
      [--youtube WHEN] [--live]
  python tools/post/post.py status tiktok|instagram|youtube ID
  python tools/post/post.py accounts       the accounts connected in Zernio
  python tools/post/post.py comments [--since WHEN] [--platform P]
  python tools/post/post.py reply PLATFORM COMMENT_ID [--post POST_ID] --text-file F [--live]
  python tools/post/post.py auth google    sign in for YouTube and Gmail

WHEN is ISO 8601 (2026-11-27T18:00+00:00); without an offset it is this
computer's local time. It must be in the future. ship prints one JSON line per
platform: post, platform, id (the Zernio post id, or the YouTube video id),
scheduled, and status ("scheduled", "dry_run", "refused" or "failed") with an
error when there is one. It exits 1 if any platform was refused or failed.

comments prints one JSON line per comment by someone else on our posts:
platform, post_id, comment_id, author, text, time, replied (one of our
replies is visible under it, or replies.jsonl has it), and url where known.
TikTok and Instagram come from Zernio's comment inbox, YouTube from
commentThreads. A platform it can't read prints {"platform", "error"}.
reply sends one reply under the same live lock as ship, and refuses a
second reply to one comment and more than REPLY_CAP replies in
REPLY_WINDOW_H hours.

The config (default ~/critter-post/config.json, or --config) holds the Zernio
key and the Google client; tokens live beside it in tokens.json. Neither
belongs in this repo. Stdlib only.
"""

import argparse
import base64
import datetime as dt
import hashlib
import http.server
import json
import secrets
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
import webbrowser
from pathlib import Path

PLATFORMS = ("tiktok", "instagram", "youtube")
ZERNIO_PLATFORMS = ("tiktok", "instagram")
GOOGLE = ("google", "youtube", "gmail")     # one sign-in, one token, kept as "google"
GOOGLE_SCOPES = ("https://www.googleapis.com/auth/youtube.upload",
                 "https://www.googleapis.com/auth/youtube.force-ssl",      # read the channel, reply to comments
                 "https://www.googleapis.com/auth/yt-analytics.readonly",  # views, watch time, retention
                 "https://www.googleapis.com/auth/gmail.modify")
DEFAULT_CONFIG = Path.home() / "critter-post" / "config.json"
ZERNIO_API = "https://zernio.com/api/v1"

# What each platform takes, checked before anything is sent (the QA gate checks the clip).
LIMITS = {
    "youtube": {"caption": 5000, "title": 100},
    "instagram": {"caption": 2200, "hashtags": 30},
    "tiktok": {"caption": 2200},
}

# TikTok's direct-post settings, sent with every TikTok post. The config's
# "zernio": {"tiktok": {...}} overrides any of them. The two confirmations
# stand for TikTok's preview-and-consent step, which the QA gate replaces.
TIKTOK = {
    "privacy_level": "PUBLIC_TO_EVERYONE",
    "allow_comment": True,
    "allow_duet": True,
    "allow_stitch": True,
    "commercial_content_type": "brand_organic",   # the account promoting its own app ("Your brand")
    "content_preview_confirmed": True,
    "express_consent_given": True,
}

# Comments and replies. A run of the reply routine sends at most REPLY_CAP
# replies: the cap counts live replies in the last REPLY_WINDOW_H hours, from
# replies.jsonl beside the config (which also stops a second reply to one comment).
REPLY_CAP, REPLY_WINDOW_H = 30, 4
REPLY_LIMITS = {"tiktok": 150, "instagram": 2200, "youtube": 10000}   # characters
COMMENT_PAGES = 5           # pages read per list, at most
ZERNIO_PAUSE = 1.0          # seconds between Zernio comment reads


# ---------------------------------------------------------------- the post

def words(spec, plat):
    """The text as it goes out: the caption then the hashtags, or YouTube's description."""
    p = spec["platforms"][plat]
    if plat == "youtube":
        return p.get("description", "")
    return f"{p.get('caption', '')}\n\n{' '.join(p.get('hashtags', []))}".strip()


def problems(spec, plat):
    p = spec.get("platforms", {}).get(plat)
    if p is None:
        return [f"the spec has no {plat} entry"]
    lim, out = LIMITS[plat], []
    if plat == "youtube":
        if not p.get("title"):
            out.append("no title")
        elif len(p["title"]) > lim["title"]:
            out.append(f"title over {lim['title']} characters")
    elif not p.get("caption"):
        out.append("no caption")
    if len(words(spec, plat)) > lim["caption"]:
        out.append(f"caption over {lim['caption']} characters")
    if len(p.get("hashtags", [])) > lim.get("hashtags", 10 ** 9):
        out.append(f"over {lim['hashtags']} hashtags")
    return out


def qa_refusal(spec):
    """Why the QA gate's record does not let this post out, or None if it does."""
    clip = Path(spec.get("clip", ""))
    if not spec.get("clip") or not clip.is_file():
        return f"no clip at {clip}"
    qa = clip.with_suffix(".qa.json")
    if not qa.is_file():
        return f"no QA record ({qa.name}); run the QA gate first"
    try:
        rec = json.loads(qa.read_text(encoding="utf-8"))
    except ValueError:
        return f"{qa.name} is not JSON"
    if rec.get("post") != spec.get("post"):
        return f"{qa.name} is for {rec.get('post')!r}, not {spec.get('post')!r}"
    if rec.get("pass") is not True:
        return "the QA gate failed it: " + "; ".join(rec.get("fails", []))[:300]
    if qa.stat().st_mtime < clip.stat().st_mtime:
        return "the clip changed after the QA gate passed it; run the gate again"
    return None


def parse_when(text):
    """An aware datetime; a time without an offset is this computer's local time."""
    when = dt.datetime.fromisoformat(text.strip().replace("Z", "+00:00"))
    return when if when.tzinfo else when.astimezone()


def rfc3339_utc(when):
    return when.astimezone(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def plan(spec, plat, when):
    """One line saying what a live run would send."""
    clip, p = Path(spec["clip"]).name, spec["platforms"][plat]
    if plat == "youtube":
        return (f"YouTube: upload {clip} as {json.dumps(p['title'])}, private until "
                f"{rfc3339_utc(when)}, then public")
    kind = "a Reel" if plat == "instagram" else "a public video"
    return (f"Zernio: {clip} to {plat} as {kind} at {when.isoformat()}, "
            f"{len(words(spec, plat))}-character caption")


def needs(cfg, plat):
    """What a live send to this platform would still lack, or None."""
    if plat in ZERNIO_PLATFORMS:
        return None if cfg.get("zernio", {}).get("api_key") else "no zernio.api_key in the config"
    return None if load_tokens(cfg).get("google") else "no Google token; run: post.py auth google"


# ---------------------------------------------------------------- ship

def ship(cfg, args):
    spec = json.loads(Path(args.spec).read_text(encoding="utf-8"))
    times = {p: getattr(args, p) for p in PLATFORMS if getattr(args, p)}
    if not times:
        sys.exit("give a time for at least one platform: --tiktok, --instagram or --youtube")
    live_ok = set(cfg.get("live", [])) if args.live else set()
    refusal = qa_refusal(spec)
    now = dt.datetime.now(dt.timezone.utc)
    media = {}        # the clip goes up to Zernio once, for both its platforms
    failed = False
    for plat, text in times.items():
        res = {"post": spec.get("post"), "platform": plat, "id": None, "scheduled": None}
        try:
            when = parse_when(text)
            res["scheduled"] = when.isoformat()
        except ValueError:
            when = None
        why = refusal or ("not an ISO 8601 time: " + repr(text) if when is None else
                          "the time is not in the future" if when <= now else
                          "; ".join(problems(spec, plat)))
        if why:
            res.update(status="refused", error=why)
        elif plat not in live_ok:
            res.update(status="dry_run", plan=plan(spec, plat, when))
            if needs(cfg, plat):
                res["needs"] = needs(cfg, plat)
        else:
            try:
                res.update(SENDERS[plat](cfg, spec, plat, when, media))
            except Exception as e:  # one platform failing must not stop the rest
                res.update(status="failed", error=str(e)[:400])
        failed |= res["status"] in ("refused", "failed")
        print(json.dumps(res, ensure_ascii=False), flush=True)
    return 1 if failed else 0


# ---------------------------------------------------------------- HTTP and tokens

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


def fresh_token(cfg, plat="google"):
    """The Google access token (YouTube and Gmail), refreshed when it is near its expiry."""
    tok = load_tokens(cfg).get("google")
    if not tok:
        raise RuntimeError("no Google token; run: post.py auth google")
    if time.time() < tok["saved"] + tok.get("expires_in", 3600) - 300:
        return tok["access_token"]
    cid, secret = google_app(cfg)
    _, new = call("POST", "https://oauth2.googleapis.com/token", form=True, data={
        "client_id": cid, "client_secret": secret,
        "refresh_token": tok["refresh_token"], "grant_type": "refresh_token"})
    new.setdefault("refresh_token", tok["refresh_token"])
    new["account"] = tok.get("account", "")
    save_token(cfg, "google", new)
    return new["access_token"]


# ---------------------------------------------------------------- Zernio (TikTok, Instagram)

def zernio(cfg, method, path, data=None, headers=None):
    key = cfg.get("zernio", {}).get("api_key")
    if not key:
        raise RuntimeError("no zernio.api_key in the config")
    return call(method, ZERNIO_API + path, data, {"Authorization": f"Bearer {key}", **(headers or {})})[1]


def zernio_account(cfg, plat):
    """The Zernio account id for a platform: the config's, or the one connected account."""
    pinned = cfg.get("zernio", {}).get("accounts", {}).get(plat)
    if pinned:
        return pinned
    found = [a for a in zernio(cfg, "GET", "/accounts").get("accounts", [])
             if a.get("platform") == plat and a.get("isActive", True)]
    if len(found) != 1:
        raise RuntimeError(f"no {plat} account is connected in Zernio" if not found else
                           f"{len(found)} {plat} accounts in Zernio; name one as zernio.accounts.{plat}")
    return found[0]["_id"]


def zernio_media(cfg, clip, media):
    """Upload the clip to Zernio's storage once; its public URL goes in each post."""
    if "url" not in media:
        data = clip.read_bytes()
        got = zernio(cfg, "POST", "/media/presign",
                     {"filename": clip.name, "contentType": "video/mp4", "size": len(data)})
        call("PUT", got["uploadUrl"], data, {"Content-Type": "video/mp4"})   # storage, not the API: no key
        media["url"] = got["publicUrl"]
    return media["url"]


def send_zernio(cfg, spec, plat, when, media):
    account = zernio_account(cfg, plat)
    url = zernio_media(cfg, Path(spec["clip"]), media)
    entry = {"platform": plat, "accountId": account}
    body = {"content": words(spec, plat), "mediaItems": [{"type": "video", "url": url}],
            "platforms": [entry], "scheduledFor": when.isoformat(),
            "externalId": f"{spec['post']}:{plat}"}
    extra = cfg.get("zernio", {}).get(plat, {})
    if plat == "tiktok":
        body["tiktokSettings"] = {**TIKTOK, **extra}
    elif extra:
        entry["platformSpecificData"] = extra
    # The same post, platform and time always carry the same key, so a retry
    # within Zernio's 24 hours returns the first post instead of a second one.
    key = uuid.uuid5(uuid.NAMESPACE_URL, f"critter-overlay/{spec['post']}/{plat}/{when.isoformat()}")
    got = zernio(cfg, "POST", "/posts", body, {"Idempotency-Key": str(key)}).get("post", {})
    if got.get("status") in ("failed", "cancelled", "partial"):
        err = next((p.get("errorMessage") for p in got.get("platforms", []) if p.get("errorMessage")), "")
        raise RuntimeError(f"Zernio post {got.get('_id')} is {got['status']}: {err}")
    if not got.get("_id"):
        raise RuntimeError("Zernio returned no post id")
    return {"id": got["_id"], "status": "scheduled"}


# ---------------------------------------------------------------- YouTube

def youtube_meta(spec, when):
    p = spec["platforms"]["youtube"]
    return {"snippet": {"title": p["title"], "description": p.get("description", ""),
                        "tags": p.get("tags", []), "categoryId": "20"},
            "status": {"privacyStatus": "private", "publishAt": rfc3339_utc(when),
                       "selfDeclaredMadeForKids": False}}


def send_youtube(cfg, spec, _plat, when, _media):
    """Upload private with publishAt; YouTube makes it public at that time."""
    data = Path(spec["clip"]).read_bytes()
    auth = {"Authorization": f"Bearer {fresh_token(cfg)}"}
    hdrs, _ = call("POST", "https://www.googleapis.com/upload/youtube/v3/videos"
                   "?uploadType=resumable&part=snippet,status", youtube_meta(spec, when),
                   {**auth, "X-Upload-Content-Type": "video/mp4",
                    "X-Upload-Content-Length": str(len(data))})
    _, video = call("PUT", hdrs["Location"], data, {**auth, "Content-Type": "video/mp4"})
    out = {"id": video["id"], "status": "scheduled", "url": f"https://youtube.com/shorts/{video['id']}"}
    if not video.get("status", {}).get("publishAt"):
        out["warning"] = "YouTube kept no publishAt; the video may stay private"
    return out


SENDERS = {"tiktok": send_zernio, "instagram": send_zernio, "youtube": send_youtube}


# ---------------------------------------------------------------- status and accounts

def status(cfg, args):
    out = {"platform": args.platform, "id": args.id}
    if args.platform == "youtube":
        auth = {"Authorization": f"Bearer {fresh_token(cfg)}"}
        _, got = call("GET", "https://www.googleapis.com/youtube/v3/videos?part=status,statistics&id="
                      + urllib.parse.quote(args.id), headers=auth)
        items = got.get("items", [])
        if not items:
            out["status"] = "not_found"
        else:
            st, stats = items[0].get("status", {}), items[0].get("statistics", {})
            out.update(status=st.get("uploadStatus"), privacy=st.get("privacyStatus"),
                       scheduled=st.get("publishAt"), url=f"https://youtube.com/shorts/{args.id}",
                       analytics={k: int(v) for k, v in stats.items() if str(v).isdigit()})
    else:
        got = zernio(cfg, "GET", "/posts/" + urllib.parse.quote(args.id)).get("post", {})
        entry = next((p for p in got.get("platforms", []) if p.get("platform") == args.platform), {})
        out.update(status=entry.get("status") or got.get("status"), post_status=got.get("status"),
                   scheduled=got.get("scheduledFor"), platform_post_id=entry.get("platformPostId"),
                   url=entry.get("platformPostUrl"), error=entry.get("errorMessage"))
        if entry.get("status") == "published":
            an = zernio(cfg, "GET", "/analytics?" + urllib.parse.urlencode({"postId": args.id}))
            rec = next((a for a in an.get("platformAnalytics", []) if a.get("platform") == args.platform), an)
            out["analytics"] = rec.get("analytics")
    print(json.dumps(out, ensure_ascii=False))
    return 0


def accounts(cfg, _args):
    for a in zernio(cfg, "GET", "/accounts").get("accounts", []):
        print(json.dumps({k: a.get(k) for k in ("_id", "platform", "username", "isActive")}))
    return 0


# ---------------------------------------------------------------- comments and replies

def replies_path(cfg):
    return Path(cfg["_dir"]) / "replies.jsonl"


def reply_log(cfg):
    path = replies_path(cfg)
    if not path.exists():
        return []
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]


def youtube_comments(cfg, since, replied_ids):
    auth = {"Authorization": f"Bearer {fresh_token(cfg)}"}
    api = "https://www.googleapis.com/youtube/v3/"
    items = call("GET", api + "channels?part=id&mine=true", headers=auth)[1].get("items", [])
    if not items:
        raise RuntimeError("the signed-in Google account has no YouTube channel")
    me, page, out = items[0]["id"], "", []
    for _ in range(COMMENT_PAGES):
        q = {"part": "snippet,replies", "allThreadsRelatedToChannelId": me, "maxResults": 100,
             "order": "time", "textFormat": "plainText"}
        if page:
            q["pageToken"] = page
        got = call("GET", api + "commentThreads?" + urllib.parse.urlencode(q), headers=auth)[1]
        for th in got.get("items", []):
            top = th["snippet"]["topLevelComment"]
            s = top["snippet"]
            if s.get("authorChannelId", {}).get("value") == me:
                continue
            ours = any(r["snippet"].get("authorChannelId", {}).get("value") == me
                       for r in th.get("replies", {}).get("comments", []))
            out.append({"platform": "youtube", "post_id": th["snippet"].get("videoId"), "comment_id": top["id"],
                        "author": s.get("authorDisplayName"), "text": s.get("textDisplay", ""),
                        "time": s.get("publishedAt"), "replied": ours or top["id"] in replied_ids})
        page = got.get("nextPageToken")
        if not page:
            break
    return [c for c in out if after(c, since)]


def after(c, since):
    """True if the comment is newer than since (or its time can't be read: better shown than lost)."""
    if not since or not c.get("time"):
        return True
    try:
        return parse_when(str(c["time"])) >= since
    except ValueError:
        return True


def zernio_comments(cfg, plat, since, replied_ids, max_posts):
    account = zernio_account(cfg, plat)
    profile = cfg.get("zernio", {}).get("profile_id")
    posts, cursor = [], None
    for _ in range(COMMENT_PAGES):     # our posts that have comments, newest first
        q = {"limit": 50, **({"profileId": profile} if profile else {}), **({"cursor": cursor} if cursor else {})}
        got = zernio(cfg, "GET", "/inbox/comments?" + urllib.parse.urlencode(q))
        posts += [p for p in got.get("data", []) if p.get("platform") == plat
                  and p.get("accountId") in (None, account) and p.get("commentCount", 1)]
        pg = got.get("pagination") or {}
        cursor = pg.get("nextCursor") or pg.get("cursor")
        if not pg.get("hasMore") or not cursor or len(posts) >= max_posts:
            break
    out = []
    for p in posts[:max_posts]:
        cursor = None
        for _ in range(COMMENT_PAGES):
            time.sleep(ZERNIO_PAUSE)    # Zernio allows 60 requests a minute on the smallest plan
            q = {"accountId": account, "limit": 100, **({"cursor": cursor} if cursor else {})}
            got = zernio(cfg, "GET", f"/inbox/comments/{urllib.parse.quote(str(p['id']))}?"
                         + urllib.parse.urlencode(q))
            for c in got.get("comments", []):
                who = c.get("from") or {}
                if who.get("isOwner"):
                    continue
                ours = any((r.get("from") or {}).get("isOwner") for r in c.get("replies", []))
                out.append({"platform": plat, "post_id": str(p["id"]), "comment_id": str(c["id"]),
                            "author": who.get("username") or who.get("name"), "text": c.get("message", ""),
                            "time": c.get("createdTime"), "replied": ours or str(c["id"]) in replied_ids,
                            "url": c.get("url")})
            pg = got.get("pagination") or {}
            cursor = pg.get("cursor") or pg.get("nextCursor")
            if not pg.get("hasMore") or not cursor:
                break
    return [c for c in out if after(c, since)]


def comments(cfg, args):
    since = parse_when(args.since) if args.since else None
    replied_ids = {r["comment_id"] for r in reply_log(cfg) if r.get("live")}
    failed = False
    for plat in [args.platform] if args.platform else PLATFORMS:
        try:
            got = youtube_comments(cfg, since, replied_ids) if plat == "youtube" else \
                zernio_comments(cfg, plat, since, replied_ids, args.posts)
        except Exception as e:  # one platform failing must not hide the others
            print(json.dumps({"platform": plat, "error": str(e)[:400]}), flush=True)
            failed = True
            continue
        for c in sorted(got, key=lambda c: str(c["time"] or "")):
            print(json.dumps(c, ensure_ascii=False), flush=True)
    return 1 if failed else 0


def reply(cfg, args):
    out = {"platform": args.platform, "comment_id": args.comment_id, "post_id": args.post, "reply_id": None}
    text = Path(args.text_file).read_text(encoding="utf-8").strip()
    log = reply_log(cfg)
    cutoff = time.time() - REPLY_WINDOW_H * 3600
    recent = [r for r in log if r.get("live") and r.get("ts", 0) >= cutoff]
    why = ("the reply is empty" if not text else
           f"over {REPLY_LIMITS[args.platform]} characters" if len(text) > REPLY_LIMITS[args.platform] else
           "--post is needed for TikTok and Instagram" if args.platform != "youtube" and not args.post else
           "already replied to this comment" if any(r.get("live") and r["comment_id"] == args.comment_id
                                                    for r in log) else
           f"{REPLY_CAP} replies already sent in the last {REPLY_WINDOW_H} hours" if len(recent) >= REPLY_CAP
           else None)
    live = args.live and args.platform in cfg.get("live", [])
    if why:
        out.update(status="refused", error=why)
    elif not live:
        out.update(status="dry_run", plan=f"reply to {args.platform} comment {args.comment_id}: {json.dumps(text)}")
    else:
        try:
            if args.platform == "youtube":
                auth = {"Authorization": f"Bearer {fresh_token(cfg)}"}
                _, got = call("POST", "https://www.googleapis.com/youtube/v3/comments?part=snippet",
                              {"snippet": {"parentId": args.comment_id, "textOriginal": text}}, auth)
                out["reply_id"] = got["id"]
            else:
                key = uuid.uuid5(uuid.NAMESPACE_URL, f"critter-overlay/reply/{args.platform}/{args.comment_id}")
                got = zernio(cfg, "POST", f"/inbox/comments/{urllib.parse.quote(args.post)}",
                             {"accountId": zernio_account(cfg, args.platform), "message": text,
                              "commentId": args.comment_id}, {"Idempotency-Key": str(key)})
                out["reply_id"] = (got.get("data") or {}).get("commentId")
            out["status"] = "replied"
        except Exception as e:
            out.update(status="failed", error=str(e)[:400])
    if out["status"] == "replied":
        with open(replies_path(cfg), "a", encoding="utf-8") as f:
            f.write(json.dumps({"ts": time.time(), "platform": args.platform, "post_id": args.post,
                                "comment_id": args.comment_id, "reply_id": out["reply_id"], "live": True}) + "\n")
    print(json.dumps(out, ensure_ascii=False))
    return 1 if out["status"] in ("refused", "failed") else 0


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


def auth(cfg, _args):
    """One Google sign-in for YouTube and Gmail."""
    port = cfg.get("google", {}).get("port", cfg.get("youtube", {}).get("port", 8765))
    redirect = f"http://127.0.0.1:{port}/"
    state = secrets.token_urlsafe(16)
    verifier = secrets.token_urlsafe(48)
    cid, secret = google_app(cfg)
    challenge = base64.urlsafe_b64encode(hashlib.sha256(verifier.encode()).digest()).rstrip(b"=").decode()
    got = loopback_code("https://accounts.google.com/o/oauth2/v2/auth?" + urllib.parse.urlencode({
        "client_id": cid, "redirect_uri": redirect, "response_type": "code",
        "scope": " ".join(GOOGLE_SCOPES), "access_type": "offline",
        "prompt": "consent select_account", "state": state, "code_challenge": challenge,
        "code_challenge_method": "S256"}), port)
    if got.get("state") != state:
        sys.exit("sign-in answer did not match; try again")
    _, tok = call("POST", "https://oauth2.googleapis.com/token", form=True, data={
        "client_id": cid, "client_secret": secret, "code": got["code"], "redirect_uri": redirect,
        "grant_type": "authorization_code", "code_verifier": verifier})
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
    save_token(cfg, "google", tok)
    print(f"saved the Google token to {tokens_path(cfg)}")
    return 0


# ---------------------------------------------------------------- main

def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--config", default=str(DEFAULT_CONFIG))
    sub = ap.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("ship", help="schedule a post that passed the QA gate")
    s.add_argument("spec")
    for plat in PLATFORMS:
        s.add_argument(f"--{plat}", metavar="WHEN", help=f"when it goes out on {plat}")
    s.add_argument("--live", action="store_true", help="really send, to platforms in the config's live list")
    st = sub.add_parser("status", help="a sent post's state and numbers")
    st.add_argument("platform", choices=PLATFORMS)
    st.add_argument("id")
    sub.add_parser("accounts", help="the accounts connected in Zernio")
    c = sub.add_parser("comments", help="other people's comments on our posts, as JSON lines")
    c.add_argument("--since", help="only comments from this time on (ISO 8601)")
    c.add_argument("--platform", choices=PLATFORMS)
    c.add_argument("--posts", type=int, default=20, help="Zernio: the most recent commented posts to read")
    r = sub.add_parser("reply", help="reply to one comment")
    r.add_argument("platform", choices=PLATFORMS)
    r.add_argument("comment_id")
    r.add_argument("--post", help="the post id from comments (TikTok and Instagram)")
    r.add_argument("--text-file", required=True, help="the reply, UTF-8")
    r.add_argument("--live", action="store_true", help="really send, if the platform is in the config's live list")
    a = sub.add_parser("auth", help="sign in to Google (YouTube and Gmail)")
    a.add_argument("platform", choices=GOOGLE)
    args = ap.parse_args(argv)

    cfg_path = Path(args.config)
    if cfg_path.exists():
        cfg = json.loads(cfg_path.read_text(encoding="utf-8"))
    elif args.cmd == "ship":
        cfg = {}      # no config: nothing is live, so ship can only dry-run
    else:
        sys.exit(f"no config at {cfg_path}; copy tools/post/config.example.json there")
    cfg["_dir"] = str(cfg_path.parent)
    return {"ship": ship, "status": status, "accounts": accounts, "comments": comments, "reply": reply,
            "auth": auth}[args.cmd](cfg, args)


if __name__ == "__main__":
    sys.exit(main())
