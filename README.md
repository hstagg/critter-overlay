# Critter Overlay

Adorable cartoon animals that wander across your screen. Click them to pop them. Invisible when idle.

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
├── __main__.py           Bootstrapper: detects/builds venv, then launches the app
├── build.py              Packages everything into a single .pyzw zipapp
├── src/
│   ├── main.py           Entry point: tray icon, hotkeys, single-instance check
│   ├── config.py         JSON settings stored at %APPDATA%\CritterOverlay
│   ├── overlay.py        Pygame transparent window + render loop
│   ├── animals.py        8 built-in animal classes + particle system
│   ├── animals_custom.py CustomAnimal class — inherits Animal, overrides draw/hit_test
│   ├── spawn_manager.py  Weighted spawn pool (built-ins + custom critters)
│   ├── settings_window.py Tkinter settings UI (Animals, Custom, Spawning, Visuals, Audio, System)
│   ├── preview_renderer.py pygame→PIL animated preview frames for settings UI
│   ├── sounds.py         Procedural sound synthesis with deterministic per-critter seeding
│   └── custom_critters/
│       ├── registry.py   Runtime store of loaded custom critter frames + masks
│       ├── storage.py    Disk layout, meta.json I/O, ID generation
│       ├── import_pipeline.py  Full import flow: validate → bg remove → animate → mask → write
│       ├── bg_removal.py Corner flood-fill background removal for opaque images
│       ├── procedural.py Split-image walk-cycle generator (bob + lean + stride shear)
│       ├── masks.py      Alpha-mask generation and numpy dilation
│       └── palette.py    Dominant-colour extraction
├── requirements.txt      Runtime dependency reference (also hardcoded in __main__.py)
├── README.md
└── Archive/              Old builds + the legacy batch-file installer
```

### Running from source during development

```
pip install -r requirements.txt
python src/main.py
```

### Building a release

```
python build.py            # auto-bumps minor version
python build.py 2.0        # specific version
```

Output: `Critter Overlay v<version>.pyzw` in the project root. Old builds are auto-moved to `Archive/`.

The `.pyzw` is a Python [zipapp](https://docs.python.org/3/library/zipapp.html). On Windows the standard python.org installer associates `.pyzw` with `pythonw.exe`, so double-clicking runs it with no console window.

### How the bootstrapper works

`__main__.py` runs every time the .pyzw is launched. Two passes:

1. **Outside the venv** (sys.prefix != APPDATA\CritterOverlay\venv):
   - Probe whether `%APPDATA%\CritterOverlay\venv` exists and has the required packages.
   - If not, open a small Tk progress window, create the venv with `venv.EnvBuilder`, pip-install requirements quietly. The window self-closes when done.
   - Spawn a detached subprocess: the venv's `pythonw.exe` running this same .pyzw. Exit.

2. **Inside the venv** (the relaunch):
   - Add `<archive>/src` to sys.path (zipimport handles paths inside the .pyzw).
   - `from main import main; main()`.

Result: end users see a single double-clickable file. First launch shows the install window once. Every subsequent launch is silent.

---

## Animals

| Animal | Default weight | Speed |
|---|---|---|
| 🐱 Kitten | 3× | Medium-fast |
| 🐢 Turtle | 1× | Slow |
| 🦆 Duck | 1× | Medium |
| 🐰 Rabbit | 1× | Fast |
| 🦔 Hedgehog | 1× | Medium-slow |
| 🐿️ Squirrel | 1× | Fast |
| 🦦 Otter | 1× | Medium |
| 🐼 Panda | 1× | Slow-medium |

---

## Settings

Right-click the tray paw → Settings (or open from the auto-shown window on first launch). All changes save immediately to `%APPDATA%\CritterOverlay\settings.json`.

- **Animals** — toggle species on/off, adjust spawn weight.
- **Custom** — import your own PNG/JPG/GIF critters; manage, enable/disable, set weight and sound.
- **Spawning** — group spawn frequency and size, solo perimeter walker toggle.
- **Visuals** — animal size (80-200px), opacity, animation detail.
- **Audio** — master toggle, volume, per-animal sounds.
- **System** — auto-launch on startup, hotkey reference.

### Custom critters

Import any PNG, JPG, or animated GIF from Settings → Custom → Create. The app:
- Removes the background (works best for solid-colour backgrounds; transparent PNGs work perfectly)
- Generates a 4-frame walk animation automatically for static images
- Assigns a sound profile deterministically from the critter's name

Custom critters inherit all built-in behaviour: perimeter walking, idle pauses, drag, throw, pop, particle burst, sound. They live in `%APPDATA%\CritterOverlay\custom\` — each in a self-contained folder that can be backed up or deleted manually.

The "Spawn now" button triggers an immediate group spawn for testing.

---

## Troubleshooting

**Setup window says install failed.** Almost always a network issue — pip couldn't reach PyPI. Check connection and double-click again. The .pyzw is safe to relaunch; it'll resume from where it stopped.

**Tray hotkey (Ctrl+Shift+P) doesn't fire.** Some security software blocks global keyboard hooks. Run the .pyzw as administrator once to confirm.

**High CPU.** Settings → Visuals → Animation = "Simple". Reduce max animals per spawn in the Spawning tab.

**Magenta flash on screen.** Rare graphics glitch with the Win32 colour-key transparency layer. Quit and relaunch from the tray.

**Start fresh.** Delete `%APPDATA%\CritterOverlay\` (settings + venv) and double-click the .pyzw again — it'll reinstall cleanly.

---

## Technical notes

- **Transparency**: Win32 `SetLayeredWindowAttributes` with magenta `(255, 0, 255)` colour key. Magenta pixels are click-through, animal pixels are visible and clickable.
- **No taskbar entry**: `WS_EX_TOOLWINDOW` extended style.
- **Always on top**: `SetWindowPos(HWND_TOPMOST, ...)`.
- **Sounds**: Generated at runtime with numpy sine-wave synthesis — no audio files bundled.
- **Settings UI**: Tkinter in a daemon thread (dark mode, tabbed layout).
- **Single instance**: Windows named mutex.
