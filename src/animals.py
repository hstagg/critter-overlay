"""
animals.py — Cartoon animals for Critter Overlay App

Design principles:
  - Warm dark-brown outlines on every shape (not pure black)
  - Big expressive eyes: sclera → iris → pupil → shine
  - Rosy blush marks on cheeks
  - Big heads relative to bodies (baby-face proportions = cute)
  - Blink, walk bob, tail wag animations

Colour rule: NEVER use exactly (255, 0, 255) — that is the chroma-key background.
"""

import math
import random
import pygame

from locomotion import update_locomotion

# ---------------------------------------------------------------------------
# Global style constants
# ---------------------------------------------------------------------------

OUTLINE     = (48, 32, 24)   # warm dark brown — softer than pure black
SHINE       = (255, 255, 255)
BLUSH_COL   = (252, 150, 158)
IRIS_COL    = (88, 62, 40)
PUPIL_COL   = (18, 14, 14)


# ---------------------------------------------------------------------------
# Drawing primitives
# ---------------------------------------------------------------------------

def _ow(s: int) -> int:
    """Outline width proportional to animal size."""
    return max(2, int(s * 0.030))


def _ec(surface, color, cx, cy, w, h):
    """Ellipse centred at (cx, cy)."""
    pygame.draw.ellipse(surface, color,
                        (int(cx - w / 2), int(cy - h / 2), int(w), int(h)))


def _ec_o(surface, fill, cx, cy, w, h, s):
    """Outlined ellipse."""
    ow = _ow(s)
    pygame.draw.ellipse(surface, OUTLINE,
                        (int(cx-w/2-ow), int(cy-h/2-ow), int(w+ow*2), int(h+ow*2)))
    pygame.draw.ellipse(surface, fill,
                        (int(cx-w/2), int(cy-h/2), int(w), int(h)))


def _circ(surface, color, cx, cy, r):
    pygame.draw.circle(surface, color, (int(cx), int(cy)), int(r))


def _circ_o(surface, fill, cx, cy, r, s):
    """Outlined circle."""
    ow = _ow(s)
    pygame.draw.circle(surface, OUTLINE, (int(cx), int(cy)), int(r) + ow)
    pygame.draw.circle(surface, fill,   (int(cx), int(cy)), int(r))


def _poly_o(surface, fill, points, s):
    """Outlined polygon."""
    ow = _ow(s)
    # Simple outline: draw slightly thicker in outline colour, then fill on top
    pygame.draw.polygon(surface, OUTLINE, points)
    # Shrink points toward centroid for fill
    cx = sum(p[0] for p in points) / len(points)
    cy = sum(p[1] for p in points) / len(points)
    inner = [(int(px + (cx-px)*ow*0.5/max(1,math.hypot(px-cx,py-cy))),
              int(py + (cy-py)*ow*0.5/max(1,math.hypot(px-cx,py-cy))))
             for px, py in points]
    pygame.draw.polygon(surface, fill, inner)


def _mir(cx: float, offset: float, d: int) -> int:
    """Mirror x-offset by direction (d=+1 right, d=-1 left)."""
    return int(cx + offset * d)


# ---------------------------------------------------------------------------
# Shared feature helpers
# ---------------------------------------------------------------------------

def _cute_eye(surface, cx, cy, r, blink=False):
    """Large cartoon eye with iris, pupil, and twin shines."""
    cx, cy, r = int(cx), int(cy), int(r)
    if blink:
        pygame.draw.arc(surface, OUTLINE,
                        (cx - r, cy - r // 2, r * 2, r),
                        0, math.pi, max(2, r // 2))
        return
    ow = max(1, r // 5)
    _circ(surface, OUTLINE, cx, cy, r + ow)
    _circ(surface, SHINE,   cx, cy, r)
    ir = max(2, int(r * 0.68))
    _circ(surface, IRIS_COL, cx, cy, ir)
    pr = max(1, int(r * 0.42))
    _circ(surface, PUPIL_COL, cx, cy, pr)
    # Main shine
    _circ(surface, SHINE, cx + max(1, int(r*0.28)), cy - max(1, int(r*0.30)), max(1, int(r*0.28)))
    # Soft secondary shine
    _circ(surface, (210, 210, 210), cx - max(1, int(r*0.18)), cy + max(1, int(r*0.18)), max(1, int(r*0.13)))


def _blush(surface, cx, cy, s):
    """Rosy cheek oval."""
    _ec(surface, BLUSH_COL, cx, cy, int(s * 0.14), int(s * 0.08))


def _whiskers(surface, cx, cy, s, d):
    """Three whisker lines each side of nose."""
    wl = int(s * 0.20)
    for i in range(3):
        wy = int(cy) + int((i - 1) * s * 0.045)
        dy = int((i - 1) * s * 0.015)
        pygame.draw.line(surface, OUTLINE,
                         (_mir(cx,  s*0.06, d), wy),
                         (_mir(cx,  s*0.06+wl, d), wy + dy), 1)
        pygame.draw.line(surface, OUTLINE,
                         (_mir(cx, -s*0.06, d), wy),
                         (_mir(cx, -s*0.06-int(wl*0.75), d), wy + dy), 1)


# ---------------------------------------------------------------------------
# Particle — pop effect
# ---------------------------------------------------------------------------

class Particle:
    GRAVITY = 380

    def __init__(self, x, y, color):
        self.x, self.y = float(x), float(y)
        self.color = color
        angle = random.uniform(0, 2 * math.pi)
        speed = random.uniform(90, 230)
        self.vx = math.cos(angle) * speed
        self.vy = math.sin(angle) * speed - random.uniform(40, 110)
        self.radius = random.randint(4, 9)
        self.life = 1.0

    def update(self, dt):
        self.vy += self.GRAVITY * dt
        self.x  += self.vx * dt
        self.y  += self.vy * dt
        self.life -= dt * 3.0
        return self.life > 0

    def draw(self, surface):
        r = max(1, int(self.radius * self.life))
        _circ(surface, self.color, self.x, self.y, r)


# ---------------------------------------------------------------------------
# Trail particle — sparkle/streak left by super-rare animals
# ---------------------------------------------------------------------------

class TrailParticle:
    """A small fading sparkle/shape. Shrinks over lifetime to simulate fade.

    We can't use alpha against the chroma-key background, so we 'fade' by
    shrinking toward zero over the particle's lifetime.

    style values: "dot", "star", "sparkle", "bubble", "glitter", "heart"
    """

    def __init__(self, x, y, color, size=6, life=1.0, star=False, style="dot"):
        self.x, self.y = float(x), float(y)
        # Avoid the chroma-key colour exactly
        if color == (255, 0, 255):
            color = (255, 1, 255)
        self.color = color
        self.size = size
        self.life = life
        self.max_life = life
        # Legacy star flag maps to style
        if star and style == "dot":
            style = "star"
        self.style = style
        self.vx = random.uniform(-18, 18)
        self.vy = random.uniform(-30, 6)
        if style == "bubble":
            self.vy = -15.0 + random.uniform(-5, 5)
            self.vx = random.uniform(-8, 8)
        elif style == "glitter":
            self.vx = random.uniform(-10, 10)
            self.vy = random.uniform(-12, 4)
        self.twinkle_phase = random.uniform(0, math.pi * 2)
        self.t_total = 0.0

    def update(self, dt):
        self.life -= dt
        self.t_total += dt
        self.x += self.vx * dt
        self.y += self.vy * dt
        if self.style == "bubble":
            # Bubbles drift up gently, minimal gravity
            self.vy += 8 * dt
            self.vx *= (1.0 - 0.5 * dt)
        else:
            # Slight gravity so trail sags a bit
            self.vy += 35 * dt
            # Air drag so trail settles
            self.vx *= (1.0 - 0.9 * dt)
        return self.life > 0

    def draw(self, surface):
        t = max(0.0, self.life / self.max_life)  # 1 → 0
        twink = 0.65 + 0.35 * math.sin(self.t_total * 9.0 + self.twinkle_phase)
        r = max(0, int(self.size * t * twink))
        if r <= 0:
            return
        ix, iy = int(self.x), int(self.y)

        if self.style in ("star", "sparkle") and r >= 2:
            pygame.draw.line(surface, self.color, (ix - r, iy), (ix + r, iy), 1)
            pygame.draw.line(surface, self.color, (ix, iy - r), (ix, iy + r), 1)
            if self.style == "sparkle":
                # Diagonal arms too for 8-point shimmer
                d = max(1, int(r * 0.7))
                pygame.draw.line(surface, self.color, (ix-d, iy-d), (ix+d, iy+d), 1)
                pygame.draw.line(surface, self.color, (ix+d, iy-d), (ix-d, iy+d), 1)
            _circ(surface, self.color, ix, iy, max(1, r // 2))

        elif self.style == "bubble":
            if r >= 2:
                pygame.draw.circle(surface, self.color, (ix, iy), r, max(1, r // 3))

        elif self.style == "glitter":
            _circ(surface, self.color, ix, iy, max(1, r))

        elif self.style == "heart" and r >= 2:
            # Simple heart: two circles + a downward triangle
            half = max(1, r // 2)
            _circ(surface, self.color, ix - half, iy - half // 2, half)
            _circ(surface, self.color, ix + half, iy - half // 2, half)
            pts = [(ix - r, iy), (ix + r, iy), (ix, iy + r)]
            pygame.draw.polygon(surface, self.color, pts)

        else:
            _circ(surface, self.color, ix, iy, r)


# ---------------------------------------------------------------------------
# Base Animal class
# ---------------------------------------------------------------------------

class Animal:
    SPECIES        = "animal"
    BASE_SPEED     = 45
    SPEED_VARIANCE = 0.25
    SIZE_SCALE     = 1.0
    PARTICLE_COLORS = [(200, 200, 200)]

    # Trail config — only super rares should set these
    LEAVES_TRAIL   = False
    TRAIL_PALETTE  = []
    TRAIL_RATE     = 0          # particles per second
    TRAIL_SIZE     = 6
    TRAIL_LIFE     = 1.0
    TRAIL_STAR     = False      # legacy — prefer TRAIL_STYLE
    TRAIL_STYLE    = "dot"      # "dot","star","sparkle","bubble","glitter","heart"

    IDLE_RATE = 0.018   # chance per second to enter idle while walking

    LOCO_PROFILE   = "classic"   # overridden per species; picked up in __init__
    IDLE_WHITELIST = None        # frozenset | None — solo idles this species can do

    WALKING   = "walking"
    IDLE      = "idle"
    TURNING   = "turning"
    POPPING   = "popping"
    SCATTERED = "scattered"
    BEHAVING  = "behaving"

    # Throw/drag physics
    THROW_GRAVITY = 520.0
    THROW_DRAG    = 0.30        # per second velocity loss

    def __init__(self, x, y, size, screen_w, screen_h,
                 direction=None, perimeter_walker=False):
        self.x, self.y = float(x), float(y)
        self.size = max(60, int(size * self.SIZE_SCALE))
        self.screen_w, self.screen_h = screen_w, screen_h
        self.perimeter_walker = perimeter_walker
        self.direction = direction if direction is not None else random.choice([-1, 1])
        self.vert_dir  = random.choice([-1, 1])

        spd = self.BASE_SPEED * (1 + random.uniform(-self.SPEED_VARIANCE, self.SPEED_VARIANCE))
        ang = random.uniform(-20, 20) * math.pi / 180
        self.vx = spd * self.direction * math.cos(ang)
        self.vy = spd * self.vert_dir  * abs(math.sin(ang))

        self.state          = self.WALKING
        self.anim_t         = 0.0
        self.walk_phase     = 0.0
        self.blink_offset   = random.uniform(0, math.pi * 2)
        self.idle_timer     = 0.0
        self.turn_timer     = 0.0
        self.peri_segment   = 0
        self.peri_progress  = 0.0
        self.alive          = True
        self.hit_radius     = int(self.size * 0.46)

        # Drag/throw state
        self.being_dragged  = False
        self.thrown         = False
        self.spin_angle     = 0.0
        self.spin_speed     = 0.0

        # Scatter state (collision impulse)
        self.scatter_timer  = 0.0

        # Trail emission accumulator
        self._trail_acc     = 0.0

        # Set by spawn_manager after construction; drives aura rendering
        self.rarity         = None   # RarityTier | None

        # Locomotion profile state (updated every frame by update_locomotion)
        self.loco_profile       = self.LOCO_PROFILE
        self.loco_phase         = 0.0
        self._loco_speed_scalar = 1.0
        self._loco_y_offset     = 0.0
        self._loco_x_offset     = 0.0

        # Behaviour state machine
        self.behaviour_name         = None   # str | None
        self.behaviour_timer        = 0.0
        self.behaviour_partner      = None   # Animal | None  (pair interactions)
        self._behaviour_exit_cd     = 0.0   # cooldown to apply on exit
        self._behaviour_cooldowns: dict = {}  # name → seconds_remaining

    # ------------------------------------------------------------------ throw/drag

    def enter_behaviour(self, name: str, duration: float,
                        partner=None, cooldown: float = 30.0) -> None:
        """Put this animal into a named behaviour state. Movement stops."""
        self.state              = self.BEHAVING
        self.behaviour_name     = name
        self.behaviour_timer    = duration
        self.behaviour_partner  = partner
        self._behaviour_exit_cd = cooldown
        self.vx = 0.0
        self.vy = 0.0

    def _exit_behaviour(self) -> None:
        """Return from BEHAVING to WALKING, applying cooldown."""
        if self.behaviour_name and self._behaviour_exit_cd > 0:
            self._behaviour_cooldowns[self.behaviour_name] = self._behaviour_exit_cd
        self.behaviour_name    = None
        self.behaviour_timer   = 0.0
        self.behaviour_partner = None
        self._behaviour_exit_cd = 0.0
        self.state = self.WALKING
        # Resume at base speed
        spd = self.BASE_SPEED * (1 + random.uniform(-self.SPEED_VARIANCE, self.SPEED_VARIANCE))
        ang = random.uniform(-15, 15) * math.pi / 180
        self.vx = spd * self.direction * math.cos(ang)
        self.vy = spd * random.choice([-1, 1]) * abs(math.sin(ang)) * 0.4

    def scatter(self, vx: float, vy: float) -> None:
        """Enter scatter state after a collision impulse."""
        if self.behaviour_name is not None:
            self._exit_behaviour()
        self.vx = vx
        self.vy = vy
        self.state = self.SCATTERED
        self.scatter_timer = 1.2
        if abs(vx) > 5:
            self.direction = 1 if vx > 0 else -1

    def set_thrown(self, vx: float, vy: float) -> None:
        """Launch this critter ballistically — it'll fly until off-screen."""
        self.thrown        = True
        self.being_dragged = False
        self.vx            = vx
        self.vy            = vy
        # Spin proportional to horizontal velocity so it tumbles forward.
        # Limit so it doesn't look ridiculous at extreme speeds.
        base_spin = max(-12.0, min(12.0, vx / 120.0))
        self.spin_speed = base_spin + random.uniform(-3.0, 3.0)
        self.spin_angle = 0.0
        # Face the throw direction for the leg/eye flip
        if vx >  20: self.direction =  1
        elif vx < -20: self.direction = -1

    def is_off_screen(self, margin_factor: float = 1.5) -> bool:
        m = int(self.size * margin_factor)
        return (self.x < -m or self.x > self.screen_w + m or
                self.y < -m or self.y > self.screen_h + m)

    # ------------------------------------------------------------------ trail

    def emit_trail(self, dt: float) -> list:
        """Returns a list of new TrailParticle objects (may be empty)."""
        if not self.LEAVES_TRAIL or self.TRAIL_RATE <= 0 or not self.TRAIL_PALETTE:
            return []
        self._trail_acc += dt
        interval = 1.0 / float(self.TRAIL_RATE)
        out = []
        # Cap to avoid runaway after a stutter
        max_emit = 8
        # Resolve style (TRAIL_STYLE takes priority; TRAIL_STAR is legacy compat)
        style = self.TRAIL_STYLE
        if style == "dot" and self.TRAIL_STAR:
            style = "star"
        while self._trail_acc >= interval and len(out) < max_emit:
            self._trail_acc -= interval
            ox = random.uniform(-self.size * 0.18, self.size * 0.18)
            oy = random.uniform(-self.size * 0.20, self.size * 0.10)
            color = random.choice(self.TRAIL_PALETTE)
            sz = random.randint(max(3, self.TRAIL_SIZE - 2), self.TRAIL_SIZE + 2)
            life = random.uniform(self.TRAIL_LIFE * 0.65, self.TRAIL_LIFE * 1.25)
            out.append(TrailParticle(self.x + ox, self.y + oy,
                                     color, size=sz, life=life,
                                     style=style))
        if self._trail_acc > interval * max_emit:
            self._trail_acc = 0.0
        return out

    # ------------------------------------------------------------------ update

    def update(self, dt, all_animals):
        # Held by the user — animate but don't move under AI; position is
        # set externally by the overlay's drag handler.
        if self.being_dragged:
            if self.behaviour_name is not None:
                self._exit_behaviour()
            self.anim_t     += dt
            self.walk_phase += dt * 50 * 0.055
            return

        # Thrown — pure ballistic motion, no walls, no collisions.
        if self.thrown:
            self.anim_t     += dt
            self.walk_phase += dt * 80 * 0.055
            self.spin_angle += self.spin_speed * dt
            self.vx -= self.vx * self.THROW_DRAG * dt
            self.vy += self.THROW_GRAVITY * dt
            self.x  += self.vx * dt
            self.y  += self.vy * dt
            if self.is_off_screen():
                self.alive = False
            return

        self.anim_t     += dt
        self.walk_phase += dt * (abs(self.vx) + abs(self.vy)) * 0.055

        # Locomotion profile — shapes movement texture in WALKING state
        update_locomotion(self, dt)

        if self.state == self.TURNING:
            self.turn_timer -= dt
            if self.turn_timer <= 0:
                self.state = self.WALKING
        elif self.state == self.IDLE:
            self.idle_timer -= dt
            if self.idle_timer <= 0:
                self.state = self.WALKING
        elif self.state == self.SCATTERED:
            self.scatter_timer -= dt
            drag = 2.0
            self.vx *= max(0.0, 1.0 - drag * dt)
            self.vy *= max(0.0, 1.0 - drag * dt)
            m = self.size // 2
            nx = self.x + self.vx * dt
            ny = self.y + self.vy * dt
            if nx < m:
                nx = float(m);               self.vx =  abs(self.vx)
            elif nx > self.screen_w - m:
                nx = float(self.screen_w - m); self.vx = -abs(self.vx)
            if ny < m:
                ny = float(m);               self.vy =  abs(self.vy)
            elif ny > self.screen_h - m:
                ny = float(self.screen_h - m); self.vy = -abs(self.vy)
            self.x, self.y = nx, ny
            spd = math.hypot(self.vx, self.vy)
            if self.scatter_timer <= 0 or spd < self.BASE_SPEED * 0.35:
                self.state = self.WALKING
                if spd > 0.1:
                    self.vx = (self.vx / spd) * self.BASE_SPEED
                    self.vy = (self.vy / spd) * self.BASE_SPEED
                else:
                    self.vx = self.direction * self.BASE_SPEED
                    self.vy = 0.0
        elif self.state == self.BEHAVING:
            self.behaviour_timer -= dt
            if self.behaviour_timer <= 0:
                self._exit_behaviour()
        elif self.state == self.WALKING:
            if self.perimeter_walker:
                self._update_perimeter(dt)
            else:
                self._update_free(dt, all_animals)
            if random.random() < dt * self.IDLE_RATE:
                self.state = self.IDLE
                self.idle_timer = random.uniform(0.8, 2.5)

    def _update_free(self, dt, all_animals):
        scalar = self._loco_speed_scalar
        nx = self.x + self.vx * scalar * dt
        ny = self.y + self.vy * scalar * dt
        m  = self.size // 2
        bounced = False

        if nx < m:
            nx = float(m); self.vx = abs(self.vx); self.direction =  1; bounced = True
        elif nx > self.screen_w - m:
            nx = float(self.screen_w - m); self.vx = -abs(self.vx); self.direction = -1; bounced = True
        if ny < m:
            ny = float(m); self.vy = abs(self.vy); bounced = True
        elif ny > self.screen_h - m:
            ny = float(self.screen_h - m); self.vy = -abs(self.vy); bounced = True

        if bounced:
            self.state = self.TURNING
            self.turn_timer = random.uniform(0.15, 0.35)

        self.x, self.y = nx, ny

    def _update_perimeter(self, dt):
        m, spd = int(self.size * 0.85), abs(self.BASE_SPEED) * 0.75
        segs = [
            (m, m, self.screen_w-m, m),
            (self.screen_w-m, m, self.screen_w-m, self.screen_h-m),
            (self.screen_w-m, self.screen_h-m, m, self.screen_h-m),
            (m, self.screen_h-m, m, m),
        ]
        sx, sy, ex, ey = segs[self.peri_segment]
        seg_len = math.hypot(ex-sx, ey-sy)
        self.peri_progress += spd * self._loco_speed_scalar * dt / max(seg_len, 1)
        if self.peri_progress >= 1.0:
            self.peri_progress = 0.0
            self.peri_segment  = (self.peri_segment + 1) % 4
            self.state = self.IDLE
            self.idle_timer = random.uniform(0.4, 1.2)
            sx, sy, ex, ey = segs[self.peri_segment]
        t = self.peri_progress
        self.x = sx + (ex-sx)*t
        self.y = sy + (ey-sy)*t
        if ex > sx: self.direction =  1
        elif ex < sx: self.direction = -1

    # ------------------------------------------------------------------ shared helpers

    def hit_test(self, mx, my):
        return math.hypot(self.x-mx, self.y-my) <= self.hit_radius

    def _blink(self):
        return math.sin(self.anim_t * 0.85 + self.blink_offset) > 0.96

    def _bob(self):
        base = math.sin(self.walk_phase * 2) * self.size * 0.04 if self.state == self.WALKING else 0.0
        return base + self._loco_y_offset

    def draw(self, surface, anim_t):
        raise NotImplementedError


# ---------------------------------------------------------------------------
# Shared idle whitelist base — universal behaviours any species can perform
# ---------------------------------------------------------------------------

_UNIVERSAL_IDLES = frozenset({
    "stretch", "yawn", "sit_and_look", "nap", "wake_up", "groom_self",
    "scratch", "ear_flick", "tail_swish", "sneeze", "shake_off",
    "look_at_cursor", "listen",
})


# ===========================================================================
# KITTEN  🐱
# ===========================================================================

class Kitten(Animal):
    SPECIES        = "kitten"
    BASE_SPEED     = 52
    SIZE_SCALE     = 1.0
    PARTICLE_COLORS = [(230, 165, 105), (245, 190, 130), (255, 160, 160)]
    LOCO_PROFILE   = "pounce"
    IDLE_WHITELIST = _UNIVERSAL_IDLES | frozenset({"hunt_pose", "chase_tail"})

    # colour palette
    C_BODY   = (228, 168, 105)
    C_HEAD   = (240, 182, 120)
    C_EAR    = (205, 135, 82)
    C_INNER  = (255, 195, 195)
    C_STRIPE = (205, 148, 85)
    C_NOSE   = (255, 140, 148)

    def draw(self, surface, anim_t):
        x, y, s, d = int(self.x + self._loco_x_offset), int(self.y), self.size, self.direction
        bob = int(self._bob())
        blink = self._blink()

        # --- tail (behind body, draw first) ---
        tb = math.sin(self.anim_t * 2.2) * s * 0.14
        tail_pts = []
        for i in range(10):
            f = i / 9
            tx = _mir(x, -s*0.22 - s*0.35*f, d)
            ty = y + bob + int(s*0.10*f - s*0.20*(1-f)*f*2 + tb*f)
            tail_pts.append((tx, ty))
        if len(tail_pts) > 1:
            pygame.draw.lines(surface, self.C_STRIPE, False, tail_pts, max(4, int(s*0.09)))
            pygame.draw.lines(surface, self.C_EAR,   False, tail_pts, max(2, int(s*0.045)))

        # --- body ---
        bw, bh = int(s*0.66), int(s*0.52)
        _ec_o(surface, self.C_BODY, x, y+bob, bw, bh, s)

        # --- head (big — baby-face proportions) ---
        hx = _mir(x, s*0.22, d)
        hy = y - int(s*0.26) + bob
        hr = int(s*0.32)
        _circ_o(surface, self.C_HEAD, hx, hy, hr, s)

        # --- ears ---
        for side, ox, tip_ox in [(-1, -0.18, -0.28), (1, 0.10, 0.22)]:
            ex0 = hx + int(d * side * s * abs(ox))
            ey0 = hy - hr + 6
            ex1 = hx + int(d * side * s * abs(tip_ox))
            ey1 = hy - hr - int(s*0.20)
            ex2 = hx + int(d * side * s * (abs(ox)+0.12))
            ey2 = hy - hr - int(s*0.06)
            _poly_o(surface, self.C_EAR, [(ex0,ey0),(ex1,ey1),(ex2,ey2)], s)
            # inner ear
            ix0 = ex0 + int((ex1-ex0)*0.25)
            iy0 = ey0 + int((ey1-ey0)*0.25)
            ix1 = ex1
            iy1 = ey1 + int(s*0.04)
            ix2 = ex2 + int((ex1-ex2)*0.22)
            iy2 = ey2 + int((ey1-ey2)*0.22)
            pygame.draw.polygon(surface, self.C_INNER, [(ix0,iy0),(ix1,iy1),(ix2,iy2)])

        # --- forehead stripes ---
        for i in range(3):
            sy2 = hy - hr + int(s*(0.05 + i*0.07))
            pygame.draw.line(surface, self.C_STRIPE,
                             (hx - int(s*0.08), sy2), (hx + int(s*0.08), sy2),
                             max(1, int(s*0.025)))

        # --- eyes ---
        er = max(5, int(s * 0.13))
        for ox in [-0.11, 0.11]:
            ex = hx + int(s * ox * d)
            _cute_eye(surface, ex, hy - int(s*0.04), er, blink)

        # --- blush ---
        _blush(surface, hx + int(d * -s*0.16), hy + int(s*0.06), s)
        _blush(surface, hx + int(d *  s*0.16), hy + int(s*0.06), s)

        # --- nose ---
        nx2, ny2 = hx, hy + int(s*0.10)
        npts = [(nx2, ny2-int(s*0.04)),
                (nx2-int(s*0.04), ny2+int(s*0.03)),
                (nx2+int(s*0.04), ny2+int(s*0.03))]
        pygame.draw.polygon(surface, self.C_NOSE, npts)

        # --- mouth ---
        pygame.draw.arc(surface, OUTLINE,
                        (hx-int(s*0.07), hy+int(s*0.10), int(s*0.07), int(s*0.07)),
                        math.pi, 2*math.pi, max(1, int(s*0.025)))
        pygame.draw.arc(surface, OUTLINE,
                        (hx, hy+int(s*0.10), int(s*0.07), int(s*0.07)),
                        math.pi, 2*math.pi, max(1, int(s*0.025)))

        # --- whiskers ---
        _whiskers(surface, hx, hy+int(s*0.09), s, d)

        # --- legs ---
        lw, lh = int(s*0.14), int(s*0.15)
        sw2 = math.sin(self.walk_phase*2) * int(s*0.04) if self.state==self.WALKING else 0
        for i, ox in enumerate([-0.28, -0.09, 0.09, 0.28]):
            lb = sw2 if i%2==0 else -sw2
            _ec_o(surface, self.C_EAR, x+int(s*ox), y+int(bh*0.52)+lb+bob, lw, lh, s)


# ===========================================================================
# TURTLE  🐢
# ===========================================================================

class Turtle(Animal):
    SPECIES        = "turtle"
    BASE_SPEED     = 28
    SIZE_SCALE     = 0.95
    PARTICLE_COLORS = [(75, 148, 75), (100, 175, 90), (180, 220, 100)]
    LOCO_PROFILE   = "plod"
    IDLE_WHITELIST = _UNIVERSAL_IDLES | frozenset({"head_tuck"})

    C_SHELL  = (78, 148, 72)
    C_LIGHT  = (108, 182, 95)
    C_DOME   = (138, 205, 118)
    C_SKIN   = (108, 175, 95)
    C_BELLY  = (185, 218, 125)
    C_LINE   = (55, 108, 52)

    def draw(self, surface, anim_t):
        x, y, s, d = int(self.x + self._loco_x_offset), int(self.y), self.size, self.direction
        bob = int(self._bob() * 0.5)
        blink = self._blink()

        # --- shell ---
        sw, sh = int(s*0.74), int(s*0.58)
        _ec_o(surface, self.C_SHELL, x, y+bob, sw, sh, s)
        # dome highlight
        _ec(surface, self.C_LIGHT, x-int(sw*0.06), y+bob-int(sh*0.08), int(sw*0.62), int(sh*0.52))
        _ec(surface, self.C_DOME,  x-int(sw*0.10), y+bob-int(sh*0.14), int(sw*0.35), int(sh*0.30))

        # hex pattern
        for cx2, cy2, pr in [
            (x, y+bob-int(s*0.12), int(s*0.10)),
            (x-int(s*0.16), y+bob+int(s*0.04), int(s*0.09)),
            (x+int(s*0.16), y+bob+int(s*0.04), int(s*0.09)),
            (x-int(s*0.08), y+bob+int(s*0.16), int(s*0.08)),
            (x+int(s*0.08), y+bob+int(s*0.16), int(s*0.08)),
        ]:
            pygame.draw.circle(surface, self.C_LINE, (cx2, cy2), pr, max(1, int(s*0.025)))

        # --- belly plate ---
        _ec(surface, self.C_BELLY, x, y+bob+int(sh*0.28), int(sw*0.55), int(sh*0.30))

        # --- head (big and round, peeking forward) ---
        hx = _mir(x, s*0.36, d)
        hy = y - int(s*0.06) + bob
        hr = int(s*0.20)
        _circ_o(surface, self.C_SKIN, hx, hy, hr, s)

        # --- neck ---
        pygame.draw.line(surface, self.C_SKIN,
                         (_mir(x, s*0.28, d), y+bob-int(sh*0.12)),
                         (hx, hy+hr-2), max(4, int(s*0.12)))

        # --- eye ---
        er = max(4, int(s*0.10))
        _cute_eye(surface, hx+int(d*s*0.04), hy-int(s*0.04), er, blink)

        # --- mouth smile ---
        pygame.draw.arc(surface, OUTLINE,
                        (_mir(hx, -s*0.05, d), hy+int(s*0.04),
                         int(s*0.10), int(s*0.07)),
                        math.pi, 2*math.pi, max(1, int(s*0.025)))

        # --- legs ---
        leg_positions = [
            (_mir(x,  s*0.28, d), y+bob+int(sh*0.35)),
            (_mir(x,  s*0.10, d), y+bob+int(sh*0.46)),
            (_mir(x, -s*0.10, d), y+bob+int(sh*0.46)),
            (_mir(x, -s*0.28, d), y+bob+int(sh*0.35)),
        ]
        sw2 = math.sin(self.walk_phase*2)*int(s*0.035) if self.state==self.WALKING else 0
        for i,(lx,ly) in enumerate(leg_positions):
            lb = sw2 if i%2==0 else -sw2
            _ec_o(surface, self.C_SKIN, lx, ly+lb, int(s*0.16), int(s*0.12), s)


# ===========================================================================
# DUCK  🦆
# ===========================================================================

class Duck(Animal):
    SPECIES        = "duck"
    BASE_SPEED     = 46
    PARTICLE_COLORS = [(248, 230, 80), (255, 200, 50), (240, 245, 220)]
    LOCO_PROFILE   = "waddle"
    IDLE_WHITELIST = _UNIVERSAL_IDLES | frozenset({"preen", "peck_ground"})

    C_BODY  = (248, 245, 228)
    C_WING  = (228, 224, 205)
    C_HEAD  = (248, 218, 58)
    C_BEAK  = (228, 128, 38)
    C_FOOT  = (215, 115, 32)

    def draw(self, surface, anim_t):
        x, y, s, d = int(self.x + self._loco_x_offset), int(self.y), self.size, self.direction
        bob = int(self._bob())
        blink = self._blink()

        # --- body (very round and fluffy) ---
        bw, bh = int(s*0.72), int(s*0.60)
        _ec_o(surface, self.C_BODY, x, y+bob, bw, bh, s)

        # --- wing detail ---
        wx = _mir(x, -s*0.06, d)
        _ec_o(surface, self.C_WING, wx, y+bob+int(s*0.06), int(s*0.44), int(s*0.32), s)
        # feather lines
        for i in range(3):
            fy = y+bob+int(s*0.01)+i*int(s*0.06)
            pygame.draw.arc(surface, OUTLINE,
                            (wx-int(s*0.18), fy, int(s*0.36), int(s*0.06)),
                            math.pi, 2*math.pi, max(1, int(s*0.020)))

        # --- tail feathers ---
        tx = _mir(x, -s*0.35, d)
        tpts = [(tx,y+bob),(tx-int(d*s*0.20),y+bob-int(s*0.22)),(tx-int(d*s*0.08),y+bob-int(s*0.08))]
        _poly_o(surface, self.C_WING, tpts, s)

        # --- head (big round ball) ---
        hx = _mir(x, s*0.26, d)
        hy = y - int(s*0.30) + bob
        hr = int(s*0.26)
        _circ_o(surface, self.C_HEAD, hx, hy, hr, s)

        # --- beak ---
        bk_pts = [
            (hx + int(d*s*0.16), hy - int(s*0.04)),
            (hx + int(d*s*0.16), hy + int(s*0.06)),
            (hx + int(d*s*0.36), hy + int(s*0.01)),
        ]
        _poly_o(surface, self.C_BEAK, bk_pts, s)

        # --- eye ---
        er = max(5, int(s*0.12))
        _cute_eye(surface, hx - int(d*s*0.06), hy - int(s*0.04), er, blink)

        # --- blush ---
        _blush(surface, hx - int(d*s*0.14), hy + int(s*0.08), s)

        # --- feet ---
        sw2 = math.sin(self.walk_phase*2)*int(s*0.04) if self.state==self.WALKING else 0
        for i, ox in enumerate([-0.14, 0.14]):
            lb = sw2 if i==0 else -sw2
            _ec_o(surface, self.C_FOOT, x+int(s*ox), y+int(bh*0.52)+lb+bob, int(s*0.18), int(s*0.09), s)


# ===========================================================================
# RABBIT  🐰
# ===========================================================================

class Rabbit(Animal):
    SPECIES        = "rabbit"
    BASE_SPEED     = 62
    SPEED_VARIANCE = 0.30
    PARTICLE_COLORS = [(205, 198, 212), (242, 180, 185), (250, 248, 252)]
    LOCO_PROFILE   = "hop"
    IDLE_WHITELIST = _UNIVERSAL_IDLES | frozenset({"nose_twitch", "stand_lookout"})

    C_BODY  = (205, 198, 215)
    C_HEAD  = (220, 215, 228)
    C_EAR   = (218, 212, 226)
    C_INNER = (242, 175, 182)
    C_NOSE  = (255, 148, 158)
    C_TAIL  = (250, 250, 254)

    def draw(self, surface, anim_t):
        x, y, s, d = int(self.x + self._loco_x_offset), int(self.y), self.size, self.direction
        bob = int(self._bob())
        hop = abs(math.sin(self.walk_phase*2)) * int(s*0.05) if self.state==self.WALKING else 0
        blink = self._blink()

        # --- tail ---
        tx = _mir(x, -s*0.34, d)
        _circ_o(surface, self.C_TAIL, tx, y+int(s*0.12)+bob, int(s*0.14), s)

        # --- body (fluffy oval) ---
        bw, bh = int(s*0.62), int(s*0.58)
        _ec_o(surface, self.C_BODY, x, y+bob, bw, bh, s)

        # --- head (big) ---
        hx = _mir(x, s*0.18, d)
        hy = y - int(s*0.28) + bob - hop
        hr = int(s*0.30)
        _circ_o(surface, self.C_HEAD, hx, hy, hr, s)

        # --- ears ---
        ear_h, ear_w = int(s*0.58), int(s*0.13)
        tilt = math.sin(self.walk_phase*2)*int(s*0.04) if self.state==self.WALKING else 0
        for i, ox in enumerate([-0.11, 0.11]):
            ecx = hx + int(s * ox * d)
            ecy = hy - hr - ear_h//2
            tilt2 = tilt if i==0 else -tilt
            _ec_o(surface, self.C_EAR, ecx+tilt2, ecy, ear_w, ear_h, s)
            _ec(surface, self.C_INNER, ecx+tilt2, ecy+int(ear_h*0.08), int(ear_w*0.52), int(ear_h*0.72))

        # --- eyes ---
        er = max(6, int(s*0.13))
        for ox in [-0.10, 0.10]:
            _cute_eye(surface, hx+int(s*ox*d), hy-int(s*0.04), er, blink)

        # --- blush ---
        _blush(surface, hx+int(d*-s*0.18), hy+int(s*0.07), s)
        _blush(surface, hx+int(d* s*0.18), hy+int(s*0.07), s)

        # --- nose ---
        _circ_o(surface, self.C_NOSE, hx, hy+int(s*0.10), max(3, int(s*0.05)), s)

        # --- mouth ---
        pygame.draw.line(surface, OUTLINE, (hx, hy+int(s*0.13)), (hx, hy+int(s*0.18)), max(1, int(s*0.025)))
        pygame.draw.arc(surface, OUTLINE,
                        (hx-int(s*0.09), hy+int(s*0.16), int(s*0.09), int(s*0.07)),
                        math.pi, 2*math.pi, max(1, int(s*0.025)))
        pygame.draw.arc(surface, OUTLINE,
                        (hx, hy+int(s*0.16), int(s*0.09), int(s*0.07)),
                        math.pi, 2*math.pi, max(1, int(s*0.025)))

        # --- whiskers ---
        _whiskers(surface, hx, hy+int(s*0.10), s, d)

        # --- feet ---
        lw, lh = int(s*0.16), int(s*0.14)
        for i, ox in enumerate([-0.20, 0.20]):
            lb = hop if i%2==0 else -hop//2
            _ec_o(surface, self.C_BODY, x+int(s*ox), y+int(bh*0.50)-lb+bob, lw, lh, s)


# ===========================================================================
# HEDGEHOG  🦔
# ===========================================================================

class Hedgehog(Animal):
    SPECIES        = "hedgehog"
    BASE_SPEED     = 38
    SIZE_SCALE     = 0.92
    PARTICLE_COLORS = [(135, 92, 60), (205, 165, 122), (245, 220, 180)]
    LOCO_PROFILE   = "snuffle"
    IDLE_WHITELIST = _UNIVERSAL_IDLES | frozenset({"snuffle_pause", "ball_up"})

    C_BACK  = (135, 92, 60)
    C_BELLY = (205, 162, 118)
    C_FACE  = (218, 180, 138)
    C_SPIKE = (112, 75, 45)
    C_NOSE  = (88, 55, 42)

    def draw(self, surface, anim_t):
        x, y, s, d = int(self.x + self._loco_x_offset), int(self.y), self.size, self.direction
        bob = int(self._bob() * 0.55)
        blink = self._blink()

        # --- spine body ---
        scx = _mir(x, -s*0.04, d)
        sw, sh = int(s*0.70), int(s*0.52)
        _ec_o(surface, self.C_BACK, scx, y+bob, sw, sh, s)

        # --- spikes (upper half of body only) ---
        n = 12
        for i in range(n):
            frac = i/(n-1) - 0.5
            # Arc from upper-back (≈202°) over the top (270°) to upper-front (≈338°)
            # sin is negative in this range → spikes point upward in screen coords
            base_angle = math.pi * (1.50 + frac * 0.75)
            ang = base_angle if d==1 else math.pi - base_angle
            spike_len = int(s * 0.18)
            cos_a, sin_a = math.cos(ang), math.sin(ang)
            bx = scx + int(cos_a * sw*0.44)
            by = y+bob + int(sin_a * sh*0.44)
            ex2 = bx + int(cos_a * spike_len)
            ey2 = by + int(sin_a * spike_len)
            pygame.draw.line(surface, self.C_SPIKE, (bx, by), (ex2, ey2), max(2, int(s*0.038)))
            # lighter tip
            mid_x = bx + int(cos_a * spike_len * 0.65)
            mid_y = by + int(sin_a * spike_len * 0.65)
            pygame.draw.line(surface, self.C_BACK, (mid_x, mid_y), (ex2, ey2), max(1, int(s*0.022)))

        # --- belly / face area ---
        fcx = _mir(x, s*0.14, d)
        _ec_o(surface, self.C_BELLY, fcx, y+bob, int(s*0.55), int(s*0.44), s)

        # --- snout ---
        snx = _mir(fcx, s*0.22, d)
        _ec_o(surface, self.C_FACE, snx, y+bob+int(s*0.04), int(s*0.22), int(s*0.20), s)

        # --- nose ---
        _circ_o(surface, self.C_NOSE, _mir(snx, s*0.07, d), y+bob+int(s*0.03), max(2, int(s*0.045)), s)

        # --- eye ---
        er = max(4, int(s*0.10))
        _cute_eye(surface, _mir(fcx, s*0.06, d), y+bob-int(s*0.09), er, blink)

        # --- blush ---
        _blush(surface, _mir(fcx, s*0.12, d), y+bob+int(s*0.08), s)

        # --- tiny legs ---
        lw, lh = int(s*0.12), int(s*0.10)
        sw2 = math.sin(self.walk_phase*2)*int(s*0.03) if self.state==self.WALKING else 0
        for i, ox in enumerate([-0.18, 0.0, 0.18]):
            lb = sw2 if i%2==0 else -sw2
            _ec(surface, self.C_BACK, x+int(s*ox), y+int(sh*0.52)+lb+bob, lw, lh)


# ===========================================================================
# SQUIRREL  🐿️
# ===========================================================================

class Squirrel(Animal):
    SPECIES        = "squirrel"
    BASE_SPEED     = 65
    SPEED_VARIANCE = 0.35
    PARTICLE_COLORS = [(178, 138, 95), (165, 108, 60), (200, 185, 150)]
    LOCO_PROFILE   = "dart"
    IDLE_WHITELIST = _UNIVERSAL_IDLES | frozenset({"stand_lookout", "chitter"})

    C_BODY  = (178, 138, 95)
    C_BELLY = (215, 188, 148)
    C_TAIL  = (168, 108, 62)
    C_TAIL2 = (198, 145, 92)
    C_EAR   = (158, 118, 75)

    def draw(self, surface, anim_t):
        x, y, s, d = int(self.x + self._loco_x_offset), int(self.y), self.size, self.direction
        bob = int(self._bob())
        blink = self._blink()
        tail_wave = math.sin(self.anim_t * 2.0) * int(s * 0.10)

        # --- huge fluffy tail (behind body, drawn first) ---
        tcx = _mir(x, -s*0.24, d)
        tcy = y - int(s*0.18) + bob + tail_wave
        tw, th = int(s*0.56), int(s*0.66)
        _ec_o(surface, self.C_TAIL, tcx, tcy, tw, th, s)
        # inner tail fluff
        _ec(surface, self.C_TAIL2, tcx+int(d*-s*0.04), tcy-int(s*0.04), int(tw*0.65), int(th*0.62))
        # tail tip highlight
        _ec(surface, self.C_BELLY, tcx+int(d*-s*0.06), tcy-int(s*0.12), int(tw*0.35), int(th*0.30))

        # --- body (compact oval) ---
        bw, bh = int(s*0.54), int(s*0.52)
        _ec_o(surface, self.C_BODY, x, y+bob, bw, bh, s)

        # --- belly ---
        _ec(surface, self.C_BELLY, x, y+bob+int(s*0.05), int(bw*0.58), int(bh*0.72))

        # --- head (big, with chubby cheeks) ---
        hx = _mir(x, s*0.20, d)
        hy = y - int(s*0.26) + bob
        hr = int(s*0.26)
        _circ_o(surface, self.C_BODY, hx, hy, hr, s)

        # chubby cheek pouches
        for cx_off in [-0.18, 0.18]:
            _ec(surface, self.C_BODY, hx+int(s*cx_off*d), hy+int(s*0.04), int(s*0.14), int(s*0.12))

        # --- ears ---
        for ox in [-0.12, 0.12]:
            ex = hx + int(s*ox*d)
            ey = hy - hr + int(s*0.02)
            er2 = int(s*0.10)
            _circ_o(surface, self.C_EAR, ex, ey, er2, s)
            _circ(surface, self.C_BELLY, ex, ey+int(er2*0.15), max(2, int(er2*0.52)))

        # --- eyes ---
        er = max(5, int(s*0.12))
        for ox in [-0.09, 0.09]:
            _cute_eye(surface, hx+int(s*ox*d), hy-int(s*0.03), er, blink)

        # --- blush ---
        _blush(surface, hx+int(d*-s*0.16), hy+int(s*0.07), s)
        _blush(surface, hx+int(d* s*0.16), hy+int(s*0.07), s)

        # --- nose ---
        _circ_o(surface, (68, 42, 28), hx+int(d*s*0.08), hy+int(s*0.07), max(2, int(s*0.04)), s)

        # --- paws ---
        sw2 = math.sin(self.walk_phase*2)*int(s*0.05) if self.state==self.WALKING else 0
        for i, ox in enumerate([-0.20, 0.20]):
            lb = sw2 if i==0 else -sw2
            _ec_o(surface, self.C_EAR, x+int(s*ox), y+int(bh*0.52)+lb+bob, int(s*0.13), int(s*0.13), s)


# ===========================================================================
# OTTER  🦦
# ===========================================================================

class Otter(Animal):
    SPECIES        = "otter"
    BASE_SPEED     = 55
    SIZE_SCALE     = 1.05
    PARTICLE_COLORS = [(125, 85, 55), (192, 158, 125), (215, 195, 168)]
    LOCO_PROFILE   = "slide"
    IDLE_WHITELIST = _UNIVERSAL_IDLES | frozenset({"belly_roll"})

    C_BODY  = (125, 85, 55)
    C_BELLY = (192, 158, 125)
    C_MUZZ  = (175, 145, 115)
    C_NOSE  = (75, 48, 35)

    def draw(self, surface, anim_t):
        x, y, s, d = int(self.x + self._loco_x_offset), int(self.y), self.size, self.direction
        bob = int(self._bob())
        blink = self._blink()

        # --- tail ---
        tx = _mir(x, -s*0.40, d)
        _ec_o(surface, self.C_BODY, tx, y+bob+int(s*0.10), int(s*0.22), int(s*0.16), s)

        # --- body (elongated, chubby) ---
        bw, bh = int(s*0.82), int(s*0.46)
        _ec_o(surface, self.C_BODY, x, y+bob, bw, bh, s)

        # --- belly (light patch) ---
        _ec(surface, self.C_BELLY, x, y+bob+int(s*0.05), int(bw*0.58), int(bh*0.78))

        # --- head (round) ---
        hx = _mir(x, s*0.30, d)
        hy = y - int(s*0.16) + bob
        hr = int(s*0.24)
        _circ_o(surface, self.C_BODY, hx, hy, hr, s)

        # --- muzzle ---
        mx = _mir(hx, s*0.18, d)
        my = hy + int(s*0.05)
        _ec_o(surface, self.C_MUZZ, mx, my, int(s*0.24), int(s*0.20), s)

        # --- nose ---
        _circ_o(surface, self.C_NOSE, _mir(mx, s*0.06, d), my-int(s*0.03), max(3, int(s*0.05)), s)

        # --- whiskers ---
        _whiskers(surface, mx, my, s, d)

        # --- eyes ---
        er = max(5, int(s*0.11))
        _cute_eye(surface, _mir(hx, -s*0.05, d), hy-int(s*0.07), er, blink)

        # --- blush ---
        _blush(surface, _mir(hx, -s*0.14, d), hy+int(s*0.05), s)

        # --- ears (small round) ---
        for ox in [-0.12, 0.12]:
            ex = hx + int(s*ox*d)
            _circ_o(surface, self.C_BODY, ex, hy-hr+int(s*0.02), int(s*0.075), s)

        # --- paws ---
        sw2 = math.sin(self.walk_phase*2)*int(s*0.04) if self.state==self.WALKING else 0
        for i, ox in enumerate([-0.28, -0.08, 0.08, 0.28]):
            lb = sw2 if i%2==0 else -sw2
            _ec_o(surface, self.C_BODY, x+int(s*ox), y+int(bh*0.52)+lb+bob, int(s*0.13), int(s*0.11), s)


# ===========================================================================
# PANDA  🐼
# ===========================================================================

class Panda(Animal):
    SPECIES        = "panda"
    BASE_SPEED     = 34
    SIZE_SCALE     = 1.10
    PARTICLE_COLORS = [(242, 242, 242), (42, 42, 42), (160, 160, 160)]
    LOCO_PROFILE   = "lumber"
    IDLE_WHITELIST = _UNIVERSAL_IDLES | frozenset({"bamboo_sit", "panda_roll"})

    C_WHITE = (242, 242, 242)
    C_BLACK = (42, 42, 42)
    C_GREY  = (180, 180, 185)
    C_NOSE  = (55, 42, 40)

    def draw(self, surface, anim_t):
        x, y, s, d = int(self.x + self._loco_x_offset), int(self.y), self.size, self.direction
        bob = int(self._bob() * 0.65)
        blink = self._blink()

        # --- body (big round white) ---
        bw, bh = int(s*0.74), int(s*0.66)
        _ec_o(surface, self.C_WHITE, x, y+bob, bw, bh, s)

        # --- black arms ---
        for ox in [-0.36, 0.36]:
            _ec_o(surface, self.C_BLACK, x+int(s*ox), y+bob+int(s*0.06), int(s*0.20), int(s*0.26), s)

        # --- black legs ---
        sw2 = math.sin(self.walk_phase*2)*int(s*0.04) if self.state==self.WALKING else 0
        for i, ox in enumerate([-0.24, 0.24]):
            lb = sw2 if i==0 else -sw2
            _ec_o(surface, self.C_BLACK, x+int(s*ox), y+int(bh*0.50)+lb+bob, int(s*0.22), int(s*0.20), s)

        # --- head (big white ball) ---
        hx = _mir(x, s*0.20, d)
        hy = y - int(s*0.30) + bob
        hr = int(s*0.32)
        _circ_o(surface, self.C_WHITE, hx, hy, hr, s)

        # --- black ears ---
        for ox in [-0.18, 0.18]:
            ex = hx + int(s*ox*d)
            _circ_o(surface, self.C_BLACK, ex, hy-hr+int(s*0.04), int(s*0.11), s)

        # --- eye patches (big black ovals, signature panda feature) ---
        for ox in [-0.11, 0.11]:
            px = hx + int(s*ox*d)
            py = hy - int(s*0.03)
            pw, ph = int(s*0.16), int(s*0.14)
            _ec_o(surface, self.C_BLACK, px, py, pw, ph, s)
            # eye inside patch
            er = max(3, int(s*0.052))
            if blink:
                pygame.draw.arc(surface, SHINE,
                                (px-er, py-er//2, er*2, er),
                                0, math.pi, max(1, er//2))
            else:
                _circ(surface, SHINE, px, py, er)
                _circ(surface, PUPIL_COL, px, py, max(1, int(er*0.55)))
                _circ(surface, SHINE, px+max(1,int(er*0.28)), py-max(1,int(er*0.30)), max(1, int(er*0.30)))

        # --- blush ---
        _blush(surface, hx+int(d*-s*0.22), hy+int(s*0.08), s)
        _blush(surface, hx+int(d* s*0.22), hy+int(s*0.08), s)

        # --- nose ---
        _circ_o(surface, self.C_NOSE, hx, hy+int(s*0.10), max(3, int(s*0.055)), s)

        # --- mouth smile ---
        pygame.draw.arc(surface, OUTLINE,
                        (hx-int(s*0.08), hy+int(s*0.11), int(s*0.08), int(s*0.07)),
                        math.pi, 2*math.pi, max(1, int(s*0.025)))
        pygame.draw.arc(surface, OUTLINE,
                        (hx, hy+int(s*0.11), int(s*0.08), int(s*0.07)),
                        math.pi, 2*math.pi, max(1, int(s*0.025)))


# ===========================================================================
# UNICORN  🦄  (super rare — fixed 1/100 spawn rate)
# ===========================================================================

class Unicorn(Animal):
    SPECIES        = "unicorn"
    BASE_SPEED     = 50
    SIZE_SCALE     = 1.05
    LOCO_PROFILE   = "classic"   # glides smoothly
    IDLE_WHITELIST = _UNIVERSAL_IDLES
    PARTICLE_COLORS = [
        (255, 130, 180), (200, 130, 255), (130, 180, 255),
        (130, 255, 180), (255, 240, 130), (255, 180, 130),
    ]

    LEAVES_TRAIL  = True
    TRAIL_PALETTE = [
        (255, 130, 180),  # pink
        (255, 180, 130),  # peach
        (255, 240, 130),  # yellow
        (130, 220, 130),  # mint
        (130, 200, 255),  # sky
        (200, 140, 255),  # lavender
    ]
    TRAIL_RATE = 22
    TRAIL_SIZE = 7
    TRAIL_LIFE = 1.1
    TRAIL_STAR = True

    C_BODY       = (252, 248, 252)   # near-white with a violet hint
    C_SHADE      = (228, 220, 232)
    C_HORN       = (255, 220, 100)
    C_HORN_SHADE = (220, 175, 60)
    C_HOOF       = (170, 140, 200)
    MANE_COLORS  = [
        (255, 130, 180), (255, 180, 130), (255, 240, 130),
        (130, 220, 130), (130, 180, 255), (200, 140, 255),
    ]

    def draw(self, surface, anim_t):
        x, y, s, d = int(self.x + self._loco_x_offset), int(self.y), self.size, self.direction
        bob = int(self._bob() * 0.7)
        blink = self._blink()

        # ----- TAIL (rainbow strands, behind body) -----
        tcx = _mir(x, -s * 0.32, d)
        tcy = y + int(s * 0.04) + bob
        for i, col in enumerate(self.MANE_COLORS):
            f = (i / (len(self.MANE_COLORS) - 1)) - 0.5  # -0.5 .. 0.5
            sway = math.sin(self.anim_t * 2.0 + i * 0.55) * s * 0.04
            pts = []
            for j in range(8):
                jf = j / 7.0
                tx = tcx + int(d * (-s * 0.24) * jf + sway * jf)
                ty = tcy + int(jf * s * 0.20 + f * s * 0.06
                               + math.sin(jf * math.pi) * s * 0.025)
                pts.append((tx, ty))
            pygame.draw.lines(surface, col, False, pts, max(2, int(s * 0.045)))

        # ----- BODY -----
        bw, bh = int(s * 0.66), int(s * 0.42)
        _ec_o(surface, self.C_BODY, x, y + bob, bw, bh, s)
        _ec(surface, self.C_SHADE,
            x - int(d * s * 0.04), y + bob + int(s * 0.06),
            int(bw * 0.50), int(bh * 0.40))

        # ----- LEGS (4 with hooves) -----
        leg_w, leg_h = int(s * 0.10), int(s * 0.20)
        sw2 = (math.sin(self.walk_phase * 2) * int(s * 0.04)
               if self.state == self.WALKING else 0)
        for i, ox in enumerate([-0.24, -0.08, 0.08, 0.24]):
            lb = sw2 if i % 2 == 0 else -sw2
            lx = x + int(s * ox)
            ly = y + int(bh * 0.40) + bob + lb
            _ec_o(surface, self.C_BODY, lx, ly, leg_w, leg_h, s)
            _ec(surface, self.C_HOOF,
                lx, ly + int(leg_h * 0.40), leg_w, int(leg_h * 0.30))

        # ----- HEAD -----
        hx = _mir(x, s * 0.30, d)
        hy = y - int(s * 0.20) + bob
        hr = int(s * 0.22)
        _circ_o(surface, self.C_BODY, hx, hy, hr, s)

        # ----- SNOUT -----
        snx = _mir(hx, s * 0.16, d)
        sny = hy + int(s * 0.06)
        _ec_o(surface, self.C_BODY, snx, sny, int(s * 0.18), int(s * 0.13), s)
        # nostril
        _circ(surface, (210, 165, 200),
              _mir(snx, s * 0.06, d), sny - int(s * 0.01),
              max(2, int(s * 0.022)))
        # smile
        pygame.draw.arc(surface, OUTLINE,
                        (_mir(snx, -s * 0.04, d), sny + int(s * 0.02),
                         int(s * 0.10), int(s * 0.06)),
                        math.pi, 2 * math.pi, max(1, int(s * 0.022)))

        # ----- EARS -----
        for ox in [-0.07, 0.07]:
            ex0 = hx + int(d * s * ox)
            ey0 = hy - hr + int(s * 0.04)
            _ec_o(surface, self.C_BODY,
                  ex0, ey0 - int(s * 0.06),
                  int(s * 0.07), int(s * 0.13), s)

        # ----- HORN (golden cone with spirals) -----
        horn_base_x = hx + int(d * s * 0.02)
        horn_base_y = hy - hr + int(s * 0.02)
        horn_tip_x  = horn_base_x + int(d * s * 0.05)
        horn_tip_y  = horn_base_y - int(s * 0.30)
        horn_pts = [
            (horn_base_x - int(d * s * 0.04), horn_base_y),
            (horn_base_x + int(d * s * 0.04), horn_base_y),
            (horn_tip_x, horn_tip_y),
        ]
        _poly_o(surface, self.C_HORN, horn_pts, s)
        # spiral lines (3 chevrons up the horn)
        for i in range(3):
            f = (i + 1) / 4.0
            sxh = horn_base_x + int((horn_tip_x - horn_base_x) * f)
            syh = horn_base_y + int((horn_tip_y - horn_base_y) * f)
            wide = int(s * 0.04 * (1 - f))
            pygame.draw.line(surface, self.C_HORN_SHADE,
                             (sxh - wide, syh), (sxh + wide, syh),
                             max(1, int(s * 0.020)))

        # ----- MANE (rainbow strands behind head, down neck) -----
        mane_x = hx - int(d * s * 0.06)
        mane_y = hy - int(s * 0.04)
        for i, col in enumerate(self.MANE_COLORS):
            f = i / (len(self.MANE_COLORS) - 1)
            ox_ = -d * (s * 0.06 + f * s * 0.20)
            sxm = mane_x + int(ox_)
            sym = mane_y + int(f * s * 0.06) - int(s * 0.04)
            exm = sxm + int(-d * s * 0.04)
            eym = sym + int(s * 0.18)
            pygame.draw.line(surface, col, (sxm, sym), (exm, eym),
                             max(2, int(s * 0.05)))

        # ----- EYE -----
        er = max(5, int(s * 0.10))
        _cute_eye(surface, _mir(hx, -s * 0.04, d),
                  hy - int(s * 0.02), er, blink)

        # ----- BLUSH -----
        _blush(surface, _mir(hx, -s * 0.12, d), hy + int(s * 0.10), s)

        # ----- HORN SPARKLE (twinkles) -----
        sparkle = (math.sin(self.anim_t * 4.5) * 0.5 + 0.5)
        sr = max(1, int(s * 0.030 * (0.4 + sparkle)))
        if sr > 0:
            _circ(surface, (255, 255, 220),
                  horn_tip_x + int(d * s * 0.015),
                  horn_tip_y - int(s * 0.015), sr)


# ===========================================================================
# GOLDEN KITTEN  ✨🐱  (legendary — fixed 1/1000 spawn rate)
# ===========================================================================

class GoldenKitten(Kitten):
    SPECIES    = "golden_kitten"
    BASE_SPEED = 60
    SIZE_SCALE = 1.05
    PARTICLE_COLORS = [
        (255, 220, 100), (255, 240, 180),
        (255, 200, 60),  (255, 255, 220),
    ]

    LEAVES_TRAIL  = True
    TRAIL_PALETTE = [
        (255, 220, 100),  # gold
        (255, 240, 180),  # pale gold
        (255, 200, 60),   # deep gold
        (255, 255, 220),  # white-gold
    ]
    TRAIL_RATE = 18
    TRAIL_SIZE = 7
    TRAIL_LIFE = 1.0
    TRAIL_STAR = True

    # Override Kitten palette with a glowy-gold scheme
    C_BODY   = (255, 215, 100)
    C_HEAD   = (255, 230, 130)
    C_EAR    = (220, 175, 60)
    C_INNER  = (255, 195, 195)
    C_STRIPE = (220, 170, 50)
    C_NOSE   = (255, 140, 148)

    C_CROWN     = (255, 220, 80)
    C_CROWN_GEM = (255, 100, 130)

    def draw(self, surface, anim_t):
        # Draw the kitten with golden palette
        super().draw(surface, anim_t)

        x, y, s, d = int(self.x + self._loco_x_offset), int(self.y), self.size, self.direction
        bob = int(self._bob())

        # ----- CROWN above the head -----
        hx = _mir(x, s * 0.22, d)
        hy = y - int(s * 0.26) + bob
        hr = int(s * 0.32)
        cx = hx
        cy = hy - hr - int(s * 0.04)
        cw = int(s * 0.30)
        ch = int(s * 0.13)
        # 3-point spiked crown
        c_pts = [
            (cx - cw // 2,    cy + ch),
            (cx - cw // 2,    cy + ch // 3),
            (cx - cw // 4,    cy + ch),
            (cx,              cy - ch // 2),
            (cx + cw // 4,    cy + ch),
            (cx + cw // 2,    cy + ch // 3),
            (cx + cw // 2,    cy + ch),
        ]
        _poly_o(surface, self.C_CROWN, c_pts, s)
        # Centre gem
        _circ(surface, self.C_CROWN_GEM, cx, cy + ch // 2,
              max(2, int(s * 0.028)))

        # ----- Floating sparkles around the kitten -----
        spark_t = self.anim_t * 2.4
        for i in range(4):
            ang = spark_t + i * (math.pi * 2 / 4)
            sx_ = x + int(math.cos(ang) * s * 0.50)
            sy_ = y + int(math.sin(ang) * s * 0.42) + bob
            sr  = max(1, int(s * 0.030 *
                              (0.4 + 0.6 * math.sin(spark_t * 1.7 + i))))
            if sr > 0:
                # Tiny 4-point spark
                pygame.draw.line(surface, (255, 250, 200),
                                 (sx_ - sr, sy_), (sx_ + sr, sy_), 1)
                pygame.draw.line(surface, (255, 250, 200),
                                 (sx_, sy_ - sr), (sx_, sy_ + sr), 1)
                _circ(surface, (255, 250, 200), sx_, sy_, max(1, sr // 2))


# ---------------------------------------------------------------------------
# Registry
# ---------------------------------------------------------------------------

ANIMAL_CLASSES = {
    "kitten":        Kitten,
    "turtle":        Turtle,
    "duck":          Duck,
    "rabbit":        Rabbit,
    "hedgehog":      Hedgehog,
    "squirrel":      Squirrel,
    "otter":         Otter,
    "panda":         Panda,
    "unicorn":       Unicorn,
    "golden_kitten": GoldenKitten,
}


def create_animal(species, x, y, size, screen_w, screen_h,
                  direction=None, perimeter_walker=False):
    cls = ANIMAL_CLASSES.get(species, Kitten)
    return cls(x, y, size, screen_w, screen_h, direction, perimeter_walker)
