# The Phase 5 sleep/resume row (docs/v3-launch-plan.md): berries and focus
# gained across a sleep are no more than the minutes actually present.
#
#   sleep_check.ps1 -Exe C:\path\CritterOverlay.exe [-Minutes 15]
#
# Starts the game (presence faked "here", a fresh save) for -Minutes of game
# time. While it runs, sleep the machine for a few minutes and wake it: a
# laptop's Sleep, or on the VM `virsh suspend` then `virsh resume` from the
# host. This script ticks every 2 s and counts any longer gap as the sleep.
# At the end it compares the focus minutes in the save with the minutes the
# machine was really awake. (The save's day_focus_min starts again at
# midnight: don't run it across midnight.)
param(
    [Parameter(Mandatory)][string]$Exe,
    [int]$Minutes = 15,
    [string]$Out = (Join-Path ([IO.Path]::GetTempPath()) "critter-sleep")
)
$ErrorActionPreference = "Stop"
New-Item -ItemType Directory -Force $Out | Out-Null
$settings = Join-Path $Out "settings.json"
$save = Join-Path $Out "economy.json"
$report = Join-Path $Out "report.json"
'{"sound": {"pops": false, "volume": 0}, "system": {"onboarded": true, "updates": "off"}}' | Out-File $settings -Encoding ascii
Remove-Item $save, $report -ErrorAction SilentlyContinue

$a = "-- --kittens=4 --idle-sim=100000,1 --seconds=$($Minutes * 60) --report=`"$report`" --settings=`"$settings`" --save=`"$save`""
$p = Start-Process -FilePath $Exe -ArgumentList $a -PassThru
$h = $p.Handle   # keep a handle so ExitCode is readable afterwards
"Running for $Minutes min of game time. Sleep the machine now for a few minutes, then wake it."
$t0 = Get-Date
$last = $t0
$slept = 0.0
while (-not $p.HasExited) {
    Start-Sleep -Seconds 2
    $now = Get-Date
    $gap = ($now - $last).TotalSeconds
    if ($gap -gt 10) {
        $slept += $gap
        "a gap of {0:F1} min (the sleep)" -f ($gap / 60)
    }
    $last = $now
    if (($now - $t0).TotalMinutes -gt $Minutes * 3 + 30) { $p.Kill(); "TIMEOUT"; break }
}
$p.WaitForExit()
$wall = ((Get-Date) - $t0).TotalMinutes
$awake = $wall - $slept / 60
$e = if (Test-Path $save) { Get-Content $save -Raw | ConvertFrom-Json } else { $null }
$focus = if ($e) { [double]$e.day_focus_min } else { -1 }
$ok = $e -and $slept -gt 60 -and $focus -le $awake + 0.5
$line = "{0,-11} {1,-58} {2,-28} {3}" -f "sleep", ("focus {0:F1} min, berries {1}; awake {2:F1} of {3:F1} min" -f $focus, $e.lifetime_berries, $awake, $wall),
    "focus <= minutes awake", $(if ($ok) { "PASS" } else { "FAIL" })
if ($slept -le 60) { $line += "  (no sleep of over a minute was seen)" }
if (-not $e) { $line += "  (no save written, exit 0x{0:X8})" -f $p.ExitCode }
$line
$line | Out-File (Join-Path $Out "sleep-results.txt") -Append -Encoding utf8
