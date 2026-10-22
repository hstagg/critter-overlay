# Soak harness

Stability and performance runs for the v3 Godot app, without changing the
game: `soak_main.gd` loads the real `main.tscn` and adds `soak_monitor.gd`,
which logs once a sample period and, by mode, pokes the game.

These runs open 10 to 20 always-on-top windows and keep a CPU core busy for
as long as they last. Run them on a spare machine or VM, not a PC in use.

## Pieces

| File | What it does |
|---|---|
| `run.sh` | One harness run (editor binary, needs `-s`); see its header. Writes `NAME_exit.txt` too |
| `soak_monitor.gd` | Per sample: frame-time p50/p95/p99, hitches over 50 ms, critters, tiers, static memory, object/node/orphan counts, window count, anomalies (non-finite or off-screen critters, stuck throws) |
| `sample.ps1` | From outside: working set, private bytes, handles, threads, GDI and USER objects, CPU seconds, child processes |
| `relrun.ps1` | Runs an exported build (which ignores `-s`) with the same sampler |
| `exit_test.ps1` | Exit cleanliness: N launches, exit codes (`timed`, `second`, `wmclose`); `-Settings` for a silent settings file |
| `night_exit.ps1` | The whole exit test unattended (20 timed, 10 second-instance, 10 WM_CLOSE, sound off) plus crash events from the Application log; for a one-off scheduled task |
| `perf.ps1` | The Phase 5 rows measured on real hardware, on the release exe: fps and CPU (see below) |
| `judge.ps1` | The Phase 5 rows judged from an 8 h `run.sh` soak, and from `night_exit.ps1`'s results |
| `sleep_check.ps1` | The sleep/resume row: focus credited across a sleep against minutes awake |
| `soak_settings.json` | Settings for the runs: 10 to start, 12 max, pairs on, odds with about 15% Legendary (they count because run.sh passes `--admin`) |

## Phase 5 thresholds

One line per row of the table in `docs/v3-launch-plan.md` (Phase 5), each
printed as measured, threshold, PASS or FAIL.

| Row | Where | Script | PASS when |
|---|---|---|---|
| Frame rate, 8 critters | Dev PC | `perf.ps1 -Row fps8` | the report's median fps >= 28 and p95 gap between frames <= 40 ms (critters run at 30 fps; 2 min, the first 20% skipped) |
| CPU, 8 active | Dev PC | `perf.ps1 -Row cpu8` | CPU seconds over wall seconds, after the first minute, <= 25% of a core (10 min) |
| CPU while paused | Dev PC | `perf.ps1 -Row paused` | as above, <= 3%, and the report says paused (Ctrl+Shift+P pressed at 20 s) |
| CPU behind a full-screen app | Dev PC | `perf.ps1 -Row fullscreen` | <= 3%, and the report says hidden (a black full-screen window from 20 s) |
| CPU, all napping | Dev PC | `perf.ps1 -Row napping` | <= 7%, and at the end the report says away with every critter napping |
| 25 critters | Dev PC | `perf.ps1 -Row cap25` | median fps >= 25 and no `ERROR:` or `SCRIPT ERROR` in the run's `godot.log` |
| GDI objects | VM, 8 h | `judge.ps1` (gdi) | <= 2,000 at the end, and flat after hour 1 |
| USER objects, threads, children | VM, 8 h | `judge.ps1` (user) | each flat after hour 1 |
| Working set | VM, 8 h | `judge.ps1` (memory) | end <= hour 1 + 15% |
| Window count | VM, sampled | `judge.ps1` (windows) | every sample <= critters + props + 3 toasts + 8 spare + 3 |
| Script errors, crashes | VM, 8 h | `judge.ps1` (errors) | no errors or anomalies on stdout, exit 0, no crash events in the Application log |
| Clean exits | Dev PC, scheduled | `night_exit.ps1`, then `judge.ps1 -Exits` | at least 30 launches, every one exit code 0, no crash events |
| Sleep/resume | Laptop or VM | `sleep_check.ps1` | focus minutes in the save <= minutes awake (a sleep of over a minute must be seen) |
| Pair completion | VM soak | `judge.ps1` (pairs) | `PAIR act` lines >= 90% of `PAIR start` lines |

"Flat" means the highest value after hour 1 is at most 10% above the value at
hour 1, plus a small allowance (GDI 50, USER 20, threads 5, children 0).
`perf.ps1 -Row all` runs the six dev-PC rows in turn (about 45 min; the
full-screen row covers the screen in black). Frame rate and CPU only count
from real hardware: the VM renders in software.

## Modes (`--soak-mode=`)

- `soak`: natural play; every 5 min a pop, every 7 min a throw, every 10 min a special visitor
- `legend`: adds four specials (use with `--kittens=16 --tier=legendary`)
- `churn`: pops up to four every 3 s and refills with Spawn
- `throw`: a throw at a random speed every 2 s
- `specials`: one of each species in a row, each doing its own behaviours back to back (no cooldowns, so lunges can carry one off the screen edge: a harness artefact)
- `pairs`: every pair interaction in turn, the two critters 120 px apart
- `idle`: just logs

Use `--idle-sim=100000,1` whenever presence should stay "here": with no one
at the keyboard the real idle time sends everyone to nap after three
minutes, which also ends pairs and stops behaviours.

## Notes

- The timed-run economy save (`critter_test_economy.json` in the temp dir)
  is not reset between runs, so bond levels carry over; delete it for a
  clean start.
- An export made from a clone needs the `.import` files committed with
  `importer="keep"` for `art/**/*.svg`, or every part fails to load.
- Frame times on a VM with software OpenGL say nothing about real hardware;
  run the performance and exit-crash checks on the target machine.
