"""
split_sprites.py — Splits 2x2 sprite sheets into 4 individual PNGs
Usage: python split_sprites.py

Place your sprite sheet images in the same folder as this script,
named like: turtle_sheet.png, duck_sheet.png, etc.

Output goes into: assets/
  turtle_idle_1.png  (top-left)
  turtle_idle_2.png  (top-right)
  turtle_walk_1.png  (bottom-left)
  turtle_walk_2.png  (bottom-right)
"""

from PIL import Image
import os

# ---------------------------------------------------------------------------
# Config — add a new entry for each sprite sheet you drop in
# ---------------------------------------------------------------------------
SHEETS = {
    "turtle_sheet.png": "turtle",
    "duck_sheet.png":   "duck",
    "rabbit_sheet.png": "rabbit",
    "hedgehog_sheet.png": "hedgehog",
    "kitten_sheet.png": "kitten",
    "squirrel_sheet.png": "squirrel",
    "otter_sheet.png":  "otter",
    "panda_sheet.png":  "panda",
    "unicorn_sheet.png": "unicorn",
    "golden_kitten_sheet.png": "golden_kitten",
}

FRAME_NAMES = ["idle_1", "idle_2", "walk_1", "walk_2"]

# Grid positions: (col, row) where col/row are 0 or 1
GRID_POSITIONS = [
    (0, 0),  # top-left    → idle_1
    (1, 0),  # top-right   → idle_2
    (0, 1),  # bottom-left → walk_1
    (1, 1),  # bottom-right→ walk_2
]

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "assets")
os.makedirs(OUTPUT_DIR, exist_ok=True)

# ---------------------------------------------------------------------------

def split_sheet(sheet_path: str, animal_name: str):
    img = Image.open(sheet_path).convert("RGBA")
    w, h = img.size
    cell_w, cell_h = w // 2, h // 2

    print(f"\n{animal_name} — {w}×{h}px → cells {cell_w}×{cell_h}px")

    for (col, row), frame_name in zip(GRID_POSITIONS, FRAME_NAMES):
        left   = col * cell_w
        upper  = row * cell_h
        right  = left + cell_w
        lower  = upper + cell_h

        cell = img.crop((left, upper, right, lower))

        # Auto-crop transparent/white padding so the critter fills the frame
        cell = autocrop(cell)

        out_name = f"{animal_name}_{frame_name}.png"
        out_path = os.path.join(OUTPUT_DIR, out_name)
        cell.save(out_path, "PNG")
        print(f"  ✓ {out_name}  ({cell.width}×{cell.height}px)")


def autocrop(img: Image.Image, padding: int = 8) -> Image.Image:
    """Trim white/transparent background, add a small padding border."""
    # Convert to RGBA if needed
    img = img.convert("RGBA")
    data = img.getdata()

    # Find bounding box of non-white, non-transparent pixels
    xs, ys = [], []
    for idx, (r, g, b, a) in enumerate(data):
        if a > 20 and not (r > 230 and g > 230 and b > 230):
            x = idx % img.width
            y = idx // img.width
            xs.append(x)
            ys.append(y)

    if not xs:
        return img  # nothing found, return as-is

    left   = max(0, min(xs) - padding)
    upper  = max(0, min(ys) - padding)
    right  = min(img.width,  max(xs) + padding)
    lower  = min(img.height, max(ys) + padding)

    return img.crop((left, upper, right, lower))


# ---------------------------------------------------------------------------

script_dir = os.path.dirname(os.path.abspath(__file__))

found_any = False
for filename, animal_name in SHEETS.items():
    sheet_path = os.path.join(script_dir, filename)
    if os.path.exists(sheet_path):
        found_any = True
        split_sheet(sheet_path, animal_name)
    else:
        print(f"  (skipping {filename} — not found)")

if found_any:
    print(f"\nDone! PNGs saved to: {OUTPUT_DIR}")
else:
    print("\nNo sheet files found. Name your images like 'turtle_sheet.png' and put them next to this script.")
