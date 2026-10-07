# release.ps1 - Full release pipeline for Critter Overlay (v3, the Godot build)
#
# Bumps the version, builds the player installer, commits, pushes, and creates
# the GitHub release in one command. build-v3.ps1 handles the native DLL,
# Godot export, exe version stamp and Inno Setup step; this script owns
# everything around it.
#
# Usage:
#   .\release.ps1 -Version 3.0.1 -Title "fix startup mutex lockout"
#   .\release.ps1 -Version 3.1.0 -Title "critter sharing" -NotesFile release-notes-v3.1.md
#   .\release.ps1 -Version 3.0.1 -Title "..." -SkipNative    # reuse the DLL in godot\bin
#
# Prerequisites (build-v3.ps1 finds them on PATH, by env var, or in the
# usual places): Godot 4.7 with export templates (GODOT), rcedit (RCEDIT),
# Inno Setup 6 (ISCC), SCons for the native DLL unless -SkipNative, and the
# gh CLI, authenticated.
#
# Always the player build: the Admin page (build-v3.ps1 -Admin) is never
# released, and step [4] refuses an installer whose exe carries it.

param(
    [Parameter(Mandatory=$true)]
    [string]$Version,

    [Parameter(Mandatory=$true)]
    [string]$Title,

    [string]$NotesFile = "",

    [switch]$SkipNative
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
# [0] Validate inputs
# ---------------------------------------------------------------------------

Step "[0] Validating inputs..."

if ($Version -notmatch '^\d+\.\d+\.\d+$') {
    Fail "Version must be X.Y.Z (e.g. 3.0.1). Got: $Version"
}

Ok "Version : $Version"
Ok "Title   : $Title"
if ($NotesFile) {
    if (-not (Test-Path $NotesFile)) { Fail "NotesFile not found: $NotesFile" }
    Ok "Notes   : $NotesFile"
} else {
    Ok "Notes   : auto-generated from commits"
}

# ---------------------------------------------------------------------------
# [1] Prerequisites (build-v3.ps1 finds the build tools itself)
# ---------------------------------------------------------------------------

Step "[1] Checking prerequisites..."

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Fail "gh CLI not found. Install with: winget install GitHub.cli"
}
$ghStatus = gh auth status 2>&1
if ($LASTEXITCODE -ne 0) { Fail "gh is not authenticated. Run: gh auth login" }
Ok "gh authenticated"

git fetch --tags --quiet origin
if (git tag --list "v$Version") { Fail "Tag v$Version already exists." }
Ok "v$Version is a new tag"

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

# godot/main.gd: the version the app shows and compares for updates
$mainGd = Join-Path $ProjectRoot "godot\main.gd"
$text = [IO.File]::ReadAllText($mainGd)
$text = $text -replace 'const VERSION := "[^"]*"', "const VERSION := `"$Version`""
[IO.File]::WriteAllText($mainGd, $text)
Ok "godot/main.gd -> $Version"

# godot/export_presets.cfg: the exe's file and product version (both presets)
$presets = Join-Path $ProjectRoot "godot\export_presets.cfg"
$text = [IO.File]::ReadAllText($presets)
$text = $text -replace 'application/file_version="[^"]*"', "application/file_version=`"$Version.0`""
$text = $text -replace 'application/product_version="[^"]*"', "application/product_version=`"$Version.0`""
[IO.File]::WriteAllText($presets, $text)
Ok "godot/export_presets.cfg -> $Version.0"

# ---------------------------------------------------------------------------
# [4] Build (the player build, never -Admin)
# ---------------------------------------------------------------------------

Step "[4] Building installer (build-v3.ps1 -Version $Version)..."

if ($SkipNative) {
    & "$ProjectRoot\build-v3.ps1" -Version $Version -SkipNative
} else {
    & "$ProjectRoot\build-v3.ps1" -Version $Version
}

$installerPath = Join-Path $ProjectRoot "installer\output\CritterOverlaySetup-$Version.exe"
if (-not (Test-Path $installerPath)) {
    Fail "Installer not found at expected path: $installerPath"
}
$exe = [IO.File]::ReadAllBytes((Join-Path $ProjectRoot "build\CritterOverlay.exe"))
if ([Text.Encoding]::ASCII.GetString($exe).Contains("admin_page.gd")) {
    Fail "The built exe carries the Admin page. Check the 'Windows Desktop' export preset's exclude filter."
}
Ok "Installer ready, no Admin page: $installerPath"

# ---------------------------------------------------------------------------
# [5] Commit and push
# ---------------------------------------------------------------------------

Step "[5] Committing version bump..."

git add godot\main.gd godot\export_presets.cfg
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
