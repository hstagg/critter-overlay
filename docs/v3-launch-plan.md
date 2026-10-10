# v3.0 launch plan: from today's build to a small beta

Audit of branch `v3` at `b0b27af` (2026-10-10), and the phased plan that gets it
to a beta build in testers' hands. Planning only: nothing in the app was changed.
Custom critters are out of scope (a later update; see
`docs/v3-custom-critters-plan.md` on branch `v3-custom-critters-plan`, section 11).
The only custom-critter question here is what happens to a v2.0 user's existing ones (D3).

Sizes: **S** is an hour or two, **M** is a day or so, **L** is several days.
Severity: **blocker** means beta does not start without it. **should-fix** means beta can
start, but the problem would muddy the feedback. **nice** is polish that can wait.

---

## Summary

### State of the build

- **Branch of record:** `origin/v3` (`b0b27af`, the merge of the soak fixes).
  - `main` (`c945927`) is 13 commits behind it. It has the critters and Admin page,
    but not the soak fixes, the committed `.import` files or the test VM.
  - `v3-critters`, `v3-ci`, `v3-updater`, `v3-soak-fixes` and `v3-godot` are fully
    merged into v3.
  - Only two branches are ahead of v3:
    - `v3-soak-followup`: one docs commit, not yet merged.
    - `v3-hedgehog-wip`: an abandoned design, superseded by the approved hedgehog.
  - A local `v3` checkout is 15 commits behind `origin/v3`.
- **What works:**
  - All ten critters are built, rigged and animated.
  - The four-tier rarity model is in place (Common species; Rare/Epic versions;
    Legendary visitors with 7 + 3 secret colours).
  - The focus economy is in: berries, luck, gifts, Rare Hour and the first visitor
    of the day.
  - Collection (34 slots), dressing-room Shop (84 clothes, dyes, treats, 3 showpieces),
    props and beds, 10 pair interactions and day/night pacing.
  - Settings (7 pages), tray panel, toasts, the 4-step welcome and light/dark themes.
  - The native layer: real-input presence, hotkeys, single instance, autostart and
    full-screen detection.
  - The one-click updater, an Inno installer that upgrades v2.0 in place, and the
    developer-only Admin build.
- **Tests run in this session:**
  - On the developer PC, all short and with sound off:
    - All five headless suites pass: economy 79, import 1331, native 19, settings 31,
      updater 57 checks.
    - `--selftest` passes: 100,000 click-through checks.
    - A 20 s timed run with 6 critters exited cleanly with no errors. Median frame
      3.7 ms, p95 10.3 ms, 59 fps on Intel Iris Xe (editor binary).
  - **CI is red on the v3 tip:** `updater_test.gd`'s "no network is offline" check
    fails on the GitHub runner. It passes locally.
- **Not run in this session:**
  - The installed exe, any installer or upgrade path, and a VM soak.
  - Multi-monitor, DPI, sleep or display-change behaviour.
  - The Admin audit by eye.
  - Everything marked *suspected* below comes from reading code and still needs a
    test.
- **Biggest gaps:**
  - No log file and no diagnostics, so a tester cannot report anything.
  - A corrupt save silently wipes progress.
  - 11 of 16 Rare/Epic slots have no art of their own.
  - The game measures the screen only once, at launch.
  - CPU use is high and keeps running while the critters are hidden.
  - There is no beta channel. A normal GitHub release would go to every v2.0 user.

### Top ten blockers

| # | Blocker | Items |
|---|---|---|
| 1 | Release builds write no log, and there is no diagnostics button. A tester has nothing to send. | C1, T1 |
| 2 | A corrupt `economy.json` or `settings.json` is overwritten at the next save, so progress is gone. Logoff, taskkill or a fast Quit can lose recent progress and settings. | C2, C4 |
| 3 | Rare/Epic versions are missing for kitten, rabbit, duckling, hedgehog and otter (both tiers) and the squirrel's Epic. Those slots arrive in the Common look with a glow. | F1, D2 |
| 4 | There is no beta release path. `release.ps1` only makes "latest" releases, which v2.0's update checker offers to everyone. The About page shows "3.0" for every 3.0.x build. | K1, P1, D4 |
| 5 | CPU: 10-12 critters use about 0.75 of a core. There is no frame cap, and paused or hidden critters keep ticking at full rate. | S3 |
| 6 | The world is measured once at launch. A resolution, dock or taskbar change leaves critters and props off-screen. There is no DPI handling, and Settings is a fixed 1100×760 window. | F2, F3 |
| 7 | "Pause for full-screen apps" leaks. Props stay on top, and new arrivals appear over a full-screen game. | F4 |
| 8 | *Suspected:* after sleep/resume, the first frame's delta may credit hours of focus (berries, every gift, max luck). Nothing clamps it. | C5 |
| 9 | The install matrix is untested: v2→v3 per-user and per-machine, v3→v3 through the updater, and uninstall while running or with data deleted. | K3 |
| 10 | CI is red. Releases must come from `main`, which is 13 commits behind, and CI only runs on `v3`. | H1, H5 |

### Phases

| Phase | Goal | Exit check (short form) |
|---|---|---|
| 1. Decisions and housekeeping | One branch of record, a frozen scope, every open question answered | Decisions table filled in; main = v3 tip; CI green |
| 2. Correctness and data safety | Nothing a tester does can lose progress or settings; every build leaves a log | New tests green; corrupt save is quarantined, not overwritten; log file written by the player build |
| 3. Feature completion | Everything visible is finished, follows display changes and respects full screen | Admin audit (with new rows) all Pass; display-change and full-screen checks pass on the VM |
| 4. Balance and polish | Numbers checked by a sim that models v3; wording consistent | Updated sim meets the targets set in D9; wording checklist done |
| 5. Performance and stability | Measured against agreed thresholds, soaked on the VM | All thresholds in Phase 5 met on the release build |
| 6. Packaging and distribution | A beta build installs, upgrades, updates and uninstalls cleanly and reaches only testers | Install matrix passes on the VM; a prerelease exists that v2.0 does not see |
| 7. Beta kit | Testers know what to do, how to report, and what is already known | One person installs and reports a bug using only the kit |
| 8. Release candidate and go/no-go | One build, every check re-run on it | Go/no-go list all green, signed off |

---

## Phase 1: decisions and housekeeping

**Goal:** stop the ground moving. One branch, a frozen scope, and answers to every
question below, so later phases do not stall waiting on them.

**Entry:** this document.

**Items:**
- Decisions D1-D21 (answers go into the decisions table).
- H1 (branch of record), H2 (soak follow-up), H3 (branch cleanup), H4 (scope freeze),
  H5 (CI green).
- R1 (public-repo hygiene).

**Exit:**
- Every decision has an answer recorded in this file.
- `git rev-list --count origin/main..origin/v3` returns 0 (or the release flow
  chosen in D1 is in place).
- The latest CI run on the branch of record is green.
- `git branch -r --no-merged <branch of record>` lists only `v3-custom-critters-plan`
  and anything deliberately kept.
- The R1 grep (see its row) finds nothing.

**Risks:**
- Merging v3 into main while worktrees still sit on old branches.
- Decisions D2 and D9 need the developer's eyes on art and numbers, and can take
  longer than the rest.

## Phase 2: correctness and data safety

**Goal:** a tester cannot lose progress or settings, and every run leaves a log
that explains what happened.

**Entry:** Phase 1 exit. D3, D12 and D21 answered.

**Items:**
- C1 (logging), C2 (save safety), C4 (save on close/quit), C5 (delta clamp).
- C6 (startup default), C7 (v2 mappings), C8 (Seen Log import gate),
  C9 (hotkey reset, tray hint), C11 (native-missing notice), C13 (no-species guard).
- P1 (full version string).

**Exit:**
- `run-tests.ps1 -Native` is green, including the new cases:
  - garbage `economy.json` and `settings.json` are preserved as `.corrupt-*` files;
  - a `.bak` exists after two saves;
  - `tick(3600, true)` credits no more than the clamp;
  - each v2 mapping in C7 has a case.
- An installed player build writes a log containing the version, renderer and
  screen lines.
- Changing a setting and pressing Quit within 0.5 s keeps the change.
- `taskkill` (without `/f`) on the VM updates `economy.json`.

**Risks:**
- Save-format changes must stay readable by today's saves (CLAUDE.md: never clobber
  unknown keys).
- C5 must not break the real "away" logic.
- Logging must not write anything personal.

## Phase 3: feature completion

**Goal:** finish what is half-built, so testers judge the real thing.

**Entry:** Phase 2 exit. D2, D3, D8, D11, D13 and D18 answered.

**Items:**
- F1 (Rare/Epic versions), F2 (display changes), F3 (DPI), F4 (full-screen leaks),
  F5 (one-monitor rules), F6 (pairs give up), F7 (groom-less pairs, duckling tail),
  F8 (climbing per species), F10 (v2 custom-critter handling), F11 (fonts).
- C10 (size slider respawns), C14 (previews and secret colours).
- T1 (diagnostics), T4 (start over).

Per CLAUDE.md, each player-visible change lands with its Admin control and its
audit check in `checks()`.

**Exit:**
- An Admin build's audit page shows every row Pass, including the new rows: climb
  per species, display change, full screen, diagnostics, start over, and the versions
  for all 16 Rare/Epic slots.
- On the VM:
  - Change the resolution and toggle the taskbar while 8 critters are out. Every
    critter and prop is inside the new work area within 5 s.
  - Simulate a full-screen app for 10 min in timer mode at 1-minute intervals. No
    critter, prop or toast window becomes visible.

**Risks:**
- F2 and F3 touch window placement, which is where Windows-only bugs live. Test on
  the VM and on the two-monitor developer setup.
- F1 depends on the art picks in D2.

## Phase 4: balance and polish

**Goal:** the numbers are deliberate and checked, and the wording reads as one product.

**Entry:** Phase 3 exit. D9, D10 and D19 answered.

**Items:**
- B1-B6 (balance).
- P2-P10 (polish).
- F9 (hit boxes), F14 (concept art in the export).

**Exit:**
- `tools/economy_sim.py` models v3: 4 tiers, 34 slots, 84 items, the v3 odds, luck
  and Rare Hour.
- Its output meets the D9 targets, and its header and `economy.gd` agree.
- A wording grep finds one term each:
  - Seen Log, Collection or Sightings: one name for the feature.
  - "special visitors" or "Legendary visitors": one name.
  - One description of idle.
- The P items are ticked off.

**Risks:**
- Balance changes alter testers' perception mid-beta. Freeze the numbers before
  Phase 8.

## Phase 5: performance, stability and soak

**Goal:** measured, not felt. Soaks go on the test VM. Only short Intel-specific
checks go on the developer PC, at a time the developer picks, with sound off.

**Entry:** Phase 4 exit (code frozen apart from performance fixes). D17 answered.

**Items:** S1-S8.

**Proposed thresholds** (D17 confirms or changes them; release build):

| Measure | Where | Pass |
|---|---|---|
| Frame rate, default 8 critters | Dev PC, Iris Xe, 2 min | median ≥ 55 fps, p95 frame ≤ 20 ms |
| CPU, default 8 critters, active | Dev PC, 10 min | ≤ 25% of one core |
| CPU while paused, hidden by a full-screen app, or all napping | Dev PC, 10 min each | ≤ 3% of one core |
| 25 critters (the cap) | Dev PC, 2 min | ≥ 30 fps, no errors |
| GDI objects after 8 h default play | VM | ≤ 2,000 and not climbing linearly with arrivals |
| USER objects, threads, child processes | VM, 8 h | flat after hour 1 |
| Working set | VM, 8 h | hour 8 ≤ hour 1 + 15% |
| Window count | VM, sampled | ≤ critters + props + 3 toasts + 3 |
| Script errors, crashes | VM, 8 h with `--idle-sim` | 0 |
| Clean exits | Dev PC, scheduled, 30 exits | 30/30 exit code 0 (Intel GL teardown) |
| Sleep/resume | Laptop or VM suspend | berries gained ≤ minutes actually present |
| Pair completion | VM soak log | ≥ 90% reach the interaction |

**Exit:** every row passes on the release build, with numbers recorded in
`docs/v3-soak-report.md`, replacing the "6-hour soak under way" line.

**Risks:**
- The VM has no GPU, so frame-rate and CPU numbers only count from real hardware.
- The GDI leak is in Godot (`DwmEnableBlurBehindWindow`). A real fix may need window
  pooling or an engine patch (L).

## Phase 6: packaging and distribution

**Goal:** a beta build installs, upgrades, updates and uninstalls cleanly, and
reaches testers without reaching v2.0 users.

**Entry:** Phase 5 exit. D4, D5 and D15 answered.

**Items:**
- K1-K11.
- L1 (third-party notices), L3 (privacy check).

**Exit:**
- The install matrix in K3 passes on the VM. Each row has a logged result.
- A prerelease build is on GitHub, and a v2.0 install's update check does not offer it.
- The VirusTotal scan of the installer and exe is recorded in the release notes.
- Clean-clone build: the K5 steps produce a DLL that passes `native_test.gd`.

**Risks:**
- Unsigned builds trip SmartScreen, and maybe antivirus heuristics (raw input,
  global hotkey, Run key).
- Version numbering, if D4 is got wrong, strands testers on a build the updater
  will not replace.

## Phase 7: beta kit

**Goal:** testers know what to install, what to try, how to report, and what is
already known.

**Entry:** Phase 6 exit. D6 and D7 answered.

**Items:**
- T2, T3, T5-T9 (beta kit).
- R2 (README), R4 (troubleshooting), R6 (release notes).
- L4 (AI disclosure in credits).
- The known-issues list (every item deferred past beta).

**Exit:** one person who has not seen the project does all of this using only the kit:
- installs past SmartScreen;
- finds the diagnostics button;
- files a test report through the chosen route;
- uninstalls.

Every question they ask becomes a line in the kit.

**Risks:**
- An over-long guide goes unread. Keep the test checklist to one page.

## Phase 8: release candidate and go/no-go

**Goal:** one build, every check re-run on that exact build.

**Entry:** Phases 1-7 exit. No open blocker.

**Checks, all on the RC installer:**
- `run-tests.ps1 -Native` is green, and CI is green on the release commit.
- The Admin audit (admin build of the same commit) is all Pass.
- The manual checklist in T6 passes on the developer PC and on the VM.
- The K3 install matrix passes.
- The Phase 5 soak is re-run, an 8 h VM soak at minimum, and the exit test passes.
- The player exe does not contain `admin.gd` or `admin_page.gd`.
- The VirusTotal result is recorded.
- The known-issues list is reviewed.

**Go:** all of the above are green and the developer signs off.

**No-go:** any blocker regressed, or any new data-loss or crash finding.

---

## Item table

Areas:
- **H** housekeeping, **C** correctness, **F** features and world, **B** balance,
  **P** polish.
- **S** performance and stability, **K** packaging, **T** beta kit.
- **R** repo and docs, **L** licensing and legal.

Phase is the phase the item lands in. *Suspected* means read in code but not seen
happening.

### Housekeeping

| ID | Ph | Item | Why / severity | Size | Deps | Verify |
|---|---|---|---|---|---|---|
| H1 | 1 | Make one branch the branch of record. `origin/v3` is the tip, `main` is 13 behind, `release.ps1` insists on `main`, and CI runs only on `v3`. | Blocker: releases would be cut from stale code. | S | D1 | `git rev-list --count origin/main..origin/v3` = 0 (or `release.ps1` and CI changed to match D1). |
| H2 | 1 | Merge `v3-soak-followup` (the soak report finding 1 correction, plus `import_test.gd.uid`). | Should-fix | S | H1 | The branch is not listed by `git branch -r --no-merged`. |
| H3 | 1 | Retire merged branches (`v3-critters`, `v3-ci`, `v3-updater`, `v3-soak-fixes`, `v3-godot`, `claude/*`). Tag and delete `v3-hedgehog-wip`. Keep `v3-custom-critters-plan`. | Nice | S | H1 | `git branch -r` shows only the kept branches. |
| H4 | 1 | Scope freeze: v3.0 beta = today's v3 plus this plan. No new species, features or custom critters. | Blocker: without it, the later phases never end. | S | D-all | Written in this file. |
| H5 | 1 | CI is red on the v3 tip. `updater_test.gd` "no network is offline" fails on the GitHub runner, which has a different network, and passes locally. | Blocker: a red gate hides real regressions. | S | | The latest CI run on the branch of record is green. Re-run twice to rule out flakiness. |

### Correctness and data safety

| ID | Ph | Item | Why / severity | Size | Deps | Verify |
|---|---|---|---|---|---|---|
| C1 | 2 | No log file. `project.godot` has no file logging, and the exe is GUI-subsystem, so all output is lost. Log to `user://logs/` with rotation: version, renderer, screens and scale, native loaded or not, and errors. | Blocker | S | | The installed player build writes the log. After 6 launches, at most N files are kept. The log has no user paths beyond `%APPDATA%`. |
| C2 | 2 | Save safety. `economy.gd:544-551` and `settings.gd:85-93` treat unparseable JSON as "start fresh", and the next save overwrites it. There is no `.bak`, `rename_absolute` is unchecked, and loaded field types are unchecked (a wrong-typed but valid JSON can error later). Quarantine bad files, keep a `.bak`, recover from `.tmp`/`.bak`, and type-check on load. | Blocker: one bad write loses a tester's Collection. | M | | New economy and settings tests: garbage file → a `.corrupt-<time>` copy byte-identical to the original; `.bak` present after 2 saves; wrong-type fields load as defaults without errors. |
| C3 | 2 | `SAVE_VERSION` is written but never read. Read it, and refuse or migrate saves from a newer version, so a tester rolling back a build does not damage a newer save. | Should-fix | S | C2 | Test: a save with version 99 is left untouched and a warning is logged. |
| C4 | 2 | Quit paths: there is no `NOTIFICATION_WM_CLOSE_REQUEST` handler (soak finding 7), so logoff and `taskkill` skip the save. `_quit()` (`main.gd:1638`) saves the economy but not the settings (0.6 s debounce). | Blocker | S | | Set a value then Quit within 0.5 s → it is kept. VM: `taskkill` without `/f` → `economy.json` mtime updated. A logoff test on the VM. |
| C5 | 2 | *Suspected:* `economy.tick` (`economy.gd:128`), `focus_s`, `stay_left` and the timers take the raw frame delta. After sleep/resume or a long stall, one frame could credit hours: berries, all gifts and max luck. Clamp it, and treat a long gap as "away". | Blocker (laptops sleep daily, and it would corrupt the balance data) | S | | Economy test `tick(3600, true)` credits at most the clamp. A real suspend/resume on a laptop: berries gained ≤ minutes actually present. |
| C6 | 2 | The welcome sets Start with Windows on (`onboarding.gd:26` `startup := true`, applied in `_done`), including for v2 upgraders who had it off. | Should-fix | S | D12 | Upgrade test: a v2 install with autostart off, then finishing the welcome, leaves the Run key absent (or follows D12). |
| C7 | 2 | Silent v2 changes: timer-spawn settings are imported but `focus.mode` stays "gather"; v2's pause hotkey and `auto_launch` are ignored; there is no message about custom critters. | Should-fix | S | D3 | `settings_test.gd` cases for each mapping. An upgrade on the VM from a real v2.0 install. |
| C8 | 2 | The Seen Log import is gated on "no economy file" (`main.gd:346`), but the v2 read is gated on "no settings file" (`main.gd:303`). A crash between the two first saves skips the Seen Log import for good. | Should-fix | S | | Test: settings file present, economy absent, v2 present → the Seen Log is still imported once. |
| C9 | 2 | "Reset all settings" does not re-register hotkeys (`settings.gd:177`, `main.gd:322-327`). The tray pause hint is hard-coded to Ctrl+Shift+P (`tray.gd:206`). | Should-fix | S | | Rebind pause, Reset all → the old chord no longer pauses and the new one does. The tray shows the bound chord. |
| C10 | 3 | The size slider respawns every critter on each notch (`settings_pages.gd:83` → `main.gd:1543-1569`). That re-rolls the Legendary colour and version, drops a brought present, leaks GDI (S2) and leaves props unresized. | Should-fix | M | | With a unicorn out, drag size 80→200 → same colour, same present, the window count does not grow, props resized. |
| C11 | 2 | If the native DLL fails to load, single instance, autostart, hotkeys, the taskbar hide and full-screen pause all vanish silently (`main.gd:314`). Log it and show a notice in System; disable the dead toggles. | Should-fix | S | C1 | Rename the DLL in an installed copy → the log line and the System notice appear, and the startup toggle is disabled. |
| C12 | 2 | `single_instance` returns true when `CreateMutexW` fails (`critter_native.cpp`). A second copy is then allowed. | Nice | S | | Native test: a mutex created by a second process with a denied ACL → returns false. |
| C13 | 2 | Every species can be switched off in Settings (`settings_pages.gd:531` has no guard, unlike the welcome), and then nothing ever arrives. | Should-fix | S | | Switching off the last species is refused, or a notice explains it. |
| C14 | 3 | Previews ignore version and colour (`critter_view.gd:60-90`, `collection.gd:280`). Collection cards build a random Legendary colour, which can show a colour the player has not met. The palette tint key is `"golden"`, not `"golden_kitten"` (`palette.gd:38`). | Should-fix: it breaks "secret until met". | S | | Admin check: after meeting one unicorn colour, 20 rebuilds of the card show only that colour. Rare/Epic slots show their version. |
| C15 | 3 | A second launch exits silently (it prints only). Tell the running copy to open Settings, or show a toast. | Nice | M | | Launch twice → the first instance opens Settings. |

### Features and world

| ID | Ph | Item | Why / severity | Size | Deps | Verify |
|---|---|---|---|---|---|---|
| F1 | 3 | Rare/Epic versions for kitten, rabbit, duckling, hedgehog and otter (both tiers) and the squirrel's Epic. `species.gd` `versions` covers only turtle, squirrel (Rare) and panda. 24 candidate folders already exist in `godot/art/<species>/`. | Blocker: 11 of 16 Collection slots look Common. | M (wiring) + art time | D2 | Admin "Every version drawn" shows 16 distinct versions. The Collection test counts 16 version entries. |
| F2 | 3 | Display changes: `area` and `screen_rect` are set once (`main.gd:279-283`). Edges, perimeter, props and throw bounds are cached, with no handler for resolution, monitor, taskbar or DPI changes. | Blocker: docking, RDP and taskbar moves strand critters off-screen. | M | D8 | VM: change the resolution and move the taskbar with 8 out → everything is inside the new work area within 5 s. A new Admin row. |
| F3 | 3 | DPI: there is no scale handling. Critter size, toasts and the fixed 1100×760 Settings window (`settings_window.gd:17`) are in physical pixels. At 150% critters look two-thirds size, and on a 1366×768 screen Settings is clipped. | Blocker (for Settings fit) | M | | VM at 1366×768 at 100%, and 1920×1080 at 125% and 150%: Settings is fully visible, and critter height = size × scale. |
| F4 | 3 | Full-screen leaks: `_show_critters` (`main.gd:1172`) hides hosts but not props. New arrivals `show()` while `busy_hidden` (`host.gd:193`). Hidden hosts keep ticking and auras keep redrawing. | Blocker: critters popping over a game is the worst first impression. | S | | VM, simulated full-screen state, timer mode every 1 min, 10 min → 0 visible windows of the process. CPU in that state is in Phase 5. |
| F5 | 3 | Monitors: only the primary is used. A hard throw toward monitor 2 vanishes, and a drag can drop a critter on monitor 2. Make primary-only consistent (clamp the drag and throw) or span monitors. | Should-fix | S (primary-only) / L (span) | D8 | Two-monitor test: a drag and a throw toward monitor 2 keep the critter on the primary. |
| F6 | 3 | Pairs give up in `approach` 36% of the time (soak finding 5; `APPROACH_LIMIT` 8 s against starts up to 420 px apart). | Should-fix | S | | Soak log: at least 90% of started pairs reach the interaction. |
| F7 | 3 | Groom pairs (`pairs.gd:247-249`) run `groom` on turtle and unicorn, which have no groom art (a head bob with shut eyes). The duckling's `tail_swish` shows nothing when sitting (`duckling.gd:54`). | Should-fix | S | | Admin pair rows for turtle and unicorn partners, and the duckling move row, all Pass by eye. |
| F8 | 3 | Climbing is audited for the kitten only (`admin.gd:223`). The rabbit's hop gait probably hops up walls. Add a per-species climb row and fix what it finds. | Should-fix | M | | Admin climb row per species, all Pass. |
| F9 | 4 | Hit boxes reuse "sit" for the hedgehog ball, the otter belly roll and the panda roll, so clicks above the ball count as hits. | Nice | S | | An Admin click test on each pose. |
| F10 | 3 | v2.0 custom critters: whatever D3 decides (recommended: keep the files, remember the sightings, tell the user once). | Should-fix | S | D3 | VM upgrade from v2 with 2 customs → the message shows once, `%APPDATA%\CritterOverlay\custom` is untouched, and the custom sightings are kept in the save. |
| F11 | 3 | Fonts: the UI asks for Fredoka and Nunito through `SystemFont` (`gui/ui.gd:21`), but they are not bundled. Most users get Segoe UI, not the designed look. | Should-fix | S | D13 | On a clean VM, the Settings screenshot matches the design font. |
| F12 | 3 | *Suspected:* with an auto-hide taskbar, the work area is the full screen, so feet sit under the taskbar. | Should-fix | S | F2 | VM with auto-hide on: feet visible. |
| F13 | 5 | *Suspected:* touch and pen input may not count as presence (raw input without a device handle), so a tablet user would read as away. | Nice (test, then known issue) | S | | One touch device, or listed as a known issue. |
| F14 | 4 | 24 unpicked concept folders (about 1.2 MB) ship in the player export. Exclude unpicked versions after D2. | Nice | S | F1 | The exported pck has no unreferenced version folders. |

### Balance

| ID | Ph | Item | Why / severity | Size | Deps | Verify |
|---|---|---|---|---|---|---|
| B1 | 4 | Legendary pacing. Completing all 10 visitor colours takes about 140 weeks at medium play and is effectively never for light play (twilight_neon is 3% of visitor rolls, split between two visitors). | Should-fix | M | D9, B5 | The sim meets the D9 target. |
| B2 | 4 | Luck stacking. Luck ×3, Rare Hour ×2 and the lucky charm ×1.5 make rare+ about 45% per roll, and the charm can be worn by every species. | Should-fix | S | D9 | The sim reports the rare+ share at max stack within the target. |
| B3 | 4 | Roll farming: | Should-fix | S-M | D19 | One economy test per closed loophole. |
| | | - a relaunch rolls `start_with` critters at the saved luck; | | | | |
| | | - timer mode rolls 6-10× more than gather mode; | | | | |
| | | - the spawn key rolls on every press; | | | | |
| | | - "Clear the Seen Log" re-pays every first find and row bonus (about 9k berries). | | | | |
| B4 | 4 | The first-visitor bonus is spent by `start_with` critters, timer groups and solo walkers, and even when rarity is off. | Should-fix | S | | Test: rarity off at launch, on later the same day → the bonus is still available. |
| B5 | 4 | `tools/economy_sim.py` models v2 (Uncommon, 48 slots, 71 items, coins), but the `economy.gd` header says the two match. Rewrite it for v3. | Should-fix: balance is guesswork without it. | M | | The sim's constants are read from or checked against `economy.gd`, `species.gd` and the wear catalogue. |
| B6 | 4 | The first-visitor comment (`economy.gd:26`) says "v2.0's" bonus. The odds differ: v3 has 78/20/2, v2 had 70/20/10. | Nice | S | | The comment is correct. |

### Polish

| ID | Ph | Item | Why / severity | Size | Deps | Verify |
|---|---|---|---|---|---|---|
| P1 | 2 | Version shown as `VERSION.substr(0,3)` (`settings_window.gd:145`, `settings_pages.gd:1480`): every 3.0.x build reads "3.0", and 3.10 would read "3.1". Show the full version plus the beta label. | Blocker: testers must be able to say which build they run. | S | D4 | About and the sidebar show e.g. "3.0 beta 2 (2.90.2)". |
| P2 | 4 | Wording: | Should-fix | S | | A grep finds one term for each. |
| | | - the same feature is called Seen Log, Collection and Sightings; | | | | |
| | | - "special visitors" and "Legendary visitors"; | | | | |
| | | - idle is described three ways; | | | | |
| | | - the sidebar says "Gathering" in timer mode. | | | | |
| P3 | 4 | "Good morning" shows from 00:00 (`settings_pages.gd:98`). The update toast's progress bar sits full for 12 s (`toast.gd:126/294`). The welcome's fake taskbar has a dd/mm date format hard-coded (`onboarding.gd:335`). | Nice | S | | By eye. |
| P4 | 4 | Only sighting toasts can be turned off. Toasts are dropped, not queued, while paused or in full screen. | Nice (ask testers) | S | | A tester question. |
| P5 | 4 | Keyboard: | Nice | M | | Keyboard-only walkthrough of the tray, Settings and a toast. |
| | | - the tray panel has `FOCUS_NONE`; | | | | |
| | | - Esc does not close Settings; | | | | |
| | | - focus is lost on every rebuild; | | | | |
| | | - info tips are mouse-only. | | | | |
| P6 | 4 | *Suspected:* the tray panel rebuilds every 0.5 s while open (`tray.gd:51-58`) and may swallow a click. | Should-fix | S | | 50 scripted clicks on tray items all register. |
| P7 | 4 | "Reset all critters" and "Reset <species>" apply with no confirmation. | Nice | S | | A confirm step exists. |
| P8 | 4 | An open window does not follow a live Windows light/dark switch. | Nice | S | | Switch the theme with Settings open → it updates. |
| P9 | 4 | Stale or garbled comments: the `pairs.gd:15-16` header, and `critter.gd:23` and `:80`. | Nice | S | | Read. |
| P10 | 4 | `hedgehog.gd` duplicates `two_head.gd`, so fixes to one miss the other. | Nice (after beta) | M | | |

### Performance and stability

| ID | Ph | Item | Why / severity | Size | Deps | Verify |
|---|---|---|---|---|---|---|
| S1 | 5 | Agree the thresholds (table in Phase 5) and a repeatable script for each row (`tools/soak/`). | Blocker: the phase cannot exit without them. | S | D17 | The script exists and the numbers are recorded. |
| S2 | 5 | GDI leak, about 1.75 objects per window created (Godot `DwmEnableBlurBehindWindow` HRGN; soak finding 4). That is about 55 an hour in normal play and much faster with C10 or churn. The per-process limit is 10,000. | Should-fix: it caps the session length. | M-L | C10 | 8 h VM soak: GDI ≤ 2,000. |
| S3 | 5 | CPU: 10-12 critters use 0.7-0.8 of a core at about 49 fps; 20 run at about 15 fps (soak finding 6). Causes: | Blocker: a work companion cannot eat a core on a laptop. | M | F4 | The Phase 5 CPU rows pass. |
| | | - no `max_fps` or low-processor mode when paused, hidden or all napping; | | | | |
| | | - hidden hosts keep ticking; | | | | |
| | | - `win.position` is set every frame per critter (`host.gd:249`); | | | | |
| | | - trail and aura redraw every frame. | | | | |
| S4 | 5 | Sleep/resume, lock, RDP connect and disconnect, and display change while running. Not handled anywhere, and never tested. | Blocker (as a test) | M | C5, F2 | Each scenario passes on the VM or a laptop, with the result logged. |
| S5 | 5 | The 6-hour VM soak is still "under way" in the report, with no result. Re-run it after Phases 2-4 on the release build. | Blocker | S (run) | C1 | Results in `docs/v3-soak-report.md`. |
| S6 | 5 | The first arrival of each species or version rasterises about 23 SVG parts on the main thread (a visible hitch). | Nice | M | | p99 frame time at arrival is under 50 ms, or listed as a known issue. |
| S7 | 5 | `vsync_taken` (`host.gd:151`) is never reset when the vsynced critter leaves. *Suspected* uneven pacing afterwards. | Should-fix | S | | The frame-time p95 does not change after the first critter leaves. |
| S8 | 5 | The texture cache is never evicted. Measure memory with every species and version loaded. | Should-fix (measure) | S | F1 | The working-set row passes. |

### Packaging and distribution

| ID | Ph | Item | Why / severity | Size | Deps | Verify |
|---|---|---|---|---|---|---|
| K1 | 6 | Beta release path. `release.ps1` always makes a "latest" release from `main`, and both v2.0's and v3's update checkers read `/releases/latest`. A beta released that way goes to every v2.0 user. Add a prerelease mode and the D4 numbering. | Blocker | S | D4, H1 | A prerelease exists; a v2.0 install and a v3 install both report "up to date". |
| K2 | 6 | Signing and antivirus. The installer and exe are unsigned (`codesign/enable=false`, no SignTool). Raw input plus a global hotkey plus a Run key can match keylogger heuristics. | Should-fix for beta, blocker for public | S (scan) / M (signing) | D5 | VirusTotal result recorded per build. The SmartScreen steps are in the tester guide. |
| K3 | 6 | Install matrix on the VM, each row logged: | Blocker | M | K1 | All rows pass. |
| | | - fresh install; | | | | |
| | | - v2.0 per-user → v3; v2.0 per-machine → v3 (possible second install under the same AppId); | | | | |
| | | - v3 → v3 through the updater (`/UPDATE=1`) and by manual reinstall; | | | | |
| | | - uninstall while running; | | | | |
| | | - uninstall keeping data, and uninstall deleting data; | | | | |
| | | - reinstall after a data delete. | | | | |
| K4 | 6 | Uninstall "delete data" also deletes `%APPDATA%\CritterOverlay`, v2.0's folder, including custom critters (`installer-v3.iss:204-224`). | Should-fix | S | D3 | The uninstall prompt names what is deleted, or keeps the v2 custom folder. |
| K5 | 6 | Native build reproducibility. godot-cpp is an unpinned sibling folder, `extension_api.json` is gitignored, CI never builds the DLL, and the static runtime is not set explicitly. | Should-fix | M | | Clean-clone steps documented. `dumpbin /dependents` shows no VC++ redistributable. `native_test.gd` passes. |
| K6 | 6 | CI covers only `v3`. There is no export smoke test, no Admin-exclusion check and no installer compile. | Should-fix | M | H1 | CI on the branch of record exports the player preset and checks it has no admin scripts. |
| K7 | 6 | The `release.ps1` Admin guard checks for `admin_page.gd` only. | Nice | S | | It checks for `admin.gd` too. |
| K8 | 6 | A failed build after the version bump leaves `release.ps1`'s tree dirty. The `.import` rewrite may dirty the tree (CRLF). | Should-fix | S | | A dry run on a clean clone leaves `git status` clean. |
| K9 | 6 | The publisher changes between v2 (a full name) and v3 (`hstagg`) in Apps & features. | Nice | S | D15 | One publisher string. |
| K10 | 6 | Beta mode (`--beta`) is only reachable from a launch flag, and it sticks once set. | Should-fix | S | D18 | Follows D18. |
| K11 | 6 | The updater depends on GitHub's asset `digest` and the exact asset name. If either changes, every user falls back to a manual download. | Nice | S | | Release checklist step: the API shows a digest for the asset. |

### Beta kit

| ID | Ph | Item | Why / severity | Size | Deps | Verify |
|---|---|---|---|---|---|---|
| T1 | 3 | Diagnostics in System: "Open log folder" and "Copy diagnostics" (version and build, renderer, screens and scale, native status, settings, economy summary, last log lines). Nothing leaves the machine unless the tester sends it. Add an Admin check per CLAUDE.md. | Blocker | S-M | C1 | The button produces a file. The Admin row is Pass. |
| T2 | 7 | Feedback route and bug template: what happened, what was expected, steps, build, diagnostics file, screenshot. | Blocker | S | D6 | The template exists and a test report has been filed through it. |
| T3 | 7 | Tell builds apart: the beta label in About, the tray tooltip and the installer name. | Blocker | S | P1, D4 | Visible in all three places. |
| T4 | 3 | "Start over" in System: wipes progress and settings and shows the welcome again. Today only "Clear the Seen Log" exists, and "Reset all settings" keeps `onboarded`. Add an Admin control. | Should-fix | S | C2 | After Start over, the welcome shows on next launch and the economy is fresh. A backup of the old save is kept. |
| T5 | 7 | Whether testers get beta mode (editable odds). | Should-fix | S | D18 | Documented in the guide. |
| T6 | 7 | Tester guide plus a one-page checklist: | Blocker | M | T1-T3 | The Phase 7 exit check. |
| | | - install past SmartScreen; | | | | |
| | | - the first 15 minutes: welcome, first critters, pop, drag and throw, pause key, tray; | | | | |
| | | - a day of normal work: nap and wake, gifts, Rare Hour, Shop, Collection; | | | | |
| | | - settings persist after Quit; | | | | |
| | | - updating to the next beta; | | | | |
| | | - uninstalling. | | | | |
| T7 | 7 | Known-issues list, built from every item deferred past beta, plus F13 and S6 if they are not fixed. | Blocker | S | | In the guide and the release notes. |
| T8 | 7 | Balance questions for testers: | Should-fix | S | | In the guide. |
| | | - how often critters arrive; | | | | |
| | | - whether Rare feels rare; | | | | |
| | | - Rare Hour timing; | | | | |
| | | - berries while paused; | | | | |
| | | - the shop prices against what they earned in a week; | | | | |
| | | - whether showing the visitors as silhouettes spoils them. | | | | |
| T9 | 7 | An opt-in "stats" section in the diagnostics file (berries, Collection size, focus minutes, arrivals per hour) that answers the balance questions without telemetry. | Should-fix | S | D7, T1 | Included in the diagnostics output. |

### Repo and docs

| ID | Ph | Item | Why / severity | Size | Deps | Verify |
|---|---|---|---|---|---|---|
| R1 | 1 | Public-repo hygiene: | Should-fix | S | D15, D21 | A grep of the tracked files for absolute user paths and `claude.ai/artifact` finds nothing. Name policy applied per D15. |
| | | - a tracked Claude Code hook with an absolute personal path (`.claude/settings.json:14`); | | | | |
| | | - an absolute personal temp path in `design/gui/parts.py:4`; | | | | |
| | | - claude.ai artifact links in code (`admin_page.gd:26`, admin-only but public); | | | | |
| | | - the developer's first name in code comments (`economy.gd:26`, `host.gd:14`, `wear.gd:9,17,27`, `settings_pages.gd:923`, `design/studio/*.py`); | | | | |
| | | - "Contact <first name>" in `docs/TROUBLESHOOTING.txt`; | | | | |
| | | - a once-committed personal README in history (`73e8af2` removed it). | | | | |
| R2 | 7 | `README.md` describes v2.0 throughout: `.pyzw`, Python, 8 animals, Uncommon, custom critters, the v2 mutex. Rewrite it for v3 (testers land there from the release page). | Should-fix | M | | No v2-only instructions remain. |
| R3 | 1 | Most of `CLAUDE.md` describes v2: "State of play" is dated 2026-05-23 (v1.10.0), and the build/run steps, project structure, code style (mutex, chroma key) and manual checklist are v2-era. Update it; the developer approves. | Should-fix | S | | State of play names the v3 branch and this plan. |
| R4 | 7 | `docs/TROUBLESHOOTING.txt` is the v2 Python guide. Replace it with v3 troubleshooting: SmartScreen, logs, reset, uninstall. | Should-fix | S | C1 | Read. |
| R5 | 7 | v1/v2 leftovers in the v3 tree: | Nice for beta, should-fix before public | S | D16 | Follows D16. |
| | | - `src/`, `__main__.py`, `scripts/`, `build.ps1`, `build.bat`, `run.bat` and `CritterOverlay.spec`; | | | | |
| | | - `Archive/` (v1 zips, art prompts) and `Sprite Images/`; | | | | |
| | | - the v1/v2 handoffs and release notes; | | | | |
| | | - a market research document. | | | | |
| R6 | 7 | Release notes for each beta build (`release-notes-v3.0-beta.md`). | Blocker | S | T7 | Attached to the prerelease. |

### Licensing and legal

| ID | Ph | Item | Why / severity | Size | Deps | Verify |
|---|---|---|---|---|---|---|
| L1 | 6 | Third-party notices: Godot's licence is shown in About (good); godot-cpp (MIT, inside the DLL) is not credited; bundled fonts (F11) need the OFL text. Add `THIRD-PARTY-NOTICES.txt` to the installer and link it from About. | Should-fix | S | F11 | The file is installed and every component is listed. |
| L2 | 6 | `installer/license.txt` is a custom non-commercial licence. Decide whether beta testers need anything more, such as "please do not share builds". | Nice | S | | Follows the decision. |
| L3 | 6 | Privacy: the only network use is the update check (GitHub; it sends the `User-Agent` version). Confirm on the VM with a network capture during the soak, and state it in the tester guide. | Should-fix | S | S5 | The capture shows only `api.github.com` (and the download hosts when updating). |
| L4 | 7 | The credits say "Code and art by its author", but the art was made with AI assistance. Make the credits accurate now; the store-page disclosure comes later. | Should-fix | S | D14 | The credits text matches D14. |
| L5 | 7 | Art provenance: v1 sprite prompts are in `Archive/`. Confirm that no v1/v2 raster art ships in v3 (v3 uses its own SVGs). | Nice | S | R5 | The exported pck has no v1 sprites. |

---

## Decisions for Harrison

Answer these up front. Each has the options and a recommendation; write the answer
in the last column.

| ID | Question | Options | Recommendation | Answer |
|---|---|---|---|---|
| D1 | Branch of record and release flow | (a) Merge v3 into main now; main becomes the dev branch again (as CLAUDE.md says); CI moves to main; v3 retires. (b) Keep v3 as the dev branch; merge to main only to release; CI on both. (c) Let `release.ps1` release from v3. | **(a)**: one branch, matching `release.ps1` and CLAUDE.md. | |
| D2 | The 11 missing Rare/Epic looks | (a) Pick from the 24 candidates already drawn (Admin > Every version drawn), polish later. (b) Ship the beta with Common look plus glow, and say so. (c) New designs first. | **(a)**: the candidates exist; picking is the bottleneck. | |
| D3 | v2.0 users' custom critters on upgrade (v3 skips `custom:` entries; v2's files in `%APPDATA%\CritterOverlay\custom` are untouched unless an uninstall deletes data) | (a) Do nothing: they silently disappear from the overlay. (b) Preserve and tell: a one-time notice ("your N custom critters are safe and will come back in a later update"); keep the `custom:` sightings in the save for the later import; make "delete data" on uninstall spare or name that folder. (c) Sticker carry-over (plan Tier 1: still image with procedural motion) in v3.0. (d) Keep v2 runnable alongside: not possible, since both share the AppId. | **(b)**: small, loses nothing, and keeps v3.0's scope; (c) is real engine work that belongs to the custom-critters update. | |
| D4 | Beta channel and numbering | (a) GitHub prereleases numbered below 3.0.0 (e.g. `2.90.N`, shown as "3.0 beta N"); testers reinstall each build; 3.0.0 final then auto-updates them; no updater change. (b) Teach the updater a beta channel (reads `/releases`, accepts prereleases when beta is on): automatic beta updates, but it touches the updater (a discuss-first area). (c) Private download link, outside GitHub. | **(a)** for a small group; revisit (b) if there are many builds. | |
| D5 | Code signing for the beta | (a) Unsigned, with SmartScreen steps and a VirusTotal link per build. (b) Buy a signing service now. | **(a)** for known testers; signing before any public build. | |
| D6 | How testers report | (a) GitHub issue form. (b) Private form or email with the diagnostics file attached. (c) A chat group. | **(b)**, with (a) for testers who use GitHub: not everyone has an account, and screenshots of a desktop can be personal. | |
| D7 | Telemetry | (a) None; opt-in stats inside the diagnostics file (T9). (b) An opt-in network ping. | **(a)**: keeps "the app sends nothing" true. | |
| D8 | Monitors | (a) Primary only for v3.0, made consistent (no losing critters to monitor 2), and documented. (b) Roam all monitors. | **(a)** for beta. | |
| D9 | Collection pacing target | (a) Set targets (e.g. a medium player fills the 24 everyday slots in about 4 weeks and meets every visitor colour in about 6 months) and tune the weights with the new sim. (b) Add a pity counter. (c) Leave it and watch. | **(a)**; keep (b) in reserve until beta data says it is needed. | |
| D10 | Rare Hour default | (a) Keep 21:00. (b) An afternoon default. (c) An hour that moves each day. | Keep the setting, change the default to **(b)**, and ask testers. | |
| D11 | Spoilers before a visitor is met | (a) Silhouettes and colour pips shown (today). (b) Silhouettes only, no colour count. (c) Nothing until first met. | **(b)**: curiosity without giving the count away. | |
| D12 | Start with Windows in the welcome | (a) On by default (today; also flips upgraders on). (b) Off by default. (c) On for fresh installs; upgraders keep their current state. | **(c)** | |
| D13 | UI fonts | (a) Bundle Fredoka and Nunito (OFL) with their licence. (b) Design for Segoe UI. | **(a)** | |
| D14 | AI-assistance wording in credits | (a) A short accurate line now (e.g. "art made with AI assistance, directed and edited by the author"). (b) Wait for the store page. | **(a)**: the current credit is inaccurate. | |
| D15 | The developer's name in the repo | (a) Neutralise code comments ("design pick") and keep the legal name only in the licence and publisher. (b) Leave as is. | **(a)** | |
| D16 | v1/v2 leftovers | (a) Tag `v2-final`, then remove v2 code, `Archive/`, the handoffs and the market document from the v3 tree. (b) Move them to a `legacy/` folder. (c) Leave them. | **(a)**, before any public build; the tag keeps v2 rebuildable. | |
| D17 | Performance thresholds | The Phase 5 table as proposed, or changed. | Accept, then adjust after the first measurements. | |
| D18 | Beta mode for testers | (a) Off: testers play the real odds. (b) On for everyone. (c) A few testers on purpose. | **(a)**; keep `--beta` for the developer. | |
| D19 | Which roll-farming loops to close before beta (B3) | Clear Seen Log re-paying, relaunch rolls, timer-mode roll count, spawn-key rolls. | Close **Clear Seen Log re-paying** now; watch the rest in beta. | |
| D20 | Berries while paused (by design today) | (a) Keep. (b) No berries while paused. | Keep, and ask testers (T8). | |
| D21 | History | Rewrite history to drop the once-committed personal README (`73e8af2`)? | Check what it contains first; rewrite only if it holds personal data. | |

---

## What was run, and what could not be verified

**Run in this session, on the developer PC (short, sound off):**
- `run-tests.ps1 -Native`: 5/5 suites pass.
- `--selftest`: pass.
- A 20 s `--seconds=20 --kittens=6` run with throwaway settings and save: exit 0,
  no errors.

**CI:** the last run on `v3` failed (`updater_test.gd`, H5). The two before it passed.

**Not run:**
- The installed exe and the installers.
- Upgrades.
- VM soaks (heavy runs belong on the VM, and this was a planning session).
- Multi-monitor and DPI changes at runtime.
- Sleep/resume.
- The Admin audit by eye.

Items marked *suspected* (C5, F12, F13, P6, S7) need their check run before any fix.

**Notes from the run:**
- On a two-monitor setup (a 150% primary plus a second monitor above it), the report's
  play area was the primary's work area, in Godot's shifted coordinates. That is
  expected, and it confirms the primary-only behaviour behind D8.
- The 6 critters drew in 240 px windows at size 120 with no DPI adjustment (F3).
