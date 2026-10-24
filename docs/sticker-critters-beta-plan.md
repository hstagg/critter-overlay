# Sticker critters beta: plan

A beta that brings back v2.0's custom critters in v3: one picture becomes a
critter that walks the desktop as one piece. It is Tier 1 of the custom
critters plan (`docs/v3-custom-critters-plan.md` on branch
`v3-custom-critters-plan`, sections 2 and 11.2), cut to what a tester who
used v2.0's custom critters needs to give feedback. Status: proposed,
2026-10-25. Nothing is built.

## What the tester gets

1. **Their v2.0 critters come back by themselves.** On first launch the beta
   copies every critter in `%APPDATA%\CritterOverlay\custom\` into its own
   store, with its name, size, speed and sighting count. v2.0's files are
   left as they are.
2. **They can make new ones.** Settings › System › Custom critters: *Import a
   critter* opens a file picker (PNG, JPG or WebP). A preview shows the
   picture with its background removed (a tolerance slider for fiddly
   photos), walking and sitting, before anything is saved. Name it, keep it.
3. **They live with the cast.** They walk in as visitors, walk with a bob and
   a lean, sit and breathe, hop, lean towards the pointer, nap (settle lower,
   Z's), and can be popped, dragged, thrown, spun dizzy and climb walls,
   because they use the same window code as every critter.
4. **A Homemade row in the Collection** with each one's picture and how
   often it has visited.
5. **Each can be switched off, renamed, resized or deleted** from the
   Custom critters list.

**Not in the beta** (each is a separate decision after feedback): clothes on
custom critters; GIF import (Godot has no GIF decoder; v2.0 GIF critters
still come back, since v2.0 saved them as frames); `.critter` file import and
export; Coat Studio; the artist routes.

## Rules it keeps

- **Outside rarity and the economy** (custom critters plan section 3, option
  a). A custom critter never rolls a tier, has no aura, earns no berries
  (no first find, no row bonus) and never brings a present. Arrivals stay
  as they are: when an arrival rolls Common, a custom critter can take its
  place by its visit weight. A Rare or better roll is never spent on one.
- **Its own storage** (to agree, see Decisions): `user://custom/<id>/`
  (that is `%APPDATA%\Critter Overlay\custom\`) holds `custom.json` (name,
  size, speed, visits, on/off, sighting count, where it came from), the
  cut-out `image.png`, and `frames/` for v2.0 critters that had their own
  frames. `settings.json` and the economy save are not changed; the
  Collection reads the Homemade row from `custom.json`.
- **Safe files.** Files over 15 MB or 4096 px a side are refused; every
  picture is decoded and re-saved as PNG at no more than 512 px, which also
  drops EXIF and GPS data. Only the cut-out is kept, never the original.

## How it is built

| # | Piece | Files | Notes |
|---|---|---|---|
| 1 | Custom store and v2.0 carry-over | new `godot/customs.gd` | Reads and writes `user://custom/`; imports v2.0's folders (`meta.json` schema 1 and 2: `frames/frame_0.png`, or `source.png` when it exists; name, `size_multiplier`, `speed_multiplier`, `sound_profile`, `trail_palette`). Sightings come from `economy.v2_custom_seen`, which 3.0 already kept for this. Replaces `main._v2_custom_notice()`. |
| 2 | The still rig | new `godot/critters/still.gd` extending `critter.gd` | One part. Walk: bob, lean and a sway of the bottom half (a `Polygon2D` mesh bent per frame, as v2.0's shear), or the v2.0 critter's own frames in a loop. Sit: a breathing squash. Squash on landing. Hit box from the picture's opaque area. Behaviour whitelist: `sit_and_look`, `nap`, hop, lean to pointer, shake. Faces left like the cast; flipped for right. |
| 3 | Arrivals | `main.gd` (`_spawn`, `_pick_species`), `host.gd`, `species.gd` | A custom critter is the species id `custom:<id>`. `Species.row()` answers for it from `customs.gd` (script `still.gd`, its idles, pop colours from the picture, a v3 sound picked from v2.0's sound profile). The Common-only swap described above. |
| 4 | Importer | new `godot/gui/importer.gd`; `gui/settings_pages.gd` System card | Background removal as v2.0: the corner colour flood-filled with a tolerance, then a 1 px feathered edge, on the downscaled picture. Live preview through `gui/critter_view.gd`. The *Custom critters* placeholder card becomes the list and the import button. |
| 5 | Collection | `gui/collection.gd` | A Homemade row under the species rows: picture, name, visits. No tier colours. |
| 6 | Admin and audit | `admin.gd`, `gui/admin_page.gd` | Per CLAUDE.md: *Spawn a homemade critter*, *Import the test picture*, *Run the v2.0 carry-over on a test folder*; audit rows for each. |
| 7 | Flags | `main.gd` | `--species=custom:<id>` works like any species; `--custom-dir=PATH` points the store at a test folder, for tests and VM runs. |
| 8 | Beta build | `main.gd` `VERSION`, `export_presets.cfg` | See Decisions for the version number. Player build only (no Admin page). |

### Order

Three sittings, each ending green and on the VM:

1. Pieces 1, 2, 3 and 7, with the tests below. A v2.0 test folder's critters
   walk on the VM.
2. Pieces 4 and 5. A photo and a doodle go through the importer on the VM.
3. Piece 6, the manual checklist, the 8 h soak with two custom critters out,
   the beta installer.

About five to seven focused days in all, against the plan's six to nine for
Tier 1 (that figure included `.critter` import and more importer polish).

## Checks

- **`godot/customs_test.gd`** (headless, picked up by `run-tests.ps1` and
  CI): the store round-trips; a fake v2.0 folder (schema 1 and schema 2,
  one static and one with four frames, one broken) carries over with name,
  size, speed and sightings, and the broken one is skipped with a log line;
  background removal on a made-up picture clears the border and keeps the
  middle; oversized and wrong-type files are refused; a re-saved picture
  has no EXIF.
- **Economy tests:** 10,000 rolled arrivals with custom critters switched on
  never give one a tier, and berries and the Collection's species rows are
  the same as with them off.
- **`settings_test.gd`** still passes (no new keys there).
- **On the VM** (never this PC): two carried-over and one imported critter
  walk, sit, nap, get thrown and climb; Settings tour of System with the
  list; a Collection screenshot with the Homemade row; frame time with 12
  critters, 6 of them custom, within 1 ms of 12 built-ins
  (custom critters plan section 6).
- **Upgrade path on the VM:** a real v2.0 install with two custom critters,
  then the beta over it. Both appear; v2.0's folder is untouched.
- The manual checklist in CLAUDE.md, plus the new Admin audit rows.

## Risks

- **`settings_pages.gd` is being changed** by the Settings overflow fix
  (Shop and Critters pages). The System card work starts after that PR
  merges, to avoid a conflict.
- **Photos with busy backgrounds** cut out badly with a corner flood fill, as
  in v2.0. The importer says so and suggests a PNG with a transparent
  background; a smarter cut-out is the guided cut-out tier, later.
- **The cardboard look.** Next to a cast that blinks and grooms, a still
  looks flat. That is what the beta is for: whether the tester still wants
  their own picture, or would rather recolour a built-in critter (Coat
  Studio).
- **Leaving the beta.** If the tester's copy later installs a release without
  custom critters, their critters stop showing but stay on disk (the same
  as 3.0 today). The version number below keeps that from happening by
  accident.

## Decisions

1. **Storage** (CLAUDE.md asks for this to be discussed): custom critters in
   their own folder, `user://custom/`, with their sightings kept there, and
   `settings.json` and the economy save unchanged. *Recommended.*
2. **Version number and delivery.** The updater compares three numbers and
   ignores pre-releases. Recommended: `VERSION = "3.0.90"`, shown as
   "3.1 beta 1" in About and the sidebar, so a 3.0.x patch is never offered
   to the beta copy and 3.1.0 is when it ships; the installer goes to the
   tester as a file, not as a public release. Alternative: a GitHub
   pre-release (public, but not offered by the updater).
3. **Clothes in the beta:** none, as in v2.0 (*recommended*), or the head
   ellipse step in the importer plus a runtime fit (custom critters plan
   section 4), about three to five more days.
