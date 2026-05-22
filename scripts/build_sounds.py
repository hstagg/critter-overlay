"""
build_sounds.py  —  Pre-generate WAV files for all animal species.

Run before building the installer:
    python build_sounds.py

Output: sounds/<species>.wav  (one per animal, synthesised at volume=1.0)

Why: PyInstaller bundles these WAVs and sounds.py loads them at runtime
instead of synthesising with numpy, so the final exe has no numpy dependency.
This cuts ~25 MB from the installer.

The WAV files are small (< 15 KB each, ~130 KB total) and are checked into
the repo so teammates don't need to regenerate them unless sounds.py changes.
"""

import os
import sys
import wave

# Make src/ importable (this script lives in scripts/, so go up one level)
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "src"))

import pygame

# sounds.py imports numpy at the top level; that's fine here because this
# script runs on the dev machine where numpy is available.
from sounds import GENERATORS, SAMPLE_RATE, CHANNELS


def _write_wav(path: str, sound: pygame.mixer.Sound) -> None:
    """Write a pygame Sound to a WAV file using its raw sample bytes."""
    raw = sound.get_raw()
    with wave.open(path, "wb") as wf:
        wf.setnchannels(CHANNELS)
        wf.setsampwidth(2)           # 16-bit samples
        wf.setframerate(SAMPLE_RATE)
        wf.writeframes(raw)


def main() -> None:
    out_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "sounds")
    os.makedirs(out_dir, exist_ok=True)

    # Initialise mixer so pygame.mixer.Sound objects can be created
    pygame.mixer.pre_init(frequency=SAMPLE_RATE, size=-16,
                          channels=CHANNELS, buffer=512)
    pygame.mixer.init()

    total_bytes = 0
    for species, gen_fn in GENERATORS.items():
        # Generate at volume=1.0; SoundManager.set_volume() handles attenuation
        # at runtime so we don't bake a fixed volume into the WAV.
        sound = gen_fn(volume=1.0)
        wav_path = os.path.join(out_dir, f"{species}.wav")
        _write_wav(wav_path, sound)
        size = os.path.getsize(wav_path)
        total_bytes += size
        print(f"  {species:<16} {wav_path}  ({size // 1024} KB)")

    pygame.mixer.quit()

    print(f"\nGenerated {len(GENERATORS)} WAV files in {out_dir}/")
    print(f"Total size: {total_bytes // 1024} KB")
    print("\nThese files are bundled into the installer by CritterOverlay.spec.")
    print("Check them in to git — they change only when sounds.py synthesis changes.")


if __name__ == "__main__":
    main()
