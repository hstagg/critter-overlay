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

## State of play (as of 2026-10-13)

- **Branch of record:** `main`. v3 (Godot 4) was merged into it in PR #7; the `v3` branch is retired.
- **Last release:** v2.0.0 (the Python app). v3.0 is not released yet.
- **The plan:** `docs/v3-launch-plan.md`. It holds the audit, the phases, the item table, the decisions, and the game design rules (G1). Work through it phase by phase; record new decisions there.
- **v1/v2:** the Python app, its build scripts and archive were removed from the tree. They are kept at tag `v2-final`.
- **Release pipeline:** `release.ps1`, a single command for the version bump, build, commit, push and GitHub release.

---

## How Claude should work on this project

### Plan before touching code

For any change beyond a single obvious bug fix, Claude proposes a plan first:
- Which files change and why
- What the approach is and whether alternatives were considered
- Any risks or things that need testing

Wait for go-ahead before writing code. The reason: this codebase has a lot of subtle Windows-specific behaviour (transparent click-through windows, the native layer, DPI and monitors, the Intel GL exit crash) where a plausible-looking change can break things in ways that only show up at runtime on Windows.

### One concern at a time

Don't refactor while fixing a bug. Don't fix adjacent issues while implementing a feature. Scope creep in a session always produces worse code than staying focused. If something adjacent is broken, note it and stop — don't fix it without being asked.

### Propose, don't assume

If the right approach is unclear, say so and give options with trade-offs. "I'll just do X" is less useful than "I see two approaches — here's the trade-off."

### Simplest thing that works

Minimum code that solves the problem. No features, options or abstractions nobody asked for; if 200 lines could be 50, rewrite it. (This and the next rule are adapted from forrestchang/andrej-karpathy-skills, MIT.)

### Define the check, then loop

Turn each task into something verifiable before starting: a failing test, a `--selftest` run, a measured frame time. Work until that check passes rather than until the code looks right.

### Design skill: store page and website only

`.claude/skills/design-taste-frontend/` (Leonxlnx/taste-skill, MIT, pinned at ce26fc2) is for the marketing site and store page. Do not apply it to the Godot app's own UI, and skip its image-generation steps. It is large (about 22k tokens), so invoke it only for web page work.

### The Admin page lands with every feature (v3)

The v3 app has a developer-only Admin page (`godot/admin.gd`, `godot/gui/admin_page.gd`): spawn anything, play every move, force pairs and events, and the audit checklist. It lives on `main` like everything else, but only the admin build carries it:

- `.\build-v3.ps1` builds the player installer (export preset "Windows Desktop"), which leaves both admin files out. Never ship anything else.
- `.\build-v3.ps1 -Admin` builds `CritterOverlaySetup-<version>-admin.exe` (preset "Windows Admin", feature tag `admin`) for the developer's own machine.
- From source: `godot --path godot -- --admin`. `--admin-run=ACTION` presses an audit Run button, for testing.
- Nothing outside those two files may preload them: `main.gd` loads `admin.gd` by path only if it exists, and `main.admin` is null in the player build.

**Rule:** a change that adds something the player can see or trigger also adds its Admin control and its audit check, in the same change. New species, versions, colours, moves, pairs and clothes appear on the page by themselves (it reads the game's own tables); a new kind of feature (a new event, a new screen, a new system) needs its own button in `admin.gd` and a line in `checks()` in `admin_page.gd`.

### Changes that require discussion first

Before implementing any of these, stop and discuss:
- Changing the distribution format (the Inno Setup installer)
- Adding a dependency: a new Godot version, a godot-cpp change, or any bundled third-party asset
- Changing the native layer (`native/`): single instance, autostart, presence or hotkeys
- Changing how settings or the economy save are stored or migrated (`godot/settings.gd`, `godot/economy.gd`)
- Anything that affects the update checker (`godot/updater.gd`)

---

## Build and run

```powershell
# Run from source (flags are listed at the top of godot/main.gd)
godot --path godot
godot --path godot -- --admin          # with the Admin page

# Headless tests (add -Native for native_test.gd, which needs the DLL)
.\run-tests.ps1

# Player installer, or the developer's admin installer
.\build-v3.ps1 -Version 3.0.1
.\build-v3.ps1 -Admin
# -SkipNative reuses the DLL already in godot\bin
```

Needs Godot 4.7 with its export templates (`GODOT` or on PATH), Inno Setup 6, and rcedit (`RCEDIT`, or `..\tools\rcedit-x64.exe`). Building the native DLL is described in `native/README.md`. The installer lands in `installer\output\`.

---

## Project structure

```
godot/                   The v3 game (Godot 4 project)
  main.gd                Entry point: windows, arrivals, the frame loop, flags
  species.gd             The species table (rarity caps, versions, idles, sounds)
  critters/              One rig script per species; critter.gd is the base,
                         two_head.gd the base for critters that sit facing you
  host.gd                One critter's window: drag, throw, edges, climbing
  behaviours.gd          Behaviour catalogue and evaluator
  pairs.gd               Pair interactions
  presence.gd            Away detection (native layer, else a PowerShell poller)
  economy.gd             Berries, luck, gifts, Rare Hour, rarity rolls, the save
  settings.gd            Settings defaults, load/save, the v2.0 import
  wear.gd, aura.gd       Clothes and rarity auras
  prop.gd, trail.gd      Showpieces (beds) and trails
  updater.gd             Update checker and one-click installer
  admin.gd               Admin page actions (admin build only)
  gui/                   Settings window and pages, tray, toasts, welcome,
                         Collection; admin_page.gd (admin build only)
  art/                   SVG rig parts per species, versions and clothes
  *_test.gd              Headless tests
native/                  CritterNative GDExtension (C++, Windows calls)
installer/               installer-v3.iss and the licence
design/                  Art pipelines (studio rounds, wear builder, GUI mock-ups)
tools/                   economy_sim.py and the soak harness (tools/soak/)
docs/                    Launch plan, soak report
```

---

## Code style

- Module docstrings (the `##` comments at the top of a file) explain the file's role and non-obvious design choices.
- **Drawing style (built-in critters):** warm dark-brown outlines, not pure black. Big expressive eyes. Rosy blush marks. Baby-face proportions.
- Settings defaults live in `DEFAULTS` in `godot/settings.gd`. Saved settings are merged over them on load; never clobber keys you don't recognise (forward-compatibility; `settings_test.gd` checks it).
- Single-instance guard: the native mutex `CritterOverlay.v3` — do not remove or rename it.

---

## Testing

`.\run-tests.ps1` runs the headless tests (`godot/*_test.gd`) except `native_test.gd` (`-Native` adds it; it needs the DLL). The Tests workflow (`.github/workflows/tests.yml`) runs the same on every push to `main` and every PR into it. A new `*_test.gd` is picked up by both without any change.

Heavy runs (soaks, stress) go on the test VM, not the developer's PC. Manual checklist for any non-trivial change:

1. Does the installed app start with no console window, and does the tray icon appear?
2. Do critters arrive and walk, and does clicking one pop it (with sound if enabled)?
3. Do drag and throw work?
4. Does the pause shortcut (Ctrl+Shift+P by default) toggle pause?
5. Do settings and progress persist across a full quit and relaunch?
6. Does a second launch exit while one copy is running?
7. For anything the player can see: does its Admin audit row pass?

---

## Release checklist

The full pipeline is automated by `release.ps1`. For any release:

```powershell
# Patch / hotfix
.\release.ps1 -Version 3.0.1 -Title "fix startup mutex lockout"

# Minor / major (write release notes first, then pass the file)
.\release.ps1 -Version 3.1.0 -Title "critter sharing" -NotesFile release-notes-v3.1.md

# Add -SkipNative to reuse the native DLL already in godot\bin
```

The script: validates inputs → checks the tag is new and git is clean on main → bumps `VERSION` in `godot/main.gd` and the exe version in `godot/export_presets.cfg` → runs `build-v3.ps1` (the player build) → refuses if the exe carries the Admin page → commits and pushes → creates the GitHub release with the installer attached.

A v3 release is also what v2.0 installs' update checker will offer, since both read the repo's latest GitHub release.

**Before running for a minor/major release:**
1. Update `README.md` with what changed
2. Write `release-notes-vX.Y.md` for the GitHub release body
3. Ensure manual test checklist passes (see Testing section above)

For patch releases, `--generate-notes` is used automatically (GitHub generates release notes from commits since the last tag).
