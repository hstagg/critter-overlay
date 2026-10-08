# v3 stability and performance soak

October 2026, branch `v3` at 6c4b53b (all ten critters built). Harness and
how to rerun: `tools/soak/README.md`.

**Machine:** Windows 11, Intel Iris Xe (OpenGL 3.3, driver 32.0.101.5542),
1920×1080 primary. Godot 4.7.2 editor binary (debug) for harness runs; a
release export of the same commit for the release numbers.

**Update, 8 October:** the dedicated exit test ran on the release export of
the fixed branch: 40 of 40 clean (section 3). After merging current `v3`:
353 more art SVGs (the version folders) got their `keep` import files, and a
new `import_test.gd` guards them; the Admin page's pair checks and
`--pair-demo` now start the two close enough to meet (10 of 10 pairs act).
A 6-hour soak on the test VM (`tools/soak/vm/`) is under way.

## Findings

| # | Finding | Severity | Evidence | Status |
|---|---|---|---|---|
| 1 | An export made outside `build-v3.ps1` (by hand, from the editor, in CI) from a fresh clone has no critter art. The art SVGs need `importer="keep"`, but the `.import` files were gitignored, so a clone imports them as textures and the `.pck` has no raw SVG for `critter.gd` to read. `build-v3.ps1` rewrites them to `keep` before exporting, so installers built with it were never affected. | Low (corrected from High on 8 Oct: the build script already covered the installer) | Direct export from a clean worktree: 453 errors in 2 min (`load_svg_from_buffer: buffer_size == 0`, `Invalid image: image is empty`), 69 per kitten = 23 parts × 3. With the `keep` files: 0 errors for every species. | **Fixed**: `.import` files committed for every art SVG; `import_test.gd` guards them |
| 2 | `main.gd` appends to `process_ms` and `fps` every frame in every run, not only report runs: unbounded growth. | Medium (slow leak in the shipped app) | Soak: 129,421 entries per array after 65 min; static memory 43.2 → 49.8 MB, about 2 × 129k Variants. Projects to about 100 MB per 24 h at 40 fps. | **Fixed**: only collected with `--report` |
| 3 | A second launch while the app is running can crash on exit (0xC0000005). The "already running" branch calls `get_tree().quit()`, which runs the GL teardown that `_quit()` exists to skip. | Medium (a double-clicked shortcut gives a crash report) | 1 of 10 second-instance launches of the release export exited with an access violation (bash exit 139); the other 9 printed the known teardown warnings. | **Fixed** and confirmed: that branch now calls `_quit(0)`; 10 of 10 second launches clean |
| 4 | GDI objects leak about 1.75 per window created (critter windows and toasts). Godot bug: `display_server_windows.cpp:1905` creates an `HRGN` for `DwmEnableBlurBehindWindow` on every transparent window and never deletes it. | Low to medium (10,000 per-process limit) | Soak: 53 → 108 over 65 min, rising only while present (arrivals, pops, toasts), flat while away. Churn (564 pops, about 570 windows): 62 → 1,061 in 8 min. Normal play: about 55 per hour, so the limit is about 180 h of continuous presence away. | Proposed (see below) |
| 5 | 36% of natural pair interactions give up during the approach. `APPROACH_LIMIT` is 8 s, but pairs start up to `NEAR` = 420 px apart and cruise speeds are 12 to 35 px/s (12 to 35 s to close 420 px). | Medium (visible: two critters head for each other, then turn away) | Soak: 77 pairs started, 49 ended in `act`, 28 in `approach`. `--pair-demo` and the Admin page's pair checks failed for all 10 pairs (critters placed 340 px apart): 0 acts in 20 runs. | Admin and demo spacing **fixed** (10 of 10 act); natural pairs proposed |
| 6 | CPU and frame rate. 10 to 12 critters keep about 0.7 to 0.8 of a CPU core busy and run below 60 fps; 20 Legendaries reach 15 fps. Game logic is a small part of it: the cost is drawing and presenting one GL window per critter. | Medium (battery and fan on laptops) | Release, 10 critters, 10 min: fps median 49 (p95 62), main `_process` 3.7 ms median, 426 CPU-s in 600 s. Debug soak: about 33 fps, p50 27 ms, p95 50 ms, 5.4% of frames over 50 ms (7,052 of 129,421). Debug, 20 Legendaries awake: about 15 fps, p50 57 to 67 ms. Everyone napping: about 39 fps, p95 38 ms. | Proposed |
| 7 | Nothing handles `WM_CLOSE` on the main window (logoff, `taskkill` without `/f`): Godot quits with the full teardown and without `economy.save()`. Saves happen every 60 s, so at most a minute of focus is lost. | Low | Code reading: no `NOTIFICATION_WM_CLOSE_REQUEST` handler, `auto_accept_quit` left on. Exit test: 10 of 10 `WM_CLOSE` exits clean, so the teardown did not crash here; only the skipped save remains. | Proposed: route it through `_quit()` |
| 8 | The timed-run economy save (`critter_test_economy.json`) is never reset, unlike the test settings, so bond levels and the collection carry over between test runs. A bonded critter then curls up by a resting pointer mid-test (looked like a stuck squirrel). | Low (test hygiene) | Specials rerun: squirrel in `loaf`, `hold_nap=true` for 4 min with presence forced on; bond levels came from an earlier churn run. | Noted |
| 9 | Behaviour lunges (hunt, prance) don't clamp to the screen edge. Back-to-back with no cooldown, a kitten got to x = -1,100. | Low (harness artefact; never seen in natural play) | Specials rerun only; 0 anomalies in the 65-min soak and the other stress runs. | Noted |

Nothing else turned up. In about 2 h of runs: no script errors, no warnings
in play, no orphan nodes, no NaN or lost critters, no stuck throws.

## 1. Mixed soak: 65 minutes

10 to 12 critters of all eight common species, arrivals every 90 s of focus,
visits up to 15 min, presence cycling 8 min here and 4 min away
(`--idle-sim=480,240`), pairs on, beta odds with about 15% Legendary. Plus, from the
harness: a pop every 5 min, a throw every 7, a special visitor every 10
(3 came: unicorn, golden kitten, unicorn).

| Measure | Start | End | Note |
|---|---|---|---|
| Working set | 319 MB (1 min) | 376 MB | Plateaus from about 37 min (375 to 390 MB) |
| Private bytes | 236 MB | 293 MB | Tracks video memory |
| Video memory (Godot) | 49 MB | 78 MB | Steps up with new species and specials, then flat from 36 min |
| Static memory (Godot) | 43.2 MB | 49.8 MB | Finding 2 |
| Objects / nodes | 2,245 to 2,525 / 442 to 628 | | Follow the critter count; no drift |
| Orphan nodes | 0 | 0 | |
| Handles / threads | 726 / 29 | 712 / 25 | Flat |
| GDI / USER objects | 53 / 40 | 108 / 39 | Finding 4 |
| CPU | | 2,955 CPU-s in 3,900 s | 76% of one core on average |
| Exit | | code 0 | |

Frame time by presence (per-minute medians; debug binary):

| | Minutes | fps | p50 ms | p95 ms | p99 ms | Hitches > 50 ms per min |
|---|---|---|---|---|---|---|
| Present | 44 | 31 | 30.4 | 52.7 | 76.7 | 134 |
| Away (napping) | 20 | 39 | 24.4 | 38.2 | 49.4 | 58 |
| All | 64 | 33 | 27.3 | 50.1 | 72.5 | 110 |

No degradation over time: p95 was 51 ms in the first 10 min and 35 ms in the
last 10 (fewer critters out by then). Activity: 77 pairs (49 acted), 37
arrivals, 13 pops, 9 throws, 11 bumps, 1 gift, 5 welcome-backs. Stdout: no
`ERROR`, `WARNING` or `SCRIPT ERROR` lines.

## 2. Stress runs

| Run | Setup | Result |
|---|---|---|
| 20 Legendaries | `--kittens=16 --tier=legendary` plus 2 unicorns and 2 golden kittens: 20 auras, 20 heart trails, 5 min | Stable: 0 anomalies, objects and nodes flat, working set 404 to 432 MB, exit 0. Slow while awake: about 15 fps, p50 57 to 67 ms, p99 up to 141 ms; once napping, about 31 fps. Main `_process` 6.1 ms median. |
| Pop and refill churn | Pop up to 4 every 3 s, Spawn refills 3, arrivals every 5 s, 8 min | 564 pops, about 570 arrivals: 0 anomalies, orphans 0, objects and nodes back to baseline after each wave, exit 0. GDI 62 → 1,061 (finding 4). Static memory 52.3 → 53.7 MB (finding 2). |
| Throws | A throw every 2 s at 150 to 4,000 px/s, refilling to 12, 5 min | 134 throws, 283 bumps, 18 thrown off the screen and replaced: no stuck slides (none over 20 s), no lost or NaN critters, exit 0. |
| Species behaviours | All 10 species in a row, each doing its own behaviours back to back, 5 min (twice) | Every one ran repeatedly: ball_up, snuffle, belly_roll, chase_tail, hunt, listen, chitter, head_tuck, nose_twitch, stand_lookout, panda_roll, peck_ground, preen, prance. 0 errors, objects flat, exit 0. Findings 8 and 9 from the rerun. |
| Pair demos | `--pair-demo=` each of the 10, twice (30 s each, presence forced on) | All exit 0 with no errors, but no pair got past `approach` (finding 5). |

## 3. Exit cleanliness

| Path | Runs | Clean | Crashes |
|---|---|---|---|
| Timed exit through `_quit()`, soak and stress runs (debug and release) | 39 | 39 | 0 |
| Second instance, before the fix (release) | 10 | 9 | 1 (0xC0000005) |
| Exit test, 8 Oct, release export of the fixed branch: | | | |
| Timed exit through `_quit()`, 6 Legendaries | 20 | 20 | 0 |
| Second instance, "already running" | 10 | 10 | 0 |
| `WM_CLOSE` from outside (`taskkill` without `/f`) | 10 | 10 | 0 |

No crash events in the Application log during the exit test. The Intel
workaround holds on every exit path, and the second-instance branch, the one
gap, is closed (finding 3). Run with `tools/soak/night_exit.ps1`, sound off.

A note for scheduling it: the Claude desktop app is packaged (MSIX), so
files its tools write under `AppData` are redirected to its own package
folder and invisible to Task Scheduler. The first scheduled attempt failed
in 2 s (0xFFFD0000, PowerShell's "file not found") for that reason; keep the
kit outside `AppData`.

## Proposed fixes (not made)

- **Finding 4, GDI leak.** Report upstream with the one-line fix
  (`DeleteObject(hRgn)` after `DwmEnableBlurBehindWindow`, at both call sites);
  it is in Godot, not this project. Until then the leak tracks windows
  created, so a mitigation is to reuse windows instead of freeing them: keep
  closed toast windows for the next toast, and park a departing critter's
  window for the next arrival. Moderate change; worth it only if long uptimes
  matter before an engine fix lands.
- **Finding 5, pairs.** Either start pairs only when the walker can arrive in
  time (`|dx| / cruise < APPROACH_LIMIT`), or scale the limit to the distance
  (for example `max(8, 1.5 * |dx| / cruise)`). (`--pair-demo` and the Admin
  pair checks now start the two 120 px apart.)
- **Finding 6, CPU.** Cap the frame rate when nothing needs it: 30 fps while
  everyone is napping or away, perhaps 30 to 40 normally, via
  `Engine.max_fps`; measure the CPU saving on this machine. Longer term,
  windows only for critters that are on screen and moving, or fewer
  presents for still critters. A design call, so not attempted here.
- **Finding 7, WM_CLOSE.** Set `get_tree().auto_accept_quit = false` and call
  `_quit(0)` on `NOTIFICATION_WM_CLOSE_REQUEST`: the same exit as the tray's
  Quit, so the economy is saved and the teardown skipped. The exit test found
  no crash on this path, so this is now only about the save.
- **Finding 8.** Delete the test economy save at the start of each timed run,
  as the test settings already are, or have the harness pass a fresh `--save=`.

## Pulling the `.import` files into an existing checkout

Git refuses to pull a commit that adds files that already exist untracked,
even with the same content, and a checkout that has been opened in Godot has
its own `.import` files. After the merge on GitHub, in that checkout:

```bash
git fetch && git diff --name-only HEAD origin/v3 --diff-filter=A -- '*.import' | xargs rm -- && git pull
```

That removes only the `.import` files the pull is about to add (the pull
puts identical copies back). Untracked art of your own keeps its imports.
