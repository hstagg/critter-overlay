"""
storage.py — Disk layout and metadata I/O for custom critters.

Each critter lives in a self-contained folder:
  %APPDATA%\CritterOverlay\custom\<slug>-<hash6>\
    frames\         frame_0.png … frame_N.png
    masks\          mask_0.npy  … mask_N.npy
    meta.json
    thumb.png
    source.png / source.gif
"""

import json
import os
import re
import uuid
from datetime import datetime, timezone
from pathlib import Path


SCHEMA_VERSION = 1


# ---------------------------------------------------------------------------
# Path helpers
# ---------------------------------------------------------------------------

def get_custom_dir() -> Path:
    appdata = os.environ.get("APPDATA", os.path.expanduser("~"))
    d = Path(appdata) / "CritterOverlay" / "custom"
    d.mkdir(parents=True, exist_ok=True)
    return d


def critter_dir(custom_dir: Path, critter_id: str) -> Path:
    return custom_dir / critter_id


def frames_dir(custom_dir: Path, critter_id: str) -> Path:
    return critter_dir(custom_dir, critter_id) / "frames"


def masks_dir(custom_dir: Path, critter_id: str) -> Path:
    return critter_dir(custom_dir, critter_id) / "masks"


# ---------------------------------------------------------------------------
# ID generation
# ---------------------------------------------------------------------------

def slugify(name: str) -> str:
    """Convert a display name to a lowercase ASCII slug."""
    s = name.lower().strip()
    s = re.sub(r"[^a-z0-9\s-]", "", s)
    s = re.sub(r"[\s]+", "-", s)
    s = re.sub(r"-+", "-", s).strip("-")
    return s or "critter"


def generate_critter_id(name: str) -> str:
    """Return '<slug>-<hash6>' — unique, human-readable folder name."""
    slug = slugify(name)[:24]  # cap slug length
    hash6 = uuid.uuid4().hex[:6]
    return f"{slug}-{hash6}"


# ---------------------------------------------------------------------------
# meta.json I/O
# ---------------------------------------------------------------------------

def default_meta(critter_id: str, name: str) -> dict:
    return {
        "id": critter_id,
        "name": name,
        "schema_version": SCHEMA_VERSION,
        "created_at": datetime.now(timezone.utc).isoformat(),
        "frame_count": 4,
        "frame_size": [120, 120],
        "import_method": "static_png",
        "procedural_animation": True,
        "source_dimensions": [0, 0],
        "trail_palette": [],
        "sound_profile": "kitten",
        "sound_seed": 0,
        "hit_radius_fallback": 55,
        "notes": "",
    }


def read_meta(critter_path: Path) -> dict | None:
    """Load meta.json from a critter folder. Returns None on failure."""
    meta_path = critter_path / "meta.json"
    try:
        with open(meta_path, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception as e:
        print(f"[custom] Failed to read meta.json in {critter_path}: {e}")
        return None


def write_meta(critter_path: Path, meta: dict) -> None:
    meta_path = critter_path / "meta.json"
    with open(meta_path, "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=2)


# ---------------------------------------------------------------------------
# Folder scaffolding
# ---------------------------------------------------------------------------

def create_critter_folder(custom_dir: Path, critter_id: str) -> Path:
    """Create the folder skeleton for a new critter. Returns the critter path."""
    path = critter_dir(custom_dir, critter_id)
    path.mkdir(parents=True, exist_ok=True)
    (path / "frames").mkdir(exist_ok=True)
    (path / "masks").mkdir(exist_ok=True)
    return path


def delete_critter_folder(custom_dir: Path, critter_id: str) -> None:
    """Recursively delete a critter's folder."""
    import shutil
    path = critter_dir(custom_dir, critter_id)
    if path.exists():
        shutil.rmtree(path)


# ---------------------------------------------------------------------------
# Scan helpers
# ---------------------------------------------------------------------------

def list_critter_ids(custom_dir: Path) -> list[str]:
    """Return all folder names in custom_dir that contain a meta.json."""
    ids = []
    if not custom_dir.exists():
        return ids
    for entry in sorted(custom_dir.iterdir()):
        if entry.is_dir() and (entry / "meta.json").exists():
            ids.append(entry.name)
    return ids
