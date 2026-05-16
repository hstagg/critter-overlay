"""
build.py - Package Critter Overlay as a single .pyzw zipapp.

Run:
    python build.py            # auto-bumps minor version
    python build.py 2.0        # specific version

Output: Critter Overlay v<version>.pyzw

The .pyzw is a Python zipapp. Double-clicking it on a machine with Python
installed (and .pyzw associated with pythonw, which is the python.org default)
launches the bootstrapper in __main__.py - no console window, no unzipping,
no setup scripts.
"""

from __future__ import annotations

import re
import shutil
import sys
import zipapp
from pathlib import Path

ROOT      = Path(__file__).resolve().parent
ARCHIVE   = ROOT / "Archive"
ARCHIVE.mkdir(exist_ok=True)


def existing_versions() -> list[Path]:
    pat = re.compile(r"Critter Overlay v(\d+)\.(\d+)\.pyzw$")
    out = []
    for p in ROOT.glob("Critter Overlay v*.pyzw"):
        if pat.search(p.name):
            out.append(p)
    return sorted(out, key=lambda p: tuple(int(x) for x in pat.search(p.name).groups()))


def next_version() -> str:
    if len(sys.argv) > 1:
        return sys.argv[1].lstrip("v")
    pat = re.compile(r"v(\d+)\.(\d+)")
    versions = existing_versions()
    if not versions:
        return "1.0"
    m = pat.search(versions[-1].name)
    major, minor = int(m.group(1)), int(m.group(2))
    return f"{major}.{minor + 1}"


def archive_old(versions: list[Path]) -> None:
    for p in versions:
        dest = ARCHIVE / p.name
        if dest.exists():
            dest.unlink()
        shutil.move(str(p), str(dest))
        print(f"  archived  {p.name}")


def stage_sources(stage: Path) -> None:
    """Copy the files we want to ship into a clean staging directory."""
    if stage.exists():
        shutil.rmtree(stage)
    stage.mkdir(parents=True)

    # Bootstrapper - mandatory at the root.
    shutil.copy2(ROOT / "__main__.py", stage / "__main__.py")

    # Application source.
    src_out = stage / "src"
    src_out.mkdir()
    for py in sorted((ROOT / "src").glob("*.py")):
        shutil.copy2(py, src_out / py.name)

    # An __init__.py so 'src' is also importable as a package if we ever want
    # that. Bootstrapper currently puts src on sys.path directly, but having
    # this is harmless and future-proof.
    (src_out / "__init__.py").write_text("", encoding="utf-8")


def main() -> None:
    version = next_version()
    out_name = f"Critter Overlay v{version}.pyzw"
    out_path = ROOT / out_name

    print(f"Building {out_name}")

    # 1. Move every old build into Archive/
    archive_old(existing_versions())

    # 2. Stage exactly what should be inside the zipapp
    stage = ROOT / "_build_stage"
    stage_sources(stage)

    # 3. Build the zipapp. Shebang #!pythonw makes Unix runs use pythonw, but
    #    on Windows it's the .pyzw extension association that matters - and
    #    .pyzw is bound to pythonw.exe by the standard installer.
    zipapp.create_archive(
        source     = stage,
        target     = out_path,
        interpreter= "/usr/bin/env pythonw",
        main       = None,  # __main__.py provides the entry point
        compressed = True,
    )

    # 4. Cleanup
    shutil.rmtree(stage)

    size_kb = out_path.stat().st_size / 1024
    print(f"Done -> {out_name}  ({size_kb:.1f} KB)")
    print()
    print("Ship this single file. End-users:")
    print("  1. Double-click it.")
    print("  2. Wait for the small dark progress window to finish (first run only).")
    print("  3. Critter Overlay opens. Done.")


if __name__ == "__main__":
    main()
