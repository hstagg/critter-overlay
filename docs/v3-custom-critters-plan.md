# Custom critters in v3: plan

Status: planning, no code. Written 2026-10-07 against the `v3-critters` tip (6c4b53b).
Covers what custom critters could be in the Godot rewrite, how each kind fits the
rig, rarity, the Collection, clothes and performance, the risks, rough effort, and
when to ship. Ends with five decisions for Harrison.

---

## 1. Where things stand

**v2.0 (Python, `src/custom_critters/`)** made a custom critter from one image:
size and type checks, EXIF strip, corner flood-fill background removal with a 1 px
feathered alpha, a procedural 4-frame walk (split at 58% height, bob, lean and a
shear on the bottom half), palette extraction for particles, and an animated
preview before anything was written. `.critter` files (schema 2) are zips of
frames, masks, sounds and meta, validated before extraction (size caps, allowed
extensions, no path traversal, frame-size checks, WAV cap). Install by
drag-drop or file picker, with a confirm dialog.

**v3 (Godot 4)** works differently, and that changes what "custom" means:

- A critter is a **rig of SVG parts** in one shared 300 x 280 frame, facing
  left, so a part's pivot is where it sits in the frame (`critters/critter.gd`).
  The kitten has 23 parts and the hedgehog 26: sit body, walk body, loaf body,
  four legs, head, eyes open and shut, ears, tail, groom arm, scratch foot and so on.
- Each species is a **script** (`critters/<species>.gd`) that sets proportions
  in `_define()` (pivots, `head_at`, `walk_legs`, `hit_bounds`, leg length,
  stride) and poses its own behaviours (the turtle's head tuck, the hedgehog's ball).
  Side-walkers share `two_head.gd`.
- **Recolouring a rig already happens.** The golden kitten is the kitten rig
  with its colours swapped by `design/studio/golden_rig.py` and extras drawn in,
  and it overrides `_load_textures()` to read from `art/golden_kitten/<variant>/`.
  Dyes on clothes do the same thing at runtime with a string replace (`wear.gd`
  `svg()`).
- **Clothes are generated at build time.** `design/wear/build.py` holds head
  metrics per species (`cx, cy, rx, ry, eye_y, eye_dx, eye_r, chin, gap, side`)
  and draws every item (about 80) for every species into
  `art/wear/<item>/<species>.svg`. Nothing fits clothes at runtime. A head the
  build never saw gets no clothes.
- **Rarity** (`economy.gd`) rolls five tiers. Harrison's model, being built now:
  Common is the species, Rare and Epic are designed versions of a species,
  Legendary is only the special visitors, which have secret colour tiers.
  The **Collection** keys on `"species:tier"` and pays berries for first finds
  and full rows.
- **v2.0 customs aren't carried over yet.** `economy.import_v2_seen()` skips
  `custom:` keys on purpose ("left for their own import"). Anyone upgrading with
  custom critters will lose them from the overlay until v3 can show them. That
  affects when this has to ship (section 9).

---

## 2. The options, from simple to sophisticated

Five kinds of custom critter plus sharing, which every kind needs. They build on
each other, so most of the work done for one kind is reused by the next.

### Tier 1: Sticker critter (a still image with procedural motion)

**What it is.** v2.0's feature ported: drop in a PNG or JPG, remove the
background, feather the edge, preview it, keep it.

**How it fits the rig.** It becomes a new minimal rig, `critters/still.gd`,
which extends `critter.gd` and has a single `body` part (the image, scaled into
the 300 x 280 frame with its feet on `ground_y`). Motion is done with the
existing springs rather than baked frames: walk bob and lean, the bottom-half
shear done as a `Polygon2D` mesh deform (or a small shader), squash on landing,
a breathing squash while sitting. Because it's still a critter, the host window,
dragging, throwing, dizzy spins, wall climbing, auras and the Collection's live
preview all work unchanged. Behaviours are a short whitelist: walk, sit, hop,
look at cursor (lean towards it), nap (settle lower, drift Z's), shake off. No
ears, tail or blinks.

**Clothes.** In the importer the user drags an ellipse over the head ("Where's
its head?") while a bow previews live. That gives `cx, cy, rx, ry` and a chin
line, and the runtime fit in section 4 hangs clothes on it. Items that hide parts
(hoods) and species-only items are left out.

**Port notes.** GDScript per-pixel loops are slow, so downscale to about 512 px
before the flood fill (about 260k pixels, well under a second), or do the fill
in a shader. Re-encoding through `Image.save_png` drops EXIF (and GPS) without
extra work. v2.0 `.critter` files import as stills, using `source/` if present,
else `frame_0`.

**Honest limit.** It's a cardboard cut-out next to a cast that blinks, grooms and
chases its tail. It's worth having for v2.0 parity and photos of real pets, but
it isn't the sophisticated version.

### Tier 2: Coat Studio (recolour and re-pattern a built-in rig)

**What it is.** Pick a species, then choose colours for its roles (coat, deep
coat, belly and muzzle, inner ear, nose, iris) and a pattern (spots, stripes,
tabby, patches, socks, a blaze, freckles, two-tone), each with a colour and a
density. Name it. Optional **"match my pet"**: drop a photo, v2.0's palette
extraction suggests the coat, belly and accent colours, and the photo is thrown
away afterwards. Nothing from the image is kept or shared, only the colours.

**How it fits the rig.** This is the golden kitten pipeline made data-driven and
run at runtime:

1. **Build time, once per species:** a script tags each species' palette with
   roles (`art/<species>/roles.json`: `{"coat": ["#F6C28F"], "coat_deep":
   ["#E89A5B"], ...}`). Coat shapes in every part get an `id` so a pattern can
   be clipped to them (`<clipPath>` that references the coat shape). This is
   about half a day per species with a check sheet.
2. **Runtime:** for each part, swap the role colours (`replacen`, as dyes do),
   insert the pattern group clipped to the coat, rasterise, and cache under
   `species:coat_id`. `golden_kitten.gd`'s `_load_textures` override already
   has this shape.

Every behaviour, pose, pair interaction and perk move works because it's the same
rig. **Clothes fit with no extra work** because the head is unchanged, so the
species' own `art/wear/*/<species>.svg` applies directly.

**Known wrinkle.** Patterns are drawn per part, so spots on the sitting body
won't sit in exactly the same places on the walking body. That's acceptable
because the built-in critters already swap whole bodies between poses. Seed each
pattern from the coat ID so it stays the same from one spawn to the next.

**Guard rail.** It changes palette and pattern only, never structure, so the
designed Rare and Epic versions (the hatchling's daisy sprout, the lynx's
tufts) stay special. A homemade gold kitten is still visibly not the golden
kitten: no glitter, no sheen, no aura.

**Why it matters.** It's the best value for the effort here. It also has the
lowest moderation risk to share, because a coat is just a recipe (section 2.6).

### Tier 3: Guided cut-out (rig a still image, part by part)

**What it is.** It sits between Tier 1 and Tier 4. The user brings one image and
chooses a body plan: "sits facing you, walks side-on" (`two_head`), "sits and
walks the same way" (kitten or rabbit style), or "upright" (penguin or duck
style). The app overlays that plan's template and the user lassoes the head,
tail, each ear and each leg, and drops pivot pins ("the neck bends here", "this
leg swings from here"). The app suggests cuts from the silhouette (the top blob
is the head, low protrusions are legs, a thin protrusion on the far side is a
tail) and the user corrects them.

**How it fits the rig.** The cuts become parts in the 300 x 280 frame. The hole
each cut leaves in the body (behind the head, under a leg) is filled with an
edge-colour smear or a blurred dilation. It's mostly hidden by the part in front,
so it doesn't need to be clever. The pins become `pivots`, `head_at` and
`walk_legs`. The rig is the base plan's script with these numbers passed in, so
it gets head turns, tail springs, ear flicks and a real leg swing. Closed eyes
for blinks and naps: the user taps each eye and the app draws a closed-eye arc
in `OUTLINE` over it. It's crude, but it reads right.

**Clothes.** The head ellipse comes from the head cut, then the runtime fit in
section 4 applies.

**Prerequisite.** Species shape has to be loadable from data rather than
constants in a script (section 5). This is also the tier where the UX matters
most: a pivot editor that doesn't confuse people is most of the effort.

### Tier 4: Part kit (an artist imports a full rig)

**What it is.** For people who draw. Download a template per body plan: an SVG
with one named layer per part, the existing species' art faded in as a guide,
and pivot marks. Draw over it in Inkscape, Affinity or Illustrator, export, and
drop it in. Layers are matched by name (`inkscape:label` or `id`): `head`, `ear-l`,
`walk-body` and so on. A loose folder of named SVG or PNG files also works.

**How it fits the rig.** `custom.json` says `"base": "kitten"` (any body plan),
and the critter runs that species' script with art from
`user://custom/<id>/parts/`. **Missing parts fall back to the base species'
art**, so an artist can start by redrawing only the head and tail and add more
later. The manifest can override a small, safe set of numbers (head pivot,
`leg_len`, `stride_deg`, `speed_range`, `critter_scale` within limits) and
validation rejects the rest. Species-specific behaviours (the turtle's tuck,
the hedgehog's ball) are only available if the plan's extra parts are supplied
(`ball`, for example). Otherwise they drop out of `idles`.

**Clothes.** Head metrics are computed from `head.svg`'s bounding box and
`eyes.svg` (the same numbers `build.py` records by hand), shown in a preview the
artist can nudge, then fitted at runtime (section 4).

**Why it matters.** This is the "sophisticated" tier for the people who'll make
the content others download. Shimeji survives on exactly this kind of creator.
A clean template and validator are worth more than any editor UI.

### Tier 5: AI-assisted part splitting

**What it is.** Tier 3's lasso step done by a model: upload one image, and
segmentation proposes the head, ears, legs and tail; inpainting fills what each
part hides; optionally a stylise pass redraws the result in the house style
(outlines, big eyes, blush) so it doesn't look like a photo next to the cast.

**Three very different things share this name:**

| Variant | What runs | Cost and risk |
|---|---|---|
| **5a. Segmentation assist** | A small local segmentation model (MobileSAM-class, roughly 40 MB as ONNX) suggests the Tier 3 cuts; the user still confirms them | New runtime dependency and a bigger install. Not generative: it outputs masks, not art. |
| **5b. Local inpaint** | Plus a generative fill for hidden areas | Models are gigabytes. It's generative AI, so it needs disclosure (section 7.3). Too big to bundle. |
| **5c. Cloud stylise** | Image goes to a hosted model, which returns house-style parts | Ongoing per-use cost, an account or key, a privacy policy (people's pets, homes and faces), live-generated content and its guardrails, and it breaks when the service changes |

**How it fits.** All three output a Tier 3 or Tier 4 critter, so nothing
downstream changes. 5a is a real improvement to Tier 3. 5b and 5c are big
product and policy decisions, not engineering add-ons.

### 2.6 Sharing (.critter v3)

Every tier needs a way to share, and the kinds of share carry very different
amounts of risk:

- **Coat recipe** (Tier 2): `{"base": "kitten", "roles": {...}, "pattern":
  {...}, "name": "..."}`. That's a few hundred bytes, so it can go in a `.critter`
  file or a **copyable code** (base64 in a short string you paste into Settings).
  No images, so the only free text to check is the name.
- **`.critter` v3 package** (Tiers 1, 3, 4): a zip with `manifest.json`
  (schema 3, base plan, `app_min_version`, content hash), `meta.json` (name,
  author, licence, `made_with` tier, an `ai_made` flag), `parts/`, optional
  `sound.wav`, `thumb.png`. Godot 4 has `ZIPReader`. Keep v2.0's checks (size
  caps, file count, extension whitelist, no traversal) and add **SVG
  sanitising**: parse with `XMLParser` and write back out only a whitelist of
  elements and attributes (`svg g path circle ellipse rect polygon polyline line
  defs clipPath linearGradient radialGradient stop`). Drop `<image>` unless it's a
  `data:image/png` URI, and drop `<script>`, `<foreignObject>`, `<use>` with
  external refs, entities, and anything over a path-count cap.
- **v2.0 packages** import as Tier 1 stills.
- **Install** stays as v2.0: drop a file on any critter window (Godot's
  `files_dropped`) or use the file picker, then a confirm dialog with name,
  author, licence and a preview, and nothing written until Accept.

Where files are shared (privately, a gallery, the Steam Workshop) is a separate
question (sections 7.1 and 7.2, and decision 5).

---

## 3. Rarity and the Collection

The rarity model gives tiers a meaning: Rare and Epic are **designed versions**
of a species and Legendary is **special visitors**. A user-made critter doesn't
fit either, and the economy has to stay sound: if customs paid first-find
berries, making 50 recolours would make 50 payouts.

**Recommended: a "Homemade" shelf, outside rarity.**

- Customs never roll a tier and never get an aura. They arrive by their own
  visit weight (the per-species `visits` setting already exists).
- The Collection gets a **Homemade** section below the species rows: one card
  per custom with its live preview, sighting count, bond, and a small
  "homemade" mark (plus the author, if it was imported).
- **No berries** from sighting customs (no first find, no row bonus), and they
  never bring presents (`BRING_CHANCE`), since a present is a free item.
- They **can wear** owned clothes, perk clothes included (dance, fly,
  celebrate). Lucky charm does nothing on them, since luck acts on rarity rolls.
- Sightings diary: leave them out, or show them with the homemade mark and no
  tier colour.
- Collection keys: `"custom:<id>"`, separate from `"species:tier"`, so
  `row_complete` and the first-find tables never see them.

**Alternatives** (decision 2): (b) let a custom's author add up to two extra
coats that turn up rarely, as a homemade "shiny" with a plain sparkle and
no berries; or (c) let customs roll the five tiers like a species. (c) conflicts
with the rarity model and opens the berry exploit.

**A possible berry sink:** unlock Coat Studio patterns with berries (say, the
first pattern free and the rest at medium-item prices), so customs give berries
somewhere to go rather than earning them. Worth considering when the economy is
tuned. It isn't needed for the feature to work.

**Card count:** every Collection card ticks a live critter. With many customs,
cap the number of live cards (say, 12) and show a still thumbnail for the rest
until hovered.

---

## 4. Clothes on custom heads

| Tier | Clothes |
|---|---|
| 2 Coat Studio | The base species' files. No work. |
| 1, 3, 4 | No file exists for this head. Needs fitting at runtime. |

**Recommended: an affine fit from a reference species.** Each item's
generator positions things from the head ellipse (`top(m, x)`, `cx`, `rx`,
`chin`), so most items can be moved from a reference species onto a new head with
one `<g transform="translate(...) scale(s)">` wrapped round the item's SVG
before rasterising. That's a string operation like the dyes, and cheap. Anchor by
slot: head items at the crown (`top(m, cx)`), face items at the eye line, neck
items at the chin. Use a **uniform** scale (`s = rx_new / rx_ref`) so bells stay
round and outline width stays roughly constant, and pick as the reference the
built-in species whose `ry/rx` is closest to the new head's. Exclude items that
hide parts (hoods) and species-only items.

Check: render every item on a few awkward test heads (very wide, very tall,
tiny) as one contact sheet (`design/wear/sheet.py` already makes these), and
exclude any item that looks wrong on a "fits badly" list rather than fixing it
case by case.

**Later, if the fit isn't good enough:** port the item generators to GDScript
(about 730 lines of Python across the `items_*.py` files) so runtime draws
exactly what `build.py` would. That's mechanical, but it means a second copy to
keep in step with every new item, so only do it if the affine fit fails the check.

---

## 5. Engine work all tiers above 1 share

1. **Pluggable art source.** `critter.gd` loads `res://art/<species>/<part>.svg`.
   Generalise the golden kitten's override: a critter carries an `art_key`
   (`kitten`, `kitten@coat:ab12`, `custom:xyz`) and a resolver that returns a
   part's SVG text, with base-species fallback. Small.
2. **Shape as data.** Move each species' `_define()` numbers (pivots, `head_at`,
   `tail_at`, `walk_legs`, `hit_bounds`, wear anchors) into a dictionary that
   can be overridden from a manifest. Tier 4 needs this for its safe overrides
   and Tier 3 needs it completely. Medium: every species script needs touching,
   and every species needs re-checking on screen afterwards.
3. **Raster cache.** Rasterise customs **once, at install**, to PNG in
   `user://custom/<id>/cache/`, so a spawn never parses user SVG. That's for
   both speed and safety. Rebuild the cache when the app version changes.
4. **Custom store.** `user://custom/<id>/` (the project uses a custom user dir,
   "Critter Overlay") holding `custom.json`, `parts/`, `cache/` and `sound.wav`.
   Per CLAUDE.md, how config is stored is something to discuss first. This is
   new storage beside the settings file, not a change to it.

---

## 6. Performance

- **Textures.** A part rasterises at `PART_SCALE` 0.75, about 225 x 210 RGBA
  (about 190 KB, or about 250 KB with mipmaps). A 23-part rig is therefore about
  6 MB, shared by every critter of that kind through the static `_textures`
  cache. A custom costs the same as a species, and only once one has spawned
  (loading is lazy).
- **Coats.** Each coat is a full set of textures (about 6 MB). Ten coats on
  screen is 60 MB of VRAM. That's fine on any desktop GPU, but the cache should
  release a coat when none of it has been on screen for a while. The current
  cache never releases anything.
- **Clothes.** One texture per item per custom, the same as built-ins.
- **Imports.** Cap raster parts at the frame size (reject or downscale anything
  larger) and cap SVG complexity: auto-traced or exported SVGs can be a megabyte
  with thousands of nodes. The install-time raster cache keeps this off the
  spawn path.
- **Stills** are the cheapest of all: one texture and a small mesh.
- **Windows.** Each critter is its own small window (`host.gd`), so customs
  count against the same on-screen limit as everything else. There's no new
  per-window cost.
- **Collection** live previews: cap them as in section 3.

Check for any tier: frame time with 12 critters on screen including 6 customs
stays within 1 ms of the same scene with built-ins only, and VRAM stays under a
fixed budget (say, 150 MB) with 10 coats spawned.

---

## 7. Risks

### 7.1 Moderation of shared files

- **What people will make.** Going by Shimeji's library, mostly fan art of
  famous characters. That's a trademark and copyright exposure for whoever
  **hosts** them, not for the app.
- **Private trading** (Discord, email): Harrison hosts nothing, so exposure is
  low. Keep the confirm dialog and a line saying to install only from people you
  trust.
- **A hosted gallery** (a pinned GitHub Discussion or a gallery page): this is
  where Shimeji-style reach comes from, but Harrison becomes a moderator. He'd
  need takedowns for infringing or offensive uploads, a reporting route, and the
  time to act on reports.
- **Photos of people.** Tier 1 and 5 make it easy to turn a photo of a person
  (or a child) into a critter and share it. Strip metadata always, warn when
  exporting a still that came from a photo, and consider not letting Tier 1
  stills be exported at all (they're for your own pet).
- **Coat recipes** are almost free of this risk: colours and pattern IDs only.
  Cap the name length and allowed characters. This is the main reason to lead
  with Tier 2 for sharing.
- **File safety** (any channel): zip bombs, traversal, and SVG parser attack
  surface (entity expansion, external refs, huge path counts). Handle it with
  the whitelist sanitiser and install-time rasterising (section 2.6), plus
  fuzzing the importer with hostile files before release.

### 7.2 Steam Workshop or not

**For:** discovery, which the v2.0 market research names as the long-term moat
(Wallpaper Engine, VPet). Valve hosts the files, users get subscribe and
auto-update, and there's reporting built in.

**Against:**
- It needs a Steam release, which is undecided.
- It needs GodotSteam (a GDExtension), a new dependency, which CLAUDE.md says
  to discuss first.
- It needs Steamworks UGC upload and subscribe UI in the app.
- Harrison would still be expected to act on reports.
- The free GitHub build can't use it, so users split into two groups.
- The `.critter` format has to be stable before thousands of files depend on it.

**Recommended:** treat the Workshop as **a channel for `.critter` files, never
the format itself**. Ship `.critter` sharing first, let the format settle for a
release or two, and add the Workshop only alongside a Steam SKU.

### 7.3 AI-art disclosure

- **App-side generative AI** (5b, 5c): Steam's content survey requires
  disclosing AI-generated content, and live-generated content also needs a
  description of the guardrails against illegal or infringing output. The
  disclosure is shown on the store page. Check the exact current wording when
  submitting, since Valve has revised it more than once. Beyond the rules, the
  cosy-indie audience this app is aimed at is often hostile to generative art,
  and "every critter hand-designed" is a selling point worth keeping.
- **User-uploaded AI art**: it can't be detected, so don't promise to. Add an
  `ai_made` flag to `meta.json` that authors set, so a gallery can filter on it.
- **Segmentation only** (5a) outputs masks, not art. It's arguably not
  "AI-generated content", but disclose it if there's doubt. Disclosing costs
  little, and being caught out costs a lot.
- **Related, but outside this plan:** the built-in cast is drawn by studio
  scripts written with an AI assistant and approved by Harrison. Steam's
  disclosure question applies to v3 itself whether or not custom critters ship,
  so it's worth settling before a store page exists.

### 7.4 Other risks

- **Upgraders lose v2.0 customs** if v3.0 can't show them (section 1). That's
  the strongest argument for doing something in v3.0.
- **Scope pull on launch.** Every tier touches the Collection, economy and
  Settings, which are what v3.0 is still building. Running both at once means
  two sets of moving parts.
- **Format lock-in.** Whatever `.critter` v3 ships as must be read forever.
  Ship the smallest manifest that works and version it.
- **Body-plan changes.** If a species' rig changes after launch (new parts,
  moved pivots), Tier 4 kits drawn against the old template break. So freeze a
  body plan's part list and pivots once the plan is published as a template.

---

## 8. Effort

Rough estimates in **focused days**: a day is a long working session with Claude
writing the code and Harrison reviewing on screen. They include the manual test
checklist and on-screen tuning, but not marketing or store work.

| Piece | Days | Depends on |
|---|---|---|
| Engine: pluggable art source + raster cache + custom store (s.5 items 1, 3, 4) | 2-3 | none |
| Engine: species shape as data (s.5 item 2) | 3-5 | none |
| **Tier 1** Sticker: still rig, import screen with preview, bg removal, v2.0 migration and v2.0 `.critter` import | 6-9 | art source |
| **Tier 2** Coat Studio: role tags for 8 species, runtime recolour, ~8 patterns, editor with live preview, "match my pet" | 9-13 | art source |
| Runtime clothes fit (affine) + contact-sheet check | 3-5 | none |
| `.critter` v3 format, sanitiser, install flow, recipe codes, hostile-file tests | 5-8 | none |
| **Tier 4** Part kit: templates per plan, layered-SVG import, validator, fallback, metrics preview, artist guide | 10-15 | shape as data, clothes fit, format |
| **Tier 3** Guided cut-out: suggested cuts, lasso and pivot editor, hole fill, blink arcs | 15-25 | Tier 4's pieces |
| **Tier 5a** local segmentation assist | 8-12 on top of Tier 3 | Tier 3, new dependency |
| **Tier 5b/5c** generative | 20-40, plus running costs for 5c | 5a, policy |
| Steam Workshop (once a Steam SKU exists) | 10-15 | Steam release, GodotSteam |

The bundles in section 9 are built from these rows:
- v3.0 carry-over: Tier 1 without the new import UI polish. About 6-8 days.
- 3.1 Critter Studio: Tier 2, the clothes fit, the format, and Tier 4. About 30-45 days.
- 3.2 cut-out: Tier 3. About 15-25 days.

---

## 9. Recommendation: v3.0 or later

**Ship the sophisticated version as a free update after launch, and ship only
v2.0 parity in v3.0.**

- **v3.0, at launch: "your critters came with you."** Tier 1 rendering, v2.0
  customs migrated automatically, and v2.0 `.critter` files still installable as
  stills on the Homemade shelf. Include the basic still import only if it fits.
  This closes the upgrade gap without opening the format, Workshop or AI
  questions, and it keeps launch focused on the cast, rarity and the Collection.
  If even this doesn't fit, the fallback is to leave v2.0's custom folder alone
  and show a one-time notice: "your custom critters return in 3.1".
- **3.1 (free update, about 6-10 weeks after launch): "Critter Studio."**
  Coat Studio with recipe codes, the Homemade shelf, runtime clothes fit,
  `.critter` v3, and the Part kit for artists. This is the "sophisticated"
  release, and it gives the launch a second news beat, which a Steam or itch
  update post, a Reddit thread and a changelog all benefit from.
- **3.2: guided cut-out from a still** (Tier 3). It replaces Tier 1 for new
  imports, with Tier 5a's local segmentation as an option if 3.1's feedback
  says the lasso step is where people give up.
- **Not planned: generative AI (5b, 5c).** Revisit only if users ask for it
  in numbers and the disclosure and brand costs are acceptable then.
- **Workshop:** alongside a Steam SKU, once `.critter` v3 has been out for at
  least one release. Until then, use a pinned GitHub Discussion as the gallery if
  Harrison is willing to moderate it, or nothing hosted if he isn't.

The reasoning: Tier 2 delivers most of the delight (making your own cat)
with the least risk, and Tier 4 delivers the creators. Both need the Homemade
shelf and the economy guard rails, which are easier to design once the launch
economy is tuned on real players than to guess at before launch.

---

## 10. Decisions for Harrison

**1. What ships in v3.0?**
- (a) v2.0 carry-over only: stills render, v2.0 customs and `.critter` files
  migrate, Critter Studio in 3.1. *(recommended)*
- (b) Carry-over plus Coat Studio in v3.0 (about 10-13 more days before
  launch).
- (c) Nothing in v3.0: leave v2.0's files in place and show a "back in 3.1"
  notice.

**2. Where do customs sit in rarity and the economy?**
- (a) Homemade shelf: no tiers, no auras, no berries, can wear clothes.
  *(recommended)*
- (b) As (a), plus up to two author-made coats that turn up rarely as a
  homemade "shiny", still with no berries.
- (c) Customs roll the five tiers like a species (conflicts with the rarity
  model, and needs exploit guards).

**3. How far up the ladder does "sophisticated" go, and when?**
- (a) 3.1: Coat Studio + Part kit; 3.2: guided cut-out. *(recommended)*
- (b) 3.1: Coat Studio only; artists wait.
- (c) Go straight to guided cut-out (with or without AI) as the headline and
  skip the Part kit.

**4. AI in the pipeline?**
- (a) No generative AI; optional local segmentation to suggest cuts (5a),
  disclosed, in 3.2 at the earliest. *(recommended)*
- (b) No AI anywhere in custom critters, and say so in the store copy.
- (c) Cloud stylising (5c), with the cost, privacy policy, guardrails and
  Steam disclosure that come with it.

**5. Where do people share?**
- (a) `.critter` files and coat codes, a pinned GitHub Discussion as the
  gallery, Workshop only alongside a Steam SKU. *(recommended)*
- (b) Workshop from the Steam launch, if there is one.
- (c) Files only, with nothing hosted and no moderation commitment.
