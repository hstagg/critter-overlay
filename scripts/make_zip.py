"""
make_zip.py  —  package Critter Overlay for distribution

Usage:
    python make_zip.py          # auto-increments minor version
    python make_zip.py v2.0     # use a specific version

What it does:
  1. Finds the current CritterOverlay_vX.Y.zip in this folder (if any).
  2. Moves it to Archive/ (creating that folder if needed).
  3. Creates a new CritterOverlay_vX.(Y+1).zip with all distributable files.
"""

import re, shutil, sys, zipfile
from pathlib import Path

base        = Path(__file__).parent
archive_dir = base / "Archive"
archive_dir.mkdir(exist_ok=True)

# ------------------------------------------------------------------
# Work out the new version number
# ------------------------------------------------------------------
existing = sorted(base.glob("CritterOverlay_v*.zip"))

if len(sys.argv) > 1:
    new_version = sys.argv[1].lstrip("v")
    new_version = f"v{new_version}"
elif existing:
    latest = existing[-1]
    m = re.search(r"v(\d+)\.(\d+)", latest.name)
    major, minor = (int(m.group(1)), int(m.group(2))) if m else (1, 0)
    new_version = f"v{major}.{minor + 1}"
else:
    new_version = "v1.0"

# ------------------------------------------------------------------
# Archive all existing zips from the project root
# ------------------------------------------------------------------
for z in existing:
    dest = archive_dir / z.name
    shutil.move(str(z), str(dest))
    print(f"  Archived {z.name} → Archive/")

# ------------------------------------------------------------------
# Build the new zip
# ------------------------------------------------------------------
out = base / f"CritterOverlay_{new_version}.zip"

# Files included in the distributable (no build artefacts)
include = [
    "run.bat",
    "setup.bat",
    "pythoninstall.bat",
    "requirements.txt",
    "START HERE.txt",
    "TROUBLESHOOTING.txt",
    "README.md",
]

print(f"\nBuilding {out.name} ...")

with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as zf:
    for name in include:
        p = base / name
        if p.exists():
            zf.write(p, name)
            print(f"  + {name}")
        else:
            print(f"  ? skipped (not found): {name}")

    for p in sorted((base / "src").glob("*.py")):
        zf.write(p, f"src/{p.name}")
        print(f"  + src/{p.name}")

print(f"\nDone → {out.name}")
