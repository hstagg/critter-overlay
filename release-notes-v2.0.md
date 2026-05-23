# Critter Overlay v2.0 — a living desktop

The big one. Four headline features, rebuilt settings UI, and a sharing format so you can trade critters with friends.

---

## What's new

### Living world

Every species now moves with a characteristic gait. The kitten punctuates walks with pounce-pauses. The rabbit hops in arcs. The otter occasionally belly-slides. The squirrel darts and freezes. You can tell them apart from movement alone with your eyes half-closed.

40+ named behaviours fire based on context: napping, grooming, stretching, tail-chasing. Pair interactions fire when two critters come within range — sniffing, following, near-miss chases, the duck and otter splashing each other. Over a 30-minute session you'll see 15+ distinct behaviours without any input.

The activity level, spawn rate, and idle bias now follow the system clock. Six time-of-day buckets shift how critters behave — evenings are quieter, late nights are sparse, midday is busy. No visual changes to the overlay; just pace and frequency.

Everything has an off-switch. Set behaviour frequency to 0 and critters reduce to pure locomotion.

### Rarity

Every critter gets a rarity tier on spawn: Common (90%), Uncommon (7%), Rare (2%), Epic (0.9%), Legendary (0.1%). Higher tiers glow — a soft shimmer for uncommon, a full pulsing corona for legendary.

A configurable Rare Hour (default 9–10 PM) doubles rare+ odds. The first spawn of the day gets a boosted roll. A Seen Log in Settings keeps a record of every rare+ sighting, colour-coded by tier.

Per-species rarity caps: turtles and pandas stop at Epic, keeping the truly rare slots open for other species.

### .critter sharing

Custom critters can now be exported as `.critter` files and shared. Drop one onto the overlay window to install it — a confirm dialog shows the name, author, and license before anything touches disk. Or use Settings → Critters → Import .critter for a file-picker flow.

Export a single critter or use "Export all" to write your full collection to a folder at once.

Packages are fully validated before extraction: size limits, allowed file types only, no path traversal, frame dimension checks, WAV size cap. A `.critter` file from an untrusted source cannot write outside the critter folder.

### Settings UX

Six tabs collapsed to four: **Critters**, **Behaviour**, **Audio**, **System**.

Custom critter controls are now always visible on each card — no gear-panel toggle. The Behaviour tab consolidates spawning, living world, and rarity settings in one scrollable page. The System tab has the Seen Log.

Importing now shows an animated preview of the processed critter before committing to disk. Accept or cancel — nothing is written until you confirm.

Toggle pills show ✓ ON / ✕ OFF. Spawn weight uses labeled stops (rare / normal / often / constant). Idle rate renamed to Activity level. Trail style renamed to Animation trail.

---

## Full changelog

**Living world**
- 9 locomotion profiles assigned per species
- 40+ behaviours with trigger logic and cooldowns
- Pair-interaction system with species-specific pairs
- Day/night activity scalar (6 time buckets, system clock)
- Per-species idle whitelists
- All systems have master on/off toggles

**Rarity**
- 5-tier system: Common / Uncommon / Rare / Epic / Legendary
- 4 aura render functions, drawn before sprite
- Per-species rarity_min / rarity_max constraints
- Rare Hour window with configurable start and duration
- First-spawn-of-day bonus
- Seen Log with tier colour coding

**.critter sharing**
- Export: builds a zip with frames, masks, sounds, thumb, meta v2
- Import: full validation then extraction; masks regenerated if absent
- Drag-and-drop onto overlay window
- Confirm dialog before install
- Bulk export to Downloads
- meta.json schema v2 with author, license, attribution_url fields

**Import pipeline**
- Preview-before-commit: animated preview modal, Accept/Cancel
- EXIF/metadata stripping on source images
- 1px Gaussian feathering on alpha channel after threshold

**Settings**
- 6 tabs → 4 (Critters, Behaviour, Audio, System)
- Custom critter inline controls (no gear panel)
- Behaviour tab: spawning + living world + rarity in one place
- Audio tab: unified species list with per-row preview
- System tab: Seen Log
- sv-ttk dark theme + ttk scrollbars
- First-run welcome modal (fires once per install)
- Tooltips on all personality controls
- ✓ ON / ✕ OFF toggle pills
- Labeled weight stops: rare / normal / often / constant

**Foundations**
- events.py: thread-safe dispatch for cross-thread call sites
- storage.py: schema_version field, migration helper
- SCHEMA_VERSION bumped to 2

---

## Upgrading from v1

Settings and custom critters from v1.x carry forward automatically. The config loader deep-merges with new defaults — no existing keys overwritten, no manual migration needed.

v1 custom critters auto-migrate to schema v2 in memory. Their folders on disk are only updated when you next change a setting for that critter.

The first-run welcome modal will appear once on first launch after upgrading (because `first_run_completed` was absent in v1 configs) and not again.

---

## Manual test checklist (pre-release)

Run on a clean Windows machine before tagging.

### Launch and lifecycle
- [ ] Installer on clean VM (no Python): completes, launches app
- [ ] First launch: green paw in tray, starts in <5s
- [ ] Subsequent launch: comparable startup, no regressions
- [ ] Single-instance: second copy blocked by mutex
- [ ] First-run welcome modal appears once, not on second launch
- [ ] Quit via tray: process exits cleanly
- [ ] In-place upgrade over v1.10: settings and custom critters preserved

### Settings
- [ ] All settings in all four tabs persist across quit/relaunch
- [ ] Corrupt settings.json: app launches with defaults, no crash
- [ ] v1 settings.json: loads cleanly, missing keys default-merged

### Built-in critters
- [ ] All 8 species spawn at default weights
- [ ] Per-species toggle, personality sliders take effect
- [ ] Click-to-pop, sound, drag-and-throw all work
- [ ] Ctrl+Shift+P pauses and resumes

### Custom critters
- [ ] Import PNG, JPG, GIF — preview appears, cancel writes nothing
- [ ] Import from frames
- [ ] Rename, adjust controls, delete
- [ ] Sound preview and upload
- [ ] v1 custom critters auto-migrate and spawn correctly

### Sharing
- [ ] Export → .critter written
- [ ] Re-import the same .critter → spawns correctly
- [ ] Drag-and-drop → confirm dialog → import works
- [ ] Bulk export → files in chosen folder
- [ ] Reject: path traversal, oversized zip, missing meta.json, bad extension, oversized wav

### Living world
- [ ] Each species visually recognisable from movement alone
- [ ] 15+ distinct behaviours over 30-minute idle session
- [ ] Pair interactions fire within ~80px
- [ ] Day/night: activity shifts across time buckets (test with clock override)
- [ ] behaviour_frequency=0: critters just walk, no behaviours
- [ ] interactions_enabled=false: no pair interactions
- [ ] CPU under 5% with 15 critters

### Rarity
- [ ] 100 spawns: tier counts roughly match distribution
- [ ] Each tier renders distinct aura
- [ ] rarity.enabled=false: v1-identical visuals
- [ ] Rare Hour doubles rare+ odds during window
- [ ] Seen Log records rare+ sightings
