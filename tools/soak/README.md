# Soak harness

Stability and performance runs for the v3 Godot app, without changing the
game: `soak_main.gd` loads the real `main.tscn` and adds `soak_monitor.gd`,
which logs once a sample period and, by mode, pokes the game.

These runs open 10 to 20 always-on-top windows and keep a CPU core busy for
as long as they last. Run them on a spare machine or VM, not a PC in use.

## Pieces

| File | What it does |
|---|---|
| `run.sh` | One harness run (editor binary, needs `-s`); see its header |
| `soak_monitor.gd` | Per sample: frame-time p50/p95/p99, hitches over 50 ms, critters, tiers, static memory, object/node/orphan counts, window count, anomalies (non-finite or off-screen critters, stuck throws) |
| `sample.ps1` | From outside: working set, private bytes, handles, threads, GDI and USER objects, CPU seconds |
| `relrun.ps1` | Runs an exported build (which ignores `-s`) with the same sampler |
| `exit_test.ps1` | Exit cleanliness: N launches, exit codes (`timed`, `second`, `wmclose`) |
| `soak_settings.json` | Settings for the runs: 10 to start, 12 max, pairs on, beta odds with about 15% Legendary |

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
