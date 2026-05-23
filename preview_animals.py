"""
preview_animals.py — Live animation preview for all 8 built-in species.

Run from the project root (vigorous-tesla worktree):
    python preview_animals.py

All species walk and animate in real time within their own cells, using the
full locomotion + behaviour system — exactly as they behave in game.

Controls:
    Click any cell   — immediately trigger that species' signature move
    ESC              — quit

Hot-reload: edit src/animals.py, src/locomotion.py, or src/behaviours.py and
save — the window updates within one frame without restarting.
"""

import os
import sys
import importlib

_ROOT = os.path.dirname(os.path.abspath(__file__))
os.chdir(_ROOT)
sys.path.insert(0, os.path.join(_ROOT, "src"))

import pygame
import animals as animals_mod
import locomotion as locomotion_mod
import behaviours as behaviours_mod
from behaviours import BehaviourEvaluator
from time_of_day import get_time_of_day_state


# ---------------------------------------------------------------------------
# Layout constants
# ---------------------------------------------------------------------------

COLS       = 4
CELL_W     = 300
CELL_H     = 220
HEADER_H   = 38
CRITTER_SZ = 80

BG        = (15, 15, 26)
CELL_BG   = (22, 22, 40)
CELL_BD   = (42, 42, 72)      # cell border (normal)
CELL_HOV  = (110, 130, 220)   # cell border (hover)
CELL_ACT  = (80, 220, 160)    # cell border (behaviour active)
LBL_COL   = (155, 170, 215)
ST_WALK   = (90, 110, 160)    # state label: walking/idle
ST_BURST  = (255, 200, 80)    # state label: burst active
ST_BEHAV  = (80, 220, 160)    # state label: behaviour active
HOT_COL   = (255, 210, 70)

SPECIES_ORDER = [
    "kitten", "turtle", "duck",    "rabbit",
    "hedgehog", "squirrel", "otter", "panda",
]

# Config used by the behaviour evaluator in preview mode
_PREVIEW_CFG = {
    "behaviour": {
        "interactions_enabled": False,   # no cross-cell pair interactions
        "behaviour_frequency":  2.0,     # fire idles more often for visibility
        "day_night_enabled":    True,    # use real system clock
    }
}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _cls_map():
    """Return {species_name: class} from the current animals_mod."""
    classes = [
        animals_mod.Kitten,   animals_mod.Turtle,  animals_mod.Duck,
        animals_mod.Rabbit,   animals_mod.Hedgehog, animals_mod.Squirrel,
        animals_mod.Otter,    animals_mod.Panda,
    ]
    return {cls.SPECIES: cls for cls in classes}


def _make_critter(cls):
    """Create a fresh critter starting at the centre of its cell."""
    cx, cy = CELL_W // 2, CELL_H // 2
    c = cls(cx, cy, CRITTER_SZ, CELL_W, CELL_H, direction=1)
    c.state = animals_mod.Animal.WALKING
    return c


def _trigger_special(c):
    """Immediately trigger the signature move for this species."""
    # Burst species: force one burst cycle
    if c.BURST_PROFILE:
        c.loco_profile     = c.BURST_PROFILE
        c.loco_phase       = 0.0
        c._burst_remaining = c.BURST_DURATION
        return
    # Behaviour species: enter their signature behaviour directly
    triggers = {
        "hedgehog": ("ball_up",       2.0),
        "panda":    ("panda_roll",    2.0),
        "otter":    ("belly_roll",    2.5),
        "turtle":   ("head_tuck",     2.5),
        "duck":     ("preen",         2.5),
        "rabbit":   ("stand_lookout", 2.0),
    }
    name, dur = triggers.get(c.SPECIES, ("sit_and_look", 2.0))
    # Clear any current behaviour first
    if c.behaviour_name is not None:
        c._exit_behaviour()
    c.enter_behaviour(name, dur)


def _cell_rect(idx):
    row, col = divmod(idx, COLS)
    return pygame.Rect(col * CELL_W, HEADER_H + row * CELL_H, CELL_W, CELL_H)


def _cell_at(mx, my):
    """Return the cell index (0-based) under pixel (mx, my), or None."""
    if my < HEADER_H:
        return None
    col = mx // CELL_W
    row = (my - HEADER_H) // CELL_H
    idx = row * COLS + col
    return idx if 0 <= idx < len(SPECIES_ORDER) else None


def _state_label(c):
    """Short string describing the critter's current animation state."""
    if c.behaviour_name:
        return c.behaviour_name
    if c.loco_profile != c.LOCO_PROFILE:
        return f"[{c.loco_profile}]"
    return c.state


def _state_colour(c):
    if c.behaviour_name:
        return ST_BEHAV
    if c.loco_profile != c.LOCO_PROFILE:
        return ST_BURST
    return ST_WALK


# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------

def main():
    pygame.init()

    rows  = len(SPECIES_ORDER) // COLS
    win_w = COLS * CELL_W
    win_h = HEADER_H + rows * CELL_H
    screen = pygame.display.set_mode((win_w, win_h))
    pygame.display.set_caption("Animal preview  —  click to trigger  |  edit src/ to hot-reload")
    clock = pygame.time.Clock()

    font_hdr = pygame.font.SysFont("Segoe UI", 14)
    font_lbl = pygame.font.SysFont("Segoe UI", 15, bold=True)
    font_st  = pygame.font.SysFont("Segoe UI", 12)

    # ── Hot-reload: watch these source files ─────────────────────────────────
    _watch = ["animals.py", "locomotion.py", "behaviours.py"]
    _src   = os.path.join(_ROOT, "src")
    _mtimes = {}
    for f in _watch:
        try:
            _mtimes[f] = os.path.getmtime(os.path.join(_src, f))
        except OSError:
            _mtimes[f] = 0.0

    # ── Initial critters ─────────────────────────────────────────────────────
    cmap     = _cls_map()
    critters = [_make_critter(cmap[sp]) for sp in SPECIES_ORDER]

    evaluator    = BehaviourEvaluator()
    reload_flash = 0.0   # seconds remaining for hot-reload flash message

    running = True
    while running:
        dt = min(clock.tick(60) / 1000.0, 0.05)

        # ── Hot-reload check ──────────────────────────────────────────────────
        for fname in _watch:
            fpath = os.path.join(_src, fname)
            try:
                mt = os.path.getmtime(fpath)
            except OSError:
                continue
            if mt != _mtimes[fname]:
                _mtimes[fname] = mt
                try:
                    importlib.reload(locomotion_mod)
                    importlib.reload(animals_mod)
                    importlib.reload(behaviours_mod)
                    cmap = _cls_map()
                    new_critters = []
                    for i, sp in enumerate(SPECIES_ORDER):
                        old = critters[i]
                        nc  = _make_critter(cmap[sp])
                        nc.x, nc.y   = old.x, old.y
                        nc.direction = old.direction
                        new_critters.append(nc)
                    critters     = new_critters
                    evaluator    = BehaviourEvaluator()
                    reload_flash = 2.5
                    print(f"[hot-reload] {fname} reloaded OK")
                except Exception as e:
                    print(f"[hot-reload] {fname} error: {e}")

        # ── Events ────────────────────────────────────────────────────────────
        mx, my = pygame.mouse.get_pos()
        hover_idx = _cell_at(mx, my)

        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
            elif event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
                idx = _cell_at(event.pos[0], event.pos[1])
                if idx is not None:
                    _trigger_special(critters[idx])

        # ── Update critters ───────────────────────────────────────────────────
        for c in critters:
            c.update(dt, [])

        # ── Behaviour evaluator (1s tick, solo idles only) ────────────────────
        activity, _spawn, sleep_bias = get_time_of_day_state(_PREVIEW_CFG)
        evaluator.tick(dt, critters, activity, sleep_bias, _PREVIEW_CFG)

        # ── Draw ──────────────────────────────────────────────────────────────
        screen.fill(BG)

        # Header bar
        hint = font_hdr.render(
            "click = trigger special  ·  edit src/ files to hot-reload  ·  ESC = quit",
            True, LBL_COL,
        )
        screen.blit(hint, (10, (HEADER_H - hint.get_height()) // 2))
        if reload_flash > 0:
            reload_flash -= dt
            flash = font_hdr.render("⟳ reloaded", True, HOT_COL)
            screen.blit(flash, (win_w - flash.get_width() - 10,
                                (HEADER_H - flash.get_height()) // 2))

        # Cells
        for idx, (sp, c) in enumerate(zip(SPECIES_ORDER, critters)):
            rect = _cell_rect(idx)

            # Critter surface
            surf = pygame.Surface((CELL_W, CELL_H))
            surf.fill(CELL_BG)
            c.draw(surf, c.anim_t)
            screen.blit(surf, rect.topleft)

            # Border: active behaviour → green, hover → blue, idle → dim
            if c.behaviour_name or c.loco_profile != c.LOCO_PROFILE:
                bd = CELL_ACT
            elif idx == hover_idx:
                bd = CELL_HOV
            else:
                bd = CELL_BD
            pygame.draw.rect(screen, bd, rect, 1)

            # Species label (top-left inside cell)
            lbl = font_lbl.render(sp, True, LBL_COL)
            screen.blit(lbl, (rect.x + 6, rect.y + 5))

            # State label (bottom-left inside cell)
            st_str = _state_label(c)
            st_col = _state_colour(c)
            st = font_st.render(st_str, True, st_col)
            screen.blit(st, (rect.x + 6, rect.bottom - st.get_height() - 5))

        pygame.display.flip()

    pygame.quit()


if __name__ == "__main__":
    main()
