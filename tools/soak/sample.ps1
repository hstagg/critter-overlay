param([string]$PidFile, [string]$Out, [int]$Every = 60)
# Samples one process (by the id the soak monitor writes) until it exits:
# working set, private bytes, handles, threads, GDI and USER objects, CPU s.
Add-Type -Namespace W -Name U -MemberDefinition '[DllImport("user32.dll")] public static extern uint GetGuiResources(System.IntPtr h, uint flags);'
while (-not (Test-Path $PidFile)) { Start-Sleep -Milliseconds 200 }
Start-Sleep -Milliseconds 300
$id = [int](Get-Content $PidFile -Raw)
$p = Get-Process -Id $id
"t_s,ws_mb,private_mb,handles,threads,gdi,user,cpu_s" | Out-File $Out -Encoding ascii
$t0 = Get-Date
while (-not $p.HasExited) {
    $p.Refresh()
    try {
        $gdi = [W.U]::GetGuiResources($p.Handle, 0)
        $usr = [W.U]::GetGuiResources($p.Handle, 1)
        $line = "{0:F0},{1:F1},{2:F1},{3},{4},{5},{6},{7:F1}" -f ((Get-Date) - $t0).TotalSeconds, ($p.WorkingSet64 / 1MB), ($p.PrivateMemorySize64 / 1MB), $p.HandleCount, $p.Threads.Count, $gdi, $usr, $p.TotalProcessorTime.TotalSeconds
        $line | Out-File $Out -Append -Encoding ascii
    } catch {}
    Start-Sleep -Seconds $Every
}
