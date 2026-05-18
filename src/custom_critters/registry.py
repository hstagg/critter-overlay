"""
registry.py — Runtime registry of loaded custom critters.

Scanned once at startup; refreshed after any import/delete.
Each record holds the critter's metadata, pre-loaded pygame Surfaces,
and numpy alpha masks — ready for CustomAnimal to consume directly.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path

import numpy as np
import pygame

from custom_critters.storage import (
    get_custom_dir,
    list_critter_ids,
    critter_dir,
    frames_dir,
    masks_dir,
    read_meta,
)


@dataclass
class CustomCritterRecord:
    id: str
    meta: dict
    frames: list[pygame.Surface] = field(default_factory=list)
    masks: list[np.ndarray] = field(default_factory=list)


class CustomCritterRegistry:

    def __init__(self, custom_dir: Path | None = None):
        self.custom_dir = custom_dir or get_custom_dir()
        self.records: dict[str, CustomCritterRecord] = {}

    # ------------------------------------------------------------------
    # Loading
    # ------------------------------------------------------------------

    def reload(self) -> None:
        """Scan the custom directory and (re)load all valid critter folders."""
        self.records.clear()
        for critter_id in list_critter_ids(self.custom_dir):
            record = self._load_record(critter_id)
            if record is not None:
                self.records[critter_id] = record

    def _load_record(self, critter_id: str) -> CustomCritterRecord | None:
        path = critter_dir(self.custom_dir, critter_id)
        meta = read_meta(path)
        if meta is None:
            return None

        frames = self._load_frames(critter_id, meta)
        if not frames:
            print(f"[custom] No frames loaded for {critter_id} — skipping.")
            return None

        masks = self._load_masks(critter_id, meta)

        return CustomCritterRecord(id=critter_id, meta=meta, frames=frames, masks=masks)

    def _load_frames(self, critter_id: str, meta: dict) -> list[pygame.Surface]:
        fd = frames_dir(self.custom_dir, critter_id)
        count = meta.get("frame_count", 4)
        surfaces = []
        for i in range(count):
            p = fd / f"frame_{i}.png"
            if not p.exists():
                print(f"[custom] Missing {p}")
                break
            try:
                surf = pygame.image.load(str(p)).convert_alpha()
                # Threshold semi-transparent edge pixels that alpha-blend against
                # the magenta chroma key and produce a purple fringe on screen.
                # Pixels with alpha < 180 become fully transparent; >= 180 → opaque.
                px = pygame.surfarray.pixels_alpha(surf)
                px[px < 180] = 0
                del px  # release surface lock
                surfaces.append(surf)
            except Exception as e:
                print(f"[custom] Failed to load frame {p}: {e}")
                break
        return surfaces

    def _load_masks(self, critter_id: str, meta: dict) -> list[np.ndarray]:
        md = masks_dir(self.custom_dir, critter_id)
        count = meta.get("frame_count", 4)
        masks = []
        for i in range(count):
            p = md / f"mask_{i}.npy"
            if not p.exists():
                break
            try:
                masks.append(np.load(str(p)))
            except Exception as e:
                print(f"[custom] Failed to load mask {p}: {e}")
                break
        return masks

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def get(self, critter_id: str) -> CustomCritterRecord | None:
        return self.records.get(critter_id)

    def all(self) -> list[CustomCritterRecord]:
        return list(self.records.values())

    def add(self, record: CustomCritterRecord) -> None:
        self.records[record.id] = record

    def remove(self, critter_id: str) -> None:
        self.records.pop(critter_id, None)

    def is_empty(self) -> bool:
        return len(self.records) == 0
