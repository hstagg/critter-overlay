# Inside the test VM: run a command on the logged-in desktop and wait for it.
# Programs started straight from an SSH session have no desktop, so their
# windows never appear; a scheduled task with an interactive logon runs in
# the auto-logged-on test user's session instead.
#
#   vm-run.ps1 -Name soak -Command 'bash C:/critter-overlay/tools/soak/run.sh soak 4200 --seconds=3900 ...'
#
# The command's output goes to C:\soak\<Name>.log; this prints its exit code.
param([Parameter(Mandatory)][string]$Command, [string]$Name = "critter-run", [int]$TimeoutMin = 300, [switch]$NoWait)
$log = "C:\soak\$Name.log"
New-Item -ItemType Directory -Force C:\soak | Out-Null
$task = "critter-$Name"
$action = New-ScheduledTaskAction -Execute "cmd.exe" -Argument "/c $Command > `"$log`" 2>&1" -WorkingDirectory "C:\critter-overlay"
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes $TimeoutMin) -AllowStartIfOnBatteries
Register-ScheduledTask -TaskName $task -Action $action -Principal $principal -Settings $settings -Force | Out-Null
Start-ScheduledTask -TaskName $task
if ($NoWait) { "started $task; log $log"; return }
Start-Sleep -Seconds 2
while ((Get-ScheduledTask -TaskName $task).State -eq "Running") { Start-Sleep -Seconds 5 }
$code = (Get-ScheduledTaskInfo -TaskName $task).LastTaskResult
Unregister-ScheduledTask -TaskName $task -Confirm:$false
"exit=0x{0:X8} log=$log" -f $code
