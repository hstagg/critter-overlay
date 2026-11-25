# Runs on the test VM (copied there by vm_take.py): films one --film take of a
# released build and packs the frames into C:\soak\film\<Name>.tar.
#
#   powershell -File C:\soak\vm-film.ps1 -Name kittens1 -Ref v3.1.1 -GameArgs "--species=kitten --kittens=3 --seconds=20"
#
# The build lives in its own worktree, C:\critter-film, so the VM's main
# checkout (used by other sessions) is never switched. Exit codes: 3 the VM is
# busy, 4 no frames were written.
param([Parameter(Mandatory)][string]$Name, [string]$Ref = "main", [string]$GameArgs = "", [int]$Fps = 30)
$ErrorActionPreference = "Stop"
$repo = "C:\critter-overlay"; $wt = "C:\critter-film"; $godot = "C:\tools\godot\godot.exe"
$run = "$repo\tools\soak\vm\vm-run.ps1"

if (@(Get-Process godot*, CritterOverlay* -ErrorAction SilentlyContinue).Count) { "busy: Godot is already running"; exit 3 }
$ErrorActionPreference = "Continue"   # git writes progress to stderr
git -C $repo fetch --quiet origin --tags
$want = (git -C $repo rev-parse "$Ref^{commit}").Trim()
$fresh = $false
if (-not (Test-Path $wt)) {
    git -C $repo worktree add --detach $wt $want 2>&1 | Out-Null
    $fresh = $true
} elseif ((git -C $wt rev-parse HEAD).Trim() -ne $want) {
    git -C $wt checkout --quiet --detach $want 2>&1 | Out-Null
    $fresh = $true
}
$ErrorActionPreference = "Stop"
if (-not (Test-Path "$wt\godot\bin") -and (Test-Path "$repo\godot\bin")) { Copy-Item -Recurse "$repo\godot\bin" "$wt\godot\bin" }
if ($fresh -or -not (Test-Path "$wt\godot\.godot")) {
    & $run -Name film-import -Command "$godot --headless --path $wt\godot --import" -TimeoutMin 20 | Out-Null
}

$out = "C:\soak\film\$Name"
Remove-Item -Recurse -Force $out, "$out.tar" -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $out | Out-Null
$cmd = "$godot --fixed-fps $Fps --path $wt\godot -- --film=$out\frames --idle-sim=100000,1 --settings=$out\settings.json --save=$out\save.json $GameArgs"
& $run -Name "film-$Name" -Command $cmd -TimeoutMin 30
if (-not (Test-Path "$out\frames\frames.jsonl")) { "no frames written; see C:\soak\film-$Name.log"; exit 4 }
tar -cf "$out.tar" -C $out frames
"ok $out.tar $($want.Substring(0, 7))"
