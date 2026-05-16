@echo off
REM build.bat — One-click build for Critter Overlay
REM Prerequisites: Python 3.11+, pip install -r requirements.txt

echo.
echo =========================================
echo   Critter Overlay — Build Script
echo =========================================
echo.

REM Install / upgrade deps
pip install -r requirements.txt --quiet

REM Clean previous build
if exist dist rmdir /s /q dist
if exist build rmdir /s /q build

REM Run PyInstaller
pyinstaller build.spec --noconfirm

echo.
if exist dist\CritterOverlay.exe (
    echo SUCCESS! Executable at: dist\CritterOverlay.exe
) else (
    echo BUILD FAILED. Check output above for errors.
)
echo.
pause
