---
type: project-readme
project: Critter Overlay App
status: Active development — personal project, gift for Jasmine, no commercial intent.
created: 2026-04-26
last_updated: 2026-05-18
tldr: Desktop pet app — cartoon animals wander across the screen, click to pop. Personal project, gift for Jasmine. v1.8 shipped with offline custom critters.
---

# Critter Overlay App

A Windows desktop companion: cartoon animals wander across the screen at random. Click to pop them. Invisible when idle. Tray icon for settings, pause, and quit.

Built originally as a gift for [[Jasmine Poon]].

## Current state

- **Build:** v1.8 complete and merged to `main`. Source ready; not yet packaged to zip.
- **Distribution:** Not distributed commercially.
- **Gifted copies:** Jasmine has a copy (v1.6-era).
- **Repo:** `hstagg/critter-overlay` on GitHub.

### What shipped in v1.8

- Offline custom critters: import PNG/JPG/GIF via Settings → Custom tab
- Background removal (corner flood-fill) for opaque images; alpha threshold to kill chroma-key fringe
- 4-frame procedural walk animation: split-image leg simulation (bob + lean + bottom-half horizontal shear)
- Per-pixel alpha mask hit detection; drag/throw/pop/sound all inherited
- Deterministic per-critter sound seeding (stored in meta.json)
- Animated 96×96 species previews in Animals and Audio tabs
- Bug fixes bundled into v1.8: scroll overscroll, Animals page layout, preview clipping, scroll-on-page-switch reliability

### v1.9 candidates (see handoff doc)

- Custom critter animation quality — needs brainstorm; split-image is good enough but not great
- Better background removal (rembg or smart matting) for photos with non-uniform backgrounds
- Trail style picker per critter
- Movement personality presets
- Drawing canvas
- Custom critter sharing (export/import zip)

## Files

| File / Folder | What it is |
|---|---|
| `README.md` | Developer and end-user documentation — install, keyboard shortcuts, project layout, build instructions. |
| `__main__.py` | Bootstrapper — detects/builds venv, installs deps, launches app. |
| `src/` | Full application source. See README.md for module list. |
| `src/custom_critters/` | Custom critter pipeline: storage, registry, import, bg removal, masks, palette, procedural animation. |
| `build.py` | Packages everything into a single `.pyzw` zipapp. |
| `build.spec`, `make_zip.py` | Supporting build tooling. |
| `requirements.txt` | Runtime dependency reference. |
| `Sprite Images/` | Animal sprite sheets — one per critter in the 4-frame grid documented in `AI Art Prompts.md`. |
| `AI Art Prompts.md` | Generation prompts for new animal sprites. Upload reference images alongside each prompt. |
| `v1.8-v1.9 Dev Handoff.md` | What shipped in v1.8, open bugs, v1.9 scope, implementation order. |
| `Archive/` | Legacy builds and old installer approach. |

## Workflow when returning

1. To add a new built-in animal: generate a 4-frame sprite sheet via `AI Art Prompts.md`, add to `Sprite Images/`, wire into `animals.py`.
2. To work on custom critters pipeline: source is in `src/custom_critters/`. Entry point is `import_pipeline.py`.
3. To build a new release: `python build.py` → produces a new `.pyzw`. Then zip and archive.
