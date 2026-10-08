param([string]$Kit, [string]$TaskName = "")
# The full exit test, unattended (for a scheduled task): 20 timed exits,
# 10 second-instance launches, 10 WM_CLOSE closes, all with sound off, then
# any crash events from the Application log. Results in $Kit\results-<time>.
# With -TaskName, removes that scheduled task when done (a one-off run).
$stamp = Get-Date -Format "yyyyMMdd-HHmm"
$dir = Join-Path $Kit "results-$stamp"
New-Item -ItemType Directory -Force $dir | Out-Null
$log = Join-Path $dir "summary.txt"
$exe = Join-Path $Kit "rel\CritterOverlay.exe"
$start = Get-Date
'{"sound": {"pops": false, "volume": 0}, "system": {"onboarded": true}}' | Out-File (Join-Path $dir "silent.json") -Encoding ascii
"started $start" | Out-File $log -Encoding utf8
foreach ($m in @(@("timed", 20), @("second", 10), @("wmclose", 10))) {
    & (Join-Path $Kit "exit_test.ps1") -Exe $exe -Dir $dir -N $m[1] -Mode $m[0] -Settings (Join-Path $dir "silent.json") | Out-File $log -Append -Encoding utf8
}
"--- Application log crash events since start (CritterOverlay):" | Out-File $log -Append -Encoding utf8
Get-WinEvent -FilterHashtable @{LogName = 'Application'; StartTime = $start} -ErrorAction SilentlyContinue |
    Where-Object { $_.Id -in 1000, 1001, 1002 -and $_.Message -match "CritterOverlay" } |
    ForEach-Object { "{0} id={1} {2}" -f $_.TimeCreated, $_.Id, ($_.Message -split "`n" | Select-Object -First 6) -join " | " } |
    Out-File $log -Append -Encoding utf8
"finished $(Get-Date)" | Out-File $log -Append -Encoding utf8
if ($TaskName -ne "") { Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue }
