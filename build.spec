# build.spec — PyInstaller spec for Critter Overlay App
# Run with: pyinstaller build.spec

import sys
from pathlib import Path

src = str(Path('src').resolve())

a = Analysis(
    [str(Path('src/main.py').resolve())],
    pathex=[src],
    binaries=[],
    datas=[],
    hiddenimports=[
        'pygame',
        'numpy',
        'keyboard',
        'tkinter',
        'tkinter.ttk',
        'winreg',
        'ctypes',
        'ctypes.wintypes',
    ],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=['matplotlib', 'scipy', 'PIL'],
    noarchive=False,
)

pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name='CritterOverlay',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=False,          # no console window
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon=None,              # add a .ico file path here if you have one
    uac_admin=False,        # set True if keyboard hotkeys require elevation
)
