"""
main.py — Entry point for Critter Overlay App

System tray icon (bottom-right of taskbar):
  Green paw  = running
  Red paw    = paused

Right-click tray for: Settings | Spawn Now | Pause/Resume | Quit
One keyboard shortcut: Ctrl+Shift+P  — toggle pause from any app

The main settings window is a proper app window (shows in taskbar).
Close it with X to minimise; reopen from the tray icon or taskbar.
"""

import sys
import os
import ctypes
import winreg
import threading
from pathlib import Path

# ---------------------------------------------------------------------------
# Single instance check
# ---------------------------------------------------------------------------

_MUTEX_NAME   = "CritterOverlayMutex_v1"
_mutex_handle = None

def _ensure_single_instance() -> bool:
    global _mutex_handle
    _mutex_handle = ctypes.windll.kernel32.CreateMutexW(None, False, _MUTEX_NAME)
    if ctypes.windll.kernel32.GetLastError() == 183:
        ctypes.windll.user32.MessageBoxW(
            0,
            "Critter Overlay is already running.\n"
            "Find the paw icon in your system tray (bottom-right of taskbar).",
            "Critter Overlay",
            0x40,
        )
        return False
    return True

# ---------------------------------------------------------------------------
# Auto-startup registry
# ---------------------------------------------------------------------------

_REG_KEY  = r"Software\Microsoft\Windows\CurrentVersion\Run"
_REG_NAME = "CritterOverlay"

def _set_autostart(enabled: bool) -> None:
    try:
        if getattr(sys, "frozen", False):
            exe_path = f'"{sys.executable}"'
        else:
            script   = Path(__file__).resolve()
            exe_path = f'"{sys.executable}" "{script}"'
        key = winreg.OpenKey(winreg.HKEY_CURRENT_USER, _REG_KEY, 0, winreg.KEY_SET_VALUE)
        if enabled:
            winreg.SetValueEx(key, _REG_NAME, 0, winreg.REG_SZ, exe_path)
        else:
            try:
                winreg.DeleteValue(key, _REG_NAME)
            except FileNotFoundError:
                pass
        winreg.CloseKey(key)
    except Exception as e:
        print(f"[startup] Registry error: {e}")

# ---------------------------------------------------------------------------
# Tray icon image (paw print)
# ---------------------------------------------------------------------------

def _make_tray_image(paused: bool = False):
    from PIL import Image, ImageDraw
    size = 64
    img  = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d    = ImageDraw.Draw(img)

    if paused:
        pad = (210, 80,  80,  255)
        toe = (235, 120, 120, 255)
    else:
        pad = (80,  200, 100, 255)
        toe = (120, 230, 140, 255)

    d.ellipse([14, 32, 50, 60], fill=pad)  # main pad
    d.ellipse([ 6, 18, 24, 34], fill=toe)  # left toe
    d.ellipse([22, 10, 42, 28], fill=toe)  # centre toe
    d.ellipse([40, 18, 58, 34], fill=toe)  # right toe
    return img

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> None:
    if not _ensure_single_instance():
        sys.exit(0)

    import keyboard
    import pystray
    from config                      import load_config, save_config
    from sounds                      import SoundManager
    from overlay                     import Overlay
    from settings_window             import SettingsWindow
    from custom_critters.registry    import CustomCritterRegistry

    config = load_config()
    _set_autostart(config["system"].get("auto_launch", True))

    quit_event = threading.Event()

    sound_mgr = SoundManager()
    sound_mgr.init(config)

    # Registry is created before the overlay so the same object is shared
    # everywhere; reload() is called after pygame.init() (inside Overlay.__init__)
    registry = CustomCritterRegistry()

    # Placeholders — assigned before use
    overlay:      Overlay        = None  # type: ignore
    settings_win: SettingsWindow = None  # type: ignore
    tray_icon:    pystray.Icon   = None  # type: ignore

    # ------------------------------------------------------------------
    # Tray refresh helper
    # ------------------------------------------------------------------

    def update_tray() -> None:
        if tray_icon is None:
            return
        try:
            tray_icon.icon  = _make_tray_image(overlay.paused)
            tray_icon.title = (
                "Critter Overlay — Paused  (right-click for options)"
                if overlay.paused else
                "Critter Overlay — Running  (right-click for options)"
            )
        except Exception:
            pass

    # ------------------------------------------------------------------
    # Callbacks
    # ------------------------------------------------------------------

    def _refresh_custom_sounds() -> None:
        """Re-register sounds for all currently loaded custom critters."""
        for record in registry.all():
            sound_mgr.register_custom(
                record.id,
                record.meta.get("sound_profile", "kitten"),
                record.meta.get("sound_seed", 0),
            )

    def on_config_saved(new_config: dict) -> None:
        nonlocal config
        config = new_config
        if overlay:
            overlay.apply_new_config(new_config)
        _set_autostart(new_config["system"].get("auto_launch", True))
        _refresh_custom_sounds()

    def on_quit() -> None:
        quit_event.set()

    # ------------------------------------------------------------------
    # Build overlay
    # ------------------------------------------------------------------

    overlay = Overlay(
        config           = config,
        sound_manager    = sound_mgr,
        open_settings_fn = lambda: settings_win.open() if settings_win else None,
        quit_event       = quit_event,
        on_pause_changed = update_tray,
        registry         = registry,
    )

    # pygame is now initialised inside Overlay — safe to load sprites/masks
    registry.reload()
    _refresh_custom_sounds()

    # Render animated previews for the settings window using live pygame surfaces
    from preview_renderer import render_all as _render_previews
    from settings_window import ANIMALS as _ANIMALS_LIST
    _preview_frames = _render_previews([sp for sp, _, _ in _ANIMALS_LIST])

    # ------------------------------------------------------------------
    # Build settings window (proper app window, shows in taskbar)
    # ------------------------------------------------------------------

    settings_win = SettingsWindow(
        config               = config,
        on_save              = on_config_saved,
        on_force_spawn       = overlay.force_spawn,
        on_quit              = on_quit,
        get_paused           = lambda: overlay.paused,
        registry             = registry,
        on_test_custom_spawn = overlay.spawn_custom,
        preview_frames       = _preview_frames,
    )

    # Wire in pause toggle so the settings window can trigger it
    settings_win.set_toggle_pause(lambda: (overlay.toggle_pause(), update_tray()))

    # Open the control window at launch — user can minimise it
    settings_win.open()

    # ------------------------------------------------------------------
    # System tray icon
    # ------------------------------------------------------------------

    def tray_open_settings(icon, item):
        settings_win.open()

    def tray_spawn_now(icon, item):
        overlay.force_spawn()

    def tray_toggle_pause(icon, item):
        overlay.toggle_pause()
        update_tray()

    def tray_quit(icon, item):
        quit_event.set()
        icon.stop()

    tray_icon = pystray.Icon(
        name  = "CritterOverlay",
        icon  = _make_tray_image(False),
        title = "Critter Overlay — Running  (right-click for options)",
        menu  = pystray.Menu(
            pystray.MenuItem("⚙  Settings",      tray_open_settings),
            pystray.MenuItem("🐾  Spawn now",     tray_spawn_now),
            pystray.MenuItem(
                "⏸  Pause / Resume",
                tray_toggle_pause,
                checked=lambda item: overlay.paused,
            ),
            pystray.Menu.SEPARATOR,
            pystray.MenuItem("✕  Quit",           tray_quit),
        ),
    )
    tray_icon.run_detached()

    # ------------------------------------------------------------------
    # Single keyboard shortcut: Ctrl+Shift+P — pause toggle
    # ------------------------------------------------------------------

    try:
        keyboard.add_hotkey(
            "ctrl+shift+p",
            lambda: (overlay.toggle_pause(), update_tray()),
            suppress=False,
        )
    except Exception as e:
        print(f"[hotkeys] Could not register hotkey: {e}")

    # ------------------------------------------------------------------
    # Run overlay (blocks until quit)
    # ------------------------------------------------------------------

    try:
        overlay.run()
    except KeyboardInterrupt:
        pass
    finally:
        quit_event.set()
        try:
            tray_icon.stop()
        except Exception:
            pass
        settings_win.close()
        try:
            keyboard.unhook_all_hotkeys()
        except Exception:
            pass


if __name__ == "__main__":
    main()
