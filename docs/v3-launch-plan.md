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
| 4 | The About page shows "3.0" for every 3.0.x build, so builds cannot be told apart. (There are no outside users yet, so normal releases are fine: D4.) | P1 |
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

## Progress

Updated 2026-10-13.

- **Phase 1: done** (D2, the Rare/Epic picks, answered 2026-10-17), except GitHub Support's purge of cached old commits
  (requested by the developer). Done: D21 history rewrite, H1-H5, R1, R3,
  D16 (v1/v2 kept at tag `v2-final`).
- **Phase 2: built** (C1-C6, C8, C9, C11, C13, P1). C7 needed no code:
  v2.0 never let the pause key change, and its autostart is covered by C6.
  C12 is left as nice-to-have.

Findings along the way:

- Godot already writes rotating logs to `%APPDATA%\Critter Overlay\logs`;
  the audit's "no log file" was wrong. C1 became the START line that makes
  those logs useful.
- Runs from source and the tests write to the same log folder as the
  installed app, so they rotate its real logs out. Known issue.
- A close request reaches the app only through a visible window. With
  every critter hidden (paused, asleep in the cottage, none out),
  `taskkill` without `/f` does not reach it, and logoff is untested. The
  60 s autosave is the backstop; S4 checks both.
- No test compiled `main.gd`, so a type error there passed CI.
  `compile_test.gd` now loads every script.
- T4 (Start over) must keep `system.v2_seen_done`, or the v2.0 Seen Log
  would come back.
- **Phase 3a: built** (T1, T4, F4, F10, C10, C14 and D11). Start over keeps
  the v2.0 import flags. Previews and the Collection never show a colour
  that has not been met. Unmet visitors are one "?" slot each, so the
  Collection total grows as visitors are met (26 at the start, not 34).
- Polish for Phase 4: in dark mode, an unmet critter's silhouette is a faint
  copy of its art, so it hints at the colour.
- **Phase 3b: built** (G2, the game design rules). Numbers are provisional
  until the sim (B5): one roll banked per 5.5 focus minutes, at most 6, and
  30 berries for Spawn now.
- Decided while building it: rolling rarity before the species means the
  lucky charm can't favour its wearer any more. It now gives every roll 1.5x
  luck, counted once, which also fixes the stacking in B2.
- Existing settings files keep their saved Rare Hour start (21:00 for v2.0
  upgraders). The 15:00 default reaches new installs and Start over only.
- **Phase 3c: built** (F2, F3). Every 2 s the app checks the primary screen's
  size, work area and display scale. If any changed, it measures again and
  redraws everyone inside it. Critters, Settings, the welcome, the tray panel
  and the notes follow the display scale, and Settings and the welcome shrink
  to fit a small screen. F5 needed no code: a slow drag onto another monitor
  snaps back when released, and a hard throw off the edge is the existing
  throw-away, as on any edge. F12 (auto-hide taskbar) stays a VM check in S4.
- Polish for Phase 4: the welcome's critter strip is wider than its card and
  clips the card's right edge (seen at every scale, so not new).
- **Phase 3e: built** (F11). Fredoka and Nunito are bundled in `godot/fonts`
  (the variable TTFs from google/fonts, SIL OFL 1.1). The OFL text ships with
  them and is shown in Credits, which covers the font part of L1.
- **Phase 3d: built** (F6, F7, F8).
  - F6: a pair's walk-over limit follows the distance and the walker's pace
    (8 to 25 s). On a 10-minute VM run with 8 critters, 7 of 8 pairs reached
    the interaction; the soak report had a third giving up. 8 is too few to
    judge the 90% bar, so the Phase 5 soak measures it.
  - F7: in grooming pairs, the turtle and unicorn (no groom art) look at
    their partner instead. The duckling no longer has tail_swish, which
    showed nothing while sitting.
  - F8: the Admin climb check runs for the species chosen. VM frames of all
    10 climbing the right wall: head upright and body along the wall for
    every one. Whether the rabbit hops instead of climbing shows only in
    motion, which is an Admin audit item.
- Working rule from 2026-10-13: anything that opens windows is tested on the
  VM, never the developer's PC.
- **Phase 4, balance: done** (B1, B2, B4, B5, B6).
  - `tools/economy_sim.py` now models v3. It reads its numbers from the game
    files and simulates light, medium and heavy players minute by minute.
  - Changes: Epic odds 0.9% to 0.7%. Visitor colour weights flattened, so
    the rarest is a third as likely as the commonest, not a twelfth. Prices:
    small 150, medium 500, large 2,000, showpiece 6,000, perk 12,000. Dye,
    treat and Spawn now are unchanged at 100, 60 and 30.
  - Results over 40 seeds, as medians:

    | Player | 24 everyday | 10 Legendary colours | Small | Showpiece | Perk |
    |---|---|---|---|---|---|
    | Light (1.5 h, 4 days) | 11 weeks | over 3 years | 1.4 h | 10 weeks | 19 weeks |
    | Medium (4 h, 5 days) | 3.9 weeks | 53 weeks | 1.3 h | 2.6 weeks | 5.2 weeks |
    | Heavy (7 h, 6 days) | 1.9 weeks | 26 weeks | 1.9 h | 1.8 weeks | 3.6 weeks |

  - B4 was already fixed by the roll bank (3b): the first-visitor bonus is
    spent only on a real roll.
  - B2: with luck at 3x, Rare Hour and a charm, Rare or better reaches about
    43% of rolls. That peak now needs one charm and an evening of focus, not
    a charm on every species. Left as a tester question.
  - The Legendary set is a coupon-collector tail, so its median varies a lot
    between seeds (p10 32 weeks, p90 135 weeks for medium players).
- **Phase 4, polish: done** (P2, P3, P5 in part, P7, P9, and the two Phase 3
  notes).
  - One word for each idea: "Legendary visitors", one idle phrase, "Record
    what you meet" instead of v2.0's "Seen Log", and "Timer" in the sidebar
    in timer mode.
  - The greeting at night is "Good evening". An update note's bar drains
    over its own 18 s. The welcome's mock taskbar shows the time only.
  - Esc closes Settings. "Reset all critters" and "Reset <critter>" ask
    first.
  - Stale comments fixed in pairs.gd and critter.gd.
  - The welcome's critter strip is cropped inside its card instead of
    stretching it. Unmet critters in dark mode are shadows, so no colour
    shows through.
  - Checked on the VM with the new `tools/soak/vm/tour.ps1`.
- Left open from Phase 4:
  - P4 (which notes can be turned off) and P8 (live theme switching) are
    tester questions or nice-to-haves.
  - The tray's keyboard focus (P5) waits on P6: the panel rebuilds twice a
    second, which would throw focus away.
  - F9 (hit boxes for ball poses) and P10 (the hedgehog's copy of
    two_head.gd) are after beta.
  - F14 waits for the Rare/Epic picks (3f).
  - New: on a 1280-wide screen, the Collection's Sightings diary box runs
    past the right edge of its column.
- **Phase 5, in progress.**
  - S3: fewer frames when there is little to see. 5 fps when nothing is on
    screen (paused, hidden for a full-screen app, nobody out). 20 fps when
    everyone is asleep. Full speed whenever an app window is open. Animation
    detail "Simple" also caps at 30 fps. A critter window moves only when its
    position changes.
  - VM CPU, 8 critters, before and after: awake 227% to 226% (software
    rendering dominates, so no change shows); asleep 217% to 127%.
  - S7: when the window that paces the frame goes, the next one takes over.
  - S4, sleep: the VM was frozen for 10 minutes mid-run from its host. The
    save shows 15.0 focus minutes for 15.0 minutes of game time, so nothing
    was credited for the freeze (C5 holds).
  - S4, display change and F12: taskbar auto-hide toggled on and off while
    the app ran. It re-measured both times (work area 800, then 752 tall) and
    kept all 6 critters. The VM's display adapter offers one resolution only,
    so a resolution change itself could not be tried there.
  - The soak harness is updated for admin-only odds (`--admin`); the old
    "beta" and "uncommon" keys are gone.
  - **Deferred until before the public release (developer's decision):**
    the Intel checks on real hardware (fps and CPU at 8, asleep, paused and
    25 critters; the 30-launch exit test; the arrival hitch, S6). Beta uses
    VM numbers only.
  - Not tested: lock and unlock, and RDP (the VM has no second session
    set up for them).
- **Phase 5, 2026-10-20** (the VM is on hold, so code and headless tests only):
  - S2 built: windows are made once and reused (`win_pool.gd`). Found in
    Godot 4.7.2's source: hiding a `Window` destroys the native window and
    showing it makes a new one, which leaks another GDI object. So pausing,
    hiding for a full-screen app and napping in the cottage leaked one per
    critter each time, as well as each arrival and toast. Now a window not in
    use is parked off the screen (drawing off) instead of hidden, and handed to
    the next critter or toast. At most 8 spare critter windows and 3 toast
    windows are kept. Showpieces are parked but not reused (they are rarely
    made). Admin: "Windows used again" (churn and the counts). Diagnostics
    show windows made and used again. `win_pool_test.gd` covers the
    bookkeeping.
  - Found with S2: the vsync calls for critter, toast and showpiece windows
    ran before those windows existed (they are made hidden), so they reached
    whichever window was current, and every re-shown window took the main
    window's vsync. Each window's vsync is now set right after it is first
    shown, and it sticks because windows are no longer re-made. On ANGLE (the
    VM) the vsync switch is global, not per window, which may be part of
    the VM's high CPU numbers.
  - The window-count threshold allows for the spares: at most critters +
    props + 3 toasts + 8 spare + 3.
  - F13 (touch and pen as presence): no touch device to test, so it goes on
    the known-issues list.
  - S1 built: a script for every threshold row (`tools/soak/README.md`,
    "Phase 5 thresholds"). `perf.ps1` runs the dev-PC rows on the release
    exe, `judge.ps1` judges an 8 h soak and the exit test, and
    `sleep_check.ps1` covers sleep/resume. `--report` now carries the gaps
    between frames and how the run ended (paused, hidden, away, napping), so
    each script can tell when its scenario didn't take. Checked for syntax.
    `judge.ps1` was also run on made-up soak output. None of them has run
    against the game yet.
- **Phase 5, 2026-10-21** (VM back; Intel run on the dev PC at the
  developer's word):
  - S2 measured on the VM: 8 min of churn (472 pops, 465 spawns) made 25
    windows in all, and GDI went 57 → 63. Before: 62 → 1,061. Pausing
    parks everyone (VM screenshots before and after).
  - Parked windows now stop drawing too, except the one pacing the frame.
    The VM's paused run had used half a core in software rendering.
  - Intel, dev PC (`perf.ps1`, release exe, sound off):

    | Row | Measured | Threshold | |
    |---|---|---|---|
    | fps, 8 | median 60, p95 frame 16.7 ms | ≥ 55, ≤ 20 ms | PASS |
    | CPU, 8 awake (60 fps) | 41% | ≤ 25% | FAIL |
    | CPU, 8 awake, Animation detail Simple (30 fps) | 21.7% | ≤ 25% | PASS |
    | CPU, paused | 3.0%, then 2.7% with parked windows not drawing | ≤ 3% | PASS |
    | CPU, behind a full-screen app | 1.8% | ≤ 3% | PASS |
    | CPU, all napping (20 fps) | 10.6%, 9.4% | ≤ 3% | FAIL |
    | 25 critters | median 32 fps, no errors | ≥ 30 | PASS |

    CPU follows the frame rate about linearly: each critter window is drawn
    and presented every frame. Decided (developer, 2026-10-21): critters run
    at 30 fps for everyone (Simple now only drops layers), 10 fps when all
    are asleep, and that row's threshold is 5%. The fps and 25-critter rows
    follow the cap (median ≥ 28 fps with p95 frame ≤ 40 ms, and ≥ 25 fps).
    To be re-measured on the RC build.
  - S8: with all 34 looks loaded (`--soak-mode=looks`), texture memory tops
    out at 174 MB, and static memory stays flat at 45 MB. The cache is
    bounded by the number of looks, so no eviction is needed.
  - S6 on the VM (debug build, software rendering): a wave of new looks
    gives 125-150 ms frames. That says little about real hardware; a check
    on the Intel PC is still open.
  - F12: with the taskbar auto-hidden, feet sit at the bottom edge and are
    visible.
  - S4: lock/unlock and RDP need someone to sign in to the VM: left to the
    developer.
  - Harness fixes: the churn and throw modes top up berries (Spawn now
    costs them), and `judge.ps1` ignores the VM's no-sound errors.
- **Phase 6, 2026-10-21:**
  - Installer (developer's choice: close a running v2.0, nothing else):
    `CloseRunning` asks v2.0 to close, then ends it after 3 s. The K3 rows
    found two more problems, now fixed:
    - uninstalling while v3 ran left the exe locked and the app running, so
      the uninstaller now closes v3 (and v2.0) first;
    - the delete-data question ignored `/SUPPRESSMSGBOXES`, so a silent
      uninstall stopped to ask. It is now suppressible, defaulting to No.
  - Found by K3: after importing the v2.0 Seen Log, v3 marked it done
    (settings, saved within a second) but saved the Collection only at the
    next 60 s autosave. A hard exit in that minute lost the v2.0 history for
    good. The economy is now saved straight after the import.
  - K4 stays as it is (developer's choice): "delete data" also removes
    v2.0's folder. It is on the known-issues list.
  - K5: godot-cpp pinned at 10.0.0-stable. The release DLL depends only on
    USER32, ADVAPI32, SHELL32 and KERNEL32.
  - K6: CI exports the player pack and fails on any Admin script; it also
    compiles the installer.
  - K7, K8, K11 in `release.ps1`. K8's other half: `build-v3.ps1` wrote the
    `.import` files with CRLF and left 1,300 changed. It now writes them
    as committed, and a build leaves the tree clean.
  - K9: the publisher stays `hstagg`. L2: no licence change (developer's
    choice).
  - L1: `THIRD-PARTY-NOTICES.txt` is installed beside the exe, and Credits
    lists godot-cpp.
  - L3: only `updater.gd` uses the network (code check).
    `tools/soak/vm/net_check.ps1` records the installed app's connections.
  - K3: `tools/soak/vm/install_matrix.ps1`, all 8 rows PASS on the VM
    (2026-10-21, after the fixes above):
    - v2.0 per-user and running → v3: the installer closed v2.0; one install,
      v3.0.0, in the same folder; v2.0's `_internal` gone.
    - The v2.0 import: settings (size, Rare Hour) carried over, and the
      Seen Log is in the Collection.
    - Reinstall over a running v3; uninstall while running (app closed, exe
      gone, data kept, start-up entry removed); reinstall picks the kept
      data up.
    - Uninstall answering Yes deletes both data folders; a fresh install.
    - v2.0 for all users and running → v3: one install, still in Program
      Files.
    - Also found: v2.0's uninstall log came along on an upgrade, with a
      step that started the app at uninstall and waited for it, so the
      uninstall hung. `UninstallLogMode=overwrite` fixes it.
    - v3 → v3 through the updater is Phase 8's two-release check.
  - K2 (VirusTotal) waits for the release candidate's installer.
- **Phase 7, 2026-10-21** (no tester guide, by the developer's choice):
  - R2 README rewritten for v3 (the in-app Help link opens it). R4
    `docs/TROUBLESHOOTING.md`. R6 and T7 `release-notes-v3.0.md`, with the
    known issues.
  - T3: the version is in About, the sidebar, the tray tooltip and the
    installer's name. T9: diagnostics show arrivals and arrivals per hour.
  - The Phase 7 exit check (someone new installs and reports using only the
    kit) will be the first tester.

- **Phase 8, release candidate, 2026-10-22** (developer's go given ahead of
  time: release if every automated check is green):
  - RC = `phase6` (PR #21), game code as of `047a5b0`. Built on the VM,
    which now has Inno Setup and rcedit (`C:	ools`). Its Godot must be the
    console build: PowerShell doesn't wait for the windowed exe, so
    `build-v3.ps1` checked for the export before it existed.
  - `run-tests.ps1 -Native` on the VM: 8 of 8 pass. The player exe has no
    Admin scripts.
  - K3 on the RC installer: all 8 rows pass. Two runs failed first, from a
    stray headless Godot of mine holding the log folder open; the row was
    re-run clean.
  - L3 on the RC: the only connection in the first 75 s was
    `api.github.com` (20.26.156.210:443).
  - The 8 h soak (S5) runs on the VM from 02:07, at 30 fps with 10
    critters.
  - Still to come: the Intel rows and the exit test on the dev PC (from
    4 a.m.), the soak result, the Admin audit (VM, by screenshot), then
    release, VirusTotal (a URL scan of the release asset; the built-in
    browser can't upload a file) and the 3.0.0 → 3.0.1 update on the VM.

## Phase 1: decisions and housekeeping

**Goal:** stop the ground moving. One branch, a frozen scope, and answers to every
question below, so later phases do not stall waiting on them.

**Entry:** this document.

**Items:**
- Decisions D1-D21 (answers go into the decisions table), and G1 (game design review: decided, see Game design rules).
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
- G2 (build the design review's outcome).
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
| Frame rate, default 8 critters | Dev PC, Iris Xe, 2 min | median ≥ 28 fps, p95 frame ≤ 40 ms (30 fps cap, decided 2026-10-21) |
| CPU, default 8 critters, active | Dev PC, 10 min | ≤ 25% of one core |
| CPU while paused or hidden by a full-screen app | Dev PC, 10 min each | ≤ 3% of one core |
| CPU, all napping (10 fps) | Dev PC, 10 min | ≤ 5% of one core (decided 2026-10-21) |
| 25 critters (the cap) | Dev PC, 2 min | ≥ 25 fps, no errors |
| GDI objects after 8 h default play | VM | ≤ 2,000 and not climbing linearly with arrivals |
| USER objects, threads, child processes | VM, 8 h | flat after hour 1 |
| Working set | VM, 8 h | hour 8 ≤ hour 1 + 15% |
| Window count | VM, sampled | ≤ critters + props + 3 toasts + 8 spare + 3 |
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

## Game design rules (G1, decided 2026-10-13)

v3 is a collection game that rewards focus time. These rules decide what a
player can change. G2 builds them, and the B items tune the numbers. "Medium
play" means about 4 focus hours a day, 5 days a week.

1. **Rolls come from focus time, not from arrivals.**
   - Focus time banks rarity rolls, at about one per 5-6 minutes. The exact
     rate and any cap on banked rolls come from the sim (B5).
   - An arriving critter takes a banked roll if there is one; otherwise it
     arrives Common.
   - The day's first-visitor bonus applies to the day's first banked roll.
   - The desk settings stay, as pure comfort: gather every, at most, start
     with, timer mode, group sizes and solo walkers.
2. **Spawn now** (the tray button and the spawn key) costs a flat berry price,
   and always rolls rarity, outside the bank. The price comes from the sim.
3. **Visit weights shape Commons only.** A Rare or better roll picks evenly
   among the species that are switched on. Switching species off stays (it
   means fewer rows to fill).
4. **Rare Hour:** the player picks the start time (default in the afternoon,
   D10). The length is fixed at 60 minutes and the boost at 2×.
5. **Switches:** Luck and First-visitor bonus are removed. "Rarity off" stays,
   as a calm mode for people who just want pets.
6. **Developer knobs:** the odds and per-species tier ranges live in the Admin
   build only. `--beta` and the beta-only Settings controls go.
7. **Paused:** berries and banked rolls keep coming while the critters are
   paused (the player is still working).
8. **"Clear the Seen Log"** is replaced by **Start over** (T4): a full reset of
   progress, berries and settings, with a backup kept. Nothing re-pays first
   finds.
9. **Pacing targets for medium play** (the sim must meet them):
   - All 24 everyday slots in about **4 weeks**.
   - Every Legendary colour (7 unicorn, 3 golden kitten) in about **a year**.
   - The shop has a **wide spread**: the cheapest things cost an hour or two
     of focus, and the top-end items take weeks of saving.

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
| F5 | 3 | Monitors: only the primary is used. A hard throw toward monitor 2 vanishes, and a drag can drop a critter on monitor 2. Make primary-only consistent (clamp the drag and throw) or span monitors. | Should-fix (3.0 is primary-only; roaming every monitor is 3.1, D8) | S (primary-only) / L (span) | D8 | Two-monitor test: a drag and a throw toward monitor 2 keep the critter on the primary. |
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
| G1 | 1 | Game design review. v3 is a collection game that rewards focus, but many settings let a player skip it (spawn key, timer mode, gather and start-with counts, visit weights, switching species off, the Rare Hour boost, luck and first-bonus toggles, beta odds). Sort every player-facing control into comfort (keep), game-affecting (limit or charge berries), or developer-only (Admin). Spawn now stays, but costs berries. Pacing targets (D9), beta mode (D18) and berries while paused (D20) are settled here. | Done 2026-10-13 (see Game design rules). | M | | A table of every control and its class, signed off. |
| G2 | 3 | Build the G1 outcome: remove or move the controls, add the spawn-now price, and migrate saved settings so removed keys fall back to defaults. | Blocker | M | G1 | Settings tests cover each removed or limited key. The Admin page still reaches the developer-only ones. |
| B1 | 4 | Legendary pacing. Completing all 10 visitor colours takes about 140 weeks at medium play and is effectively never for light play (twilight_neon is 3% of visitor rolls, split between two visitors). | Should-fix | M | D9, B5 | The sim meets the D9 target. |
| B2 | 4 | Luck stacking. Luck ×3, Rare Hour ×2 and the lucky charm ×1.5 make rare+ about 45% per roll, and the charm can be worn by every species. | Should-fix | S | D9 | The sim reports the rare+ share at max stack within the target. |
| B3 | 4 | Roll farming: | Mostly resolved by G1 rules 1, 2 and 8; re-check with the sim | S-M | G1 | One economy test per closed loophole. |
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
| K1 | 6 | Beta release path. `release.ps1` always makes a "latest" release from `main`, and both v2.0's and v3's update checkers read `/releases/latest`. A beta released that way goes to every v2.0 user. Add a prerelease mode and the D4 numbering. | Nice: D4 says normal releases are fine while there are no outside users | S | D4, H1 | A prerelease exists; a v2.0 install and a v3 install both report "up to date". |
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
| K10 | 6 | Beta mode (`--beta`) is only reachable from a launch flag, and it sticks once set. | Resolved by G1 rule 6 (`--beta` goes) | S | D18 | Follows D18. |
| K11 | 6 | The updater depends on GitHub's asset `digest` and the exact asset name. If either changes, every user falls back to a manual download. | Nice | S | | Release checklist step: the API shows a digest for the asset. |

### Beta kit

| ID | Ph | Item | Why / severity | Size | Deps | Verify |
|---|---|---|---|---|---|---|
| T1 | 3 | Diagnostics in System: "Open log folder" and "Copy diagnostics" (version and build, renderer, screens and scale, native status, settings, economy summary, last log lines). Nothing leaves the machine unless the tester sends it. Add an Admin check per CLAUDE.md. | Blocker | S-M | C1 | The button produces a file. The Admin row is Pass. |
| T2 | 7 | Feedback route and bug template: what happened, what was expected, steps, build, diagnostics file, screenshot. | Nice: messages for now (D6) | S | D6 | The template exists and a test report has been filed through it. |
| T3 | 7 | Tell builds apart: the beta label in About, the tray tooltip and the installer name. | Blocker | S | P1, D4 | Visible in all three places. |
| T4 | 3 | "Start over" in System: wipes progress and settings and shows the welcome again. Today only "Clear the Seen Log" exists, and "Reset all settings" keeps `onboarded`. Add an Admin control. | Should-fix | S | C2 | After Start over, the welcome shows on next launch and the economy is fresh. A backup of the old save is kept. |
| T5 | 7 | Whether testers get beta mode (editable odds). | Resolved by G1 rule 6 (no beta mode) | S | D18 | Documented in the guide. |
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
| D1 | Branch of record and release flow | (a) Merge v3 into main now; main becomes the dev branch again (as CLAUDE.md says); CI moves to main; v3 retires. (b) Keep v3 as the dev branch; merge to main only to release; CI on both. (c) Let `release.ps1` release from v3. | **(a)**: one branch, matching `release.ps1` and CLAUDE.md. || **(a)**, 2026-10-13. CI moved to main; v3 merges into main and retires. |
| D2 | The 11 missing Rare/Epic looks | (a) Pick from the 24 candidates already drawn (Admin > Every version drawn), polish later. (b) Ship the beta with Common look plus glow, and say so. (c) New designs first. | **(a)**: the candidates exist; picking is the bottleneck. || **(a)**, 2026-10-17. Kitten calico / snow, rabbit dutch / lop, duckling brown / cygnet, hedgehog blonde / albino, otter sea / snow, squirrel Epic snowy (Rare / Epic). Wired in `species.gd`; F1 done. |
| D3 | v2.0 users' custom critters on upgrade (v3 skips `custom:` entries; v2's files in `%APPDATA%\CritterOverlay\custom` are untouched unless an uninstall deletes data) | (a) Do nothing: they silently disappear from the overlay. (b) Preserve and tell: a one-time notice ("your N custom critters are safe and will come back in a later update"); keep the `custom:` sightings in the save for the later import; make "delete data" on uninstall spare or name that folder. (c) Sticker carry-over (plan Tier 1: still image with procedural motion) in v3.0. (d) Keep v2 runnable alongside: not possible, since both share the AppId. | **(b)**: small, loses nothing, and keeps v3.0's scope; (c) is real engine work that belongs to the custom-critters update. || **(b)** |
| D4 | Beta channel and numbering | (a) GitHub prereleases numbered below 3.0.0 (e.g. `2.90.N`, shown as "3.0 beta N"); testers reinstall each build; 3.0.0 final then auto-updates them; no updater change. (b) Teach the updater a beta channel (reads `/releases`, accepts prereleases when beta is on): automatic beta updates, but it touches the updater (a discuss-first area). (c) Private download link, outside GitHub. | **(a)** for a small group; revisit (b) if there are many builds. || **Neither needed yet:** no outside users (the developer and one tester), so builds go out as normal releases through the updater. Selling and advertising wait until it is polished. K1 drops to nice. |
| D5 | Code signing for the beta | (a) Unsigned, with SmartScreen steps and a VirusTotal link per build. (b) Buy a signing service now. | **(a)** for known testers; signing before any public build. || **(a)** |
| D6 | How testers report | (a) GitHub issue form. (b) Private form or email with the diagnostics file attached. (c) A chat group. | **(b)**, with (a) for testers who use GitHub: not everyone has an account, and screenshots of a desktop can be personal. || For now the tester messages the developer directly. An in-app comments window is parked (see the 3.1 pipeline). |
| D7 | Telemetry | (a) None; opt-in stats inside the diagnostics file (T9). (b) An opt-in network ping. | **(a)**: keeps "the app sends nothing" true. || **(a)** |
| D8 | Monitors | (a) Primary only for v3.0, made consistent (no losing critters to monitor 2), and documented. (b) Roam all monitors. | **(a)** for beta. || **(a)** for 3.0. Roaming every monitor is planned for 3.1. |
| D9 | Collection pacing target | (a) Set targets (e.g. a medium player fills the 24 everyday slots in about 4 weeks and meets every visitor colour in about 6 months) and tune the weights with the new sim. (b) Add a pity counter. (c) Leave it and watch. | **(a)**; keep (b) in reserve until beta data says it is needed. || **Decided (G1):** everyday set in about 4 weeks; every Legendary colour in about a year; a wider shop spread (see the design rules). |
| D10 | Rare Hour default | (a) Keep 21:00. (b) An afternoon default. (c) An hour that moves each day. | Keep the setting, change the default to **(b)**, and ask testers. || **(b)** |
| D11 | Spoilers before a visitor is met | (a) Silhouettes and colour pips shown (today). (b) Silhouettes only, no colour count. (c) Nothing until first met. | **(b)**: curiosity without giving the count away. || **(b)** |
| D12 | Start with Windows in the welcome | (a) On by default (today; also flips upgraders on). (b) Off by default. (c) On for fresh installs; upgraders keep their current state. | **(c)** || **(c)** |
| D13 | UI fonts | (a) Bundle Fredoka and Nunito (OFL) with their licence. (b) Design for Segoe UI. | **(a)** || **(a)** |
| D14 | AI-assistance wording in credits | (a) A short accurate line now (e.g. "art made with AI assistance, directed and edited by the author"). (b) Wait for the store page. | **(a)**: the current credit is inaccurate. || **(b)**: wait for the store page. |
| D15 | The developer's name in the repo | (a) Neutralise code comments ("design pick") and keep the legal name only in the licence and publisher. (b) Leave as is. | **(a)** || **(a)** |
| D16 | v1/v2 leftovers | (a) Tag `v2-final`, then remove v2 code, `Archive/`, the handoffs and the market document from the v3 tree. (b) Move them to a `legacy/` folder. (c) Leave them. | **(a)**, before any public build; the tag keeps v2 rebuildable. || **(a)** |
| D17 | Performance thresholds | The Phase 5 table as proposed, or changed. | Accept, then adjust after the first measurements. || **(Accept)** |
| D18 | Beta mode for testers | (a) Off: testers play the real odds. (b) On for everyone. (c) A few testers on purpose. | **(a)**; keep `--beta` for the developer. || **Decided (G1):** odds and tier ranges are Admin-only; `--beta` goes. |
| D19 | Which roll-farming loops to close before beta (B3) | Clear Seen Log re-paying, relaunch rolls, timer-mode roll count, spawn-key rolls. | Close **Clear Seen Log re-paying** now; watch the rest in beta. || **Decided (G1):** rolls come from focus time; spawn now costs berries. |
| D20 | Berries while paused (by design today) | (a) Keep. (b) No berries while paused. | Keep, and ask testers (T8). || **Keep earning.** Berries and banked rolls continue while paused. |
| D21 | History | Rewrite history to drop the once-committed personal README (`73e8af2`)? | Check what it contains first; rewrite only if it holds personal data. || **Done 2026-10-13.** `_README.md` stripped from every commit; branches and tags force-pushed; GitHub Support asked to purge cached views. |

---

## 3.1 pipeline

Decided as later work, kept here so nothing is lost:

- **Roam every monitor** (D8): critters walk across all screens, with mixed-DPI handling.
- **In-app comments window** for tester feedback, with screenshots (D6).
- **Custom critters**: see `docs/v3-custom-critters-plan.md`.

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
