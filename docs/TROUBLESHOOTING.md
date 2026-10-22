# Troubleshooting

## "Windows protected your PC" when installing

The installer isn't signed yet, so SmartScreen doesn't know it. Choose
**More info**, then **Run anyway**. Some antivirus tools are wary of new,
unsigned apps that watch for idle time and register a global shortcut; each
release's notes link a VirusTotal scan of its installer.

## No critters appear

- **Paused?** Look at the tray icon by the clock: if it says paused, press
  **Ctrl+Shift+P** (or your own pause shortcut) or click the icon and choose
  Resume critters.
- **A full-screen app?** Critters hide while a game, film or presentation has
  the screen, and come back when it closes. (Settings › Focus › Pause in
  full-screen apps.)
- **Just started?** A couple arrive at once, then one more every few minutes
  of focus time, up to your limit (Settings › Focus).
- **Is it running?** Look for the little kitten face in the tray (it may be
  behind the ^ arrow). If not, start Critter Overlay from the Start menu.

## The pause shortcut does nothing

Another app may already use the same keys. Settings › System › Shortcuts:
pick another combination. If the System page says the Windows helper isn't
loaded, the shortcut, start with Windows and full-screen pause are off:
reinstall to put the helper back.

## Critters are in the wrong place after changing displays

They redraw themselves inside the main screen a couple of seconds after a
resolution, scaling or taskbar change. v3.0 uses the main screen only:
critters thrown or dragged towards a second screen come back.

## Settings or progress didn't save

Critter Overlay saves as you go and when it quits. If a save file is ever
damaged, it is set aside as `economy.json.corrupt-<time>` (or
`settings.json.corrupt-<time>`) and the last good copy is used. They're all in
`%APPDATA%\Critter Overlay`.

## Starting again

Settings › System › **Start over** clears your Collection, berries and
settings, and shows the welcome again. Your old save is kept beside the new one
as `economy.json.before-start-over`.

## Reporting a bug

Settings › System › Help:

- **Copy diagnostics** puts your version, screens, settings and the recent log
  on the clipboard: paste it into your message.
- **Open folder** shows the log files, if you're asked for them.

Nothing is sent anywhere unless you send it. A screenshot helps too (check
it shows nothing private first).

## Uninstalling

Settings › Apps › Installed apps › Critter Overlay › Uninstall. Choose
**No** when it asks about deleting your data to keep it for a reinstall, or
**Yes** to remove everything. Yes also removes v2.0's folder, including any
custom critters made in v2.0.
