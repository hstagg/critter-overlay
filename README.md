# Critter Overlay

Adorable cartoon animals that wander across your screen. They have personalities, react to each other, slow down at night, and occasionally show up as rare glowing variants. Click them to pop them. Import your own.

---

## For end users

You need Python installed (any 3.8+ from [python.org](https://www.python.org/downloads/) — tick "Add Python to PATH" if installing fresh).

1. **Double-click `Critter Overlay v*.pyzw`.**
2. First launch only: a small dark window appears for 20-40s while it sets itself up. It closes on its own.
3. Critter Overlay opens. Done.

That's the entire install. No batch files, no folders to extract, nothing to configure. Every subsequent launch is silent.

The app installs into an isolated environment at `%APPDATA%\CritterOverlay\venv` so it doesn't touch your system Python or any other projects. To uninstall completely, delete that folder and the .pyzw file.

### Keyboard shortcuts

| Shortcut | Action |
|---|---|
| `Ctrl+Shift+P` | Pause / resume spawning |

Right-click the paw icon in the system tray for Settings, Spawn Now, Pause/Resume, Quit.

---

## For the developer

### Project layout

```
Critter Overlay App/
├── __main__.py              Bootstrapper: detects/builds venv, then launches the app
├── src/
│   ├── main.py              Entry point: tray icon, hotkeys, single-instance check
│   ├── config.py            JSON settings stored at %APPDATA%\CritterOverlay
│   ├── overlay.py           Pygame transparent window + render loop + DROPFILE handler
│   ├── events.py            Thread-safe event dispatch (pause, config, spawn, file-drop)
│   ├── animals.py           8 built-in animal classes + particle system + aura hook
│   ├── animals_custom.py    CustomAnimal class — locomotion, rarity, aura
│   ├── spawn_manager.py     Weighted spawn pool, rarity tier rolls, behaviour triggers
│   ├── rarity.py            Tier enum, distribution roll, per-tier modifier dataclass
│   ├── auras.py             4 aura render functions (uncommon → legendary)
│   ├── locomotion.py        9 locomotion profiles (classic, hop, dart, waddle, ...)
│   ├── behaviours.py        40+ named behaviours with trigger logic
│   ├── time_of_day.py       Day/night activity scalar (6 time buckets)
│   ├── settings_window.py   Tkinter settings UI (4 tabs: Critters, Behaviour, Audio, System)
│   ├── preview_renderer.py  pygame→PIL animated preview frames for settings UI
│   ├── sounds.py            Procedural sound synthesis, 14 preset profiles
│   └── custom_critters/
│       ├── registry.py      Runtime store of loaded custom critter frames + masks
│       ├── storage.py       Disk layout, meta.json v2 I/O, ID generation, migration
│       ├── import_pipeline.py  Import flow: validate → bg remove → animate → mask → write
│       ├── sharing.py       .critter zip export / import / validation / bulk export
│       ├── bg_removal.py    Corner flood-fill background removal
│       ├── procedural.py    Walk-cycle generator (bob + lean + stride shear)
│       ├── masks.py         Alpha-mask generation and numpy dilation
│       └── palette.py       Dominant-colour extraction
├── requirements.txt
├── README.md
└── Archive/                 Old builds
```

### Running from source

```
pip install -r requirements.txt
python src/main.py
```

### Building a release

```
.\release.ps1 -Version 2.0.0 -Title "a living desktop" -NotesFile release-notes-v2.0.md
```

The script: validates inputs → checks git is clean on main → bumps `src/version.py` → builds the installer → commits, pushes, creates the GitHub release.

---

## Animals

| Animal | Default weight | Locomotion | Rarity cap |
|---|---|---|---|
| 🐱 Kitten | 3× | pounce-pause | legendary |
| 🐢 Turtle | 1× | plod | epic |
| 🦆 Duck | 1× | waddle | legendary |
| 🐰 Rabbit | 1× | hop | legendary |
| 🦔 Hedgehog | 1× | snuffle | legendary |
| 🐿️ Squirrel | 1× | dart-freeze | legendary |
| 🦦 Otter | 1× | slide | legendary |
| 🐼 Panda | 1× | lumber | epic |

---

## Living world

Each species moves with a characteristic locomotion profile. The kitten punctuates walks with pounce-pauses; the rabbit hops in arcs; the otter occasionally belly-slides; the squirrel darts and freezes. You can tell the species apart from movement alone with your eyes half-closed.

**Behaviours** fire based on state and proximity: napping, grooming, playing, pair-interactions (sniffing, following, near-miss chases, splashing). Over a 30-minute session, 15+ distinct behaviours will fire without any input.

**Day/night cycle** reads the system clock. Activity, spawn rate, and idle bias shift across six time buckets. No visual changes — no tint, no colour shift — just pace and frequency.

All three systems have on/off toggles in Settings → Behaviour. Setting `behaviour_frequency` to 0 reduces critters to pure locomotion.

---

## Rarity

Every critter that spawns is assigned a rarity tier:

| Tier | Default odds | Visual |
|---|---|---|
| Common | 90% | no aura |
| Uncommon | 7% | soft shimmer |
| Rare | 2% | glowing outline |
| Epic | 0.9% | pulsing halo |
| Legendary | 0.1% | full corona |

**Rare hour** (default 9 PM–10 PM) doubles rare+ odds. **First spawn of the day** also gets a boosted roll. Both can be configured or disabled.

Per-species `rarity_min` / `rarity_max` constrain the range — turtles and pandas cap at epic by default. The Seen Log in Settings → System records every rare+ sighting.

---

## .critter sharing

Custom critters can be exported and shared as `.critter` files — standard ZIPs with a defined layout:

```
mycritter.critter
├── meta.json       name, author, license, personality settings
├── manifest.json   content hash, min app version
├── frames/         frame_0.png ... frame_N.png
├── masks/          (optional — regenerated on import if absent)
├── sounds/         (optional)
├── source/         (optional — original image for re-import)
└── thumb.png       (optional)
```

**Export** — Settings → Critters → Export button on any custom critter card, or "Export all" to write everything to a folder at once.

**Import** — Settings → Critters → "Import .critter", or drag-and-drop a `.critter` file directly onto the overlay window. A confirm dialog shows the name, author, and license before anything is written to disk.

**Validation** — packages are checked before extraction: size ≤ 50 MB, file count ≤ 100, per-file ≤ 10 MB, allowed extensions only (`.png .json .wav .txt .md`), no path traversal, frame dimensions within 10% of declared size, `.wav` files ≤ 2 MB.

---

## Settings

Right-click the tray paw → Settings. All changes save immediately.

- **Critters** — built-in species (toggle, spawn weight, personality) and custom critters (inline controls: size, speed, activity level, animation trail, sound) in one scrollable list. Import and export from the top button row.
- **Behaviour** — spawning frequency and group size; living world toggles (day/night, behaviour frequency, pair interactions); rarity distribution, rare hour, and first-spawn-of-day bonus.
- **Audio** — master toggle, volume, and per-species sound toggle with preview button.
- **System** — auto-launch on startup, hotkey reference, Seen Log (all rare+ sightings colour-coded by tier).

### Custom critters

Three import modes in Settings → Critters:

**Import image** — single PNG, JPG, or animated GIF. Background is removed automatically (transparent PNGs used as-is). A preview of the processed critter appears before anything is written to disk — accept or cancel.

**Import frames** — 2–8 hand-drawn PNG frames in walk-cycle order. Frames are used directly.

**Import .critter** — install a shared `.critter` package. Confirm dialog shows metadata before install.

Per-critter controls are always visible on each card:
- **Size** — tiny / small / normal / large / huge
- **Speed** — snail / slow / average / fast / rapid / supersonic
- **Activity level** — narcoleptic / sleepy / lazy / normal / active / wired
- **Animation trail** — none / dots / stars / sparkles / bubbles / glitter / hearts
- **Sound** — choose from 14 preset profiles or upload a `.wav`; preview with ▶

Custom critters inherit all built-in behaviour: elastic collision, perimeter walking, idle pauses, drag, throw, pop, particle burst, sound, rarity auras, day/night scaling. They live in `%APPDATA%\CritterOverlay\custom\`.

### Critter physics

All critters interact physically. Elastic equal-mass collisions — throw one at a group and they scatter. A thrown critter that hits another transfers momentum; the hit critter coasts before resuming normal walking.

---

## Upgrading from v1

Settings and custom critters from v1 are preserved automatically. The v2 config loader deep-merges with new defaults so no existing keys are overwritten. v1 custom critters auto-migrate to schema v2 in memory on first load; the folder on disk is only updated when you next change a setting for that critter.

The first-run welcome modal fires once on upgrade (because `first_run_completed` was absent in v1 configs) and not again.

---

## Troubleshooting

**Setup window says install failed.** Almost always a network issue — pip couldn't reach PyPI. Check connection and double-click again. The .pyzw is safe to relaunch.

**Tray hotkey (Ctrl+Shift+P) doesn't fire.** Some security software blocks global keyboard hooks. Run as administrator once to confirm.

**High CPU.** Settings → Behaviour → set behaviour frequency lower. Reduce max animals per spawn.

**Magenta flash on screen.** Rare graphics glitch with the Win32 colour-key transparency layer. Quit and relaunch.

**Start fresh.** Delete `%APPDATA%\CritterOverlay\` and relaunch — reinstalls cleanly, all settings reset.

---

## Technical notes

- **Transparency**: Win32 `SetLayeredWindowAttributes` with magenta `(255, 0, 255)` colour key. Magenta pixels are click-through; animal pixels are visible and clickable.
- **No taskbar entry**: `WS_EX_TOOLWINDOW` extended style.
- **Always on top**: `SetWindowPos(HWND_TOPMOST, ...)`.
- **Sounds**: 14 pre-generated WAV profiles bundled with the installer. Numpy synthesis fallback when running from source.
- **Settings UI**: Tkinter in a daemon thread, sv-ttk dark theme, 4-tab layout.
- **Single instance**: Windows named mutex `CritterOverlayMutex_v1`.
- **Config**: JSON at `%APPDATA%\CritterOverlay\settings.json`. Deep-merged with defaults on load; unknown keys preserved.
- **Custom critter storage**: `%APPDATA%\CritterOverlay\custom\<slug>-<hash6>\` — self-contained folders, safe to back up or delete manually.
