"""
__main__.py - Bootstrapper for the Critter Overlay zipapp.

How it works:
  1. User double-clicks Critter Overlay.pyzw  ->  Windows runs it with pythonw.
  2. We check for an isolated venv at %APPDATA%\\CritterOverlay\\venv with the
     required packages installed.
  3. If anything is missing we open a small dark Tk window, build the venv and
     install the deps quietly. Window self-closes when ready.
  4. We re-launch the same .pyzw using the venv's pythonw (detached) and exit.
  5. On the second pass we are inside the venv, so we just import src/main.py
     and run the app.

Result: the user only ever sees one file. First launch shows a 20-40s progress
window once, every subsequent launch is silent.
"""

from __future__ import annotations

import ctypes
import os
import queue
import subprocess
import sys
import threading
from pathlib import Path

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

APP_NAME      = "CritterOverlay"
APPDATA       = Path(os.environ.get("APPDATA") or Path.home() / "AppData" / "Roaming")
APP_DIR       = APPDATA / APP_NAME
VENV_DIR      = APP_DIR / "venv"
VENV_PY       = VENV_DIR / "Scripts" / "python.exe"
VENV_PYW      = VENV_DIR / "Scripts" / "pythonw.exe"
MARKER_FILE   = VENV_DIR / ".critter_setup_complete"

REQUIREMENTS = [
    "pygame>=2.3.0",
    "numpy>=1.24.0",
    "keyboard>=0.13.5",
    "pystray>=0.19.0",
    "Pillow>=10.0.0",
]

# Cheap import probe: if any of these fail, we need to (re)install.
PROBE = "import pygame, numpy, keyboard, pystray, PIL"

# Win32 process-creation flags so the relaunched copy is fully detached.
DETACHED_PROCESS         = 0x00000008
CREATE_NEW_PROCESS_GROUP = 0x00000200
CREATE_NO_WINDOW         = 0x08000000


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _archive_path() -> Path:
    """Path to this .pyzw (or to __main__.py during dev runs)."""
    arg0 = Path(sys.argv[0]).resolve() if sys.argv and sys.argv[0] else Path()
    if arg0.suffix.lower() in (".pyz", ".pyzw"):
        return arg0
    # Fallback: __file__ inside zipapp resolves to <archive>/__main__.py
    return Path(__file__).resolve().parent


def _in_venv() -> bool:
    try:
        return Path(sys.prefix).resolve() == VENV_DIR.resolve()
    except Exception:
        return False


def _venv_ready() -> bool:
    if not VENV_PYW.exists() or not MARKER_FILE.exists():
        return False
    try:
        proc = subprocess.run(
            [str(VENV_PY), "-c", PROBE],
            capture_output=True, timeout=15,
            creationflags=CREATE_NO_WINDOW,
        )
        return proc.returncode == 0
    except Exception:
        return False


def _msgbox(text: str, title: str = "Critter Overlay", flags: int = 0x10) -> None:
    try:
        ctypes.windll.user32.MessageBoxW(0, text, title, flags)
    except Exception:
        pass


# ---------------------------------------------------------------------------
# First-run install with Tk progress window
# ---------------------------------------------------------------------------

def _install_with_progress() -> None:
    """Build the venv and install requirements, with a small Tk progress UI."""
    import tkinter as tk
    from tkinter import ttk

    msg_q: "queue.Queue[tuple[str, int | None]]" = queue.Queue()
    done = threading.Event()
    error: dict[str, BaseException] = {}

    # ---- background worker ------------------------------------------------
    def worker() -> None:
        try:
            APP_DIR.mkdir(parents=True, exist_ok=True)

            msg_q.put(("Preparing environment...", 10))
            if not VENV_PY.exists():
                import venv
                venv.EnvBuilder(with_pip=True, clear=False).create(str(VENV_DIR))

            msg_q.put(("Updating installer...", 30))
            subprocess.run(
                [str(VENV_PY), "-m", "pip", "install", "--upgrade",
                 "pip", "--disable-pip-version-check", "-q"],
                check=True, creationflags=CREATE_NO_WINDOW,
            )

            msg_q.put(("Installing packages (this part takes the longest)...", 60))
            subprocess.run(
                [str(VENV_PY), "-m", "pip", "install",
                 "--disable-pip-version-check", "-q", *REQUIREMENTS],
                check=True, creationflags=CREATE_NO_WINDOW,
            )

            msg_q.put(("Verifying...", 90))
            subprocess.run(
                [str(VENV_PY), "-c", PROBE],
                check=True, creationflags=CREATE_NO_WINDOW,
            )

            MARKER_FILE.write_text("ok", encoding="utf-8")
            msg_q.put(("Ready.", 100))
        except BaseException as e:  # noqa: BLE001
            error["e"] = e
        finally:
            done.set()

    threading.Thread(target=worker, daemon=True).start()

    # ---- UI ---------------------------------------------------------------
    root = tk.Tk()
    root.title("Critter Overlay")
    root.configure(bg="#1b1b1b")
    root.geometry("440x170")
    root.resizable(False, False)

    # Centre on screen
    root.update_idletasks()
    sw = root.winfo_screenwidth()
    sh = root.winfo_screenheight()
    x  = (sw - 440) // 2
    y  = (sh - 170) // 2
    root.geometry(f"440x170+{x}+{y}")

    # Minimal styling for the progress bar
    style = ttk.Style(root)
    try:
        style.theme_use("clam")
    except Exception:
        pass
    style.configure(
        "Critter.Horizontal.TProgressbar",
        troughcolor="#2a2a2a",
        background="#5cc97a",
        bordercolor="#2a2a2a",
        lightcolor="#5cc97a",
        darkcolor="#5cc97a",
    )

    tk.Label(
        root, text="Setting up Critter Overlay",
        bg="#1b1b1b", fg="#f0f0f0",
        font=("Segoe UI", 12, "bold"),
    ).pack(pady=(18, 4))

    tk.Label(
        root, text="One-time setup. Should take 20-40 seconds.",
        bg="#1b1b1b", fg="#999999",
        font=("Segoe UI", 9),
    ).pack(pady=(0, 14))

    status = tk.Label(
        root, text="Starting...",
        bg="#1b1b1b", fg="#cccccc",
        font=("Segoe UI", 9),
    )
    status.pack(pady=(0, 8))

    bar = ttk.Progressbar(
        root, length=380, mode="determinate", maximum=100,
        style="Critter.Horizontal.TProgressbar",
    )
    bar.pack()

    def poll() -> None:
        latest = None
        try:
            while True:
                latest = msg_q.get_nowait()
        except queue.Empty:
            pass
        if latest is not None:
            text, pct = latest
            status.config(text=text)
            if pct is not None:
                bar["value"] = pct
        if done.is_set():
            root.after(350, root.destroy)
        else:
            root.after(80, poll)

    root.after(80, poll)
    root.protocol("WM_DELETE_WINDOW", lambda: None)  # cannot close mid-install
    root.mainloop()

    if "e" in error:
        raise error["e"]


# ---------------------------------------------------------------------------
# Relaunch inside the venv
# ---------------------------------------------------------------------------

def _relaunch_in_venv() -> None:
    archive = _archive_path()
    try:
        subprocess.Popen(
            [str(VENV_PYW), str(archive)],
            creationflags=DETACHED_PROCESS | CREATE_NEW_PROCESS_GROUP,
            close_fds=True,
            cwd=str(archive.parent),
        )
    except Exception as e:
        _msgbox(
            "Critter Overlay installed its environment but could not start.\n\n"
            f"Details: {e}\n\n"
            f"You can launch manually with:\n  {VENV_PYW}  {archive}",
            "Critter Overlay",
        )


# ---------------------------------------------------------------------------
# Run the actual app (we are inside the venv)
# ---------------------------------------------------------------------------

def _run_app() -> None:
    archive_root = Path(__file__).resolve().parent
    src_path = str(archive_root / "src")
    if src_path not in sys.path:
        sys.path.insert(0, src_path)
    # src/main.py defines main()
    from main import main as app_main  # type: ignore
    app_main()


# ---------------------------------------------------------------------------
# Entry
# ---------------------------------------------------------------------------

def bootstrap() -> None:
    if _in_venv():
        _run_app()
        return

    if not _venv_ready():
        try:
            _install_with_progress()
        except subprocess.CalledProcessError as e:
            _msgbox(
                "Critter Overlay couldn't install its packages.\n\n"
                "This is almost always a network issue. Check your connection "
                "and try launching again.\n\n"
                f"Technical detail: pip exited with code {e.returncode}.",
                "Critter Overlay - setup failed",
            )
            sys.exit(1)
        except BaseException as e:  # noqa: BLE001
            _msgbox(
                "Critter Overlay couldn't finish setting up.\n\n"
                f"Details: {e}",
                "Critter Overlay - setup failed",
            )
            sys.exit(1)

    _relaunch_in_venv()


if __name__ == "__main__":
    bootstrap()
