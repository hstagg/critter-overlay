"""
preview_auras.py — Live aura design preview for all rarity tiers.

Run from the project root (vigorous-tesla worktree):
    python preview_auras.py

- All 4 non-Common tiers shown side by side, animating in real time.
- Press 1-0 to switch the displayed critter species.
- Edit src/auras.py and save — the window updates within one frame automatically.
- Dark background so aura colours read clearly (no chroma-key weirdness).
"""

import os
import sys
import importlib

_ROOT = os.path.dirname(os.path.abspath(__file__))
os.chdir(_ROOT)   # make all relative paths work regardless of launch directory
sys.path.insert(0, os.path.join(_ROOT, "src"))

import pygame
import animals as animals_mod
import auras as auras_mod
from rarity import RarityTier


# ---------------------------------------------------------------------------
# Layout
# ---------------------------------------------------------------------------

CELL_W       = 210
CELL_H       = 210
PAD          = 20
CRITTER_SIZE = 90   # passed to Animal.__init__; actual size = max(60, int(90 * SIZE_SCALE))
HEADER_H     = 34
FOOTER_H     = 28
BG           = (18, 18, 30)
CELL_BG      = (26, 26, 44)

TIERS = [
    (RarityTier.UNCOMMON,  "Uncommon",  (160, 185, 255)),
    (RarityTier.RARE,      "Rare",      (255, 210, 80)),
    (RarityTier.EPIC,      "Epic",      (210, 160, 255)),
    (RarityTier.LEGENDARY, "Legendary", (255, 130, 130)),
]

SPECIES = [
    ("Kitten",       lambda: animals_mod.Kitten),
    ("Turtle",       lambda: animals_mod.Turtle),
    ("Duck",         lambda: animals_mod.Duck),
    ("Rabbit",       lambda: animals_mod.Rabbit),
    ("Hedgehog",     lambda: animals_mod.Hedgehog),
    ("Squirrel",     lambda: animals_mod.Squirrel),
    ("Otter",        lambda: animals_mod.Otter),
    ("Panda",        lambda: animals_mod.Panda),
    ("Unicorn",      lambda: animals_mod.Unicorn),
    ("GoldenKitten", lambda: animals_mod.GoldenKitten),
]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _make_critter(cls, tier):
    """Instantiate a critter frozen at the centre of a CELL_W x CELL_H surface."""
    cx = CELL_W // 2
    cy = CELL_H // 2
    c = cls(cx, cy, CRITTER_SIZE, 9999, 9999, direction=1)
    c.state     = animals_mod.Animal.WALKING
    c.anim_t    = 0.0
    c.rarity    = tier
    return c


def _reload_auras():
    """Reload auras module from disk. Returns new mtime."""
    path = os.path.join("src", "auras.py")
    try:
        importlib.reload(auras_mod)
    except Exception as e:
        print(f"[aura reload error] {e}")
    try:
        return os.path.getmtime(path)
    except OSError:
        return 0.0


# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------

def main():
    pygame.init()

    font_header = pygame.font.SysFont("Segoe UI", 17, bold=True)
    font_footer = pygame.font.SysFont("Segoe UI", 13)
    font_key    = pygame.font.SysFont("Segoe UI", 12)

    n = len(TIERS)
    win_w = PAD + n * (CELL_W + PAD)
    win_h = HEADER_H + PAD + CELL_H + PAD + FOOTER_H
    screen = pygame.display.set_mode((win_w, win_h))
    pygame.display.set_caption("Aura preview  —  edit src/auras.py to hot-reload")
    clock = pygame.time.Clock()

    species_idx = 0
    anim_t      = 0.0
    auras_mtime = os.path.getmtime(os.path.join("src", "auras.py"))

    def build_critters():
        cls = SPECIES[species_idx][1]()
        return [_make_critter(cls, tier) for tier, *_ in TIERS]

    critters = build_critters()

    while True:
        dt = clock.tick(60) / 1000.0

        # ---- events ----
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pygame.quit()
                return
            if event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    pygame.quit()
                    return
                idx = event.key - pygame.K_1   # K_1=0, K_2=1, …, K_0=9 (pygame.K_0 = K_1+9)
                if event.key == pygame.K_0:
                    idx = 9
                if 0 <= idx < len(SPECIES):
                    species_idx = idx
                    critters = build_critters()

        # ---- hot-reload auras.py ----
        try:
            mt = os.path.getmtime(os.path.join("src", "auras.py"))
            if mt != auras_mtime:
                auras_mtime = _reload_auras()
                print("[auras.py reloaded]")
        except OSError:
            pass

        anim_t += dt

        # ---- draw ----
        screen.fill(BG)

        # Tier column headers
        for i, (tier, label, col) in enumerate(TIERS):
            cx = PAD + i * (CELL_W + PAD)
            surf = font_header.render(label, True, col)
            screen.blit(surf, (cx + CELL_W // 2 - surf.get_width() // 2, (HEADER_H - surf.get_height()) // 2))

        # Critter cells
        for i, (critter, (tier, label, col)) in enumerate(zip(critters, TIERS)):
            cx = PAD + i * (CELL_W + PAD)
            cy = HEADER_H + PAD

            cell = pygame.Surface((CELL_W, CELL_H))
            cell.fill(CELL_BG)

            critter.anim_t    = anim_t
            critter.walk_phase = anim_t * 2.5
            critter.x = CELL_W // 2
            critter.y = CELL_H // 2

            auras_mod.draw_aura(cell, CELL_W // 2, CELL_H // 2,
                                critter.size, tier, anim_t)
            critter.draw(cell, anim_t)

            screen.blit(cell, (cx, cy))

        # Footer: species name + key hints
        sp_name = SPECIES[species_idx][0]
        hint = f"  ·  1–9, 0 to switch species"
        footer = font_footer.render(sp_name + hint, True, (130, 130, 155))
        screen.blit(footer, (PAD, HEADER_H + PAD + CELL_H + (FOOTER_H - footer.get_height()) // 2))

        pygame.display.flip()


if __name__ == "__main__":
    main()
