# Critter Studio: build plan

Status: **planned, not started.** Written 2026-11-19 against `main` at v3.1.1.

This is the plan for making your own critters in full. Players can make a
critter in three ways:

- build it from shapes inside the app (the **Shape Builder**);
- draw it in their own software (the **Part kit**);
- animate it frame by frame in their own software (**frame critters**).

All four body plans ship, along with clothes on homemade heads and sharing. The
plan is meant to be executed from top to bottom over many sessions. Every
homemade critter, however it was made, lives in one **My critters** home
(P26), and each milestone goes live as a normal update (section 9).

The earlier options paper is `docs/v3-custom-critters-plan.md` on branch
`v3-custom-critters-plan`. Below it is called "the options paper". Its
sticker tier shipped in 3.1 as Homemade critters (`customs.gd`,
`critters/still.gd`, `gui/importer.gd`), and this plan builds on that.

---

## 0. How to use this plan

- **Each session** picks the first step in the progress table (section 11)
  that is not done. It reads that step in section 7, does it, runs the step's
  *Done when* check, then updates the table and adds a line to the log.
  - Each step is sized to finish in one or two sessions and to end green:
    tests pass and the step's audit rows pass.
  - Run windowed checks on the VM.
- **One step, one PR** into `main`, with the plan doc updated in the same PR.
  Unfinished work stays hidden from players behind the `studio` feature gate
  (7.A2) until the milestone release that ships it. That way `main` can still
  ship a patch release at any time.
- **It goes live as normal updates.** Each milestone (R1–R4 in section 7) is a
  public GitHub release that every install, the tester's included, gets
  through the in-app updater. Nothing is sent as a file. A smaller update in
  between is fine whenever something is ready for the tester to try. Some
  jank is acceptable: fix it in the next patch.
- **Design steps (A0, C0, D0) are sessions with the developer**, not solo
  work: designs are made with Claude Design and the design skills, and go
  back and forth until the developer approves one. No mock-ups go to the
  tester; they try the real thing after the next update.
- **Decisions** are in section 10. A step that depends on an open decision
  says so, and must not start until the decision is made.
- **When reality disagrees with the plan**, for example when a measurement in
  a spike says otherwise, change the plan in the same PR and say why in the
  log. Don't work round it silently.

---

## 1. Direction and scope

Agreed with the developer on 2026-11-19, after a tester asked for a simple
shapes-only editor with layers such as body, head, legs and tail, and for a
way to use their own drawing software.

**In this plan:**

| Way in | Who it is for | What they make |
|---|---|---|
| **Shape Builder** | Everyone. No other software needed. | A critter built from shapes on named layers, in the cast's style |
| **Part kit** | People who draw (Inkscape, Affinity, Illustrator, Krita, Procreate, Photoshop and so on) | The same layers, drawn in their own app |
| **Frame critters** | People who animate (Aseprite, Krita, any app that exports frames or GIFs) | Their own animation, in any shape |
| Sticker (3.1, unchanged) | A photo or a doodle | One picture moved as one piece |

The plan also covers:

- **all four body plans**: side-on, faces-you, upright and blob (section 4);
- **every gait the cast has**, plus the gaits blobs need;
- **clothes on homemade heads**;
- **homemade critters in pair interactions**;
- **sharing**: builder codes and `.critter` v3 files, plus `.critter` v2
  import;
- **custom sounds**;
- **dropping a file onto a critter** to import it.

**Decided:** Coat Studio is dropped. The Shape Builder covers what it would
have done (your own colours, no software needed), and the Shape Builder can
also change the shape.

**Not in this plan:**

- The guided cut-out and AI part-splitting (options paper Tiers 3 and 5).
  The Part kit and the Shape Builder cover the same need without a model or
  the disclosure questions. Revisit after the release if players ask.
- A hosted gallery or the Steam Workshop (decision 6).
- Native `.psd`, `.kra` or `.procreate` files. Each of those apps can export
  something this plan accepts (section 6, P9).

**The rules that do not change:**

- Homemade critters stay **outside rarity and the economy**: no tier, no
  aura, no berries, no presents. They arrive in place of a rolled Common,
  weighted by their visit setting, exactly as stickers do now.
- `settings.json` and the economy save are not changed.
- No new dependencies: no new Godot version, no godot-cpp change and no
  bundled third-party assets. The native layer, the installer and the updater
  are not touched.

---

## 2. What exists today

These facts are from reading the code, and the plan builds on each of them.

**The rig (`critters/critter.gd`)**
- Parts are SVGs in a shared 300 x 280 frame, facing left, with the ground at
  y 262 for most species. They are rasterised at `PART_SCALE` 0.75, and the
  textures are cached in the static `_textures`, keyed by `art_key()`. That
  cache never releases anything.
- Parts are optional. `_has(part)` gates `tail`, `walk-body`, `loaf-body`,
  `stand-body`, `eyes-closed`, `mouth-open`, `nose`, `scratch-foot` and
  `groom-paws`.
- **The hard requirements** are `head`, `eyes`, `head_at["sit"]`, and a
  `hit_bounds` entry for every pose that is used.
- **Leg visibility:** legs show only in the `walk` pose. The sit pose draws
  `sit_parts`, which are sitting bodies with the feet drawn in.
- **A gap kits must fill:** a critter with no `loaf-body` shows **no body at
  all** while napping, because `sit_body` is hidden in `loaf`.
- **Blink fallback:** when there is no `eyes-closed`, a blink squashes `eyes`
  instead (`critter.gd:1055`).
- **Gaits:**
  - The trot is pure data: `walk_legs` pairs, `leg_len`, `stride_deg` and
    `leg_lift`.
  - The hop (`rabbit.gd`), waddle (`duckling.gd`) and the faces-you
    variations (turtle plod, squirrel dart, otter slide, unicorn bounce,
    hedgehog scurry, panda sway) are overrides in each species script.
- **`two_head.gd`** carries a front face for sitting and a side face
  (`head-side`, `eye-side`) for walking. It moves clothes between them with
  `wear_walk_shift`, `wear_nap_shift`, `wear_side_scale`, `wear_crown` and
  `wear_neck`.

**Behaviours**
- Each one is in a table in `behaviours.gd`. Each species lists what it can do
  as `idles` in its `species.gd` row.
- The shared poses live in `critter.gd` `_behaviour_params`. Missing optional
  nodes are null-checked, so a behaviour whose part is missing does nothing
  rather than crashing. That is safe, but it looks broken, which is why kits
  only get behaviours they have parts for (4.6).

**Pairs (`pairs.gd`)**
- Partners are matched by species id.
- `custom:` critters are excluded (`pairs.gd:127`).
- `play_bow` calls `stretch` without checking `can_do`.

**Clothes**
- `design/wear/build.py` draws 84 items for each species from ten hand-entered
  head metrics: `cx`, `cy`, `rx`, `ry`, `eye_y`, `eye_dx`, `eye_r`, `chin`,
  `gap` and `side`. The output is `art/wear/<item>/<species>.svg` in a
  300 x 400 frame (`WEAR_HEADROOM` 120).
- Of the 84 items, 24 are species-only. Hoods and the mane hide ears.
- Nothing fits clothes at runtime.
- `aura.gd` `CROWN_LIFT` is per species, with 95 as the default.

**Homemade critters (3.1)**
- Each lives in `user://custom/<id>/`, with `custom.json` and `image.png`, plus
  `frames/` for v2.0 animations.
- `load_all()` **skips any folder without `image.png`**. Section 5.1 uses
  this to keep 3.1.1 safe.
- The species row comes from `customs._row()`. Ids are `custom:<id>`.
- The importer card is on Settings › System (`settings_pages.gd:1510`). The
  Critters page has a "Your own · Soon" tile (`_your_own_tile`, :500).

**GUI**
- Settings is its own borderless OS window, 1100 x 760.
  - Pages are registered in `NAV` (`settings_window.gd:21`) and dispatched by
    a `match` (`settings_pages.gd:43`).
  - Widgets are in `gui/controls.gd` (`K`).
- **What the GUI lacks:**
  - a colour picker;
  - a themed text field;
  - drag and drop of files (no `files_dropped` anywhere).
- `gui/critter_view.gd` renders a live critter in a SubViewport at 24 fps.

**Admin**
- Audit rows are `[group, id, title, how, action]` in `admin_page.gd`
  `checks()`.
- Actions are matched in `admin.gd` `run()` (`kind:arg`).
- Direct buttons are in `_events_card`.
- `--admin-run=ACTION` runs one action.

**host.gd**
- Clicks hit-test `critter.hit_rect()`, which is built from `hit_bounds`.
- The click-through hole uses `region_rect()`, the union of the visible
  Sprite2Ds.
- Three numbers are fixed in pixels: the body centre and trail (36 px) and
  confetti (90 px). Dizzy stars use `head_height`.

---

## 3. Architecture

```
                         ┌────────────── user://custom/<id>/ ──────────────┐
 Shape Builder ──writes──▶ shapes.json ─┐                                   │
   (gui/studio/)          │             ├─▶ parts/<part>.svg ─┐             │
 Part kit import ─────────▶ (sanitised) ┘   parts/<part>.png  ├─▶ cache/    │
   (gui/kit_import.gd)    │                                   │  <part>.png ├─▶ critters/kit/<plan>.gd
                          │ kit.json (plan, pins, gait, size, sound, metrics)│     side · front · upright · blob
 Frame import ────────────▶ clips.json + frames/ ──▶ cache/atlas.png ───────┼─▶ critters/kit/frames.gd
                          │                                                  │
 Sticker (3.1) ───────────▶ image.png ───────────────────────────────────────┼─▶ critters/still.gd
                          └──────────────────────────────────────────────────┘
```

**Rigs.** There is one script per body plan. Each extends the cast base that
already has the right structure, so all the shared motion and behaviours are
inherited:

| Plan | Script | Extends | Modelled on |
|---|---|---|---|
| Side-on | `critters/kit/side.gd` | `critter.gd` | kitten, rabbit |
| Faces you | `critters/kit/front.gd` | `two_head.gd` | otter, squirrel, turtle, panda |
| Upright | `critters/kit/upright.gd` | `critter.gd` | duckling |
| Blob (new) | `critters/kit/blob.gd` | `critter.gd` | none: no legs |
| Frames | `critters/kit/frames.gd` | `critter.gd` | v2.0 frame stills, Shimeji |

**Shared helpers.** GDScript has no mixins, so the plan scripts call static
helpers:
- **`critters/kit/kit_data.gd`** reads `kit.json` and sets the rig's
  variables (`pivots`, `head_at`, `tail_at`, `walk_legs`, `leg_len`,
  `hit_bounds`, `critter_scale`, `speed_range`, `head_height`, and
  `wear_*` for the front plan). It also loads textures from the cache,
  applies the fallbacks (4.5) and builds the behaviour list (4.6).
- **`critters/kit/gaits.gd`** holds the gait maths as static functions (4.4).

**The species scripts are not changed.** The hop, waddle and other gaits are
re-implemented in `gaits.gd` rather than moved out of `rabbit.gd` and
`duckling.gd`, so this plan cannot break the cast. Moving the species onto
`gaits.gd` later is a separate cleanup, and not part of this plan.

**`customs.gd`** stays the one store. It gains `kind` (`sticker`, `kit` or
`frames`), the kit and clip loaders, the raster cache and the behaviour table.
`Species.row()` answers for every kind, as it already does for stickers.

**Two kinds of art, one cache.** A spawn never parses an SVG the player
supplied. Parts are rasterised once, at save, to `cache/`. The cache is
rebuilt when the app version changes (the version is stored in `kit.json`)
and when the critter is edited. Texture cache keys carry a revision
(`custom:<id>@<rev>`), so an edit never shows a stale texture.

**Releasing textures.** The static texture cache gains reference counts for
`custom:` keys only. When no critter of that kind is on screen or in a
preview for 60 s, its textures are freed. Built-in species keep today's
behaviour.

---

## 4. Body plans

The part names match the cast's own names, so the templates, fixtures and code
all speak the same language. Coordinates are SVG units in the 300 x 280
frame, facing left.

### 4.1 Side-on (`side`): like the kitten

Profile in every pose.

| Part | Need | Attaches to | Fallback if missing |
|---|---|---|---|
| `walk-body` | **required** | body | none |
| `head` | **required** | neck pin | none |
| `eyes` | **required** | head | none |
| `leg-front`, `leg-back` | **required** | hip pins | none |
| `leg-front-far`, `leg-back-far` | optional | hip pins, behind | Near leg tinted 18% darker, shifted 8 units back |
| `body` (sitting) | optional | body | `walk-body` with the legs at rest (the rig keeps legs visible in sit) |
| `loaf-body` (napping) | optional | body | `walk-body` lowered to the ground, squashed to 85% and legs hidden; tail rests curled |
| `eyes-closed` | optional | head | Builder: arcs drawn over each eye. Part kit: the existing squash blink |
| `ear-l`, `ear-r` | optional | ear pins on the head, behind it | `ear-r` = `ear-l` tinted darker, shifted 10 units back |
| `tail` | optional | tail pin | No tail behaviours |
| `mouth-open` | optional | head | No yawn or sneeze |
| `nose` | optional | head | No nose twitch |
| `head-front` | optional, new | head, in front | Horns, fringes and the like, drawn over the head |
| `wing` | optional, new | wing pin, near side | Flaps in fly, hops, shake off and celebrate |
| `back-extra` | optional, new | body, behind | Mane, quills, shell, backpack |
| `front-extra` | optional, new | body, in front | Bib, belly patch over the legs |
| `stand-body` | optional | body | No stand lookout |

**Pins:** `neck-walk`, `neck-sit`, `hip-front`, `hip-back`, `tail`, `ear-l`,
`ear-r`, `eyes` and `wing`.

**Gaits:** trot (default), hop.

### 4.2 Faces you (`front`): like the otter, squirrel and turtle

The critter sits facing you and walks side-on. It extends `two_head.gd`, so
the clothes handling between the two faces is inherited.

| Part | Need | Fallback |
|---|---|---|
| `body` (sitting, front) | **required** | none |
| `head` (front face) | **required** | none |
| `eyes` | **required** | none |
| `walk-body` | **required** | none |
| `leg-front`, `leg-back` | **required** | none |
| `head-side`, `eye-side` | optional | The front face stays on while walking, as the panda's does |
| `eye-side-closed`, `eyes-closed` | optional | Arcs or a squash, as in 4.1 |
| `loaf-body` | optional | `body` lowered and squashed, eyes closed |
| `loaf-eyes`, `loaf-eyes-closed` | optional | Eyes stay on the head |
| `ear-l`, `ear-r` | optional | Builder: `ear-r` mirrors `ear-l` about the head's centre |
| `foot-l`, `foot-r` | optional | Feet drawn in `body` |
| `paws` | optional | As above |
| `tail`, `mouth-open`, `nose`, `head-front`, `wing`, `back-extra`, `front-extra` | optional | As in 4.1 |
| far legs | optional | As in 4.1 |

**Pins:** `neck-sit`, `neck-walk` (two_head `side_pivot`), `hip-front`,
`hip-back`, `tail`, `ear-l`, `ear-r`, `eyes` and `eye-side`.

**Gaits:** trot (default), plod, scurry, dart (dart and freeze), slide (the
otter's), bounce (the unicorn's) and sway (the panda's).

### 4.3 Upright (`upright`): like the duckling

It stands on two legs facing you and waddles side-on.

| Part | Need | Fallback |
|---|---|---|
| `body` (front) | **required** | none |
| `head` | **required** | none |
| `eyes` | **required** | none |
| `leg-near` | **required** | none |
| `leg-far` | optional | Near leg tinted darker |
| `walk-body` | optional | `body` |
| `wing-l`, `wing-r` | optional | Builder: `wing-r` mirrors `wing-l` |
| `wing-side` | optional | `wing-l` |
| `loaf-body` | optional | `body` settled down as a ball (the duckling's nap) |
| `tuft` | optional | Sprung like the duckling's. Clothes hide it as they hide the duckling's |
| `tail`, `eyes-closed`, `mouth-open` (beak open), `head-front`, `back-extra`, `front-extra` | optional | As in 4.1 |

**Pins:** `neck`, `hip`, `feet` (the waddle rocks about this), `wing-l`,
`wing-r`, `tail`, `tuft` and `eyes`.

**Gaits:** waddle (default), hop.

### 4.4 Blob (`blob`): new, no legs

Slimes, ghosts, snakes, fish, jellies, rocks with eyes.

| Part | Need | Fallback |
|---|---|---|
| `body` | **required** | none |
| `eyes` | **required** | none |
| `head` | optional | none. A blob with no head carries its eyes on the body |
| `eyes-closed`, `mouth-open`, `ear-l`, `ear-r` (antennae, fins), `tail`, `head-front`, `back-extra` | optional | As in 4.1 |
| `loaf-body` | optional | `body` melted: 120% wide, 70% tall |

**Pins:** `eyes`, `top` (where antennae and hats sit), `tail` and `ear-l`,
`ear-r`.

**Gaits:**
- **bounce** (default): squash, spring and land, time-based like the rabbit's
  hop.
- **slide**: glides with a wobble.
- **float**: hovers 10–20 units up with a slow bob; landing a throw is soft.
- **slither**: a side-to-side wave, using `still.gd`'s mesh bend on the body.

**What a blob cannot do:** climbing is a slide up the wall with no reach and
pull, and any behaviour that needs legs is left out (4.6).

### 4.5 Gaits (`critters/kit/gaits.gd`)

Static functions that take the critter and return the params a gait sets:
`lift`, `torso_rot`, `torso_dy`, the leg angles and `_gait_speed`. Each kit
plan script calls the gait chosen in `kit.json` from its `_advance_gait`,
`_gait_speed`, `_settled` and `_base_params` overrides.

| Gait | Taken from | Distance or time | Settled when |
|---|---|---|---|
| trot | `critter.gd` default (data only) | distance | always |
| hop | `rabbit.gd` (HOP_CYCLE, ARC, HOP_HEIGHT, `_apply_legs` keys) | time | on the ground |
| waddle | `duckling.gd` (rock about FEET, tail counter-wag) | distance | always |
| plod | `turtle.gd` `_gait_speed` and sway | distance | always |
| scurry | `hedgehog.gd` `_gait_speed` | distance | always |
| dart | `squirrel.gd` `tick` dart and freeze | distance | always (squirrel has no `_settled`) |
| slide | `otter.gd` (frozen gait, legs tucked) | distance | always |
| bounce (legged) | `unicorn.gd` torso_dy | distance | always |
| sway | `panda.gd` | distance | always |
| bounce (blob), float, slither | new | time / time / distance | on the ground / always / always |

The constants are copied, with a comment naming the source line. Each gait has
a headless test that samples it through two cycles. The test checks that its
speed averages 1 and its lift is never negative, and, for the copied gaits,
that it matches the source species' values at the same phases. The test drives
both rigs, so the species is the reference.

### 4.6 Behaviours for homemade critters

There is one table in `customs.gd`: behaviour → the parts and plans it needs.
A kit's `idles` are the behaviours whose needs it meets. A test checks that no
kit gets a behaviour touching a part it lacks.

| Behaviour | Needs |
|---|---|
| sit_and_look, look_at_cursor, wake_up, listen, hello, dizzy | `head`, `eyes` (blob: `eyes`) |
| nap | always (fallback loaf, 4.1–4.4) |
| shake_off | always |
| stretch | a legged plan |
| yawn, sneeze | `mouth-open` |
| ear_flick | `ear-l` or `ear-r` (blob antennae count), or `tuft` |
| tail_swish, chase_tail | `tail` (chase_tail: side-on plan only) |
| nose_twitch | `nose` |
| stand_lookout | `stand-body` |
| groom | `groom-paws` (Part kit) or, for the upright plan, wings |
| scratch | `scratch-foot` |
| preen, peck_ground | upright plan with `mouth-open` (as the beak) |
| hunt | side-on plan, trot gait |
| dance, fly, celebrate (perks) | any plan. Fly uses `wing` if there is one |
| ball_up, head_tuck, chitter, belly_roll, panda_roll, prance, snuffle | **not offered**: each needs a drawing that only its species has |

Frame critters use their own clips instead (section 7.E1).

**Clip behaviours.** A frame critter's named clips (`act-dance`,
`act-wave` and so on) become behaviours with the id `clip:<name>`.
`behaviours.gd` gains a lookup that answers for ids it does not list. The
duration is the clip length times its loops, the cooldown is 30 s and the
weight is 1. The evaluator schedules them like any other behaviour.

### 4.7 Pins, grounding, size and hit bounds (all plans)

**Pins** are the joints: where a part attaches and turns. Each comes from one
of three places:
- **Shape Builder:** suggested from the geometry. The neck is the centre of
  the overlap between head and body. A hip is the top centre of its leg. The
  tail root is the tail point nearest the body. An ear root is the bottom
  centre of the ear. The player can drag any pin.
- **Part kit:** from the template's `pins` layer if the artist moved them,
  otherwise the template's defaults. They can be dragged in the importer.

**Validation** clamps each pin to a box around its default: within 60 units,
and hips must stay below the neck. It warns on anything the clamp moved.

**Grounding.** On save, each pose is moved down or up so that its lowest
opaque point sits on `ground_y` (262). For a legged walk pose that point is
the bottom of the legs at rest. `leg_len` is the hip-to-sole distance.
`stride_deg` and `leg_lift` take the plan's defaults, scaled by leg length.

**Size.** The cast is about 95 px tall at `critter_scale` 0.45 for a drawing
about 210 units tall. `critter_scale` = 0.45 × (210 / drawn height),
clamped to 0.3–0.7, then times the player's size choice (Small 0.8, Medium
1.0, Large 1.25, as stickers have). `speed_range` is the plan's default times
the speed choice.

**Hit bounds** per pose are the union of the parts' alpha bounding boxes in
the cache, plus 4 units. `head_height` is ground_y minus the eyes pin.

**Heads for clothes** are described in section 7, F1.

---

## 5. Data formats

### 5.1 The store

```
user://custom/<id>/
  custom.json      as 3.1 (name, size, speed, visits, enabled, sightings, from)
                   plus "kind": "sticker" | "kit" | "frames", "schema": 2, "rev": N
  image.png        stickers only (unchanged)
  frames/          stickers from v2.0 only (unchanged)
  kit.json         kits: see 5.2
  shapes.json      Shape Builder kits only: see 5.3
  parts/<part>.svg | parts/<part>.png    Part kit sources, sanitised; builder SVGs
  clips.json       frame critters: see 5.4
  clips/<clip>/<n>.png                   frame critters' frames, re-encoded
  cache/<part>.png | cache/atlas.png     rasterised once; rebuilt on edit or app version change
  thumb.png        128 px card picture for the Collection and the Homemade list
  sound.wav|.ogg   optional custom sound (7.B6)
  source.json      optional: the path of the file it was imported from, for Reload (7.C4)
```

- **Back compatibility.** A `custom.json` with no `kind` is a sticker, so 3.1
  stores load unchanged.
- **Forward safety.** Kits and frame critters **never write `image.png`**, so
  an older 3.1.x build skips them with a log line (`load_all` requires
  `image.png`). It does not show a broken critter. This is tested by running
  3.1.1's `load_all` code against a fixture store (7.A3).
- **Unknown keys** in any of these files are kept when re-saving, as
  `settings.gd` does.

### 5.2 `kit.json`

```json
{
  "schema": 1, "plan": "side", "gait": "trot", "app": "3.2.0",
  "faces": "left",
  "parts": ["walk-body", "head", "eyes", "leg-front", "leg-back", "tail", "ear-l"],
  "auto": {"leg-front-far": true, "leg-back-far": true, "body": true, "loaf-body": true,
           "eyes-closed": "arcs", "ear-r": "tint"},
  "pins": {"neck-walk": [112, 198], "hip-front": [118, 224], "hip-back": [196, 224],
           "tail": [226, 192], "eyes": [96, 150], "ear-l": [90, 140]},
  "derived": {"leg_len": 38, "ground_y": 262, "scale": 0.47,
              "hit": {"walk": [18, 36, 272, 226], "sit": [...], "loaf": [...]}},
  "head": {"cx": 104, "cy": 150, "rx": 60, "ry": 50, "eye_y": 152, "eye_dx": 24,
           "eye_r": 10, "chin": 196, "top": 100},
  "sound": "kitten",
  "made_with": "builder" | "svg" | "png" | "ora"
}
```

- `derived` is recomputed on every save. It is never trusted from an
  imported file.
- `head` holds the clothes metrics (7.F1).

### 5.3 `shapes.json` (Shape Builder)

```json
{
  "schema": 1, "plan": "side", "style": {"outline": "#5B3A29", "width": 6, "blush": true},
  "layers": {
    "head": [
      {"t": "ellipse", "x": 104, "y": 150, "w": 120, "h": 100, "rot": 0, "fill": "#F6C28F"},
      {"t": "ellipse", "x": 104, "y": 170, "w": 50, "h": 30, "fill": "#FFE9D6", "inside": true, "line": false}
    ],
    "eyes": [{"t": "eye", "preset": "big", "x": 92, "y": 150, "w": 22, "h": 26, "fill": "#3A2A22"}]
  },
  "auto": {"loaf-body": true},
  "pins": {"neck-walk": [112, 198]}
}
```

**Shape types:**

| Type | What it is | Fields |
|---|---|---|
| `ellipse` | Ellipse | x, y, w, h, rot |
| `rect` | Rounded rectangle | adds `r`, the corner radius |
| `tri` | Triangle | adds `r` (rounded corners) and `apex` (0–1, where the top point sits) |
| `drop` | Teardrop | x, y, w, h, rot |
| `heart` | Heart | x, y, w, h, rot |
| `star` | Star | adds `n`, the point count, 4–8 |
| `blob` | A closed smooth shape through 3–12 points (Catmull-Rom) | `pts` |
| `stroke` | An open curve through 2–8 points, with round caps | `pts`, `width` |
| `eye` | A preset eye: pupil, highlight and optional lash | `preset` |

**Flags on every shape:**
- `fill`: a `#RRGGBB` colour.
- `line`: outline on or off (default on).
- `inside`: clipped to the layer's other shapes. Use it for markings,
  bellies and spots.
- `flip`.

**Limits:**

| What | Limit |
|---|---|
| Shapes per layer | 60 |
| Shapes in all | 400 |
| Points per shape | 12 |
| Coordinates | −60 to 360 |
| Sizes | 2 to 400 |
| Name | up to 24 characters: letters, digits, spaces, `-'` and emoji |

### 5.4 `clips.json` (frame critters)

```json
{
  "schema": 1, "faces": "left", "ground": 262, "stride_px": 114,
  "clips": {
    "walk": {"frames": 8, "fps": 10, "loop": true},
    "sit":  {"frames": 4, "fps": 4, "loop": true},
    "act-wave": {"frames": 12, "fps": 12, "loop": false, "loops": 1}
  },
  "head": {"walk": [[96, 120, 1.0]], "sit": [[150, 110, 1.0]]}
}
```

- `head` is optional, with one entry per clip. An entry is `[x, y, scale]`:
  either one for the whole clip or one per frame. Clothes use it (7.F3).
- Clips are `walk` (required), `sit`, `nap`, `blink`, `held`, `thrown`,
  `land`, `climb` and `act-<name>` (up to 8). The fallbacks are in 7.E1.
- **Limits:**
  - 64 frames in all;
  - each frame within 300 x 280 units (stored at up to 2× for detail);
  - one atlas of at most 2048 x 2048.

### 5.5 Sharing

**Builder code**
- The format is `CRIT1-` + base64url(deflate(minified `shapes.json` +
  name)).
- A typical critter is 600–1,200 characters, which is fine for a chat
  message.
- On paste it is decoded, decompressed with a size cap, then validated
  against 5.3 and the limits. The app then writes its own SVGs from the
  numbers, so nothing in a code is ever parsed as SVG.

**`.critter` v3**
- A zip:
  - `manifest.json`: schema 3, kind, plan, `app_min`, a content hash;
  - `meta.json`: name, author (optional), licence (optional), `made_with`,
    and `ai_made` (set by the author, as in the options paper);
  - the kind's own files: `shapes.json`, or `kit.json` + `parts/`, or
    `clips.json` + `clips/`;
  - optional `sound`;
  - `thumb.png`.
- On install, everything goes through the same import path as a fresh import
  (sanitiser, re-encode, validation), never copied as it is.
- **Not included:** `cache/`, `source.json` and visit counts.

**`.critter` v2** (from v2.0) installs as a sticker, as 3.1's v2.0 folder
carry-over already does.

---

## 6. Problems and their solutions

These are the problems worked through before writing the steps. Each step
points back to the ones it handles.

**P1. A homemade head on a stock body.**
The options paper's fallback to the base species' art would mix styles.
- **Solution:** never fall back to cast art. Each plan has a small required
  core (4.1–4.4).
- Everything else either gets an automatic stand-in built from the critter's
  own art (tinted far legs, mirrored ears, a melted loaf) or drops the
  behaviours that need it.

**P2. Too many drawings.**
The kitten has 23 parts across three poses, and asking a player for that
kills the feature.
- **Solution:** one pose is required: walking for side-on and blob, plus
  sitting for faces-you and upright, where facing you is the point. Every
  other pose is automatic until the player draws it.
- **In the builder:** a pose starts as "Same as walking (automatic)". *Draw
  this pose* copies the walking shapes as a starting point, so a sitting pose
  is a few edits rather than a redraw.

**P3. Napping with no nap drawing shows no body.**
`critter.gd` hides `sit_body` in `loaf`, so a critter with no `loaf-body`
naps as a floating head.
- **Solution:** each kit plan overrides `_set_pose()` to show the fallback
  loaf: the walking body lowered and squashed, legs hidden. The fixture with
  only the required parts checks it on screen.

**P4. Ground, size and joints come out wrong for any drawing that isn't the
template's proportions** (a dachshund, a giraffe).
- **Solution:** grounding, size, `leg_len` and `hit_bounds` are computed on
  every save (4.7), never typed in. Pins are suggested, draggable and
  clamped.
- The importer shows the rig's joints over the art, with the critter walking
  beside it, so a bad pin is visible straight away.

**P5. Many shapes, many outlines.**
If every shape is drawn with its own outline, overlapping shapes show outlines
inside the silhouette. The cast has one outline round each part.
- **Solution:** draw each layer in two passes. First every outlined shape's
  stroke at twice the outline width, then every fill on top, in order. Only
  the outer edge of the merged silhouette shows.
- `inside` shapes (markings) are clipped to the union of the layer's other
  shapes with an SVG `clipPath`, and get no outline.
- Spike A1 confirms Godot's SVG rasteriser (ThorVG) draws this correctly.

**P6. The editor must feel responsive.**
Re-rasterising SVG on every mouse move might be too slow on integrated
graphics.
- **Solution:** the shape model produces polygons as well as SVG, since it
  needs them anyway for hit-testing. While the player drags, the canvas draws
  the polygons directly with Godot's drawing calls. When they let go, the
  layer is re-rasterised from SVG, so what they see settles on exactly what
  the critter will wear.
- Spike A1 measures both. If the SVG raster is under 8 ms for a 40-shape
  layer on Iris Xe, the polygon path is dropped and SVG is used throughout.

**P7. Matching layer names from many drawing apps.**
- **Inkscape:** `inkscape:label` on `<g inkscape:groupmode="layer">`.
- **Affinity:** layer name as `id`, with its own escaping.
- **Illustrator:** layer name as `id`, with `_x5F_` style escapes and `_1_`
  suffixes for duplicates.
- **Solution:** normalise every candidate name, then look it up in the plan's
  part list and an alias table (`body-walk` → `walk-body`, `eye` → `eyes`).
  - Normalising means: unescape `_xNN_`, lowercase, drop trailing `_N_`,
    replace spaces and underscores with `-`.
  - The importer lists what matched and what didn't, and lets the player pick
    a part for any layer that didn't match.
- Fixtures exported from each app go in the tests.

**P8. SVG features the rasteriser does not draw.**
Blur and drop-shadow filters, text, and some embedded images.
- **Solution:** the sanitiser drops them. The checklist names what was dropped
  in plain words: "Blur effects aren't supported, so they were left out",
  "Convert text to paths before exporting". Spike A1 lists exactly what
  ThorVG supports in this Godot version.

**P9. Raster apps export layers in different ways.**
- **Krita:**
  - its Export Layers plugin writes full-canvas PNGs;
  - it can also save `.ora` (OpenRaster), as GIMP and MyPaint can.
- **Procreate:** shares layers as full-canvas PNGs.
- **Photoshop:** Export Layers to Files trims each layer unless told not to.
- **Solution:** accept three forms:
  - a folder or zip of PNGs named after the parts, at the template's size or
    an exact multiple of it (2×, 3×, 4×);
  - `.ora`: a zip with `stack.xml` giving each layer's name and offset, read
    with `ZIPReader`;
  - trimmed PNGs plus their offsets in a `parts.txt`. This is mentioned only
    in the guide's Photoshop section.
- A PNG whose size is not a multiple of the template is refused, with the
  template's size in the message.

**P10. Hostile files.**
Files can be shared, so the import is an attack surface: zip bombs, path
traversal, SVG entity expansion, external references, giant images that
exhaust memory on decode, and absurd path counts.
- **ZIPs:**
  - at most 300 entries;
  - 40 MB uncompressed in all, 8 MB per entry;
  - names limited to `[A-Za-z0-9._/-]`, with no `..`, no leading `/` and no
    drive letters.
- **SVG:** parsed with `XMLParser` and written back out from a whitelist:
  - elements: `svg g path circle ellipse rect polygon polyline line defs
    clipPath mask linearGradient radialGradient stop`;
  - presentation attributes only;
  - no `<script>`, `<foreignObject>`, `<image>`, `<use>` that points outside
    the file, `<!ENTITY` or `<!DOCTYPE`;
  - at most 4,000 elements and a 2 MB file.
- **Images:** the PNG `IHDR` and GIF screen size are read from the header
  bytes **before** decoding. Anything over 4096 px a side is refused.
- **JSON:** a size cap of 256 KB and the schema validated.
- **Testing:** a fuzz pass in step G3 throws mutated fixtures at every
  importer.

**P11. Frame critters drift, skate and pop.**
Frames from different apps sit at different heights, walk cycles don't match
the walking speed, and loops don't close.
- **Solution:**
  - The importer finds the lowest opaque pixel across each clip and grounds
    the clip there, with a nudge control.
  - A `stride_px` slider is previewed live so the feet don't skate. This is
    what `still.gd`'s `ANIM_CYCLE_PX` does for v2.0 frames.
  - A checklist warns:
    - when the bottoms of walk frames vary by more than 6 px;
    - when the first and last frames differ a lot (the loop doesn't close);
    - when pixels touch the frame edge (clipped art).

**P12. Memory with many frames.**
At part scale a frame is about 190 KB, and 64 frames would be 12 MB per
critter.
- **Solution:** pack each critter's frames into one atlas with mipmaps,
  loaded when the critter first spawns and released 60 s after the last one
  leaves (section 3).
- The budget check (H3) is 150 MB of VRAM with every kind on screen.

**P13. GIF and APNG.**
Godot has no GIF decoder, and its PNG loader reads only the first frame of an
APNG.
- **Solution:** a small GIF decoder in GDScript (`gif.gd`, about 200 lines:
  LZW, disposal modes, transparency), decoding at most 64 frames.
- APNG is split by chunk into plain PNGs (`apng.gd`, about 120 lines). Both
  are tested against fixtures made by common tools.
- No new dependency.

**P14. Clothes on any head.**
Today clothes exist only as files drawn at build time for ten known heads.
- **Solution (decision 3):** port the item generators (`design/wear/*.py`,
  about 730 lines) to GDScript as `wear_draw.gd`. Clothes for a homemade head
  are then drawn from its own metrics, exactly as the build draws them for
  the cast.
- **Drift:** a parity test renders every item for every built-in species with
  both the Python output and `wear_draw.gd`, and fails on any difference.
- **Kept out:** species-only items (24) are excluded from homemade critters,
  and hoods hide `ear-l`/`ear-r`/`tuft`.
- **The alternative, an affine fit from a reference species,** is cheaper. It
  fails on very wide or very tall heads, where hats come out too small or
  float.

**P15. Two faces, one set of clothes.**
Faces-you critters carry clothes on the front face and move them for the
side face.
- **Solution:** `front.gd` inherits `two_head.gd`'s handling.
- `wear_crown`, `wear_neck`, `wear_walk_shift` and `wear_nap_shift` are
  computed from the two heads' metrics: the shift is the difference between
  the side and front crowns. `wear_side_scale` is the ratio of their widths,
  clamped to 0.7–1.0.
- With no side head, the shift is just the neck move between poses.

**P16. Homemade critters in pairs.**
Today they are excluded.
- **Solution:** a homemade critter may join a pair whose behaviours it can
  do. `pairs.gd` gains a check for each pair's needs:
  - sniff needs `nose_twitch` or `listen`;
  - stare_contest needs `look_at_cursor`;
  - play_bow needs `stretch`;
  - sit_together needs nap;
  - bump needs nothing.
- Species-specific pairs (kitten_tussle, hedgehog_defence and the others)
  stay species-only.
- **The existing bug fixed on the way:** `play_bow` calling `stretch` without
  `can_do`. A cast critter that can't stretch would show nothing. That fix is
  its own commit in B6.

**P17. Numbers in `host.gd` assume cast sizes.**
- **Solution:** the 36 px body centre, the 90 px confetti height and aura's
  `CROWN_LIFT` come from the critter: half its walk hit-box height, its hit
  top, and its head top above ground.
- For built-in species the existing constants are used unchanged, through an
  override that only kit plans implement.

**P18. The builder's window.**
The Settings window is 1100 x 760 with a 232 px sidebar. That is too tight
for a canvas, a layers panel, tools, a colour panel and a live preview.
- **Solution (decision 2):** a separate **Critter Studio** window with the
  same chrome as Settings, resizable, with a minimum of 1200 x 800 scaled by
  `UI.fit`. It is opened from the My critters page.
- It keeps the session open while the player watches their critter on the
  desktop.

**P19. Missing widgets.**
There is no colour picker, no themed text field and no file drop.
- **Solution:**
  - `gui/colour_picker.gd`:
    - swatches taken from the cast's own palette;
    - 12 recent colours;
    - a saturation and value square, a hue strip and a hex field.
  - `K.text_field()` in `controls.gd`.
  - File drop is handled through `Window.files_dropped` on critter windows and
    the Settings and Studio windows. A dropped file goes to the importer for
    its type.

**P20. Long work and a releasable `main`.**
- **Solution (decision 1):** every step merges into `main`. Anything not yet
  ready for players sits behind a `studio` gate with one switch per way in:
  `main.studio_on(&"kit")`, `&"shapes"`, `&"frames"` and `&"share"`.
- In the admin build, and with the `--studio` flag, every switch is on. In
  the player build a switch turns on in the milestone release that ships it
  (R1–R4), and its gate check is then deleted.
- Patch releases from `main` keep working at any time.

**P21. Upgrades and downgrades.**
- **3.1 to 3.2 and on:** stickers keep working (no `kind` means sticker).
- **Reinstalling an older version:** kits are skipped and not shown broken,
  because there is no `image.png` (5.1). They come back after updating again.
- **Every milestone is checked through the updater itself** (R1–R4): the
  previous public release is installed on the VM, offers the update, installs
  it, and the homemade critters are all still there.

**P26. A messy, confusing UI.**
There are five ways to get a critter (shapes, your own drawing app, an
animation, a picture, a friend's code or file), and each could grow its own
screens. Players need to see at once what each way is for, and that they all
end in the same thing: a critter.
- **Solution:** one home, **My critters**, built in A2 from the A0 design:
  - **Every homemade critter in one place**, whatever made it, each with a
    small badge for how it was made. Whether the ways also get their own
    lists or filters is the first question for the A0 design session; the
    starting point is one list with filter chips (All, Built, Drawn,
    Animated, Picture).
  - **One "Make a critter" entry** that explains the ways in plain words and
    by what the player has ("No drawing app? Build from shapes", "Draw in
    your own app", "Bring an animation", "Use a picture", "Got a code or a
    file?").
  - **Every critter opens the same detail view**: on or off, name, size,
    sound, Edit (opens whatever made it), Share, Delete.
  - The same words everywhere: the page, the Collection badges, the
    importers, the Studio and `making-critters.md`.
- **Design sessions** (A0 for the hub, C0 for importing, D0 for the Studio
  window) are made with Claude Design and the design skills, with the
  developer, before the code. Each approved design is saved under
  `design/studio/` with a note of what was decided.
- **Usability checks** at D7 and after each milestone release, from the
  tester's use of the real update.

**P22. Templates going stale.**
Once a template is published, artists draw against it.
- **Solution:** each template has a version (`walker-1`). The part list and
  pin defaults of a published version never change.
- A change means a new template version. The importer reads every version
  it knows.

**P23. Test data in the player build.**
Fixtures (the kitten-as-kit, hostile files, app exports) must not ship.
- **Solution:** fixtures live in `godot/test_data/`, which the player and
  admin presets exclude.
- `run-tests.ps1` and CI gain a check that the exported pack has no
  `test_data/` paths. CI already checks this for the Admin scripts (K6), so
  the new check sits next to that one.

**P24. Players drawing other people's characters.**
On their own desktop this is their business.
- **Solution:** for sharing, the install dialog says "Only install critters
  from people you trust", as v2.0 did. `meta.json` carries an optional
  author and licence.
- There is no hosted gallery, so there is nothing to moderate (decision 6).

**P25. A mismatch between the editor preview and the desktop critter.**
- **Solution:** the Studio's live preview is a real kit critter, rendered with
  `critter_view.gd` from a temporary in-memory kit (`custom:_preview`, as the
  sticker importer does). What the player sees walking is exactly what will
  walk.

---

## 7. Steps

Each step lists:
- the files;
- what to build;
- the Admin buttons and audit rows (CLAUDE.md requires them for anything the
  player can see or trigger);
- the tests;
- **Done when**, the check that closes it.

Phase order: **A** groundwork → **B** kit rigs → **C** Part kit → **D** Shape
Builder → **E** frame critters → **F** clothes → **G** sharing → **H**
release. Milestone releases go live through the updater after C (R1, 3.2.0),
D (R2, 3.3.0) and E (R3, 3.4.0); H4 is the last (R4, 3.5.0).

### Phase A: groundwork

**A0. Design session: My critters and Make a critter.** (P26) *With the
developer.*
- **What:** design the player's way in, with Claude Design and the design
  skills, going back and forth until it is approved:
  - the My critters page: one list of every homemade critter, and whether
    the ways in also get their own lists, tabs or filters;
  - the Make a critter chooser: how the five ways are explained and picked;
  - the shared detail view for one critter;
  - where it lives (a Settings page after Critters, its own window, or
    both), and how the Critters page's "Your own" tile and the Collection
    lead to it;
  - empty states (no critters yet) and the words used for each way.
- The design is for the Godot app, so it is drawn in the app's own look
  (`design/` GUI mock-ups, `gui/theme.gd`), not as a web page.
- **Done when:** the developer approves the design. It is saved in
  `design/studio/my-critters/`, and the decisions are in the log. A2 and
  the later steps that add screens follow it.

**A1. Rasteriser spike.** (P5, P6, P8)
- **Files:** `tools/studio_spike.gd`, a headless script that is not shipped.
- **What:**
  1. Time `Image.load_svg_from_string` at `PART_SCALE` for layers of 10, 40
     and 60 shapes, with and without `clipPath`.
  2. Render the two-pass outline (P5) and check the inner outlines are
     hidden.
  3. Probe ThorVG support for: `clipPath`, `mask`, linear and radial
     gradients, `stroke-linejoin` round, `stroke-linecap` round, `opacity`,
     `fill-rule` evenodd, `<filter>`, `<text>`, and `<image>` with a data
     URI.
- Run it on this PC (headless) and on the VM, which has no GPU, as the
  worst case.
- **Done when:** the results table is pasted into this doc under A1, and P6's
  choice (polygons while dragging, or SVG throughout) is recorded.
- **Results (2026-11-24, Godot 4.7, `tools/studio_spike.gd`).** Median of
  15 rasterisations of one two-pass layer, in ms. "PC" is this PC (Iris Xe;
  ThorVG rasterises on the CPU, so the GPU does not matter). "VM" is the test
  VM (i5-10210U, virtualised), the worst case.

  | Shapes | clipPath | PC x0.75 | PC x1.2 | VM x0.75 | VM x1.2 |
  |---|---|---|---|---|---|
  | 10 | no | 0.33 | 0.44 | 1.06 | 1.87 |
  | 10 | yes | 0.44 | 0.66 | 1.20 | 1.79 |
  | 40 | no | 1.10 | 1.78 | 3.42 | 4.37 |
  | 40 | yes | 1.61 | 2.12 | 4.15 | 5.63 |
  | 60 | no | 1.66 | 2.13 | 4.57 | 5.50 |
  | 60 | yes | 2.21 | 3.36 | 8.44 | 8.30 |

  - **P6 decided: SVG throughout.** A 40-shape layer is under 2 ms on this PC
    and under 6 ms on the VM. The canvas re-rasterises only the layer being
    edited, at most once a frame. The shape model still makes polygons, for
    hit-testing only.
  - **P5 confirmed:** with one stroke per shape, an outline shows inside the
    silhouette; with the two-pass layer it doesn't, the outer edge keeps a
    4-unit outline, and `clipPath` markings stay inside the union.
  - **P8, what ThorVG draws:** `clipPath`, `mask`, linear and radial
    gradients, round joins and caps, `opacity`, `fill-rule` evenodd,
    `feGaussianBlur`, `<image>` with a PNG data URI (`href` and
    `xlink:href`), `<use>`, transforms, `style` attributes and `<style>`
    classes. **Not drawn:** `<text>` (no fonts), so the importer still says
    "Convert text to paths". Blur is drawn, so the sanitiser (C2) may keep
    `feGaussianBlur` and drop only other filter primitives.

**A2. Studio gate, My critters page and widgets.** (P19, P20)
- **Files:** `main.gd`, `gui/settings_window.gd`, `gui/settings_pages.gd`,
  `gui/controls.gd`, new `gui/colour_picker.gd`, `export_presets.cfg`,
  `build-v3.ps1`, `admin.gd`, `gui/admin_page.gd`.
- **What:**
  - **The gate:** `main.studio_on(way)` (P20) is true for every way in the
    admin build or with `--studio`, and false in the player build until that
    way's milestone release.
  - **The My critters page**, laid out as approved in A0. It ships to players
    in this step, since stickers already exist:
    - The System page's *Custom critters* list and sticker import move here,
      into the one list and the Make a critter chooser.
    - The Critters page's "Your own · Soon" tile opens this page.
    - In the chooser, ways that are still gated show nothing to players. In
      the admin build they open placeholders at this stage.
  - **`K.text_field()`.** Moved from `importer.gd`'s hand-styled LineEdit
    (:111–128), which is then switched to use it.
  - **`colour_picker.gd`**, as described in P19. It returns a `#RRGGBB`.
- **Admin:**
  - Buttons: *Open My critters* (`open:my_critters`) and *Colour picker
    test*, which opens it in a dialog.
  - Audit rows: "My critters lists every homemade critter and imports a
    picture" and "Colour picker returns the colour picked".
- **Tests:** `settings_test.gd` still passes, since no settings keys change.
- **Done when:** on the VM, the sticker import and the list work from the new
  page in the player build, which shows no gated ways, and the admin build
  shows the placeholders. The Settings tour screenshots are in the log. This
  step can go out as a small update on its own.

**A3. Store schema 2.** (P21, P23, section 5.1)
- **Files:** `customs.gd`, `customs_test.gd`, new `godot/test_data/` and its
  exclusion in `export_presets.cfg`, `run-tests.ps1`, the CI workflow.
- **What:**
  - `kind`, `schema`, `rev` and `thumb.png`.
  - `load_all()` loads kits and frame critters when the gate is on, and
    skips them, with a log line, when it is off. Stickers load as now.
  - The texture release by reference count for `custom:` keys (section 3),
    and cache keys with `@rev`.
  - **Keep unknown keys** on re-save.
- **Tests:**
  - A 3.1 store loads unchanged.
  - A kit folder is skipped by the 3.1.1 `load_all` logic. The 3.1.1 version
    of the function is copied into the test as a frozen reference.
  - Unknown keys survive a save.
  - Textures are freed 60 s after release (simulated clock).
  - The exported pack contains no `test_data/` (CI).
- **Done when:** all of the above pass locally and in CI.

**A4. Gaits.** (section 4.5)
- **Files:** new `critters/kit/gaits.gd`, `gaits_test.gd`.
- **What:** every gait in the 4.5 table as static functions, with the
  constants copied and their source line cited.
- **Tests:** the 4.5 checks, including parity with rabbit hop, duckling
  waddle, turtle plod, squirrel dart, otter slide, unicorn bounce, hedgehog
  scurry and panda sway at sampled phases.
- **Done when:** `gaits_test.gd` passes.

### Phase B: kit rigs

**B1. Side-on plan and the kit data layer.** (P1–P4, sections 4.1, 4.6,
4.7)
- **Files:**
  - new `critters/kit/kit_data.gd` and `critters/kit/side.gd`;
  - `customs.gd`: kit loading, raster cache, the behaviour table, `_row` for
    kits;
  - `species.gd`, if the row needs a new field;
  - `main.gd`: `--species=custom:<id>` already works; add
    `--kit-dir=PATH` to load a single kit folder for tests;
  - fixture `test_data/kits/kitten_side/`.
- **What:**
  - **`kit_data.gd`:**
    - read `kit.json`;
    - set the rig's variables;
    - load cache textures, and rasterise any that are missing;
    - compute `derived` (grounding, scale, leg length, hit bounds) when
      saving a kit;
    - build the fallbacks in 4.1;
    - build `idles` from the 4.6 table.
  - **`side.gd`:**
    - `_define` from data;
    - `_set_pose` override for P3 (fallback sit with legs, fallback loaf);
    - the gait hooks to `gaits.gd`;
    - the new optional parts (`head-front`, `wing`, `back-extra`,
      `front-extra`) in `_build_rig` / `_build_head_extras`;
    - `region_rect` that covers them.
  - **Fixture: the kitten as a kit.** The kitten's own `walk-body`, legs,
    head, eyes, ears and tail SVGs, with pins taken from `kitten.gd`'s
    constants. A second fixture has only the required parts.
- **Admin:**
  - Buttons: *Spawn the kitten kit* and *Spawn the bare kit*.
  - Audit rows: "Kitten kit walks, sits, naps and blinks like the kitten" and
    "Bare kit naps with a body and blinks".
- **Tests (`kit_test.gd`):**
  - The kit loads.
  - The derived numbers for the kitten fixture are within 2 units of
    `kitten.gd`'s.
  - A missing required part is refused with its name.
  - The behaviour table never gives the bare kit tail or ear behaviours.
  - The fallback loaf has a visible body.
- **Done when:** on the VM, the kitten kit and the real kitten walk side by
  side and look the same apart from the kitten's own species moves.
  Screenshots and a 20 s capture are in the log.

**B2. Faces-you plan.** (P15, section 4.2)
- **Files:** `critters/kit/front.gd`, fixture `test_data/kits/otter_front/`
  plus a no-side-head fixture.
- **What:**
  - Extends `two_head.gd`, with `_define` from data.
  - The panda-style fallback when there is no `head-side`.
  - The gaits plod, scurry, dart, slide, bounce and sway.
- **Admin:**
  - Buttons: *Spawn the otter kit* and *Spawn the one-face kit*.
  - Audit row: "Otter kit sits facing you and walks side-on".
- **Tests:** loads, derived numbers against `otter.gd`, and the one-face kit
  keeps its front face while walking.
- **Done when:** on the VM, the otter kit and the otter look the same.

**B3. Upright plan.** (section 4.3)
- **Files:** `critters/kit/upright.gd`, fixture
  `test_data/kits/duckling_upright/`.
- **What:**
  - The waddle and hop.
  - Wings: flap in groom (as the duckling's fluff-up), shake_off and
    celebrate.
  - The sprung `tuft`.
  - The ball loaf fallback.
- **Admin:** a spawn button and an audit row, as in B1.
- **Tests:** loads, and derived numbers against `duckling.gd`.
- **Done when:** on the VM, it is side by side with the duckling.

**B4. Blob plan.** (section 4.4)
- **Files:** `critters/kit/blob.gd`, fixtures `test_data/kits/slime/`
  (bounce), `ghost/` (float) and `snake/` (slither), drawn by hand for the
  tests.
- **What:**
  - The four blob gaits.
  - Eyes on the body when there is no head.
  - The melt loaf.
  - Climbing as a slide up the wall: override `_climb_params`.
  - Throws land with a squash. A float blob lands softly and rises back to
    its hover height.
- **Admin:**
  - Buttons: *Spawn slime*, *Spawn ghost*, *Spawn snake*.
  - Audit row: "Blobs bounce, float and slither; nap melted; climb".
- **Tests:** loads, idles contain no legged behaviours, and the float height
  stays within 10–20 units.
- **Done when:** all three walk, nap, get thrown, climb and get popped on the
  VM.

**B5. Custom sounds.**
- **Files:** `customs.gd`, `host.gd` (where the sound is played), and the
  sound card on the My critters page.
- **What:**
  - Choose a cast sound (as stickers do) or import a WAV or OGG.
  - Imports are limited to 2 s and 500 KB. The file is decoded and re-saved
    (WAV via `AudioStreamWAV`, OGG via `AudioStreamOggVorbis.load_from_buffer`),
    and played at the same volume as the cast.
- **Admin:** button *Play a homemade sound*; audit row "Imported sound plays
  on pop".
- **Tests:** too long, too big and wrong type are refused, and a good file
  round-trips.
- **Done when:** the audit row passes on the VM.

**B6. Pairs and host numbers for homemade critters.** (P16, P17)
- **Files:** `pairs.gd`, `host.gd`, `aura.gd`, the kit plan scripts.
- **What:**
  - **Pairs:** the generic pairs gain need-checks, and kits may join them.
  - **The fix, as its own commit:** gate `play_bow`'s stretch with `can_do`.
  - **Host numbers:** the body centre, confetti height and crown lift come
    from the critter (P17).
- **Admin:**
  - Button: *Pair the kitten kit with the kitten*.
  - Audit row: "Homemade critters join generic pairs only".
- **Tests:** `pairs_test` cases: a kit never gets kitten_tussle, a blob never
  gets play_bow, and a cast critter without stretch skips play_bow's stretch.
- **Done when:** the tests pass, and a kit-and-cast sniff and sit_together
  play on the VM.

### Phase C: Part kit (players' own drawing software)

**C0. Design session: importing.** (P26) *With the developer.*
- **What:** design one import flow that the Part kit (C4), the sticker
  importer and the frame importer (E3) all share, following the A0 design:
  - choosing or dropping a file, and what each kind of file becomes;
  - the preview, the list of found and missing parts with what each costs,
    and the warnings;
  - naming and keeping, and Reload;
  - where the templates and `making-critters.md` are offered.
- **Done when:** the developer approves it. It is saved in
  `design/studio/import/`, with the decisions in the log.

**C1. Templates.** (P22)
- **Files:** new `design/templates/build.py`, its output in
  `godot/templates/`, which ships.
- **What:** for each plan, `side-1.svg`, `front-1.svg`, `upright-1.svg` and
  `blob-1.svg`. Each has:
  - one Inkscape layer per part, with the part name as both `inkscape:label`
    and `id`;
  - a locked `guide` layer: a faint cast critter (the kitten, otter or
    duckling; for the blob, the slime fixture), the frame, the ground line
    and notes such as "draw facing left", "overlap at the joints" and
    "keep lines bold";
  - a `pins` layer with one small named circle per pin.
- Optional parts are marked in the layer name, for example
  `tail (optional)`. The suffix is stripped when matching.
- Each template also has a `*-guide.png` for raster apps: the same picture
  flattened, at 2× size (600 x 560).
- **Done when:**
  - every template opens in Inkscape with its layers named;
  - re-importing an untouched template gives a kit that is the guide critter
    itself (the round trip, C4's test);
  - the PNGs are exactly 2× the frame.

**C2. SVG sanitiser and layer splitter.** (P7, P8, P10)
- **Files:** new `svg_clean.gd`, `svg_clean_test.gd`, and fixtures in
  `test_data/svg/`: an Inkscape export, an Affinity export, an Illustrator
  export, plus hostile files.
- **What:**
  - **`clean(text)`:** the whitelist from P10, which returns the clean text
    and a list of what was dropped.
  - **`split(text)`:** finds the layer groups, normalises their names and
    matches them with aliases (P7). For each part it returns an SVG with the
    document's `viewBox` and `<defs>` and only that layer. Layer transforms
    are kept.
  - Pins are read from the `pins` layer.
  - A non-matching document (no layers) is reported as "no layers found",
    with a pointer to the template.
- **Tests:**
  - each app fixture splits into the right parts;
  - each hostile file is cleaned or refused (entity bomb, external `href`,
    `<script>`, `<foreignObject>`, 50,000 paths, 10 MB);
  - the clean output re-parses.
- **Done when:** `svg_clean_test.gd` passes.

**C3. Raster imports.** (P9, P10)
- **Files:** new `raster_kit.gd` (PNG folder or zip, and `.ora`), tests, and
  fixtures: a Krita `.ora`, a PNG folder at 2×, a Photoshop trimmed set with
  `parts.txt`, and bad sizes.
- **What:**
  - Read the header before decoding (P10).
  - Check the size against the template (an exact multiple).
  - Downscale to 1× for the cache, keeping the 2× source in `parts/` for
    zoom.
  - Match names as in P7.
  - `.ora`: parse `stack.xml` for names and offsets, and composite each layer
    into a full-canvas image.
- **Tests:** each fixture imports, bad sizes are refused with the template
  size in the message, and an oversized header is refused without decoding.
- **Done when:** the tests pass.

**C4. The kit importer.** (P4, P25)
- **Files:** new `gui/kit_import.gd` (opened from Homemade › Import
  drawings), `customs.gd` (`add_kit`), and `critter_view.gd` if the preview
  needs a pose control.
- **What:**
  1. Choose a plan, with pictures of each.
  2. Pick a file: SVG, a PNG folder, a zip or `.ora`.
  3. A checklist: each part found or missing, and what a missing part costs
     ("no tail: no tail swish"); anything the sanitiser dropped; layers that
     didn't match, with a drop-down to assign them.
  4. **Joints:** the art with the pins drawn on it, draggable. The critter
     walks beside it live, with buttons to make it sit, nap, blink and look.
  5. Name, size, speed, gait (that plan's gaits) and sound.
  6. Keep.
- **Get the drawing templates** saves the four SVGs and guide PNGs to a
  folder the player picks.
- **Reload from file:**
  - `source.json` remembers where the kit came from.
  - In the Homemade list, the kit's *Reload* re-imports it, keeping its
    pins, name and settings.
  - While the importer is open, the source file is checked every 2 s, and
    the preview updates when it changes. That way an artist can keep their
    app and the preview side by side.
- **Admin:**
  - Buttons: *Import the test template* (the round trip) and *Import the
    Krita fixture*.
  - Audit rows: "Template round trip gives the guide critter", "Missing
    parts are listed with their cost" and "Reload picks up a changed file".
- **Tests:** the round trip in `kit_test.gd`: template, then import, then
  derived numbers equal to the fixture's.
- **Done when:** on the VM, a kit drawn in Inkscape and one exported from
  Krita (the fixtures) import, walk and reload. The tester's own drawing goes
  through it after R1.

**C5. Drop a file to import.** (P19)
- **Files:** `host.gd` and `gui/settings_window.gd`: connect
  `files_dropped`; route by extension to the sticker importer, the kit
  importer, the frame importer (from E) or the `.critter` installer (from G).
  Behind the gate.
- **Admin:** button *Simulate a drop of the test template*; audit row
  "Dropping a file opens the right importer".
- **Done when:** a drop onto a critter on the VM opens the kit importer.

**R1. Release 3.2.0: "Draw your own critters".** Turns on the `kit` way:
- the four plans;
- the Part kit with its templates, and drop-to-import;
- custom sounds;
- pairs.

Follow the milestone release steps in section 9.

### Phase D: Shape Builder

**D0. Design session: the Studio window.** (P18, P26) *With the developer.*
- **What:** design the Shape Builder's window, following the A0 design:
  - the canvas, frame and ground line;
  - layers grouped by pose, and how missing parts are shown;
  - the shape tools, the colour panel and the live preview;
  - picking a starter, placing pins, saving, and going back to My critters;
  - what a first-time player sees.
- **Done when:** the developer approves it. It is saved in
  `design/studio/builder/`, with the decisions in the log. D2–D6 follow it.

**D1. Shape model and SVG writer.** (P5, P6, section 5.3)
- **Files:** new `studio/shapes.gd` and `studio/shape_svg.gd`, and
  `shapes_test.gd`.
- **What:**
  - **Model:** each shape type in 5.3, with:
    - its outline as a polygon (for hit-testing and the drag preview);
    - its SVG element;
    - validation against the limits.
  - **Writer:** `shapes.json` → one SVG per part:
    - the two-pass outline;
    - `inside` clips;
    - eye presets;
    - blush;
    - the automatic parts:
      - closed-eye arcs at each `eye` shape;
      - tinted far legs and ears;
      - the mirrored ear;
      - the loaf and sit stand-ins, written as real SVG so the rig sees ordinary
        parts.
  - **Pin suggestion** from the geometry (4.7).
- **Tests:**
  - every shape type round-trips (JSON to model to JSON);
  - out-of-range values are clamped or refused;
  - the outline trick's raster has no inner outline pixels (a sampled check
    on a two-ellipse layer);
  - suggested pins on a starter are within 6 units of the hand-placed ones.
- **Done when:** `shapes_test.gd` passes.

**D2. Studio window shell.** (P18, decision 2)
- **Files:** new `gui/studio/studio_window.gd`, `gui/studio/canvas.gd` and
  `gui/studio/layers_panel.gd`.
- **What:**
  - The window: same chrome as Settings, resizable, with a minimum size.
  - The canvas: the 300 x 280 frame with 120 units of headroom shown (for
    hats), the ground line, a faint guide critter (can be switched off),
    zoom from 50% to 400%, pan, and a pixel grid at high zoom.
  - The layers panel, grouped by pose (Shared, Walking, Sitting, Napping).
    Each part has show/hide and lock, "automatic" parts are marked, and
    *Draw this pose* copies from walking (P2).
  - The other layers are shown faintly so the player draws a part in place.
- **Admin:** button *Open the Studio*; audit row "Studio opens at minimum
  size on a 1366 x 768 screen".
- **Done when:** the window opens, pans and zooms on the VM at 100% and
  150% scale.

**D3. Shape tools.**
- **Files:** `gui/studio/tools.gd`, `gui/studio/history.gd`.
- **What:**
  - **Adding:** one button per shape type. A click on the canvas places the
    shape at a default size.
  - **Selecting:** click; Shift-click adds to the selection; drag-select.
  - **Handles:** move; scale (Shift keeps the ratio); rotate (Shift snaps to
    15°); point handles on `blob` and `stroke`; a corner-radius handle on
    `rect` and `tri`.
  - **Shape commands:** bring forward, send back, mirror, duplicate
    (Ctrl+D), delete (Del), and nudge with the arrow keys (Shift for 10).
  - **Live symmetry** on front-facing layers: shapes on one side are mirrored
    to the other as you draw.
  - **Undo and redo** (Ctrl+Z, Ctrl+Y). Each action is a snapshot of the
    layer, capped at 200.
  - **Copy and paste** between layers and poses.
  - **Snapping** to the ground line and the frame centre.
- **Tests:** `history_test.gd` (undo and redo across 50 actions restores
  exactly) and hit-testing on rotated shapes.
- **Done when:** an Admin script (*Build the test critter by script*) drives
  the tools to make a small critter. The output matches a stored
  `shapes.json`.

**D4. Colour and style.**
- **Files:** `gui/studio/style_panel.gd`, plus `colour_picker.gd` from A2.
- **What:**
  - Fill colour.
  - Outline on or off per shape.
  - *Marking* (sets `inside`).
  - Eye presets: big, sleepy, sparkly, simple dot.
  - Blush on or off.
  - A palette row of the colours used in this critter, for re-use.
  - The outline colour and width are fixed to the cast's style. The player
    can't change them, which is what keeps homemade critters looking like
    they belong.
- **Done when:** recolouring the test critter updates the canvas and the
  preview.

**D5. Starters.**
- **Files:** `godot/studio/starters/*.json`, written by hand in the builder
  and saved.
- **What:** two starters per plan:

  | Plan | Starters |
  |---|---|
  | Side-on | round cat, floppy dog |
  | Faces you | bear, round mouse |
  | Upright | chick, penguin |
  | Blob | slime, ghost |

  Plus *Blank*. Each starter has every automatic pose left automatic, so a
  new player only sees what they need to change.
- **Admin:** button *Spawn every starter*; audit row "Every starter saves as
  a kit that walks".
- **Done when:** all eight walk on the VM.

**D6. Preview, pins and save.** (P4, P25)
- **Files:** `gui/studio/preview.gd`, `customs.gd` (`add_kit` from shapes).
- **What:**
  - **Live preview:** a real kit critter walks beside the canvas, with
    buttons to sit, nap, blink, look and *Try clothes* (after F).
  - **Pins mode:** shows the suggested pins on the canvas, draggable.
  - **Save:** validate, write `shapes.json` and the SVGs, rasterise, make the
    thumbnail, and add the critter to the Homemade list.
  - **Edit later:** *Edit* in the Homemade list opens the Studio with its
    `shapes.json`.
  - Closing with unsaved changes asks first.
- **Admin:** button *Save the test critter*; audit rows "Builder critter
  arrives, walks, naps and blinks" and "Edit then save updates the critter on
  screen" (the `@rev` cache key).
- **Done when:** on the VM, a critter built from the round-cat starter with
  changes arrives on the desktop. It is then edited, and the critter on
  screen updates.

**D7. Usability pass.**
- Use the D3 to D6 flows the way a new player would.
- Fix what is confusing: tooltips on every tool, an empty-state hint on each
  layer ("Add a shape to draw the tail"), and keyboard shortcuts listed in a
  `?` panel.
- Any feedback from the tester's use of 3.2.0 that touches the shared
  screens is worked in here too.
- **Done when:** the developer has walked through the flows and signed them
  off, and every issue found is fixed or logged.

**R2. Release 3.3.0: "Build a critter from shapes".** Turns on the
`shapes` way. Follow the milestone release steps in section 9.

### Phase E: frame critters

**E1. Clip player.** (P11, P12, sections 4.6 and 5.4)
- **Files:** new `critters/kit/frames.gd`, `customs.gd` (frame kind, atlas),
  `behaviours.gd` (lookup for `clip:` ids), fixture
  `test_data/frames/pixel_cat/`.
- **What:**
  - Extends `critter.gd`. It keeps movement, modes, host, edges, throws,
    climbing (the host rotates it) and dizzy (the host spins it).
  - It replaces the part rig with one Sprite2D on the atlas.
  - **Mode picks the clip:**

    | Mode | Clip | Falls back to |
    |---|---|---|
    | walk | `walk` | none (required) |
    | sit | `sit` | `walk` frame 0 |
    | nap | `nap` | `sit` |
    | held | `held` | `sit` |
    | airborne | `thrown` | `held` |
    | landing | `land` | a squash |
    | wall | `climb` | `walk` |
    | blink | `blink`, in place of sit for one play every few seconds | none |

  - `act-*` clips run as `clip:` behaviours.
  - Walk speed follows `stride_px`.
  - Art faces left; `faces: right` flips it.
  - `region_rect` and the hit bounds come from the union of the clip's frame
    alpha boxes.
- **Admin:** button *Spawn the pixel cat*; audit row "Frame critter walks,
  sits, naps, plays its act clips, climbs and is thrown".
- **Tests:** `frames_test.gd`: fallbacks, clip behaviours appear in idles,
  the atlas is within 2048, and frames are released 60 s after the last
  instance.
- **Done when:** on the VM, the pixel cat does everything in the audit row.

**E2. Frame formats.** (P13)
- **Files:** new `frames_import.gd`, `gif.gd`, `apng.gd`, tests, and fixtures
  for each format (made with Aseprite, Krita, ezgif and ffmpeg-style tools).
- **What:**
  - a folder per clip of numbered PNGs;
  - a sprite sheet with a grid (rows, columns, count);
  - Aseprite JSON + PNG, where frame tags become clips;
  - GIF, one file per clip;
  - APNG;
  - a zip of any of these.
  - Every frame is re-encoded on import.
- **Tests:**
  - each fixture decodes to the right frame count and size;
  - GIF disposal modes 1, 2 and 3 and transparency are correct (pixel
    checks);
  - the 64-frame cap holds;
  - an oversized header is refused.
- **Done when:** the tests pass.

**E3. Frame importer.** (P11)
- **Files:** new `gui/frames_import.gd`.
- **What:**
  - Assign files to clips; a single sheet or Aseprite file fills in its
    clips.
  - Per clip: fps, loop, and loops for act clips.
  - Facing.
  - Automatic grounding with a nudge.
  - A stride slider with a live preview.
  - The P11 checklist.
  - Name, size and sound.
  - Keep, and Reload (as in C4).
- **Admin:** button *Import the pixel cat sheet*; audit row "Frame import
  warns about a loop that doesn't close".
- **Done when:** on the VM, the fixtures for every format import and walk.

**R3. Release 3.4.0: "Animated critters".** Turns on the `frames` way.
Follow the milestone release steps in section 9.

### Phase F: clothes on homemade critters

**F1. Head metrics.** (P15, P17)
- **Files:** `kit_data.gd`, `studio/shape_svg.gd`, `gui/kit_import.gd`.
- **What:**
  - **Builder kits:** the metrics are exact from the shapes:
    - the head ellipse is the fit of the head layer's outline;
    - the eyes come from the `eye` shapes;
    - the chin is the bottom of the head layer;
    - `top` is the crown.
  - **Part kits:** the head is fitted from the `head` part's alpha (bounding
    ellipse) and the eyes from `eyes`' alpha blobs. The importer then shows
    the ellipse with a hat on it ("Where's its head?") so the player can
    adjust it.
  - **Front plans:** also the side head's metrics and the computed `wear_*`
    values (P15).
  - Stored in `kit.json` `head`.
- **Tests:** the metrics of the kitten-kit fixture are within 4 units of
  `build.py`'s `SPECIES["kitten"]`.

**F2. Clothes drawn at runtime.** (P14, decision 3)
- **Files:** new `wear_draw.gd` (a port of `design/wear/common.py`,
  `build.py` and `items_*.py`), `wear.gd` (`svg_for_kit(id, metrics, dye)`),
  `critter.gd` (`wear()` takes the SVG text from a hook the kit plans
  override), and `wear_draw_test.gd`.
- **What:**
  - Port every item's draw function and its helpers.
  - Kits draw from their own metrics. The result is cached per kit, item and
    dye, and released with the kit.
  - Species-only items are never offered to homemade critters: the Shop's
    preview and dressing up both filter on `Wear.only()`.
  - `hides` for kits: hoods hide `ear-l`, `ear-r`, `tuft` and `head-front`.
- **Parity test:** for each built-in species and each item, the GDScript SVG
  rasterised equals the shipped `art/wear/<item>/<species>.svg` rasterised,
  within 1% of pixels at alpha difference > 8. It fails on any item that
  drifts.
- **Admin:**
  - Buttons: *Dress the kitten kit in everything* (cycles items) and *Make
    the clothes contact sheet*, which writes a PNG of every item on three
    awkward test heads (wide, tall, tiny) to the scratch folder.
  - Audit row: "Clothes fit homemade heads (contact sheet reviewed)".
- **Done when:**
  - the parity test passes;
  - the contact sheet has been reviewed;
  - any item that looks wrong on an awkward head goes on a `FITS_BADLY`
    list in `wear.gd` and is hidden for kits, rather than being fixed one
    by one.

**F3. Clothes on frame critters.**
- **Files:** `gui/frames_import.gd`, `frames.gd`.
- **What:**
  - Optional *Where's its head?*. Per clip, mark the head on the first
    frame, and on any later frames where it moves. The frames in between
    are interpolated.
  - Clothes are drawn from a reference metrics set scaled to the marked size
    and moved per frame.
  - With no marks, clothes are off for that critter, and the Shop says so.
- **Admin:** button *Dress the pixel cat*; audit row "Frame critter with head
  marks wears a hat that follows its head".
- **Done when:** the audit row passes on the VM.

### Phase G: sharing

**G1. Builder codes.** (section 5.5)
- **Files:** new `share.gd` and `share_test.gd`, and the My critters page:
  *Copy code* on builder critters, plus *Paste a code*.
- **What:** encode and decode as in 5.5. A pasted code opens a preview with
  the name and the critter walking, and offers *Keep* or *Edit in Studio*.
- **Tests:**
  - round trip;
  - a code over the size cap or with bad numbers is refused;
  - a decompression bomb (a tiny code that inflates past the cap) is refused
    without allocating.
- **Admin:** button *Copy and paste the test critter*; audit row "A code
  round-trips to the same critter".

**G2. `.critter` v3 files.** (P10, P24, section 5.5)
- **Files:** `share.gd`, the install dialog in `gui/`, the C5 drop routing.
- **What:**
  - **Export** from the Homemade list: *Save as file*.
    - Builder critters carry `shapes.json`.
    - Part kits carry their parts.
    - Frame critters carry their clips.
    - Stickers can be exported only if decision 5 says so.
  - **Install:** pick a file or drop it. A dialog shows the name, the author,
    the licence, the critter walking, and "Only install critters from people
    you trust". Nothing is written until *Install*.
  - **v2.0 `.critter` files** install as stickers.
- **Admin:**
  - Buttons: *Export and re-install each test critter* and *Install the v2.0
    test file*.
  - Audit row: "Every kind round-trips through a file".
- **Tests:**
  - a round trip for each kind;
  - an `app_min` above this version is refused with a message;
  - a manifest whose hash doesn't match is refused.

**G3. Hostile-file pass.** (P10)
- **Files:** `tools/fuzz_import.gd`, a headless script that is not shipped.
- **What:** mutate every fixture (truncate, flip bytes, inflate sizes, rename
  entries) and feed the results to every importer, 2,000 cases each.
- **Done when:** nothing crashes, hangs over 5 s or allocates over 1 GB. Any
  finding is fixed and its case added to the unit tests.

Clothes (F) and sharing (G) ship together with H in R4. A smaller update
can carry clothes earlier if the tester wants to try them.

### Phase H: Collection, docs and release

**H1. Collection.**
- **Files:** `gui/collection.gd`.
- **What:**
  - The Homemade row shows every kind with a small badge (Built, Drawn,
    Animated, Picture).
  - Live previews are capped at 12. The rest show `thumb.png` until hovered.
- **Admin:** existing `open:collection` with 20 homemade critters; audit row
  "Homemade row caps live cards at 12".

**H2. Docs.**
- **`docs/making-critters.md`** (public, linked from the importer and the
  Studio's `?`):
  - the three ways in;
  - the four plans with pictures;
  - each drawing app's export steps (Inkscape, Affinity, Illustrator, Krita,
    Procreate, Photoshop, Aseprite);
  - the artist rules;
  - what each missing part costs;
  - the frame clips and their fallbacks;
  - sharing, and installing safely.
- **`README.md`** for 3.5, `release-notes-v3.5.md`, and
  `docs/TROUBLESHOOTING.md` entries for import errors.

**H3. Performance and soak.**
- **On the VM:**
  - 12 critters, 6 of them homemade: 1 sticker, 1 of each kit plan and 1
    frame critter. Frame time stays within 1 ms of 12 built-ins.
  - VRAM stays under 150 MB with 10 different homemade critters spawned.
  - An 8 h soak with 4 homemade critters out shows no memory growth (the
    texture release works).
- The results go in `docs/v3-soak-report.md`.

**H4. R4: release 3.5.0, "Critter Studio".** Turns on the `share` way and
ships clothes, sharing, the Collection badges and the docs.
- **The gate:** with every way now on for players, `main.studio_on()` and
  its checks are deleted.
- Follow the milestone release steps in section 9, plus the downgrade check
  from P21.
- **Release:** `.
elease.ps1 -Version 3.5.0 -Title "Critter Studio"
  -NotesFile release-notes-v3.5.md`.

---

## 8. Testing, overall

- **Headless** (`run-tests.ps1` and CI pick up each new `*_test.gd`):
  - `customs_test`, `gaits_test`, `kit_test`, `svg_clean_test`, `raster_kit`
    tests, `shapes_test`, `history_test`, `frames_test`, the format tests,
    `wear_draw_test` (parity), `share_test`, `pairs_test` additions and
    `economy_test` additions.
  - The economy additions: 10,000 rolled arrivals with every kind of
    homemade critter switched on never give one a tier, and berries and the
    Collection's species rows are identical with them on or off.
  - `settings_test` is unchanged and must stay green.
- **Fixtures:** the cast-as-kit fixtures (kitten, otter, duckling) are the
  reference for everything. If a kit rig ever disagrees with its species,
  the kit is wrong.
- **On the VM, never on this PC:** every windowed run, every tour and every
  soak. Headless tests are fine locally.
- **Feedback after each release:** the tester updates like any player, through
  the in-app updater. Their notes (the in-app comments window, with
  screenshots) go in the log and become patch fixes, or changes to later
  steps.
- **The manual checklist in CLAUDE.md** at every release, plus every Admin
  audit row.

---

## 9. Release, branching and versions

- Each step is a branch and a PR into `main`. Unfinished ways stay behind
  the `studio` gate (P20, decision 1).
- **Milestone releases** are normal public releases, offered to every
  install by the updater (decision 7):

  | Release | After | Version | Turns on |
  |---|---|---|---|
  | R1 | C5 | 3.2.0 | `kit`: four plans, Part kit, sounds, pairs |
  | R2 | D7 | 3.3.0 | `shapes`: the Shape Builder |
  | R3 | E3 | 3.4.0 | `frames`: animated critters |
  | R4 | H3 | 3.5.0 | `share`, clothes, Collection, docs; the gate is removed |

- **The milestone release steps** (R1–R4):
  1. Turn the way's switch on in the player build and delete its gate
     checks.
  2. On the VM: the manual checklist in CLAUDE.md and every audit row, old
     and new.
  3. **The update path:** install the previous public release on the VM
     with a few homemade critters, let its updater offer the new version,
     install it from there, and check the critters are all still there.
  4. `README.md` and `release-notes-vX.Y.md` (a minor release needs notes).
  5. `.
elease.ps1 -Version X.Y.0 -Title "..." -NotesFile
     release-notes-vX.Y.md`.
  6. Tell the developer it is live, so the tester can be told to update.
- **Smaller updates in between** are patch releases from `main` (3.2.1 and
  so on), whenever something is ready to try or a fix is due. A way that
  isn't finished stays gated in them.
- **The CLAUDE.md "discuss first" list:**
  - Storage: **yes**, decision 4.
  - Dependencies: **none added**.
  - Native layer, installer, updater: **not touched**. The update path is
    tested at every milestone, but the updater itself does not change.

---

## 10. Decisions

| # | Decision | Options | Recommended | Status |
|---|---|---|---|---|
| 1 | How the long build lands | (a) Step PRs into `main`, unfinished ways behind a `studio` gate. (b) One long `critter-studio` branch merged at the end. | **(a)**: `main` stays releasable and merges stay small | **decided 2026-11-23** |
| 2 | Where the Shape Builder lives | (a) Its own Critter Studio window. (b) A page inside Settings. | **(a)**: Settings is too small for canvas + panels + preview (P18) | **decided 2026-11-23** |
| 3 | Clothes on homemade heads | (a) Port the item generators to GDScript with a parity test (P14). (b) Affine fit from the nearest species. | **(a)**: fits any head; parity test stops drift. Later, `build.py` could call the GDScript and the Python copy could go (not in this plan) | **decided 2026-11-23** |
| 4 | Storage (CLAUDE.md: discuss first) | Extend `user://custom/<id>/` as in 5.1; kits never write `image.png`; settings and economy save untouched | **As written** | **decided 2026-11-23** |
| 5 | Can stickers be exported in `.critter` files? | (a) Yes, with a line in the dialog: "Made from a picture: only share pictures you're happy for others to have". (b) No (they're your own pet). | **(a)**: v2.0 allowed it | **decided 2026-11-23** |
| 6 | Hosted gallery | (a) None in this plan; files and codes travel however players like. (b) A pinned GitHub Discussion. | **(a)**: nothing to moderate | **decided 2026-11-23** |
| 7 | How it reaches the tester | Milestone releases 3.2.0–3.5.0 through the updater, smaller patch updates in between; nothing sent as a file (section 9) | n/a | **decided 2026-11-23** (replaces file-sent betas) |
| 8 | The tester's drawing app | Ask them | n/a. It sets which fixture is made first in C2 or C3 (both ship) | open |
| 9 | Coat Studio | Dropped in favour of the Shape Builder | n/a | **decided 2026-11-19** |
| 10 | Scope | Everything in section 1; the cut-out and AI splitting out | n/a | **decided 2026-11-19** |
| 11 | Design sessions for the app UI | A0, C0 and D0 use Claude Design and the design skills with the developer; no tester mock-ups | n/a | **decided 2026-11-23** |

---

## 11. Progress

| Step | What | Status |
|---|---|---|
| A0 | Design: My critters and Make a critter | waiting for a session with the developer |
| A1 | Rasteriser spike | done 2026-11-24 |
| A2 | Studio gate, My critters page, widgets | not started |
| A3 | Store schema 2 | done 2026-11-24 |
| A4 | Gaits | done 2026-11-24 |
| B1 | Side-on plan + kit data layer | done 2026-11-24 |
| B2 | Faces-you plan | done 2026-11-24 |
| B3 | Upright plan | done 2026-11-24 |
| B4 | Blob plan | done 2026-11-24 |
| B5 | Custom sounds | done 2026-11-24 (the card waits for A2) |
| B6 | Pairs and host numbers | done 2026-11-24 |
| C0 | Design: importing | not started |
| C1 | Templates | done 2026-11-24 |
| C2 | SVG sanitiser and splitter | done 2026-11-24 |
| C3 | Raster imports | done 2026-11-24 |
| C4 | Kit importer | engine done 2026-11-24; screens wait for C0 |
| C5 | Drop a file to import | not started |
| R1 | **Release 3.2.0** | not started |
| D0 | Design: the Studio window | not started |
| D1 | Shape model and SVG writer | done 2026-11-24 |
| D2 | Studio window shell | not started |
| D3 | Shape tools | not started |
| D4 | Colour and style | not started |
| D5 | Starters | not started |
| D6 | Preview, pins and save | not started |
| D7 | Usability pass | not started |
| R2 | **Release 3.3.0** | not started |
| E1 | Clip player | done 2026-11-24 |
| E2 | Frame formats | done 2026-11-24 |
| E3 | Frame importer | not started |
| R3 | **Release 3.4.0** | not started |
| F1 | Head metrics | not started |
| F2 | Clothes drawn at runtime | not started |
| F3 | Clothes on frame critters | not started |
| G1 | Builder codes | not started |
| G2 | `.critter` v3 files | not started |
| G3 | Hostile-file pass | not started |
| H1 | Collection | not started |
| H2 | Docs | not started |
| H3 | Performance and soak | not started |
| H4 | **R4: release 3.5.0** | not started |

### Log

- 2026-11-19: plan written. Decisions 9 and 10 made.
- 2026-11-23: decisions 1–7 made as recommended. Decision 8 waits on the tester.
- 2026-11-23: no mock-ups for the tester and no file-sent betas: milestones go
  live as normal updates (decision 7 changed, section 9). Design sessions A0,
  C0 and D0 added, and P26 (one My critters home for every kind). Decision 11.
- 2026-11-24: A1 done: SVG throughout (P6), two-pass outlines confirmed (P5),
  ThorVG feature list recorded (P8). A0 needs the developer, so the steps that
  don't touch the UI (A3, A4, B1 on) run first; A2 waits for A0.
- 2026-11-24: A3 done. The gate's switches (`Customs.ways`, `way_on()`,
  `--studio`, all on in the admin build) were built here rather than in A2,
  since `load_all` needs them; A2 keeps the page and widgets. The gate lives
  in `customs.gd`, not `main.gd`, so static code can ask it. `economy_test`
  and `save_test` fail on this PC on `main` as well (JSON parse of the save);
  not touched here.
- 2026-11-24: A4 done. `gaits.gd` takes a state dictionary per critter
  (`Gaits.state()`: the gait, its counters, and the `mid` and `feet` pins a
  hop pitches and a waddle rocks about). `gaits_test.gd` drives each species
  beside a kitten running the gait and compares pose, speed, phase, lift,
  squash, legs and the dart and slide draws. The dart row of 4.5 was wrong
  (squirrel walks by distance and is always settled) and is fixed. The new
  gaits are `blob_bounce`, `float` and `slither`.
- 2026-11-24: B1 done. Changes from the plan, all in the code's docstrings:
  - **Fixtures are generated, not stored.** `critters/kit/fixtures.gd`
    builds the kitten kit and the bare kit from `res://art/kitten/`, which
    ships, so the Admin buttons work in the admin build too. The file is
    left out of the player preset. The kitten's sitting and nap parts are
    joined into one SVG each.
  - **More optional pins** than 4.1 lists, because the cast draws parts in
    one place and moves them in others: `head` (the head's pivot in its own
    drawing), `neck-loaf`, `neck-stand`, `tail-walk`, `tail-sit`, the
    `-far` hips, and each leg's own pivot. All default to the plain pins.
  - **Size:** `critter_scale` = 0.45 x 226 / (walking height), where 226 is
    the kitten's walking height, so the kitten kit is exactly the kitten's
    size. (4.7 said 210 units.)
  - **Hit boxes** are everything drawn plus 4, so they hold the kitten's
    hand-trimmed boxes and run up to 22 units larger.
  - **Grounding** is measured (`ground_dy`), not applied: the importer (C4)
    and the builder (D6) move the art when they save it.
  - Checked on the VM: the kitten kit beside the kitten, and the bare kit
    with its darker far legs and melted nap. Screenshots only; the 20 s
    capture is still to do.
- 2026-11-24: B2 done. The otter fixture is the otter's art moved by
  (26, -8) onto the kit frame's ground point. Until F1 measures the two
  heads, the clothes shift between faces is the neck's move (P15's
  no-side-head rule), not the crown difference. A kit has one tail, so the
  otter kit walks with its sitting tail. Its hit boxes sit inside the
  otter's hand-set ones (60-85% of their area). `two_head.gd` assumed the
  side face and the closed eyes were always drawn; `front.gd` overrides
  `_build_head_extras`, `_on_pose` and `_apply_extras` so they are optional.
  Seen on the VM: the otter kit beside the otter, and the one-face kit
  plodding with its front face.
- 2026-11-24: B3 done. Pins are `neck-sit` (4.3's `neck`), `neck-walk`,
  `hip`, `hip-far` and the wing and tuft pins, with the duckling's numbers
  as defaults. The duckling's beak is drawn on its head in the fixture, and
  `beak-in` is its `mouth-open`. Groom counts a wing as "groom paws" for
  this plan (the fluff-up). Seen on the VM beside the duckling.
- 2026-11-24: B4 done. Gait names in kit.json: `blob_bounce`, `glide` (4.4's
  "slide", renamed so it isn't the otter's), `float`, `slither`. Float is a
  hover in every pose (`p.float`), not a walking lift, so a ghost doesn't
  drop to the ground to sit. Slither is a wave of the whole body (torso turn
  and dip), not still.gd's mesh bend: simpler, and it reads well at size.
  The fixtures are drawn in `fixtures.gd` rather than `test_data/`. Seen on
  the VM: slime, ghost and snake getting about. Throwing, climbing and
  popping them are on the Admin page but weren't run on the VM.
- 2026-11-24: B5 done apart from the sound card, which goes on the My
  critters page in A2 (after the A0 design session). A WAV is decoded and
  written again; an OGG is kept as it is once it decodes, since Godot can't
  write OGG. `custom.json` says `"sound": "own"` and the file is
  `sound.wav` or `sound.ogg`. Admin: *Imported sound plays on pop*. Not yet
  run on the VM (it has no audio device, so it can only check for errors).
- 2026-11-24: B6 done. The play_bow fix is its own commit. `critter.gd`
  gains `body_centre_px()` and `head_top_px()` (36 and 90 for the cast);
  kit rigs return measured ones, and `host.gd` and `aura.gd` ask the
  critter. The aura's crown lift is unchanged: homemade critters never
  wear an aura. Pair checks live in `kit_test.gd`, since there is no
  `pairs_test.gd`.
- 2026-11-24: C1 done. The templates are built by `tools/build_templates.gd`
  (headless Godot) rather than `design/templates/build.py`, so they come from
  the same fixture data the tests use (`critters/kit/fixtures.gd`). The
  side-on template shows the kitten walking: its head, tail and legs are
  drawn where they sit when walking, with the pins moved to match, so the
  rig is unchanged. Layers of other poses are hidden. The guide PNGs ship as
  raw files (`templates/*.png` in both presets' include filter). Opening
  them in Inkscape, and the round trip, wait for C2 and C4.
- 2026-11-24: C2 done. The whitelist also keeps `<use>` pointing inside
  the file, `<style>` (Illustrator's default export, with `@import` and
  outside links stripped) and `filter`/`feGaussianBlur` (A1: ThorVG draws
  blur). An empty layer is a part not drawn. Unknown layers come back under
  their own name for the importer to ask about. The app fixtures are made in
  the test with each app's naming (Inkscape labels, Affinity `serif:id`,
  Illustrator `_x5F_`/`_1_` ids); real exports from the tester's app should
  be added as files once decision 8 is answered.
- 2026-11-24: C3 done. A zip's directory is read from its own bytes, before
  anything is unpacked, so entry counts, unpacked sizes and names are checked
  first. Spaces are allowed in names inside zips, beyond P10's character set,
  since drawing apps use them. `parts.txt` lines are "file name x y". PNG
  parts are kept at the size they came (the cache scales them, `kit_data.gd`).
  The fixtures are made in the test; real exports from Krita and Photoshop
  should be added as files once decision 8 is answered.
- 2026-11-24: C4's engine done: `kit_import.gd` (stage a file, write a kit
  folder, ground it). The screens wait for the C0 design session. Untouched
  templates import as their example critters, as SVG and as 2x PNGs (the
  round trip C1 asked for, `kit_import_test.gd`). Grounding counts only
  pixels at least half opaque and leaves art within 6 units of the line
  alone, since the cast's own feet sit a little into it. The part cache is
  now keyed by file content (MD5), and PNG parts shrink through mipmaps,
  because Lanczos left faint pixels that widened the hit boxes.
- 2026-11-24: D1 done. The writer makes the closed-eye arcs and the blush;
  far legs, the other ear, sitting and napping are left to `kit_data.gd`'s
  fallbacks (made from the rasterised parts), not written as SVG. If the
  Studio's preview shows those stand-ins looking soft at large sizes, write
  them as SVG then. Suggested pins: the neck is the centre of the area where
  the head and body shapes really overlap (not their boxes); the tail root
  is the point on the tail's centre line nearest the body.
- 2026-11-24: E1 done. Atlas cells are at part scale (225 x 210), so 64
  frames fit in 2048 x 2048 (9 x 9). `stride_px` is in drawing units. A
  frame critter's moves are a nap and its `act-*` clips; the cast's shared
  moves aren't offered, since its frames can't show them. The `land` clip
  isn't played yet (a squash stands in). Clothes on frame critters wait for
  F3. On the VM the pixel cat showed and sat with its own frames; walking
  across the screen was checked headless (`frames_test.gd`), not on the VM.
  VM note: a checkout there can be blocked by `.uid` files an earlier import
  made; delete them before switching branches.
- 2026-11-24: E2 done: `gif.gd`, `apng.gd` and `frames_import.gd` (stage
  and write, no screens). Fixtures are made in the test by small GIF and
  APNG writers there, not by outside tools; files from real apps (Aseprite,
  Krita, ezgif) should be added once decision 8 is answered. The whole set of
  clips is scaled by one factor to about the cast's height (pixel art by
  whole steps, nearest-neighbour) and each clip is grounded on its lowest
  pixel. Clip names are matched loosely ("idle" is sit, "sleeping" is nap);
  anything else is the player's own move.
