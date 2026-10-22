# On the test VM: the install matrix (K3 in docs/v3-launch-plan.md), each row
# logged PASS or FAIL in <Kit>\results.txt. Run it on the desktop through
# vm-run.ps1 (it starts the app), from an elevated task (the per-machine row
# needs it):
#
#   vm-run.ps1 -Name k3 -TimeoutMin 40 -Command "powershell -NoProfile -ExecutionPolicy Bypass -File C:\critter-overlay\tools\soak\vm\install_matrix.ps1"
#
# <Kit> holds CritterOverlaySetup-2.0.0.exe (the v2.0.0 release) and the v3
# installer under test. Rows, in order, each starting from the state the one
# before left:
#   v2user     v2.0 per-user, running, then v3 over it: v2 closed, one install,
#              v2's runtime gone, and v3's first run imports v2's settings
#   reinstall  v3 over itself while it runs
#   uninstall  uninstall while running, keeping data (the default answer)
#   keepdata   install again: the kept data is picked up
#   deletedata uninstall answering Yes to "delete your data": someone presses Y
#              (on the VM console from the host: vmtype.py "y")
#   fresh      install with nothing before it
#   v2machine  v2.0 for all users, running, then v3 over it: one install, still
#              per-machine
# The rows wipe both apps' data folders on this machine.
param(
    [string]$Kit = "C:\soak\k3",
    [string]$V3 = "CritterOverlaySetup-3.0.0.exe",
    [string]$Rows = "v2user,reinstall,uninstall,keepdata,deletedata,fresh,v2machine"   # comma list (powershell -File passes one string)
)
$ErrorActionPreference = "Continue"
$results = Join-Path $Kit "results.txt"
$v3Data = Join-Path $env:APPDATA "Critter Overlay"
$v2Data = Join-Path $env:APPDATA "CritterOverlay"
$runKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"

function Say([string]$row, [bool]$ok, [string]$detail) {
    $line = "{0} {1,-10} {2} {3}" -f (Get-Date -Format "HH:mm:ss"), $row, $(if ($ok) { "PASS" } else { "FAIL" }), $detail
    $line | Out-File $results -Append -Encoding utf8
}

function Entries {
    # Apps & features entries for Critter Overlay, per-user and per-machine.
    # (Callers wrap it in @(): PowerShell 5.1 gives one object no .Count.)
    @(Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like "Critter Overlay*" })
}

function AppDir {
    $e = Entries | Select-Object -First 1
    if ($e) { $e.InstallLocation.TrimEnd("\") } else { $null }
}

function Running {
    @(Get-Process CritterOverlay -ErrorAction SilentlyContinue)
}

function Wait-Gone([int]$s = 20) {
    $t = 0
    while ((Running).Count -gt 0 -and $t -lt $s * 4) { Start-Sleep -Milliseconds 250; $t++ }
}

function Run-Setup([string]$exe, [string]$flags, [string]$name) {
    $log = Join-Path $Kit "$name.log"
    $p = Start-Process (Join-Path $Kit $exe) -ArgumentList "$flags /LOG=`"$log`"" -PassThru -Wait
    return @($p.ExitCode, $log)
}

function Uninstall-All([string]$extra = "/VERYSILENT /SUPPRESSMSGBOXES") {
    foreach ($e in Entries) {
        $u = $e.UninstallString.Trim('"')
        Start-Process $u -ArgumentList "$extra /NORESTART" -Wait
    }
    # unins000.exe hands over to a copy of itself in %TEMP% (_unins.tmp),
    # which does the work and may still be deleting when the first exits.
    $t = 0
    while ((Get-Process _unins* -ErrorAction SilentlyContinue) -and $t -lt 240) { Start-Sleep -Milliseconds 250; $t++ }
    Start-Sleep -Seconds 1
}

function Start-App([string]$exe, [int]$s = 25) {
    # A real start (no test flags, so the real settings and save are used),
    # then asked to close as Windows would.
    $p = Start-Process $exe -PassThru
    Start-Sleep -Seconds $s
    return $p
}

function Close-App {
    taskkill /IM CritterOverlay.exe | Out-Null
    Wait-Gone 15
    taskkill /F /IM CritterOverlay.exe 2>$null | Out-Null
    Wait-Gone 5
}

function Seed-V2 {
    # A used v2.0's settings, as v2.0 writes them when a setting changes (a
    # v2.0 never changed has none, and nothing to import): a few settings and
    # a Seen Log.
    New-Item -ItemType Directory -Force $v2Data | Out-Null
    '{"visual": {"animal_size": 100, "opacity": 90}, "audio": {"sound_enabled": false, "volume": 30},
 "behaviour": {"day_night_enabled": true, "behaviour_frequency": 2.0, "interactions_enabled": true},
 "rarity": {"enabled": true, "rare_hour": {"enabled": true, "start_hour": 16, "duration_minutes": 60, "rare_tier_boost": 2.0},
  "seen_log_enabled": true, "seen_log": {"kitten": {"common": 5, "rare": 1}, "duck": {"common": 2}}},
 "system": {"auto_launch": true},
 "animals": {"kitten": {"enabled": true, "weight": 1.0}, "duck": {"enabled": true, "weight": 2.0}}}' |
        Out-File (Join-Path $v2Data "settings.json") -Encoding ascii
}

function V3-Settings {
    $f = Join-Path $v3Data "settings.json"
    if (Test-Path $f) { Get-Content $f -Raw | ConvertFrom-Json } else { $null }
}

"--- install_matrix $(Get-Date -Format s), v3 = $V3" | Out-File $results -Append -Encoding utf8
foreach ($row in $Rows.Split(",").Trim()) {
    switch ($row) {
        "v2user" {
            Close-App; Uninstall-All
            Remove-Item -Recurse -Force $v3Data, $v2Data -ErrorAction SilentlyContinue
            $r2 = Run-Setup "CritterOverlaySetup-2.0.0.exe" "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /CURRENTUSER" "v2user-v2"
            Seed-V2
            $dir = AppDir
            $null = Start-App (Join-Path $dir "CritterOverlay.exe") 20
            $v2Up = (Running).Count -gt 0
            $r3 = Run-Setup $V3 "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART" "v2user-v3"
            Wait-Gone 10
            $left = (Running).Count
            $es = @(Entries)
            $closed = (Select-String $r3[1] -Pattern "v2.0 is running: closing it" -Quiet)
            $ver = (Get-Item (Join-Path $dir "CritterOverlay.exe")).VersionInfo.FileVersion
            $ok = $r2[0] -eq 0 -and $v2Up -and $r3[0] -eq 0 -and $closed -and $left -eq 0 -and $es.Count -eq 1 -and
                $es[0].DisplayVersion -eq "3.0.0" -and -not (Test-Path (Join-Path $dir "_internal")) -and $ver -like "3.0.0*"
            Say $row $ok ("v2 setup {0}, v2 ran {1}, v3 setup {2}, installer closed v2 {3}, left running {4}, entries {5} ({6}), _internal gone {7}, exe {8}, in {9}" -f
                $r2[0], $v2Up, $r3[0], $closed, $left, $es.Count, (($es | % DisplayVersion) -join ","), (-not (Test-Path (Join-Path $dir "_internal"))), $ver, $dir)
            # v3's first real run imports v2.0's settings.
            $null = Start-App (Join-Path $dir "CritterOverlay.exe") 30
            Close-App
            $s = V3-Settings
            $run = (Get-ItemProperty $runKey -ErrorAction SilentlyContinue).CritterOverlay
            $econ = Join-Path $v3Data "economy.json"
            $seen = (Test-Path $econ) -and (Get-Content $econ -Raw) -match '"kitten'
            $ok = $s -and $s.system.from_v2 -eq $true -and $s.system.v2_seen_done -eq $true -and $seen -and $s.critters.size -eq 100
            Say "v2import" $ok ("settings from_v2 {0}, Seen Log done {1}, kitten in the Collection {2}, size {3}, startup entry '{4}'" -f
                $s.system.from_v2, $s.system.v2_seen_done, $seen, $s.critters.size, $run)
        }
        "reinstall" {
            $dir = AppDir
            $null = Start-App (Join-Path $dir "CritterOverlay.exe") 20
            $r = Run-Setup $V3 "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART" "reinstall"
            Wait-Gone 10
            $es = @(Entries)
            $ok = $r[0] -eq 0 -and $es.Count -eq 1 -and (Test-Path (Join-Path $dir "CritterOverlay.exe")) -and (V3-Settings).system.from_v2 -eq $true
            Say $row $ok ("setup {0}, entries {1}, left running {2}, settings kept {3}" -f $r[0], $es.Count, (Running).Count, (V3-Settings).system.from_v2)
        }
        "uninstall" {
            $dir = AppDir
            $null = Start-App (Join-Path $dir "CritterOverlay.exe") 20
            Uninstall-All
            Wait-Gone 10
            $run = (Get-ItemProperty $runKey -ErrorAction SilentlyContinue).CritterOverlay
            $ok = @(Entries).Count -eq 0 -and -not (Test-Path (Join-Path $dir "CritterOverlay.exe")) -and (Running).Count -eq 0 -and
                (Test-Path (Join-Path $v3Data "settings.json")) -and -not $run
            Say $row $ok ("entries {0}, exe left {1}, running {2}, data kept {3}, startup entry '{4}'" -f @(Entries).Count,
                (Test-Path (Join-Path $dir "CritterOverlay.exe")), (Running).Count, (Test-Path (Join-Path $v3Data "settings.json")), $run)
        }
        "keepdata" {
            $r = Run-Setup $V3 "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART" "keepdata"
            $null = Start-App (Join-Path (AppDir) "CritterOverlay.exe") 25
            Close-App
            $ok = $r[0] -eq 0 -and @(Entries).Count -eq 1 -and (V3-Settings).system.from_v2 -eq $true
            Say $row $ok ("setup {0}, entries {1}, earlier settings picked up {2}" -f $r[0], @(Entries).Count, (V3-Settings).system.from_v2)
        }
        "deletedata" {
            # Not /SUPPRESSMSGBOXES: the question is asked, and Y must be pressed.
            "deletedata: waiting for Y on the uninstaller's question" | Out-File $results -Append -Encoding utf8
            Uninstall-All "/SILENT"
            $ok = @(Entries).Count -eq 0 -and -not (Test-Path $v3Data) -and -not (Test-Path $v2Data)
            Say $row $ok ("entries {0}, v3 data left {1}, v2 data left {2}" -f @(Entries).Count, (Test-Path $v3Data), (Test-Path $v2Data))
        }
        "fresh" {
            Close-App; Uninstall-All
            Remove-Item -Recurse -Force $v3Data, $v2Data -ErrorAction SilentlyContinue
            $r = Run-Setup $V3 "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART" "fresh"
            $null = Start-App (Join-Path (AppDir) "CritterOverlay.exe") 25
            Close-App
            $s = V3-Settings
            $ok = $r[0] -eq 0 -and @(Entries).Count -eq 1 -and $s -and -not $s.system.from_v2
            Say $row $ok ("setup {0}, entries {1}, settings written {2}, from_v2 {3}" -f $r[0], @(Entries).Count, [bool]$s, $s.system.from_v2)
        }
        "v2machine" {
            Close-App; Uninstall-All
            Remove-Item -Recurse -Force $v3Data, $v2Data -ErrorAction SilentlyContinue
            $r2 = Run-Setup "CritterOverlaySetup-2.0.0.exe" "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /ALLUSERS" "v2machine-v2"
            Seed-V2
            $dir = AppDir
            $null = Start-App (Join-Path $dir "CritterOverlay.exe") 20
            $v2Up = (Running).Count -gt 0
            $r3 = Run-Setup $V3 "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART" "v2machine-v3"
            Wait-Gone 10
            $es = @(Entries)
            $ver = (Get-Item (Join-Path $dir "CritterOverlay.exe")).VersionInfo.FileVersion
            $ok = $r2[0] -eq 0 -and $v2Up -and $r3[0] -eq 0 -and (Running).Count -eq 0 -and $es.Count -eq 1 -and
                $es[0].DisplayVersion -eq "3.0.0" -and $dir -like "*Program Files*" -and $ver -like "3.0.0*"
            Say $row $ok ("v2 setup {0}, v2 ran {1}, v3 setup {2}, left running {3}, entries {4} ({5}), exe {6}, in {7}" -f
                $r2[0], $v2Up, $r3[0], (Running).Count, $es.Count, (($es | % DisplayVersion) -join ","), $ver, $dir)
            Uninstall-All
        }
    }
}
"--- done $(Get-Date -Format s)" | Out-File $results -Append -Encoding utf8
