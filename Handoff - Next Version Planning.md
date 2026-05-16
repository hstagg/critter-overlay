# Critter Overlay — Planning Handoff
**For:** External critique and planning cycles across multiple models  
**Purpose:** Complete context for evaluating the next version of the app — a proper Windows installer and custom user-created critters. This document stands alone; no prior context assumed.

---

## What the app is

A Windows desktop companion app. Cartoon animals periodically appear on screen, wander around, and vanish. The user can click to pop them (particle burst + sound), drag and throw them off-screen, or just ignore them. It is invisible when idle — no window, no taskbar entry. It lives in the system tray.

Built as a personal gift, currently in active use. No commercial release yet. v1.6 is the current build.

---

## Current technical architecture

### Deployment: zipapp bootstrapper

The app ships as a single `.pyzw` file (Python zipapp). Double-clicking it triggers `__main__.py`, which:

1. Checks whether `%APPDATA%\CritterOverlay\venv` exists with all required packages.
2. If not: opens a small Tk progress window and pip-installs everything into an isolated venv. Window closes automatically when done.
3. Re-launches itself using the venv's `pythonw.exe` (no console window). Exits.
4. On the second run (inside the venv): adds the bundled `src/` to sys.path and calls `main.main()`.

Result: single double-clickable file, no Python install required if the user already has it, silent after first-run setup.

**Limitation:** The user must have Python 3.8+ installed and in PATH. This is the primary UX friction point being addressed by the installer proposal.

**Runtime dependencies (all pip-installable):**
- `pygame` — render loop, window, input
- `pillow` — tray icon image generation
- `pystray` — Windows system tray
- `keyboard` — global hotkey (`Ctrl+Shift+P`)
- `numpy` — procedural sound synthesis

---

### Window and transparency: overlay.py

The core technical trick. A full-screen borderless pygame window sits above every other window. Transparency is achieved via Win32:

- `WS_EX_LAYERED` + `SetLayeredWindowAttributes` with colour key `(255, 0, 255)` (magenta).
- The pygame surface is filled entirely with magenta at the start of each frame. Windows treats magenta pixels as transparent and click-through.
- Animal pixels (non-magenta) are visible and receive mouse events.
- `WS_EX_TOOLWINDOW` removes the taskbar entry.
- `SetWindowPos(HWND_TOPMOST)` keeps it above everything.

**Click-through logic:** magenta = Windows passes the click to the app below. Non-magenta = this window catches it. This is handled at the OS level, not in pygame.

**Clickbox (hit detection):** Every animal uses a circular hit radius (`hit_radius = size * 0.46`). This is a single `math.hypot` distance check. It is an approximation — for round-ish creatures it works well. For elongated shapes (otter, unicorn) there is slight mismatch between the visible sprite and the click target.

**Render loop:** 60 FPS target. Each frame: fill magenta → draw trail particles → draw animals → draw pop particles → draw notifications → `pygame.display.flip()`. No alpha blending (incompatible with chroma key). Transparency is achieved only by colour substitution.

---

### Animals: animals.py

**Base Animal class** handles:
- Position, velocity, direction (facing left/right)
- State machine: `WALKING`, `IDLE`, `TURNING`, `POPPING`
- Two movement modes:
  - **Free roaming** (`_update_free`): bounces off screen edges, mild collision avoidance with other animals, random idle pauses
  - **Perimeter walking** (`_update_perimeter`): follows the four screen edges in a loop, pausing at corners
- Walk animation: `walk_phase` accumulates based on speed; used to drive leg bob (`sin(walk_phase * 2)`) and head bob
- Blink: `sin(anim_t * 0.85 + blink_offset) > 0.96` — each animal has a random phase offset so they don't blink in sync
- Drag physics: position locked to mouse while held, history of last 250ms of mouse positions used to estimate throw velocity on release
- Throw physics: ballistic arc with gravity (520 px/s²), drag (30%/s), spin angle proportional to horizontal velocity; animal removed when off-screen
- Trail system: `LEAVES_TRAIL`, `TRAIL_PALETTE`, `TRAIL_RATE`, `TRAIL_SIZE`, `TRAIL_LIFE`, `TRAIL_STAR` — class-level flags; `emit_trail()` returns `TrailParticle` objects per frame. Currently only Unicorn and GoldenKitten use trails.
- Pop: spawns 10–16 `Particle` objects in species-specific colours, plays species sound

**All 8 standard animals are procedurally drawn** using pygame primitives (ellipses, circles, polygons, arcs, lines). No sprite sheets. The design language:

- Warm dark-brown outlines (not pure black) on every shape
- Large expressive eyes: sclera → iris → pupil → twin highlight dots
- Rosy blush ovals on cheeks
- Big heads relative to bodies (baby-face proportions)
- Magenta `(255, 0, 255)` is explicitly avoided in all colour definitions

| Animal | Speed | Notes |
|---|---|---|
| Kitten | 52px/s | Default weight 3× (most common). Tail wag, forehead stripes, whiskers. |
| Turtle | 28px/s | Hex shell pattern, protruding head/neck. |
| Duck | 46px/s | Fluffy body, feather arc detail, triangle beak. |
| Rabbit | 62px/s | Tall ears with pink inner, hop added to bob. |
| Hedgehog | 38px/s | 12 spike lines on upper body. |
| Squirrel | 65px/s | Large fluffy tail with wave animation, chubby cheek pouches. |
| Otter | 55px/s | Elongated body, whiskers. |
| Panda | 34px/s | Black eye patches over white face, black arms/legs. |

**Two rare animals:**

| Animal | Rarity | Special |
|---|---|---|
| Unicorn | 1/100 per individual spawn | Rainbow mane/tail (6-strand sinusoidal wave), horn sparkle, star-shaped rainbow trail at 22 particles/sec |
| Golden Kitten | 1/1000 per individual spawn | Golden palette Kitten + crown with gem + 4 orbiting sparkles + gold trail |

---

### Spawn manager: spawn_manager.py

Two spawn modes, timed independently:

1. **Group spawn** (default every 5 min ±15%): picks a base species by weighted random, spawns 5–10 individuals. Each individual independently rolls for rare species (1/100 unicorn, 1/1000 golden kitten) before defaulting to the group species.
2. **Solo perimeter walker** (default every 10 min ±15%): spawns one animal at a random screen edge, walks the perimeter. Rares spawn as free-roamers instead (so their trail is more visible).

First spawn fires 30 seconds after launch. Pause freezes both countdown timers. Config changes (interval, count, enabled species) apply immediately.

---

### Config: config.py

JSON stored at `%APPDATA%\CritterOverlay\settings.json`. Loaded at startup and deep-merged with `DEFAULT_CONFIG` so new fields added in updates are always present. Settings window saves immediately on change; overlay and spawn manager call `apply_config()` to pick up changes without restart.

Config sections: `animals` (per-species enabled/weight/sound), `spawn` (intervals, counts, solo toggle), `visual` (size 80–200px, opacity 50–100%, animation detail), `audio` (master toggle, volume 0–100), `system` (auto-launch, hotkey).

---

### Settings window: settings_window.py

Tkinter window (proper app window — shows in taskbar, unlike the overlay). Dark mode, tabbed layout. Tabs: Animals, Spawning, Visuals, Audio, System. Changes save to disk immediately. Has a "Spawn now" button for testing and a pause toggle. Can be minimised; reopened from tray or taskbar.

---

### Sounds: sounds.py

All sounds generated at runtime using numpy sine-wave synthesis. No audio files bundled. Sounds are generated once at startup (and on volume change) and cached as pygame Sound objects.

Each species has a handcrafted generator using combinations of: frequency sweep, FM synthesis, ADSR envelope, noise texture, harmonic stacking. Examples:
- Kitten: falling 900→550Hz sweep with soft envelope
- Duck: FM burst (carrier 450Hz, mod 80Hz, depth 4.0)
- Unicorn: stacked harmonic chime with tremolo, upward sweep 880→1200Hz
- Golden Kitten: kitten sweep + bell harmonics at 2200Hz and 3300Hz

---

## What is being proposed for the next version

### Proposal 1: Proper Windows installer

Replace the `.pyzw` bootstrapper with:

1. **PyInstaller** — bundles the Python interpreter, all dependencies, and all source into a standalone `.exe`. No Python installation required on the target machine. Bundle size estimate: 30–60 MB.
2. **Inno Setup** — wraps the PyInstaller output into a standard Windows installer wizard (Next/Next/Install). Creates: Program Files entry, Start Menu shortcut, desktop shortcut, Add/Remove Programs uninstall registration.

End result: user downloads `CritterOverlaySetup.exe`, runs it, done. Industry-standard experience.

**Open questions for critique:**
- PyInstaller + pygame has known edge cases (SDL DLL path issues, hidden imports). What is the most reliable build configuration?
- Should the installer update in-place or require uninstall-then-reinstall?
- How should custom critter data (see Proposal 2) be preserved across updates?

---

### Proposal 2: Custom critters

Allow users to create their own critters. The core flow:

1. User draws or uploads an image in-app.
2. The app generates animated walk-cycle frames.
3. The custom critter is registered and behaves identically to built-ins (walks, pops, trail, sound).

**The draw-yourself path:** An in-app drawing canvas — basic brush, eraser, fill, colour picker. User draws their character, then hits "Animate". Clean cartoon art (high contrast, clear silhouette) is expected to animate better than photos.

**The upload path:** User uploads a PNG, JPG, or animated GIF. If animated GIF, frames are extracted directly. If static, animation is generated.

**Animation generation — three candidate approaches:**

**A. Procedural animation (no AI, fully offline)**
Take the uploaded static image, remove background (e.g. `rembg` library, runs locally, ~5s), then apply per-frame transforms:
- Frame 1: neutral
- Frame 2: slight forward lean, front limbs down
- Frame 3: slight compression (squash)
- Frame 4: slight backward lean, back limbs down

Plus walk bob, blink overlay, optional tail append. Produces a "hopping along" feel rather than a true walk cycle. Works well for blobs, round cartoon characters. Less convincing for articulated humanoids. Fully offline, no cost, no API keys.

**B. AI animation via external API (cloud, cost per use)**
Send the static image to a video generation API (Runway Gen-4 Turbo, Kling, etc.). Receive a 2–3 second video clip. Extract 4–8 frames from the video. Stitch into a sprite sheet. Store locally.

Current API costs:
- Runway Gen-4 Turbo: ~$0.05/second → ~$0.10–0.15 per generation (~10–12p)
- AnimateDiff via Replicate: ~$0.07–0.10 per run (~6–8p)
- Kling 2.6 Pro: ~$0.07–0.10 per short clip

The AI option requires: internet at design time, a thin backend (serverless function — AWS Lambda, Vercel, Cloudflare Workers) to hold the API key (it cannot be embedded in the client), and a payment flow if the feature is monetised.

**C. Accept animated GIFs directly (no generation at all)**
If the user supplies an animated GIF, extract frames with Pillow. Zero cost, zero AI, immediate. Quality is entirely dependent on what the user provides. Could be the primary path for technically capable users.

**Monetisation angle:** Charge a one-time unlock fee (~50p–£1) per custom critter slot. At 50p and Stripe European card fees (~1.4% + 20p flat), the net after fees is ~29p, leaving ~17p margin after AI cost. At £1, net after Stripe is ~77p, leaving ~65p after AI cost. Bundle pricing (e.g. 3 critters for £1.49) improves unit economics significantly.

---

## Open questions for critique

The following are the specific design questions where outside analysis is most useful. Current testers are satisfied with the existing quality level; the question is whether the new features can meet or exceed that bar.

### Animation quality: is AI actually needed?

The current 8 animals are procedurally animated (no sprite frames at all — they are drawn fresh each frame with pygame). Users find them charming. The question for custom critters is whether procedural deformation of a static image (Option A) produces output that feels consistent with the existing critters, or whether the quality gap would be jarring.

Key factors:
- The current critters are vector-style with deliberate cartoon proportions. An uploaded photo or realistic image would look different regardless of animation method.
- Procedural deformation (squash/stretch, lean, bob) is the same motion language the current critters use. It may map naturally.
- AI video generation produces more organic, character-specific motion but introduces latency, cost, and a cloud dependency.
- A hybrid is possible: procedural as the default, AI as an optional paid enhancement.

### Clickbox accuracy for custom shapes

The current circular hit radius (`size * 0.46`) is appropriate for the round-ish built-in animals. For custom uploads that might be elongated, irregular, or have large transparent regions, a circle is a poor fit.

Options:
- Keep the circle. Simple, consistent, predictable.
- Generate a bounding polygon from the non-transparent pixels at upload time (convex hull or simplified polygon via OpenCV). Store alongside the sprite. More accurate but adds complexity and could produce weird shapes.
- Use a per-frame alpha mask test (check if the clicked pixel is non-transparent). Accurate but requires the surface to be queryable, which conflicts with the current chroma-key architecture where transparency is done at the OS level.

The alpha mask approach is the most accurate but requires architectural change: instead of filling magenta and relying on the OS colour key, the overlay would need to maintain a pixel-accurate mask in memory and manually decide whether to pass events. This is non-trivial.

### Trail effects for custom critters

Currently, trail emission is a class-level flag (`LEAVES_TRAIL`, `TRAIL_PALETTE` etc.) defined per species. For custom critters, options are:
- No trail (simplest — custom critters behave like standard ones)
- Fixed trail using a palette sampled from the critter's dominant colours (automatic, no user input)
- User selects a trail style in the custom critter editor (star, dot, heart, etc.) and a colour

The dominant-colour sampling approach is technically straightforward with Pillow (`image.getcolors()` after quantising) and would make custom critters feel personalised without requiring explicit UI choices.

### Sound for custom critters

Currently each species has a handcrafted procedural sound. Options for custom critters:
- Assign a random sound from the existing library at creation time
- Let the user pick from the 8 existing sound profiles
- Generate a new procedural sound by randomising the synthesis parameters (carrier frequency, sweep range, FM depth, envelope shape) within ranges known to produce "cute" results
- The drawn character's shape or colour could seed the random parameters (e.g. rounder shapes → lower frequency; brighter colours → higher pitch). This is aesthetic whimsy but would give each critter a consistent identity.

### Movement patterns

All animals currently use the same two movement modes (free roam + perimeter walker) with the same speed variance. Custom critters would default to this. Open questions:
- Should custom critters have selectable movement personalities (e.g. "wanders", "patrols edges", "hops", "fast and erratic")?
- The hop motion is currently rabbit-specific (an extra `abs(sin(walk_phase))` term added to the y position). This could be a selectable parameter.
- The perimeter walker is currently only for solo spawns. Should users be able to set their custom critter to always perimeter-walk?

### Backend architecture for the cloud path

If AI animation is included, the client app cannot hold an API key. A minimal backend is required:

- **Serverless function** (Cloudflare Workers, AWS Lambda, Vercel Functions): receives the image, calls the AI API, returns the frame data. Stateless, cheap at low volume, scales automatically.
- **Payment integration**: Stripe Checkout (redirect to Stripe-hosted page) or Stripe Payment Links. On successful payment, the backend returns a signed token that unlocks the feature locally. The token could be bound to a machine ID or email.
- **Custom critter storage**: once frames are generated and stored locally, the cloud is not needed again. The local storage format would be a folder in `%APPDATA%\CritterOverlay\custom\<critter_id>\` containing frame PNGs, a metadata JSON (name, palette for trail, sound profile, hitbox data), and a thumbnail.

The backend can be minimal — a single serverless function handles: verify payment → call AI API → return frames. No database required if the token is stateless (HMAC-signed payload).

### Sprite format for custom critters

The current animals have no sprite sheets — they are drawn procedurally. Custom critters need actual image data. Proposed format:

- 4 frames stored as individual PNGs (not a sprite sheet) in `%APPDATA%\CritterOverlay\custom\<id>\frames\`
- Each frame: RGBA, background transparent, recommended square dimensions matching the animal size setting (default 120×120, scaling applied at render time)
- Rendered in the overlay by blitting the appropriate frame based on `walk_phase` rather than calling a `draw()` method
- The `Animal` subclass for custom critters (`CustomAnimal`) inherits all movement, physics, trail, and sound logic from the base class; `draw()` is overridden to blit the current frame with optional horizontal flip for direction

### Custom animal registration and persistence

Custom critters need to survive app restarts and updates. Proposed storage:
- Each custom critter: folder at `%APPDATA%\CritterOverlay\custom\<uuid>\`
  - `frames/` — 4 PNG frames
  - `meta.json` — name, trail_palette, sound_profile, hit_radius_override, creation_date
  - `thumb.png` — 64×64 thumbnail for the settings UI
- Settings config gains a `"custom_animals"` section: list of IDs with enabled/weight/sound flags (same structure as built-ins)
- The settings window gains a "Custom" tab showing thumbnails of registered critters, with enable/disable toggles and a "Create new" button

---

## Summary of open design decisions

| Question | Option A | Option B | Option C |
|---|---|---|---|
| Custom animation source | Procedural deformation (offline, free) | AI API (cloud, ~10p/gen) | User supplies animated GIF |
| Clickbox for custom shapes | Keep circle | Convex hull from alpha | Per-pixel alpha test (requires arch change) |
| Sound for custom critters | Pick from existing library | Randomised procedural | Colour/shape-seeded procedural |
| Trail for custom critters | None | Auto-sample dominant colours | User-selectable style |
| Movement personality | Fixed (same as built-ins) | Selectable presets | —  |
| Monetisation price point | 50p/critter (Stripe fees eat ~42%) | £1/critter (~77p net) | Bundle: 3 for £1.49 |
| Backend | Serverless function (Cloudflare/Lambda) | Self-hosted | No backend (offline only, procedural) |

The no-backend, procedural-only path is the fastest to ship and requires no ongoing infrastructure or cost. The AI path produces higher-quality animation but adds complexity, latency, cost, and a payment flow. Both can coexist: ship procedural first, add AI as a paid upgrade later.
