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
# released, and step [4] refuses an installer whose exe carries it. A failed
# build undoes the version bump; after the release, step [6] checks GitHub
# gave the asset the sha256 digest the updater needs.

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
function Fail([string]$msg) { Write-Host "  $msg" -ForegroundColor Red; exit 1 }

$bumped = @("godot\main.gd", "godot\export_presets.cfg")
function Undo-Bump {
    # A failed build leaves the tree as it was, so the next try starts clean.
    git checkout -- @bumped
    Write-Host "  Version bump undone." -ForegroundColor Yellow
}

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

try {
    if ($SkipNative) {
        & "$ProjectRoot\build-v3.ps1" -Version $Version -SkipNative
    } else {
        & "$ProjectRoot\build-v3.ps1" -Version $Version
    }
} catch {
    Undo-Bump
    Fail "Build failed: $_"
}

$installerPath = Join-Path $ProjectRoot "installer\output\CritterOverlaySetup-$Version.exe"
if (-not (Test-Path $installerPath)) {
    Undo-Bump
    Fail "Installer not found at expected path: $installerPath"
}
# The Admin page's two scripts, as the export names them (compiled to .gdc).
$exe = [Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes((Join-Path $ProjectRoot "build\CritterOverlay.exe")))
$found = @("admin.gdc", "admin_page.gdc", "res://admin.gd", "res://gui/admin_page.gd") | Where-Object { $exe.Contains($_) }
if ($found) {
    Undo-Bump
    Fail "The built exe carries the Admin page ($($found -join ', ')). Check the 'Windows Desktop' export preset's exclude filter."
}
$extra = git status --porcelain | Where-Object { $_ -notmatch 'godot/(main\.gd|export_presets\.cfg)$' }
if ($extra) {
    Write-Host ($extra -join "`n")
    Undo-Bump
    Fail "The build changed files besides the version bump."
}
Ok "Installer ready, no Admin page: $installerPath"

# ---------------------------------------------------------------------------
# [5] Commit and push
# ---------------------------------------------------------------------------

Step "[5] Committing version bump..."

git add godot\main.gd godot\export_presets.cfg
git diff --cached --quiet
if ($LASTEXITCODE -eq 0) {
    # The version files already said $Version (the first release of a line).
    Ok "Version files already at ${Version}: nothing to commit"
} else {
    git commit -m "release: v$Version - $Title"
    if ($LASTEXITCODE -ne 0) { Fail "git commit failed." }
    Ok "Committed"
}

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

# The one-click updater (godot/updater.gd) needs the asset under this exact
# name, with a sha256 digest from GitHub. Without them every installed copy
# falls back to "download it yourself".
$asset = (gh api "repos/hstagg/critter-overlay/releases/tags/v$Version" | ConvertFrom-Json).assets |
    Where-Object { $_.name -eq "CritterOverlaySetup-$Version.exe" }
if (-not $asset -or $asset.size -le 0 -or "$($asset.digest)" -notlike "sha256:*") {
    Fail "Released, but the asset has no sha256 digest or the wrong name: one-click updates will not offer it."
}
Ok "Asset $($asset.name), $($asset.size) bytes, $($asset.digest)"

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
