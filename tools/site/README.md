# The landing site

`site/` is Critter Overlay's website, published to GitHub Pages at
https://hstagg.github.io/critter-overlay/ by `.github/workflows/pages.yml` on
every push to `main` that touches `site/` or `tools/site/`. Only `site/` is
published; `docs/` (the internal plans) never is.

- `index.html`: the home page. `press/`: the press kit. `privacy/`: privacy.
- `style.css`: one stylesheet, in the app's colours (`godot/gui/palette.gd`,
  light and dark) and fonts (Fredoka and Nunito, cut to Latin as WOFF).
- No JavaScript, no cookies, nothing loaded from other sites. The privacy
  page says so; keep it true.
- The press kit zip (`press/critter-overlay-press-kit.zip`) is built by the
  workflow from `press/media/` and never stored in git.

## Checks

```powershell
python tools/site/site.py check
```

Every page has its title, description, canonical and Open Graph tags; every
local link and image exists; no page has an em-dash or en-dash, mentions
another operating system or loads anything from another site; and every link
page matches the template. The Tests workflow runs it on each pull request.

## Link pages: counting visits per channel or creator

`/c/<id>/` sends the visitor straight on to the itch.io page. Its referrer
policy (`no-referrer-when-downgrade`) lets the browser pass the full address
to itch.io, so the itch dashboard's Referrers report shows one row per link.

```powershell
python tools/site/site.py link tiktok     # a named link
python tools/site/site.py pool 10         # ten random ids, for creators
```

- An id is public: never a person's name or handle. Which creator holds which
  id is kept privately, outside this repo.
- The counts are visits that reached itch.io, not downloads, and they are a
  floor: Safari, and Firefox in strict or private mode, send only the site's
  origin, so those visits pool in a single `hstagg.github.io` row.
- itch.io has no documented campaign parameter (`?ac=` is its affiliate code
  and counts purchases only), and GitHub Pages reports no traffic.
- A cookieless counter (GoatCounter, for example) would count every visit to
  a link page in any browser, but it needs an account and would change what
  the privacy page says.

## Media

The clips and desk screenshots are the game's own `--film` captures pasted
onto mock desktops (`tools/film`, `tools/desk`), cropped to 960×600 loops,
silent. The critter art is the game's own renders, and the icon is
`godot/icon.png`. When a release ships, add it to the press kit's release
history.
