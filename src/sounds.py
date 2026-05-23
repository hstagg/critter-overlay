"""
sounds.py — Procedural sound generation for Critter Overlay App

v1.7 change: if pre-generated WAV files are present (bundled by the installer,
or produced locally by build_sounds.py), load those instead of synthesising
at runtime. This removes the numpy dependency from the installed exe.

Fallback priority:
  1. WAV files in the bundled sounds/ directory (installed exe)
  2. WAV files in sounds/ relative to project root (local dev, after build_sounds.py)
  3. Numpy synthesis (local dev, when WAVs haven't been generated yet)
"""

import math
import os
import random
import sys

import pygame

# ---------------------------------------------------------------------------
# Optional numpy — only needed for synthesis fallback.
# When running from the bundled exe, WAVs are always present so numpy is
# never imported. When running from source without pre-generated WAVs,
# numpy synthesis kicks in as before.
# ---------------------------------------------------------------------------

try:
    import numpy as np
    _NUMPY_OK = True
except ImportError:
    _NUMPY_OK = False

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

SAMPLE_RATE = 22050
CHANNELS = 2  # stereo

# ---------------------------------------------------------------------------
# WAV directory resolver
# ---------------------------------------------------------------------------

def _bundled_sounds_dir() -> str | None:
    """Return path to directory containing pre-generated WAVs, or None."""
    # Running as a PyInstaller bundle
    if getattr(sys, "frozen", False):
        candidate = os.path.join(sys._MEIPASS, "sounds")
        if os.path.isdir(candidate):
            return candidate

    # Running from source: look for sounds/ at project root (one level up from src/)
    here = os.path.dirname(os.path.abspath(__file__))
    candidate = os.path.normpath(os.path.join(here, "..", "sounds"))
    if os.path.isdir(candidate):
        return candidate

    return None

# ---------------------------------------------------------------------------
# Low-level synthesis helpers (only used when numpy is available)
# ---------------------------------------------------------------------------

def _make_sound(wave) -> pygame.mixer.Sound:
    """Convert a float32 mono wave (-1..1) into a pygame Sound (stereo int16)."""
    wave = np.clip(wave, -1.0, 1.0)
    samples = (wave * 32767).astype(np.int16)
    stereo = np.column_stack([samples, samples])
    return pygame.sndarray.make_sound(stereo)


def _envelope(t, attack, decay, sustain, sustain_level, release):
    """Simple ADSR envelope."""
    env = np.zeros_like(t)
    for i, ti in enumerate(t):
        if ti < attack:
            env[i] = ti / attack
        elif ti < attack + decay:
            env[i] = 1.0 - (1.0 - sustain_level) * (ti - attack) / decay
        elif ti < attack + decay + sustain:
            env[i] = sustain_level
        else:
            remaining = ti - (attack + decay + sustain)
            env[i] = sustain_level * max(0, 1.0 - remaining / max(release, 1e-6))
    return env


def _sine_fm(t, carrier_hz, mod_hz, mod_depth):
    """Frequency-modulated sine wave."""
    modulator = mod_depth * np.sin(2 * math.pi * mod_hz * t)
    return np.sin(2 * math.pi * carrier_hz * t + modulator)


def _sweep(t, freq_start, freq_end):
    """Sine wave with linearly swept frequency."""
    freq = freq_start + (freq_end - freq_start) * (t / max(t[-1], 1e-6))
    return np.sin(2 * math.pi * np.cumsum(freq) / SAMPLE_RATE)

# ---------------------------------------------------------------------------
# Seed perturbation helper
# ---------------------------------------------------------------------------

def _p(rng: random.Random | None, value: float, spread: float) -> float:
    """Perturb value by ±spread fraction using rng; return value unchanged if rng is None."""
    if rng is None:
        return value
    return value * rng.uniform(1.0 - spread, 1.0 + spread)


# ---------------------------------------------------------------------------
# Per-animal sound generators
# Each accepts an optional rng; when provided, key synthesis params are
# perturbed deterministically so custom critters get distinct sound variants.
# seed=0 (default) → rng=None → exact canonical sound preserved.
# ---------------------------------------------------------------------------

def _gen_kitten(volume: float, rng: random.Random | None = None) -> pygame.mixer.Sound:
    """Soft meow: falling pitch sweep with gentle envelope."""
    duration = _p(rng, 0.35, 0.10)
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration))
    wave = _sweep(t, _p(rng, 900, 0.05), _p(rng, 550, 0.05))
    env = _envelope(t, _p(rng, 0.02, 0.10), _p(rng, 0.08, 0.10),
                    _p(rng, 0.15, 0.10), 0.6, _p(rng, 0.10, 0.10))
    return _make_sound(wave * env * volume * 0.7)


def _gen_turtle(volume: float, rng: random.Random | None = None) -> pygame.mixer.Sound:
    """Gentle hiss: low-frequency breathiness with noise."""
    duration = _p(rng, 0.30, 0.10)
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration))
    noise = np.random.uniform(-1, 1, len(t))
    tone = np.sin(2 * math.pi * _p(rng, 180, 0.05) * t) * 0.3
    wave = noise * 0.6 + tone
    env = _envelope(t, _p(rng, 0.04, 0.10), _p(rng, 0.05, 0.10),
                    _p(rng, 0.15, 0.10), 0.4, _p(rng, 0.06, 0.10))
    return _make_sound(wave * env * volume * 0.5)


def _gen_duck(volume: float, rng: random.Random | None = None) -> pygame.mixer.Sound:
    """Cheerful quack: sharp FM burst."""
    duration = _p(rng, 0.25, 0.10)
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration))
    wave = _sine_fm(t, carrier_hz=_p(rng, 450, 0.05),
                    mod_hz=_p(rng, 80, 0.05), mod_depth=_p(rng, 4.0, 0.03))
    env = _envelope(t, _p(rng, 0.01, 0.10), _p(rng, 0.06, 0.10),
                    _p(rng, 0.08, 0.10), 0.5, _p(rng, 0.10, 0.10))
    return _make_sound(wave * env * volume * 0.65)


def _gen_rabbit(volume: float, rng: random.Random | None = None) -> pygame.mixer.Sound:
    """Soft squeak: high brief chirp."""
    duration = _p(rng, 0.20, 0.10)
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration))
    wave = _sweep(t, _p(rng, 1400, 0.05), _p(rng, 1100, 0.05))
    env = _envelope(t, _p(rng, 0.01, 0.10), _p(rng, 0.04, 0.10),
                    _p(rng, 0.05, 0.10), 0.4, _p(rng, 0.10, 0.10))
    return _make_sound(wave * env * volume * 0.55)


def _gen_hedgehog(volume: float, rng: random.Random | None = None) -> pygame.mixer.Sound:
    """Snuffle: low purring with slight noise texture."""
    duration = _p(rng, 0.28, 0.10)
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration))
    f1, f2 = _p(rng, 220, 0.05), _p(rng, 440, 0.05)
    tone = np.sin(2 * math.pi * f1 * t) + _p(rng, 0.4, 0.03) * np.sin(2 * math.pi * f2 * t)
    noise = np.random.uniform(-1, 1, len(t)) * 0.2
    wave = tone + noise
    env = _envelope(t, _p(rng, 0.03, 0.10), _p(rng, 0.06, 0.10),
                    _p(rng, 0.12, 0.10), 0.5, _p(rng, 0.07, 0.10))
    return _make_sound(wave * env * volume * 0.45)


def _gen_squirrel(volume: float, rng: random.Random | None = None) -> pygame.mixer.Sound:
    """Quick chatter: two-tone rapid chirp."""
    duration = _p(rng, 0.22, 0.10)
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration))
    wave = np.sin(2 * math.pi * _p(rng, 1100, 0.05) * t) * \
           (0.5 + 0.5 * np.sin(2 * math.pi * _p(rng, 30, 0.05) * t))
    env = _envelope(t, _p(rng, 0.005, 0.10), _p(rng, 0.05, 0.10),
                    _p(rng, 0.08, 0.10), 0.6, _p(rng, 0.08, 0.10))
    return _make_sound(wave * env * volume * 0.60)


def _gen_otter(volume: float, rng: random.Random | None = None) -> pygame.mixer.Sound:
    """Playful squeak: bouncy FM chirp."""
    duration = _p(rng, 0.28, 0.10)
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration))
    wave = _sine_fm(t, carrier_hz=_p(rng, 700, 0.05),
                    mod_hz=_p(rng, 25, 0.05), mod_depth=_p(rng, 3.0, 0.03))
    env = _envelope(t, _p(rng, 0.01, 0.10), _p(rng, 0.05, 0.10),
                    _p(rng, 0.12, 0.10), 0.55, _p(rng, 0.10, 0.10))
    return _make_sound(wave * env * volume * 0.60)


def _gen_panda(volume: float, rng: random.Random | None = None) -> pygame.mixer.Sound:
    """Gentle squeak: soft falling tone."""
    duration = _p(rng, 0.32, 0.10)
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration))
    wave = _sweep(t, _p(rng, 600, 0.05), _p(rng, 400, 0.05)) + \
           _p(rng, 0.3, 0.03) * _sweep(t, _p(rng, 1200, 0.05), _p(rng, 800, 0.05))
    env = _envelope(t, _p(rng, 0.03, 0.10), _p(rng, 0.06, 0.10),
                    _p(rng, 0.12, 0.10), 0.5, _p(rng, 0.11, 0.10))
    return _make_sound(wave * env * volume * 0.55)


def _gen_unicorn(volume: float, rng: random.Random | None = None) -> pygame.mixer.Sound:
    """Magical chime: bright stacked harmonics rising into a shimmer."""
    duration = _p(rng, 0.55, 0.10)
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration))
    base  = _sweep(t, _p(rng,  880, 0.05), _p(rng, 1200, 0.05))
    third = _sweep(t, _p(rng, 1100, 0.05), _p(rng, 1500, 0.05))
    fifth = _sweep(t, _p(rng, 1320, 0.05), _p(rng, 1800, 0.05))
    high  = np.sin(2 * math.pi * _p(rng, 2640, 0.05) * t) * _p(rng, 0.25, 0.03)
    shimmer = np.sin(2 * math.pi * _p(rng, 18, 0.05) * t) * 0.15
    wave = (base * _p(rng, 0.55, 0.03) + third * _p(rng, 0.30, 0.03) +
            fifth * _p(rng, 0.20, 0.03) + high) * (1.0 + shimmer)
    env = _envelope(t, _p(rng, 0.02, 0.10), _p(rng, 0.10, 0.10),
                    _p(rng, 0.30, 0.10), 0.55, _p(rng, 0.18, 0.10))
    return _make_sound(wave * env * volume * 0.55)


def _gen_squeak(volume: float, rng: random.Random | None = None) -> pygame.mixer.Sound:
    """High-pitched quick squeak."""
    duration = _p(rng, 0.15, 0.10)
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration))
    wave = _sweep(t, _p(rng, 1800, 0.05), _p(rng, 1400, 0.05))
    env = _envelope(t, _p(rng, 0.005, 0.10), _p(rng, 0.03, 0.10),
                    _p(rng, 0.04, 0.10), 0.5, _p(rng, 0.07, 0.10))
    return _make_sound(wave * env * volume * 0.55)


def _gen_chirp(volume: float, rng: random.Random | None = None) -> pygame.mixer.Sound:
    """Bird-like short trill: rapid frequency oscillation."""
    duration = _p(rng, 0.20, 0.10)
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration))
    trill = np.sin(2 * math.pi * _p(rng, 30, 0.05) * t)
    base_freq = _p(rng, 1600, 0.05) + trill * _p(rng, 200, 0.05)
    wave = np.sin(2 * math.pi * np.cumsum(base_freq) / SAMPLE_RATE)
    env = _envelope(t, _p(rng, 0.005, 0.10), _p(rng, 0.04, 0.10),
                    _p(rng, 0.08, 0.10), 0.55, _p(rng, 0.07, 0.10))
    return _make_sound(wave * env * volume * 0.55)


def _gen_bloop(volume: float, rng: random.Random | None = None) -> pygame.mixer.Sound:
    """Soft water drop: descending sine with quick decay."""
    duration = _p(rng, 0.22, 0.10)
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration))
    wave = _sweep(t, _p(rng, 520, 0.05), _p(rng, 180, 0.05))
    env = _envelope(t, _p(rng, 0.005, 0.10), _p(rng, 0.05, 0.10),
                    _p(rng, 0.06, 0.10), 0.35, _p(rng, 0.09, 0.10))
    return _make_sound(wave * env * volume * 0.60)


def _gen_pop(volume: float, rng: random.Random | None = None) -> pygame.mixer.Sound:
    """Light cartoon pop: brief noise burst with click."""
    duration = _p(rng, 0.10, 0.10)
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration))
    noise = np.random.uniform(-1, 1, len(t))
    click = np.sin(2 * math.pi * _p(rng, 300, 0.05) * t) * 0.5
    wave = noise * 0.7 + click
    env = _envelope(t, _p(rng, 0.002, 0.10), _p(rng, 0.02, 0.10),
                    _p(rng, 0.02, 0.10), 0.2, _p(rng, 0.06, 0.10))
    return _make_sound(wave * env * volume * 0.55)


def _gen_grunt(volume: float, rng: random.Random | None = None) -> pygame.mixer.Sound:
    """Low short grunt: deep FM pulse."""
    duration = _p(rng, 0.18, 0.10)
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration))
    wave = _sine_fm(t, carrier_hz=_p(rng, 120, 0.05),
                    mod_hz=_p(rng, 40, 0.05), mod_depth=_p(rng, 2.0, 0.03))
    env = _envelope(t, _p(rng, 0.01, 0.10), _p(rng, 0.04, 0.10),
                    _p(rng, 0.05, 0.10), 0.45, _p(rng, 0.08, 0.10))
    return _make_sound(wave * env * volume * 0.65)


def _gen_bell(volume: float, rng: random.Random | None = None) -> pygame.mixer.Sound:
    """Soft chime: clean high partial with long decay."""
    duration = _p(rng, 0.60, 0.10)
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration))
    fundamental = np.sin(2 * math.pi * _p(rng, 880, 0.05) * t)
    second      = np.sin(2 * math.pi * _p(rng, 1760, 0.05) * t) * 0.35
    third       = np.sin(2 * math.pi * _p(rng, 2640, 0.05) * t) * 0.15
    wave = fundamental + second + third
    env = _envelope(t, _p(rng, 0.005, 0.10), _p(rng, 0.05, 0.10),
                    _p(rng, 0.05, 0.10), 0.4, _p(rng, 0.50, 0.10))
    return _make_sound(wave * env * volume * 0.50)


def _gen_golden_kitten(volume: float, rng: random.Random | None = None) -> pygame.mixer.Sound:
    """Sparkly meow: kitten-style sweep with a bell harmonic on top."""
    duration = _p(rng, 0.50, 0.10)
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration))
    meow  = _sweep(t, _p(rng, 1000, 0.05), _p(rng, 620, 0.05))
    bell  = np.sin(2 * math.pi * _p(rng, 2200, 0.05) * t) * _p(rng, 0.30, 0.03)
    bell2 = np.sin(2 * math.pi * _p(rng, 3300, 0.05) * t) * _p(rng, 0.18, 0.03)
    twinkle = (1.0 + _p(rng, 0.20, 0.03) * np.sin(2 * math.pi * _p(rng, 14, 0.05) * t))
    wave = (meow * _p(rng, 0.65, 0.03) + bell + bell2) * twinkle
    env = _envelope(t, _p(rng, 0.02, 0.10), _p(rng, 0.10, 0.10),
                    _p(rng, 0.20, 0.10), 0.55, _p(rng, 0.18, 0.10))
    return _make_sound(wave * env * volume * 0.6)

# ---------------------------------------------------------------------------
# Registry of synthesis functions (used by SoundManager and build_sounds.py)
# ---------------------------------------------------------------------------

GENERATORS = {
    "kitten":        _gen_kitten,
    "turtle":        _gen_turtle,
    "duck":          _gen_duck,
    "rabbit":        _gen_rabbit,
    "hedgehog":      _gen_hedgehog,
    "squirrel":      _gen_squirrel,
    "otter":         _gen_otter,
    "panda":         _gen_panda,
    "unicorn":       _gen_unicorn,
    "golden_kitten": _gen_golden_kitten,
    # Extra preset profiles for custom critters
    "squeak":  _gen_squeak,
    "chirp":   _gen_chirp,
    "bloop":   _gen_bloop,
    "pop":     _gen_pop,
    "grunt":   _gen_grunt,
    "bell":    _gen_bell,
}

# Profiles available for selection in the UI (species sounds + extra presets)
EXTRA_PRESETS = ["squeak", "chirp", "bloop", "pop", "grunt", "bell"]
ALL_PROFILES  = list(GENERATORS.keys())

# ---------------------------------------------------------------------------
# Sound manager
# ---------------------------------------------------------------------------

class SoundManager:
    """
    Loads and caches animal sounds. Respects config volume and toggles.

    Loading priority (v1.7):
      1. Pre-generated WAVs in sounds/ (bundled exe or local dev after build_sounds.py)
      2. Numpy synthesis (local dev fallback)

    When all sounds are loaded from WAVs, volume changes call set_volume()
    directly rather than regenerating — faster and keeps the exe numpy-free.
    """

    def __init__(self):
        self._sounds: dict[str, pygame.mixer.Sound] = {}
        self._volume: float = 0.5
        self._enabled: bool = True
        self._wav_mode: bool = False   # True when all sounds loaded from WAV files
        self._preview_channel = None   # active preview Channel, stopped before next preview

    def init(self, config: dict) -> None:
        """Initialise pygame mixer and load or generate all sounds."""
        try:
            pygame.mixer.pre_init(frequency=SAMPLE_RATE, size=-16,
                                  channels=CHANNELS, buffer=512)
            pygame.mixer.init()
        except Exception as e:
            print(f"[sounds] Mixer init failed: {e}. Audio disabled.")
            self._enabled = False
            return

        self.apply_config(config)
        self._generate_all()

    def _generate_all(self) -> None:
        """Load sounds from WAVs if available; fall back to numpy synthesis."""
        self._sounds.clear()
        sounds_dir = _bundled_sounds_dir()
        loaded_from_wav = 0

        for species, gen_fn in GENERATORS.items():
            # --- Try WAV first ---
            if sounds_dir:
                wav_path = os.path.join(sounds_dir, f"{species}.wav")
                if os.path.isfile(wav_path):
                    try:
                        sound = pygame.mixer.Sound(wav_path)
                        sound.set_volume(self._volume)
                        self._sounds[species] = sound
                        loaded_from_wav += 1
                        continue
                    except Exception as e:
                        print(f"[sounds] WAV load failed for {species}: {e}")

            # --- Fall back to synthesis ---
            if _NUMPY_OK:
                try:
                    self._sounds[species] = gen_fn(self._volume)
                except Exception as e:
                    print(f"[sounds] Synthesis failed for {species}: {e}")
            else:
                print(f"[sounds] No WAV for '{species}' and numpy unavailable — sound skipped.")

        self._wav_mode = (loaded_from_wav == len(GENERATORS))
        if self._wav_mode:
            print(f"[sounds] Loaded {loaded_from_wav} sounds from pre-generated WAVs.")

    def apply_config(self, config: dict) -> None:
        """Update volume and enabled state from config."""
        self._enabled = config["audio"].get("sound_enabled", True)
        raw_vol = config["audio"].get("volume", 50)
        self._volume = max(0.0, min(1.0, raw_vol / 100.0))

        if not pygame.mixer.get_init():
            return

        if self._wav_mode:
            # WAV-loaded sounds: just update the volume on existing objects,
            # no need to regenerate.
            for sound in self._sounds.values():
                sound.set_volume(self._volume)
        else:
            # Synthesised sounds bake in the volume — regenerate at new level.
            self._generate_all()

    def register_custom(self, critter_id: str, profile: str, seed: int,
                        sound_file: str = "") -> None:
        """
        Generate and cache a sound for a custom critter.
        If sound_file is a non-empty path, loads from that file.
        Otherwise synthesises from profile with seed perturbation.
        Key stored as 'custom:<critter_id>'.
        """
        if not pygame.mixer.get_init():
            return
        key = f"custom:{critter_id}"
        # File takes priority over profile synthesis
        if sound_file:
            try:
                sound = pygame.mixer.Sound(sound_file)
                sound.set_volume(self._volume)
                self._sounds[key] = sound
                return
            except Exception as e:
                print(f"[sounds] Failed to load sound file '{sound_file}': {e}")
                # Fall through to profile synthesis
        if not _NUMPY_OK:
            print(f"[sounds] No sound file and numpy unavailable — sound skipped for {critter_id}.")
            return
        gen_fn = GENERATORS.get(profile, GENERATORS["kitten"])
        rng = random.Random(seed) if seed else None
        try:
            sound = gen_fn(self._volume, rng)
            self._sounds[key] = sound
        except Exception as e:
            print(f"[sounds] register_custom failed for {critter_id}: {e}")

    def unregister_custom(self, critter_id: str) -> None:
        """Remove a custom critter's sound from the cache."""
        self._sounds.pop(f"custom:{critter_id}", None)

    def play_preview(self, profile_or_path: str) -> None:
        """Play a sound once for preview purposes. Non-blocking, fire-and-forget."""
        if not self._enabled or not pygame.mixer.get_init():
            return
        # Stop any in-progress preview
        if self._preview_channel is not None:
            try:
                self._preview_channel.stop()
            except Exception:
                pass
        sound = None
        if os.path.isfile(profile_or_path):
            try:
                sound = pygame.mixer.Sound(profile_or_path)
                sound.set_volume(self._volume)
            except Exception as e:
                print(f"[sounds] Preview load failed: {e}")
        else:
            gen_fn = GENERATORS.get(profile_or_path)
            if gen_fn and _NUMPY_OK:
                try:
                    sound = gen_fn(self._volume)
                except Exception as e:
                    print(f"[sounds] Preview synthesis failed: {e}")
            elif not gen_fn:
                # Might be a cached custom sound key like "custom:abc"
                sound = self._sounds.get(profile_or_path)
        if sound:
            try:
                self._preview_channel = sound.play()
            except Exception as e:
                print(f"[sounds] Preview play failed: {e}")

    def play(self, species: str, config: dict) -> None:
        """Play the pop/throw sound for a species if enabled in config."""
        if not self._enabled:
            return
        if species.startswith("custom:"):
            # Per-custom-critter sound toggle stored in config["custom_animals"]
            critter_id = species[len("custom:"):]
            custom_cfg = config.get("custom_animals", {}).get(critter_id, {})
            if not custom_cfg.get("sound", True):
                return
        else:
            animal_cfg = config["animals"].get(species, {})
            if not animal_cfg.get("sound", True):
                return
        sound = self._sounds.get(species)
        if sound:
            try:
                sound.play()
            except Exception as e:
                print(f"[sounds] Play failed for {species}: {e}")
