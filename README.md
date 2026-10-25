# Critter Overlay

Small companions for long days. Critters wander your Windows desktop while you
work: they arrive as you keep at it, nap when you step away and wake when you
come back. Meet them all in your Collection, earn berries for your focus time,
and dress them up.

Windows 10 or 11.

## Install

1. Download **CritterOverlaySetup-&lt;version&gt;.exe** from the
   [latest release](https://github.com/hstagg/critter-overlay/releases/latest).
2. Open it. The installer isn't signed yet, so Windows may show "Windows
   protected your PC": choose **More info**, then **Run anyway**.
3. Accept the licence and choose **Install**. Critter Overlay starts when
   it's done, and a short welcome shows you around.

**Coming from v2.0?** Install straight over it: no need to uninstall first.
If v2.0 is running, the installer closes it. Your settings and the critters
you'd seen in v2.0 come with you, and so do the custom critters you made in
v2.0: they arrive switched off, so turn them on in Settings › System › Custom
critters.

## Using it

- **Critters** walk in from the sides while you work, up to the number you
  choose. Click one to pop it; drag one to pick it up; fling it to throw it.
- **Pause** with **Ctrl+Shift+P** (change it in Settings › System), or from the
  tray icon. Critters hide while a full-screen game, film or presentation has
  the screen.
- **The tray icon** (bottom right, by the clock): click it for a panel with
  who's out, your berries, the next gift, Spawn, Pause, Settings and Quit.
  Double-click it for Settings.
- **Berries** come from focus time. Spend them in the Shop on clothes, dyes,
  treats and showpieces (beds for napping critters), or on **Spawn now**.
- **Homemade critters**: make your own from any picture in Settings › System ›
  Custom critters › Import a critter. It walks as one piece, like v2.0's.
- **Showpieces** (a basket bed, a tent, a cottage) stand on your desktop: drag
  one anywhere, or right-click it to put it away.
- **Stay on the desktop** (Settings › World, or the tray icon): critters and
  showpieces live on your desktop behind your windows, instead of on top.
  Show desktop (Win+D) brings them into view.
- **The Collection** records every critter you meet: Common, Rare and Epic,
  plus the Legendary visitors, which stay secret until you meet them.
- **Rare Hour**: once a day, for an hour you pick, rarer critters turn up more
  often.

Everything is in **Settings**: Home, Critters, Focus, World, Sound,
Collection, Shop and System.

## Privacy

Critter Overlay keeps everything on your computer. To tell when you're
working, it checks how long it's been since your last key press or mouse
movement; it never records which keys you press, what you type or where you
click. Once a day it asks GitHub whether there's a newer version, and when
there is, downloads it (Settings › System › Updates: download, only tell
you, or never check). Nothing about you or your critters is sent.

## Updates

New versions install themselves with one click: a note appears when one is
ready. You can also check from Settings › System.

## Uninstall

Settings › Apps › Installed apps › Critter Overlay › Uninstall. It asks
whether to delete your Collection, berries and settings too; the default
keeps them, so a reinstall picks up where you left off.

## Something wrong?

See [Troubleshooting](docs/TROUBLESHOOTING.md). For a bug report, Settings ›
System › Help › **Copy diagnostics** puts what's needed on your clipboard
(your version, screens, settings and the recent log). Nothing is sent
anywhere unless you paste it into a message.

## For developers

v3 is a [Godot 4.7](https://godotengine.org) project in `godot/`, with a
small C++ GDExtension for the Windows calls Godot can't make in `native/`.

```powershell
godot --path godot                    # run from source
godot --path godot -- --admin         # with the Admin page
.\run-tests.ps1                       # the headless tests (-Native adds the DLL's)
.\build-v3.ps1 -Version 3.0.0         # the player installer, in installer\output
```

Building needs Godot 4.7 with its export templates, Inno Setup 6 and rcedit;
the native DLL is described in [native/README.md](native/README.md). The
plan for v3.0 is [docs/v3-launch-plan.md](docs/v3-launch-plan.md), and the
soak and measuring tools are in [tools/soak](tools/soak/README.md). v1 and
v2 (the Python app) are kept at the tag `v2-final`.

## Licence

Free for personal, non-commercial use: see [installer/license.txt](installer/license.txt).
Third-party components: [THIRD-PARTY-NOTICES.txt](THIRD-PARTY-NOTICES.txt).
