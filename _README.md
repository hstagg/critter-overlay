---
type: project-readme
project: Critter Overlay App
status: Active development — personal project, gift for Jasmine, no commercial intent.
created: 2026-04-26
last_updated: 2026-05-02
tldr: Desktop pet app — cartoon animals wander across the screen, click to pop. Personal project, gift for Jasmine. Active development, no commercial intent.
---

# Critter Overlay App

A Windows desktop companion: cartoon animals wander across the screen at random. Click to pop them. Invisible when idle. Tray icon for settings, pause, and quit.

Built originally as a gift for [[Jasmine Poon]].

## Current state

- **Build:** v1.6 complete and packaged (`CritterOverlay_v1.6.zip`).
- **Distribution:** Not distributed commercially.
- **Gifted copies:** Jasmine has a copy.

## Files

| File / Folder | What it is |
|---|---|
| `README.md` | Developer and end-user documentation — install, keyboard shortcuts, project layout, build instructions. |
| `__main__.py` | Bootstrapper — detects/builds venv, installs deps, launches app. |
| `src/` | Full application source (8 modules: main, config, overlay, animals, spawn_manager, settings_window, animal_previews, sounds). |
| `build.py` | Packages everything into a single `.pyzw` zipapp. |
| `build.spec`, `make_zip.py` | Supporting build tooling. |
| `requirements.txt` | Runtime dependency reference. |
| `Sprite Images/` | Animal sprite sheets — one per critter in the 4-frame grid documented in `AI Art Prompts.md`. |
| `AI Art Prompts.md` | Generation prompts for new animal sprites. Upload reference images alongside each prompt. |
| `Critter Overlay v1.0.pyzw` | v1.0 release archive. |
| `CritterOverlay_v1.6.zip` | v1.6 release — current. |
| `Archive/` | Legacy batch-file installer approach. Superseded by the .pyzw bootstrapper. |

## Workflow when returning

1. To add a new animal: generate a 4-frame sprite sheet via `AI Art Prompts.md`, add to `Sprite Images/`, wire into `animals.py`.
2. To build a new release: `python build.py` → produces a new `.pyzw`.
