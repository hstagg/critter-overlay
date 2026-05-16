"""
overlay.py — Main pygame transparent overlay window for Critter Overlay App

Technical approach:
  - Full-screen borderless pygame window
  - Win32 SetLayeredWindowAttributes with colour key (255, 0, 255) = magenta
  - Background filled with magenta → appears transparent to user
  - Animal pixels (non-magenta) are visible and capture mouse clicks
  - WS_EX_TOOLWINDOW removes the taskbar entry
  - SetWindowPos HWND_TOPMOST keeps it above everything

Click-through logic:
  - Magenta pixels: Windows automatically passes clicks through to apps below
  - Non-magenta (animal) pixels: clicks land on this window, we handle them
"""

import sys
import ctypes
import ctypes.wintypes
import math
import random
import time

import pygame

from animals import Animal, Particle, TrailParticle, create_animal
from spawn_manager import SpawnManager
from sounds import SoundManager
from config import save_config

# How far the mouse must move during a press-hold for the gesture to count
# as a "drag → throw" rather than a "click → pop".
DRAG_THRESHOLD_PX = 8

# Minimum throw speed if the user releases gently (so the critter still
# leaves the screen rather than hovering forever).
MIN_THROW_SPEED   = 380.0

# ---------------------------------------------------------------------------
# Colour constants
# ---------------------------------------------------------------------------

CHROMA      = (255, 0, 255)   # transparent / click-through background
CHROMA_CREF = 0x00FF00FF      # COLORREF for Windows: 0x00BBGGRR = R=255,G=0,B=255
                               # Wait — COLORREF = R | (G<<8) | (B<<16)
                               # Magenta: 255 | 0<<8 | 255<<16 = 255 + 16711680 = 16711935 = 0xFF00FF
CHROMA_CREF = 255 + (0 << 8) + (255 << 16)   # correct

TARGET_FPS  = 60

# ---------------------------------------------------------------------------
# Win32 setup helpers
# ---------------------------------------------------------------------------

GWL_EXSTYLE       = -20
WS_EX_LAYERED     = 0x00080000
WS_EX_TOOLWINDOW  = 0x00000080   # no taskbar button
WS_EX_TOPMOST     = 0x00000008   # (handled via SetWindowPos)
LWA_COLORKEY      = 0x00000001
HWND_TOPMOST      = ctypes.wintypes.HWND(-1)
SWP_NOMOVE        = 0x0002
SWP_NOSIZE        = 0x0001
SWP_NOACTIVATE    = 0x0010
SWP_SHOWWINDOW    = 0x0040


def _setup_win32_overlay(hwnd: int) -> None:
    user32 = ctypes.windll.user32

    # Add layered + toolwindow styles
    ex = user32.GetWindowLongW(hwnd, GWL_EXSTYLE)
    ex |= WS_EX_LAYERED | WS_EX_TOOLWINDOW
    user32.SetWindowLongW(hwnd, GWL_EXSTYLE, ex)

    # Colour key transparency
    user32.SetLayeredWindowAttributes(hwnd, CHROMA_CREF, 0, LWA_COLORKEY)

    # Always on top, no focus steal
    user32.SetWindowPos(
        hwnd, HWND_TOPMOST, 0, 0, 0, 0,
        SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE
    )


# ---------------------------------------------------------------------------
# Pop flash notification (brief text overlay)
# ---------------------------------------------------------------------------

class Notification:
    def __init__(self, text: str, x: int, y: int, color=(255, 230, 80)):
        self.text = text
        self.x = x
        self.y = float(y)
        self.color = color
        self.life = 1.5   # seconds

    def update(self, dt: float) -> bool:
        self.y -= 28 * dt
        self.life -= dt
        return self.life > 0

    def draw(self, surface, font):
        alpha = min(1.0, self.life * 1.5)
        # Fade by blending colour toward background... can't do alpha with
        # chroma key easily, so just draw while alive
        surf = font.render(self.text, True, self.color)
        surface.blit(surf, (int(self.x - surf.get_width() / 2), int(self.y)))


# ---------------------------------------------------------------------------
# Main Overlay class
# ---------------------------------------------------------------------------

class Overlay:

    def __init__(self, config: dict, sound_manager: SoundManager,
                 open_settings_fn, quit_event, on_pause_changed=None):
        self.config = config
        self.sound_manager = sound_manager
        self.open_settings_fn = open_settings_fn
        self.quit_event = quit_event
        self._on_pause_changed = on_pause_changed  # callback → updates tray icon

        self.paused: bool = False  # always start unpaused

        # Animals and particles alive on screen
        self._animals: list[Animal] = []
        self._particles: list[Particle] = []
        self._trail_particles: list[TrailParticle] = []
        self._notifications: list[Notification] = []

        # Drag/throw state
        self._dragging_animal: Animal | None = None
        self._drag_start_pos: tuple[int, int] | None = None
        self._drag_start_time: float = 0.0
        self._drag_max_dist:  float = 0.0
        self._drag_history:   list[tuple[float, int, int]] = []

        # Settings change detection
        self._config_dirty: bool = False

        # Initialise display
        pygame.init()
        info = pygame.display.Info()
        self.screen_w = info.current_w
        self.screen_h = info.current_h

        # Full-screen borderless window positioned at 0,0
        import os
        os.environ.setdefault("SDL_VIDEO_WINDOW_POS", "0,0")
        self.screen = pygame.display.set_mode(
            (self.screen_w, self.screen_h),
            pygame.NOFRAME | pygame.HWSURFACE | pygame.DOUBLEBUF
        )
        pygame.display.set_caption("CritterOverlay")

        # Win32 overlay magic
        try:
            wm = pygame.display.get_wm_info()
            hwnd = wm.get("window")
            if hwnd:
                _setup_win32_overlay(hwnd)
        except Exception as e:
            print(f"[overlay] Win32 setup warning: {e}")

        # Font for notifications
        pygame.font.init()
        self._font = pygame.font.SysFont("Segoe UI", 18, bold=True)

        # Spawn manager
        self._spawn_manager = SpawnManager(
            self.screen_w, self.screen_h, config,
            on_spawn=self._on_spawn
        )

        self._clock = pygame.time.Clock()

    # ------------------------------------------------------------------
    # Public API (called from main thread or hotkey callbacks)
    # ------------------------------------------------------------------

    def toggle_pause(self) -> None:
        self.paused = not self.paused
        if self._on_pause_changed:
            self._on_pause_changed()

    def apply_new_config(self, new_config: dict) -> None:
        """Called when settings window saves a change."""
        self.config = new_config
        self.paused = new_config["system"].get("paused", False)
        self._spawn_manager.apply_config(new_config)
        self.sound_manager.apply_config(new_config)
        self._config_dirty = True

    def request_quit(self) -> None:
        self.quit_event.set()

    def force_spawn(self) -> None:
        self._spawn_manager.force_spawn()

    def force_solo(self) -> None:
        self._spawn_manager.force_solo()

    # ------------------------------------------------------------------
    # Spawn callback
    # ------------------------------------------------------------------

    def _on_spawn(self, animals: list[Animal]) -> None:
        self._animals.extend(animals)
        # Surface a notification when something rare appears.
        for a in animals:
            if a.SPECIES == "unicorn":
                self._notifications.append(Notification(
                    "Magical Unicorn appeared!",
                    int(a.x), int(a.y - a.size * 0.7),
                    color=(255, 200, 250),
                ))
                self._notifications[-1].life = 3.0
            elif a.SPECIES == "golden_kitten":
                self._notifications.append(Notification(
                    "✨ Legendary Golden Kitten! ✨",
                    int(a.x), int(a.y - a.size * 0.7),
                    color=(255, 230, 100),
                ))
                self._notifications[-1].life = 4.0

    # ------------------------------------------------------------------
    # Main loop
    # ------------------------------------------------------------------

    def run(self) -> None:
        prev_time = time.monotonic()

        while not self.quit_event.is_set():
            now = time.monotonic()
            dt = min(now - prev_time, 0.05)   # cap dt to avoid spiral on lag
            prev_time = now

            self._handle_events()
            self._update(dt)
            self._render()
            self._clock.tick(TARGET_FPS)

        self._cleanup()

    # ------------------------------------------------------------------
    # Event handling
    # ------------------------------------------------------------------

    def _handle_events(self) -> None:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                self.quit_event.set()

            elif event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
                self._on_mouse_down(event.pos)

            elif event.type == pygame.MOUSEMOTION:
                if self._dragging_animal is not None:
                    self._on_mouse_motion(event.pos)

            elif event.type == pygame.MOUSEBUTTONUP and event.button == 1:
                if self._dragging_animal is not None:
                    self._on_mouse_up(event.pos)

            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    self.quit_event.set()

    # ------------------------------------------------------------------
    # Mouse: press → potentially grab, release → click=pop or drag=throw
    # ------------------------------------------------------------------

    def _on_mouse_down(self, pos: tuple[int, int]) -> None:
        mx, my = pos
        # Hit-test top-most animal first (later in list = drawn later = on top).
        for animal in reversed(self._animals):
            if not animal.alive:
                continue
            if animal.hit_test(mx, my):
                self._dragging_animal  = animal
                self._drag_start_pos   = (mx, my)
                self._drag_start_time  = time.monotonic()
                self._drag_max_dist    = 0.0
                self._drag_history     = [(time.monotonic(), mx, my)]
                animal.being_dragged   = True
                animal.thrown          = False  # in case caught mid-flight
                animal.spin_angle      = 0.0
                animal.spin_speed      = 0.0
                return

    def _on_mouse_motion(self, pos: tuple[int, int]) -> None:
        a = self._dragging_animal
        if a is None or self._drag_start_pos is None:
            return
        mx, my = pos
        # Move the animal under the cursor
        a.x, a.y = float(mx), float(my)

        # Track motion history for throw-velocity estimation
        now = time.monotonic()
        self._drag_history.append((now, mx, my))
        # Trim to the last 250 ms — older samples make velocity stale
        cutoff = now - 0.25
        self._drag_history = [h for h in self._drag_history if h[0] >= cutoff]

        sx, sy = self._drag_start_pos
        d = math.hypot(mx - sx, my - sy)
        if d > self._drag_max_dist:
            self._drag_max_dist = d

    def _on_mouse_up(self, pos: tuple[int, int]) -> None:
        a = self._dragging_animal
        if a is None:
            return
        mx, my = pos
        a.being_dragged       = False
        self._dragging_animal = None

        # Click → pop
        if self._drag_max_dist < DRAG_THRESHOLD_PX:
            self._pop_animal(a)
            return

        # Drag → throw with velocity from recent history
        vx, vy = self._estimate_throw_velocity()

        speed = math.hypot(vx, vy)
        if speed < MIN_THROW_SPEED:
            # Use overall drag direction at the minimum speed so it still flies
            sx, sy = self._drag_start_pos or (mx, my)
            dx = mx - sx
            dy = my - sy
            dist = math.hypot(dx, dy)
            if dist > 1.0:
                vx = dx / dist * MIN_THROW_SPEED
                vy = dy / dist * MIN_THROW_SPEED
            else:
                vx = MIN_THROW_SPEED * (1 if random.random() < 0.5 else -1)
                vy = -MIN_THROW_SPEED * 0.3

        a.set_thrown(vx, vy)
        # Throw despawns same as a pop, so play the species sound for feedback.
        self.sound_manager.play(a.SPECIES, self.config)

    def _estimate_throw_velocity(self) -> tuple[float, float]:
        """Compute a throw velocity from the recent drag samples."""
        if len(self._drag_history) < 2:
            return 0.0, 0.0
        # Use the last ~120 ms for a snappy, intuitive feel.
        last_t = self._drag_history[-1][0]
        recent = [h for h in self._drag_history if h[0] >= last_t - 0.12]
        if len(recent) < 2:
            recent = self._drag_history[-2:]
        t0, x0, y0 = recent[0]
        t1, x1, y1 = recent[-1]
        dt = max(t1 - t0, 1e-3)
        return (x1 - x0) / dt, (y1 - y0) / dt

    def _pop_animal(self, animal: Animal) -> None:
        animal.alive = False
        if animal in self._animals:
            self._animals.remove(animal)

        # Spawn particles
        colors = animal.PARTICLE_COLORS
        for _ in range(random.randint(10, 16)):
            color = random.choice(colors)
            p = Particle(animal.x, animal.y, color)
            self._particles.append(p)

        # Play sound
        self.sound_manager.play(animal.SPECIES, self.config)

    # ------------------------------------------------------------------
    # Update
    # ------------------------------------------------------------------

    def _update(self, dt: float) -> None:
        # Tick spawn manager — pass dt so it can freeze countdown while paused
        self._spawn_manager.tick(dt=dt, paused=self.paused)

        # Update animals + harvest trail particles from rares
        for animal in list(self._animals):
            animal.update(dt, self._animals)
            if animal.LEAVES_TRAIL and not animal.being_dragged:
                new_trails = animal.emit_trail(dt)
                if new_trails:
                    self._trail_particles.extend(new_trails)

        # Reap thrown animals that have left the screen
        if any(not a.alive for a in self._animals):
            self._animals = [a for a in self._animals if a.alive]

        # Update particles
        self._particles = [p for p in self._particles if p.update(dt)]
        self._trail_particles = [p for p in self._trail_particles if p.update(dt)]

        # Update notifications
        self._notifications = [n for n in self._notifications if n.update(dt)]

    # ------------------------------------------------------------------
    # Render
    # ------------------------------------------------------------------

    def _render(self) -> None:
        # Fill background with chroma key (becomes transparent)
        self.screen.fill(CHROMA)

        # Draw trail particles UNDER animals so the critter floats above its sparkle
        for p in self._trail_particles:
            p.draw(self.screen)

        # Draw all animals (thrown ones get rotated by their spin angle)
        for animal in self._animals:
            if animal.thrown and abs(animal.spin_angle) > 0.01:
                self._draw_thrown_animal(animal)
            else:
                animal.draw(self.screen, animal.anim_t)

        # Draw pop-burst particles in front of animals
        for p in self._particles:
            p.draw(self.screen)

        # Draw notifications
        for n in self._notifications:
            n.draw(self.screen, self._font)

        pygame.display.flip()

    def _draw_thrown_animal(self, animal: Animal) -> None:
        """Render a thrown critter onto a temp surface, rotate, blit centred."""
        bs = max(64, int(animal.size * 2.6))
        tmp = pygame.Surface((bs, bs))
        tmp.fill(CHROMA)
        tmp.set_colorkey(CHROMA)

        # Translate the animal to the centre of the temp surface for drawing,
        # then put its real position back so update keeps moving it correctly.
        real_x, real_y = animal.x, animal.y
        animal.x = bs / 2.0
        animal.y = bs / 2.0
        try:
            animal.draw(tmp, animal.anim_t)
        finally:
            animal.x, animal.y = real_x, real_y

        rotated = pygame.transform.rotate(tmp, math.degrees(animal.spin_angle))
        rect = rotated.get_rect(center=(int(real_x), int(real_y)))
        self.screen.blit(rotated, rect)

    # ------------------------------------------------------------------
    # Cleanup
    # ------------------------------------------------------------------

    def _cleanup(self) -> None:
        pygame.quit()
