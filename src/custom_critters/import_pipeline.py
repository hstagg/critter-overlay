"""
import_pipeline.py — Full import pipeline for custom critters.

Accepts a file path (PNG, JPG, or animated GIF) and produces a fully
populated critter folder under custom_dir. Returns the critter ID on
success, or raises ImportError with a plain-English message on failure.

Call flow:
  run_import(path, name, custom_dir) -> critter_id          (one-shot)

Preview-before-commit flow:
  pil_frames, method = prepare_frames(path)                 (no disk I/O)
  critter_id = run_import_from_prepared(pil_frames, method, name, custom_dir)
"""

from __future__ import annotations

import hashlib
import os
import shutil
from pathlib import Path

from PIL import Image, ImageSequence

from custom_critters.bg_removal import remove_background
from custom_critters.masks import generate_and_save_masks
from custom_critters.palette import extract_palette
from custom_critters.procedural import generate_frames
from custom_critters.storage import (
    create_critter_folder,
    default_meta,
    frames_dir,
    generate_critter_id,
    write_meta,
)

CANONICAL_SIZE = 120   # px — frames are stored at this size
MAX_FILE_MB    = 10
MAX_DIM        = 2048
MIN_DIM        = 32
MAX_GIF_FRAMES = 30


# ---------------------------------------------------------------------------
# Preview-before-commit entry points
# ---------------------------------------------------------------------------

def prepare_frames(src_path: str | Path) -> tuple[list, str]:
    """
    Run the image-processing pipeline without writing anything to disk.
    Returns (pil_frames, method) ready to pass to run_import_from_prepared().
    Raises ImportError with a user-facing message on failure.
    """
    src_path = Path(src_path)
    _validate_file(src_path)
    ext = src_path.suffix.lower()
    if ext == ".gif":
        pil_frames, method = _load_gif(src_path)
    else:
        pil_frames, method = _load_static(src_path)
    pil_frames = _crop_and_fit(pil_frames)
    _validate_content(pil_frames[0])
    return pil_frames, method


def run_import_from_prepared(pil_frames: list, method: str,
                             name: str, custom_dir: Path) -> str:
    """
    Commit already-processed frames to disk.  Call after prepare_frames()
    and optional user preview/confirmation.  Returns critter_id.
    """
    import hashlib
    critter_id   = generate_critter_id(name)
    critter_path = create_critter_folder(custom_dir, critter_id)

    fd = frames_dir(custom_dir, critter_id)
    for i, frame in enumerate(pil_frames):
        frame.save(str(fd / f"frame_{i}.png"), format="PNG")

    from custom_critters.storage import masks_dir as _masks_dir
    md = _masks_dir(custom_dir, critter_id)
    generate_and_save_masks(pil_frames, md)

    thumb = pil_frames[0].copy()
    thumb.thumbnail((64, 64), Image.LANCZOS)
    thumb64 = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    ox = (64 - thumb.width) // 2
    oy = (64 - thumb.height) // 2
    thumb64.paste(thumb, (ox, oy), thumb)
    thumb64.save(str(critter_path / "thumb.png"), format="PNG")

    palette = extract_palette(pil_frames[0])
    _PRESETS = ["kitten", "turtle", "duck", "rabbit",
                "hedgehog", "squirrel", "otter", "panda"]
    name_hash     = int(hashlib.md5(name.encode()).hexdigest()[:8], 16)
    sound_profile = _PRESETS[name_hash % len(_PRESETS)]
    sound_seed    = name_hash & 0xFFFF

    meta = default_meta(critter_id, name)
    meta.update({
        "frame_count":        len(pil_frames),
        "frame_size":         [CANONICAL_SIZE, CANONICAL_SIZE],
        "import_method":      method,
        "procedural_animation": (method != "animated_gif"),
        "trail_palette":      palette,
        "sound_profile":      sound_profile,
        "sound_seed":         sound_seed,
        "hit_radius_fallback": int(CANONICAL_SIZE * 0.46),
    })
    write_meta(critter_path, meta)
    return critter_id


# ---------------------------------------------------------------------------
# Public entry point (one-shot)
# ---------------------------------------------------------------------------

def run_import(src_path: str | Path, name: str,
               custom_dir: Path) -> str:
    """
    Import an image file as a new custom critter.
    Returns the critter_id string.
    Raises ImportError with a user-friendly message on any problem.
    """
    src_path = Path(src_path)
    _validate_file(src_path)

    ext = src_path.suffix.lower()
    if ext == ".gif":
        pil_frames, method = _load_gif(src_path)
    else:
        pil_frames, method = _load_static(src_path)

    # Common pipeline
    pil_frames = _crop_and_fit(pil_frames)
    _validate_content(pil_frames[0])

    critter_id = generate_critter_id(name)
    critter_path = create_critter_folder(custom_dir, critter_id)

    # Save source
    source_name = "source.gif" if ext == ".gif" else "source.png"
    shutil.copy2(src_path, critter_path / source_name)

    # Save frames
    fd = frames_dir(custom_dir, critter_id)
    for i, frame in enumerate(pil_frames):
        frame.save(str(fd / f"frame_{i}.png"), format="PNG")

    # Generate masks
    from custom_critters.storage import masks_dir as _masks_dir
    md = _masks_dir(custom_dir, critter_id)
    generate_and_save_masks(pil_frames, md)

    # Thumbnail (64×64 from frame 0)
    thumb = pil_frames[0].copy()
    thumb.thumbnail((64, 64), Image.LANCZOS)
    thumb64 = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    ox = (64 - thumb.width) // 2
    oy = (64 - thumb.height) // 2
    thumb64.paste(thumb, (ox, oy), thumb)
    thumb64.save(str(critter_path / "thumb.png"), format="PNG")

    # Palette
    palette = extract_palette(pil_frames[0])

    # Sound profile — deterministic from name hash
    _PRESETS = ["kitten", "turtle", "duck", "rabbit",
                "hedgehog", "squirrel", "otter", "panda"]
    name_hash = int(hashlib.md5(name.encode()).hexdigest()[:8], 16)
    sound_profile = _PRESETS[name_hash % len(_PRESETS)]
    sound_seed = name_hash & 0xFFFF

    # Write meta
    meta = default_meta(critter_id, name)
    meta.update({
        "frame_count": len(pil_frames),
        "frame_size": [CANONICAL_SIZE, CANONICAL_SIZE],
        "import_method": method,
        "procedural_animation": (method != "animated_gif"),
        "source_dimensions": list(Image.open(src_path).size),
        "trail_palette": palette,
        "sound_profile": sound_profile,
        "sound_seed": sound_seed,
        "hit_radius_fallback": int(CANONICAL_SIZE * 0.46),
    })
    write_meta(critter_path, meta)

    return critter_id


# ---------------------------------------------------------------------------
# Second public entry point — multi-frame import
# ---------------------------------------------------------------------------

def run_import_frames(src_paths: list, name: str, custom_dir: Path) -> str:
    """
    Import 2–8 hand-drawn PNG frames as a custom critter animation.
    Returns critter_id.  Raises ImportError with a user-facing message on failure.
    """
    import numpy as np

    src_paths = [Path(p) for p in src_paths]

    if not (2 <= len(src_paths) <= 8):
        raise ImportError("Please provide between 2 and 8 frames.")

    pil_frames = []
    for path in src_paths:
        _validate_file(path)
        try:
            img = Image.open(path)
        except Exception as e:
            raise ImportError(f"Could not open {path.name}: {e}")

        img.load()

        if img.mode == "RGBA":
            rgba = img.convert("RGBA")
            alpha = np.array(rgba)[:, :, 3]
            meaningful = float((alpha < 255).sum()) / alpha.size > 0.01
        else:
            rgba = None
            meaningful = False

        if not meaningful:
            rgba = remove_background(img if rgba is None else img)

        pil_frames.append(rgba)

    # Align all frames to the same global bounding box
    bbox = _global_bbox(pil_frames)
    if bbox:
        pil_frames = [f.crop(bbox) for f in pil_frames]

    pil_frames = _crop_and_fit(pil_frames)
    _validate_content(pil_frames[0])

    critter_id   = generate_critter_id(name)
    critter_path = create_critter_folder(custom_dir, critter_id)

    # Preserve originals for future re-generation
    src_dir = critter_path / "source_frames"
    src_dir.mkdir(exist_ok=True)
    for i, path in enumerate(src_paths):
        shutil.copy2(path, src_dir / f"frame_{i}{path.suffix}")

    fd = frames_dir(custom_dir, critter_id)
    for i, frame in enumerate(pil_frames):
        frame.save(str(fd / f"frame_{i}.png"), format="PNG")

    from custom_critters.storage import masks_dir as _masks_dir
    md = _masks_dir(custom_dir, critter_id)
    generate_and_save_masks(pil_frames, md)

    thumb = pil_frames[0].copy()
    thumb.thumbnail((64, 64), Image.LANCZOS)
    thumb64 = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    ox = (64 - thumb.width) // 2
    oy = (64 - thumb.height) // 2
    thumb64.paste(thumb, (ox, oy), thumb)
    thumb64.save(str(critter_path / "thumb.png"), format="PNG")

    palette    = extract_palette(pil_frames[0])
    name_hash  = int(hashlib.md5(name.encode()).hexdigest()[:8], 16)
    _PRESETS   = ["kitten", "turtle", "duck", "rabbit",
                  "hedgehog", "squirrel", "otter", "panda"]
    sound_profile = _PRESETS[name_hash % len(_PRESETS)]
    sound_seed    = name_hash & 0xFFFF

    meta = default_meta(critter_id, name)
    meta.update({
        "frame_count":        len(pil_frames),
        "frame_size":         [CANONICAL_SIZE, CANONICAL_SIZE],
        "import_method":      "frame_strip",
        "procedural_animation": False,
        "source_dimensions":  list(Image.open(src_paths[0]).size),
        "trail_palette":      palette,
        "sound_profile":      sound_profile,
        "sound_seed":         sound_seed,
        "hit_radius_fallback": int(CANONICAL_SIZE * 0.46),
    })
    write_meta(critter_path, meta)

    return critter_id


# ---------------------------------------------------------------------------
# Loaders
# ---------------------------------------------------------------------------

def _load_static(path: Path) -> tuple[list[Image.Image], str]:
    """Load a PNG or JPG as a single RGBA image; generate 4 procedural frames."""
    import numpy as np

    try:
        img = Image.open(path)
    except Exception as e:
        raise ImportError(f"Could not open image: {e}")

    img.load()

    has_alpha_channel = img.mode == "RGBA" or "transparency" in img.info
    if has_alpha_channel:
        rgba = img.convert("RGBA")
        alpha = np.array(rgba)[:, :, 3]
        # Treat as already transparent only if >1% of pixels are actually transparent.
        # A PNG saved with mode=RGBA but a solid opaque background will have 0 transparent
        # pixels — fall through to bg removal in that case.
        meaningful_transparency = float((alpha < 255).sum()) / alpha.size > 0.01
    else:
        rgba = None
        meaningful_transparency = False

    if meaningful_transparency:
        method = "static_png"
        rgba = _strip_exif(rgba)
    else:
        rgba = remove_background(_strip_exif(img))
        method = "static_jpg"

    return generate_frames(rgba), method


def _load_gif(path: Path) -> tuple[list[Image.Image], str]:
    """Extract and normalise frames from an animated GIF."""
    try:
        gif = Image.open(path)
    except Exception as e:
        raise ImportError(f"Could not open GIF: {e}")

    raw_frames: list[Image.Image] = []
    try:
        for frame in ImageSequence.Iterator(gif):
            raw_frames.append(frame.convert("RGBA"))
    except Exception as e:
        raise ImportError(f"Failed to read GIF frames: {e}")

    if not raw_frames:
        raise ImportError("GIF contains no frames.")
    if len(raw_frames) > MAX_GIF_FRAMES:
        raise ImportError(
            f"This GIF has {len(raw_frames)} frames — it may be a screen recording. "
            f"Please use a GIF with {MAX_GIF_FRAMES} frames or fewer."
        )

    # Subsample to 4–8 frames
    target = 4 if len(raw_frames) <= 6 else min(8, len(raw_frames))
    frames = _subsample(raw_frames, target)

    # Compute global bounding box across all frames to keep alignment
    bbox = _global_bbox(frames)
    if bbox:
        frames = [f.crop(bbox) for f in frames]

    return frames, "animated_gif"


# ---------------------------------------------------------------------------
# Common pipeline helpers
# ---------------------------------------------------------------------------

def _crop_and_fit(frames: list[Image.Image]) -> list[Image.Image]:
    """
    For each frame: crop to non-transparent bounding box, then fit into
    CANONICAL_SIZE × CANONICAL_SIZE with transparent padding.
    """
    result = []
    for frame in frames:
        if frame.mode != "RGBA":
            frame = frame.convert("RGBA")
        bbox = frame.getbbox()
        if bbox:
            frame = frame.crop(bbox)
        fitted = _fit_to_canvas(frame, CANONICAL_SIZE)
        fitted = _threshold_alpha(fitted)
        fitted = _feather_alpha(fitted)
        result.append(fitted)
    return result


def _threshold_alpha(img: Image.Image, threshold: int = 180) -> Image.Image:
    """
    Eliminate semi-transparent fringe pixels that cause chroma-key bleed.
    Pixels with alpha < threshold become fully transparent; rest become opaque.
    """
    r, g, b, a = img.split()
    a = a.point(lambda v: 255 if v >= threshold else 0)
    return Image.merge("RGBA", (r, g, b, a))


def _feather_alpha(img: Image.Image, radius: float = 1.0) -> Image.Image:
    """Apply a small Gaussian blur to the alpha channel to smooth hard edges."""
    from PIL import ImageFilter
    r, g, b, a = img.split()
    a = a.filter(ImageFilter.GaussianBlur(radius=radius))
    return Image.merge("RGBA", (r, g, b, a))


def _strip_exif(img: Image.Image) -> Image.Image:
    """Return a clean copy of img with no EXIF/metadata."""
    clean = Image.new(img.mode, img.size)
    clean.putdata(list(img.getdata()))
    return clean


def _fit_to_canvas(img: Image.Image, size: int) -> Image.Image:
    """Scale img to fit within size×size preserving aspect ratio; centre on canvas."""
    img.thumbnail((size, size), Image.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ox = (size - img.width) // 2
    oy = (size - img.height) // 2
    canvas.paste(img, (ox, oy), img)
    return canvas


def _subsample(frames: list[Image.Image], target: int) -> list[Image.Image]:
    if len(frames) <= target:
        # Duplicate to reach target
        out = []
        for i in range(target):
            out.append(frames[i % len(frames)])
        return out
    indices = [int(i * len(frames) / target) for i in range(target)]
    return [frames[i] for i in indices]


def _global_bbox(frames: list[Image.Image]) -> tuple | None:
    """Compute the union bounding box of non-transparent pixels across all frames."""
    min_x, min_y = float("inf"), float("inf")
    max_x, max_y = 0, 0
    found = False
    for frame in frames:
        bb = frame.getbbox()
        if bb:
            found = True
            min_x = min(min_x, bb[0])
            min_y = min(min_y, bb[1])
            max_x = max(max_x, bb[2])
            max_y = max(max_y, bb[3])
    if not found:
        return None
    return (int(min_x), int(min_y), int(max_x), int(max_y))


# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

def _validate_file(path: Path) -> None:
    if not path.exists():
        raise ImportError("File not found.")

    size_mb = path.stat().st_size / (1024 * 1024)
    if size_mb > MAX_FILE_MB:
        raise ImportError(
            f"This file is {size_mb:.0f} MB. Please use a file under {MAX_FILE_MB} MB."
        )

    ext = path.suffix.lower()
    if ext not in (".png", ".jpg", ".jpeg", ".gif"):
        raise ImportError(
            "Unsupported file type. Please use a PNG, JPG, or animated GIF."
        )

    try:
        img = Image.open(path)
        img.load() if ext != ".gif" else None
        w, h = img.size
    except Exception as e:
        raise ImportError(f"Could not read image: {e}")

    if w < MIN_DIM or h < MIN_DIM:
        raise ImportError(
            f"This image is too small ({w}×{h} px). "
            f"Please use at least {MIN_DIM}×{MIN_DIM} pixels."
        )
    if w > MAX_DIM or h > MAX_DIM:
        raise ImportError(
            f"This image is too large ({w}×{h} px). "
            f"Please use an image no larger than {MAX_DIM}×{MAX_DIM} pixels."
        )


def _validate_content(frame: Image.Image) -> None:
    if frame.mode != "RGBA":
        frame = frame.convert("RGBA")
    import numpy as np
    alpha = np.array(frame)[:, :, 3]
    total = alpha.size
    opaque = int((alpha > 32).sum())

    if opaque == 0:
        raise ImportError("This image appears to be completely transparent.")
    if opaque / total < 0.05:
        raise ImportError(
            "Almost no visible content was found after background removal. "
            "Try a transparent PNG instead."
        )
