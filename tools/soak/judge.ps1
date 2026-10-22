# The Phase 5 rows judged from an 8 h soak on the test VM (docs/v3-launch-plan.md,
# "Proposed thresholds"), and from the unattended exit test:
#
#   gdi         GDI objects at the end <= 2,000, and flat after hour 1
#   user        USER objects, threads and child processes flat after hour 1
#   memory      working set at the end <= hour 1 + 15%
#   windows     every sample: windows <= critters + props + 3 toasts + 8 spare + 3
#   errors      no script or engine errors, no anomalies, exit code 0, no crash events
#   pairs       >= 90% of pairs started reach the interaction
#   exits       (with -Exits) >= 30 launches, every one exit code 0, no crash events
#
# The soak itself (on the VM, through vm-run.ps1), e.g.:
#   bash tools/soak/run.sh soak8h 30600 --seconds=28800 --idle-sim=480,240 --soak-mode=soak --soak-every=60
# then, on the VM:
#   judge.ps1 -Dir tools\soak\out -Name soak8h [-Exits C:\soak-kit\results-<time>]
#
# "Flat" means the highest value after hour 1 is at most 10% (plus a small
# allowance) above the value at hour 1. A run shorter than 8 h is judged on
# what it has, and says so.
param(
    [Parameter(Mandatory)][string]$Dir,
    [Parameter(Mandatory)][string]$Name,
    [string]$Exits = ""          # night_exit.ps1's results-<time> folder
)
$ErrorActionPreference = "Stop"
$fails = 0

function Say([string]$row, [string]$measured, [string]$threshold, [bool]$ok) {
    if (-not $ok) { $script:fails++ }
    $line = "{0,-9} {1,-50} {2,-34} {3}" -f $row, $measured, $threshold, $(if ($ok) { "PASS" } else { "FAIL" })
    $line
    $line | Out-File (Join-Path $Dir "$Name-judged.txt") -Append -Encoding utf8
}

function Flat($rows, [string]$col, [double]$allow) {
    # [value at hour 1, highest after it, whether that is flat]
    $after = @($rows | Where-Object { [double]$_.t_s -ge 3600 })
    if ($after.Count -eq 0) { return @($null, $null, $false) }
    $first = [double]$after[0].$col
    $top = ($after | ForEach-Object { [double]$_.$col } | Measure-Object -Maximum).Maximum
    return @($first, $top, ($top -le $first * 1.1 + $allow))
}

$proc = @(Import-Csv (Join-Path $Dir "${Name}_proc.csv"))
$samples = @(Get-Content (Join-Path $Dir "$Name.jsonl") | Where-Object { $_ } | ForEach-Object { $_ | ConvertFrom-Json })
$out = Get-Content (Join-Path $Dir "${Name}_out.txt") -Raw
$hours = [double]$proc[-1].t_s / 3600
$start = (Get-Item (Join-Path $Dir "${Name}_proc.csv")).CreationTime
"judge.ps1 $(Get-Date -Format s): $Name, {0:F1} h of samples{1}" -f $hours, $(if ($hours -lt 7.9) { " (shorter than the 8 h the rows ask for)" })

# GDI
$g = Flat $proc "gdi" 50
Say "gdi" ("end {0}, hour 1 {1}, highest after {2}" -f $proc[-1].gdi, $g[0], $g[1]) "<= 2,000 and flat after hour 1" ([double]$proc[-1].gdi -le 2000 -and $g[2])

# USER objects, threads, child processes
$u = Flat $proc "user" 20
$th = Flat $proc "threads" 5
$k = Flat $proc "children" 0
Say "user" ("USER {0}->{1}, threads {2}->{3}, children {4}->{5}" -f $u[0], $u[1], $th[0], $th[1], $k[0], $k[1]) "each flat after hour 1" ($u[2] -and $th[2] -and $k[2])

# Working set
$h1 = @($proc | Where-Object { [double]$_.t_s -ge 3600 })[0]
$ok = $h1 -and [double]$proc[-1].ws_mb -le [double]$h1.ws_mb * 1.15
Say "memory" ("hour 1 {0} MB, end {1} MB" -f $h1.ws_mb, $proc[-1].ws_mb) "end <= hour 1 + 15%" ([bool]$ok)

# Window count
$over = @($samples | Where-Object { $_.windows -gt $_.critters + $_.props + 3 + 8 + 3 })
$most = ($samples | ForEach-Object { $_.windows } | Measure-Object -Maximum).Maximum
Say "windows" ("most {0}; {1} of {2} samples over" -f $most, $over.Count, $samples.Count) "<= critters + props + 14" ($over.Count -eq 0 -and $samples.Count -gt 0)

# Script errors, anomalies, exit code, crash events
# The VM has no sound device: Godot's WASAPI start-up errors there are not the game's.
$noSound = "WASAPI|audio_driver_wasapi"
$lines = $out -split "`n"
$errs = 0
for ($i = 0; $i -lt $lines.Count; $i++) {
    # An error and the "at:" line after it.
    if ($lines[$i] -match "SCRIPT ERROR|ERROR:" -and ($lines[$i] + $(if ($i + 1 -lt $lines.Count) { $lines[$i + 1] })) -notmatch $noSound) { $errs++ }
}
$anom = ([regex]::Matches($out, "SOAK ANOMALY")).Count
$exitFile = Join-Path $Dir "${Name}_exit.txt"
$code = if (Test-Path $exitFile) { (Get-Content $exitFile -Raw).Trim() } else { "?" }
$crashes = @(Get-WinEvent -FilterHashtable @{LogName = 'Application'; StartTime = $start} -ErrorAction SilentlyContinue |
    Where-Object { $_.Id -in 1000, 1001, 1002 -and $_.Message -match "godot|CritterOverlay" }).Count
Say "errors" ("{0} errors, {1} anomalies, exit {2}, {3} crash events" -f $errs, $anom, $code, $crashes) "all 0" ($errs -eq 0 -and $anom -eq 0 -and $code -eq "0" -and $crashes -eq 0)

# Pair completion
$started = ([regex]::Matches($out, "PAIR start ")).Count
$acted = ([regex]::Matches($out, "PAIR act ")).Count
$share = if ($started -gt 0) { 100.0 * $acted / $started } else { 0 }
Say "pairs" ("{0} of {1} reached the interaction ({2:F0}%)" -f $acted, $started, $share) ">= 90%" ($started -gt 0 -and $share -ge 90)

# Clean exits (night_exit.ps1's summary)
if ($Exits -ne "") {
    $sum = Get-Content (Join-Path $Exits "summary.txt")
    $codes = @($sum | Where-Object { $_ -match '^(timed|second|wmclose) \d+ (\S+)$' } | ForEach-Object { $Matches[2] })
    $clean = @($codes | Where-Object { $_ -eq "0x00000000" }).Count
    $events = @($sum | Where-Object { $_ -match " id=100[012] " }).Count   # the crash events night_exit lists
    Say "exits" ("{0} of {1} clean, {2} crash events" -f $clean, $codes.Count, $events) ">= 30, all exit 0" ($codes.Count -ge 30 -and $clean -eq $codes.Count -and $events -eq 0)
}

"{0} failing; results also in {1}" -f $fails, (Join-Path $Dir "$Name-judged.txt")
exit $(if ($fails -eq 0) { 0 } else { 1 })
