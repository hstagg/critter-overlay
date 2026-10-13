# On the test VM: a settings or welcome tour into C:\soak\<Name>, on the desktop.
#   tour.ps1 -Name p4t -Kind settings -Settings C:\soak\qdark.json
param([Parameter(Mandatory)][string]$Name, [ValidateSet("settings", "welcome")][string]$Kind = "settings", [string]$Settings = "C:\soak\q3e.json")
$dir = "C:\soak\$Name"
Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $dir | Out-Null
$cmd = "C:\tools\godot\godot.exe --path godot -- --$Kind-tour=$dir --settings=$Settings --save=C:\soak\e-$Name.json"
& powershell -NoProfile -ExecutionPolicy Bypass -File C:\critter-overlay\tools\soak\vm\vm-run.ps1 -Name $Name -TimeoutMin 6 -Command $cmd
Select-String -Path "C:\soak\$Name.log" -Pattern "SCRIPT ERROR", "TOUR done", "Can't save" | Select-Object -First 5 | ForEach-Object Line
"{0} pictures" -f (Get-ChildItem "$dir\*.png").Count
