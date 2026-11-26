"""post.py with the network replaced: nothing here can send.

  python -m unittest tools/post/test_post.py
"""

import contextlib
import copy
import datetime as dt
import io
import json
import os
import shutil
import sys
import tempfile
import time
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).parent))
import post  # noqa: E402

SPEC = {
    "post": "2099-01-01-desk-kittens",
    "on_screen": ["six hours into the spreadsheet..."],
    "platforms": {
        "tiktok": {"caption": "kittens on your desktop. free on itch.io", "hashtags": ["#desktoppet", "#wfh"]},
        "instagram": {"caption": "kittens on your desktop. link in bio", "hashtags": ["#desktoppet"]},
        "youtube": {"title": "kittens on your desktop #shorts", "description": "free on itch.io",
                    "tags": ["desktop pet"]},
    },
}
SOON = (dt.datetime.now(dt.timezone.utc) + dt.timedelta(days=1)).replace(microsecond=0)
LATER = SOON + dt.timedelta(hours=1)


def no_network(*a, **_k):
    raise AssertionError(f"tried to send: {a[:2]}")


class FakeHTTP:
    """Answers post.call by method and URL fragment, and records every request."""

    def __init__(self, routes):
        self.routes, self.calls = routes, []

    def __call__(self, method, url, data=None, headers=None, form=False):
        self.calls.append({"method": method, "url": url, "data": data, "headers": dict(headers or {})})
        for (m, frag), reply in self.routes.items():
            if m == method and frag in url:
                if callable(reply):
                    reply = reply()
                return reply if isinstance(reply, tuple) else ({}, reply)
        raise AssertionError(f"unexpected {method} {url}")

    def find(self, method, frag):
        return [c for c in self.calls if c["method"] == method and frag in c["url"]]


ZERNIO_ROUTES = {
    ("GET", "/accounts"): {"accounts": [
        {"_id": "acc-tt", "platform": "tiktok", "username": "@x", "isActive": True},
        {"_id": "acc-ig", "platform": "instagram", "username": "x", "isActive": True},
        {"_id": "acc-old", "platform": "tiktok", "username": "@x", "isActive": False}]},
    ("POST", "/media/presign"): {"uploadUrl": "https://storage.example/up?sig=1",
                                 "publicUrl": "https://media.example/clip.mp4", "key": "k", "expiresIn": 3600},
    ("PUT", "storage.example"): {},
}


class ShipTest(unittest.TestCase):
    def setUp(self):
        self.dir = Path(tempfile.mkdtemp())
        self.clip = self.dir / "clip.mp4"
        self.clip.write_bytes(b"not really a video")
        self.spec = dict(copy.deepcopy(SPEC), clip=str(self.clip))
        self.spec_path = self.dir / "post.json"
        self.spec_path.write_text(json.dumps(self.spec), encoding="utf-8")
        self.qa(True)
        self.cfg_path = self.dir / "config.json"
        self.config(live=[])

    def tearDown(self):
        shutil.rmtree(self.dir, ignore_errors=True)

    def qa(self, passed, post_id=None, fails=()):
        qa = self.clip.with_suffix(".qa.json")
        qa.write_text(json.dumps({"post": post_id or SPEC["post"], "pass": passed, "fails": list(fails)}))
        later = time.time() + 5
        os.utime(qa, (later, later))

    def config(self, **cfg):
        self.cfg_path.write_text(json.dumps(cfg))

    def google_token(self):
        (self.dir / "tokens.json").write_text(json.dumps(
            {"google": {"access_token": "T", "refresh_token": "R", "saved": time.time(), "expires_in": 3600}}))

    def run_post(self, *argv, http=no_network, config=None):
        out = io.StringIO()
        with mock.patch.object(post, "call", http), contextlib.redirect_stdout(out):
            code = post.main(["--config", str(config or self.cfg_path), *argv])
        return code, out.getvalue()

    def ship(self, *extra, http=no_network, config=None, times=None):
        times = times or {"tiktok": SOON, "instagram": SOON, "youtube": LATER}
        args = ["ship", str(self.spec_path)]
        for plat, when in times.items():
            args += [f"--{plat}", when if isinstance(when, str) else when.isoformat()]
        code, out = self.run_post(*args, *extra, http=http, config=config)
        return code, {r["platform"]: r for r in map(json.loads, out.splitlines())}

    # ---- the locks

    def test_dry_run_needs_no_config_and_sends_nothing(self):
        code, res = self.ship("--live", config=self.dir / "none.json")
        self.assertEqual(code, 0)
        self.assertEqual(set(res), set(post.PLATFORMS))
        for plat, r in res.items():
            self.assertEqual(r["status"], "dry_run")
            self.assertIsNone(r["id"])
            self.assertEqual(r["post"], SPEC["post"])
        self.assertIn("Zernio", res["tiktok"]["plan"])
        self.assertIn("Reel", res["instagram"]["plan"])
        self.assertIn("private until", res["youtube"]["plan"])
        self.assertIn("zernio.api_key", res["tiktok"]["needs"])
        self.assertIn("Google", res["youtube"]["needs"])

    def test_live_needs_flag_and_list(self):
        self.config(live=["tiktok"], zernio={"api_key": "K"})
        http = FakeHTTP({**ZERNIO_ROUTES, ("POST", "/posts"): {"post": {"_id": "zp1", "status": "scheduled"}}})
        _, res = self.ship(http=http)                       # no --live: all dry
        self.assertEqual({r["status"] for r in res.values()}, {"dry_run"})
        self.assertEqual(http.calls, [])
        _, res = self.ship("--live", http=http)             # --live: only the listed platform
        self.assertEqual(res["tiktok"]["status"], "scheduled")
        self.assertEqual(res["instagram"]["status"], "dry_run")
        self.assertEqual(res["youtube"]["status"], "dry_run")

    # ---- the QA gate

    def test_refused_without_a_qa_pass(self):
        cases = {
            "no QA record": lambda: self.clip.with_suffix(".qa.json").unlink(),
            "failed it: loudness": lambda: self.qa(False, fails=["loudness -20 LUFS"]),
            "is for 'other'": lambda: self.qa(True, post_id="other"),
            "changed after": lambda: os.utime(self.clip, (time.time() + 60, time.time() + 60)),
        }
        self.config(live=list(post.PLATFORMS), zernio={"api_key": "K"})
        for why, breaks in cases.items():
            with self.subTest(why):
                self.qa(True)
                os.utime(self.clip, (time.time() - 60, time.time() - 60))
                breaks()
                code, res = self.ship("--live")
                self.assertEqual(code, 1)
                for r in res.values():
                    self.assertEqual(r["status"], "refused")
                    self.assertIn(why, r["error"])

    def test_bad_times_and_words_are_refused(self):
        self.spec["platforms"]["tiktok"]["caption"] = "x" * 2300
        self.spec_path.write_text(json.dumps(self.spec), encoding="utf-8")
        past = dt.datetime.now(dt.timezone.utc) - dt.timedelta(hours=1)
        code, res = self.ship(times={"tiktok": SOON, "instagram": past, "youtube": "tomorrow"})
        self.assertEqual(code, 1)
        self.assertIn("2200", res["tiktok"]["error"])
        self.assertIn("not in the future", res["instagram"]["error"])
        self.assertIn("ISO 8601", res["youtube"]["error"])

    def test_platform_missing_from_spec(self):
        del self.spec["platforms"]["instagram"]
        self.spec_path.write_text(json.dumps(self.spec), encoding="utf-8")
        _, res = self.ship()
        self.assertEqual(res["instagram"]["status"], "refused")
        self.assertEqual(res["tiktok"]["status"], "dry_run")

    def test_local_time_without_offset(self):
        naive = (dt.datetime.now() + dt.timedelta(days=2)).replace(second=0, microsecond=0)
        _, res = self.ship(times={"youtube": naive.isoformat(timespec="minutes")})
        got = dt.datetime.fromisoformat(res["youtube"]["scheduled"])
        self.assertIsNotNone(got.tzinfo)
        self.assertEqual(got, naive.astimezone())

    # ---- Zernio

    def test_zernio_schedules_both_with_one_upload(self):
        self.config(live=["tiktok", "instagram"], zernio={"api_key": "K", "instagram": {"shareToFeed": True}})
        made = iter(["zp-tt", "zp-ig"])
        http = FakeHTTP({**ZERNIO_ROUTES,
                         ("POST", "/posts"): lambda: {"post": {"_id": next(made), "status": "scheduled"}}})
        code, res = self.ship("--live", http=http, times={"tiktok": SOON, "instagram": LATER})
        self.assertEqual(code, 0, res)
        self.assertEqual((res["tiktok"]["id"], res["instagram"]["id"]), ("zp-tt", "zp-ig"))
        self.assertEqual(res["tiktok"]["status"], "scheduled")
        self.assertEqual(len(http.find("POST", "/media/presign")), 1)
        put = http.find("PUT", "storage.example")[0]
        self.assertNotIn("Authorization", put["headers"])
        self.assertEqual(put["headers"]["Content-Type"], "video/mp4")
        self.assertEqual(put["data"], b"not really a video")
        tt, ig = http.find("POST", "/posts")
        tt_body, ig_body = tt["data"], ig["data"]
        self.assertEqual(tt["headers"]["Authorization"], "Bearer K")
        self.assertEqual(tt_body["platforms"], [{"platform": "tiktok", "accountId": "acc-tt"}])
        self.assertEqual(tt_body["scheduledFor"], SOON.isoformat())
        self.assertEqual(tt_body["mediaItems"], [{"type": "video", "url": "https://media.example/clip.mp4"}])
        self.assertEqual(tt_body["content"], "kittens on your desktop. free on itch.io\n\n#desktoppet #wfh")
        self.assertEqual(tt_body["tiktokSettings"]["privacy_level"], "PUBLIC_TO_EVERYONE")
        self.assertTrue(tt_body["tiktokSettings"]["express_consent_given"])
        self.assertEqual(ig_body["platforms"], [{"platform": "instagram", "accountId": "acc-ig",
                                                 "platformSpecificData": {"shareToFeed": True}}])
        self.assertNotIn("tiktokSettings", ig_body)
        self.assertEqual(ig_body["scheduledFor"], LATER.isoformat())
        self.assertNotEqual(tt["headers"]["Idempotency-Key"], ig["headers"]["Idempotency-Key"])

    def test_retry_carries_the_same_idempotency_key(self):
        self.config(live=["tiktok"], zernio={"api_key": "K", "accounts": {"tiktok": "pinned"}})
        http = FakeHTTP({**ZERNIO_ROUTES, ("POST", "/posts"): {"post": {"_id": "zp1", "status": "scheduled"}}})
        self.ship("--live", http=http, times={"tiktok": SOON})
        self.ship("--live", http=http, times={"tiktok": SOON})
        a, b = http.find("POST", "/posts")
        self.assertEqual(a["headers"]["Idempotency-Key"], b["headers"]["Idempotency-Key"])
        self.assertEqual(a["data"]["platforms"][0]["accountId"], "pinned")
        self.assertEqual(http.find("GET", "/accounts"), [])

    def test_account_choice_and_missing_key(self):
        self.config(live=["tiktok"], zernio={"api_key": "K"})
        two = {"accounts": [{"_id": "a", "platform": "tiktok"}, {"_id": "b", "platform": "tiktok"}]}
        _, res = self.ship("--live", http=FakeHTTP({("GET", "/accounts"): two}), times={"tiktok": SOON})
        self.assertEqual(res["tiktok"]["status"], "failed")
        self.assertIn("zernio.accounts.tiktok", res["tiktok"]["error"])
        self.config(live=["tiktok"])
        _, res = self.ship("--live", times={"tiktok": SOON})
        self.assertIn("no zernio.api_key", res["tiktok"]["error"])

    def test_a_failure_does_not_stop_the_rest(self):
        self.config(live=list(post.PLATFORMS), zernio={"api_key": "K"})
        self.google_token()
        http = FakeHTTP({**ZERNIO_ROUTES,
                         ("POST", "/posts"): {"post": {"_id": "zp1", "status": "failed", "platforms": [
                             {"platform": "tiktok", "status": "failed", "errorMessage": "video too short"}]}},
                         ("POST", "upload/youtube"): ({"Location": "https://upload.example/s1"}, {}),
                         ("PUT", "upload.example"): {"id": "vid1", "status": {"publishAt": "x"}}})
        code, res = self.ship("--live", http=http)
        self.assertEqual(code, 1)
        self.assertIn("video too short", res["tiktok"]["error"])
        self.assertEqual(res["instagram"]["status"], "failed")
        self.assertEqual(res["youtube"]["status"], "scheduled")

    # ---- YouTube

    def test_youtube_uploads_private_with_publish_at(self):
        self.config(live=["youtube"])
        self.google_token()
        when = dt.datetime(2099, 1, 1, 18, 0, tzinfo=dt.timezone(dt.timedelta(hours=1)))
        http = FakeHTTP({("POST", "upload/youtube"): ({"Location": "https://upload.example/s1"}, {}),
                         ("PUT", "upload.example"): {"id": "vid1", "status": {"privacyStatus": "private",
                                                                              "publishAt": "2099-01-01T17:00:00Z"}}})
        code, res = self.ship("--live", http=http, times={"youtube": when})
        self.assertEqual(code, 0)
        self.assertEqual(res["youtube"]["id"], "vid1")
        self.assertEqual(res["youtube"]["url"], "https://youtube.com/shorts/vid1")
        self.assertNotIn("warning", res["youtube"])
        meta = http.find("POST", "upload/youtube")[0]["data"]
        self.assertEqual(meta["status"]["privacyStatus"], "private")
        self.assertEqual(meta["status"]["publishAt"], "2099-01-01T17:00:00Z")
        self.assertEqual(meta["snippet"]["title"], "kittens on your desktop #shorts")
        self.assertEqual(meta["snippet"]["tags"], ["desktop pet"])
        self.assertEqual(http.find("PUT", "upload.example")[0]["headers"]["Authorization"], "Bearer T")

    def test_youtube_warns_when_publish_at_is_dropped(self):
        self.config(live=["youtube"])
        self.google_token()
        http = FakeHTTP({("POST", "upload/youtube"): ({"Location": "https://upload.example/s1"}, {}),
                         ("PUT", "upload.example"): {"id": "vid1", "status": {"privacyStatus": "private"}}})
        _, res = self.ship("--live", http=http, times={"youtube": SOON})
        self.assertIn("may stay private", res["youtube"]["warning"])

    # ---- status and accounts

    def test_status_of_a_zernio_post(self):
        self.config(zernio={"api_key": "K"})
        http = FakeHTTP({("GET", "/posts/zp1"): {"post": {"_id": "zp1", "status": "published", "platforms": [
            {"platform": "tiktok", "status": "published", "platformPostId": "742",
             "platformPostUrl": "https://www.tiktok.com/@x/video/742"}]}},
            ("GET", "/analytics?postId=zp1"): {"platformAnalytics": [
                {"platform": "tiktok", "analytics": {"views": 900, "likes": 40}}]}})
        code, out = self.run_post("status", "tiktok", "zp1", http=http)
        got = json.loads(out)
        self.assertEqual(code, 0)
        self.assertEqual(got["status"], "published")
        self.assertEqual(got["platform_post_id"], "742")
        self.assertEqual(got["analytics"], {"views": 900, "likes": 40})

    def test_status_of_a_youtube_video(self):
        self.config()
        self.google_token()
        http = FakeHTTP({("GET", "youtube/v3/videos"): {"items": [
            {"status": {"uploadStatus": "processed", "privacyStatus": "private", "publishAt": "2099-01-01T17:00:00Z"},
             "statistics": {"viewCount": "0", "likeCount": "0"}}]}})
        _, out = self.run_post("status", "youtube", "vid1", http=http)
        got = json.loads(out)
        self.assertEqual((got["status"], got["privacy"]), ("processed", "private"))
        self.assertEqual(got["analytics"], {"viewCount": 0, "likeCount": 0})

    def test_accounts_list_shows_no_secrets(self):
        self.config(zernio={"api_key": "SECRET"})
        _, out = self.run_post("accounts", http=FakeHTTP(dict(ZERNIO_ROUTES)))
        self.assertEqual(len(out.splitlines()), 3)
        self.assertNotIn("SECRET", out)


if __name__ == "__main__":
    unittest.main()
