"""
updater.py — GitHub release update checker.

Checks the GitHub releases API on startup (background thread).
Shows a native Win32 dialog if a newer version is available.
Remembers dismissed versions so the user isn't reprompted for the same
version on every launch.

The check_now() function is for the manual "Check for updates" button in
the settings window — it's synchronous and returns the result to the caller.
"""
from __future__ import annotations

import ctypes
import json
import os
import threading
import urllib.error
import urllib.request
import webbrowser
from pathlib import Path

from version import APP_VERSION

_REPO         = "hstagg/critter-overlay"
_API_URL      = f"https://api.github.com/repos/{_REPO}/releases/latest"
RELEASES_URL  = f"https://github.com/{_REPO}/releases"


# ---------------------------------------------------------------------------
# Dismissed-version persistence
# ---------------------------------------------------------------------------

def _dismissed_path() -> Path:
    appdata = os.environ.get("APPDATA", os.path.expanduser("~"))
    return Path(appdata) / "CritterOverlay" / "update_dismissed.txt"


def _get_dismissed() -> str | None:
    try:
        text = _dismissed_path().read_text(encoding="utf-8").strip()
        return text or None
    except Exception:
        return None


def _set_dismissed(tag: str) -> None:
    try:
        _dismissed_path().write_text(tag, encoding="utf-8")
    except Exception:
        pass


# ---------------------------------------------------------------------------
# Version comparison
# ---------------------------------------------------------------------------

def _parse_ver(v: str) -> tuple[int, ...]:
    """'v1.9.0' or '1.9.0' → (1, 9, 0).  Returns (0,) on parse failure."""
    v = v.lstrip("v").strip()
    try:
        return tuple(int(x) for x in v.split("."))
    except ValueError:
        return (0,)


def is_newer(latest: str, current: str) -> bool:
    """True if latest version is strictly greater than current."""
    return _parse_ver(latest) > _parse_ver(current)


# ---------------------------------------------------------------------------
# GitHub API fetch
# ---------------------------------------------------------------------------

def fetch_latest() -> tuple[str, str] | None:
    """
    Hit the GitHub releases API.
    Returns (tag_name, html_url) or None on any network/parse failure.
    Fails silently — never raises.
    """
    try:
        req = urllib.request.Request(
            _API_URL,
            headers={"User-Agent": f"CritterOverlay/{APP_VERSION}"},
        )
        with urllib.request.urlopen(req, timeout=6) as resp:
            data = json.loads(resp.read())
        tag = data["tag_name"]
        url = data["html_url"]
        return tag, url
    except Exception:
        return None


# ---------------------------------------------------------------------------
# Prompt
# ---------------------------------------------------------------------------

def _show_prompt(tag: str, url: str) -> None:
    """
    Win32 MessageBoxW — safe to call from any thread.
    Always records the tag as dismissed so the prompt doesn't repeat this
    launch cycle even if the user says No.
    """
    msg = (
        f"Version {tag} is available!\n\n"
        "Open GitHub to download the update?"
    )
    result = ctypes.windll.user32.MessageBoxW(
        0, msg, "Critter Overlay — Update available",
        0x24,   # MB_YESNO | MB_ICONQUESTION
    )
    _set_dismissed(tag)
    if result == 6:  # IDYES
        webbrowser.open(url)


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def check_in_background() -> None:
    """
    Start a daemon thread that checks for updates and prompts if one is found.
    Does nothing if:
      - the latest release is not newer than the running version, or
      - the latest release is the same as the last dismissed version.
    """
    def _run() -> None:
        result = fetch_latest()
        if result is None:
            return
        tag, url = result
        if not is_newer(tag, APP_VERSION):
            return
        dismissed = _get_dismissed()
        if dismissed and not is_newer(tag, dismissed):
            return
        _show_prompt(tag, url)

    threading.Thread(target=_run, daemon=True).start()


def check_now() -> tuple[str, str] | None:
    """
    Synchronous check for the settings window button.
    Returns (tag, release_url) if a newer version exists, else None.
    Returns None silently on network failure.
    """
    result = fetch_latest()
    if result is None:
        return None
    tag, url = result
    return (tag, url) if is_newer(tag, APP_VERSION) else None
