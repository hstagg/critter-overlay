#!/bin/bash
# One harness run: the game with the soak monitor, sampled from outside.
#
#   tools/soak/run.sh NAME TIMEOUT_S [main.gd and --soak-* flags...]
#
# e.g. a 65-minute mixed soak:
#   tools/soak/run.sh soak 4200 --seconds=3900 --gather-every=90 --stay=900 \
#       --idle-sim=480,240 --soak-mode=soak --soak-every=60
#
# Runs with `godot` (the editor binary: the harness needs -s, which exported
# builds ignore). Output goes to $SOAK_OUT (default tools/soak/out):
# NAME.jsonl (monitor, one line per sample), NAME_proc.csv (working set,
# handles, GDI/USER objects, CPU), NAME_report.json (main.gd's report),
# NAME_out.txt (stdout).
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
out="${SOAK_OUT:-$here/out}"
every="${EVERY:-60}"
name=$1; to=$2; shift 2
mkdir -p "$out"
cp "$here/soak_settings.json" "$out/${name}_settings.json"
rm -f "${out:?}/${name:?}.pid"
powershell -NoProfile -ExecutionPolicy Bypass -File "$here/sample.ps1" -PidFile "$out/$name.pid" -Out "$out/${name}_proc.csv" -Every "$every" &
cd "$repo"
timeout "$to" godot --path godot -s "$here/soak_main.gd" -- --report="$out/${name}_report.json" \
	--settings="$out/${name}_settings.json" --soak-every="$every" --soak-log="$out/$name.jsonl" \
	--soak-pid="$out/$name.pid" "$@" > "$out/${name}_out.txt" 2>&1
echo "$name exit=$?"
