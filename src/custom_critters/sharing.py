"""
sharing.py — .critter package export and import.

A .critter file is a standard ZIP:
  meta.json          schema_version=2, id, name, author, license, ...
  manifest.json      { content_hash, app_min_version, exported_at }
  frames/            frame_0.png ... frame_N.png
  masks/             (optional — regenerated on import if absent)
  sounds/            (optional)
  source/            (optional — original image, for re-import)
  thumb.png          (optional)

Public API
----------
  export_critter(critter_id, dest_path, custom_dir)
  bulk_export(custom_dir, dest_dir) -> list[Path]
  read_package_meta(zip_path) -> dict          # peek without extracting
  import_critter_package(zip_path, custom_dir) -> critter_id
"""

from __future__ import annotations

import hashlib
import json
import shutil
from datetime import datetime, timezone
from pathlib import Path
import zipfile

from custom_critters.storage import (
    SCHEMA_VERSION,
    create_critter_folder,
    critter_dir,
    frames_dir,
    generate_critter_id,
    get_custom_dir,
    list_critter_ids,
    masks_dir,
    migrate_meta,
    read_meta,
    write_meta,
)

# ---------------------------------------------------------------------------
# Limits
# ---------------------------------------------------------------------------

MAX_ZIP_MB   = 50
MAX_FILE_MB  = 10
MAX_FILES    = 100
MAX_FRAMES   = 32
MAX_WAV_MB   = 2
ALLOWED_EXTS = {".png", ".json", ".wav", ".txt", ".md"}


# ---------------------------------------------------------------------------
# Export
# ---------------------------------------------------------------------------

def export_critter(critter_id: str, dest_path: Path,
                   custom_dir: Path | None = None) -> None:
    """Write a .critter zip to dest_path for the given critter_id."""
    custom_dir = custom_dir or get_custom_dir()
    cdir = critter_dir(custom_dir, critter_id)
    if not cdir.exists():
        raise ValueError(f"Critter folder not found: {cdir}")

    meta = read_meta(cdir)
    if meta is None:
        raise ValueError("Could not read meta.json")

    # Ensure v2 fields are present
    meta.setdefault("author",          "anonymous")
    meta.setdefault("license",         "unknown")
    meta.setdefault("attribution_url", None)
    meta.setdefault("app_min_version", "2.0.0")
    meta["schema_version"] = 2

    manifest = {
        "content_hash":    _hash_frames(cdir),
        "app_min_version": meta.get("app_min_version", "2.0.0"),
        "exported_at":     datetime.now(timezone.utc).isoformat(),
    }

    with zipfile.ZipFile(dest_path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        zf.writestr("meta.json",     json.dumps(meta,     indent=2))
        zf.writestr("manifest.json", json.dumps(manifest, indent=2))

        fd = frames_dir(custom_dir, critter_id)
        if fd.exists():
            for f in sorted(fd.iterdir()):
                if f.suffix.lower() == ".png":
                    zf.write(f, f"frames/{f.name}")

        md = masks_dir(custom_dir, critter_id)
        if md.exists():
            for f in sorted(md.iterdir()):
                zf.write(f, f"masks/{f.name}")

        thumb = cdir / "thumb.png"
        if thumb.exists():
            zf.write(thumb, "thumb.png")

        for src_name in ("source.png", "source.gif"):
            src = cdir / src_name
            if src.exists():
                zf.write(src, f"source/{src_name}")

        sfdir = cdir / "source_frames"
        if sfdir.exists():
            for sf in sorted(sfdir.iterdir()):
                zf.write(sf, f"source/{sf.name}")

        for wav_name in ("walk.wav", "custom.wav"):
            wav = cdir / wav_name
            if wav.exists():
                zf.write(wav, f"sounds/{wav_name}")


def bulk_export(custom_dir: Path | None = None,
                dest_dir: Path | None = None) -> list[Path]:
    """
    Export all custom critters to dest_dir (default: ~/Downloads).
    Returns a list of written .critter paths.
    """
    import os
    custom_dir = custom_dir or get_custom_dir()
    if dest_dir is None:
        dest_dir = Path(os.path.expanduser("~")) / "Downloads"
    dest_dir.mkdir(parents=True, exist_ok=True)

    written: list[Path] = []
    for cid in list_critter_ids(custom_dir):
        meta = read_meta(critter_dir(custom_dir, cid))
        if meta is None:
            continue
        raw_name = meta.get("name", cid)
        safe = "".join(c for c in raw_name if c.isalnum() or c in " _-").strip()
        dest = dest_dir / f"{safe or cid}.critter"
        if dest.exists():
            dest = dest_dir / f"{safe or cid}-{cid[-6:]}.critter"
        try:
            export_critter(cid, dest, custom_dir)
            written.append(dest)
        except Exception as e:
            print(f"[sharing] bulk export failed for {cid}: {e}")
    return written


# ---------------------------------------------------------------------------
# Import — peek
# ---------------------------------------------------------------------------

def read_package_meta(zip_path: Path) -> dict:
    """
    Open a .critter zip and return parsed meta.json without extracting.
    Raises ValueError with a user-facing message on any problem.
    """
    _check_zip_size(zip_path)
    try:
        with zipfile.ZipFile(zip_path, "r") as zf:
            _validate_zip_structure(zf)
            raw = zf.read("meta.json")
    except zipfile.BadZipFile:
        raise ValueError("This file is not a valid .critter package.")
    try:
        meta = json.loads(raw)
    except json.JSONDecodeError as e:
        raise ValueError(f"meta.json could not be parsed: {e}")
    if not {"id", "name"} <= set(meta):
        raise ValueError("meta.json is missing required fields (id, name).")
    return meta


# ---------------------------------------------------------------------------
# Import — full
# ---------------------------------------------------------------------------

def import_critter_package(zip_path: Path,
                           custom_dir: Path | None = None) -> str:
    """
    Validate and import a .critter zip into custom_dir.
    Returns the new local critter_id.
    Raises ValueError with a user-facing message on any failure.
    """
    custom_dir = custom_dir or get_custom_dir()
    _check_zip_size(zip_path)

    with zipfile.ZipFile(zip_path, "r") as zf:
        _validate_zip_structure(zf)
        _validate_zip_entries(zf)

        try:
            meta = json.loads(zf.read("meta.json"))
        except Exception as e:
            raise ValueError(f"meta.json could not be parsed: {e}")
        if not {"id", "name"} <= set(meta):
            raise ValueError("meta.json is missing required fields.")

        frame_names = sorted(
            n for n in zf.namelist()
            if n.startswith("frames/") and n.endswith(".png")
        )
        if not frame_names:
            raise ValueError("Package contains no frame images.")
        if len(frame_names) > MAX_FRAMES:
            raise ValueError(f"Too many frames ({len(frame_names)} > {MAX_FRAMES}).")

        declared_size = meta.get("frame_size")
        if declared_size:
            _validate_frame_dims(zf, frame_names, declared_size)

        for entry in zf.infolist():
            if entry.filename.startswith("sounds/") and entry.filename.endswith(".wav"):
                wav_mb = entry.file_size / (1024 * 1024)
                if wav_mb > MAX_WAV_MB:
                    raise ValueError(
                        f"{entry.filename} is too large "
                        f"({wav_mb:.1f} MB > {MAX_WAV_MB} MB)."
                    )

        # Assign a fresh local ID to avoid collisions
        new_id   = generate_critter_id(meta.get("name", "imported"))
        cdir     = create_critter_folder(custom_dir, new_id)

        try:
            fd = cdir / "frames"
            for fn in frame_names:
                (fd / Path(fn).name).write_bytes(zf.read(fn))

            mask_names = [n for n in zf.namelist() if n.startswith("masks/")]
            if mask_names:
                md = cdir / "masks"
                md.mkdir(exist_ok=True)
                for mn in mask_names:
                    (md / Path(mn).name).write_bytes(zf.read(mn))

            if "thumb.png" in zf.namelist():
                (cdir / "thumb.png").write_bytes(zf.read("thumb.png"))

            sound_entries = [
                n for n in zf.namelist()
                if n.startswith("sounds/") and n.endswith(".wav")
            ]
            if sound_entries:
                sd = cdir / "sounds"
                sd.mkdir(exist_ok=True)
                for se in sound_entries:
                    (sd / Path(se).name).write_bytes(zf.read(se))

            meta["id"] = new_id
            write_meta(cdir, migrate_meta(meta))

        except Exception as e:
            shutil.rmtree(cdir, ignore_errors=True)
            raise ValueError(f"Extraction failed: {e}")

    _ensure_masks(cdir, custom_dir, new_id)
    return new_id


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

def _check_zip_size(zip_path: Path) -> None:
    size_mb = zip_path.stat().st_size / (1024 * 1024)
    if size_mb > MAX_ZIP_MB:
        raise ValueError(
            f"Package is {size_mb:.0f} MB — maximum allowed is {MAX_ZIP_MB} MB."
        )


def _validate_zip_structure(zf: zipfile.ZipFile) -> None:
    names = zf.namelist()
    if len(names) > MAX_FILES:
        raise ValueError(f"Package has too many files ({len(names)} > {MAX_FILES}).")
    if "meta.json" not in names:
        raise ValueError("Package is missing meta.json.")
    for name in names:
        _check_path_safe(name)


def _validate_zip_entries(zf: zipfile.ZipFile) -> None:
    for entry in zf.infolist():
        if entry.filename.endswith("/"):
            continue
        ext = Path(entry.filename).suffix.lower()
        if ext not in ALLOWED_EXTS:
            raise ValueError(
                f"Disallowed file type in package: {entry.filename!r}. "
                f"Allowed: {', '.join(sorted(ALLOWED_EXTS))}."
            )
        file_mb = entry.file_size / (1024 * 1024)
        if file_mb > MAX_FILE_MB:
            raise ValueError(
                f"{entry.filename!r} is too large "
                f"({file_mb:.1f} MB > {MAX_FILE_MB} MB)."
            )


def _check_path_safe(name: str) -> None:
    if "\x00" in name:
        raise ValueError("Package contains a path with null bytes.")
    if name.startswith("/") or name.startswith("\\"):
        raise ValueError(f"Absolute path in package: {name!r}")
    if ".." in Path(name.replace("\\", "/")).parts:
        raise ValueError(f"Path traversal attempt in package: {name!r}")


def _validate_frame_dims(zf: zipfile.ZipFile, frame_names: list[str],
                         declared_size: list[int]) -> None:
    from PIL import Image
    import io
    w_decl, h_decl = declared_size
    for fn in frame_names[:4]:
        try:
            img = Image.open(io.BytesIO(zf.read(fn)))
            w, h = img.size
        except Exception:
            raise ValueError(f"Frame {fn!r} could not be read as an image.")
        if (abs(w - w_decl) / max(w_decl, 1) > 0.10 or
                abs(h - h_decl) / max(h_decl, 1) > 0.10):
            raise ValueError(
                f"Frame {fn!r} size {w}x{h} does not match declared "
                f"{w_decl}x{h_decl} (tolerance ±10%)."
            )


def _ensure_masks(cdir: Path, custom_dir: Path, critter_id: str) -> None:
    md = masks_dir(custom_dir, critter_id)
    if md.exists() and any(md.iterdir()):
        return
    try:
        from PIL import Image
        from custom_critters.masks import generate_and_save_masks
        fd = cdir / "frames"
        frame_files = sorted(fd.glob("frame_*.png"),
                             key=lambda p: int(p.stem.split("_")[1]))
        pil_frames = [Image.open(f).convert("RGBA") for f in frame_files]
        generate_and_save_masks(pil_frames, md)
    except Exception as e:
        print(f"[sharing] mask regeneration failed for {critter_id}: {e}")


def _hash_frames(cdir: Path) -> str:
    fd = cdir / "frames"
    if not fd.exists():
        return ""
    h = hashlib.sha256()
    for f in sorted(fd.glob("frame_*.png")):
        h.update(f.read_bytes())
    return h.hexdigest()[:16]
