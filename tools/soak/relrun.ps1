param([string]$Exe, [string]$ArgLine, [string]$Out, [int]$Every = 30, [int]$TimeoutS = 900)
# Starts the exported game, samples it like sample.ps1, and returns its exit code.
Add-Type -Namespace W -Name U -MemberDefinition '[DllImport("user32.dll")] public static extern uint GetGuiResources(System.IntPtr h, uint flags);'
$p = Start-Process -FilePath $Exe -ArgumentList $ArgLine -PassThru -RedirectStandardOutput "$Out.stdout.txt" -RedirectStandardError "$Out.stderr.txt"
$h = $p.Handle   # keep a handle so ExitCode is readable afterwards
"t_s,ws_mb,private_mb,handles,threads,gdi,user,cpu_s" | Out-File "$Out.csv" -Encoding ascii
$t0 = Get-Date
$next = 0
while (-not $p.HasExited) {
    $el = ((Get-Date) - $t0).TotalSeconds
    if ($el -ge $next -and $Every -gt 0) {
        $p.Refresh()
        try {
            $line = "{0:F0},{1:F1},{2:F1},{3},{4},{5},{6},{7:F1}" -f $el, ($p.WorkingSet64 / 1MB), ($p.PrivateMemorySize64 / 1MB), $p.HandleCount, $p.Threads.Count, [W.U]::GetGuiResources($h, 0), [W.U]::GetGuiResources($h, 1), $p.TotalProcessorTime.TotalSeconds
            $line | Out-File "$Out.csv" -Append -Encoding ascii
        } catch {}
        $next += $Every
    }
    if ($el -gt $TimeoutS) { "TIMEOUT"; break }
    Start-Sleep -Milliseconds 250
}
$p.WaitForExit()
"exit=0x{0:X8} ({1})" -f $p.ExitCode, $p.ExitCode
