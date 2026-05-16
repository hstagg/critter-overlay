"""
sounds.py — Procedural sound generation for Critter Overlay App
Generates cute animal sounds using numpy sine-wave synthesis.
No external audio files required.
"""

import math
import numpy as np
import pygame

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

SAMPLE_RATE = 22050
CHANNELS = 2  # stereo

# ---------------------------------------------------------------------------
# Low-level synthesis helpers
# ---------------------------------------------------------------------------

def _make_sound(wave: np.ndarray) -> pygame.mixer.Sound:
    """Convert a float32 mono wave (-1..1) into a pygame Sound (stereo int16)."""
    wave = np.clip(wave, -1.0, 1.0)
    samples = (wave * 32767).astype(np.int16)
    stereo = np.column_stack([samples, samples])
    return pygame.sndarray.make_sound(stereo)


def _envelope(t: np.ndarray, attack: float, decay: float, sustain: float,
               sustain_level: float, release: float) -> np.ndarray:
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


def _sine_fm(t: np.ndarray, carrier_hz: float, mod_hz: float,
              mod_depth: float) -> np.ndarray:
    """Frequency-modulated sine wave."""
    modulator = mod_depth * np.sin(2 * np.pi * mod_hz * t)
    return np.sin(2 * np.pi * carrier_hz * t + modulator)


def _sweep(t: np.ndarray, freq_start: float, freq_end: float) -> np.ndarray:
    """Sine wave with linearly swept frequency."""
    freq = freq_start + (freq_end - freq_start) * (t / max(t[-1], 1e-6))
    return np.sin(2 * np.pi * np.cumsum(freq) / SAMPLE_RATE)


# ---------------------------------------------------------------------------
# Per-animal sound generators
# ---------------------------------------------------------------------------

def _gen_kitten(volume: float) -> pygame.mixer.Sound:
    """Soft meow: falling pitch sweep with gentle envelope."""
    duration = 0.35
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration))
    wave = _sweep(t, 900, 550)
    env = _envelope(t, 0.02, 0.08, 0.15, 0.6, 0.10)
    return _make_sound(wave * env * volume * 0.7)


def _gen_turtle(volume: float) -> pygame.mixer.Sound:
    """Gentle hiss: low-frequency breathiness with noise."""
    duration = 0.30
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration))
    noise = np.random.uniform(-1, 1, len(t))
    tone = np.sin(2 * np.pi * 180 * t) * 0.3
    wave = noise * 0.6 + tone
    env = _envelope(t, 0.04, 0.05, 0.15, 0.4, 0.06)
    return _make_sound(wave * env * volume * 0.5)


def _gen_duck(volume: float) -> pygame.mixer.Sound:
    """Cheerful quack: sharp FM burst."""
    duration = 0.25
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration))
    wave = _sine_fm(t, carrier_hz=450, mod_hz=80, mod_depth=4.0)
    env = _envelope(t, 0.01, 0.06, 0.08, 0.5, 0.10)
    return _make_sound(wave * env * volume * 0.65)


def _gen_rabbit(volume: float) -> pygame.mixer.Sound:
    """Soft squeak: high brief chirp."""
    duration = 0.20
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration))
    wave = _sweep(t, 1400, 1100)
    env = _envelope(t, 0.01, 0.04, 0.05, 0.4, 0.10)
    return _make_sound(wave * env * volume * 0.55)


def _gen_hedgehog(volume: float) -> pygame.mixer.Sound:
    """Snuffle: low purring with slight noise texture."""
    duration = 0.28
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration))
    tone = np.sin(2 * np.pi * 220 * t) + 0.4 * np.sin(2 * np.pi * 440 * t)
    noise = np.random.uniform(-1, 1, len(t)) * 0.2
    wave = tone + noise
    env = _envelope(t, 0.03, 0.06, 0.12, 0.5, 0.07)
    return _make_sound(wave * env * volume * 0.45)


def _gen_squirrel(volume: float) -> pygame.mixer.Sound:
    """Quick chatter: two-tone rapid chirp."""
    duration = 0.22
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration))
    wave = np.sin(2 * np.pi * 1100 * t) * (0.5 + 0.5 * np.sin(2 * np.pi * 30 * t))
    env = _envelope(t, 0.005, 0.05, 0.08, 0.6, 0.08)
    return _make_sound(wave * env * volume * 0.60)


def _gen_otter(volume: float) -> pygame.mixer.Sound:
    """Playful squeak: bouncy FM chirp."""
    duration = 0.28
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration))
    wave = _sine_fm(t, carrier_hz=700, mod_hz=25, mod_depth=3.0)
    env = _envelope(t, 0.01, 0.05, 0.12, 0.55, 0.10)
    return _make_sound(wave * env * volume * 0.60)


def _gen_panda(volume: float) -> pygame.mixer.Sound:
    """Gentle squeak: soft falling tone."""
    duration = 0.32
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration))
    wave = _sweep(t, 600, 400) + 0.3 * _sweep(t, 1200, 800)
    env = _envelope(t, 0.03, 0.06, 0.12, 0.5, 0.11)
    return _make_sound(wave * env * volume * 0.55)


def _gen_unicorn(volume: float) -> pygame.mixer.Sound:
    """Magical chime: bright stacked harmonics rising into a shimmer."""
    duration = 0.55
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration))
    # Major-chord-ish stack with a gentle upward sweep
    base = _sweep(t, 880, 1200)              # A5 → ~D6
    third = _sweep(t, 1100, 1500)            # major-3rd above
    fifth = _sweep(t, 1320, 1800)
    high = np.sin(2 * np.pi * 2640 * t) * 0.25
    shimmer = np.sin(2 * np.pi * 18 * t) * 0.15  # tremolo
    wave = (base * 0.55 + third * 0.30 + fifth * 0.20 + high) * (1.0 + shimmer)
    env = _envelope(t, 0.02, 0.10, 0.30, 0.55, 0.18)
    return _make_sound(wave * env * volume * 0.55)


def _gen_golden_kitten(volume: float) -> pygame.mixer.Sound:
    """Sparkly meow: kitten-style sweep with a bell harmonic on top."""
    duration = 0.50
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration))
    meow = _sweep(t, 1000, 620)
    bell = np.sin(2 * np.pi * 2200 * t) * 0.30
    bell2 = np.sin(2 * np.pi * 3300 * t) * 0.18
    twinkle = (1.0 + 0.20 * np.sin(2 * np.pi * 14 * t))
    wave = (meow * 0.65 + bell + bell2) * twinkle
    env = _envelope(t, 0.02, 0.10, 0.20, 0.55, 0.18)
    return _make_sound(wave * env * volume * 0.6)


# ---------------------------------------------------------------------------
# Sound manager class
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
}


class SoundManager:
    """Generates and caches animal sounds. Respects config volume and toggles."""

    def __init__(self):
        self._sounds: dict[str, pygame.mixer.Sound] = {}
        self._volume: float = 0.5
        self._enabled: bool = True

    def init(self, config: dict) -> None:
        """Initialise pygame mixer and pre-generate all sounds."""
        try:
            pygame.mixer.pre_init(frequency=SAMPLE_RATE, size=-16, channels=CHANNELS, buffer=512)
            pygame.mixer.init()
        except Exception as e:
            print(f"[sounds] Mixer init failed: {e}. Audio disabled.")
            self._enabled = False
            return

        self.apply_config(config)
        self._generate_all()

    def _generate_all(self) -> None:
        """Generate (or regenerate) all animal sounds at current volume."""
        self._sounds.clear()
        for species, gen_fn in GENERATORS.items():
            try:
                self._sounds[species] = gen_fn(self._volume)
            except Exception as e:
                print(f"[sounds] Failed to generate {species} sound: {e}")

    def apply_config(self, config: dict) -> None:
        """Update volume and enabled state from config."""
        self._enabled = config["audio"].get("sound_enabled", True)
        raw_vol = config["audio"].get("volume", 50)
        self._volume = max(0.0, min(1.0, raw_vol / 100.0))
        # Regenerate sounds at new volume if mixer is up
        if pygame.mixer.get_init():
            self._generate_all()

    def play(self, species: str, config: dict) -> None:
        """Play the sound for a species if enabled in config."""
        if not self._enabled:
            return
        animal_cfg = config["animals"].get(species, {})
        if not animal_cfg.get("sound", True):
            return
        sound = self._sounds.get(species)
        if sound:
            try:
                sound.play()
            except Exception as e:
                print(f"[sounds] Play failed for {species}: {e}")
