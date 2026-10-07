# run-tests.ps1 - runs the v3 headless tests (godot\*_test.gd), as CI does.
#
#   .\run-tests.ps1            # every test but native_test.gd
#   .\run-tests.ps1 -Native    # native_test.gd too (needs the native DLL built)
#
# A test passes when Godot exits 0 and prints no SCRIPT ERROR or Parse Error.
# A test script that does not compile never quits, so each one has a time
# limit. Godot is found as in build-v3.ps1: GODOT, or godot_console / godot
# on PATH.

param(
    [switch]$Native,
    [int]$TimeoutSec = 300
)

$ErrorActionPreference = "Stop"
$Root = $PSScriptRoot

$godot = $env:GODOT
if (-not ($godot -and (Test-Path $godot))) {
    $c = Get-Command godot_console, godot -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $c) { throw "Cannot find Godot. Put godot_console on PATH or set GODOT." }
    $godot = $c.Source
}

$tests = Get-ChildItem "$Root\godot" -Filter *_test.gd | Where-Object { $Native -or $_.Name -ne "native_test.gd" }
if (-not $tests) { throw "No tests found in godot\" }

$failed = @()
foreach ($t in $tests) {
    $log = Join-Path ([IO.Path]::GetTempPath()) "critter-$($t.BaseName).log"
    $p = Start-Process $godot -ArgumentList "--headless", "--path", "`"$Root\godot`"", "--script", "res://$($t.Name)" `
        -RedirectStandardOutput $log -RedirectStandardError "$log.err" -NoNewWindow -PassThru
    $null = $p.Handle   # without this, ExitCode is empty once the process has gone
    $finished = $p.WaitForExit($TimeoutSec * 1000)
    if (-not $finished) { $p.Kill() }
    $out = (@(Get-Content $log, "$log.err" -ErrorAction SilentlyContinue) -join "`n")
    $why = if (-not $finished) { "did not finish in $TimeoutSec s" }
        elseif ($p.ExitCode -ne 0) { "exit code $($p.ExitCode)" }
        elseif ($out -match "SCRIPT ERROR|Parse Error") { "script error" }
        else { "" }
    $summary = ($out -split "`n" | Where-Object { $_ -match "checks" } | Select-Object -Last 1)
    if ($why -eq "") {
        Write-Host "PASS  $($t.Name)  $summary" -ForegroundColor Green
    } else {
        Write-Host "FAIL  $($t.Name)  ($why)" -ForegroundColor Red
        Write-Host $out
        if ($env:GITHUB_ACTIONS) { Write-Host "::error file=godot/$($t.Name)::$($t.Name) failed: $why" }
        $failed += $t.Name
    }
}

if ($failed) {
    Write-Host ""
    Write-Host "$($failed.Count) of $($tests.Count) failed: $($failed -join ', ')" -ForegroundColor Red
    exit 1
}
Write-Host ""
Write-Host "All $($tests.Count) passed." -ForegroundColor Green
exit 0
