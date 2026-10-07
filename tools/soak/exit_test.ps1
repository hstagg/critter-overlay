param([string]$Exe, [string]$Dir, [int]$N = 20, [string]$Mode = "timed")
# Exit cleanliness: launch N times and record each exit code.
#   timed     --seconds=8 with legendaries (auras, trails): the _quit() path
#   second    no flags while the installed app holds the mutex: "already running"
#   wmclose   --seconds=60, then taskkill without /f (WM_CLOSE) after 8 s
$results = @()
for ($i = 1; $i -le $N; $i++) {
    $out = Join-Path $Dir ("exit_{0}_{1}" -f $Mode, $i)
    if ($Mode -eq "second" -and -not (Get-Process CritterOverlay -ErrorAction SilentlyContinue | ? { $_.Path -like "*\Programs\Critter Overlay\*" })) {
        "ABORT: the installed app is not running, so a flagless launch would be a real session"; break
    }
    switch ($Mode) {
        "timed"   { $a = "-- --seconds=8 --kittens=6 --tier=legendary --report=$Dir/exit_report_$i.json" }
        "second"  { $a = "" }
        "wmclose" { $a = "-- --seconds=60 --kittens=6 --tier=legendary" }
    }
    $p = if ($a) { Start-Process -FilePath $Exe -ArgumentList $a -PassThru -RedirectStandardOutput "$out.out.txt" -RedirectStandardError "$out.err.txt" }
         else { Start-Process -FilePath $Exe -PassThru -RedirectStandardOutput "$out.out.txt" -RedirectStandardError "$out.err.txt" }
    $h = $p.Handle
    if ($Mode -eq "wmclose") {
        Start-Sleep -Seconds 8
        taskkill /PID $p.Id | Out-Null
    }
    if (-not $p.WaitForExit(90000)) { $p.Kill(); $code = "HUNG" } else { $code = "0x{0:X8}" -f $p.ExitCode }
    $results += $code
    "{0} {1} {2}" -f $Mode, $i, $code
    Start-Sleep -Milliseconds 500
}
"SUMMARY $Mode : " + (($results | Group-Object | % { "$($_.Name) x$($_.Count)" }) -join ", ")
