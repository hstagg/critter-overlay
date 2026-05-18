"""
make_icon.py  —  Generate installer/icon.ico from the paw-print design.

Run once (or whenever you want to update the icon):
    python make_icon.py

Output: installer/icon.ico  (multi-size ICO: 16, 24, 32, 48, 64, 128, 256 px)

The design mirrors the tray icon in main.py so the installer, exe, and tray
all share the same visual identity.
"""

import os
from PIL import Image, ImageDraw


def _make_paw(size: int) -> Image.Image:
    """Draw a green paw print at the given square size."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # Scale from the reference 64 px tray-icon geometry
    s = size / 64.0

    pad = (80,  200, 100, 255)   # green main pad
    toe = (120, 230, 140, 255)   # slightly lighter toes

    # Main pad (large teardrop ellipse, lower half of icon)
    d.ellipse([int(14 * s), int(32 * s), int(50 * s), int(60 * s)], fill=pad)

    # Three toe beans arranged in an arc above the pad
    d.ellipse([int( 6 * s), int(18 * s), int(24 * s), int(34 * s)], fill=toe)  # left
    d.ellipse([int(22 * s), int(10 * s), int(42 * s), int(28 * s)], fill=toe)  # centre
    d.ellipse([int(40 * s), int(18 * s), int(58 * s), int(34 * s)], fill=toe)  # right

    return img


def main() -> None:
    out_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "installer")
    os.makedirs(out_dir, exist_ok=True)

    sizes = [16, 24, 32, 48, 64, 128, 256]
    images = [_make_paw(s) for s in sizes]

    ico_path = os.path.join(out_dir, "icon.ico")
    # PIL writes a proper multi-resolution ICO when given a list of sizes
    images[0].save(
        ico_path,
        format="ICO",
        sizes=[(s, s) for s in sizes],
        append_images=images[1:],
    )
    print(f"Icon written to {ico_path}  ({len(sizes)} sizes: {sizes})")


if __name__ == "__main__":
    main()
