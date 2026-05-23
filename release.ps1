# release.ps1 - Full release pipeline for Critter Overlay
#
# Bumps version files, builds the installer, commits, pushes, and creates the
# GitHub release in one command. build.ps1 handles the PyInstaller + Inno Setup
# step; this script owns everything around it.
#
# Usage:
#   .\release.ps1 -Version 1.9.1 -Title "fix startup mutex lockout"
#   .\release.ps1 -Version 2.0.0 -Title "critter sharing" -NotesFile release-notes-v2.0.md
#
# Prerequisites: Python, PyInstaller, Inno Setup 6, gh CLI (authenticated)

param(
    [Parameter(Mandatory=$true)]
    [string]$Version,

    [Parameter(Mandatory=$true)]
    [string]$Title,

    [string]$NotesFile = ""
)

$ErrorActionPreference = "Stop"
$ProjectRoot = $PSScriptRoot

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

function Step([string]$msg) {
    Write-Host ""
    Write-Host $msg -ForegroundColor Cyan
}

function Ok([string]$msg)   { Write-Host "  $msg" -ForegroundColor Green }
function Fail([string]$msg) { Write-Error $msg; exit 1 }

# ---------------------------------------------------------------------------
# [0] Validate version format
# ---------------------------------------------------------------------------

Step "[0] Validating inputs..."

if ($Version -notmatch '^\d+\.\d+\.\d+$') {
    Fail "Version must be X.Y.Z (e.g. 1.9.1). Got: $Version"
}

$parts   = $Version -split '\.'
$tuple   = "($($parts[0]), $($parts[1]), $($parts[2]), 0)"
$vstring = "$Version.0"

Ok "Version : $Version"
Ok "Title   : $Title"
if ($NotesFile) {
    if (-not (Test-Path $NotesFile)) { Fail "NotesFile not found: $NotesFile" }
    Ok "Notes   : $NotesFile"
} else {
    Ok "Notes   : auto-generated from commits"
}

# ---------------------------------------------------------------------------
# [1] Prerequisites
# ---------------------------------------------------------------------------

Step "[1] Checking prerequisites..."

foreach ($cmd in @("python","pyinstaller")) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Fail "$cmd not found on PATH."
    }
    Ok "$cmd found"
}

$innoSearchPaths = @(
    "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
    "C:\Program Files\Inno Setup 6\ISCC.exe",
    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
)
$isccFound = $false
foreach ($p in $innoSearchPaths) { if (Test-Path $p) { $isccFound = $true; break } }
if (-not $isccFound) { Fail "Inno Setup 6 (ISCC.exe) not found." }
Ok "Inno Setup found"

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Fail "gh CLI not found. Install with: winget install GitHub.cli"
}
$ghStatus = gh auth status 2>&1
if ($LASTEXITCODE -ne 0) { Fail "gh is not authenticated. Run: gh auth login" }
Ok "gh authenticated"

# ---------------------------------------------------------------------------
# [2] Git working tree must be clean
# ---------------------------------------------------------------------------

Step "[2] Checking git state..."

Set-Location $ProjectRoot
$dirty = git status --porcelain
if ($dirty) {
    Write-Host ""
    Write-Host $dirty
    Fail "Working tree is not clean. Commit or stash changes before releasing."
}
Ok "Working tree clean"

$currentBranch = git rev-parse --abbrev-ref HEAD
if ($currentBranch -ne "main") {
    Fail "Not on main branch (currently on '$currentBranch'). Releases must ship from main."
}
Ok "On main"

# ---------------------------------------------------------------------------
# [3] Bump version files
# ---------------------------------------------------------------------------

Step "[3] Bumping version files to $Version..."

# src/version.py
$versionPy = Join-Path $ProjectRoot "src\version.py"
(Get-Content $versionPy) -replace 'APP_VERSION\s*=\s*"[^"]*"', "APP_VERSION = `"$Version`"" |
    Set-Content $versionPy -Encoding utf8
Ok "src/version.py -> $Version"

# installer/version_info.txt  (tuple and string fields)
$viFile = Join-Path $ProjectRoot "installer\version_info.txt"
$vi = Get-Content $viFile -Raw
$vi = $vi -replace 'filevers=\(\d+,\s*\d+,\s*\d+,\s*\d+\)', "filevers=$tuple"
$vi = $vi -replace 'prodvers=\(\d+,\s*\d+,\s*\d+,\s*\d+\)', "prodvers=$tuple"
$vi = $vi -replace "u'FileVersion',\s*u'[^']*'",    "u'FileVersion',      u'$vstring'"
$vi = $vi -replace "u'ProductVersion',\s*u'[^']*'", "u'ProductVersion',   u'$vstring'"
Set-Content $viFile $vi -Encoding utf8
Ok "installer/version_info.txt -> $vstring"

# ---------------------------------------------------------------------------
# [4] Build
# ---------------------------------------------------------------------------

Step "[4] Building installer (build.ps1 -Version $Version)..."

& "$ProjectRoot\build.ps1" -Version $Version
if ($LASTEXITCODE -ne 0) { Fail "build.ps1 failed." }

$installerPath = Join-Path $ProjectRoot "installer\output\CritterOverlaySetup-$Version.exe"
if (-not (Test-Path $installerPath)) {
    Fail "Installer not found at expected path: $installerPath"
}
Ok "Installer ready: $installerPath"

# ---------------------------------------------------------------------------
# [5] Commit and push
# ---------------------------------------------------------------------------

Step "[5] Committing version bump..."

git add src\version.py installer\version_info.txt sounds\*.wav
git commit -m "release: v$Version - $Title"
if ($LASTEXITCODE -ne 0) { Fail "git commit failed." }
Ok "Committed"

git push origin main
if ($LASTEXITCODE -ne 0) { Fail "git push failed." }
Ok "Pushed to main"

# ---------------------------------------------------------------------------
# [6] GitHub release
# ---------------------------------------------------------------------------

Step "[6] Creating GitHub release v$Version..."

$releaseArgs = @(
    "release", "create", "v$Version",
    $installerPath,
    "--title", "v$Version - $Title"
)

if ($NotesFile) {
    $releaseArgs += @("--notes-file", $NotesFile)
} else {
    $releaseArgs += "--generate-notes"
}

& gh @releaseArgs
if ($LASTEXITCODE -ne 0) { Fail "gh release create failed." }

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------

Write-Host ""
Write-Host "=============================================" -ForegroundColor Green
Write-Host "  RELEASED v$Version" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green
Write-Host ""
Write-Host "  https://github.com/hstagg/critter-overlay/releases/tag/v$Version" -ForegroundColor Green
Write-Host ""
Write-Host "Next: smoke-test the installer from the release page." -ForegroundColor Cyan
Write-Host ""
