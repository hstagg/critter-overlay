# First logon on the Critter Overlay test VM: stay awake and unlocked, no
# surprise restarts, and SSH in with a key only. Logs to C:\setup.
New-Item -ItemType Directory -Force C:\setup | Out-Null
Start-Transcript -Path C:\setup\firstlogon.log -Append

# Awake and unlocked: tests open windows on this desktop.
powercfg /change standby-timeout-ac 0
powercfg /change monitor-timeout-ac 0
powercfg /change hibernate-timeout-ac 0
powercfg /hibernate off
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Personalization" /v NoLockScreen /t REG_DWORD /d 1 /f
reg add "HKCU\Control Panel\Desktop" /v ScreenSaveActive /t REG_SZ /d 0 /f
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v InactivityTimeoutSecs /t REG_DWORD /d 0 /f

# Updates download but never restart with someone logged on.
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoRebootWithLoggedOnUsers /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v AUOptions /t REG_DWORD /d 3 /f

# OpenSSH server, key login only, PowerShell as the shell.
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
Set-Service sshd -StartupType Automatic
Start-Service sshd
if (-not (Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -DisplayName "OpenSSH Server (sshd)" -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
}
# The VM's NAT network comes up as Public, and the capability's rule only
# covers Private: open it on any profile, and call the network Private.
Set-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -Profile Any
Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private
$keys = "C:\ProgramData\ssh\administrators_authorized_keys"
Set-Content -Path $keys -Value "__SSHKEY__" -Encoding ascii
icacls $keys /inheritance:r /grant "Administrators:F" /grant "SYSTEM:F"
New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell -Value "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -PropertyType String -Force
$conf = "C:\ProgramData\ssh\sshd_config"
(Get-Content $conf) -replace '^#?PasswordAuthentication .*', 'PasswordAuthentication no' | Set-Content $conf -Encoding ascii
Restart-Service sshd

"done $(Get-Date)" | Out-File C:\setup\done.txt
Stop-Transcript
