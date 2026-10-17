# One staged scene, filmed and composed into a vertical MP4.
#
#   .\tools\film\scene.ps1 -Species otter -Count 5 -Seconds 25
#   .\tools\film\scene.ps1 -Species kitten -Count 3 -Tier rare -Layout crop -Zoom 1.5 -Tight 0.6
#   .\tools\film\scene.ps1 -PairDemo play_bow -Layout crop -Zoom 2
#
# The critters really appear on this screen for the length of the take; the
# video is built from their own windows (main.gd --film), not a screen grab.
# Uses throwaway settings and save files, so the real game is untouched.
# Needs Godot on PATH (or GODOT), Python with Pillow, and ffmpeg.

param(
    [string]$Species = "kitten",
    [int]$Count = 4,
    [int]$Perimeter = 0,
    [string]$Tier = "",
    [string]$Wear = "",
    [string]$PairDemo = "",
    [string]$Demo = "",
    [double]$Zoom = 0,
    [int]$Seconds = 20,
    [ValidateSet("letterbox", "crop")][string]$Layout = "letterbox",
    [double]$Tight = 1.0,
    [string]$Caption = "",
    [string]$Backdrop = "",
    [string]$Out = ""
)
$ErrorActionPreference = "Stop"
$root = Resolve-Path "$PSScriptRoot\..\.."
$godot = if ($env:GODOT) { $env:GODOT } else { "godot" }
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$work = Join-Path $env:TEMP "critter-film-$stamp"
New-Item -ItemType Directory -Force $work | Out-Null
if (-not $Out) { $Out = Join-Path ([Environment]::GetFolderPath("MyVideos")) "Critter Overlay\$stamp-$Species.mp4" }
New-Item -ItemType Directory -Force (Split-Path $Out) | Out-Null

# Present the whole take, so nobody naps because the keyboard went quiet.
$game = @("--film=$work\frames", "--seconds=$Seconds", "--idle-sim=100000,1",
          "--settings=$work\settings.json", "--save=$work\save.json")
if ($PairDemo) { $game += "--pair-demo=$PairDemo" }
elseif ($Demo) { $game += "--demo=$Demo"; $game += "--species=$Species" }
else { $game += "--species=$Species"; $game += "--kittens=$Count"; if ($Perimeter) { $game += "--perimeter=$Perimeter" } }
if ($Tier) { $game += "--tier=$Tier" }
if ($Wear) { $game += "--wear=$Wear" }
if ($Zoom -gt 0) { $game += "--zoom=$Zoom" }

Write-Host "Filming $Seconds s (critters will show on screen)..."
$ErrorActionPreference = "Continue"   # Godot's warnings on stderr are not failures
& $godot --fixed-fps 30 --path "$root\godot" -- @game 2>&1 | Out-Null
$ErrorActionPreference = "Stop"
if (-not (Test-Path "$work\frames\frames.jsonl")) { throw "no frames written to $work\frames" }

$compose = @("$PSScriptRoot\compose.py", "$work\frames", $Out, "--layout", $Layout)
if ($Caption) { $compose += @("--caption", $Caption) }
if ($Tight -lt 1) { $compose += @("--tight", "$Tight") }
if ($Backdrop) { $compose += @("--backdrop", $Backdrop) }
python @compose
if ($LASTEXITCODE) { throw "compose failed" }
Remove-Item -Recurse -Force $work
Write-Host "Saved $Out"
