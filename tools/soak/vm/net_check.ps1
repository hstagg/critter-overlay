# On the test VM: what the installed app connects to (L3 in
# docs/v3-launch-plan.md). Starts it as a player would, then for -Seconds
# records every TCP connection the process owns, and names each address from
# the DNS cache. The update check happens 20 s after start, so a minute
# covers it. Run it on the desktop through vm-run.ps1.
#
#   vm-run.ps1 -Name net -TimeoutMin 5 -Command "powershell -NoProfile -ExecutionPolicy Bypass -File C:\critter-overlay\tools\soak\vm\net_check.ps1"
#
# PASS when every address belongs to a GitHub name (api.github.com, and the
# download hosts when an update is fetched).
param(
    [string]$Exe = "$env:LOCALAPPDATA\Programs\Critter Overlay\CritterOverlay.exe",
    [int]$Seconds = 60,
    [string]$Out = "C:\soak\net-check.txt"
)
Clear-DnsClientCache
$p = Start-Process $Exe -PassThru
$seen = @{}
$t0 = Get-Date
while (((Get-Date) - $t0).TotalSeconds -lt $Seconds -and -not $p.HasExited) {
    Get-NetTCPConnection -OwningProcess $p.Id -ErrorAction SilentlyContinue |
        Where-Object { $_.RemoteAddress -notin "0.0.0.0", "::", "127.0.0.1", "::1" } |
        ForEach-Object { $seen["$($_.RemoteAddress):$($_.RemotePort)"] = $true }
    Start-Sleep -Milliseconds 250
}
taskkill /IM CritterOverlay.exe | Out-Null
$cache = Get-DnsClientCache -ErrorAction SilentlyContinue
$lines = @()
$ok = $true
foreach ($k in $seen.Keys) {
    $ip = $k.Substring(0, $k.LastIndexOf(":"))
    $names = @($cache | Where-Object { $_.Data -eq $ip } | ForEach-Object Entry | Select-Object -Unique)
    $github = @($names | Where-Object { $_ -match "github" }).Count -gt 0
    if (-not $github) { $ok = $false }
    $lines += "  $k  $($names -join ', ')"
}
if ($seen.Count -eq 0) { $ok = $false; $lines += "  none: the update check did not run, so this shows nothing" }
$head = "{0} net        {1} {2} address(es) in {3} s; all GitHub: {4}" -f (Get-Date -Format "HH:mm:ss"), $(if ($ok) { "PASS" } else { "FAIL" }), $seen.Count, $Seconds, $ok
@($head) + $lines | Out-File $Out -Append -Encoding utf8
