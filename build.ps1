# build.ps1 — Critter Overlay v1.7 build script
#
# Prerequisites (see BUILD.md for full setup instructions):
#   pip install -r requirements.txt
#   pip install -r requirements-build.txt
#   Inno Setup 6  https://jrsoftware.org/isinfo.php
#
# Usage:
#   .\build.ps1              # builds version from installer/version_info.txt (1.7.0)
#   .\build.ps1 -Version 1.7.1

param(
    [string]$Version = "1.7.0"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = $PSScriptRoot

Write-Host ""
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "  Critter Overlay  v$Version  Build Script" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

# ── Step 1: Check prerequisites ───────────────────────────────────────────────

Write-Host "[1/6] Checking prerequisites..." -ForegroundColor Yellow

$pyExe = Get-Command python -ErrorAction SilentlyContinue
if (-not $pyExe) {
    Write-Error "Python not found on PATH. Install Python 3.8+ and try again."
    exit 1
}
Write-Host "  Python : $($pyExe.Source)"

$pyInstaller = Get-Command pyinstaller -ErrorAction SilentlyContinue
if (-not $pyInstaller) {
    Write-Error @"
PyInstaller not found. Install it with:
    pip install -r requirements-build.txt
"@
    exit 1
}
Write-Host "  PyInstaller : $($pyInstaller.Source)"

# Search common Inno Setup install locations
$innoSearchPaths = @(
    "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
    "C:\Program Files\Inno Setup 6\ISCC.exe",
    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
)
$iscc = $null
foreach ($p in $innoSearchPaths) {
    if (Test-Path $p) { $iscc = $p; break }
}
if (-not $iscc) {
    Write-Error @"
Inno Setup 6 compiler (ISCC.exe) not found.
Download and install from: https://jrsoftware.org/isinfo.php
Then rerun this script.
"@
    exit 1
}
Write-Host "  Inno Setup : $iscc"
Write-Host ""

# ── Step 2: Generate icon if missing ─────────────────────────────────────────

Write-Host "[2/6] Icon..." -ForegroundColor Yellow
$iconPath = Join-Path $ProjectRoot "installer\icon.ico"
if (-not (Test-Path $iconPath)) {
    Write-Host "  Generating icon..."
    Set-Location $ProjectRoot
    python make_icon.py
    if ($LASTEXITCODE -ne 0) { Write-Error "make_icon.py failed"; exit 1 }
} else {
    Write-Host "  Icon already present — skipping generation."
}
Write-Host ""

# ── Step 3: Pre-generate sound WAVs ──────────────────────────────────────────

Write-Host "[3/6] Pre-generating sound WAVs (removes numpy from bundle)..." -ForegroundColor Yellow
Set-Location $ProjectRoot
python build_sounds.py
if ($LASTEXITCODE -ne 0) { Write-Error "build_sounds.py failed"; exit 1 }
Write-Host ""

# ── Step 4: PyInstaller ───────────────────────────────────────────────────────

Write-Host "[4/6] Running PyInstaller (onedir)..." -ForegroundColor Yellow
Set-Location $ProjectRoot

# Clean previous outputs
if (Test-Path "build") { Remove-Item -Recurse -Force "build" }
if (Test-Path "dist")  { Remove-Item -Recurse -Force "dist"  }

pyinstaller CritterOverlay.spec --noconfirm
if ($LASTEXITCODE -ne 0) { Write-Error "PyInstaller failed"; exit 1 }
Write-Host ""

# ── Step 5: Audit dist/ for required DLLs ────────────────────────────────────

Write-Host "[5/6] Auditing dist\CritterOverlay\..." -ForegroundColor Yellow

$exePath = Join-Path $ProjectRoot "dist\CritterOverlay\CritterOverlay.exe"
if (-not (Test-Path $exePath)) {
    Write-Error "EXE not found at $exePath — PyInstaller did not produce expected output."
    exit 1
}
Write-Host "  CritterOverlay.exe found." -ForegroundColor Green

# SDL2 DLLs: pygame bundles these via its hook, but verify
$sdlDlls = @("SDL2.dll", "SDL2_mixer.dll")
$missingDlls = @()
foreach ($dll in $sdlDlls) {
    $found = Get-ChildItem "dist\CritterOverlay\" -Filter $dll -Recurse -ErrorAction SilentlyContinue
    if ($found) {
        Write-Host "  $dll found." -ForegroundColor Green
    } else {
        Write-Warning "  $dll NOT found in dist\. If the app fails to launch, add an explicit binaries entry for it in CritterOverlay.spec."
        $missingDlls += $dll
    }
}

# Verify WAVs made it into the bundle
$bundledWavs = Get-ChildItem "dist\CritterOverlay\sounds\" -Filter "*.wav" -ErrorAction SilentlyContinue
if ($bundledWavs) {
    Write-Host "  $($bundledWavs.Count) WAV files bundled in sounds\." -ForegroundColor Green
} else {
    Write-Warning "  No WAV files found in dist\CritterOverlay\sounds\. Sound will be unavailable in the bundle."
}
Write-Host ""

# ── Step 6: Inno Setup ───────────────────────────────────────────────────────

Write-Host "[6/6] Building installer with Inno Setup..." -ForegroundColor Yellow
Set-Location $ProjectRoot
& $iscc /DMyAppVersion=$Version "installer\installer.iss"
if ($LASTEXITCODE -ne 0) { Write-Error "Inno Setup compilation failed"; exit 1 }

$installerOut = Join-Path $ProjectRoot "installer\output\CritterOverlaySetup-$Version.exe"
if (-not (Test-Path $installerOut)) {
    Write-Error "Installer not found at expected path: $installerOut"
    exit 1
}

# ── Done ──────────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "=============================================" -ForegroundColor Green
Write-Host "  BUILD COMPLETE" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Installer : $installerOut" -ForegroundColor Green
Write-Host "  Bundled EXE : $exePath"
if ($missingDlls.Count -gt 0) {
    Write-Host ""
    Write-Host "  WARNING: Missing DLLs: $($missingDlls -join ', ')" -ForegroundColor Yellow
    Write-Host "  Test launch on a machine without SDL installed before releasing." -ForegroundColor Yellow
}
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Smoke test: run  dist\CritterOverlay\CritterOverlay.exe"
Write-Host "     Verify: tray icon appears, animals spawn within 30s, sounds play,"
Write-Host "     settings window opens, Ctrl+Shift+P works."
Write-Host ""
Write-Host "  2. Install on clean Windows 10 VM — full checklist in v1.7-v1.8 Dev Handoff.md sec. 2"
Write-Host "  3. Install on clean Windows 11 VM — same checklist"
Write-Host "  4. Test upgrade: install this, modify settings, build v1.7.1, install over the top,"
Write-Host "     verify settings preserved."
Write-Host "  5. Document SmartScreen warning in release notes before distributing."
Write-Host ""
