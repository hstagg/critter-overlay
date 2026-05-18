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
import webbrowser
from pathlib import Path
from typing import Callable

APP_VERSION  = "1.8"
RELEASES_URL = "https://github.com/hstagg/critter-overlay/releases"

from PIL import Image, ImageTk

from config import save_config, reset_to_defaults
from custom_critters.registry import CustomCritterRegistry
from custom_critters.storage import delete_critter_folder, get_custom_dir, write_meta
from custom_critters.import_pipeline import run_import

try:
    from animal_previews import FRAMES as _ANIMAL_FRAMES
except ImportError:
    _ANIMAL_FRAMES = {}

SOUND_PRESETS = ["kitten", "turtle", "duck", "rabbit",
                 "hedgehog", "squirrel", "otter", "panda"]

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
                 preview_frames: dict | None = None):
        self._config               = config
        self._on_save              = on_save
        self._on_force_spawn       = on_force_spawn
        self._on_quit              = on_quit
        self._get_paused           = get_paused or (lambda: False)
        self._registry             = registry or CustomCritterRegistry()
        self._on_test_custom_spawn = on_test_custom_spawn
        self._on_toggle_pause: Callable | None = None

        # Raw base64 frame data — PhotoImages are created in the tkinter thread
        self._preview_frames_data: dict = preview_frames if preview_frames is not None else _ANIMAL_FRAMES

        self._root: tk.Tk | None = None
        self._thread: threading.Thread | None = None
        self._lock = threading.Lock()

        # Animated preview frames: species -> list[ImageTk.PhotoImage]
        # Populated in _run() (tkinter thread) from _preview_frames_data.
        self._animal_frames:       dict[str, list] = {}
        self._animal_frames_small: dict[str, list] = {}

        # Active animation callbacks: after() job ids, cancelled on page change
        self._anim_jobs: list[str] = []

        self._current_page = "home"
        self._content_frame: tk.Frame | None = None
        self._nav_btns: dict[str, tk.Button] = {}

        # Live-update labels
        self._status_dot: tk.Label | None   = None
        self._status_lbl: tk.Label | None   = None
        self._sidebar_pause_btn: tk.Button | None = None
        self._home_big_lbl: tk.Label | None = None
        self._home_big_sub: tk.Label | None = None
        self._home_big_bg:  str = CARD_BG

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

    # ── Internal ──────────────────────────────────────────────────────────────

    def _restore(self) -> None:
        self._root.deiconify()
        self._root.lift()
        self._root.focus_force()

    def _run(self) -> None:
        self._root = tk.Tk()
        self._load_animal_frames()   # must run in tkinter thread (PhotoImage needs a root)
        self._build_window()
        self._poll_status()
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
        self._show_page("home")

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
            ("home",     "⌂",  "Home"),
            ("animals",  "🐾", "Animals"),
            ("custom",   "✨", "Custom"),
            ("spawning", "⏱",  "Spawning"),
            ("audio",    "🔊", "Audio"),
            ("system",   "⚙",  "System"),
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

        # Home-page live labels
        if self._current_page == "home":
            self._refresh_home_status(paused)

    def _refresh_home_status(self, paused: bool) -> None:
        if self._home_big_lbl is None:
            return
        try:
            if paused:
                bg   = "#1f0f0f"
                fg   = RED
                text = "⏸  PAUSED"
                sub  = "Animals are frozen — click Resume to continue."
            else:
                bg   = "#0f1f12"
                fg   = GREEN
                text = "●  RUNNING"
                sub  = "Animals are roaming freely across your screen."

            self._home_big_lbl.configure(text=text, fg=fg, bg=bg)
            self._home_big_sub.configure(text=sub, bg=bg)
            self._home_big_lbl.master.configure(bg=bg)
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

        # Reset home live labels
        self._home_big_lbl = None
        self._home_big_sub = None

        {
            "home":     self._page_home,
            "animals":  self._page_animals,
            "custom":   self._page_custom,
            "spawning": self._page_spawning,
            "audio":    self._page_audio,
            "system":   self._page_system,
        }.get(page_id, self._page_home)(self._content_frame)

    # ── Page: Home ────────────────────────────────────────────────────────────

    def _page_home(self, parent: tk.Frame) -> None:
        scroll_canvas, inner = self._scrollable(parent)

        paused = self._get_paused()

        # ── Big status card ──
        status_bg = "#0f1f12" if not paused else "#1f0f0f"
        status_card = tk.Frame(inner, bg=status_bg, padx=24, pady=22)
        status_card.pack(fill="x", pady=(0, 16))

        self._home_big_lbl = tk.Label(
            status_card,
            text="●  RUNNING" if not paused else "⏸  PAUSED",
            font=(FF, 26, "bold"),
            bg=status_bg,
            fg=GREEN if not paused else RED,
        )
        self._home_big_lbl.pack(anchor="w")

        self._home_big_sub = tk.Label(
            status_card,
            text=("Animals are roaming freely across your screen."
                  if not paused else "Animals are frozen — click Resume to continue."),
            font=(FF, 10),
            bg=status_bg,
            fg=FG2,
        )
        self._home_big_sub.pack(anchor="w", pady=(5, 0))

        # ── Quick-action pair ──
        actions = tk.Frame(inner, bg=CONTENT_BG)
        actions.pack(fill="x", pady=(0, 20))
        actions.grid_columnconfigure(0, weight=1)
        actions.grid_columnconfigure(1, weight=1)

        self._action_card(
            actions, row=0, col=0, padright=8,
            icon="💥", title="Spawn Now",
            desc="Send a wave of critters onto the screen",
            color=ACCENT,
            command=self._on_force_spawn,
        )
        self._action_card(
            actions, row=0, col=1, padright=0,
            icon="▶" if paused else "⏸",
            title="Resume" if paused else "Pause",
            desc="Freeze or unfreeze all animal activity",
            color=GREEN if paused else RED,
            command=self._toggle_pause,
        )

        # ── Stat trio ──
        stats = tk.Frame(inner, bg=CONTENT_BG)
        stats.pack(fill="x", pady=(0, 24))
        stats.grid_columnconfigure(0, weight=1)
        stats.grid_columnconfigure(1, weight=1)
        stats.grid_columnconfigure(2, weight=1)

        spawn_min   = self._config["spawn"].get("primary_interval_min", 5)
        cnt_min     = self._config["spawn"].get("primary_count_min", 5)
        cnt_max     = self._config["spawn"].get("primary_count_max", 10)
        enabled_n   = sum(1 for s in self._config["animals"].values()
                          if s.get("enabled", True))

        self._stat_card(stats, col=0, pad=8, icon="⏱",
                        value=f"{spawn_min} min", label="Spawn interval")
        self._stat_card(stats, col=1, pad=8, icon="🐾",
                        value=f"{cnt_min}–{cnt_max}", label="Per-spawn count")
        self._stat_card(stats, col=2, pad=0, icon="✓",
                        value=f"{enabled_n} / 8", label="Species active")

        # ── Tip bar ──
        tip = tk.Frame(inner, bg=CARD_BG, padx=16, pady=10)
        tip.pack(fill="x")
        tk.Label(tip, text="💡", font=(FF, 10), bg=CARD_BG, fg=AMBER).pack(side="left")
        tk.Label(tip, text="  Use the sidebar to adjust which animals appear and how often.",
                 font=(FF, 9), bg=CARD_BG, fg=FG2).pack(side="left")
        tk.Label(tip, text="  Ctrl+Shift+P  to pause from any app.",
                 font=(FF, 9), bg=CARD_BG, fg=FG3).pack(side="left")

    def _action_card(self, parent, row, col, padright,
                     icon, title, desc, color, command):
        card = tk.Frame(parent, bg=CARD_BG, padx=20, pady=18, cursor="hand2")
        card.grid(row=row, column=col, sticky="nsew",
                  padx=(0, padright), pady=(0, 0))

        top = tk.Frame(card, bg=CARD_BG)
        top.pack(anchor="w")
        tk.Label(top, text=icon, font=(FF, 16), bg=CARD_BG, fg=color).pack(side="left")
        tk.Label(top, text=f"  {title}", font=(FF, 13, "bold"),
                 bg=CARD_BG, fg=color).pack(side="left")

        tk.Label(card, text=desc, font=(FF, 9), bg=CARD_BG, fg=FG3).pack(anchor="w", pady=(5, 0))

        for w in [card] + list(card.winfo_children()) + [top] + list(top.winfo_children()):
            w.bind("<Button-1>", lambda e, c=command: c())
            w.bind("<Enter>",    lambda e, f=card: f.configure(bg=CARD_HOV))
            w.bind("<Leave>",    lambda e, f=card: f.configure(bg=CARD_BG))

    def _stat_card(self, parent, col, pad, icon, value, label):
        card = tk.Frame(parent, bg=CARD_BG, padx=16, pady=16)
        card.grid(row=0, column=col, sticky="nsew", padx=(0, pad))
        tk.Label(card, text=icon, font=(FF, 14), bg=CARD_BG, fg=ACCENT).pack(anchor="w")
        tk.Label(card, text=value, font=(FF, 16, "bold"),
                 bg=CARD_BG, fg=FG).pack(anchor="w", pady=(3, 0))
        tk.Label(card, text=label, font=(FF, 8), bg=CARD_BG, fg=FG3).pack(anchor="w")

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

    # ── Page: Animals ─────────────────────────────────────────────────────────

    def _page_animals(self, parent: tk.Frame) -> None:
        self._page_header(parent, "Animals",
                          "Choose which species appear and how frequently they're picked.")
        _, inner = self._scrollable(parent)

        for species, emoji, name in ANIMALS:
            cell = tk.Frame(inner, bg=CARD_BG, padx=18, pady=16)
            cell.pack(fill="x", pady=(0, 8))
            self._animal_card(cell, species, emoji, name)

        # Reset weights link
        link = tk.Label(inner, text="Reset all weights to default",
                        font=(FF, 9), bg=CONTENT_BG, fg=FG3,
                        cursor="hand2")
        link.pack(anchor="w", pady=(12, 0))
        link.bind("<Button-1>", lambda e: self._reset_weights())

    def _animal_card(self, parent, species, emoji, name) -> None:
        cfg = self._config["animals"][species]
        enabled_var = tk.BooleanVar(value=cfg.get("enabled", True))
        weight_var  = tk.DoubleVar(value=cfg.get("weight", 1.0))

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
            # Fallback: emoji placeholder at a fixed pixel size
            img_lbl = tk.Label(left, text=emoji, font=(FF, 28), bg=CARD_BG)
            img_lbl.pack(padx=(_PREVIEW_SIZE // 4,) * 2,
                         pady=(_PREVIEW_SIZE // 4,) * 2)

        # ── Name + enabled toggle ──
        head = tk.Frame(right, bg=CARD_BG)
        head.pack(fill="x")

        tk.Label(head, text=name, font=(FF, 12, "bold"),
                 bg=CARD_BG, fg=FG).pack(side="left")

        is_on   = cfg.get("enabled", True)
        pill = tk.Label(head, text="ON" if is_on else "OFF",
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
            p.configure(text="ON" if val else "OFF",
                        fg=(GREEN if val else FG3),
                        bg=("#0f2015" if val else CARD_BG))
            self._set("animals", s, "enabled", val)

        chk.configure(command=on_toggle)
        pill.bind("<Button-1>", lambda e, v=enabled_var: (v.set(not v.get()), on_toggle()))

        # ── Weight ──
        tk.Frame(right, bg=BORDER, height=1).pack(fill="x", pady=(10, 8))

        w_head = tk.Frame(right, bg=CARD_BG)
        w_head.pack(fill="x")
        tk.Label(w_head, text="Spawn frequency",
                 font=(FF, 8), bg=CARD_BG, fg=FG3).pack(side="left")

        w_lbl = tk.Label(w_head, text=f"{weight_var.get():.1f}×",
                         font=(FF, 8, "bold"), bg=CARD_BG, fg=ACCENT)
        w_lbl.pack(side="right")

        def on_weight(v, s=species, lbl=w_lbl):
            fv = round(float(v), 1)
            lbl.configure(text=f"{fv:.1f}×")
            self._set("animals", s, "weight", fv)

        sl = tk.Scale(right, from_=0.1, to=5.0, resolution=0.1,
                      orient="horizontal", variable=weight_var,
                      bg=CARD_BG, fg=FG2, troughcolor=SLIDER_TR,
                      highlightthickness=0, bd=0, showvalue=False,
                      command=on_weight)
        sl.pack(fill="x", pady=(4, 0))

    # ── Page: Custom critters ────────────────────────────────────────────────

    def _page_custom(self, parent: tk.Frame) -> None:
        self._page_header(parent, "Custom",
                          "Import your own critters from PNG, JPG, or animated GIF.")
        _, inner = self._scrollable(parent)

        # Import button
        import_btn = tk.Button(inner,
            text="＋  Import new critter",
            command=lambda: self._import_dialog(inner),
            bg="#1a0f35", fg=ACCENT,
            activebackground="#23154a", activeforeground=ACCENT,
            relief="flat", font=(FF, 10, "bold"),
            cursor="hand2", pady=12, padx=16, anchor="w")
        import_btn.pack(fill="x", pady=(0, 16))

        records = self._registry.all()
        if not records:
            tk.Label(inner,
                     text="No custom critters yet. Click 'Import new critter' above to add one.",
                     font=(FF, 9), bg=CONTENT_BG, fg=FG3,
                     wraplength=460, justify="left").pack(anchor="w", pady=20)
            return

        for record in records:
            self._custom_critter_row(inner, record)

    def _custom_critter_row(self, parent: tk.Frame, record) -> None:
        cid  = record.id
        meta = record.meta
        custom_cfg = self._config.get("custom_animals", {}).get(cid, {})

        card = tk.Frame(parent, bg=CARD_BG, padx=16, pady=14)
        card.pack(fill="x", pady=(0, 8))

        # ── Thumbnail ──
        left = tk.Frame(card, bg=CARD_BG)
        left.pack(side="left", padx=(0, 14))

        thumb_path = get_custom_dir() / cid / "thumb.png"
        thumb_photo = None
        if thumb_path.exists():
            try:
                img = Image.open(str(thumb_path)).convert("RGBA")
                bg  = Image.new("RGBA", img.size, (_CARD_RGB[0], _CARD_RGB[1], _CARD_RGB[2], 255))
                bg.paste(img, mask=img.split()[3])
                thumb_photo = ImageTk.PhotoImage(bg.convert("RGB"))
            except Exception:
                pass

        if thumb_photo:
            lbl = tk.Label(left, image=thumb_photo, bg=CARD_BG)
            lbl.image = thumb_photo
            lbl.pack()
        else:
            tk.Label(left, text="🐾", font=(FF, 22), bg=CARD_BG, fg=FG3,
                     width=4, height=2).pack()

        # ── Right controls ──
        right = tk.Frame(card, bg=CARD_BG)
        right.pack(side="left", fill="both", expand=True)

        # Name row
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

        # Enabled pill
        is_on       = custom_cfg.get("enabled", True)
        enabled_var = tk.BooleanVar(value=is_on)
        pill = tk.Label(head,
                        text="ON" if is_on else "OFF",
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
            p.configure(text="ON" if val else "OFF",
                        fg=(GREEN if val else FG3),
                        bg=("#0f2015" if val else CARD_BG))
            self._set_custom(_cid, "enabled", val)

        chk.configure(command=on_toggle)
        pill.bind("<Button-1>", lambda e, v=enabled_var: (v.set(not v.get()), on_toggle()))

        # Weight slider
        tk.Frame(right, bg=BORDER, height=1).pack(fill="x", pady=(8, 6))

        w_row = tk.Frame(right, bg=CARD_BG)
        w_row.pack(fill="x")
        tk.Label(w_row, text="Spawn frequency", font=(FF, 8), bg=CARD_BG, fg=FG3).pack(side="left")

        weight_var = tk.DoubleVar(value=custom_cfg.get("weight", 1.0))
        w_lbl = tk.Label(w_row, text=f"{weight_var.get():.1f}×",
                         font=(FF, 8, "bold"), bg=CARD_BG, fg=ACCENT)
        w_lbl.pack(side="right")

        def on_weight(v, _cid=cid, lbl=w_lbl):
            fv = round(float(v), 1)
            lbl.configure(text=f"{fv:.1f}×")
            self._set_custom(_cid, "weight", fv)

        tk.Scale(right, from_=0.5, to=5.0, resolution=0.1,
                 orient="horizontal", variable=weight_var,
                 bg=CARD_BG, fg=FG2, troughcolor=SLIDER_TR,
                 highlightthickness=0, bd=0, showvalue=False,
                 command=on_weight).pack(fill="x", pady=(4, 6))

        # Sound preset dropdown + action buttons
        btn_row = tk.Frame(right, bg=CARD_BG)
        btn_row.pack(fill="x")

        tk.Label(btn_row, text="Sound:", font=(FF, 8), bg=CARD_BG, fg=FG3).pack(side="left")

        current_preset = custom_cfg.get("sound_override") or meta.get("sound_profile", "kitten")
        sound_var = tk.StringVar(value=current_preset)
        preset_menu = tk.OptionMenu(btn_row, sound_var, *SOUND_PRESETS)
        preset_menu.configure(bg=CARD_BG, fg=FG2, activebackground=SEL_BG,
                              activeforeground=FG, relief="flat",
                              font=(FF, 8), highlightthickness=0)
        preset_menu["menu"].configure(bg=CARD_BG, fg=FG2, font=(FF, 8))
        preset_menu.pack(side="left", padx=(4, 12))

        def on_sound(*_, _cid=cid, var=sound_var):
            self._set_custom(_cid, "sound_override", var.get())

        sound_var.trace_add("write", on_sound)

        # Test spawn
        tk.Button(btn_row, text="▶ Test",
                  command=lambda _cid=cid: self._on_test_custom_spawn and self._on_test_custom_spawn(_cid),
                  bg=CARD_BG, fg=ACCENT2,
                  activebackground=SEL_BG, activeforeground=FG,
                  relief="flat", font=(FF, 8, "bold"),
                  cursor="hand2", padx=8, pady=4).pack(side="left")

        # Delete
        tk.Button(btn_row, text="✕ Delete",
                  command=lambda _cid=cid: self._delete_custom(_cid),
                  bg=CARD_BG, fg=RED,
                  activebackground="#2a1010", activeforeground=RED,
                  relief="flat", font=(FF, 8),
                  cursor="hand2", padx=8, pady=4).pack(side="right")

    def _import_dialog(self, parent_inner: tk.Frame) -> None:
        """Modal dialog to import a new custom critter."""
        path = filedialog.askopenfilename(
            title="Choose an image",
            filetypes=[
                ("Supported images", "*.png *.jpg *.jpeg *.gif"),
                ("PNG", "*.png"), ("JPEG", "*.jpg *.jpeg"), ("GIF", "*.gif"),
            ],
        )
        if not path:
            return

        # Name autofilled from filename (no extension)
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

            import_btn.configure(state="disabled", text="Importing…")
            dlg.update()

            try:
                critter_id = run_import(path, name, get_custom_dir())
            except ImportError as err:
                status_lbl.configure(text=str(err), fg=RED)
                import_btn.configure(state="normal", text="Import")
                return
            except Exception as err:
                status_lbl.configure(text=f"Unexpected error: {err}", fg=RED)
                import_btn.configure(state="normal", text="Import")
                return

            # Register in config
            if "custom_animals" not in self._config:
                self._config["custom_animals"] = {}
            self._config["custom_animals"][critter_id] = {
                "enabled": True, "weight": 1.0, "sound_override": None, "size_override": None,
            }
            save_config(self._config)

            # Reload registry and notify overlay
            self._registry.reload()
            self._on_save(self._config)

            dlg.destroy()
            self._show_page("custom")

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
        self._show_page("custom")

    def _set_custom(self, critter_id: str, key: str, value) -> None:
        if "custom_animals" not in self._config:
            self._config["custom_animals"] = {}
        if critter_id not in self._config["custom_animals"]:
            self._config["custom_animals"][critter_id] = {}
        self._config["custom_animals"][critter_id][key] = value
        save_config(self._config)
        self._on_save(self._config)

    # ── Page: Spawning ────────────────────────────────────────────────────────

    def _page_spawning(self, parent: tk.Frame) -> None:
        self._page_header(parent, "Spawning",
                          "Control how frequently critters arrive and in what numbers.")
        _, inner = self._scrollable(parent)

        self._section_label(inner, "Primary group spawns")

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

        self._section_label(inner, "Per-species sounds")

        grid = tk.Frame(inner, bg=CONTENT_BG)
        grid.pack(fill="x")
        grid.grid_columnconfigure(0, weight=1)
        grid.grid_columnconfigure(1, weight=1)

        for i, (species, emoji, name) in enumerate(ANIMALS):
            row_i, col_i = divmod(i, 2)
            pad_r = 8 if col_i == 0 else 0
            cell = tk.Frame(grid, bg=CARD_BG, padx=14, pady=10)
            cell.grid(row=row_i, column=col_i, sticky="nsew",
                      padx=(0, pad_r), pady=(0, 6))

            cfg = self._config["animals"][species]
            var = tk.BooleanVar(value=cfg.get("sound", True))

            # Animated 48×48 preview, or emoji fallback
            small_frames = self._animal_frames_small.get(species)
            if small_frames:
                prev = tk.Label(cell, image=small_frames[0], bg=CARD_BG)
                prev.image = small_frames[0]
                prev.pack(side="left", padx=(0, 8))
                self._start_anim(prev, small_frames)
            else:
                tk.Label(cell, text=emoji, font=(FF, 14),
                         bg=CARD_BG, fg=FG2).pack(side="left", padx=(0, 4))

            tk.Label(cell, text=name,
                     font=(FF, 9, "bold"), bg=CARD_BG, fg=FG).pack(side="left")
            chk = tk.Checkbutton(cell, variable=var,
                                 command=lambda s=species, v=var:
                                     self._set("animals", s, "sound", v.get()),
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
        updates_btn = tk.Button(inner,
            text="↗   Check for updates on GitHub",
            command=lambda: webbrowser.open(RELEASES_URL),
            bg=CARD_BG, fg=FG2,
            activebackground=CARD_HOV, activeforeground=FG,
            relief="flat", font=(FF, 9),
            cursor="hand2", pady=11, padx=16, anchor="w")
        updates_btn.pack(fill="x", pady=(0, 0))

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

        state_lbl = tk.Label(head, text="ON" if cur else "OFF",
                             font=(FF, 8, "bold"),
                             bg=CARD_BG,
                             fg=GREEN if cur else FG3)
        state_lbl.pack(side="right", padx=(0, 6))

        def on_toggle(s=section, k=key, v=var, lbl=state_lbl):
            val = v.get()
            lbl.configure(text="ON" if val else "OFF",
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
        self._show_page("animals")

    def _do_quit(self) -> None:
        if self._root:
            self._root.destroy()
        self._on_quit()

    def _toggle_pause(self) -> None:
        if self._on_toggle_pause:
            self._on_toggle_pause()
