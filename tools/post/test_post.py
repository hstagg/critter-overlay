"""The posting queue, end to end in a dry run: nothing here touches the network.

  python -m unittest tools/post/test_post.py      (needs ffmpeg for the clip)
"""

import contextlib
import io
import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import post  # noqa: E402


def no_network(*_a, **_k):
    raise AssertionError("a dry run tried to send")


@unittest.skipUnless(shutil.which("ffmpeg"), "needs ffmpeg")
class QueueTest(unittest.TestCase):
    def setUp(self):
        self.dir = Path(tempfile.mkdtemp())
        self.clip = self.dir / "clip.mp4"
        subprocess.run(["ffmpeg", "-v", "error", "-f", "lavfi", "-i", "color=c=pink:s=270x480:d=2",
                        "-pix_fmt", "yuv420p", str(self.clip)], check=True)
        self.cfg = self.dir / "config.json"
        self.cfg.write_text(json.dumps({"queue": str(self.dir / "queue"), "live": ["youtube"],
                                        "front": {"type": "post"}, "summary_key": "summary"}))
        for plat in post.PLATFORMS:
            post.SENDERS[plat] = no_network

    def tearDown(self):
        shutil.rmtree(self.dir, ignore_errors=True)

    def run_cmd(self, *argv):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            try:
                post.main(["--config", str(self.cfg), *argv])
            except SystemExit as e:
                if e.code not in (0, None):
                    raise
        return out.getvalue()

    def stage(self, title="Rare: Sea Otter", when="2026-10-01 18:00"):
        self.run_cmd("stage", str(self.clip), "--title", title, "--when", when,
                     "--caption", "The longer you stay, the rarer we get.",
                     "--hashtags", "#desktoppet #cozygames")
        return next((self.dir / "queue").glob("*.md"))

    def test_staged_file_reads_back(self):
        p = post.Post(self.stage())
        self.assertEqual(p.get("title"), "Rare: Sea Otter")
        self.assertEqual(p.get("hashtags"), "#desktoppet #cozygames")
        self.assertEqual(p.get("type"), "post")
        self.assertEqual(p.platforms, ["tiktok", "instagram", "youtube"])
        self.assertEqual(p.caption, "The longer you stay, the rarer we get.")
        self.assertFalse(p.approved)
        self.assertEqual(post.check_post(p), [])

    def test_unapproved_never_goes(self):
        self.stage()
        out = self.run_cmd("publish", "--now")
        self.assertIn("not approved", out)
        self.assertNotIn("dry run", out)

    def test_approved_dry_run_logs_and_sends_nothing(self):
        path = self.stage()
        path.write_text(path.read_text(encoding="utf-8").replace("- [ ] approve", "- [x] approve"),
                        encoding="utf-8")
        out = self.run_cmd("publish", "--now")
        for plat in post.PLATFORMS:
            self.assertIn(f"dry run {plat}", out)
        p = post.Post(path)
        self.assertEqual(p.posted, {})
        self.assertIn("## Log", p.body)
        self.assertIn("caption to paste", p.body)

    def test_live_needs_flag_and_list(self):
        path = self.stage(when="2026-01-01 09:00")  # long past, so due
        path.write_text(path.read_text(encoding="utf-8").replace("- [ ] approve", "- [x] approve"),
                        encoding="utf-8")
        sent = []
        post.SENDERS["youtube"] = lambda cfg, p: sent.append(p) or "vid1"
        out = self.run_cmd("publish", "--live")
        self.assertEqual(len(sent), 1)          # youtube is in the live list
        self.assertIn("dry run tiktok", out)    # the others stay dry
        self.assertEqual(post.Post(path).posted, {"youtube": "vid1"})
        self.run_cmd("publish", "--live")
        self.assertEqual(len(sent), 1)          # never twice

    def test_binned_and_future_are_left(self):
        path = self.stage()
        path.write_text(path.read_text(encoding="utf-8").replace("- [ ] approve", "- [x] approve")
                        .replace("- [ ] bin", "- [x] bin"), encoding="utf-8")
        self.assertEqual(self.run_cmd("publish", "--now"), "")
        self.stage(title="Later", when="2099-01-01 18:00")
        self.assertEqual(self.run_cmd("publish"), "")

    def test_auto_slot_follows_cadence(self):
        self.stage(when="2099-01-01 18:00")
        self.run_cmd("stage", str(self.clip), "--title", "Next", "--caption", "x")
        names = sorted(f.name for f in (self.dir / "queue").glob("*.md"))
        self.assertEqual(names[1], "2099-01-03 next.md")

    def test_check_catches_landscape(self):
        wide = self.dir / "wide.mp4"
        subprocess.run(["ffmpeg", "-v", "error", "-f", "lavfi", "-i", "color=c=pink:s=480x270:d=1",
                        "-pix_fmt", "yuv420p", str(wide)], check=True)
        self.clip = wide
        self.assertIn("not 9:16 (480x270)", post.check_post(post.Post(self.stage())))


if __name__ == "__main__":
    unittest.main()
