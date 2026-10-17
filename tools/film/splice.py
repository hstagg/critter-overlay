"""Join pieces of several --film captures into one capture edit.py can cut.

  python tools/film/splice.py OUT CAPTURE_A:FROM:TO CAPTURE_B:FROM:TO ...

Each piece is a capture folder with the seconds to take from it. OUT gets a
frames.jsonl that points back at the pieces' PNGs, with time running on from
one piece to the next, so a reveal can cut from one critter to another under
a flash. All pieces must come from the same screen and frame rate.
"""

import json
import os
import sys
from pathlib import Path


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    lines, head, t_out = [], None, 0.0
    for spec in sys.argv[2:]:
        path, a, b = spec.rsplit(":", 2)
        cap = Path(path)
        raw = (cap / "frames.jsonl").read_text(encoding="utf-8").splitlines()
        head = head or raw[0]
        frames = [json.loads(l) for l in raw[1:] if l.strip()]
        step = frames[2]["t"] - frames[1]["t"]
        rel = os.path.relpath(cap, out)
        for fr in frames:
            if float(a) <= fr["t"] < float(b):
                for w in fr["wins"]:
                    w["png"] = f"{rel}/{w['png']}"
                fr["t"] = t_out
                t_out += step
                lines.append(json.dumps(fr))
    (out / "frames.jsonl").write_text("\n".join([head] + lines) + "\n", encoding="utf-8")
    print(f"{out}: {len(lines)} frames, {t_out:.1f} s")


if __name__ == "__main__":
    main()
