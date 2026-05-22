# build.ps1 - Critter Overlay v1.7 build script
#
# Prerequisites (see BUILD.md for full setup instructions):
#   pip install -r requirements.txt
#   pip install -r requirements-build.txt
#   Inno Setup 6  https://jrsoftware.org/isinfo.php
#
# Usage:
#   .\build.ps1              # builds version 1.7.0
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

# --- Step 1: Check prerequisites ---

Write-Host "[1/6] Checking prerequisites..." -ForegroundColor Yellow

$pyExe = Get-Command python -ErrorAction SilentlyContinue
if (-not $pyExe) {
    Write-Error "Python not found on PATH. Install Python 3.8+ and try again."
    exit 1
}
Write-Host "  Python : $($pyExe.Source)"

$pyInstaller = Get-Command pyinstaller -ErrorAction SilentlyContinue
if (-not $pyInstaller) {
    Write-Error "PyInstaller not found. Install it with: pip install -r requirements-build.txt"
    exit 1
}
Write-Host "  PyInstaller : $($pyInstaller.Source)"

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
    Write-Error "Inno Setup 6 (ISCC.exe) not found. Download from: https://jrsoftware.org/isinfo.php"
    exit 1
}
Write-Host "  Inno Setup : $iscc"
Write-Host ""

# --- Step 2: Generate icon if missing ---

Write-Host "[2/6] Icon..." -ForegroundColor Yellow
$iconPath = Join-Path $ProjectRoot "installer\icon.ico"
if (-not (Test-Path $iconPath)) {
    Write-Host "  Generating icon..."
    Set-Location $ProjectRoot
    python make_icon.py
    if ($LASTEXITCODE -ne 0) { Write-Error "make_icon.py failed"; exit 1 }
} else {
    Write-Host "  Icon already present - skipping generation."
}
Write-Host ""

# --- Step 3: Pre-generate sound WAVs ---

Write-Host "[3/6] Pre-generating sound WAVs (removes numpy from bundle)..." -ForegroundColor Yellow
Set-Location $ProjectRoot
python scripts\build_sounds.py
if ($LASTEXITCODE -ne 0) { Write-Error "build_sounds.py failed"; exit 1 }
Write-Host ""

# --- Step 4: PyInstaller ---

Write-Host "[4/6] Running PyInstaller (onedir)..." -ForegroundColor Yellow
Set-Location $ProjectRoot

if (Test-Path "build") { Remove-Item -Recurse -Force "build" }
if (Test-Path "dist")  { Remove-Item -Recurse -Force "dist"  }

pyinstaller CritterOverlay.spec --noconfirm
if ($LASTEXITCODE -ne 0) { Write-Error "PyInstaller failed"; exit 1 }
Write-Host ""

# --- Step 5: Audit dist/ ---

Write-Host "[5/6] Auditing dist\CritterOverlay\..." -ForegroundColor Yellow

$exePath = Join-Path $ProjectRoot "dist\CritterOverlay\CritterOverlay.exe"
if (-not (Test-Path $exePath)) {
    Write-Error "EXE not found at $exePath - PyInstaller did not produce expected output."
    exit 1
}
Write-Host "  CritterOverlay.exe found." -ForegroundColor Green

$sdlDlls = @("SDL2.dll", "SDL2_mixer.dll")
$missingDlls = @()
foreach ($dll in $sdlDlls) {
    $found = Get-ChildItem "dist\CritterOverlay\" -Filter $dll -Recurse -ErrorAction SilentlyContinue
    if ($found) {
        Write-Host "  $dll found." -ForegroundColor Green
    } else {
        Write-Warning "  $dll NOT found in dist\. If the app fails to launch, add an explicit binaries entry in CritterOverlay.spec."
        $missingDlls += $dll
    }
}

# PyInstaller 6 puts datas in _internal/ subdirectory
$bundledWavs = Get-ChildItem "dist\CritterOverlay\_internal\sounds\" -Filter "*.wav" -ErrorAction SilentlyContinue
if ($bundledWavs) {
    Write-Host "  $($bundledWavs.Count) WAV files bundled in _internal\sounds\." -ForegroundColor Green
} else {
    Write-Warning "  No WAV files found in dist\CritterOverlay\_internal\sounds\. Sound will be unavailable."
}
Write-Host ""

# --- Step 6: Inno Setup ---

Write-Host "[6/6] Building installer with Inno Setup..." -ForegroundColor Yellow
Set-Location $ProjectRoot
& $iscc /DMyAppVersion=$Version "installer\installer.iss"
if ($LASTEXITCODE -ne 0) { Write-Error "Inno Setup compilation failed"; exit 1 }

$installerOut = Join-Path $ProjectRoot "installer\output\CritterOverlaySetup-$Version.exe"
if (-not (Test-Path $installerOut)) {
    Write-Error "Installer not found at expected path: $installerOut"
    exit 1
}

# --- Done ---

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
    Write-Host "  Test on a machine without SDL installed before releasing." -ForegroundColor Yellow
}
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Smoke test: dist\CritterOverlay\CritterOverlay.exe"
Write-Host "     - Tray paw icon appears"
Write-Host "     - Animals spawn within 30s"
Write-Host "     - Settings window opens"
Write-Host "     - Ctrl+Shift+P pauses/resumes"
Write-Host "     - Pop sounds play"
Write-Host ""
Write-Host "  2. Install + test on clean Windows 10 VM"
Write-Host "  3. Install + test on clean Windows 11 VM"
Write-Host ""
