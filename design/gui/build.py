import json, re, pathlib, html.parser, sys
import parts
from parts import head, foot
from pages1 import home, critters, focus
from pages2 import world, sound, system, collection
from pages3 import tray, toasts, onboarding, EXTRA
from pages4 import foundations, notes

ROOT = pathlib.Path(__file__).parent
OUT = ROOT / "project"
PREV = ROOT / "preview"
OUT.mkdir(exist_ok=True); PREV.mkdir(exist_ok=True)
HEIGHTS = json.loads((ROOT / "heights.json").read_text()) if (ROOT / "heights.json").exists() else {}

# rows of (file, title, fn, w, h, dark, interactive)
ROWS = [
    ("Settings window, light", [
        ("Main.dc.html", "Settings · Home", home, 1100, 880, False, True),
        ("Settings-Critters.dc.html", "Settings · Critters", critters, 1100, 1220, False, True),
        ("Settings-Focus.dc.html", "Settings · Focus", focus, 1100, 1780, False, True),
        ("Settings-World.dc.html", "Settings · World", world, 1100, 1420, False, True)]),
    ("Settings window, continued", [
        ("Settings-Sound.dc.html", "Settings · Sound", sound, 1100, 780, False, True),
        ("Collection.dc.html", "Collection (Seen Log)", collection, 1100, 1240, False, True),
        ("Settings-System.dc.html", "Settings · System", system, 1100, 1560, False, True)]),
    ("Dark theme", [
        ("Dark-Home.dc.html", "Dark · Home", home, 1100, 880, True, True),
        ("Dark-Critters.dc.html", "Dark · Critters", critters, 1100, 1220, True, True),
        ("Dark-Collection.dc.html", "Dark · Collection", collection, 1100, 1240, True, True)]),
    ("Around the desktop: tray and toasts", [
        ("Tray.dc.html", "Tray panel and icon, light and dark", tray, 1280, 1720, False, False),
        ("Toasts.dc.html", "Rare sighting toasts", toasts, 1280, 1000, False, False)]),
    ("First run", [
        ("Onboarding.dc.html", "First run, four steps", onboarding, 2160, 820, False, False)]),
    ("Foundations and notes", [
        ("Foundations.dc.html", "Foundations: colour, type, controls, Godot notes", foundations, 1280, 2800, False, False),
        ("Notes.dc.html", "Notes: assumptions and v2.0 mapping", notes, 1280, 2900, False, False)]),
]

VOID = {"area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "source", "track", "wbr",
        "path", "circle", "ellipse", "rect", "use", "line", "polygon", "polyline", "stop"}

class Check(html.parser.HTMLParser):
    def __init__(self):
        super().__init__(); self.stack = []; self.err = []
    def handle_starttag(self, tag, attrs):
        if tag not in VOID: self.stack.append(tag)
        for k, v in attrs:
            if v and k not in ("style", "class", "aria-label", "href", "title") and "var(" in v:
                self.err.append(("var-in-attr", tag, k, v))
    def handle_endtag(self, tag):
        if tag in VOID: return
        if self.stack and self.stack[-1] == tag: self.stack.pop()
        else: self.err.append((tag, self.stack[-3:], self.getpos()))

CHECK_JS = r"""<script>
window.addEventListener('load', () => setTimeout(() => {
  const root = document.body.firstElementChild;
  const rb = root.getBoundingClientRect();
  const issues = [];
  let maxBottom = 0;
  for (const el of root.querySelectorAll('*')) {
    if (el.closest('svg') && el.tagName.toLowerCase() !== 'svg') continue;
    const r = el.getBoundingClientRect();
    if (r.width === 0 || r.height === 0) continue;
    const cs = getComputedStyle(el);
    if (cs.position !== 'absolute' && r.height < rb.height - 2 && !el.closest('aside')) maxBottom = Math.max(maxBottom, r.bottom - rb.top);
    if (r.bottom > rb.bottom + 1 || r.right > rb.right + 1) issues.push('OUT ' + el.tagName + ' ' + (el.textContent||'').trim().slice(0,40) + ' r=' + Math.round(r.right-rb.left) + ' b=' + Math.round(r.bottom-rb.top));
    if (el.children.length === 0 || [...el.childNodes].some(n => n.nodeType === 3 && n.textContent.trim())) {
      if (el.scrollWidth > el.clientWidth + 1 && cs.overflow !== 'visible' && el.clientWidth > 0) issues.push('CLIP-X ' + el.tagName + ' ' + (el.textContent||'').trim().slice(0,40));
    }
    const p = el.parentElement;
    if (p && p !== root && el.tagName !== 'svg' && cs.position !== 'absolute') {
      const pr = p.getBoundingClientRect(); const pcs = getComputedStyle(p);
      if ((pcs.overflow === 'hidden') && (r.right > pr.right + 2 || r.bottom > pr.bottom + 2) && !p.closest('svg') && el.tagName !== 'DIV' ) issues.push('HIDDEN ' + el.tagName + ' ' + (el.textContent||'').trim().slice(0,40));
      if (r.right > pr.right + 2 && pcs.overflow === 'visible' && cs.position !== 'absolute' && p.tagName !== 'svg') issues.push('SPILL ' + el.tagName + ' ' + (el.textContent||'').trim().slice(0,40) + ' by ' + Math.round(r.right - pr.right));
    }
  }
  const pre = document.createElement('pre'); pre.id = 'report';
  pre.textContent = JSON.stringify({h: Math.round(rb.height), content: Math.round(maxBottom), issues: [...new Set(issues)].slice(0, 60)});
  document.body.appendChild(pre);
}, 600));
</script>"""

def preview_html(doc):
    helmet = re.search(r"<helmet>(.*?)</helmet>", doc, re.S).group(1)
    body = re.search(r"</helmet>(.*?)</x-dc>", doc, re.S).group(1)
    return f'<!doctype html><html lang="en-GB"><head><meta charset="utf-8">{helmet}</head><body>{body}{CHECK_JS}</body></html>'

ALL = []
y = 0
notes_ = {}
for ri, (rtitle, boards) in enumerate(ROWS):
    x = 0; rowh = 0
    for f, title, fn, w, h, dark, inter in boards:
        h = HEIGHTS.get(f, h)
        parts.MODE["dark"] = dark
        extra = EXTRA if f in ("Tray.dc.html", "Toasts.dc.html", "Onboarding.dc.html", "Foundations.dc.html", "Notes.dc.html") else ""
        body = fn()
        body = re.sub(r"height: \d+px; display: flex; background: var\(--ground\); color: var\(--ink\); overflow: hidden", f"height: {h}px; display: flex; background: var(--ground); color: var(--ink); overflow: hidden", body, count=1)
        body = re.sub(r"^(<div style=\"width: \d+px; height: )\d+px", lambda m: m.group(1) + f"{h}px", body.lstrip(), count=1)
        if f == "Notes.dc.html":
            body = body.replace(" > ", " › ")
        if dark:
            body = body.replace("<div ", '<div class="th-dark" ', 1) if 'class="th-dark"' not in body[:200] else body
        doc = head(title.split(":")[0], extra) + body + foot(w, h)
        assert "{{" not in body, f
        assert "—" not in doc and "–" not in doc, f"dash in {f}"
        c = Check(); c.feed(body)
        if c.err or c.stack:
            print(f, "ERR", c.err[:5], "OPEN", c.stack[:5])
        (OUT / f).write_text(doc, encoding="utf-8")
        (PREV / f.replace(".dc.html", ".html")).write_text(preview_html(doc), encoding="utf-8")
        ALL.append((f, title, w, h, x, y, inter))
        x += w + 80; rowh = max(rowh, h)
    notes_[f"t{ri+1}"] = {"x": 0, "y": y - 260, "text": rtitle, "kind": "title1", "maxW": x - 80}
    y += rowh + 380
parts.MODE["dark"] = False

notes_["s1"] = {"x": 4720, "y": 0, "w": 300, "fill": "purple", "size": "m",
                "text": "Second pass: violet and plum theme, with dark versions of Home, Critters, Collection and the tray. Nav links work in Play. Every v2.0 control is mapped on the Notes artboard at the bottom."}
boards = {}
for f, title, w, h, x, y, inter in ALL:
    b = {"x": x, "y": y, "w": w, "h": h, "title": title}
    if inter: b["is_interactive"] = True
    if f.endswith(".dc.html") and w == 1100: b["radius"] = 16
    boards[f] = b
live = json.loads((ROOT / "live_canvas.json").read_text(encoding="utf-8"))
live["boards"] = boards
live["order"] = [a[0] for a in ALL]
live["notes"] = notes_
(OUT / "canvas.json").write_text(json.dumps(live, indent=2), encoding="utf-8")
print("built", len(ALL))
