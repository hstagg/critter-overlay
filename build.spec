# build.spec — PyInstaller spec for Critter Overlay App
# Produces a onedir build at dist/CritterOverlay/ which Inno Setup then wraps.
# Run with: pyinstaller build.spec  (from the project root)

from pathlib import Path

src = str(Path('src').resolve())

a = Analysis(
    [str(Path('src/main.py').resolve())],
    pathex=[src],
    binaries=[],
    datas=[],
    hiddenimports=[
        # pystray Windows backend
        'pystray._win32',
        'pystray._util',
        'pystray._util.win32',
        # PIL / Pillow
        'PIL',
        'PIL.Image',
        'PIL.ImageChops',
        'PIL.ImageDraw',
        'PIL.ImageFilter',
        'PIL.ImageSequence',
        'PIL.ImageTk',
        'PIL._tkinter_finder',
        # custom_critters package
        'custom_critters',
        'custom_critters.bg_removal',
        'custom_critters.import_pipeline',
        'custom_critters.masks',
        'custom_critters.palette',
        'custom_critters.procedural',
        'custom_critters.registry',
        'custom_critters.storage',
        # stdlib
        'tkinter',
        'tkinter.ttk',
        'winreg',
        'ctypes',
        'ctypes.wintypes',
    ],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=['matplotlib', 'scipy'],
    noarchive=False,
)

pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    [],          # onedir: binaries/datas go to COLLECT, not EXE
    exclude_binaries=True,
    name='CritterOverlay',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    icon='installer/icon.ico',
    uac_admin=False,
)

coll = COLLECT(
    exe,
    a.binaries,
    a.datas,
    strip=False,
    upx=True,
    upx_exclude=[],
    name='CritterOverlay',
)
