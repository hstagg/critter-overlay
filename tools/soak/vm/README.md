# Windows test VM

A Windows 11 VM on a spare Linux box (KVM), for soak and stress runs that
would otherwise tie up a working PC. Reached over SSH through the host.

## What it is good for, and what not

Good for: long soaks (8 to 24 h), leaks (working set, GDI and USER objects,
Godot object counts), script errors, behaviour logic and anomalies, exit
codes. Not for: frame rates, CPU cost, or the Intel GL exit crash. The VM
has no GPU (software rendering), so those numbers say nothing about real
hardware; run the performance and exit-crash checks on a real Intel machine
(`../night_exit.ps1` as a one-off scheduled task).

## Build it

On the Linux host, with passwordless sudo:

1. Download the Windows 11 Enterprise evaluation ISO from Microsoft's
   Evaluation Center (90 days; rebuild when it expires).
2. Copy `autounattend.xml` and `firstlogon.ps1` to a folder and fill in
   their placeholders: `__PASSWORD__` (the local `tester` account; keep it
   in a file only you can read) and `__SSHKEY__` (the public key that may
   log in).
3. `./create-vm.sh WINDOWS_ISO THAT_FOLDER`. Windows installs unattended,
   logs in as `tester`, keeps the session awake and unlocked, and enables
   OpenSSH with key login only: 30 to 45 minutes.
4. Give the VM a fixed address (`virsh net-update default add ip-dhcp-host
   ...`) and an SSH entry with `ProxyJump` through the host.
5. Over SSH: `vm-setup.ps1 -Branch <branch>` installs Git, Godot 4.7.2 and
   its export templates, and clones the repo to `C:\critter-overlay`.
6. Copy the native DLLs into `C:\critter-overlay\godot\bin` (gitignored;
   build them or take them from a dev checkout) and import once:
   `godot --headless --path godot --import`.

## Run tests

Programs started straight from SSH have no desktop, so their windows never
appear. `vm-run.ps1` runs a command in the logged-in session instead and
waits for it:

```powershell
C:\critter-overlay\tools\soak\vm\vm-run.ps1 -Name soak -Command 'bash tools/soak/run.sh soak 4200 --seconds=3900 --gather-every=90 --stay=900 --idle-sim=480,240 --soak-mode=soak --soak-every=60'
```

Results land in `C:\critter-overlay\tools\soak\out`; copy them back with
`scp`. Use `-NoWait` for long runs and check back later.
