# CritterOverlay.spec — PyInstaller spec for Critter Overlay v1.7+
#
# Build mode: --onedir  (produces dist/CritterOverlay/ directory)
# Reason: avoids extraction overhead on every launch and reduces AV false positives.
# Inno Setup wraps the directory into a single installer exe.
#
# Run directly:  pyinstaller CritterOverlay.spec
# Or via build script:  .\build.ps1

import glob
import os
from pathlib import Path

# ---------------------------------------------------------------------------
# Source layout
# ---------------------------------------------------------------------------

_here = os.path.dirname(os.path.abspath(SPEC))
src = str(Path(os.path.join(_here, 'src')).resolve())

# Pre-generated WAV files (produced by build_sounds.py before this runs).
# If sounds/ doesn't exist yet, datas is empty and the app falls back to
# numpy synthesis (which won't work in the bundle -- run build_sounds.py first).
_wav_files = glob.glob(os.path.join(_here, 'sounds', '*.wav'))
_wav_datas = [(f, 'sounds') for f in _wav_files]

if not _wav_files:
    print(
        '\n[spec WARNING] No pre-generated WAV files found in sounds/.\n'
        '  Run:  python build_sounds.py\n'
        '  before running pyinstaller, or sound will be unavailable in the bundle.\n'
    )

# ---------------------------------------------------------------------------
# Analysis
# ---------------------------------------------------------------------------

a = Analysis(
    [str(Path(os.path.join(_here, 'src', 'main.py')).resolve())],
    pathex=[src],
    binaries=[],
    datas=_wav_datas,
    hiddenimports=[
        # pystray needs its Win32 backend collected explicitly
        'pystray._win32',
        'pystray._util.win32',
        # Pillow's Tkinter bridge (settings_window.py uses ImageTk)
        'PIL._tkinter_finder',
        # Standard library bits that PyInstaller sometimes misses
        'winreg',
        'ctypes',
        'ctypes.wintypes',
        # keyboard hook — collected automatically but listed for clarity
        'keyboard',
    ],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[
        # numpy is only needed for sound synthesis; if WAVs are bundled we
        # don't need it at runtime. Remove to cut ~25 MB from the bundle.
        # If build_sounds.py wasn't run, sounds will be silently skipped.
        'numpy',
        # Unused stdlib / package internals
        'unittest',
        'test',
        'tkinter.test',
        'pydoc_data',
        'pygame.tests',
        # Other heavy packages that nothing here imports
        'scipy',
        'matplotlib',
        'IPython',
        'setuptools',
        'pkg_resources',
    ],
    noarchive=False,
)

# ---------------------------------------------------------------------------
# SDL DLL audit (printed at spec load time — check dist/ after first build)
# ---------------------------------------------------------------------------

print('\n[spec] Expected SDL DLLs will be checked after build in build.ps1.\n')

# ---------------------------------------------------------------------------
# PYZ + EXE + COLLECT (onedir)
# ---------------------------------------------------------------------------

pyz = PYZ(a.pure, a.zipped_data)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,     # binaries go into COLLECT, not into EXE
    name='CritterOverlay',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    console=False,             # no console window — this is a GUI app
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon='installer/icon.ico',
    version='installer/version_info.txt',
)

coll = COLLECT(
    exe,
    a.binaries,
    a.zipfiles,
    a.datas,
    strip=False,
    upx=True,
    upx_exclude=[],
    name='CritterOverlay',
)
