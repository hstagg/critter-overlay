"""The landing site in site/ (GitHub Pages): link pages and checks.

  python tools/site/site.py link ID [ID ...]   write site/c/<ID>/index.html
  python tools/site/site.py pool N             add N random link ids and print them
  python tools/site/site.py check              the checks CI runs (Tests and Site workflows)

A link page (/c/<id>/) sends the visitor straight on to the itch.io page. Its
referrer policy lets the browser tell itch.io the full page address, so itch's
Referrers report shows a row per link (Chrome, Edge, Firefox). Safari and
private or strict modes send only the site's origin, so those visits pool in
one row and each link's count is a floor. Nothing is set or stored here.

The repo is public: an id must never be a person's name or handle. Which id
belongs to which channel or creator is kept privately, outside this repo.
"""

import re
import secrets
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SITE = ROOT / "site"
BASE = "https://hstagg.github.io/critter-overlay/"
ITCH = "https://critteroverlay.itch.io/critter-overlay"
ID_RE = re.compile(r"^[a-z0-9][a-z0-9-]{1,30}$")
POOL_CHARS = "abcdefghjkmnpqrstuvwxyz23456789"   # no 0/o, 1/l/i
BUILT_AT_DEPLOY = {"press/critter-overlay-press-kit.zip"}   # pages.yml makes it

LINK = """<!doctype html>
<html lang="en-GB">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Critter Overlay on itch.io</title>
<meta name="robots" content="noindex">
<meta name="referrer" content="no-referrer-when-downgrade">
<meta http-equiv="refresh" content="0; url={itch}">
<link rel="icon" href="../../favicon.ico" sizes="any">
<link rel="stylesheet" href="../../style.css">
</head>
<body>
<main class="page">
  <div class="wrap page-head">
    <h1>Off to itch.io</h1>
    <p>Critter Overlay is free on itch.io, for Windows 10 and 11.</p>
    <p><a class="btn" href="{itch}">Continue to itch.io</a></p>
  </div>
</main>
</body>
</html>
"""


def link_page() -> str:
    return LINK.format(itch=ITCH)


def write_link(link_id: str) -> Path:
    if not ID_RE.match(link_id):
        sys.exit(f"bad id {link_id!r}: lowercase letters, digits and hyphens, 2 to 31 long")
    path = SITE / "c" / link_id / "index.html"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(link_page(), encoding="utf-8", newline="\n")
    return path


def pool(n: int) -> list:
    have = {p.name for p in (SITE / "c").iterdir() if p.is_dir()} if (SITE / "c").exists() else set()
    out = []
    while len(out) < n:
        i = "".join(secrets.choice(POOL_CHARS) for _ in range(5))
        if i not in have and not i.isalpha() and not i.isdigit():   # a letter and a digit, so never a word
            have.add(i)
            out.append(i)
            write_link(i)
    return out


# --- Checks ---------------------------------------------------------------------

DASHES = {"\u2014": "em-dash", "\u2013": "en-dash"}
FORBIDDEN_WORDS = re.compile(r"\b(mac|macos|mac os|os x|osx|linux|ubuntu|ios|android)\b", re.I)
HEAD_TAGS = [
    ("title", re.compile(r"<title>[^<]{10,}</title>")),
    ("description", re.compile(r'<meta name="description" content="[^"]{50,}">')),
    ("canonical", re.compile(r'<link rel="canonical" href="' + re.escape(BASE) + r'[^"]*">')),
    ("og:title", re.compile(r'<meta property="og:title" content="[^"]+">')),
    ("og:description", re.compile(r'<meta property="og:description" content="[^"]+">')),
    ("og:url", re.compile(r'<meta property="og:url" content="' + re.escape(BASE) + r'[^"]*">')),
    ("og:image", re.compile(r'<meta property="og:image" content="' + re.escape(BASE) + r'[^"]+">')),
    ("viewport", re.compile(r'<meta name="viewport" content="width=device-width, initial-scale=1">')),
]
REF_RE = re.compile(r'\b(?:href|src|poster)="([^"]+)"')
EXTERNAL_LOAD = re.compile(r'<(?:script|link|img|video|source|iframe)\b[^>]*\b(?:src|href)="(?:https?:)?//', re.I)


def visible_text(html: str) -> str:
    html = re.sub(r"<script\b.*?</script>", " ", html, flags=re.S)
    return re.sub(r"<[^>]+>", " ", html)


def check() -> list:
    errors = []
    pages = sorted(SITE.rglob("*.html"))
    if not pages:
        return ["no pages in site/"]
    for page in pages:
        rel = page.relative_to(SITE).as_posix()
        html = page.read_text(encoding="utf-8")
        is_link = rel.startswith("c/")
        for ch, name in DASHES.items():
            if ch in html:
                errors.append(f"{rel}: has an {name}")
        m = FORBIDDEN_WORDS.search(visible_text(html))
        if m:
            errors.append(f"{rel}: mentions {m.group(0)!r} (the site is Windows only)")
        for line in html.splitlines():
            if EXTERNAL_LOAD.search(line) and 'rel="canonical"' not in line:
                errors.append(f"{rel}: loads something from another site: {line.strip()[:90]}")
        if is_link:
            if html != link_page():
                errors.append(f"{rel}: differs from the link page (rewrite it with: site.py link {page.parent.name})")
            continue
        for name, rx in HEAD_TAGS:
            if not rx.search(html):
                errors.append(f"{rel}: missing or malformed {name}")
        for ref in REF_RE.findall(html):
            if re.match(r"^(https?:|mailto:|#)", ref):
                continue
            target = (page.parent / ref.split("#")[0]).resolve()
            if ref.endswith("/"):
                target = target / "index.html"
            try:
                key = target.relative_to(SITE.resolve()).as_posix()
            except ValueError:
                errors.append(f"{rel}: {ref} points outside the site")
                continue
            if key not in BUILT_AT_DEPLOY and not target.is_file():
                errors.append(f"{rel}: {ref} does not exist")
    return errors


def main() -> None:
    args = sys.argv[1:]
    if args[:1] == ["link"] and len(args) > 1:
        for i in args[1:]:
            print(write_link(i).relative_to(ROOT).as_posix())
    elif args[:1] == ["pool"] and len(args) == 2:
        print("\n".join(pool(int(args[1]))))
    elif args == ["check"]:
        errors = check()
        for e in errors:
            print(e)
        print(f"site check: {len(errors)} problem(s)")
        sys.exit(1 if errors else 0)
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
