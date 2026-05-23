"""
settings_window.py — Critter Overlay control window

Proper app-style window (shows in taskbar, minimises on X to tray).
Sidebar navigation, dark theme inspired by Spotify / VS Code.
"""

import base64
import io
import threading
import tkinter as tk
import tkinter.filedialog as filedialog
import tkinter.messagebox as messagebox
import tkinter.ttk as ttk
import webbrowser
from pathlib import Path
from typing import Callable

try:
    import sv_ttk as _sv_ttk
    _SVTTK = True
except ImportError:
    _SVTTK = False

from PIL import Image, ImageTk

from config import save_config, reset_to_defaults
from version import APP_VERSION
from updater import RELEASES_URL, check_now
from custom_critters.registry import CustomCritterRegistry
from custom_critters.storage import delete_critter_folder, get_custom_dir, write_meta
from custom_critters.import_pipeline import (
    run_import, run_import_frames,
    prepare_frames, run_import_from_prepared,
)
from custom_critters.sharing import (
    export_critter, bulk_export,
    import_critter_package, read_package_meta,
)
from sounds import EXTRA_PRESETS

try:
    from animal_previews import FRAMES as _ANIMAL_FRAMES
except ImportError:
    _ANIMAL_FRAMES = {}

SOUND_PRESETS = ["kitten", "turtle", "duck", "rabbit",
                 "hedgehog", "squirrel", "otter", "panda",
                 "squeak", "chirp", "bloop", "pop", "grunt", "bell"]

# Card background as RGB tuple for PIL compositing
_CARD_RGB     = (30, 30, 53)   # matches CARD_BG "#1e1e35"
_PREVIEW_SIZE = 96             # preview canvas size (px)
_ANIM_FPS     = 10             # settings-window animation speed

# ── Palette ─────────────────────────────────────────────────────────────────

SIDEBAR_BG = "#0f0f1a"   # near-black navy
CONTENT_BG = "#16162a"   # dark navy
CARD_BG    = "#1e1e35"   # card surfaces
CARD_HOV   = "#26263e"   # card hover
ACCENT     = "#c084fc"   # soft violet
ACCENT2    = "#67e8f9"   # cyan highlight
GREEN      = "#4ade80"   # mint — running
RED        = "#f87171"   # coral — paused / danger
AMBER      = "#fbbf24"   # amber — warning
FG         = "#e2e8f0"   # primary text
FG2        = "#94a3b8"   # secondary
FG3        = "#4b5563"   # muted / tertiary
BORDER     = "#1e2040"   # subtle divider
SEL_BG     = "#23234a"   # selected nav item
SLIDER_TR  = "#2d2d55"   # slider trough

FF = "Segoe UI"          # font family

# ── Per-critter personality tables ───────────────────────────────────────────

_SPEED_VALUES = [0.10, 0.30, 1.0, 2.5, 5.0, 12.0]
_SPEED_LABELS = ["snail", "slow", "average", "fast", "rapid", "supersonic"]

_IDLE_VALUES  = [0.003, 0.008, 0.018, 0.045, 0.100, 0.250]
_IDLE_LABELS  = ["wired", "active", "normal", "lazy", "sleepy", "narcoleptic"]

_SIZE_VALUES  = [0.5, 0.75, 1.0, 1.5, 2.5]
_SIZE_LABELS  = ["tiny", "small", "normal", "large", "huge"]

_TRAIL_STYLES = [
    ("none",     "None"),
    ("dots",     "Dots"),
    ("stars",    "Stars"),
    ("sparkles", "Sparkles"),
    ("bubbles",  "Bubbles"),
    ("glitter",  "Glitter"),
    ("hearts",   "Hearts"),
]

_WEIGHT_VALUES = [0.1, 1.0, 3.0, 5.0]
_WEIGHT_LABELS = ["rare", "normal", "often", "constant"]


def _nearest_pos(value: float, table: list) -> int:
    return min(range(len(table)), key=lambda i: abs(table[i] - value))

# ── Animal roster ────────────────────────────────────────────────────────────

ANIMALS = [
    ("kitten",   "🐱", "Kitten"),
    ("turtle",   "🐢", "Turtle"),
    ("duck",     "🦆", "Duck"),
    ("rabbit",   "🐰", "Rabbit"),
    ("hedgehog", "🦔", "Hedgehog"),
    ("squirrel", "🐿️", "Squirrel"),
    ("otter",    "🦦", "Otter"),
    ("panda",    "🐼", "Panda"),
]


# ─────────────────────────────────────────────────────────────────────────────

class SettingsWindow:

    def __init__(self,
                 config: dict,
                 on_save: Callable[[dict], None],
                 on_force_spawn: Callable[[], None],
                 on_quit: Callable[[], None],
                 get_paused: Callable[[], bool] = None,
                 registry: CustomCritterRegistry | None = None,
                 on_test_custom_spawn: Callable[[str], None] | None = None,
                 preview_frames: dict | None = None,
                 sound_manager=None):
        self._config               = config
        self._on_save              = on_save
        self._on_force_spawn       = on_force_spawn
        self._on_quit              = on_quit
        self._get_paused           = get_paused or (lambda: False)
        self._registry             = registry or CustomCritterRegistry()
        self._on_test_custom_spawn = on_test_custom_spawn
        self._on_toggle_pause: Callable | None = None
        self._sound_manager        = sound_manager

        # Raw base64 frame data — PhotoImages are created in the tkinter thread
        self._preview_frames_data: dict = preview_frames if preview_frames is not None else _ANIMAL_FRAMES

        self._root: tk.Tk | None = None
        self._thread: threading.Thread | None = None
        self._lock = threading.Lock()
        self._pending_drop: str | None = None  # path queued before window opened

        # Animated preview frames: species -> list[ImageTk.PhotoImage]
        # Populated in _run() (tkinter thread) from _preview_frames_data.
        self._animal_frames:       dict[str, list] = {}
        self._animal_frames_small: dict[str, list] = {}

        # Active animation callbacks: after() job ids, cancelled on page change
        self._anim_jobs: list[str] = []

        self._current_page = "critters"
        self._content_frame: tk.Frame | None = None
        self._nav_btns: dict[str, tk.Button] = {}

        # Live-update labels (sidebar only)
        self._status_dot: tk.Label | None   = None
        self._status_lbl: tk.Label | None   = None
        self._sidebar_pause_btn: tk.Button | None = None

    # ── Public API ────────────────────────────────────────────────────────────

    def set_toggle_pause(self, fn: Callable) -> None:
        """Wire in the pause-toggle action after construction."""
        self._on_toggle_pause = fn

    def open(self) -> None:
        with self._lock:
            if self._thread and self._thread.is_alive():
                if self._root:
                    self._root.after(0, self._restore)
                return
            self._thread = threading.Thread(target=self._run, daemon=True)
            self._thread.start()

    def close(self) -> None:
        if self._root:
            try:
                self._root.after(0, self._root.destroy)
            except Exception:
                pass

    def update_config(self, config: dict) -> None:
        self._config = config

    def handle_file_drop(self, path: str) -> None:
        """Called from the overlay thread when a .critter file is dropped."""
        if self._root is not None:
            self._root.after(0, lambda: self._import_flow(path))
        else:
            self._pending_drop = path
            self.open()

    # ── Internal ──────────────────────────────────────────────────────────────

    def _restore(self) -> None:
        self._root.deiconify()
        self._root.lift()
        self._root.focus_force()

    def _run(self) -> None:
        self._root = tk.Tk()
        self._load_animal_frames()   # must run in tkinter thread (PhotoImage needs a root)
        self._build_window()
        if _SVTTK:
            _sv_ttk.set_theme("dark")
        self._poll_status()
        if not self._config.get("first_run_completed", False):
            self._root.after(400, self._show_welcome_modal)
        if self._pending_drop:
            path = self._pending_drop
            self._pending_drop = None
            self._root.after(600, lambda: self._import_flow(path))
        self._root.mainloop()
        self._root = None
        self._animal_frames.clear()
        self._animal_frames_small.clear()

    # ── Window skeleton ───────────────────────────────────────────────────────

    def _build_window(self) -> None:
        root = self._root
        root.title("Critter Overlay")
        root.configure(bg=SIDEBAR_BG)
        root.resizable(True, True)
        root.minsize(700, 500)

        # X button → minimise to tray, don't quit
        root.protocol("WM_DELETE_WINDOW", lambda: root.withdraw())

        w, h = 800, 580
        sw, sh = root.winfo_screenwidth(), root.winfo_screenheight()
        root.geometry(f"{w}x{h}+{(sw-w)//2}+{(sh-h)//2}")

        # Two-column layout
        sidebar = tk.Frame(root, bg=SIDEBAR_BG, width=190)
        sidebar.pack(side="left", fill="y")
        sidebar.pack_propagate(False)

        divider = tk.Frame(root, bg=BORDER, width=1)
        divider.pack(side="left", fill="y")

        content_wrap = tk.Frame(root, bg=CONTENT_BG)
        content_wrap.pack(side="left", fill="both", expand=True)

        self._content_frame = content_wrap
        self._build_sidebar(sidebar)
        self._show_page("critters")

    # ── Sidebar ───────────────────────────────────────────────────────────────

    def _build_sidebar(self, parent: tk.Frame) -> None:

        # ── Branding ──
        brand = tk.Frame(parent, bg=SIDEBAR_BG)
        brand.pack(fill="x", pady=(28, 20), padx=20)

        tk.Label(brand, text="🐾", font=(FF, 30), bg=SIDEBAR_BG).pack(anchor="w")
        tk.Label(brand, text="Critter Overlay", font=(FF, 13, "bold"),
                 bg=SIDEBAR_BG, fg=FG).pack(anchor="w", pady=(4, 0))
        tk.Label(brand, text=f"v{APP_VERSION}", font=(FF, 8),
                 bg=SIDEBAR_BG, fg=FG3).pack(anchor="w")

        # ── Status pill ──
        pill = tk.Frame(parent, bg=SIDEBAR_BG)
        pill.pack(fill="x", padx=20, pady=(0, 18))

        self._status_dot = tk.Label(pill, text="●", font=(FF, 11),
                                    bg=SIDEBAR_BG, fg=GREEN)
        self._status_dot.pack(side="left")
        self._status_lbl = tk.Label(pill, text="Running", font=(FF, 9),
                                    bg=SIDEBAR_BG, fg=GREEN)
        self._status_lbl.pack(side="left", padx=(5, 0))

        # ── Nav separator ──
        tk.Frame(parent, bg=BORDER, height=1).pack(fill="x", padx=16, pady=(0, 10))

        # ── Nav items ──
        nav = [
            ("critters",  "🐾", "Critters"),
            ("behaviour", "⏱",  "Behaviour"),
            ("audio",     "🔊", "Audio"),
            ("system",    "⚙",  "System"),
        ]
        for page_id, icon, label in nav:
            btn = tk.Button(
                parent,
                text=f"  {icon}   {label}",
                anchor="w",
                command=lambda p=page_id: self._show_page(p),
                bg=SIDEBAR_BG, fg=FG2,
                activebackground=SEL_BG, activeforeground=FG,
                relief="flat", font=(FF, 10),
                cursor="hand2", pady=11, padx=12,
            )
            btn.pack(fill="x", padx=8, pady=1)
            self._nav_btns[page_id] = btn

        # ── Bottom actions ──
        tk.Frame(parent, bg=BORDER, height=1).pack(fill="x", padx=16, pady=14)

        spawn_btn = tk.Button(
            parent,
            text="💥  Spawn Now",
            command=self._on_force_spawn,
            bg="#1a0f35", fg=ACCENT,
            activebackground="#23154a", activeforeground=ACCENT,
            relief="flat", font=(FF, 9, "bold"),
            cursor="hand2", pady=9,
        )
        spawn_btn.pack(fill="x", padx=12, pady=(0, 6))

        self._sidebar_pause_btn = tk.Button(
            parent,
            text="⏸  Pause",
            command=self._toggle_pause,
            bg="#120f0f", fg=FG2,
            activebackground="#1e1515", activeforeground=RED,
            relief="flat", font=(FF, 9, "bold"),
            cursor="hand2", pady=9,
        )
        self._sidebar_pause_btn.pack(fill="x", padx=12, pady=(0, 16))

    # ── Status polling ────────────────────────────────────────────────────────

    def _poll_status(self) -> None:
        if self._root is None:
            return
        paused = self._get_paused()
        self._apply_status(paused)
        self._root.after(700, self._poll_status)

    def _apply_status(self, paused: bool) -> None:
        dot_col  = RED   if paused else GREEN
        dot_text = "⏸"  if paused else "●"
        lbl_text = "Paused"  if paused else "Running"
        btn_text = "▶  Resume" if paused else "⏸  Pause"
        btn_fg   = GREEN if paused else FG2

        if self._status_dot:
            try:
                self._status_dot.configure(text=dot_text, fg=dot_col)
            except tk.TclError:
                pass
        if self._status_lbl:
            try:
                self._status_lbl.configure(text=lbl_text, fg=dot_col)
            except tk.TclError:
                pass
        if self._sidebar_pause_btn:
            try:
                self._sidebar_pause_btn.configure(text=btn_text, fg=btn_fg)
            except tk.TclError:
                pass

    # ── Page routing ──────────────────────────────────────────────────────────

    def _show_page(self, page_id: str) -> None:
        self._current_page = page_id
        self._cancel_anims()

        for pid, btn in self._nav_btns.items():
            if pid == page_id:
                btn.configure(bg=SEL_BG, fg=FG, font=(FF, 10, "bold"))
            else:
                btn.configure(bg=SIDEBAR_BG, fg=FG2, font=(FF, 10))

        # Unbind wheel before destroying old canvas so stale callbacks don't linger
        if self._root:
            try:
                self._root.unbind_all("<MouseWheel>")
            except Exception:
                pass

        for w in self._content_frame.winfo_children():
            w.destroy()

        {
            "critters":  self._page_critters,
            "behaviour": self._page_behaviour,
            "audio":     self._page_audio,
            "system":    self._page_system,
        }.get(page_id, self._page_critters)(self._content_frame)

    # ── Welcome modal (first-run only) ────────────────────────────────────────

    def _show_welcome_modal(self) -> None:
        if not self._root:
            return

        modal = tk.Toplevel(self._root)
        modal.title("Welcome")
        modal.configure(bg=CONTENT_BG)
        modal.resizable(False, False)
        modal.grab_set()

        w, h = 420, 230
        sw, sh = modal.winfo_screenwidth(), modal.winfo_screenheight()
        modal.geometry(f"{w}x{h}+{(sw-w)//2}+{(sh-h)//2}")

        inner = tk.Frame(modal, bg=CONTENT_BG, padx=28, pady=22)
        inner.pack(fill="both", expand=True)

        tk.Label(inner, text="Welcome to Critter Overlay",
                 font=(FF, 14, "bold"), bg=CONTENT_BG, fg=FG).pack(anchor="w")

        tk.Label(inner,
                 text="Right-click the paw icon in your taskbar to open\n"
                      "settings, pause, or spawn a critter.",
                 font=(FF, 9), bg=CONTENT_BG, fg=FG2,
                 justify="left").pack(anchor="w", pady=(10, 6))

        hotkey_row = tk.Frame(inner, bg=CONTENT_BG)
        hotkey_row.pack(anchor="w", pady=(0, 18))
        tk.Label(hotkey_row, text="Hotkey: ",
                 font=(FF, 9), bg=CONTENT_BG, fg=FG2).pack(side="left")
        tk.Label(hotkey_row, text="Ctrl + Shift + P",
                 font=(FF, 9, "bold"), bg="#1a1040", fg=ACCENT,
                 padx=8, pady=3).pack(side="left")
        tk.Label(hotkey_row, text="  pause / resume",
                 font=(FF, 9), bg=CONTENT_BG, fg=FG2).pack(side="left")

        btn_row = tk.Frame(inner, bg=CONTENT_BG)
        btn_row.pack(fill="x")

        def _dismiss():
            self._config["first_run_completed"] = True
            save_config(self._config)
            self._on_save(self._config)
            try:
                modal.destroy()
            except tk.TclError:
                pass

        tk.Button(btn_row, text="Don't show again",
                  command=_dismiss,
                  bg=CARD_BG, fg=FG2,
                  activebackground=CARD_HOV, activeforeground=FG,
                  relief="flat", font=(FF, 9),
                  cursor="hand2", padx=12, pady=8).pack(side="left")

        tk.Button(btn_row, text="Open Settings",
                  command=_dismiss,
                  bg="#1a0f35", fg=ACCENT,
                  activebackground="#23154a", activeforeground=ACCENT,
                  relief="flat", font=(FF, 9, "bold"),
                  cursor="hand2", padx=16, pady=8).pack(side="left", padx=(8, 0))

        modal.after(8000, lambda: _dismiss() if modal.winfo_exists() else None)

    # ── Tooltip helper ────────────────────────────────────────────────────────

    def _add_tooltip(self, widget: tk.Widget, text: str) -> None:
        """Show a small tooltip near the widget on hover."""
        tip: dict = {"win": None}

        def on_enter(e):
            if tip["win"]:
                return
            x = widget.winfo_rootx() + 20
            y = widget.winfo_rooty() + widget.winfo_height() + 4
            tw = tk.Toplevel(self._root)
            tw.wm_overrideredirect(True)
            tw.wm_geometry(f"+{x}+{y}")
            tk.Label(tw, text=text, font=(FF, 8), bg="#2d2d4a", fg=FG2,
                     padx=7, pady=4, justify="left",
                     wraplength=260).pack()
            tip["win"] = tw

        def on_leave(e):
            if tip["win"]:
                try:
                    tip["win"].destroy()
                except tk.TclError:
                    pass
                tip["win"] = None

        widget.bind("<Enter>", on_enter, add="+")
        widget.bind("<Leave>", on_leave, add="+")

    # ── Generic fn-based setting widgets ─────────────────────────────────────

    def _setting_toggle_fn(self, parent, label, desc, get_fn, set_fn,
                           tooltip: str = "") -> None:
        """Toggle card with custom get/set lambdas (for nested config paths)."""
        card = tk.Frame(parent, bg=CARD_BG, padx=18, pady=14)
        card.pack(fill="x", pady=(0, 8))

        cur = get_fn()
        var = tk.BooleanVar(value=cur)

        head = tk.Frame(card, bg=CARD_BG)
        head.pack(fill="x")

        lbl = tk.Label(head, text=label, font=(FF, 10, "bold"), bg=CARD_BG, fg=FG)
        lbl.pack(side="left")
        if tooltip:
            self._add_tooltip(lbl, tooltip)

        state_lbl = tk.Label(head,
                             text=("✓  ON" if cur else "✕  OFF"),
                             font=(FF, 8, "bold"), bg=CARD_BG,
                             fg=(GREEN if cur else FG3))
        state_lbl.pack(side="right", padx=(0, 6))

        def on_toggle(v=var, lbl=state_lbl):
            val = v.get()
            lbl.configure(text=("✓  ON" if val else "✕  OFF"),
                          fg=(GREEN if val else FG3))
            set_fn(val)
            save_config(self._config)
            self._on_save(self._config)

        chk = tk.Checkbutton(head, variable=var, command=on_toggle,
                             bg=CARD_BG, activebackground=CARD_BG,
                             selectcolor=CARD_BG, fg=ACCENT,
                             relief="flat", cursor="hand2")
        chk.pack(side="right")

        tk.Label(card, text=desc, font=(FF, 8), bg=CARD_BG, fg=FG3).pack(
            anchor="w", pady=(2, 0))

    def _setting_slider_fn(self, parent, label, desc, get_fn, set_fn,
                           from_, to, res, unit="", tooltip: str = "") -> None:
        """Slider card with custom get/set lambdas."""
        card = tk.Frame(parent, bg=CARD_BG, padx=18, pady=14)
        card.pack(fill="x", pady=(0, 8))

        head = tk.Frame(card, bg=CARD_BG)
        head.pack(fill="x")

        lbl = tk.Label(head, text=label, font=(FF, 10, "bold"), bg=CARD_BG, fg=FG)
        lbl.pack(side="left")
        if tooltip:
            self._add_tooltip(lbl, tooltip)

        cur = get_fn()
        display_val = int(cur) if res >= 1 else round(cur, 2)
        val_lbl = tk.Label(head, text=f"{display_val}{unit}",
                           font=(FF, 10, "bold"), bg=CARD_BG, fg=ACCENT)
        val_lbl.pack(side="right")

        tk.Label(card, text=desc, font=(FF, 8), bg=CARD_BG, fg=FG3).pack(
            anchor="w", pady=(2, 6))

        var = tk.DoubleVar(value=cur)

        def on_slide(v, lbl=val_lbl, u=unit):
            fv = int(float(v)) if res >= 1 else round(float(v), 2)
            lbl.configure(text=f"{fv}{u}")
            set_fn(fv)
            save_config(self._config)
            self._on_save(self._config)

        tk.Scale(card, from_=from_, to=to, resolution=res,
                 orient="horizontal", variable=var,
                 bg=CARD_BG, fg=FG, troughcolor=SLIDER_TR,
                 highlightthickness=0, bd=0, showvalue=False,
                 command=on_slide).pack(fill="x")

    # ── Animal preview frame loader ───────────────────────────────────────────

    def _load_animal_frames(self) -> None:
        """Decode base64 PNGs into full-size and half-size PhotoImage lists."""
        self._animal_frames.clear()
        self._animal_frames_small.clear()
        for species, b64_list in self._preview_frames_data.items():
            full, small = [], []
            for b64 in b64_list:
                try:
                    img = Image.open(io.BytesIO(base64.b64decode(b64))).convert("RGB")
                    full.append(ImageTk.PhotoImage(img))
                    sm = img.resize((48, 48), Image.LANCZOS)
                    small.append(ImageTk.PhotoImage(sm))
                except Exception as e:
                    print(f"[settings] Frame load failed for {species}: {e}")
            if full:
                self._animal_frames[species]       = full
            if small:
                self._animal_frames_small[species] = small

    def _start_anim(self, label: tk.Label, frames: list) -> None:
        """Cycle through frames on a Label widget at _ANIM_FPS."""
        if not frames or len(frames) < 2:
            return
        delay = 1000 // _ANIM_FPS
        state = [0]

        def tick():
            if not self._root:
                return
            try:
                state[0] = (state[0] + 1) % len(frames)
                label.configure(image=frames[state[0]])
                job = self._root.after(delay, tick)
                self._anim_jobs.append(job)
            except tk.TclError:
                pass  # widget destroyed

        job = self._root.after(delay, tick)
        self._anim_jobs.append(job)

    def _cancel_anims(self) -> None:
        """Cancel all pending animation callbacks."""
        if self._root:
            for job in self._anim_jobs:
                try:
                    self._root.after_cancel(job)
                except Exception:
                    pass
        self._anim_jobs.clear()

    def _animal_card(self, parent, species, emoji, name) -> None:
        cfg = self._config["animals"][species]
        enabled_var = tk.BooleanVar(value=cfg.get("enabled", True))

        # ── Horizontal layout: animated preview | controls ──
        left = tk.Frame(parent, bg=CARD_BG)
        left.pack(side="left", padx=(0, 14))

        right = tk.Frame(parent, bg=CARD_BG)
        right.pack(side="left", fill="both", expand=True)

        # ── Animated preview ──
        frames = self._animal_frames.get(species)
        if frames:
            img_lbl = tk.Label(left, image=frames[0], bg=CARD_BG,
                               width=_PREVIEW_SIZE, height=_PREVIEW_SIZE)
            img_lbl.image = frames[0]
            img_lbl.pack()
            self._start_anim(img_lbl, frames)
        else:
            img_lbl = tk.Label(left, text=emoji, font=(FF, 28), bg=CARD_BG)
            img_lbl.pack(padx=(_PREVIEW_SIZE // 4,) * 2,
                         pady=(_PREVIEW_SIZE // 4,) * 2)

        # ── Name + enabled toggle ──
        head = tk.Frame(right, bg=CARD_BG)
        head.pack(fill="x")

        tk.Label(head, text=name, font=(FF, 12, "bold"),
                 bg=CARD_BG, fg=FG).pack(side="left")

        is_on = cfg.get("enabled", True)
        pill = tk.Label(head, text="✓  ON" if is_on else "✕  OFF",
                        font=(FF, 8, "bold"),
                        bg=("#0f2015" if is_on else CARD_BG),
                        fg=(GREEN if is_on else FG3),
                        padx=7, pady=2, cursor="hand2")
        pill.pack(side="right", padx=(0, 2))

        chk = tk.Checkbutton(head, variable=enabled_var,
                             bg=CARD_BG, activebackground=CARD_BG,
                             selectcolor=CARD_BG, fg=ACCENT,
                             relief="flat", cursor="hand2")
        chk.pack(side="right")

        def on_toggle(p=pill, v=enabled_var, s=species):
            val = v.get()
            p.configure(text="✓  ON" if val else "✕  OFF",
                        fg=(GREEN if val else FG3),
                        bg=("#0f2015" if val else CARD_BG))
            self._set("animals", s, "enabled", val)

        chk.configure(command=on_toggle)
        pill.bind("<Button-1>", lambda e, v=enabled_var: (v.set(not v.get()), on_toggle()))

        # ── Spawn frequency (labeled stops) ──
        tk.Frame(right, bg=BORDER, height=1).pack(fill="x", pady=(10, 8))

        freq_lbl = tk.Label(right, text="Spawn frequency",
                            font=(FF, 8), bg=CARD_BG, fg=FG3)
        freq_lbl.pack(anchor="w")
        self._add_tooltip(freq_lbl, "How often this species is chosen when a group spawns.\n"
                                    "rare = picked rarely, constant = almost always included.")
        self._labeled_slider(right, "",
                             _WEIGHT_VALUES, _WEIGHT_LABELS,
                             get_fn=lambda s=species: cfg.get("weight", 1.0),
                             set_fn=lambda v, s=species: self._set("animals", s, "weight", v))

        # ── Personality sliders ──
        tk.Frame(right, bg=BORDER, height=1).pack(fill="x", pady=(6, 6))

        speed_lbl = tk.Label(right, text="Speed", font=(FF, 8), bg=CARD_BG, fg=FG3)
        speed_lbl.pack(anchor="w")
        self._add_tooltip(speed_lbl, "How fast this species moves across the screen.")
        self._labeled_slider(right, "",
                             _SPEED_VALUES, _SPEED_LABELS,
                             get_fn=lambda s=species: cfg.get("speed_multiplier", 1.0),
                             set_fn=lambda v, s=species: self._set("animals", s, "speed_multiplier", v))

        act_lbl = tk.Label(right, text="Activity level", font=(FF, 8), bg=CARD_BG, fg=FG3)
        act_lbl.pack(anchor="w", pady=(4, 0))
        self._add_tooltip(act_lbl, "How often this species stops to idle, groom, or nap.\n"
                                   "narcoleptic = constantly stopping, wired = rarely stops.")
        self._labeled_slider(right, "",
                             _IDLE_VALUES, _IDLE_LABELS,
                             get_fn=lambda s=species: cfg.get("idle_rate", 0.018),
                             set_fn=lambda v, s=species: self._set("animals", s, "idle_rate", v))

        self._trail_radio_row(right,
                              get_fn=lambda s=species: cfg.get("trail_style", "none"),
                              set_fn=lambda v, s=species: self._set("animals", s, "trail_style", v))

    # ── Page: Critters (built-ins + custom merged) ───────────────────────────

    def _page_critters(self, parent: tk.Frame) -> None:
        self._page_header(parent, "Critters",
                          "Manage built-in species and custom critters.")
        _, inner = self._scrollable(parent)

        # ── Import / export buttons ──
        btn_row = tk.Frame(inner, bg=CONTENT_BG)
        btn_row.pack(fill="x", pady=(0, 16))
        for col in range(4):
            btn_row.grid_columnconfigure(col, weight=1)

        tk.Button(btn_row,
            text="＋  Import image",
            command=lambda: self._import_dialog(inner),
            bg="#1a0f35", fg=ACCENT,
            activebackground="#23154a", activeforeground=ACCENT,
            relief="flat", font=(FF, 9, "bold"),
            cursor="hand2", pady=10, padx=10, anchor="w",
        ).grid(row=0, column=0, sticky="ew", padx=(0, 4))

        tk.Button(btn_row,
            text="＋  Import frames",
            command=lambda: self._import_frames_dialog(inner),
            bg="#0f1a35", fg=ACCENT2,
            activebackground="#152545", activeforeground=ACCENT2,
            relief="flat", font=(FF, 9, "bold"),
            cursor="hand2", pady=10, padx=10, anchor="w",
        ).grid(row=0, column=1, sticky="ew", padx=(0, 4))

        tk.Button(btn_row,
            text="📦  Import .critter",
            command=self._import_critter_file,
            bg="#0f251a", fg=GREEN,
            activebackground="#143020", activeforeground=GREEN,
            relief="flat", font=(FF, 9, "bold"),
            cursor="hand2", pady=10, padx=10, anchor="w",
        ).grid(row=0, column=2, sticky="ew", padx=(0, 4))

        tk.Button(btn_row,
            text="⬆  Export all",
            command=self._bulk_export,
            bg=CARD_BG, fg=FG2,
            activebackground=CARD_HOV, activeforeground=FG,
            relief="flat", font=(FF, 9),
            cursor="hand2", pady=10, padx=10, anchor="w",
        ).grid(row=0, column=3, sticky="ew")

        # ── Built-in species ──
        self._section_label(inner, "Built-in species")

        for species, emoji, name in ANIMALS:
            cell = tk.Frame(inner, bg=CARD_BG, padx=18, pady=16)
            cell.pack(fill="x", pady=(0, 8))
            self._animal_card(cell, species, emoji, name)

        link = tk.Label(inner, text="Reset all weights to default",
                        font=(FF, 9), bg=CONTENT_BG, fg=FG3, cursor="hand2")
        link.pack(anchor="w", pady=(8, 16))
        link.bind("<Button-1>", lambda e: self._reset_weights())

        # ── Custom critters ──
        self._section_label(inner, "Custom critters")

        records = self._registry.all()
        if not records:
            tk.Label(inner,
                     text="No custom critters yet. Use the import buttons above to add one.",
                     font=(FF, 9), bg=CONTENT_BG, fg=FG3,
                     wraplength=460, justify="left").pack(anchor="w", pady=(4, 16))
            return

        for record in records:
            self._custom_critter_row(inner, record)

    def _custom_critter_row(self, parent: tk.Frame, record) -> None:
        cid        = record.id
        meta       = record.meta
        custom_cfg = self._config.get("custom_animals", {}).get(cid, {})

        card = tk.Frame(parent, bg=CARD_BG, padx=16, pady=14)
        card.pack(fill="x", pady=(0, 8))

        # ── Left: animated preview on hover ──
        left = tk.Frame(card, bg=CARD_BG, width=_PREVIEW_SIZE, height=_PREVIEW_SIZE)
        left.pack(side="left", padx=(0, 14))
        left.pack_propagate(False)

        preview_lbl = tk.Label(left, bg=CARD_BG,
                               width=_PREVIEW_SIZE, height=_PREVIEW_SIZE)
        preview_lbl.pack()

        # Load static thumb immediately; animate on hover
        static_photo = self._load_custom_thumb(cid)
        if static_photo:
            preview_lbl.configure(image=static_photo)
            preview_lbl.image = static_photo
        else:
            preview_lbl.configure(text="🐾", font=(FF, 22), fg=FG3)

        self._bind_custom_hover(preview_lbl, cid, static_photo)

        # ── Right controls ──
        right = tk.Frame(card, bg=CARD_BG)
        right.pack(side="left", fill="both", expand=True)

        # Name + enabled row
        head = tk.Frame(right, bg=CARD_BG)
        head.pack(fill="x")

        name_var = tk.StringVar(value=meta.get("name", cid))
        name_entry = tk.Entry(head, textvariable=name_var,
                              font=(FF, 11, "bold"),
                              bg=CARD_BG, fg=FG, insertbackground=FG,
                              relief="flat", bd=0)
        name_entry.pack(side="left", fill="x", expand=True)

        def on_name_change(e, _cid=cid, var=name_var):
            new_name = var.get().strip()
            if not new_name:
                return
            meta["name"] = new_name
            write_meta(get_custom_dir() / _cid, meta)

        name_entry.bind("<FocusOut>", on_name_change)
        name_entry.bind("<Return>",   on_name_change)

        is_on       = custom_cfg.get("enabled", True)
        enabled_var = tk.BooleanVar(value=is_on)
        pill = tk.Label(head,
                        text="✓  ON" if is_on else "✕  OFF",
                        font=(FF, 8, "bold"),
                        bg=("#0f2015" if is_on else CARD_BG),
                        fg=(GREEN if is_on else FG3),
                        padx=7, pady=2, cursor="hand2")
        pill.pack(side="right", padx=(0, 2))

        chk = tk.Checkbutton(head, variable=enabled_var,
                             bg=CARD_BG, activebackground=CARD_BG,
                             selectcolor=CARD_BG, fg=ACCENT,
                             relief="flat", cursor="hand2")
        chk.pack(side="right")

        def on_toggle(_cid=cid, v=enabled_var, p=pill):
            val = v.get()
            p.configure(text="✓  ON" if val else "✕  OFF",
                        fg=(GREEN if val else FG3),
                        bg=("#0f2015" if val else CARD_BG))
            self._set_custom(_cid, "enabled", val)

        chk.configure(command=on_toggle)
        pill.bind("<Button-1>", lambda e, v=enabled_var: (v.set(not v.get()), on_toggle()))

        # Frame count + method badge
        frame_count  = meta.get("frame_count", 4)
        import_method = meta.get("import_method", "static_png")
        badge_text = {
            "static_png":   "procedural",
            "static_jpg":   "procedural",
            "animated_gif": "animated gif",
            "frame_strip":  "drawn frames",
        }.get(import_method, import_method)

        tk.Label(right,
                 text=f"{frame_count} frames  ·  {badge_text}",
                 font=(FF, 7), bg=CARD_BG, fg=FG3).pack(anchor="w", pady=(2, 0))

        # ── Spawn frequency (labeled stops) ──
        tk.Frame(right, bg=BORDER, height=1).pack(fill="x", pady=(8, 6))

        freq_lbl = tk.Label(right, text="Spawn frequency",
                            font=(FF, 8), bg=CARD_BG, fg=FG3)
        freq_lbl.pack(anchor="w")
        self._add_tooltip(freq_lbl, "How often this critter is chosen when a group spawns.")
        self._labeled_slider(right, "",
                             _WEIGHT_VALUES, _WEIGHT_LABELS,
                             get_fn=lambda _cid=cid: custom_cfg.get("weight", 1.0),
                             set_fn=lambda v, _cid=cid: self._set_custom(_cid, "weight", v))

        # ── Personality controls (always visible) ──
        tk.Frame(right, bg=BORDER, height=1).pack(fill="x", pady=(6, 6))

        def _meta_set(key, value, _cid=cid):
            meta[key] = value
            write_meta(get_custom_dir() / _cid, meta)

        size_lbl = tk.Label(right, text="Size", font=(FF, 8), bg=CARD_BG, fg=FG3)
        size_lbl.pack(anchor="w")
        self._add_tooltip(size_lbl, "Scales this critter up or down relative to the global size.")
        self._labeled_slider(right, "",
                             _SIZE_VALUES, _SIZE_LABELS,
                             get_fn=lambda: meta.get("size_multiplier", 1.0),
                             set_fn=lambda v: _meta_set("size_multiplier", v))

        speed_lbl = tk.Label(right, text="Speed", font=(FF, 8), bg=CARD_BG, fg=FG3)
        speed_lbl.pack(anchor="w", pady=(4, 0))
        self._add_tooltip(speed_lbl, "How fast this critter walks across the screen.")
        self._labeled_slider(right, "",
                             _SPEED_VALUES, _SPEED_LABELS,
                             get_fn=lambda: meta.get("speed_multiplier", 1.0),
                             set_fn=lambda v: _meta_set("speed_multiplier", v))

        act_lbl = tk.Label(right, text="Activity level", font=(FF, 8), bg=CARD_BG, fg=FG3)
        act_lbl.pack(anchor="w", pady=(4, 0))
        self._add_tooltip(act_lbl, "How often this critter stops to idle, groom, or nap.")
        self._labeled_slider(right, "",
                             _IDLE_VALUES, _IDLE_LABELS,
                             get_fn=lambda: meta.get("idle_rate", 0.018),
                             set_fn=lambda v: _meta_set("idle_rate", v))

        self._trail_radio_row(right,
                              get_fn=lambda: meta.get("trail_style", "none"),
                              set_fn=lambda v: _meta_set("trail_style", v))

        # ── Sound ──
        tk.Frame(right, bg=BORDER, height=1).pack(fill="x", pady=(4, 8))
        self._build_sound_picker(right, cid, meta)

        # ── Action row ──
        tk.Frame(right, bg=BORDER, height=1).pack(fill="x", pady=(6, 6))
        act_row = tk.Frame(right, bg=CARD_BG)
        act_row.pack(fill="x")

        tk.Button(act_row, text="▶ Test",
                  command=lambda _cid=cid:
                      self._on_test_custom_spawn and self._on_test_custom_spawn(_cid),
                  bg=CARD_BG, fg=ACCENT2,
                  activebackground=SEL_BG, activeforeground=FG,
                  relief="flat", font=(FF, 8, "bold"),
                  cursor="hand2", padx=8, pady=4).pack(side="left")

        tk.Button(act_row, text="⬆ Export",
                  command=lambda _cid=cid: self._export_critter(_cid),
                  bg=CARD_BG, fg=FG2,
                  activebackground=CARD_HOV, activeforeground=FG,
                  relief="flat", font=(FF, 8),
                  cursor="hand2", padx=8, pady=4).pack(side="left", padx=(4, 0))

        tk.Button(act_row, text="✕ Delete",
                  command=lambda _cid=cid: self._delete_custom(_cid),
                  bg=CARD_BG, fg=RED,
                  activebackground="#2a1010", activeforeground=RED,
                  relief="flat", font=(FF, 8),
                  cursor="hand2", padx=8, pady=4).pack(side="right")

    # ── Shared slider widget ──────────────────────────────────────────────────

    def _labeled_slider(self, parent: tk.Frame, row_label: str,
                        steps: list, labels: list,
                        get_fn, set_fn, bg=CARD_BG) -> None:
        """Reusable labeled discrete slider. get_fn() → current value; set_fn(value) → persist."""
        cur_val = get_fn()
        cur_pos = _nearest_pos(cur_val, steps)

        row = tk.Frame(parent, bg=bg)
        row.pack(fill="x", pady=(0, 6))

        if row_label:
            tk.Label(row, text=row_label, font=(FF, 8), bg=bg,
                     fg=FG3, width=8, anchor="w").pack(side="left")

        val_lbl = tk.Label(row, text=labels[cur_pos],
                           font=(FF, 8, "bold"), bg=bg, fg=ACCENT, width=12, anchor="w")
        val_lbl.pack(side="left", padx=(4, 0))

        var = tk.IntVar(value=cur_pos)

        def on_change(v, _steps=steps, _labels=labels, _lbl=val_lbl, _set=set_fn):
            pos = int(float(v))
            _lbl.configure(text=_labels[pos])
            _set(_steps[pos])

        tk.Scale(row, from_=0, to=len(steps) - 1, resolution=1,
                 orient="horizontal", variable=var,
                 bg=bg, fg=FG2, troughcolor=SLIDER_TR,
                 highlightthickness=0, bd=0, showvalue=False,
                 command=on_change).pack(side="left", fill="x", expand=True, padx=(8, 0))

    def _trail_radio_row(self, parent: tk.Frame, get_fn, set_fn, bg=CARD_BG) -> None:
        """Animation trail radio buttons (7 options). get_fn() → current str; set_fn(str) → persist."""
        trail_row = tk.Frame(parent, bg=bg)
        trail_row.pack(fill="x", pady=(0, 8))
        tk.Label(trail_row, text="Trail", font=(FF, 8), bg=bg,
                 fg=FG3, anchor="w").pack(side="left", padx=(0, 4))

        trail_var = tk.StringVar(value=get_fn())

        def on_trail(*_, var=trail_var):
            set_fn(var.get())

        trail_var.trace_add("write", on_trail)

        # Two rows of radio buttons to avoid overflow
        rb_wrap = tk.Frame(trail_row, bg=bg)
        rb_wrap.pack(side="left", fill="x", expand=True)
        row1 = tk.Frame(rb_wrap, bg=bg)
        row1.pack(anchor="w")
        row2 = tk.Frame(rb_wrap, bg=bg)
        row2.pack(anchor="w")
        for i, (style_val, style_lbl) in enumerate(_TRAIL_STYLES):
            dest = row1 if i < 4 else row2
            tk.Radiobutton(dest, text=style_lbl, variable=trail_var, value=style_val,
                           bg=bg, fg=FG2, activebackground=bg,
                           selectcolor=bg, font=(FF, 8),
                           relief="flat", cursor="hand2").pack(side="left", padx=(4, 0))

    # ── Custom critter settings panel (reused by inline layout) ──────────────

    def _build_critter_settings(self, panel: tk.Frame, cid: str, meta: dict) -> None:
        tk.Frame(panel, bg=BORDER, height=1).pack(fill="x", pady=(6, 8))

        def _meta_get(key, default):
            return meta.get(key, default)

        def _meta_set(key, value):
            meta[key] = value
            write_meta(get_custom_dir() / cid, meta)

        # Size slider (top of panel)
        self._labeled_slider(panel, "Size",
                             _SIZE_VALUES, _SIZE_LABELS,
                             get_fn=lambda: _meta_get("size_multiplier", 1.0),
                             set_fn=lambda v: _meta_set("size_multiplier", v))

        self._labeled_slider(panel, "Speed",
                             _SPEED_VALUES, _SPEED_LABELS,
                             get_fn=lambda: _meta_get("speed_multiplier", 1.0),
                             set_fn=lambda v: _meta_set("speed_multiplier", v))

        self._labeled_slider(panel, "Idle",
                             _IDLE_VALUES, _IDLE_LABELS,
                             get_fn=lambda: _meta_get("idle_rate", 0.018),
                             set_fn=lambda v: _meta_set("idle_rate", v))

        self._trail_radio_row(panel,
                              get_fn=lambda: meta.get("trail_style", "none"),
                              set_fn=lambda v: _meta_set("trail_style", v))

        # Sound picker: preset + file upload
        tk.Frame(panel, bg=BORDER, height=1).pack(fill="x", pady=(4, 8))
        self._build_sound_picker(panel, cid, meta)

    def _build_sound_picker(self, panel: tk.Frame, cid: str, meta: dict) -> None:
        """Sound preset selector + file upload + preview button for a custom critter."""
        custom_cfg = self._config.get("custom_animals", {}).get(cid, {})

        lbl_row = tk.Frame(panel, bg=CARD_BG)
        lbl_row.pack(fill="x", pady=(0, 4))
        tk.Label(lbl_row, text="Sound", font=(FF, 8, "bold"),
                 bg=CARD_BG, fg=FG2).pack(side="left")

        current_profile = custom_cfg.get("sound_override") or meta.get("sound_profile", "kitten")
        current_file    = custom_cfg.get("sound_file", "")

        # --- Preset row ---
        preset_row = tk.Frame(panel, bg=CARD_BG)
        preset_row.pack(fill="x", pady=(0, 4))

        tk.Label(preset_row, text="Preset", font=(FF, 8), bg=CARD_BG,
                 fg=FG3, width=8, anchor="w").pack(side="left")

        sound_var = tk.StringVar(value=current_profile)
        preset_menu = tk.OptionMenu(preset_row, sound_var, *SOUND_PRESETS)
        preset_menu.configure(bg=CARD_BG, fg=FG2, activebackground=SEL_BG,
                              activeforeground=FG, relief="flat",
                              font=(FF, 8), highlightthickness=0)
        preset_menu["menu"].configure(bg=CARD_BG, fg=FG2, font=(FF, 8))
        preset_menu.pack(side="left", padx=(4, 0))

        def on_sound_preset(*_, _cid=cid, var=sound_var):
            self._set_custom(_cid, "sound_override", var.get())
            self._set_custom(_cid, "sound_file", "")
            file_lbl.configure(text="")

        sound_var.trace_add("write", on_sound_preset)

        def preview_preset():
            if self._sound_manager:
                self._sound_manager.play_preview(sound_var.get())

        tk.Button(preset_row, text="▶",
                  command=preview_preset,
                  bg=CARD_BG, fg=ACCENT2,
                  activebackground=SEL_BG, activeforeground=FG,
                  relief="flat", font=(FF, 8), cursor="hand2",
                  padx=6, pady=2).pack(side="left", padx=(4, 0))

        # --- File upload row ---
        file_row = tk.Frame(panel, bg=CARD_BG)
        file_row.pack(fill="x", pady=(0, 4))

        tk.Label(file_row, text="File", font=(FF, 8), bg=CARD_BG,
                 fg=FG3, width=8, anchor="w").pack(side="left")

        short_name = Path(current_file).name if current_file else ""
        file_lbl = tk.Label(file_row, text=short_name, font=(FF, 8), bg=CARD_BG,
                            fg=FG2, anchor="w")
        file_lbl.pack(side="left", padx=(4, 0), fill="x", expand=True)

        def upload_sound(_cid=cid):
            path = filedialog.askopenfilename(
                title="Choose a sound file",
                filetypes=[("Audio files", "*.wav *.mp3"), ("All files", "*.*")]
            )
            if not path:
                return
            # Copy to critter data dir
            import shutil
            dest_dir = get_custom_dir() / _cid
            dest_path = dest_dir / "sound.wav"
            try:
                shutil.copy2(path, str(dest_path))
            except Exception as e:
                messagebox.showerror("Upload failed", str(e))
                return
            stored = str(dest_path)
            self._set_custom(_cid, "sound_file", stored)
            file_lbl.configure(text=Path(path).name)

        def remove_sound(_cid=cid):
            self._set_custom(_cid, "sound_file", "")
            file_lbl.configure(text="")

        def preview_file():
            sf = self._config.get("custom_animals", {}).get(cid, {}).get("sound_file", "")
            if sf and self._sound_manager:
                self._sound_manager.play_preview(sf)

        tk.Button(file_row, text="Upload",
                  command=upload_sound,
                  bg=CARD_BG, fg=FG2,
                  activebackground=SEL_BG, activeforeground=FG,
                  relief="flat", font=(FF, 8), cursor="hand2",
                  padx=6, pady=2).pack(side="right")

        tk.Button(file_row, text="▶",
                  command=preview_file,
                  bg=CARD_BG, fg=ACCENT2,
                  activebackground=SEL_BG, activeforeground=FG,
                  relief="flat", font=(FF, 8), cursor="hand2",
                  padx=6, pady=2).pack(side="right", padx=(0, 4))

        tk.Button(file_row, text="✕",
                  command=remove_sound,
                  bg=CARD_BG, fg=RED,
                  activebackground="#2a1010", activeforeground=RED,
                  relief="flat", font=(FF, 8), cursor="hand2",
                  padx=4, pady=2).pack(side="right", padx=(0, 2))

    # ── Custom critter preview helpers ───────────────────────────────────────

    def _load_custom_thumb(self, cid: str) -> "ImageTk.PhotoImage | None":
        thumb_path = get_custom_dir() / cid / "thumb.png"
        if not thumb_path.exists():
            return None
        try:
            img = Image.open(str(thumb_path)).convert("RGBA")
            img = img.resize((_PREVIEW_SIZE, _PREVIEW_SIZE), Image.LANCZOS)
            bg  = Image.new("RGBA", img.size, (_CARD_RGB[0], _CARD_RGB[1], _CARD_RGB[2], 255))
            bg.paste(img, mask=img.split()[3])
            photo = ImageTk.PhotoImage(bg.convert("RGB"))
            return photo
        except Exception:
            return None

    def _load_custom_anim_frames(self, cid: str) -> list:
        """Load all stored animation frames for a custom critter as PhotoImage list."""
        frames_path = get_custom_dir() / cid / "frames"
        images = []
        for i in range(8):
            p = frames_path / f"frame_{i}.png"
            if not p.exists():
                break
            try:
                img = Image.open(str(p)).convert("RGBA")
                img = img.resize((_PREVIEW_SIZE, _PREVIEW_SIZE), Image.LANCZOS)
                bg  = Image.new("RGBA", img.size, (_CARD_RGB[0], _CARD_RGB[1], _CARD_RGB[2], 255))
                bg.paste(img, mask=img.split()[3])
                images.append(ImageTk.PhotoImage(bg.convert("RGB")))
            except Exception:
                break
        return images

    def _bind_custom_hover(self, label: tk.Label, cid: str,
                           static_photo: "ImageTk.PhotoImage | None") -> None:
        """Start animation on Enter, revert to static on Leave."""
        hover_state = {"jobs": [], "frames": None}

        def on_enter(e):
            if hover_state["frames"] is None:
                frames = self._load_custom_anim_frames(cid)
                hover_state["frames"] = frames if len(frames) >= 2 else []
            if not hover_state["frames"]:
                return
            self._start_anim_on(label, hover_state["frames"], hover_state["jobs"])

        def on_leave(e):
            for job in hover_state["jobs"]:
                try:
                    self._root.after_cancel(job)
                except Exception:
                    pass
            hover_state["jobs"].clear()
            if static_photo:
                try:
                    label.configure(image=static_photo)
                except tk.TclError:
                    pass

        label.bind("<Enter>", on_enter)
        label.bind("<Leave>", on_leave)

    def _start_anim_on(self, label: tk.Label, frames: list, job_list: list) -> None:
        """Cycle frames on label, tracking job IDs in job_list."""
        if not frames or len(frames) < 2:
            return
        delay = 1000 // _ANIM_FPS
        state = [0]

        def tick():
            if not self._root:
                return
            try:
                state[0] = (state[0] + 1) % len(frames)
                label.configure(image=frames[state[0]])
                job = self._root.after(delay, tick)
                job_list.append(job)
            except tk.TclError:
                pass

        job = self._root.after(delay, tick)
        job_list.append(job)

    # ── Import: single image ─────────────────────────────────────────────────

    def _import_dialog(self, parent_inner: tk.Frame) -> None:
        """Modal dialog to import a single image as a new custom critter."""
        path = filedialog.askopenfilename(
            title="Choose an image",
            filetypes=[
                ("Supported images", "*.png *.jpg *.jpeg *.gif"),
                ("PNG", "*.png"), ("JPEG", "*.jpg *.jpeg"), ("GIF", "*.gif"),
            ],
        )
        if not path:
            return

        default_name = Path(path).stem.replace("_", " ").replace("-", " ").title()

        dlg = tk.Toplevel(self._root)
        dlg.title("Import critter")
        dlg.configure(bg=CONTENT_BG)
        dlg.resizable(False, False)
        dlg.grab_set()

        w, h = 420, 200
        sw, sh = dlg.winfo_screenwidth(), dlg.winfo_screenheight()
        dlg.geometry(f"{w}x{h}+{(sw-w)//2}+{(sh-h)//2}")

        tk.Label(dlg, text="Name your critter",
                 font=(FF, 13, "bold"), bg=CONTENT_BG, fg=FG).pack(anchor="w", padx=24, pady=(20, 4))
        tk.Label(dlg, text=Path(path).name,
                 font=(FF, 8), bg=CONTENT_BG, fg=FG3).pack(anchor="w", padx=24)

        name_var = tk.StringVar(value=default_name)
        entry = tk.Entry(dlg, textvariable=name_var,
                         font=(FF, 11), bg=CARD_BG, fg=FG,
                         insertbackground=FG, relief="flat", bd=0)
        entry.pack(fill="x", padx=24, pady=(10, 0), ipady=8)
        entry.select_range(0, "end")
        entry.focus_set()

        status_lbl = tk.Label(dlg, text="", font=(FF, 8),
                              bg=CONTENT_BG, fg=AMBER, wraplength=370, justify="left")
        status_lbl.pack(anchor="w", padx=24, pady=(6, 0))

        btn_row = tk.Frame(dlg, bg=CONTENT_BG)
        btn_row.pack(fill="x", padx=24, pady=(12, 0))

        def do_import():
            name = name_var.get().strip()
            if not name:
                status_lbl.configure(text="Please enter a name.", fg=RED)
                return
            import_btn.configure(state="disabled", text="Generating preview…")
            dlg.update()

            def run_prepare():
                try:
                    pil_frames, method = prepare_frames(path)
                    dlg.after(0, lambda: show_preview(pil_frames, method, name))
                except ImportError as err:
                    dlg.after(0, lambda e=err: (
                        status_lbl.configure(text=str(e), fg=RED),
                        import_btn.configure(state="normal", text="Import"),
                    ))
                except Exception as err:
                    dlg.after(0, lambda e=err: (
                        status_lbl.configure(text=f"Unexpected error: {e}", fg=RED),
                        import_btn.configure(state="normal", text="Import"),
                    ))

            def show_preview(pil_frames, method, name):
                dlg.destroy()
                self._show_import_preview(
                    pil_frames, method, name,
                    on_accept=lambda frames, meth, n: (
                        self._commit_prepared_import(frames, meth, n),
                        self._show_page("critters"),
                    ),
                )

            threading.Thread(target=run_prepare, daemon=True).start()

        import_btn = tk.Button(btn_row, text="Import",
                               command=do_import,
                               bg="#1a0f35", fg=ACCENT,
                               activebackground="#23154a", activeforeground=ACCENT,
                               relief="flat", font=(FF, 10, "bold"),
                               cursor="hand2", padx=16, pady=8)
        import_btn.pack(side="left")

        tk.Button(btn_row, text="Cancel",
                  command=dlg.destroy,
                  bg=CARD_BG, fg=FG2,
                  activebackground=CARD_HOV, activeforeground=FG,
                  relief="flat", font=(FF, 9),
                  cursor="hand2", padx=12, pady=8).pack(side="left", padx=(8, 0))

        entry.bind("<Return>", lambda e: do_import())

    # ── Import: animation frames ──────────────────────────────────────────────

    def _import_frames_dialog(self, parent_inner: tk.Frame) -> None:
        """Modal dialog to import 2–8 hand-drawn PNG frames."""
        dlg = tk.Toplevel(self._root)
        dlg.title("Import animation frames")
        dlg.configure(bg=CONTENT_BG)
        dlg.resizable(True, False)
        dlg.grab_set()

        w, h = 620, 460
        sw, sh = dlg.winfo_screenwidth(), dlg.winfo_screenheight()
        dlg.geometry(f"{w}x{h}+{(sw-w)//2}+{(sh-h)//2}")

        # State
        paths = []           # list of Path
        thumb_photos = []    # list of ImageTk.PhotoImage (kept alive)
        transp_flags = []    # list of bool — True = already transparent
        preview_frames = []  # list of ImageTk.PhotoImage for the preview strip

        # ── Header ──
        tk.Label(dlg, text="Import animation frames",
                 font=(FF, 13, "bold"), bg=CONTENT_BG, fg=FG).pack(anchor="w", padx=24, pady=(18, 2))
        tk.Label(dlg,
                 text="Upload 2–8 PNG frames in walk-cycle order. Transparent PNGs are used as-is;\n"
                      "opaque images will have their background removed automatically.",
                 font=(FF, 8), bg=CONTENT_BG, fg=FG2, justify="left").pack(anchor="w", padx=24, pady=(0, 10))

        # ── Frame strip ──
        strip_outer = tk.Frame(dlg, bg=CARD_BG, height=140)
        strip_outer.pack(fill="x", padx=24, pady=(0, 10))
        strip_outer.pack_propagate(False)

        strip_canvas = tk.Canvas(strip_outer, bg=CARD_BG, highlightthickness=0, height=140)
        strip_scroll = tk.Scrollbar(strip_outer, orient="horizontal",
                                    command=strip_canvas.xview,
                                    bg=CARD_BG, troughcolor=CARD_BG,
                                    relief="flat", bd=0, width=6)
        strip_canvas.configure(xscrollcommand=strip_scroll.set)
        strip_scroll.pack(side="bottom", fill="x")
        strip_canvas.pack(side="left", fill="both", expand=True)

        strip_inner = tk.Frame(strip_canvas, bg=CARD_BG)
        strip_win = strip_canvas.create_window((0, 0), window=strip_inner, anchor="nw")

        def _update_strip_scroll(e=None):
            strip_canvas.configure(scrollregion=strip_canvas.bbox("all"))
            strip_canvas.itemconfig(strip_win, height=strip_canvas.winfo_height())

        strip_inner.bind("<Configure>", _update_strip_scroll)

        # ── Name field ──
        name_row = tk.Frame(dlg, bg=CONTENT_BG)
        name_row.pack(fill="x", padx=24, pady=(0, 8))
        tk.Label(name_row, text="Name", font=(FF, 9), bg=CONTENT_BG, fg=FG3).pack(side="left", padx=(0, 8))
        name_var = tk.StringVar()
        name_entry = tk.Entry(name_row, textvariable=name_var,
                              font=(FF, 10), bg=CARD_BG, fg=FG,
                              insertbackground=FG, relief="flat", bd=0)
        name_entry.pack(side="left", fill="x", expand=True, ipady=6)

        # ── Status / error label ──
        status_lbl = tk.Label(dlg, text="", font=(FF, 8),
                              bg=CONTENT_BG, fg=AMBER, wraplength=570, justify="left")
        status_lbl.pack(anchor="w", padx=24, pady=(0, 4))

        # ── Bottom buttons ──
        bot_row = tk.Frame(dlg, bg=CONTENT_BG)
        bot_row.pack(fill="x", padx=24, pady=(4, 18))

        add_btn = tk.Button(bot_row, text="＋ Add frame",
                            bg=CARD_BG, fg=ACCENT2,
                            activebackground=SEL_BG, activeforeground=FG,
                            relief="flat", font=(FF, 9, "bold"),
                            cursor="hand2", padx=10, pady=6)
        add_btn.pack(side="left")

        import_btn = tk.Button(bot_row, text="Import",
                               bg="#1a0f35", fg=ACCENT,
                               activebackground="#23154a", activeforeground=ACCENT,
                               relief="flat", font=(FF, 10, "bold"),
                               cursor="hand2", padx=16, pady=8,
                               state="disabled")
        import_btn.pack(side="right")

        tk.Button(bot_row, text="Cancel",
                  command=dlg.destroy,
                  bg=CARD_BG, fg=FG2,
                  activebackground=CARD_HOV, activeforeground=FG,
                  relief="flat", font=(FF, 9),
                  cursor="hand2", padx=12, pady=8).pack(side="right", padx=(0, 8))

        # ── Strip rebuild ──
        def _rebuild_strip():
            for w in strip_inner.winfo_children():
                w.destroy()
            thumb_photos.clear()
            preview_frames.clear()

            for idx, (p, transp) in enumerate(zip(paths, transp_flags)):
                col = tk.Frame(strip_inner, bg=CARD_BG, padx=4, pady=6)
                col.pack(side="left")

                # Thumbnail
                try:
                    img = Image.open(str(p)).convert("RGBA")
                    img.thumbnail((80, 80), Image.LANCZOS)
                    bg_img = Image.new("RGBA", (80, 80), (_CARD_RGB[0], _CARD_RGB[1], _CARD_RGB[2], 255))
                    ox = (80 - img.width) // 2
                    oy = (80 - img.height) // 2
                    bg_img.paste(img, (ox, oy), img)
                    photo = ImageTk.PhotoImage(bg_img.convert("RGB"))
                    thumb_photos.append(photo)
                    preview_frames.append(photo)
                except Exception:
                    photo = None

                frame_lbl = tk.Label(col, image=photo if photo else None,
                                     text="" if photo else "?",
                                     bg=CARD_BG, width=80, height=80)
                if photo:
                    frame_lbl.image = photo
                frame_lbl.pack()

                # Transparency badge
                badge_text = "✓ transparent" if transp else "⚠ bg-remove"
                badge_fg   = "#4ade80" if transp else AMBER
                tk.Label(col, text=badge_text, font=(FF, 7), bg=CARD_BG, fg=badge_fg).pack()

                # Reorder + remove buttons
                ctrl = tk.Frame(col, bg=CARD_BG)
                ctrl.pack()

                def make_left(i=idx):
                    def go():
                        if i > 0:
                            paths[i-1], paths[i] = paths[i], paths[i-1]
                            transp_flags[i-1], transp_flags[i] = transp_flags[i], transp_flags[i-1]
                            _rebuild_strip()
                            _update_import_btn()
                    return go

                def make_right(i=idx):
                    def go():
                        if i < len(paths) - 1:
                            paths[i+1], paths[i] = paths[i], paths[i+1]
                            transp_flags[i+1], transp_flags[i] = transp_flags[i], transp_flags[i+1]
                            _rebuild_strip()
                            _update_import_btn()
                    return go

                def make_remove(i=idx):
                    def go():
                        paths.pop(i)
                        transp_flags.pop(i)
                        _rebuild_strip()
                        _update_import_btn()
                    return go

                for text, cmd, fg_col in [
                    ("←", make_left(idx),   FG2),
                    ("→", make_right(idx),  FG2),
                    ("✕", make_remove(idx), RED),
                ]:
                    tk.Button(ctrl, text=text, command=cmd,
                              bg=CARD_BG, fg=fg_col,
                              activebackground=SEL_BG, activeforeground=FG,
                              relief="flat", font=(FF, 8),
                              cursor="hand2", padx=4, pady=2).pack(side="left")

            strip_canvas.after_idle(_update_strip_scroll)

        def _update_import_btn():
            ok = 2 <= len(paths) <= 8
            import_btn.configure(state="normal" if ok else "disabled")
            if len(paths) == 0:
                status_lbl.configure(text="Add 2–8 frames to continue.", fg=FG3)
            elif len(paths) == 1:
                status_lbl.configure(text="Add at least one more frame.", fg=AMBER)
            elif len(paths) > 8:
                status_lbl.configure(text="Maximum 8 frames.", fg=RED)
            else:
                status_lbl.configure(text=f"{len(paths)} frames ready.", fg=FG3)

        def _check_transparency(path: Path) -> bool:
            """Return True if the image already has meaningful transparency."""
            import numpy as np
            try:
                img = Image.open(str(path))
                if img.mode != "RGBA" and "transparency" not in img.info:
                    return False
                rgba = img.convert("RGBA")
                alpha = np.array(rgba)[:, :, 3]
                return float((alpha < 255).sum()) / alpha.size > 0.01
            except Exception:
                return False

        def _add_files(file_paths):
            for fp in file_paths:
                p = Path(fp)
                ext = p.suffix.lower()
                if ext not in (".png", ".jpg", ".jpeg"):
                    status_lbl.configure(
                        text=f"{p.name} skipped — use PNG or JPG frames only.", fg=AMBER)
                    continue
                if len(paths) >= 8:
                    status_lbl.configure(text="Maximum 8 frames reached.", fg=AMBER)
                    break
                transp = _check_transparency(p)
                paths.append(p)
                transp_flags.append(transp)
            _rebuild_strip()
            _update_import_btn()

        def on_add():
            chosen = filedialog.askopenfilenames(
                title="Choose frame images",
                filetypes=[("Images", "*.png *.jpg *.jpeg"), ("PNG", "*.png"), ("JPEG", "*.jpg *.jpeg")],
                parent=dlg,
            )
            if chosen:
                _add_files(chosen)
                if not name_var.get().strip() and chosen:
                    default = Path(chosen[0]).stem.replace("_", " ").replace("-", " ").title()
                    name_var.set(default)
                    name_entry.select_range(0, "end")

        add_btn.configure(command=on_add)

        def do_import():
            name = name_var.get().strip()
            if not name:
                status_lbl.configure(text="Please enter a name.", fg=RED)
                return
            if not (2 <= len(paths) <= 8):
                return
            import_btn.configure(state="disabled", text="Importing…")
            dlg.update()
            try:
                critter_id = run_import_frames(paths, name, get_custom_dir())
            except ImportError as err:
                status_lbl.configure(text=str(err), fg=RED)
                import_btn.configure(state="normal", text="Import")
                return
            except Exception as err:
                status_lbl.configure(text=f"Unexpected error: {err}", fg=RED)
                import_btn.configure(state="normal", text="Import")
                return
            self._finish_import(critter_id)
            dlg.destroy()
            self._show_page("critters")

        import_btn.configure(command=do_import)
        name_entry.bind("<Return>", lambda e: do_import())

        # Initialise strip with empty state hint
        _update_import_btn()

    # ── Sharing: export ───────────────────────────────────────────────────────

    def _export_critter(self, critter_id: str) -> None:
        record = self._registry.get(critter_id)
        name   = record.meta.get("name", critter_id) if record else critter_id
        safe   = "".join(c for c in name if c.isalnum() or c in " _-").strip()
        dest   = filedialog.asksaveasfilename(
            title        = "Export critter",
            defaultextension = ".critter",
            initialfile  = f"{safe or critter_id}.critter",
            filetypes    = [(".critter packages", "*.critter"), ("All files", "*")],
            parent       = self._root,
        )
        if not dest:
            return
        try:
            export_critter(critter_id, Path(dest))
            messagebox.showinfo("Exported", f"Saved to:\n{dest}", parent=self._root)
        except Exception as e:
            messagebox.showerror("Export failed", str(e), parent=self._root)

    def _bulk_export(self) -> None:
        dest_dir = filedialog.askdirectory(
            title="Choose export folder",
            parent=self._root,
        )
        if not dest_dir:
            return
        try:
            written = bulk_export(dest_dir=Path(dest_dir))
        except Exception as e:
            messagebox.showerror("Export failed", str(e), parent=self._root)
            return
        if written:
            names = "\n".join(p.name for p in written)
            messagebox.showinfo(
                "Exported",
                f"Exported {len(written)} critter(s) to:\n{dest_dir}\n\n{names}",
                parent=self._root,
            )
        else:
            messagebox.showinfo(
                "Nothing to export",
                "No custom critters found.",
                parent=self._root,
            )

    # ── Sharing: .critter import ──────────────────────────────────────────────

    def _import_critter_file(self) -> None:
        path = filedialog.askopenfilename(
            title     = "Import .critter package",
            filetypes = [(".critter packages", "*.critter"), ("All files", "*")],
            parent    = self._root,
        )
        if not path:
            return
        self._import_flow(path)

    def _import_flow(self, path: str) -> None:
        """Route a dropped or opened file to the right import handler."""
        p = Path(path)
        if p.suffix.lower() == ".critter":
            self._import_critter_package_flow(p)
        else:
            self._import_dialog_with_path(str(p))

    def _import_critter_package_flow(self, zip_path: Path) -> None:
        try:
            meta = read_package_meta(zip_path)
        except ValueError as e:
            messagebox.showerror("Invalid package", str(e), parent=self._root)
            return
        self._show_import_confirm(meta, zip_path)

    def _show_import_confirm(self, meta: dict, zip_path: Path) -> None:
        """Confirm dialog shown before committing a .critter import."""
        dlg = tk.Toplevel(self._root)
        dlg.title("Install critter?")
        dlg.configure(bg=CONTENT_BG)
        dlg.resizable(False, False)
        dlg.grab_set()
        w, h = 440, 260
        sw, sh = dlg.winfo_screenwidth(), dlg.winfo_screenheight()
        dlg.geometry(f"{w}x{h}+{(sw-w)//2}+{(sh-h)//2}")

        tk.Label(dlg, text="Install critter?",
                 font=(FF, 14, "bold"), bg=CONTENT_BG, fg=FG
                 ).pack(anchor="w", padx=24, pady=(20, 4))

        info_frame = tk.Frame(dlg, bg=CARD_BG, padx=16, pady=12)
        info_frame.pack(fill="x", padx=24, pady=(0, 12))

        for label, key, fallback in [
            ("Name",    "name",    "—"),
            ("Author",  "author",  "anonymous"),
            ("License", "license", "unknown"),
        ]:
            row = tk.Frame(info_frame, bg=CARD_BG)
            row.pack(fill="x", pady=2)
            tk.Label(row, text=f"{label}:", font=(FF, 8), bg=CARD_BG,
                     fg=FG3, width=8, anchor="w").pack(side="left")
            tk.Label(row, text=meta.get(key, fallback),
                     font=(FF, 9, "bold"), bg=CARD_BG, fg=FG,
                     anchor="w").pack(side="left")

        status_lbl = tk.Label(dlg, text="", font=(FF, 8),
                              bg=CONTENT_BG, fg=RED, wraplength=390)
        status_lbl.pack(anchor="w", padx=24)

        btn_row = tk.Frame(dlg, bg=CONTENT_BG)
        btn_row.pack(fill="x", padx=24, pady=(4, 0))

        def do_install():
            install_btn.configure(state="disabled", text="Installing…")
            dlg.update()
            try:
                critter_id = import_critter_package(zip_path)
            except ValueError as e:
                status_lbl.configure(text=str(e))
                install_btn.configure(state="normal", text="Install")
                return
            except Exception as e:
                status_lbl.configure(text=f"Unexpected error: {e}")
                install_btn.configure(state="normal", text="Install")
                return
            self._finish_import(critter_id)
            dlg.destroy()
            self._show_page("critters")

        install_btn = tk.Button(btn_row, text="Install",
                                command=do_install,
                                bg="#1a0f35", fg=ACCENT,
                                activebackground="#23154a", activeforeground=ACCENT,
                                relief="flat", font=(FF, 10, "bold"),
                                cursor="hand2", padx=16, pady=8)
        install_btn.pack(side="left")

        tk.Button(btn_row, text="Cancel", command=dlg.destroy,
                  bg=CARD_BG, fg=FG2,
                  activebackground=CARD_HOV, activeforeground=FG,
                  relief="flat", font=(FF, 9),
                  cursor="hand2", padx=12, pady=8).pack(side="left", padx=(8, 0))

    # ── Preview-before-commit ─────────────────────────────────────────────────

    def _import_dialog_with_path(self, path: str) -> None:
        """Open the name dialog pre-filled with the given path (used by drag-drop)."""
        default_name = Path(path).stem.replace("_", " ").replace("-", " ").title()

        dlg = tk.Toplevel(self._root)
        dlg.title("Import critter")
        dlg.configure(bg=CONTENT_BG)
        dlg.resizable(False, False)
        dlg.grab_set()
        w, h = 420, 200
        sw, sh = dlg.winfo_screenwidth(), dlg.winfo_screenheight()
        dlg.geometry(f"{w}x{h}+{(sw-w)//2}+{(sh-h)//2}")

        tk.Label(dlg, text="Name your critter",
                 font=(FF, 13, "bold"), bg=CONTENT_BG, fg=FG).pack(anchor="w", padx=24, pady=(20, 4))
        tk.Label(dlg, text=Path(path).name,
                 font=(FF, 8), bg=CONTENT_BG, fg=FG3).pack(anchor="w", padx=24)

        name_var = tk.StringVar(value=default_name)
        entry = tk.Entry(dlg, textvariable=name_var,
                         font=(FF, 11), bg=CARD_BG, fg=FG,
                         insertbackground=FG, relief="flat", bd=0)
        entry.pack(fill="x", padx=24, pady=(10, 0), ipady=8)
        entry.select_range(0, "end")
        entry.focus_set()

        status_lbl = tk.Label(dlg, text="", font=(FF, 8),
                              bg=CONTENT_BG, fg=AMBER, wraplength=370, justify="left")
        status_lbl.pack(anchor="w", padx=24, pady=(6, 0))

        btn_row = tk.Frame(dlg, bg=CONTENT_BG)
        btn_row.pack(fill="x", padx=24, pady=(12, 0))

        def do_import():
            name = name_var.get().strip()
            if not name:
                status_lbl.configure(text="Please enter a name.", fg=RED)
                return
            import_btn.configure(state="disabled", text="Generating preview…")
            dlg.update()

            def run_prepare():
                try:
                    pil_frames, method = prepare_frames(path)
                    dlg.after(0, lambda: _show(pil_frames, method, name))
                except ImportError as err:
                    dlg.after(0, lambda e=err: (
                        status_lbl.configure(text=str(e), fg=RED),
                        import_btn.configure(state="normal", text="Import"),
                    ))
                except Exception as err:
                    dlg.after(0, lambda e=err: (
                        status_lbl.configure(text=f"Unexpected error: {e}", fg=RED),
                        import_btn.configure(state="normal", text="Import"),
                    ))

            def _show(pil_frames, method, name):
                dlg.destroy()
                self._show_import_preview(
                    pil_frames, method, name,
                    on_accept=lambda frames, meth, n: (
                        self._commit_prepared_import(frames, meth, n),
                        self._show_page("critters"),
                    ),
                )

            threading.Thread(target=run_prepare, daemon=True).start()

        import_btn = tk.Button(btn_row, text="Import", command=do_import,
                               bg="#1a0f35", fg=ACCENT,
                               activebackground="#23154a", activeforeground=ACCENT,
                               relief="flat", font=(FF, 10, "bold"),
                               cursor="hand2", padx=16, pady=8)
        import_btn.pack(side="left")
        tk.Button(btn_row, text="Cancel", command=dlg.destroy,
                  bg=CARD_BG, fg=FG2,
                  activebackground=CARD_HOV, activeforeground=FG,
                  relief="flat", font=(FF, 9),
                  cursor="hand2", padx=12, pady=8).pack(side="left", padx=(8, 0))
        entry.bind("<Return>", lambda e: do_import())

    def _show_import_preview(self, pil_frames: list, method: str, name: str,
                             on_accept) -> None:
        """
        Modal showing an animated preview of the critter before committing to disk.
        on_accept(pil_frames, method, name) called if user clicks Accept.
        """
        dlg = tk.Toplevel(self._root)
        dlg.title("Preview")
        dlg.configure(bg=CONTENT_BG)
        dlg.resizable(False, False)
        dlg.grab_set()
        w, h = 320, 340
        sw, sh = dlg.winfo_screenwidth(), dlg.winfo_screenheight()
        dlg.geometry(f"{w}x{h}+{(sw-w)//2}+{(sh-h)//2}")

        tk.Label(dlg, text=f"Preview: {name}",
                 font=(FF, 12, "bold"), bg=CONTENT_BG, fg=FG
                 ).pack(pady=(16, 4))

        canvas_size = 180
        canvas = tk.Canvas(dlg, width=canvas_size, height=canvas_size,
                           bg=CARD_BG, highlightthickness=0)
        canvas.pack(pady=(0, 8))

        # Convert PIL frames to PhotoImages (must happen in tkinter thread)
        photos: list[ImageTk.PhotoImage] = []
        for frame in pil_frames:
            img = frame.copy().resize((canvas_size, canvas_size), Image.NEAREST)
            photos.append(ImageTk.PhotoImage(img))

        frame_idx = [0]
        anim_job  = [None]

        def animate():
            if not dlg.winfo_exists():
                return
            canvas.delete("all")
            canvas.create_image(canvas_size // 2, canvas_size // 2,
                                anchor="center", image=photos[frame_idx[0]])
            frame_idx[0] = (frame_idx[0] + 1) % len(photos)
            anim_job[0] = dlg.after(120, animate)

        animate()

        badge = {
            "static_png":   "procedural animation",
            "static_jpg":   "procedural animation",
            "animated_gif": "animated gif",
            "frame_strip":  "drawn frames",
        }.get(method, method)
        tk.Label(dlg, text=f"{len(pil_frames)} frames  ·  {badge}",
                 font=(FF, 8), bg=CONTENT_BG, fg=FG3).pack()

        btn_row = tk.Frame(dlg, bg=CONTENT_BG)
        btn_row.pack(pady=(12, 0))

        def do_accept():
            if anim_job[0]:
                dlg.after_cancel(anim_job[0])
            dlg.destroy()
            on_accept(pil_frames, method, name)

        tk.Button(btn_row, text="✓  Add critter", command=do_accept,
                  bg="#1a0f35", fg=ACCENT,
                  activebackground="#23154a", activeforeground=ACCENT,
                  relief="flat", font=(FF, 10, "bold"),
                  cursor="hand2", padx=16, pady=8).pack(side="left")

        def do_cancel():
            if anim_job[0]:
                dlg.after_cancel(anim_job[0])
            dlg.destroy()

        tk.Button(btn_row, text="Cancel", command=do_cancel,
                  bg=CARD_BG, fg=FG2,
                  activebackground=CARD_HOV, activeforeground=FG,
                  relief="flat", font=(FF, 9),
                  cursor="hand2", padx=12, pady=8).pack(side="left", padx=(8, 0))

    def _commit_prepared_import(self, pil_frames: list, method: str, name: str) -> None:
        try:
            critter_id = run_import_from_prepared(
                pil_frames, method, name, get_custom_dir()
            )
            self._finish_import(critter_id)
        except Exception as e:
            messagebox.showerror("Import failed", str(e), parent=self._root)

    def _finish_import(self, critter_id: str) -> None:
        """Register a newly imported critter in config and reload the registry."""
        if "custom_animals" not in self._config:
            self._config["custom_animals"] = {}
        self._config["custom_animals"][critter_id] = {
            "enabled": True, "weight": 1.0,
            "sound_override": None, "sound_file": "", "sound": True,
            "size_override": None,
        }
        save_config(self._config)
        self._registry.reload()
        self._on_save(self._config)

    def _delete_custom(self, critter_id: str) -> None:
        name = self._registry.get(critter_id)
        display = name.meta.get("name", critter_id) if name else critter_id
        ok = messagebox.askyesno(
            "Delete critter",
            f"Delete \"{display}\"?\n\nThis cannot be undone.",
            icon="warning",
            parent=self._root,
        )
        if not ok:
            return
        delete_critter_folder(get_custom_dir(), critter_id)
        self._registry.remove(critter_id)
        self._config.get("custom_animals", {}).pop(critter_id, None)
        save_config(self._config)
        self._on_save(self._config)
        self._show_page("critters")

    def _set_custom(self, critter_id: str, key: str, value) -> None:
        if "custom_animals" not in self._config:
            self._config["custom_animals"] = {}
        if critter_id not in self._config["custom_animals"]:
            self._config["custom_animals"][critter_id] = {}
        self._config["custom_animals"][critter_id][key] = value
        save_config(self._config)
        self._on_save(self._config)

    # ── Page: Behaviour ───────────────────────────────────────────────────────

    def _page_behaviour(self, parent: tk.Frame) -> None:
        self._page_header(parent, "Behaviour",
                          "Spawning rates, living-world activity, and rarity settings.")
        _, inner = self._scrollable(parent)

        # ── Spawning ──
        self._section_label(inner, "Spawning")

        self._setting_slider(inner,
            label="Spawn frequency",
            desc="A new group arrives every N minutes (±15 % jitter)",
            section="spawn", key="primary_interval_min",
            from_=1, to=60, res=1, unit=" min")

        self._setting_slider(inner,
            label="Min animals per spawn",
            desc="Fewest critters in a single group",
            section="spawn", key="primary_count_min",
            from_=1, to=15, res=1)

        self._setting_slider(inner,
            label="Max animals per spawn",
            desc="Most critters in a single group",
            section="spawn", key="primary_count_max",
            from_=1, to=25, res=1)

        self._section_label(inner, "Solo perimeter walker")

        self._setting_toggle(inner,
            label="Enable solo walkers",
            desc="A lone animal traces the edge of your screen between group spawns",
            section="spawn", key="solo_enabled")

        self._setting_slider(inner,
            label="Solo frequency",
            desc="One solo walker every N minutes",
            section="spawn", key="solo_interval_min",
            from_=1, to=60, res=1, unit=" min")

        # ── Living world ──
        self._section_label(inner, "Living world")

        self._setting_toggle(inner,
            label="Day / night cycle",
            desc="Activity slows at night and speeds up in the morning — felt through behaviour, never visual tint",
            section="behaviour", key="day_night_enabled")

        self._setting_slider(inner,
            label="Behaviour frequency",
            desc="How often critters stop to stretch, groom, interact, or nap  (0.3 = rarely, 2.0 = constantly)",
            section="behaviour", key="behaviour_frequency",
            from_=0.3, to=2.0, res=0.1, unit="×")

        self._setting_toggle(inner,
            label="Pair interactions",
            desc="Allow two critters nearby to sniff, follow, play, or groom each other",
            section="behaviour", key="interactions_enabled")

        # ── Rarity ──
        self._section_label(inner, "Rarity")

        self._setting_toggle(inner,
            label="Enable rarity tiers",
            desc="Spawned critters roll a hidden tier (Common → Legendary) that shows as a subtle aura and trail",
            section="rarity", key="enabled")

        # Tier distribution sliders
        dist_card = tk.Frame(inner, bg=CARD_BG, padx=18, pady=14)
        dist_card.pack(fill="x", pady=(0, 8))
        tk.Label(dist_card, text="Tier distribution", font=(FF, 10, "bold"),
                 bg=CARD_BG, fg=FG).pack(anchor="w")
        tk.Label(dist_card, text="Percentage chance for each rarity tier per spawn  "
                                 "(values are relative weights — they don't need to sum to 100)",
                 font=(FF, 8), bg=CARD_BG, fg=FG3, wraplength=440,
                 justify="left").pack(anchor="w", pady=(2, 8))

        _TIERS = [
            ("common",    "Common",    0.90),
            ("uncommon",  "Uncommon",  0.07),
            ("rare",      "Rare",      0.02),
            ("epic",      "Epic",      0.009),
            ("legendary", "Legendary", 0.001),
        ]
        dist = self._config["rarity"]["distribution"]
        for tier_key, tier_label, tier_default in _TIERS:
            row = tk.Frame(dist_card, bg=CARD_BG)
            row.pack(fill="x", pady=(0, 4))
            tk.Label(row, text=tier_label, font=(FF, 8), bg=CARD_BG, fg=FG3,
                     width=10, anchor="w").pack(side="left")
            cur = dist.get(tier_key, tier_default)
            val_lbl = tk.Label(row, text=f"{cur*100:.1f}%",
                               font=(FF, 8, "bold"), bg=CARD_BG, fg=ACCENT, width=6)
            val_lbl.pack(side="right")
            var = tk.DoubleVar(value=cur)

            def on_dist(v, tk_=tier_key, lbl=val_lbl):
                fv = round(float(v), 4)
                lbl.configure(text=f"{fv*100:.1f}%")
                self._config["rarity"]["distribution"][tk_] = fv
                save_config(self._config)
                self._on_save(self._config)

            tk.Scale(row, from_=0.0, to=0.5, resolution=0.001,
                     orient="horizontal", variable=var,
                     bg=CARD_BG, fg=FG2, troughcolor=SLIDER_TR,
                     highlightthickness=0, bd=0, showvalue=False,
                     command=on_dist).pack(side="left", fill="x", expand=True, padx=(4, 8))

        # Rare hour
        rh = self._config["rarity"]["rare_hour"]
        self._setting_toggle_fn(inner,
            label="Rare hour",
            desc="Double the odds of Rare+ tiers during a daily one-hour window",
            get_fn=lambda: rh.get("enabled", True),
            set_fn=lambda v: rh.update({"enabled": v}))

        self._setting_slider_fn(inner,
            label="Rare hour start",
            desc="Local hour when rare-hour begins (24-hour clock)",
            get_fn=lambda: rh.get("start_hour", 21),
            set_fn=lambda v: rh.update({"start_hour": int(v)}),
            from_=0, to=23, res=1, unit=":00")

        self._setting_toggle_fn(inner,
            label="First spawn of the day bonus",
            desc="The first critter spawned after midnight is guaranteed Rare or better",
            get_fn=lambda: self._config["rarity"].get("first_spawn_of_day_bonus", True),
            set_fn=lambda v: self._config["rarity"].update({"first_spawn_of_day_bonus": v}))

        self._section_label(inner, "Behaviour")

        self._setting_toggle(inner,
            label="Day / night cycle",
            desc="Critters move slower and nap more at night; more active in the morning",
            section="behaviour", key="day_night_enabled")

        self._setting_toggle(inner,
            label="Pair interactions",
            desc="Two critters near each other may sniff, play, groom, or interact briefly",
            section="behaviour", key="interactions_enabled")

        self._setting_slider(inner,
            label="Behaviour frequency",
            desc="How often critters pause for idle animations and pair interactions",
            section="behaviour", key="behaviour_frequency",
            from_=0.3, to=2.0, res=0.1)

    # ── Page: Audio ───────────────────────────────────────────────────────────

    def _page_audio(self, parent: tk.Frame) -> None:
        self._page_header(parent, "Audio",
                          "Sounds play when you click an animal to pop it.")
        _, inner = self._scrollable(parent)

        self._section_label(inner, "Master")

        self._setting_toggle(inner,
            label="Sound enabled",
            desc="Play a sound effect when animals are popped",
            section="audio", key="sound_enabled")

        self._setting_slider(inner,
            label="Volume",
            desc="Master volume for all pop sounds",
            section="audio", key="volume",
            from_=0, to=100, res=5, unit="%")

        self._section_label(inner, "All species")

        # ── Unified list: built-ins then custom ──
        for species, emoji, name in ANIMALS:
            self._audio_row(inner, name=name, emoji=emoji,
                            small_frames=self._animal_frames_small.get(species),
                            get_sound=lambda s=species: self._config["animals"][s].get("sound", True),
                            set_sound=lambda v, s=species: self._set("animals", s, "sound", v),
                            preview=lambda s=species: (
                                self._sound_manager.play_preview(s)
                                if self._sound_manager else None))

        for record in self._registry.all():
            cid   = record.id
            cname = record.meta.get("name", cid)
            custom_cfg = self._config.get("custom_animals", {}).setdefault(cid, {})
            sound_key  = custom_cfg.get("sound_override") or record.meta.get("sound_profile", "kitten")
            sound_file = custom_cfg.get("sound_file", "")

            def _preview_custom(_cid=cid, _sk=sound_key, _sf=sound_file):
                if not self._sound_manager:
                    return
                _cfg = self._config.get("custom_animals", {}).get(_cid, {})
                sf = _cfg.get("sound_file", "")
                if sf:
                    self._sound_manager.play_preview(sf)
                else:
                    self._sound_manager.play_preview(
                        _cfg.get("sound_override") or _sk)

            self._audio_row(inner, name=cname, emoji="🐾",
                            small_frames=None,
                            get_sound=lambda _cid=cid: self._config.get(
                                "custom_animals", {}).get(_cid, {}).get("sound", True),
                            set_sound=lambda v, _cid=cid: self._set_custom(_cid, "sound", v),
                            preview=_preview_custom)

    def _audio_row(self, parent, name, emoji, small_frames,
                   get_sound, set_sound, preview) -> None:
        """Single row in the unified audio list."""
        cell = tk.Frame(parent, bg=CARD_BG, padx=14, pady=10)
        cell.pack(fill="x", pady=(0, 6))

        if small_frames:
            prev = tk.Label(cell, image=small_frames[0], bg=CARD_BG)
            prev.image = small_frames[0]
            prev.pack(side="left", padx=(0, 8))
            self._start_anim(prev, small_frames)
        else:
            tk.Label(cell, text=emoji, font=(FF, 14),
                     bg=CARD_BG, fg=FG2).pack(side="left", padx=(0, 6))

        tk.Label(cell, text=name,
                 font=(FF, 9, "bold"), bg=CARD_BG, fg=FG).pack(side="left")

        # Preview button
        tk.Button(cell, text="▶",
                  command=preview,
                  bg=CARD_BG, fg=ACCENT2,
                  activebackground=SEL_BG, activeforeground=FG,
                  relief="flat", font=(FF, 8), cursor="hand2",
                  padx=6, pady=2).pack(side="right", padx=(0, 4))

        # Sound toggle
        var = tk.BooleanVar(value=get_sound())
        chk = tk.Checkbutton(cell, variable=var,
                             command=lambda v=var: set_sound(v.get()),
                             bg=CARD_BG, activebackground=CARD_BG,
                             selectcolor=CARD_BG, fg=ACCENT,
                             relief="flat", cursor="hand2")
        chk.pack(side="right")

    # ── Page: System ──────────────────────────────────────────────────────────

    def _page_system(self, parent: tk.Frame) -> None:
        self._page_header(parent, "System", "Startup behaviour, keyboard shortcut, and app info.")
        _, inner = self._scrollable(parent)

        # ── Startup ──
        self._section_label(inner, "Startup")
        self._setting_toggle(inner,
            label="Launch on Windows startup",
            desc="Critter Overlay starts automatically when you log in",
            section="system", key="auto_launch")

        # ── Shortcut ──
        self._section_label(inner, "Keyboard shortcut")

        shortcut_card = tk.Frame(inner, bg=CARD_BG, padx=18, pady=16)
        shortcut_card.pack(fill="x", pady=(0, 8))

        left = tk.Frame(shortcut_card, bg=CARD_BG)
        left.pack(side="left", fill="x", expand=True)
        tk.Label(left, text="Pause / Resume", font=(FF, 10, "bold"),
                 bg=CARD_BG, fg=FG).pack(anchor="w")
        tk.Label(left, text="Toggle critter activity from any application",
                 font=(FF, 8), bg=CARD_BG, fg=FG3).pack(anchor="w")

        tk.Label(shortcut_card, text="Ctrl + Shift + P",
                 font=(FF, 9, "bold"), bg="#1a1040", fg=ACCENT,
                 padx=10, pady=5, relief="flat").pack(side="right")

        # ── Danger zone ──
        self._section_label(inner, "Danger zone")

        reset_btn = tk.Button(inner,
            text="↺   Reset all settings to defaults",
            command=self._do_reset,
            bg=CARD_BG, fg=FG2,
            activebackground=CARD_HOV, activeforeground=FG,
            relief="flat", font=(FF, 9),
            cursor="hand2", pady=11, padx=16, anchor="w")
        reset_btn.pack(fill="x", pady=(0, 6))

        quit_btn = tk.Button(inner,
            text="✕   Quit Critter Overlay",
            command=self._do_quit,
            bg="#1a0808", fg=RED,
            activebackground="#2a1010", activeforeground=RED,
            relief="flat", font=(FF, 9, "bold"),
            cursor="hand2", pady=11, padx=16, anchor="w")
        quit_btn.pack(fill="x", pady=(0, 0))

        # ── Updates ──
        self._section_label(inner, "Updates")

        update_status = tk.Label(inner, text="", font=(FF, 8),
                                 bg=CONTENT_BG, fg=FG3)
        update_status.pack(anchor="w", pady=(0, 4))

        def _do_check():
            updates_btn.config(state="disabled", text="⏳   Checking…")
            update_status.config(text="", fg=FG3)
            def _run():
                result = check_now()
                def _apply():
                    updates_btn.config(state="normal",
                                       text="↗   Check for updates on GitHub")
                    if result is None:
                        update_status.config(
                            text="You're on the latest version.", fg=FG3)
                    else:
                        tag, url = result
                        update_status.config(
                            text=f"Version {tag} is available!  →  opening GitHub…",
                            fg=ACCENT)
                        webbrowser.open(url)
                inner.after(0, _apply)
            threading.Thread(target=_run, daemon=True).start()

        updates_btn = tk.Button(inner,
            text="↗   Check for updates on GitHub",
            command=_do_check,
            bg=CARD_BG, fg=FG2,
            activebackground=CARD_HOV, activeforeground=FG,
            relief="flat", font=(FF, 9),
            cursor="hand2", pady=11, padx=16, anchor="w")
        updates_btn.pack(fill="x", pady=(0, 0))

        # ── Critters I've seen ──
        self._section_label(inner, "Critters I've seen")

        seen_log = self._config.get("rarity", {}).get("seen_log", {})
        seen_enabled = self._config.get("rarity", {}).get("seen_log_enabled", True)

        if not seen_enabled:
            tk.Label(inner, text="Seen log is disabled (rarity.seen_log_enabled = false).",
                     font=(FF, 8), bg=CONTENT_BG, fg=FG3).pack(anchor="w")
        elif not seen_log:
            tk.Label(inner,
                     text="Nothing recorded yet — first sightings of each rarity tier per species will appear here.",
                     font=(FF, 8), bg=CONTENT_BG, fg=FG3,
                     wraplength=460, justify="left").pack(anchor="w")
        else:
            _TIER_COLORS = {
                "common":    FG3,
                "uncommon":  "#67e8f9",
                "rare":      "#a78bfa",
                "epic":      "#f59e0b",
                "legendary": "#f87171",
            }
            seen_card = tk.Frame(inner, bg=CARD_BG, padx=16, pady=12)
            seen_card.pack(fill="x", pady=(0, 8))
            for species, tiers in sorted(seen_log.items()):
                row = tk.Frame(seen_card, bg=CARD_BG)
                row.pack(fill="x", pady=(0, 4))
                tk.Label(row, text=species.capitalize(),
                         font=(FF, 9, "bold"), bg=CARD_BG, fg=FG,
                         width=12, anchor="w").pack(side="left")
                for tier, count in sorted(tiers.items()):
                    col = _TIER_COLORS.get(tier, FG2)
                    tk.Label(row, text=f"{tier} ×{count}",
                             font=(FF, 8), bg=CARD_BG, fg=col,
                             padx=6).pack(side="left")

        # ── About ──
        self._section_label(inner, "About")
        tk.Label(inner, text=f"Critter Overlay  ·  v{APP_VERSION}",
                 font=(FF, 10, "bold"), bg=CONTENT_BG, fg=FG).pack(anchor="w")
        tk.Label(inner, text="Adorable desktop companions. Made with love.",
                 font=(FF, 9), bg=CONTENT_BG, fg=FG3).pack(anchor="w", pady=(3, 0))

    # ── Reusable layout helpers ───────────────────────────────────────────────

    def _scrollable(self, parent: tk.Frame) -> tuple[tk.Canvas, tk.Frame]:
        """Returns (canvas, inner_frame) for a vertically scrollable area."""
        canvas = tk.Canvas(parent, bg=CONTENT_BG, highlightthickness=0,
                           relief="flat", bd=0)
        if _SVTTK:
            scrollbar = ttk.Scrollbar(parent, orient="vertical",
                                      command=canvas.yview)
        else:
            scrollbar = tk.Scrollbar(parent, orient="vertical",
                                     command=canvas.yview,
                                     bg=CONTENT_BG, troughcolor=CONTENT_BG,
                                     relief="flat", bd=0, width=8)
        inner = tk.Frame(canvas, bg=CONTENT_BG)

        canvas.configure(yscrollcommand=scrollbar.set)
        canvas.pack(side="left", fill="both", expand=True,
                    padx=(28, 0), pady=(0, 24))
        scrollbar.pack(side="right", fill="y", pady=8)

        win_id = canvas.create_window((0, 0), window=inner, anchor="nw")

        first_configure = [True]

        def _on_frame_configure(e):
            # Defer until pending layout is settled so bbox reflects final height.
            def _apply():
                try:
                    bb = canvas.bbox("all")
                    if bb:
                        canvas.configure(scrollregion=(0, 0, bb[2], bb[3]))
                    if first_configure[0]:
                        canvas.yview_moveto(0)
                        first_configure[0] = False
                except tk.TclError:
                    pass
            canvas.after_idle(_apply)

        def _on_canvas_configure(e):
            canvas.itemconfig(win_id, width=e.width)

        def _on_wheel(e):
            try:
                canvas.yview_scroll(-1 * (e.delta // 120), "units")
            except tk.TclError:
                pass

        inner.bind("<Configure>", _on_frame_configure)
        canvas.bind("<Configure>", _on_canvas_configure)

        # Bind immediately — _show_page unbinds before destroying old canvas,
        # so this always refers to the current page's canvas.
        if self._root:
            self._root.bind_all("<MouseWheel>", _on_wheel)

        return canvas, inner

    def _page_header(self, parent: tk.Frame, title: str, subtitle: str) -> None:
        header = tk.Frame(parent, bg=CONTENT_BG)
        header.pack(fill="x", padx=28, pady=(28, 0))

        tk.Label(header, text=title, font=(FF, 20, "bold"),
                 bg=CONTENT_BG, fg=FG).pack(anchor="w")
        tk.Label(header, text=subtitle, font=(FF, 9),
                 bg=CONTENT_BG, fg=FG2).pack(anchor="w", pady=(3, 12))
        tk.Frame(header, bg=BORDER, height=1).pack(fill="x")

        # Spacer
        tk.Frame(parent, bg=CONTENT_BG, height=16).pack()

    def _section_label(self, parent: tk.Frame, text: str) -> None:
        tk.Label(parent, text=text.upper(),
                 font=(FF, 7, "bold"), bg=CONTENT_BG, fg=ACCENT).pack(
            anchor="w", pady=(20, 6))

    def _setting_slider(self, parent, label, desc,
                        section, key, from_, to, res, unit="") -> None:
        card = tk.Frame(parent, bg=CARD_BG, padx=18, pady=14)
        card.pack(fill="x", pady=(0, 8))

        head = tk.Frame(card, bg=CARD_BG)
        head.pack(fill="x")

        tk.Label(head, text=label, font=(FF, 10, "bold"),
                 bg=CARD_BG, fg=FG).pack(side="left")

        cur = self._config[section].get(key, from_)
        display_val = int(cur) if res >= 1 else cur
        val_lbl = tk.Label(head, text=f"{display_val}{unit}",
                           font=(FF, 10, "bold"), bg=CARD_BG, fg=ACCENT)
        val_lbl.pack(side="right")

        tk.Label(card, text=desc, font=(FF, 8), bg=CARD_BG, fg=FG3).pack(
            anchor="w", pady=(2, 6))

        var = tk.DoubleVar(value=cur)

        def on_slide(v, s=section, k=key, lbl=val_lbl, u=unit):
            fv = int(float(v)) if res >= 1 else round(float(v), 1)
            lbl.configure(text=f"{fv}{u}")
            self._set_direct(s, k, fv)

        sl = tk.Scale(card, from_=from_, to=to, resolution=res,
                      orient="horizontal", variable=var,
                      bg=CARD_BG, fg=FG, troughcolor=SLIDER_TR,
                      highlightthickness=0, bd=0, showvalue=False,
                      command=on_slide)
        sl.pack(fill="x")

    def _setting_toggle(self, parent, label, desc, section, key) -> None:
        card = tk.Frame(parent, bg=CARD_BG, padx=18, pady=14)
        card.pack(fill="x", pady=(0, 8))

        cur = self._config[section].get(key, True)
        var = tk.BooleanVar(value=cur)

        head = tk.Frame(card, bg=CARD_BG)
        head.pack(fill="x")

        tk.Label(head, text=label, font=(FF, 10, "bold"),
                 bg=CARD_BG, fg=FG).pack(side="left")

        state_lbl = tk.Label(head, text="✓  ON" if cur else "✕  OFF",
                             font=(FF, 8, "bold"),
                             bg=CARD_BG,
                             fg=GREEN if cur else FG3)
        state_lbl.pack(side="right", padx=(0, 6))

        def on_toggle(s=section, k=key, v=var, lbl=state_lbl):
            val = v.get()
            lbl.configure(text="✓  ON" if val else "✕  OFF",
                          fg=GREEN if val else FG3)
            self._set_direct(s, k, val)

        chk = tk.Checkbutton(head, variable=var, command=on_toggle,
                             bg=CARD_BG, activebackground=CARD_BG,
                             selectcolor=CARD_BG, fg=ACCENT,
                             relief="flat", cursor="hand2")
        chk.pack(side="right")

        tk.Label(card, text=desc, font=(FF, 8), bg=CARD_BG, fg=FG3).pack(
            anchor="w", pady=(2, 0))

    # ── Config mutations ──────────────────────────────────────────────────────

    def _set_direct(self, section: str, key: str, value) -> None:
        self._config[section][key] = value
        save_config(self._config)
        self._on_save(self._config)

    def _set(self, section: str, subsection: str, key: str, value) -> None:
        self._config[section][subsection][key] = value
        save_config(self._config)
        self._on_save(self._config)

    def _do_reset(self) -> None:
        new_cfg = reset_to_defaults()
        self._config = new_cfg
        self._on_save(new_cfg)
        self._show_page(self._current_page)

    def _reset_weights(self) -> None:
        for sp in self._config["animals"]:
            self._config["animals"][sp]["weight"] = 1.0
        self._config["animals"]["kitten"]["weight"] = 3.0
        save_config(self._config)
        self._on_save(self._config)
        self._show_page("critters")

    def _do_quit(self) -> None:
        if self._root:
            self._root.destroy()
        self._on_quit()

    def _toggle_pause(self) -> None:
        if self._on_toggle_pause:
            self._on_toggle_pause()
