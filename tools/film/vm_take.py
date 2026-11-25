"""Film one take on the test VM and bring its frames back.

    python tools/film/vm_take.py NAME [--ref v3.1.1] [--fps 30] -- --species=kitten --kittens=3 --seconds=20 --zoom=1.4

Everything after "--" goes to the game (main.gd's flags). Critters appear on
the VM's screen, never this one. The frames land in
%USERPROFILE%\\Videos\\Critter Overlay\\takes\\NAME\\frames, ready for edit.py.
Without --ref it films the newest release tag, which is what players download.

Needs `ssh critter-vm` (the test VM), with the repo at C:\\critter-overlay.
"""

import argparse
import shutil
import subprocess
import sys
import tarfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
TAKES = Path.home() / "Videos" / "Critter Overlay" / "takes"
VM = "critter-vm"


def latest_release():
    tags = subprocess.run(["git", "-C", str(HERE), "tag", "--list", "v*", "--sort=-v:refname"],
                          capture_output=True, text=True).stdout.split()
    return tags[0] if tags else "main"


def main():
    argv = sys.argv[1:]
    game = argv[argv.index("--") + 1:] if "--" in argv else []
    argv = argv[:argv.index("--")] if "--" in argv else argv
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("name")
    ap.add_argument("--ref", default="")
    ap.add_argument("--fps", type=int, default=30)
    a = ap.parse_args(argv)
    ref = a.ref or latest_release()
    subprocess.run(["scp", "-q", str(HERE / "vm-film.ps1"), f"{VM}:C:/soak/vm-film.ps1"], check=True)
    args = " ".join(game).replace('"', "")
    r = subprocess.run(["ssh", VM, f'powershell -NoProfile -File C:\\soak\\vm-film.ps1 -Name {a.name} -Ref {ref} '
                                   f'-Fps {a.fps} -GameArgs "{args}"'], capture_output=True, text=True)
    out = "\n".join(l for l in (r.stdout + r.stderr).splitlines() if "post-quantum" not in l and not l.startswith("**"))
    print(out.strip())
    if r.returncode or "ok " not in out:
        sys.exit(f"filming failed ({r.returncode})")
    dest = TAKES / a.name
    if dest.exists():
        shutil.rmtree(dest)
    dest.mkdir(parents=True)
    tar = dest.with_suffix(".tar")
    subprocess.run(["scp", "-q", f"{VM}:C:/soak/film/{a.name}.tar", str(tar)], check=True)
    with tarfile.open(tar) as t:
        t.extractall(dest, filter="data")
    tar.unlink()
    n = len((dest / "frames" / "frames.jsonl").read_text(encoding="utf-8").splitlines()) - 1
    print(f"{dest / 'frames'}: {n} frames of {ref}")


if __name__ == "__main__":
    main()
