# CritterOverlay — CLAUDE.md

This file governs how Claude works on this codebase. It is NOT a README.
Public repo: **github.com/hstagg/critter-overlay** — treat every file in this directory as potentially visible to anyone.

The Second Brain vault CLAUDE.md may also be loaded (Claude Code merges up the tree). Vault rules do not apply here: no propagation protocol, no living-file updates, no Profile observations, no session files, no wiki-links. Vault rules resume outside this folder.

---

## Public repo discipline

This repo is public. Before committing anything, ask: "Could this embarrass the project or reveal something personal?"

**Never commit:**
- Real names of people (friends, family, recipients) — use neutral descriptions if needed
- References to who the app was made for or given to
- Second Brain vault conventions: wiki-links (`[[...]]`), YAML frontmatter with `tldr:`, `type:` fields
- Personal paths, usernames beyond `hstagg`, account details
- Harrison's location, university, or life situation

**CLAUDE.md itself:** this file is safe to commit (no personal info). Whether to do so is Harrison's call — it's standard practice for Claude Code projects.

---

## State of play (as of 2026-05-23)

- **Current branch:** `main` — this is where active development lives
- **Last release:** v1.9.1 — fix custom critter import in .exe bundle (numpy excluded from PyInstaller by mistake)
- **Uncommitted changes:** none
- **Next planning doc:** `v1.10.0 Dev Handoff.md`
- **Release pipeline:** `release.ps1` — single command handles version bump, build, commit, push, and GitHub release creation

---

## How Claude should work on this project

### Plan before touching code

For any change beyond a single obvious bug fix, Claude proposes a plan first:
- Which files change and why
- What the approach is and whether alternatives were considered
- Any risks or things that need testing

Wait for go-ahead before writing code. The reason: this codebase has a lot of subtle Windows-specific behaviour (pygame overlay, pystray, chroma-key, venv bootstrap) where a plausible-looking change can break things in ways that only show up at runtime on Windows.

### One concern at a time

Don't refactor while fixing a bug. Don't fix adjacent issues while implementing a feature. Scope creep in a session always produces worse code than staying focused. If something adjacent is broken, note it and stop — don't fix it without being asked.

### Propose, don't assume

If the right approach is unclear, say so and give options with trade-offs. "I'll just do X" is less useful than "I see two approaches — here's the trade-off."

### Changes that require discussion first

Before implementing any of these, stop and discuss:
- Changing the distribution format (`.pyzw` → `.exe`, etc.)
- Adding new dependencies to `requirements.txt`
- Changing the venv bootstrap logic in `__main__.py`
- Changing how config is stored or migrated
- Anything that affects the update checker (`src/updater.py`)
- Changes to the chroma-key colour `(255, 0, 255)` — this is the transparency key, changing it breaks all existing sprite assets

---

## Build and run

```bat
# Run in development (console visible — useful for print debugging)
python src\main.py

# Run as end-users see it (no console window)
run.bat

# Install deps
pip install -r requirements.txt        # or: setup.bat

# Build .pyzw zipapp (auto-bumps minor version)
python scripts\build.py                # or: build.bat
python scripts\build.py 2.0            # explicit version

# Package for distribution
python scripts\make_zip.py
```

Build output lands in the project root as `Critter Overlay v<N>.<N>.pyzw`. Previous builds move to `Archive/`.

---

## Project structure

```
__main__.py              Zipapp bootstrapper — builds venv on first launch
src/
  main.py                Entry point; tray icon, settings window, spawn loop
  animals.py             Built-in animal drawing (pygame, procedural vector art)
  animals_custom.py      Custom animal rendering
  animal_previews.py     Animated preview sprites for settings window
  config.py              Settings — JSON in %APPDATA%\CritterOverlay\
  overlay.py             Transparent overlay window (pygame, click-through)
  spawn_manager.py       Animal spawn timing and group logic
  settings_window.py     Settings UI (tkinter)
  sounds.py              Sound playback per animal
  preview_renderer.py    Preview rendering for settings
  updater.py             In-app update checker
  version.py             APP_VERSION string (bump here on release)
  custom_critters/       Custom critter import pipeline
    import_pipeline.py   Full import flow
    bg_removal.py        Background removal for uploaded images
    masks.py             Sprite mask generation
    procedural.py        Procedural walk animation from still images
    palette.py           Colour extraction and remapping
    registry.py          Custom critter registry
    storage.py           File storage for critter assets
scripts/
  build.py               Builds the .pyzw
  make_zip.py            Packages .pyzw into distribution zip
  build_previews.py      Regenerates animal preview sprites
  build_sounds.py        Processes sound assets
  make_icon.py           Generates app icon
  split_sprites.py       Splits sprite sheets
```

---

## Code style

- PEP 8. Type hints where they add real clarity — not required everywhere.
- Module docstrings explain the file's role and non-obvious design choices.
- **Colour rule:** never use exactly `(255, 0, 255)` anywhere. That is the chroma-key background — it becomes transparent in the overlay window. Use `(254, 0, 255)` or similar if you need near-magenta for any reason.
- **Drawing style (built-in animals):** warm dark-brown outlines `OUTLINE = (48, 32, 24)`, not pure black. Big expressive eyes with sclera → iris → pupil → shine layers. Rosy blush marks. Baby-face proportions.
- Config defaults in `DEFAULT_CONFIG` in `config.py`. Always merge with user config on load; never clobber keys you don't recognise (forward-compatibility).
- Single-instance guard via Windows mutex `CritterOverlayMutex_v1` — do not remove or rename this.

---

## Testing

No automated test suite. Manual testing checklist for any non-trivial change:

1. Does the app launch without a console window (`run.bat`)?
2. Does the tray icon appear (green paw)?
3. Do animals spawn and walk across the screen?
4. Does clicking an animal pop it (with sound if enabled)?
5. Does `Ctrl+Shift+P` toggle pause?
6. Do settings persist across a full quit-and-relaunch?
7. If you changed the custom critter pipeline: import a PNG, check it spawns and animates.
8. Does the app refuse to open a second instance (mutex check)?

For changes to `__main__.py` or the venv bootstrap: test on a machine where the venv doesn't yet exist (or delete `%APPDATA%\CritterOverlay\venv` to simulate first launch).

---

## Release checklist

The full pipeline is automated by `release.ps1`. For any release:

```powershell
# Patch / hotfix
.\release.ps1 -Version 1.9.1 -Title "fix startup mutex lockout"

# Minor / major (write release notes first, then pass the file)
.\release.ps1 -Version 2.0.0 -Title "critter sharing" -NotesFile release-notes-v2.0.md
```

The script: validates inputs → checks git is clean on main → bumps `src/version.py` and `installer/version_info.txt` → runs `build.ps1` → commits and pushes → creates the GitHub release with the installer attached.

**Before running for a minor/major release:**
1. Update `README.md` with what changed
2. Write `release-notes-vX.Y.md` for the GitHub release body
3. Ensure manual test checklist passes (see Testing section above)

For patch releases, `--generate-notes` is used automatically (GitHub generates release notes from commits since the last tag).
