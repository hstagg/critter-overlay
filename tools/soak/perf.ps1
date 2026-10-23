# The Phase 5 rows measured on real hardware (docs/v3-launch-plan.md,
# "Proposed thresholds"), each run on the exported release build:
#
#   fps8        8 critters, 2 min: median fps >= 28, p95 frame <= 40 ms (30 fps cap)
#   cpu8        8 critters awake, 10 min: <= 25% of one core
#   paused      8 critters, paused with the pause shortcut, 10 min: <= 3%
#   fullscreen  8 critters behind a full-screen window, 10 min: <= 3%
#   napping     8 critters all asleep (presence faked away), 10 min: <= 7%
#   cap25       25 critters, 2 min: median fps >= 25, no errors
#   all         each of the above in turn (about 45 min)
#
#   perf.ps1 -Exe C:\path\CritterOverlay.exe -Row all [-Out dir] [-Minutes 10]
#
# Each row prints one line: ROW  measured  threshold  PASS|FAIL, plus why when
# the scenario did not take (e.g. the shortcut did not pause). Runs use a
# throwaway settings file with sound off and the update check off, and a
# throwaway save. Pause the installed app first (or quit it): two copies
# would share the shortcut. "fullscreen" covers the screen in black for the
# whole run. A PC in use skews the CPU rows: run at a quiet time.
param(
    [Parameter(Mandatory)][string]$Exe,
    [ValidateSet("fps8", "cpu8", "paused", "fullscreen", "napping", "cap25", "all")][string]$Row = "all",
    [string]$Out = (Join-Path ([IO.Path]::GetTempPath()) "critter-perf"),
    [int]$Minutes = 10,         # the CPU rows' length; the first minute is not counted
    [string]$Extra = ""         # more flags for every run, e.g. '--set=system.detail:"simple"'
)
$ErrorActionPreference = "Stop"
New-Item -ItemType Directory -Force $Out | Out-Null
Add-Type -Namespace W -Name U -MemberDefinition @'
[DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, System.UIntPtr extra);
'@
Add-Type -AssemblyName System.Windows.Forms

function Press-Pause {
    # Ctrl+Shift+P, the default pause shortcut (settings.gd), as real key presses.
    foreach ($k in 0x11, 0x10, 0x50) { [W.U]::keybd_event($k, 0, 0, [UIntPtr]::Zero) }
    foreach ($k in 0x50, 0x10, 0x11) { [W.U]::keybd_event($k, 0, 2, [UIntPtr]::Zero) }
}

function Run-Game([string]$Name, [int]$Seconds, [string]$Extra, [string]$Poke = "") {
    # Runs the game for $Seconds of game time with $Extra flags. $Poke: "pause"
    # presses the shortcut at 20 s; "fullscreen" puts a full-screen window up
    # at 20 s until the game exits. Returns its report, CPU samples and output.
    $settings = Join-Path $Out "$Name.settings.json"
    '{"sound": {"pops": false, "volume": 0}, "system": {"onboarded": true, "updates": "off"}}' | Out-File $settings -Encoding ascii
    $report = Join-Path $Out "$Name.report.json"
    $save = Join-Path $Out "$Name.economy.json"
    Remove-Item $report, $save, (Join-Path $Out "$Name.godot.log") -ErrorAction SilentlyContinue
    $a = "-- --seconds=$Seconds --report=`"$report`" --settings=`"$settings`" --save=`"$save`" $Extra $script:Extra"
    $p = Start-Process -FilePath $Exe -ArgumentList $a -PassThru `
        -RedirectStandardOutput (Join-Path $Out "$Name.out.txt") -RedirectStandardError (Join-Path $Out "$Name.err.txt")
    $h = $p.Handle   # keep a handle so ExitCode is readable afterwards
    $t0 = Get-Date
    $cpu = @()       # [seconds since start, CPU seconds]
    $form = $null
    $poked = $false
    while (-not $p.HasExited) {
        $el = ((Get-Date) - $t0).TotalSeconds
        $p.Refresh()
        try { $cpu += , @($el, $p.TotalProcessorTime.TotalSeconds) } catch {}
        if (-not $poked -and $el -ge 20) {
            $poked = $true
            if ($Poke -eq "pause") { Press-Pause }
            if ($Poke -eq "fullscreen") {
                $form = New-Object System.Windows.Forms.Form
                $form.FormBorderStyle = "None"
                $form.BackColor = "Black"
                $form.StartPosition = "Manual"
                $form.Bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
                $form.TopMost = $true
                $form.Show()
                $form.Activate()
            }
        }
        if ($el -gt $Seconds * 2 + 120) { $p.Kill(); break }
        for ($i = 0; $i -lt 20; $i++) {
            if ($form) { [System.Windows.Forms.Application]::DoEvents() }
            Start-Sleep -Milliseconds 250
        }
    }
    $p.WaitForExit()
    if ($form) { $form.Close() }
    $r = if (Test-Path $report) { Get-Content $report -Raw | ConvertFrom-Json } else { $null }
    # The exported exe prints nothing to stdout (GUI subsystem); Godot's own
    # log of this run is the newest godot.log until the next run.
    $log = Join-Path $env:APPDATA "Critter Overlay\logs\godot.log"
    if (Test-Path $log) { Copy-Item $log (Join-Path $Out "$Name.godot.log") -Force }
    $text = @(Get-Content (Join-Path $Out "$Name.godot.log"), (Join-Path $Out "$Name.err.txt") -ErrorAction SilentlyContinue) -join "`n"
    return @{ report = $r; cpu = $cpu; text = $text; exit = ("0x{0:X8}" -f $p.ExitCode) }
}

function Cpu-Percent($cpu) {
    # Share of one core from the end of the first minute to the end.
    $from = $cpu | Where-Object { $_[0] -ge 60 } | Select-Object -First 1
    $to = $cpu[-1]
    if (-not $from -or $to[0] -le $from[0]) { return $null }
    return 100.0 * ($to[1] - $from[1]) / ($to[0] - $from[0])
}

function Say([string]$row, [string]$measured, [string]$threshold, [bool]$ok, [string]$why = "") {
    $line = "{0,-11} {1,-34} {2,-28} {3}" -f $row, $measured, $threshold, $(if ($ok) { "PASS" } else { "FAIL" })
    if ($why) { $line += "  ($why)" }
    $line
    $line | Out-File (Join-Path $Out "perf-results.txt") -Append -Encoding utf8
}

$present = "--idle-sim=100000,1"   # presence stays "here" (no one is at the keyboard)
$cpuS = $Minutes * 60
$rows = if ($Row -eq "all") { "fps8", "cpu8", "paused", "fullscreen", "napping", "cap25" } else { @($Row) }
"perf.ps1 $(Get-Date -Format s) exe=$Exe" | Out-File (Join-Path $Out "perf-results.txt") -Append -Encoding utf8
foreach ($r in $rows) {
    switch ($r) {
        "fps8" {
            $g = Run-Game $r 120 "--kittens=8 $present"
            $m = $g.report.fps.median; $p95 = $g.report.frame_gap_ms.p95
            Say $r ("median {0} fps, p95 frame {1} ms" -f $m, $p95) "median >= 28, p95 <= 40 ms" ($m -ge 28 -and $p95 -le 40) $(if (-not $g.report) { "no report, exit $($g.exit)" })
        }
        "cpu8" {
            $g = Run-Game $r $cpuS "--kittens=8 $present"
            $c = Cpu-Percent $g.cpu
            Say $r ("{0:F1}% of a core" -f $c) "<= 25%" ($c -ne $null -and $c -le 25) $(if ($g.report.napping -gt 0) { "$($g.report.napping) were napping" })
        }
        "paused" {
            $g = Run-Game $r $cpuS "--kittens=8 $present" "pause"
            $c = Cpu-Percent $g.cpu
            $took = $g.report -and $g.report.paused
            Say $r ("{0:F1}% of a core" -f $c) "<= 3%" ($took -and $c -ne $null -and $c -le 3) $(if (-not $took) { "the shortcut did not pause it" })
        }
        "fullscreen" {
            $g = Run-Game $r $cpuS "--kittens=8 $present" "fullscreen"
            $c = Cpu-Percent $g.cpu
            $took = $g.report -and $g.report.hidden
            Say $r ("{0:F1}% of a core" -f $c) "<= 3%" ($took -and $c -ne $null -and $c -le 3) $(if (-not $took) { "the app did not see a full-screen app" })
        }
        "napping" {
            # Away after 5 s of faked idleness; everyone settles within a minute.
            $g = Run-Game $r $cpuS "--kittens=8 --idle-sim=1,100000 --away-after=5"
            $c = Cpu-Percent $g.cpu
            $took = $g.report -and $g.report.away -and $g.report.napping -eq $g.report.critters
            Say $r ("{0:F1}% of a core" -f $c) "<= 7%" ($took -and $c -ne $null -and $c -le 7) $(if (-not $took) { "not everyone was asleep at the end" })
        }
        "cap25" {
            $g = Run-Game $r 120 "--kittens=25 $present"
            $m = $g.report.fps.median
            $errs = ([regex]::Matches($g.text, "SCRIPT ERROR|ERROR:")).Count
            Say $r ("median {0} fps, {1} errors" -f $m, $errs) "median >= 25, no errors" ($m -ge 25 -and $errs -eq 0) $(if (-not $g.report) { "no report, exit $($g.exit)" })
        }
    }
}
"Results also in $(Join-Path $Out 'perf-results.txt')"
