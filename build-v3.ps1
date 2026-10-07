# build-v3.ps1 - builds the Critter Overlay v3 installer from the Godot project.
#
#   .\build-v3.ps1                  # version 3.0.0
#   .\build-v3.ps1 -Version 3.0.1
#   .\build-v3.ps1 -Admin           # the developer's build, with the Admin page
#
# Steps: native DLL (release) -> Godot export -> exe icon and version
# (rcedit) -> Inno Setup installer in installer\output\.
#
# Needs, found on PATH or given by environment variable:
#   godot or godot_console        GODOT    (Godot 4.7 with its export templates)
#   rcedit-x64.exe                RCEDIT
#   Inno Setup 6 (ISCC.exe)       ISCC     (default install paths are searched)
#   SCons for the native DLL      SCONS_PYTHON (a python with scons), and
#                                 godot-cpp beside this repo (see native\README.md)
# -SkipNative uses the DLL already in godot\bin.
# -Admin exports the "Windows Admin" preset (feature tag "admin", with
# admin.gd and gui/admin_page.gd) to build-admin\ and names the installer
# CritterOverlaySetup-<version>-admin.exe. Never ship it: the player preset
# ("Windows Desktop") leaves the Admin page out entirely.

param(
    [string]$Version = "3.0.0",
    [switch]$SkipNative,
    [switch]$Admin
)

$ErrorActionPreference = "Stop"
$Root = $PSScriptRoot

function Step([string]$m) { Write-Host ""; Write-Host $m -ForegroundColor Cyan }
function Find([string]$envName, [string[]]$names, [string[]]$paths) {
    $v = [Environment]::GetEnvironmentVariable($envName)
    if ($v -and (Test-Path $v)) { return $v }
    foreach ($n in $names) { $c = Get-Command $n -ErrorAction SilentlyContinue; if ($c) { return $c.Source } }
    foreach ($p in $paths) { if (Test-Path $p) { return $p } }
    throw "Cannot find $($names[0]). Put it on PATH or set $envName."
}

if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw "Version must look like 3.0.0" }

$godot = Find "GODOT" @("godot_console", "godot") @()
$rcedit = Find "RCEDIT" @("rcedit-x64.exe", "rcedit") @("$Root\..\tools\rcedit-x64.exe")
$iscc = Find "ISCC" @("ISCC.exe") @("C:\Program Files (x86)\Inno Setup 6\ISCC.exe", "C:\Program Files\Inno Setup 6\ISCC.exe", "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe")

# The version shown in the app (main.gd VERSION) must match.
$main = Get-Content "$Root\godot\main.gd" -Raw
if ($main -notmatch "const VERSION := `"$([regex]::Escape($Version))`"") {
    throw "godot\main.gd VERSION is not $Version. Update it first."
}

if (-not $SkipNative) {
    Step "[1/4] Native DLL (release)"
    $py = if ($env:SCONS_PYTHON) { $env:SCONS_PYTHON } else { "python" }
    Push-Location "$Root\native"
    & $py -m SCons custom_api_file=extension_api.json target=template_release
    if ($LASTEXITCODE -ne 0) { Pop-Location; throw "native build failed" }
    Pop-Location
}
if (-not (Test-Path "$Root\godot\bin\critter_native.windows.template_release.x86_64.dll")) {
    throw "The release native DLL is missing; build it (drop -SkipNative)."
}

Step "[2/4] Godot export"
# The game reads its SVG art as text (it rasterises at its own scale), so the
# export must carry the files themselves, not Godot's imported textures.
Get-ChildItem "$Root\godot\art" -Recurse -Filter *.svg | ForEach-Object {
    Set-Content -Path "$($_.FullName).import" -Value "[remap]`n`nimporter=`"keep`"`n" -Encoding ascii
}
& $godot --headless --path "$Root\godot" --import

$preset = if ($Admin) { "Windows Admin" } else { "Windows Desktop" }
$out = if ($Admin) { "$Root\build-admin" } else { "$Root\build" }
if (Test-Path $out) { Remove-Item "$out\*" -Recurse -Force }
New-Item -ItemType Directory -Force $out | Out-Null
& $godot --headless --path "$Root\godot" --export-release $preset "$out\CritterOverlay.exe"
if (-not (Test-Path "$out\CritterOverlay.exe")) { throw "export failed" }

Step "[3/4] Icon and version"
& $rcedit "$out\CritterOverlay.exe" --set-icon "$Root\godot\icon.ico" `
    --set-file-version "$Version.0" --set-product-version "$Version.0" `
    --set-version-string "ProductName" "Critter Overlay" `
    --set-version-string "FileDescription" "Critter Overlay" `
    --set-version-string "CompanyName" "hstagg"
if ($LASTEXITCODE -ne 0) { throw "rcedit failed" }

Step "[4/4] Installer"
Push-Location "$Root\installer"
$setup = if ($Admin) { "CritterOverlaySetup-$Version-admin" } else { "CritterOverlaySetup-$Version" }
& $iscc "/DMyAppVersion=$Version" "/DBuildDir=$out" "/F$setup" "installer-v3.iss"
if ($LASTEXITCODE -ne 0) { Pop-Location; throw "Inno Setup failed" }
Pop-Location

Write-Host ""
Write-Host "Built installer\output\$setup.exe" -ForegroundColor Green
